extends Node2D
## Render and collision are derived from the same map data, not separate maps.
@export var layout: MapLayout
var grid_overlay: bool = false
var walkability_overlay: bool = false
var waypoints_overlay: bool = false
var paths_overlay: bool = false
var spawns_overlay: bool = true
var towers_overlay: bool = true
var units: Array[MapUnit] = []
var _label_scale: float = 0

func _ready() -> void:
	if layout == null: return
	var errors := layout.validation_errors()
	if not errors.is_empty():
		push_error("Invalid map data: " + "; ".join(errors))
		return
	var walls := StaticBody2D.new()
	walls.name = "TerrainCollision"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	# Merge each blocked run into a capsule. Long walls remain solid, while the
	# rounded ends stop moving circles from catching on square outer corners.
	for y in range(layout.dimensions.y):
		var x := 0
		while x < layout.dimensions.x:
			if layout.is_walkable(Vector2i(x, y)):
				x += 1
				continue
			var first := x
			while x < layout.dimensions.x and not layout.is_walkable(Vector2i(x, y)): x += 1
			var collision := CollisionShape2D.new()
			collision.position = Vector2(first + (x - first) * 0.5, y + 0.5) * layout.tile_size
			var run_width: float = (x - first) * layout.tile_size
			if y == 0 or y == layout.dimensions.y - 1 or first == 0 or x == layout.dimensions.x:
				var edge := RectangleShape2D.new()
				edge.size = Vector2(run_width, layout.tile_size)
				collision.shape = edge
			elif x - first == 1:
				var circle := CircleShape2D.new()
				circle.radius = layout.tile_size * 0.47
				collision.shape = circle
			else:
				var capsule := CapsuleShape2D.new()
				capsule.radius = layout.tile_size * 0.47
				capsule.height = run_width - layout.tile_size * 0.06
				collision.shape = capsule
				collision.rotation = PI * 0.5
			walls.add_child(collision)
	# Physical bounds also support edited layouts without blocked perimeter cells.
	var size := layout.world_size()
	for rect in [Rect2(-128, -128, size.x + 256, 128), Rect2(-128, size.y, size.x + 256, 128), Rect2(-128, 0, 128, size.y), Rect2(size.x, 0, 128, size.y)]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)
	queue_redraw()

func _process(_delta: float) -> void:
	var scale_value := get_global_transform_with_canvas().get_scale().x
	if paths_overlay or not is_equal_approx(scale_value, _label_scale): queue_redraw()
	_label_scale = scale_value

func set_overlay(key: String, enabled: bool) -> void:
	set(key + "_overlay", enabled)
	queue_redraw()

func _label(text: String, point: Vector2, color: Color, size_value: int = 36) -> void:
	var readable_size := maxi(size_value, ceili(18 / maxf(0.01, get_global_transform_with_canvas().get_scale().x)))
	draw_string(ThemeDB.fallback_font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, readable_size, color)

func _interior_wall_bounds() -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var visited: Dictionary = {}
	for y in range(1, layout.dimensions.y - 1):
		for x in range(1, layout.dimensions.x - 1):
			var start := Vector2i(x, y)
			if layout.is_walkable(start) or visited.has(start): continue
			var pending: Array[Vector2i] = [start]
			visited[start] = true
			var minimum := start
			var maximum := start
			while not pending.is_empty():
				var cell: Vector2i = pending.pop_back()
				minimum = Vector2i(mini(minimum.x, cell.x), mini(minimum.y, cell.y))
				maximum = Vector2i(maxi(maximum.x, cell.x), maxi(maximum.y, cell.y))
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + direction
					if next.x <= 0 or next.y <= 0 or next.x >= layout.dimensions.x - 1 or next.y >= layout.dimensions.y - 1: continue
					if visited.has(next) or layout.is_walkable(next): continue
					visited[next] = true
					pending.append(next)
			result.append(Rect2i(minimum, maximum - minimum + Vector2i.ONE))
	return result

