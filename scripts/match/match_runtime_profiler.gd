extends RefCounted
## Lightweight deterministic counters for diagnosing match simulation cost.

var _started_usec: int = 0
var _tick: int = 0
var _current: Dictionary = {}
var _last: Dictionary = {}

func begin(tick: int, entity_count: int) -> void:
	_tick = tick
	_started_usec = Time.get_ticks_usec()
	_current = {
		"tick": tick,
		"entities": entity_count,
		"target_queries": 0,
		"target_candidates": 0,
		"vision_checks": 0,
		"vision_observers": 0,
		"path_requests": 0,
	}

func record_target_query() -> void:
	_current.target_queries = int(_current.get("target_queries", 0)) + 1

func record_target_candidate() -> void:
	_current.target_candidates = int(_current.get("target_candidates", 0)) + 1

func record_vision_check() -> void:
	_current.vision_checks = int(_current.get("vision_checks", 0)) + 1

func record_vision_observer() -> void:
	_current.vision_observers = int(_current.get("vision_observers", 0)) + 1

func record_path_request() -> void:
	_current.path_requests = int(_current.get("path_requests", 0)) + 1

func finish() -> void:
	_current.tick_usec = Time.get_ticks_usec() - _started_usec
	_last = _current.duplicate(true)

func snapshot() -> Dictionary:
	return _last.duplicate(true)
