extends RefCounted
## Deterministic grid index for local match-world queries.

const CELL_SIZE := 384.0

var _cells: Dictionary = {}
var _max_vision_range: float = 0.0
var _entity_count: int = 0
var _dirty: bool = true

func rebuild(entities: Dictionary) -> void:
	_cells.clear()
	_entity_count = entities.size()
	_dirty = false
	_max_vision_range = 0.0
	var ids: Array = entities.keys()
	ids.sort()
	for id in ids:
		var info: Dictionary = entities[id]
		var actor: MapUnit = info.actor
		if not actor.runtime.alive: continue
		var cell := _cell_for(actor.position)
		if not _cells.has(cell): _cells[cell] = []
		_cells[cell].append(id)
		_max_vision_range = maxf(_max_vision_range, float(actor.runtime.stats.get("vision_range", 0.0)))

func query_circle(center: Vector2, radius: float) -> Array[String]:
	var result: Array[String] = []
	var min_cell := _cell_for(center - Vector2.ONE * radius)
	var max_cell := _cell_for(center + Vector2.ONE * radius)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			for id in _cells.get(Vector2i(x, y), []): result.append(id)
	result.sort()
	return result

func max_vision_range() -> float:
	return _max_vision_range

func entity_count() -> int:
	return _entity_count

func invalidate() -> void:
	_dirty = true

func is_dirty() -> bool:
	return _dirty

func _cell_for(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))