func _draw() -> void:
	if layout == null: return
	var tile := layout.tile_size
	var ground_color: Color = layout.terrain_definitions.get(".", {}).get("color", Color(0.29, 0.40, 0.29))
	var river_color: Color = layout.terrain_definitions.get("W", {}).get("color", Color(0.20, 0.42, 0.58))
	var river_points := PackedVector2Array()
	for y in range(layout.dimensions.y):
		var river_total: float = 0.0
		var river_count: int = 0
		for x in range(layout.dimensions.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * tile, Vector2.ONE * tile)
			var terrain: Dictionary = layout.terrain_at(cell)
			var terrain_name: String = terrain.get("name", "")
			if terrain_name in ["Wall", "River"]:
				draw_rect(rect, ground_color)
			else:
				draw_rect(rect, terrain.get("color", Color.MAGENTA))
			if terrain_name == "River":
				river_total += x + 0.5
				river_count += 1
			if walkability_overlay:
				draw_rect(rect.grow(-6), Color(0.3, 1, 0.4, 0.12) if layout.is_walkable(cell) else Color(1, 0.2, 0.15, 0.65), false, 4)
		if river_count > 0: river_points.append(Vector2(river_total / river_count * tile, (y + 0.5) * tile))
	if river_points.size() > 1: draw_polyline(river_points, river_color, tile * 1.4, true)
	var wall_color: Color = layout.terrain_definitions.get("#", {}).get("color", Color(0.20, 0.23, 0.24))
	for bounds in _interior_wall_bounds():
		var wall_style := StyleBoxFlat.new()
		wall_style.bg_color = wall_color
		wall_style.set_corner_radius_all(roundi(tile * 0.65))
		draw_style_box(wall_style, Rect2(Vector2(bounds.position) * tile + Vector2(5, 5), Vector2(bounds.size) * tile - Vector2(10, 10)))
	# The outer boundary remains a continuous frame.
	for rect in [Rect2(0, 0, layout.world_size().x, tile), Rect2(0, layout.world_size().y - tile, layout.world_size().x, tile), Rect2(0, tile, tile, layout.world_size().y - tile * 2), Rect2(layout.world_size().x - tile, tile, tile, layout.world_size().y - tile * 2)]:
		draw_rect(rect, wall_color)
	if grid_overlay:
		for x in range(layout.dimensions.x + 1): draw_line(Vector2(x * tile, 0), Vector2(x * tile, layout.world_size().y), Color(1, 1, 1, 0.15), 1)
		for y in range(layout.dimensions.y + 1): draw_line(Vector2(0, y * tile), Vector2(layout.world_size().x, y * tile), Color(1, 1, 1, 0.15), 1)
	for index in range(layout.base_areas.size()):
		var area := layout.base_areas[index]
		var rect := Rect2(Vector2(area.position) * tile, Vector2(area.size) * tile)
		draw_rect(rect.grow(-12), Color(0.45, 0.75, 1) if index == 0 else Color(1, 0.5, 0.5), false, 8)
		_label("BLUE BASE" if index == 0 else "RED BASE", rect.position + Vector2(30, 65), Color.WHITE, 48)
	for lane in ["TOP", "MID", "BOT"]:
		var points := layout.route(lane, 0)
		if points.is_empty(): continue
		_label(lane, points[1] + Vector2(35, -40), Color(1, 1, 0.85), 48)
		if waypoints_overlay:
			draw_polyline(points, Color(1, 0.85, 0.2, 0.8), 6, true)
			for index in range(points.size()):
				draw_circle(points[index], 18, Color(1, 0.85, 0.2))
				if index > 0 and index < points.size() - 1:
					_label("B%d / R%d" % [index, points.size() - 1 - index], points[index] + Vector2(22, 60), Color(1, 0.9, 0.3), 28)
	if spawns_overlay:
		for team in range(2):
			for point in layout.spawn_points(team):
				draw_arc(point, 45, 0, TAU, 24, Color(0.6, 0.85, 1) if team == 0 else Color(1, 0.7, 0.7), 5, true)
	if towers_overlay:
		for cell in layout.tower_cells:
			draw_rect(Rect2(layout.cell_center(Vector2i(cell)) - Vector2(40, 50), Vector2(80, 100)), Color(1, 1, 0.9, 0.8), false, 5)
		for cell in layout.jungle_camps:
			var center := layout.cell_center(Vector2i(cell))
			draw_arc(center, 38, 0, TAU, 28, Color(0.95, 0.62, 0.18), 5, true)
			_label("CAMP", center + Vector2(-38, 65), Color(1, 0.78, 0.3), 20)
	if paths_overlay:
		for unit in units:
			if unit.path_index >= unit.path.size(): continue
			var points := PackedVector2Array([unit.position])
			points.append_array(unit.path.slice(unit.path_index))
			if points.size() > 1: draw_polyline(points, unit.view.visual_data.team_color.lightened(0.4), 5, true)
