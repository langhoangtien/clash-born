class_name MapNavigation
extends RefCounted
## Static Godot AStarGrid2D; continuous movement/collision belongs to MapUnit.
var layout: MapLayout
var grid := AStarGrid2D.new()
var agent_radius: float
const TOWER_BODY_RADIUS := 44.0

func _init(data: MapLayout, radius: float = 32.0) -> void:
	layout = data
	agent_radius = maxf(0, radius)
	grid.region = Rect2i(Vector2i.ZERO, data.dimensions)
	grid.cell_size = Vector2.ONE * data.tile_size
	grid.offset = Vector2.ONE * data.tile_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(data.dimensions.y):
		for x in range(data.dimensions.x):
			var cell := Vector2i(x, y)
			grid.set_point_solid(cell, not point_is_clear(data.cell_center(cell)))

func _tower_is_clear(point: Vector2) -> bool:
	for tower_cell in layout.tower_cells:
		if point.distance_to(layout.cell_center(Vector2i(tower_cell))) < TOWER_BODY_RADIUS + agent_radius:
			return false
	return true

func point_is_clear(point: Vector2) -> bool:
	var size := layout.world_size()
	if not point.is_finite() or point.x < agent_radius or point.y < agent_radius or point.x > size.x - agent_radius or point.y > size.y - agent_radius: return false
	if not _tower_is_clear(point): return false
	var first := layout.world_to_cell(point - Vector2.ONE * agent_radius)
	var last := layout.world_to_cell(point + Vector2.ONE * agent_radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if layout.is_walkable(cell): continue
			var rect := Rect2(Vector2(cell) * layout.tile_size, Vector2.ONE * layout.tile_size)
			var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
			if rect.has_point(point) or point.distance_to(closest) < agent_radius - 0.001: return false
	return true

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not point_is_clear(from) or not point_is_clear(to): return []
	var start := layout.world_to_cell(from)
	var end := layout.world_to_cell(to)
	if grid.is_point_solid(start) or grid.is_point_solid(end): return []
	var points := grid.get_point_path(start, end)
	if points.is_empty(): return points
	# Replanning from a position between cell centers must not send the actor
	# backwards to its current cell center before following the next segment.
	points[0] = from
	# Cell centers guide A*, but exact destinations remain world coordinates.
	if points[-1].distance_to(to) > 0.001: points.append(to)
	return points

func lane_path(from: Vector2, lane: String, team: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var current := from
	for waypoint in layout.route(lane, team):
		var leg := path(current, waypoint)
		if leg.is_empty(): return []
		for point in leg:
			if result.is_empty() or result[-1].distance_to(point) > 0.001: result.append(point)
		current = waypoint
	return result
