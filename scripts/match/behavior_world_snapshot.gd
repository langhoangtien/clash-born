class_name BehaviorWorldSnapshot
extends RefCounted
## Read-only per-tick world view. Controllers must not access live actors.

var tick: int
var facts: Array[BehaviorFact] = []
var _actors: Dictionary = {} # String -> BehaviorActorSnapshot; internal index only.

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
