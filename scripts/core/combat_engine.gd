class_name CombatEngine
extends RefCounted
## Fixed-step, seeded simulation. No scene, input, rendering or wall-clock state.

var balance: BalanceSettings
var units: Array[UnitRuntimeState] = []
var tick_count: int = 0
var finished: bool = false
var winner_team: int = -1
var finish_reason: String = ""
var rng := RandomNumberGenerator.new()
var random_seed: int = 1
var metrics := CombatMetrics.new()
var _commands: Array[Dictionary] = []

func _init(settings: BalanceSettings) -> void:
	balance = settings

## Compatibility entry point for isolated formula/duel tests without AI.
func reset(blue: UnitStats, red: UnitStats, blue_position: Vector2, red_position: Vector2, seed_value: int = 1, blue_items: Array[EquipmentData] = [], red_items: Array[EquipmentData] = []) -> void:
	reset_scenario([
		{"id": "blue_01", "team": 0, "source": blue, "position": blue_position, "equipment": blue_items, "ai": false},
		{"id": "red_01", "team": 1, "source": red, "position": red_position, "equipment": red_items, "ai": false},
	], seed_value)

func reset_scenario(entries: Array[Dictionary], seed_value: int = 1) -> bool:
	var counts := [0, 0]
	var ids: Array[String] = []
	for entry in entries:
		if not entry.has("id") or not entry.has("source") or not entry.source is UnitStats or entry.get("team", -1) not in [0, 1]: return false
		if entry.id.is_empty() or entry.id in ids: return false
		ids.append(entry.id)
		counts[entry.team] += 1
	if counts[0] not in range(1, 6) or counts[1] not in range(1, 6): return false
	units.clear()
	for entry in entries:
		var items: Array[EquipmentData] = []
		items.assign(entry.get("equipment", []))
		var unit := UnitRuntimeState.new(entry.id, entry.team, entry.get("position", Vector2.ZERO), entry.source, balance, items)
		unit.ai_enabled = entry.get("ai", true)
		units.append(unit)
	tick_count = 0
	finished = false
	winner_team = -1
	finish_reason = ""
	random_seed = seed_value
	rng.seed = seed_value
	_commands.clear()
	metrics.initialize(units)
	return true

func get_unit(id: String) -> UnitRuntimeState:
	for unit in units:
		if unit.unit_id == id: return unit
	return null

## Debug command, intentionally bypasses ability cost/cast rules.
func queue_effect(source_id: String, target_id: String, kind: StatusEffect.Kind, duration: float, magnitude: float, instance_id: String) -> void:
	_commands.append({"source": source_id, "target": target_id, "kind": kind, "duration": duration, "magnitude": magnitude, "id": instance_id})

func _apply_effect(command: Dictionary, events: Array[Dictionary]) -> void:
	var unit := get_unit(command.target)
	if unit == null or not unit.alive or command.duration <= 0 or command.id.is_empty() or command.kind not in StatusEffect.Kind.values(): return
	var effect := StatusEffect.new()
	effect.instance_id = command.id
	effect.source_unit_id = command.source
	effect.target_unit_id = command.target
	effect.kind = command.kind
	effect.magnitude = command.magnitude
	var duration: float = command.duration * (1 - unit.stats.status_resistance) if effect.kind == StatusEffect.Kind.STUN else command.duration
	effect.duration_ticks = maxi(1, ceili(duration * SimulationClock.TICKS_PER_SECOND - 0.000000001))
	effect.expires_at_tick = tick_count + effect.duration_ticks
	unit.effects.apply(effect)
	var applied := _event("effect_applied", effect.source_unit_id, unit.unit_id)
	applied.effect_id = effect.instance_id
	applied.effect_kind = effect.kind
	applied.duration_ticks = effect.duration_ticks
	applied.magnitude = effect.magnitude
	events.append(applied)

