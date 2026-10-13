extends Node2D
## Render and collision are derived from the same map data, not separate maps.
@export var layout: MapLayout
var grid_overlay: bool = false
var walkability_overlay: bool = false
var waypoints_overlay: bool = false
var paths_overlay: bool = false
var spawns_overlay: bool = true
var towers_overlay: bool = true
## Runtime-only gameplay geometry.  The authored reference sprite is deliberately
## outside this code path: hiding it cannot change map navigation or collisions.
var debug_enabled: bool = false
var tower_attack_range: float = 380.0
var tower_body_radius: float = 44.0
var units: Array[MapUnit] = []
var _label_scale: float = 0

func _ready() -> void:
	if layout == null: return
	var errors := layout.validation_errors()
	if not errors.is_empty():
		push_error("Invalid map data: " + "; ".join(errors))
		return
	_build_gameplay_hierarchy()
	var blockers: Node2D = get_node("StaticBlockers")
	var walls := StaticBody2D.new()
	walls.name = "WorldBoundary"
	walls.collision_layer = 1
	walls.collision_mask = 0
	blockers.add_child(walls)
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
	_build_towers()
	_build_jungle_camps()
	# Compatibility handle for the pre-greybox prototype.  Gameplay collision is
	# now under StaticBlockers/WorldBoundary; this marker preserves old tooling
	# that inspected the former TerrainCollision container.
	var legacy_collision := Node2D.new()
	legacy_collision.name = "TerrainCollision"
	legacy_collision.add_child(Marker2D.new())
	add_child(legacy_collision)
	queue_redraw()

func _build_gameplay_hierarchy() -> void:
	# Keep visual geometry, pathfinding metadata and physics bodies distinct.  This
	# node tree is intentionally created from MapLayout rather than from pixels.
	for child_name in ["VisualGreybox", "Navigation", "StaticBlockers", "Towers", "JungleCamps", "DebugOverlay"]:
		if not has_node(child_name):
			var node := Node2D.new()
			node.name = child_name
			add_child(node)
	var visual: Node2D = get_node("VisualGreybox")
	for child_name in ["LanePolygons", "JungleGroundPolygons", "RiverPolygons", "BlockedTerrainPolygons"]:
		if not visual.has_node(child_name):
			var layer := Node2D.new()
			layer.name = child_name
			visual.add_child(layer)
	var navigation: Node2D = get_node("Navigation")
	if not navigation.has_node("NavigationRegion2D"):
		var region := NavigationRegion2D.new()
		region.name = "NavigationRegion2D"
		# Runtime A* uses the same MapLayout with agent-radius clearance.  The
		# region contains only individual legal cells, never a full-map rectangle.
		region.navigation_polygon = _navigation_polygon_from_layout()
		navigation.add_child(region)
	_build_greybox_polygons()

func _navigation_polygon_from_layout() -> NavigationPolygon:
	var nav := NavigationPolygon.new()
	var tile := layout.tile_size
	var vertices := PackedVector2Array()
	var polygons: Array[PackedInt32Array] = []
	for y in range(layout.dimensions.y):
		for x in range(layout.dimensions.x):
			if not layout.is_walkable(Vector2i(x, y)): continue
			var first := vertices.size()
			var origin := Vector2(x, y) * tile
			vertices.append_array(PackedVector2Array([origin, origin + Vector2(tile, 0), origin + Vector2(tile, tile), origin + Vector2(0, tile)]))
			polygons.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))
	nav.vertices = vertices
	for polygon in polygons: nav.add_polygon(polygon)
	return nav

func _build_greybox_polygons() -> void:
	var layers := {"Lane": "LanePolygons", "Jungle": "JungleGroundPolygons", "River": "RiverPolygons", "Wall": "BlockedTerrainPolygons"}
	var colors := {"Lane": Color(0.78, 0.70, 0.49, 0.75), "Jungle": Color(0.18, 0.38, 0.22, 0.55), "River": Color(0.18, 0.48, 0.78, 0.72), "Wall": Color(0.18, 0.15, 0.18, 0.9)}
	var visual: Node2D = get_node("VisualGreybox")
	for y in range(layout.dimensions.y):
		for x in range(layout.dimensions.x):
			var terrain: String = layout.terrain_at(Vector2i(x, y)).get("name", "")
			if not layers.has(terrain): continue
			var polygon := Polygon2D.new()
			polygon.name = "%s_%02d_%02d" % [terrain.replace(" ", ""), x, y]
			var origin := Vector2(x, y) * layout.tile_size
			polygon.polygon = PackedVector2Array([origin, origin + Vector2(layout.tile_size, 0), origin + Vector2.ONE * layout.tile_size, origin + Vector2(0, layout.tile_size)])
			polygon.color = colors[terrain]
			visual.get_node(layers[terrain]).add_child(polygon)

