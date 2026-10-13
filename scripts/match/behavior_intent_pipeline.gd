class_name BehaviorIntentPipeline
extends RefCounted
## Phase-2 dark-launch pipeline. No legacy actor is registered for execution.

var _queued_facts: Array[BehaviorFact] = []
var active_facts: Array[BehaviorFact] = []
var executor := IntentExecutor.new()

func queue_fact(fact: BehaviorFact) -> void:
	if fact != null: _queued_facts.append(fact)

func begin_tick(tick: int, entities: Dictionary, visibility: Callable = Callable()) -> BehaviorWorldSnapshot:
	active_facts.clear()
	for fact in _queued_facts:
		if fact.is_active(tick): active_facts.append(fact)
	_queued_facts = active_facts.duplicate()
	var snapshot := BehaviorWorldSnapshot.new(tick, active_facts)
	for actor_id in entities.keys():
		var info: Dictionary = entities[actor_id]
		var actor: MapUnit = info.get("actor", null)
		if actor == null: continue
		var visible_ids := PackedStringArray()
		if visibility.is_valid():
			for candidate_id in entities.keys():
				var candidate: MapUnit = entities[candidate_id].get("actor", null)
				if candidate != null and candidate.runtime.team_id != actor.runtime.team_id and visibility.call(actor, candidate): visible_ids.append(candidate_id)
		snapshot.add_actor(BehaviorActorSnapshot.new(actor_id, actor.runtime.team_id, actor.runtime.alive, info.get("kind", ""), actor.position, actor.runtime.stats.collision_radius, actor.runtime.target_id, visible_ids))
	executor.begin_tick(tick)
	return snapshot

## Controllers are deliberately absent until their individual migration phase.
func decide(_snapshot: BehaviorWorldSnapshot) -> Array[BehaviorIntent]:
	return []

func apply_intents(intents: Array[BehaviorIntent], snapshot: BehaviorWorldSnapshot, entities: Dictionary, objectives: ObjectiveRegistry) -> void:
	for intent in intents: executor.apply(intent, snapshot, entities, objectives)
