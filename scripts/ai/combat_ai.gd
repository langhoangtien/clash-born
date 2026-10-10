class_name CombatAI
extends RefCounted

enum Mode { PASSIVE, NEAREST, LOWEST_HP, HIGHEST_DAMAGE }

static func select_target(source: UnitRuntimeState, units: Array[UnitRuntimeState]) -> UnitRuntimeState:
	if source.ai_mode == Mode.PASSIVE:
		return null
	var best: UnitRuntimeState
	var best_score := INF
	for candidate in units:
		if not candidate.alive or candidate.team_id == source.team_id:
			continue
		var score := source.position.distance_squared_to(candidate.position)
		if source.ai_mode == Mode.LOWEST_HP: score = candidate.current_hp
		elif source.ai_mode == Mode.HIGHEST_DAMAGE:
			score = -(candidate.stats.physical_damage + candidate.stats.magic_damage + candidate.stats.pure_damage) * candidate.stats.attack_speed
		if score < best_score or (is_equal_approx(score, best_score) and (best == null or candidate.unit_id < best.unit_id)):
			best = candidate
			best_score = score
	return best

static func move_units(units: Array[UnitRuntimeState], balance: BalanceSettings) -> void:
	var positions: Dictionary = {}
	for unit in units:
		var next := unit.position
		var target := select_target(unit, units)
		if unit.ai_enabled and unit.can_move() and unit.casting.is_empty() and target != null:
			var delta := target.position - unit.position
			var distance := delta.length()
			var desired_range := unit.attack_range()
			var target_radius: float = target.stats.collision_radius
			for ability in unit.abilities:
				if ability != null and unit.current_tick >= unit.ability_ready_ticks.get(ability.id, 0) and unit.current_mana >= ability.mana_cost:
					desired_range = unit.cast_range(ability)
					target_radius = target.stats.collision_radius if ability.target_type == AbilityData.TargetType.ENEMY else 0.0
					break
			var stop_distance: float = desired_range + unit.stats.collision_radius + target_radius
			var travel := minf(unit.movement_speed(balance) * SimulationClock.TICK_SECONDS, maxf(0, distance - stop_distance))
			if distance > 0: next += delta / distance * travel
		positions[unit.unit_id] = next
	# Two stable separation passes; stunned/passive units are never displaced.
	for pass_index in range(2):
		for left in range(units.size()):
			for right in range(left + 1, units.size()):
				var a := units[left]
				var b := units[right]
				if not a.alive or not b.alive: continue
				var delta: Vector2 = positions[b.unit_id] - positions[a.unit_id]
				var distance := delta.length()
				var radii: float = a.stats.collision_radius + b.stats.collision_radius
				if distance >= radii: continue
				var direction := delta / distance if distance > 0.000001 else Vector2.RIGHT
				var overlap := radii - distance
				var a_moves := a.ai_enabled and a.can_move() and a.ai_mode != Mode.PASSIVE and a.casting.is_empty()
				var b_moves := b.ai_enabled and b.can_move() and b.ai_mode != Mode.PASSIVE and b.casting.is_empty()
				if a_moves: positions[a.unit_id] -= direction * overlap * (0.5 if b_moves else 1.0)
				if b_moves: positions[b.unit_id] += direction * overlap * (0.5 if a_moves else 1.0)
	for unit in units:
		var point: Vector2 = positions[unit.unit_id]
		var radius: float = unit.stats.collision_radius
		unit.position = Vector2(clampf(point.x, radius, 1600 - radius), clampf(point.y, radius, 900 - radius)) if unit.ai_enabled else unit.position
