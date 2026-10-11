class_name MapLayout
extends Resource
## Tile authoring data; routes/spawns/markers use integer cell coordinates.
@export var dimensions := Vector2i(40, 40)
@export var tile_size: float = 128.0
@export var cells: PackedStringArray = []
@export var terrain_definitions: Dictionary = {}
@export var lane_waypoints: Dictionary = {}
@export var blue_spawns: PackedVector2Array = []
@export var red_spawns: PackedVector2Array = []
@export var base_areas: Array[Rect2i] = []
@export var tower_cells: PackedVector2Array = []
@export var tower_teams: PackedInt32Array = []
## Explicit structure metadata.  These arrays intentionally share the tower_cells
## index so gameplay never infers a lane or tier from a world position.
@export var tower_ids: PackedStringArray = []
@export var tower_lanes: PackedStringArray = []
@export var tower_tiers: PackedInt32Array = []
@export var tower_prerequisites: Array[PackedStringArray] = []
@export var jungle_camps: PackedVector2Array = []
@export var fountain_cells: PackedVector2Array = []
@export var throne_cells: PackedVector2Array = []

func world_size() -> Vector2:
	return Vector2(dimensions) * tile_size

func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size

func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / tile_size), floori(point.y / tile_size))

func in_bounds(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, dimensions).has_point(cell)

func terrain_at(cell: Vector2i) -> Dictionary:
	if not in_bounds(cell) or cell.y >= cells.size() or cell.x >= cells[cell.y].length(): return {}
	return terrain_definitions.get(cells[cell.y].substr(cell.x, 1), {})

func is_walkable(cell: Vector2i) -> bool:
	return terrain_at(cell).get("walkable", false)

func route(lane: String, team: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for cell in lane_waypoints.get(lane, PackedVector2Array()): result.append(cell_center(Vector2i(cell)))
	if team == 1: result.reverse()
	return result

func spawn_points(team: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for cell in blue_spawns if team == 0 else red_spawns: result.append(cell_center(Vector2i(cell)))
	return result

func fountain_point(team: int) -> Vector2:
	if fountain_cells.size() == 2: return cell_center(Vector2i(fountain_cells[team]))
	return spawn_points(team)[0]

func throne_point(team: int) -> Vector2:
	if throne_cells.size() == 2: return cell_center(Vector2i(throne_cells[team]))
	return spawn_points(team)[0]

func tower_team(index: int) -> int:
	if index >= 0 and index < tower_teams.size(): return tower_teams[index]
	var point := cell_center(Vector2i(tower_cells[index]))
	return 0 if point.distance_to(spawn_points(0)[0]) < point.distance_to(spawn_points(1)[0]) else 1

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if dimensions.x < 3 or dimensions.y < 3 or tile_size <= 0: errors.append("Invalid dimensions/tile size")
	if cells.size() != dimensions.y: errors.append("Row count does not match dimensions")
	for row in cells:
		if row.length() != dimensions.x: errors.append("Row width does not match dimensions")
		for symbol in row:
			if not terrain_definitions.has(symbol): errors.append("Undefined terrain: " + symbol)
	for lane in ["TOP", "MID", "BOT"]:
		var points: PackedVector2Array = lane_waypoints.get(lane, PackedVector2Array())
		if points.size() < 2: errors.append("Missing route " + lane)
		for point in points:
			if not is_walkable(Vector2i(point)): errors.append("Blocked waypoint " + lane)
	for spawns in [blue_spawns, red_spawns]:
		if spawns.is_empty(): errors.append("Missing team spawn")
		for point in spawns:
			if not is_walkable(Vector2i(point)): errors.append("Blocked spawn")
	if tower_teams.size() != tower_cells.size(): errors.append("Tower team count mismatch")
	if tower_ids.size() != tower_cells.size(): errors.append("Tower id count mismatch")
	if tower_lanes.size() != tower_cells.size(): errors.append("Tower lane count mismatch")
	if tower_tiers.size() != tower_cells.size(): errors.append("Tower tier count mismatch")
	if tower_prerequisites.size() != tower_cells.size(): errors.append("Tower prerequisite count mismatch")
	var seen_tower_ids := {}
	for index in range(tower_ids.size()):
		var id := tower_ids[index]
		if id.is_empty() or seen_tower_ids.has(id): errors.append("Invalid or duplicate tower id: " + id)
		seen_tower_ids[id] = true
		if tower_lanes[index] not in ["TOP", "MID", "BOT", "BASE"]: errors.append("Invalid tower lane: " + tower_lanes[index])
		if tower_tiers[index] < 1: errors.append("Invalid tower tier: " + str(tower_tiers[index]))
	for prerequisites in tower_prerequisites:
		for prerequisite in prerequisites:
			if prerequisite not in tower_ids: errors.append("Unknown tower prerequisite: " + prerequisite)
	for point in tower_cells:
		if not is_walkable(Vector2i(point)): errors.append("Blocked tower")
	for point in jungle_camps:
		if not is_walkable(Vector2i(point)): errors.append("Blocked jungle camp")
	for point in fountain_cells + throne_cells:
		if not is_walkable(Vector2i(point)): errors.append("Blocked base marker")
	return errors