func _build_towers() -> void:
	var towers: Node2D = get_node("Towers")
	for index in range(layout.tower_cells.size()):
		var tower := Node2D.new()
		tower.name = "Tower_%02d" % (index + 1)
		tower.position = layout.cell_center(Vector2i(layout.tower_cells[index]))
		tower.set_meta("team", layout.tower_team(index))
		tower.set_meta("lane", layout.tower_lanes[index])
		tower.set_meta("tier", layout.tower_tiers[index])
		tower.set_meta("attack_range", tower_attack_range)
		tower.set_meta("is_alive", true)
		var body := StaticBody2D.new()
		body.name = "StaticBody2D"
		# MapUnit terrain mask is 1, so tower bodies share that solid world layer.
		# The separate AttackRange remains layer 0 and can never block movement.
		body.collision_layer = 1
		body.collision_mask = 0
		var body_shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = tower_body_radius
		body_shape.shape = circle
		body.add_child(body_shape)
		tower.add_child(body)
		var attack_range := Area2D.new()
		attack_range.name = "AttackRange"
		attack_range.collision_layer = 0
		attack_range.collision_mask = 2
		var range_shape := CollisionShape2D.new()
		var range_circle := CircleShape2D.new()
		range_circle.radius = tower_attack_range
		range_shape.shape = range_circle
		attack_range.add_child(range_shape)
		tower.add_child(attack_range)
		towers.add_child(tower)

func _build_jungle_camps() -> void:
	var camps: Node2D = get_node("JungleCamps")
	for index in range(layout.jungle_camps.size()):
		var camp := Node2D.new()
		camp.name = "Camp_%02d" % (index + 1)
		camp.position = layout.cell_center(Vector2i(layout.jungle_camps[index]))
		camp.set_meta("camp_id", "camp_%02d" % (index + 1))
		var marker := Marker2D.new()
		marker.name = "Marker2D"
		camp.add_child(marker)
		for definition in [["SpawnArea", 72.0], ["LeashArea", 280.0]]:
			var area := Area2D.new()
			area.name = definition[0]
			area.collision_layer = 0
			area.collision_mask = 0
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = definition[1]
			shape.shape = circle
			area.add_child(shape)
			camp.add_child(area)
		camps.add_child(camp)

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	walkability_overlay = enabled
	paths_overlay = enabled
	towers_overlay = true
	queue_redraw()

