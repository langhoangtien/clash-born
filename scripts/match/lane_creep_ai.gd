extends RefCounted
## Sole decision and movement owner for lane creeps and siege catapults.

func choose(host: Node, info: Dictionary, tick: int) -> MapUnit:
	var actor: MapUnit = info.actor
	var old_target_id: String = actor.runtime.target_id
	var retaliation_id: String = info.get("retaliation_target_id", "")
	if not retaliation_id.is_empty() and host.entities.has(retaliation_id):
		var retaliation_target: MapUnit = host.entities[retaliation_id].actor
		var origin: Vector2 = info.get("creep_chase_origin", actor.position)
		if retaliation_target.runtime.alive and retaliation_target.runtime.team_id != actor.runtime.team_id and tick <= int(info.get("hero_aggro_until", 0)) and actor.position.distance_to(origin) <= host.settings.creep_hero_leash_range and actor.runtime.distance_to_unit(retaliation_target.runtime) <= host.settings.creep_hero_leash_range:
			info.creep_state = "HERO_RETALIATE"
			host._persist_entity_info(info)
			return retaliation_target
	info.retaliation_target_id = ""
	info.hero_aggro_until = 0
	var current: MapUnit = host._current_target(actor)
	if current != null:
		var current_info: Dictionary = host.entities[current.runtime.unit_id]
		var valid_target: bool = current_info.kind == "creep" and not current_info.get("neutral", false) and current_info.lane == info.lane and actor.runtime.distance_to_unit(current.runtime) <= host.settings.creep_chase_limit
		if current_info.kind == "tower": valid_target = current == host.get_next_attackable_structure(actor.runtime.team_id, info.lane) and actor.runtime.distance_to_unit(current.runtime) <= host.settings.creep_chase_limit
		if valid_target:
			info.creep_state = "LANE_COMBAT" if current_info.kind == "creep" else "STRUCTURE_SIEGE"
			host._persist_entity_info(info)
			return current
		actor.runtime.target_id = ""
		info.creep_state = "RETURN_TO_LANE"
	if not host._structure_chain_configured(actor.runtime.team_id, info.lane):
		info.creep_config_error = true
		info.creep_state = "CONFIG_ERROR"
		host._trace_ai(info, "STUCK", "missing structure chain team=%d lane=%s; movement stopped safely" % [actor.runtime.team_id, info.lane])
		host._persist_entity_info(info)
		return null
	info.creep_config_error = false
	var target: MapUnit = host._choose_target(info, ["creep"], host.settings.creep_detection_range, true, false, info.lane)
	if target == null:
		var structure: MapUnit = host.get_next_attackable_structure(actor.runtime.team_id, info.lane)
		if structure != null and actor.runtime.distance_to_unit(structure.runtime) <= host.settings.creep_detection_range: target = structure
	if target != null:
		info.creep_state = "LANE_COMBAT" if host.entities[target.runtime.unit_id].kind == "creep" else "STRUCTURE_SIEGE"
	else:
		info.creep_state = "LANE_ADVANCE"
	var new_target_id := target.runtime.unit_id if target != null else ""
	if new_target_id != old_target_id:
		var target_kind: String = host.entities[new_target_id].kind if host.entities.has(new_target_id) else "none"
		var distance := actor.runtime.distance_to_unit(target.runtime) if target != null else -1.0
		host._trace_ai(info, "TARGET", "state=%s team=%d lane=%s waypoint=%d old=%s new=%s kind=%s distance=%.1f structures=[%s]" % [info.creep_state, actor.runtime.team_id, info.lane, int(info.route_index), old_target_id, new_target_id, target_kind, distance, host._structure_candidate_report(actor.runtime.team_id, info.lane)])
	host._persist_entity_info(info)
	return target

func drive(host: Node, info: Dictionary, target: MapUnit, tick: int) -> void:
	var actor: MapUnit = info.actor
	if info.get("creep_config_error", false):
		actor.runtime.target_id = ""
		actor.stop()
		host._persist_entity_info(info)
		return
	if target != null:
		actor.movement_speed_multiplier = 1.0
		actor.runtime.target_id = target.runtime.unit_id
		if actor.runtime.distance_to_unit(target.runtime) <= actor.runtime.attack_range():
			actor.stop()
		else:
			var target_moved := not actor.path.is_empty() and actor.path[-1].distance_to(target.position) > 96.0
			if actor.path.is_empty() or (target_moved and tick % 30 == info.ai_phase): host._issue_ai_move(info, target.position, "lane-target:" + target.runtime.unit_id, tick)
		host._persist_entity_info(info)
		return
	info.creep_state = "LANE_ADVANCE" if info.get("creep_state", "") != "RETURN_TO_LANE" else "RETURN_TO_LANE"
	actor.runtime.target_id = ""
	actor.movement_speed_multiplier = float(info.get("travel_speed_multiplier", 1.0))
	var route: PackedVector2Array = info.route
	var closest := INF
	for index in range(info.route_index, route.size()):
		var distance := actor.position.distance_to(route[index])
		if distance < closest:
			closest = distance
			info.route_index = index
	while info.route_index < route.size() and actor.position.distance_to(route[info.route_index]) < 8.0: info.route_index += 1
	if info.route_index < route.size():
		var waypoint := route[info.route_index]
		if actor.path.is_empty() or actor.path[-1].distance_to(waypoint) > 0.1: host._issue_ai_move(info, waypoint, "lane-waypoint", tick)
	else:
		actor.stop()
	host._persist_entity_info(info)
