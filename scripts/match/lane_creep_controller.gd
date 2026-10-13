class_name LaneCreepController
extends RefCounted
## Contract 5 controller. It decides only; IntentExecutor owns target/path writes.

func decide(snapshot: BehaviorWorldSnapshot, memory: LaneCreepMemory, settings: MatchSettings) -> BehaviorIntent:
	var actor := snapshot.actor(memory.actor_id)
	if actor == null or not actor.alive: return BehaviorIntent.new(memory.actor_id, "IDLE", "", Vector2.ZERO, false, snapshot.tick, "DEAD")
	_consume_facts(snapshot, actor, memory, settings)
	if not snapshot.lane_is_configured(actor.team_id, memory.lane):
		memory.state = "CONFIG_ERROR"
		return BehaviorIntent.new(actor.actor_id, memory.state, "", Vector2.ZERO, false, snapshot.tick, "CONFIG_ERROR")
	var retaliation := _retaliation_target(snapshot, actor, memory, settings)
	if retaliation != null:
		memory.state = "HERO_RETALIATE"
		return _combat_intent(snapshot, actor, retaliation, memory.state, "DIRECT_HERO_DAMAGE")
	var current := snapshot.actor(actor.current_target_id)
	if _is_lane_creep_target(actor, current, memory, settings):
		memory.return_required = false
		memory.state = "LANE_COMBAT"
		return _combat_intent(snapshot, actor, current, memory.state, "KEEP_LANE_TARGET")
	if _is_lane_objective_target(snapshot, actor, current, memory, settings):
		memory.return_required = false
		memory.state = "STRUCTURE_SIEGE"
		return _combat_intent(snapshot, actor, current, memory.state, "KEEP_LANE_OBJECTIVE")
	var creep_target := _nearest_lane_creep(snapshot, actor, memory, settings)
	if creep_target != null:
		memory.return_required = false
		memory.state = "LANE_COMBAT"
		return _combat_intent(snapshot, actor, creep_target, memory.state, "LANE_CREEP")
	var objective_id := snapshot.next_lane_objective_id(actor.team_id, memory.lane)
	if not objective_id.is_empty():
		var structure := snapshot.actor(objective_id)
		if structure != null and actor.edge_distance_to(structure) <= settings.creep_detection_range:
			memory.return_required = false
			memory.state = "STRUCTURE_SIEGE"
			return _combat_intent(snapshot, actor, structure, memory.state, "NEXT_LANE_OBJECTIVE")
	memory.state = "RETURN_TO_LANE" if memory.return_required else "LANE_ADVANCE"
	return _waypoint_intent(snapshot, actor, memory)

func _consume_facts(snapshot: BehaviorWorldSnapshot, actor: BehaviorActorSnapshot, memory: LaneCreepMemory, settings: MatchSettings) -> void:
	for fact in snapshot.facts:
		if fact.kind == BehaviorFact.Kind.TARGET_INVALID and fact.source_id == actor.actor_id:
			memory.return_required = true
			memory.retaliation_target_id = ""
		if fact.kind != BehaviorFact.Kind.HERO_DAMAGE: continue
		var aggressor := snapshot.actor(fact.source_id)
		var victim := snapshot.actor(fact.target_id)
		if aggressor == null or victim == null or aggressor.kind != "hero" or victim.kind != "hero": continue
		if aggressor.team_id == actor.team_id or victim.team_id != actor.team_id or victim.lane != memory.lane: continue
		if actor.edge_distance_to(victim) > settings.creep_hero_protection_range: continue
		memory.retaliation_target_id = aggressor.actor_id
		memory.retaliation_origin = actor.position
		memory.retaliation_expiry_tick = snapshot.tick + settings.creep_hero_aggro_ticks

func _retaliation_target(snapshot: BehaviorWorldSnapshot, actor: BehaviorActorSnapshot, memory: LaneCreepMemory, settings: MatchSettings) -> BehaviorActorSnapshot:
	if memory.retaliation_target_id.is_empty(): return null
	var target := snapshot.actor(memory.retaliation_target_id)
	if target == null or not target.alive or snapshot.tick > memory.retaliation_expiry_tick or target.team_id == actor.team_id or target.lane != memory.lane or actor.position.distance_to(memory.retaliation_origin) > settings.creep_hero_leash_range or target.position.distance_to(memory.retaliation_origin) > settings.creep_hero_leash_range:
		memory.retaliation_target_id = ""
		memory.return_required = true
		return null
	return target

func _is_lane_creep_target(actor: BehaviorActorSnapshot, target: BehaviorActorSnapshot, memory: LaneCreepMemory, settings: MatchSettings) -> bool:
	return target != null and target.alive and target.kind == "creep" and not target.neutral and target.team_id != actor.team_id and target.lane == memory.lane and actor.edge_distance_to(target) <= settings.creep_chase_limit

func _is_lane_objective_target(snapshot: BehaviorWorldSnapshot, actor: BehaviorActorSnapshot, target: BehaviorActorSnapshot, memory: LaneCreepMemory, settings: MatchSettings) -> bool:
	return target != null and target.kind == "tower" and target.actor_id == snapshot.next_lane_objective_id(actor.team_id, memory.lane) and target.team_id != actor.team_id and actor.edge_distance_to(target) <= settings.creep_chase_limit

func _nearest_lane_creep(snapshot: BehaviorWorldSnapshot, actor: BehaviorActorSnapshot, memory: LaneCreepMemory, settings: MatchSettings) -> BehaviorActorSnapshot:
	var best: BehaviorActorSnapshot
	var best_distance := INF
	for candidate in snapshot.actors():
		if not _is_lane_creep_target(actor, candidate, memory, settings) or not actor.can_see(candidate.actor_id): continue
		var distance := actor.edge_distance_to(candidate)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (best == null or candidate.actor_id < best.actor_id)):
			best = candidate
			best_distance = distance
	return best

func _combat_intent(snapshot: BehaviorWorldSnapshot, actor: BehaviorActorSnapshot, target: BehaviorActorSnapshot, state: String, reason: String) -> BehaviorIntent:
	var move := actor.edge_distance_to(target) > actor.attack_range
	return BehaviorIntent.new(actor.actor_id, state, target.actor_id, target.position, move, snapshot.tick + 1, reason)

func _waypoint_intent(snapshot: BehaviorWorldSnapshot, actor: BehaviorActorSnapshot, memory: LaneCreepMemory) -> BehaviorIntent:
	var closest := INF
	for index in range(memory.route_index, memory.route.size()):
		var distance := actor.position.distance_to(memory.route[index])
		if distance < closest:
			closest = distance
			memory.route_index = index
	while memory.route_index < memory.route.size() and actor.position.distance_to(memory.route[memory.route_index]) < 8.0: memory.route_index += 1
	if memory.route_index >= memory.route.size(): return BehaviorIntent.new(actor.actor_id, memory.state, "", Vector2.ZERO, false, snapshot.tick + 1, "ROUTE_COMPLETE")
	return BehaviorIntent.new(actor.actor_id, memory.state, "", memory.route[memory.route_index], true, snapshot.tick + 1, "FORWARD_WAYPOINT")
