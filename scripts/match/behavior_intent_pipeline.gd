class_name BehaviorIntentPipeline
extends RefCounted
## Phase-2 dark-launch pipeline. No legacy actor is registered for execution.

var _queued_facts: Array[BehaviorFact] = []
var active_facts: Array[BehaviorFact] = []
var executor := IntentExecutor.new()
var lane_creep_controller := LaneCreepController.new()
var lane_creep_memories: Dictionary = {} # String -> LaneCreepMemory

func queue_fact(fact: BehaviorFact) -> void:
	if fact != null: _queued_facts.append(fact)

func register_lane_creep(actor_id: String, lane: String, route: PackedVector2Array) -> void:
	lane_creep_memories[actor_id] = LaneCreepMemory.new(actor_id, lane, route)

func unregister_actor(actor_id: String) -> void:
	lane_creep_memories.erase(actor_id)

func begin_tick(tick: int, entities: Dictionary, visibility: Callable = Callable(), objectives: ObjectiveRegistry = null) -> BehaviorWorldSnapshot:
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
		snapshot.add_actor(BehaviorActorSnapshot.new(actor_id, actor.runtime.team_id, actor.runtime.alive, info.get("kind", ""), info.get("lane", ""), info.get("neutral", false), actor.position, actor.runtime.stats.collision_radius, actor.runtime.attack_range(), actor.runtime.target_id, visible_ids))
	if objectives != null:
		for team_id in [0, 1]:
			for lane in ["TOP", "MID", "BOT"]:
				snapshot.set_lane_configured(team_id, lane, objectives.lane_is_configured(team_id, lane))
				var objective := objectives.next_lane_objective(team_id, lane, entities)
				if objective != null: snapshot.set_lane_objective(team_id, lane, objective.runtime_id)
	executor.begin_tick(tick)
	return snapshot

func decide(snapshot: BehaviorWorldSnapshot, settings: MatchSettings) -> Array[BehaviorIntent]:
	var intents: Array[BehaviorIntent] = []
	var ids: Array[String] = []
	for actor_id in lane_creep_memories: ids.append(actor_id)
	ids.sort()
	for actor_id in ids:
		var memory: LaneCreepMemory = lane_creep_memories[actor_id]
		intents.append(lane_creep_controller.decide(snapshot, memory, settings))
	return intents

func apply_intents(intents: Array[BehaviorIntent], snapshot: BehaviorWorldSnapshot, entities: Dictionary, objectives: ObjectiveRegistry) -> void:
	for intent in intents: executor.apply(intent, snapshot, entities, objectives)
	for fact in executor.failure_facts: queue_fact(fact)