func _process(_delta: float) -> void:
	var scale_value := get_global_transform_with_canvas().get_scale().x
	if debug_enabled or paths_overlay or not is_equal_approx(scale_value, _label_scale): queue_redraw()
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
			if terrain_name == "Lane":
				draw_rect(rect.grow(-10), Color(0.82, 0.73, 0.55, 0.36))
			elif terrain_name == "Jungle" and ((x * 17 + y * 31) % 7 == 0):
				_draw_jungle_patch(rect, x, y)
			if layout.is_brush_cell(cell):
				_draw_brush_patch(rect)
			elif terrain_name == "Ground / passage" and ((x * 13 + y * 19) % 23 == 0):
				draw_circle(rect.get_center() + Vector2(-12, 14), 7, Color(0.35, 0.52, 0.28, 0.6))
			if terrain_name == "River":
				river_total += x + 0.5
				river_count += 1
			if walkability_overlay:
				var overlay_color: Color = Color(0.3, 1, 0.4, 0.18) if layout.is_walkable(cell) else Color(1, 0.2, 0.15, 0.38)
				draw_rect(rect.grow(-4), overlay_color, true)
				draw_rect(rect.grow(-4), overlay_color.lightened(0.25), false, 3)
		if river_count > 0: river_points.append(Vector2(river_total / river_count * tile, (y + 0.5) * tile))
	if river_points.size() > 1:
		for point in river_points: draw_circle(point, tile * 0.74, Color(0.12, 0.45, 0.72, 0.92))
		draw_polyline(river_points, river_color.lightened(0.18), tile * 1.18, true)
		for index in range(0, river_points.size(), 3):
			var point := river_points[index]
			draw_line(point + Vector2(-tile * 0.28, -6), point + Vector2(tile * 0.18, -6), Color(0.55, 0.88, 0.96, 0.45), 5, true)
	var wall_color: Color = layout.terrain_definitions.get("#", {}).get("color", Color(0.20, 0.23, 0.24))
	for bounds in _interior_wall_bounds():
		var wall_style := StyleBoxFlat.new()
		wall_style.bg_color = wall_color
		wall_style.set_corner_radius_all(roundi(tile * 0.65))
		draw_style_box(wall_style, Rect2(Vector2(bounds.position) * tile + Vector2(5, 5), Vector2(bounds.size) * tile - Vector2(10, 10)))
		if debug_enabled:
			draw_rect(Rect2(Vector2(bounds.position) * tile, Vector2(bounds.size) * tile), Color(1, 0.18, 0.15, 0.95), false, 7)
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
		_draw_base_badge(rect.get_center(), Color(0.18, 0.58, 1.0) if index == 0 else Color(1.0, 0.28, 0.3))
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
	if debug_enabled:
		for index in range(layout.tower_cells.size()):
			var tower_point := layout.cell_center(Vector2i(layout.tower_cells[index]))
			draw_arc(tower_point, tower_attack_range, 0, TAU, 64, Color(1, 0.2, 0.18, 0.72), 4, true)
			draw_arc(tower_point, tower_body_radius, 0, TAU, 24, Color(1, 0.18, 0.15, 1), 4, true)
		for cell in layout.jungle_camps:
			var camp_point := layout.cell_center(Vector2i(cell))
			draw_circle(camp_point, 9, Color(1, 0.82, 0.1, 1))
			draw_arc(camp_point, 280, 0, TAU, 48, Color(1, 0.82, 0.1, 0.9), 4, true)
		var mouse := get_global_mouse_position()
		_label("MAP %.0f, %.0f" % [mouse.x, mouse.y], mouse + Vector2(18, -18), Color(1, 1, 0.75), 24)

func _draw_jungle_patch(rect: Rect2, x: int, y: int) -> void:
	var center := rect.get_center() + Vector2(float((x * 11) % 17 - 8), float((y * 7) % 13 - 6))
	draw_circle(center + Vector2(-18, 10), 22, Color(0.05, 0.25, 0.2, 0.92))
	draw_circle(center + Vector2(12, 5), 26, Color(0.10, 0.40, 0.26, 0.95))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-28, 8), center + Vector2(-8, -30), center + Vector2(5, 8)]), Color(0.30, 0.62, 0.25, 0.9))
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, 8), center + Vector2(17, -35), center + Vector2(35, 8)]), Color(0.20, 0.52, 0.23, 0.9))
	draw_line(center + Vector2(-17, 8), center + Vector2(-17, 30), Color(0.25, 0.20, 0.12, 0.8), 7, true)

func _draw_brush_patch(rect: Rect2) -> void:
	var color := Color(0.22, 0.62, 0.23, 0.9)
	for offset in [Vector2(-32, 30), Vector2(-12, 12), Vector2(12, 28), Vector2(34, 7)]:
		draw_colored_polygon(PackedVector2Array([rect.get_center() + offset + Vector2(-10, 13), rect.get_center() + offset + Vector2(0, -24), rect.get_center() + offset + Vector2(10, 13)]), color)

func _draw_base_badge(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(0, 18), 62, Color(0.03, 0.08, 0.12, 0.3))
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -58), center + Vector2(43, 0), center + Vector2(0, 58), center + Vector2(-43, 0)]), Color(color, 0.8))
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -39), center + Vector2(28, 0), center + Vector2(0, 39), center + Vector2(-28, 0)]), color.lightened(0.22))
