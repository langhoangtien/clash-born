extends RefCounted
## Sole decision and movement owner for enemy hero bots.

func choose(host: Node, info: Dictionary, tick: int) -> MapUnit:
	var actor: MapUnit = info.actor
	var lane: String = info.get("assigned_lane", "MID")
	if info.get("ai_state", "") == "FOUNTAIN_RECOVER":
		if not (host.in_fountain(actor.runtime) and actor.runtime.current_hp >= actor.runtime.stats.max_hp * host.settings.bot_recover_hp_fraction): return null
		host._set_bot_state(info, "RALLY", tick, "recovered")
	if info.get("ai_state", "") == "EXIT_TOWER_RANGE":
		if host._tower_targeting_unit(actor) != null: return null
		host._set_bot_state(info, "RALLY", tick, "outside-tower-range")
	if actor.runtime.current_hp <= actor.runtime.stats.max_hp * host.settings.bot_retreat_hp_fraction:
		host._set_bot_state(info, "FOUNTAIN_RECOVER", tick, "hp-below-retreat-threshold")
		return null
	var attacking_tower: MapUnit = host._tower_targeting_unit(actor)
	if attacking_tower != null:
		info.tower_threat_id = attacking_tower.runtime.unit_id
		host._set_bot_state(info, "EXIT_TOWER_RANGE", tick, "enemy-tower-targeting-hero")
		return null
	var base_intruder: MapUnit = host._bot_base_intruder(info, lane)
	if base_intruder != null:
		host._set_bot_state(info, "DEFEND_BASE", tick, "hostile-lane-creep-near-fountain")
		info.ai_last_target_tick = tick
		host._persist_entity_info(info)
		return base_intruder
	var creep_target: MapUnit = host._choose_target(info, ["creep"], host.settings.bot_chase_range, true, false, lane)
	if creep_target != null:
		host._set_bot_state(info, "LANE_FIGHT", tick, "enemy-lane-creep-in-range")
		info.ai_last_target_tick = tick
		host._persist_entity_info(info)
		return creep_target
	var player_distance: float = actor.position.distance_to(host.player.position)
	if host.player.runtime.alive and player_distance <= host.settings.bot_chase_range and not host.is_inside_enemy_tower_range(host.player.position, actor.runtime.team_id):
		var hero_target: MapUnit = host._choose_target(info, ["hero"], host.settings.bot_chase_range, true, false, "", true)
		if hero_target != null:
			host._set_bot_state(info, "HERO_FIGHT", tick, "enemy-hero-in-safe-chase-range")
			info.ai_last_target_tick = tick
			host._persist_entity_info(info)
			return hero_target
	var tower: MapUnit = host.get_next_attackable_structure(actor.runtime.team_id, lane)
	if tower != null and host._tower_has_attacking_creep_cover(tower, actor.runtime.team_id) and actor.position.distance_to(tower.position) <= host.settings.bot_chase_range:
		host._set_bot_state(info, "SIEGE", tick, "allied-creep-cover")
		return tower
	host._set_bot_state(info, "RALLY", tick, "no-local-combat-target")
	return null

func drive(host: Node, info: Dictionary, target: MapUnit, tick: int) -> void:
	var actor: MapUnit = info.actor
	if info.ai_state == "FOUNTAIN_RECOVER":
		if not host.in_fountain(actor.runtime): host._issue_ai_move(info, host.layout.fountain_point(actor.runtime.team_id), "retreat-fountain", tick)
		else: actor.stop()
		return
	if info.ai_state == "EXIT_TOWER_RANGE":
		var tower_id: String = info.get("tower_threat_id", "")
		if host.entities.has(tower_id): host._issue_ai_move(info, host._tower_escape_point(actor, host.entities[tower_id].actor), "tower-range-escape", tick)
		else: actor.stop()
		return
	if target != null:
		host._drive_target(info, target, tick)
		return
	var lane: String = info.get("assigned_lane", "MID")
	var anchor: Vector2 = host.get_defensive_anchor(actor.runtime.team_id, lane)
	var frontline: MapUnit = host._bot_frontline(actor.runtime.team_id, lane)
	var destination: Vector2 = anchor
	var source: String = "defensive-anchor"
	if frontline != null:
		destination = host._lane_point_at_progress(lane, actor.runtime.team_id, host._lane_progress(frontline.position, lane, actor.runtime.team_id) - host.settings.bot_frontline_trail_distance)
		source = "frontline-rally"
	else:
		var next_tower: MapUnit = host.get_next_attackable_structure(actor.runtime.team_id, lane)
		if next_tower != null:
			destination = host._tower_escape_point(actor, next_tower)
			source = "lane-push-rally"
	if actor.position.distance_to(destination) > 80.0: host._issue_ai_move(info, destination, source, tick)
	else: actor.stop()