func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished or units.is_empty(): return events
	tick_count += 1
	# Stable order: expire -> debug commands -> regen -> targets/movement ->
	# casting/effects -> collect attacks -> metrics stun tick -> damage -> deaths.
	for unit in units:
		unit.current_tick = tick_count
		for effect in unit.effects.expire(tick_count):
			var expired := _event("effect_expired", effect.source_unit_id, unit.unit_id)
			expired.effect_id = effect.instance_id
			expired.effect_kind = effect.kind
			events.append(expired)
	for command in _commands: _apply_effect(command, events)
	_commands.clear()
	for unit in units:
		if not unit.alive: continue
		var before := unit.current_hp
		unit.current_hp = minf(unit.stats.max_hp, unit.current_hp + unit.stats.hp_regen * SimulationClock.TICK_SECONDS)
		unit.current_mana = minf(unit.stats.max_mana, unit.current_mana + unit.stats.mana_regen * SimulationClock.TICK_SECONDS)
		metrics.by_unit[unit.unit_id].healing_received += unit.current_hp - before
		var target := CombatAI.select_target(unit, units)
		if not unit.ai_enabled:
			for candidate in units:
				if candidate.alive and candidate.team_id != unit.team_id:
					target = candidate
					break
		unit.target_id = target.unit_id if target != null else ""
	CombatAI.move_units(units, balance)
	_resolve_abilities(events)
	var pending: Array[Dictionary] = []
	for source in units:
		var target := get_unit(source.target_id)
		if not source.can_act() or not source.casting.is_empty() or target == null or not target.alive or (source.ai_enabled and source.ai_mode == CombatAI.Mode.PASSIVE): continue
		if tick_count + 0.000000001 < source.next_attack_tick or source.position.distance_to(target.position) > source.stats.attack_range + 0.000001: continue
		if tick_count - source.next_attack_tick >= 1.0: source.next_attack_tick = tick_count
		source.next_attack_tick += SimulationClock.TICKS_PER_SECOND / source.stats.attack_speed
		var hit := HitCalculator.resolve(source.stats, target.stats, rng, balance)
		var attack := _event("attack", source.unit_id, target.unit_id)
		attack.can_miss = source.stats.attacks_can_miss
		attack.can_crit = source.stats.attacks_can_crit
		attack.missed = hit.missed
		attack.critical = hit.critical
		events.append(attack)
		if hit.missed:
			events.append(_event("miss", source.unit_id, target.unit_id))
			continue
		for damage_type in range(3):
			var raw: float = source.stats[["physical_damage", "magic_damage", "pure_damage"][damage_type]]
			if raw <= 0: continue
			var damage := _event("damage", source.unit_id, target.unit_id)
			damage.damage_type = damage_type
			damage.critical = hit.critical and (source.stats.pure_attacks_can_crit or damage_type != DamageCalculator.DamageType.PURE)
			damage.raw_damage = raw * source.stats.critical_multiplier if damage.critical else raw
			var physical := DamageCalculator.effective_armor(target.physical_armor(), source.stats.armor_reduction, source.stats.physical_armor_penetration)
			var magical := DamageCalculator.effective_armor(target.stats.magic_armor, source.stats.magic_armor_reduction)
			damage.final_damage = DamageCalculator.calculate(damage.raw_damage, damage_type, physical, magical, balance)
			pending.append(damage)
	metrics.record_tick(units, tick_count)
	for damage in pending:
		var target := get_unit(damage.target_unit_id)
		damage.applied_damage = minf(target.current_hp, damage.final_damage)
		target.current_hp = maxf(0, target.current_hp - damage.final_damage)
		events.append(damage)
	var teams_alive := [false, false]
	for unit in units:
		if unit.alive and unit.current_hp <= 0:
			unit.alive = false
			unit.casting.clear()
			events.append(_event("death", "", unit.unit_id))
		if unit.alive: teams_alive[unit.team_id] = true
	if not teams_alive[0] or not teams_alive[1]:
		finished = true
		winner_team = 0 if teams_alive[0] else (1 if teams_alive[1] else -1)
		finish_reason = "elimination"
	elif tick_count >= ceili(balance.battle_time_limit_seconds * SimulationClock.TICKS_PER_SECOND):
		finished = true
		finish_reason = "time_limit"
	if finished:
		var result_event := _event("finished", "", "")
		result_event.winner_team = winner_team
		result_event.reason = finish_reason
		events.append(result_event)
	metrics.consume(events)
	return events

func _resolve_abilities(events: Array[Dictionary]) -> void:
	var completed: Array[Dictionary] = []
	for source in units:
		if not source.alive: continue
		if not source.casting.is_empty() and not source.can_cast():
			events.append(_event("cast_interrupted", source.unit_id, source.casting.target))
			source.casting.clear()
		if not source.ai_enabled or source.ai_mode == CombatAI.Mode.PASSIVE or not source.can_cast(): continue
		if source.casting.is_empty():
			var target := get_unit(source.target_id)
			if target == null or not target.alive: continue
			for index in range(source.abilities.size()):
				var ability := source.abilities[index]
				if ability == null or ability.id.is_empty() or tick_count < source.ability_ready_ticks.get(ability.id, 0) or source.current_mana < ability.mana_cost: continue
				if source.position.distance_to(target.position) > ability.cast_range: continue
				source.current_mana -= maxf(0, ability.mana_cost)
				source.ability_ready_ticks[ability.id] = tick_count + maxi(1, ceili(ability.cooldown * SimulationClock.TICKS_PER_SECOND))
				source.casting = {"index": index, "target": target.unit_id, "complete_tick": tick_count + maxi(0, ceili(ability.cast_time * SimulationClock.TICKS_PER_SECOND))}
				var cast := _event("cast", source.unit_id, target.unit_id)
				cast.ability_id = ability.id
				cast.ability_name = ability.display_name
				cast.mana_cost = ability.mana_cost
				events.append(cast)
				break
		if not source.casting.is_empty() and source.casting.complete_tick <= tick_count:
			completed.append({"source": source, "target": source.casting.target, "ability": source.abilities[source.casting.index]})
			source.casting.clear()
	for cast in completed:
		var target := get_unit(cast.target)
		if target == null or not target.alive or cast.source.position.distance_to(target.position) > cast.ability.cast_range:
			events.append(_event("cast_interrupted", cast.source.unit_id, cast.target))
			continue
		for index in range(cast.ability.effects.size()):
			var effect: AbilityEffectData = cast.ability.effects[index]
			_apply_effect({"source": cast.source.unit_id, "target": target.unit_id, "kind": effect.kind, "duration": effect.duration, "magnitude": effect.magnitude, "id": "%s_%d" % [cast.ability.id, index]}, events)

func result() -> Dictionary:
	return {"winner_team": winner_team, "duration": tick_count * SimulationClock.TICK_SECONDS, "reason": finish_reason, "finished": finished, "units": metrics.by_unit.duplicate(true)}

func _event(kind: String, source_id: String, target_id: String) -> Dictionary:
	return {"kind": kind, "tick": tick_count, "source_unit_id": source_id, "target_unit_id": target_id}
