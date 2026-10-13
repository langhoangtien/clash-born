class_name IntentExecutor
extends RefCounted
## The exclusive target/path writer for actors migrated to the intent pipeline.

var _applied_actor_ids: Dictionary = {}
var _last_destinations: Dictionary = {}
var traces: Array[String] = []
var failure_facts: Array[BehaviorFact] = []
var _tick: int = -1

func begin_tick(tick: int) -> void:
	_tick = tick
	_applied_actor_ids.clear()
	traces.clear()
	failure_facts.clear()

func apply(intent: BehaviorIntent, snapshot: BehaviorWorldSnapshot, entities: Dictionary, objectives: ObjectiveRegistry) -> bool:
	if _tick != snapshot.tick or intent == null or intent.actor_id.is_empty() or _applied_actor_ids.has(intent.actor_id): return false
	_applied_actor_ids[intent.actor_id] = true
	var source_snapshot := snapshot.actor(intent.actor_id)
	var actor: MapUnit = _live_actor(intent.actor_id, entities)
	if source_snapshot == null or actor == null or not source_snapshot.alive or intent.is_expired(snapshot.tick):
		_cancel(actor, intent, "EXPIRED_OR_MISSING", "")
		return false
	var old_target: String = actor.runtime.target_id
	var valid_target := intent.target_id.is_empty() or _is_legal_target(source_snapshot, intent.target_id, snapshot, entities, objectives)
	if not valid_target:
		_cancel(actor, intent, "INVALID_TARGET", old_target)
		return false
	actor.runtime.target_id = intent.target_id
	if intent.has_destination:
		var previous: Vector2 = _last_destinations.get(intent.actor_id, Vector2.INF)
		if previous.distance_to(intent.destination) > 0.01:
			if not actor.go_to(intent.destination):
				_cancel(actor, intent, "UNREACHABLE", old_target)
				failure_facts.append(BehaviorFact.new(BehaviorFact.Kind.TARGET_INVALID, intent.actor_id, intent.target_id, snapshot.tick, snapshot.tick + 1, "UNREACHABLE"))
				return false
			_last_destinations[intent.actor_id] = intent.destination
	else:
		actor.stop()
	_trace(intent, old_target, actor.runtime.target_id, intent.destination)
	return true

func _is_legal_target(source: BehaviorActorSnapshot, target_id: String, snapshot: BehaviorWorldSnapshot, entities: Dictionary, objectives: ObjectiveRegistry) -> bool:
	var target_snapshot := snapshot.actor(target_id)
	var target: MapUnit = _live_actor(target_id, entities)
	if target_snapshot == null or target == null or not target_snapshot.alive or target_snapshot.team_id == source.team_id: return false
	if not source.can_see(target_id): return false
	var target_info: Dictionary = entities.get(target_id, {})
	if target_info.get("kind", "") == "tower": return objectives.is_attackable(target_info.get("semantic_id", ""), entities)
	if target_info.get("kind", "") == "core": return objectives.is_attackable("%s_core" % ("blue" if target_snapshot.team_id == 0 else "red"), entities)
	return true

func _live_actor(actor_id: String, entities: Dictionary) -> MapUnit:
	if not entities.has(actor_id): return null
	return entities[actor_id].get("actor", null)

func _cancel(actor, intent: BehaviorIntent, reason: String, old_target: String) -> void:
	if actor != null:
		actor.runtime.target_id = ""
		actor.stop()
	_trace(intent, old_target, "", actor.position if actor != null else Vector2.ZERO, reason)
	if reason == "INVALID_TARGET": failure_facts.append(BehaviorFact.new(BehaviorFact.Kind.TARGET_INVALID, intent.actor_id, intent.target_id, _tick, _tick + 1, reason))

func _trace(intent: BehaviorIntent, old_target: String, new_target: String, destination: Vector2, override_reason: String = "") -> void:
	var reason := override_reason if not override_reason.is_empty() else intent.reason
	traces.append("tick=%d actor_id=%s state=%s reason=%s old_target=%s new_target=%s destination=%s" % [_tick, intent.actor_id, intent.state, reason, old_target, new_target, str(destination)])
