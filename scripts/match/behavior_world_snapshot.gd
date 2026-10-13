class_name BehaviorWorldSnapshot
extends RefCounted
## Read-only per-tick world view. Controllers must not access live actors.

var tick: int
var facts: Array[BehaviorFact] = []
var _actors: Dictionary = {} # String -> BehaviorActorSnapshot; internal index only.
var _lane_objectives: Dictionary = {} # "team|lane" -> runtime actor ID.
var _configured_lanes: Dictionary = {} # "team|lane" -> bool.

func _init(snapshot_tick: int = 0, snapshot_facts: Array[BehaviorFact] = []) -> void:
	tick = snapshot_tick
	facts.assign(snapshot_facts)

func add_actor(actor: BehaviorActorSnapshot) -> void:
	_actors[actor.actor_id] = actor

func actor(actor_id: String) -> BehaviorActorSnapshot:
	return _actors.get(actor_id) as BehaviorActorSnapshot

func actors() -> Array[BehaviorActorSnapshot]:
	var result: Array[BehaviorActorSnapshot] = []
	for actor_snapshot in _actors.values(): result.append(actor_snapshot)
	return result

func set_lane_objective(team_id: int, lane: String, runtime_id: String) -> void:
	_lane_objectives[_lane_key(team_id, lane)] = runtime_id

func next_lane_objective_id(team_id: int, lane: String) -> String:
	return str(_lane_objectives.get(_lane_key(team_id, lane), ""))

func set_lane_configured(team_id: int, lane: String, configured: bool) -> void:
	_configured_lanes[_lane_key(team_id, lane)] = configured

func lane_is_configured(team_id: int, lane: String) -> bool:
	return bool(_configured_lanes.get(_lane_key(team_id, lane), false))

func _lane_key(team_id: int, lane: String) -> String:
	return "%d|%s" % [team_id, lane]
