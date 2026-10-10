class_name CombatEngine
extends RefCounted
## Fixed two-unit duel; seeded RNG, no scene nodes, AI, input or wall time.

var balance: BalanceSettings
var units: Array[UnitRuntimeState] = []
var tick_count: int = 0
var finished: bool = false
var winner_team: int = -1
var rng := RandomNumberGenerator.new()
var random_seed: int = 1
var _commands: Array[Dictionary] = []

func _init(settings: BalanceSettings) -> void:
	balance = settings

func reset(blue: UnitStats, red: UnitStats, blue_position: Vector2, red_position: Vector2, seed_value: int = 1) -> void:
	units = [
		UnitRuntimeState.new("blue_01", 0, blue_position, blue, balance),
		UnitRuntimeState.new("red_01", 1, red_position, red, balance),
	]
	tick_count = 0
	finished = false
	winner_team = -1
	random_seed = seed_value
	rng.seed = seed_value
	_commands.clear()

## Debug/simulation commands, not abilities: no mana cost, cooldown or casting.
func queue_effect(source_id: String, target_id: String, kind: StatusEffect.Kind, duration: float, magnitude: float, instance_id: String) -> void:
	_commands.append({"source": source_id, "target": target_id, "kind": kind, "duration": duration, "magnitude": magnitude, "id": instance_id})

func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished or units.size() != 2:
		return events
	tick_count += 1
	# Expire effects -> apply queued effects -> regenerate -> collect attacks
	# -> apply damage -> deaths/results. Commands execute at the next tick.
	for unit in units:
		unit.current_tick = tick_count
		for effect in unit.effects.expire(tick_count):
			var expired := _event("effect_expired", effect.source_unit_id, unit.unit_id)
			expired.effect_id = effect.instance_id
			expired.effect_kind = effect.kind
			events.append(expired)
	for command in _commands:
		for unit in units:
			if unit.unit_id != command.target or not unit.alive or command.duration <= 0 or command.id.is_empty() or command.kind not in StatusEffect.Kind.values():
				continue
			var effect := StatusEffect.new()
			effect.instance_id = command.id
			effect.source_unit_id = command.source
			effect.target_unit_id = command.target
			effect.kind = command.kind
			effect.magnitude = command.magnitude
			var duration: float = command.duration
			if effect.kind == StatusEffect.Kind.STUN:
				duration *= 1 - unit.stats.status_resistance
			effect.duration_ticks = maxi(1, ceili(duration * SimulationClock.TICKS_PER_SECOND - 0.000000001))
			effect.expires_at_tick = tick_count + effect.duration_ticks
			unit.effects.apply(effect)
			var applied := _event("effect_applied", effect.source_unit_id, unit.unit_id)
			applied.effect_id = effect.instance_id
			applied.effect_kind = effect.kind
			applied.duration_ticks = effect.duration_ticks
			applied.magnitude = effect.magnitude
			events.append(applied)
	_commands.clear()
	for unit in units:
		if unit.alive:
			unit.current_hp = minf(unit.stats.max_hp, unit.current_hp + unit.stats.hp_regen * SimulationClock.TICK_SECONDS)
			unit.current_mana = minf(unit.stats.max_mana, unit.current_mana + unit.stats.mana_regen * SimulationClock.TICK_SECONDS)
	var pending: Array[Dictionary] = []
	for index in range(2):
		var source := units[index]
		var target := units[1 - index]
		if not source.can_act() or not target.alive or tick_count + 0.000000001 < source.next_attack_tick:
			continue
		if source.position.distance_to(target.position) > source.stats.attack_range:
			continue
		# Keep fractional tick remainder; discard backlog after stun/out-of-range.
		if tick_count - source.next_attack_tick >= 1.0:
			source.next_attack_tick = tick_count
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
		var damage_keys := ["physical_damage", "magic_damage", "pure_damage"]
		for damage_type in range(3):
			var raw: float = source.stats[damage_keys[damage_type]]
			if raw <= 0.0:
				continue
			var damage := _event("damage", source.unit_id, target.unit_id)
			damage.damage_type = damage_type
			var eligible: bool = source.stats.pure_attacks_can_crit or damage_type != DamageCalculator.DamageType.PURE
			damage.critical = hit.critical and eligible
			damage.raw_damage = raw * source.stats.critical_multiplier if damage.critical else raw
			var physical_armor := DamageCalculator.effective_armor(target.physical_armor(), source.stats.armor_reduction, source.stats.physical_armor_penetration)
			var magic_armor := DamageCalculator.effective_armor(target.stats.magic_armor, source.stats.magic_armor_reduction)
			damage.final_damage = DamageCalculator.calculate(damage.raw_damage, damage_type, physical_armor, magic_armor, balance)
			damage.target_index = 1 - index
			pending.append(damage)
	for damage in pending:
		var target := units[damage.target_index]
		damage.applied_damage = minf(target.current_hp, damage.final_damage)
		target.current_hp = maxf(0.0, target.current_hp - damage.final_damage)
		damage.erase("target_index")
		events.append(damage)
	for unit in units:
		if unit.alive and unit.current_hp <= 0.0:
			unit.alive = false
			events.append(_event("death", "", unit.unit_id))
	if not units[0].alive or not units[1].alive:
		finished = true
		winner_team = 0 if units[0].alive else (1 if units[1].alive else -1)
		var result := _event("finished", "", "")
		result.winner_team = winner_team
		events.append(result)
	return events

func _event(kind: String, source_id: String, target_id: String) -> Dictionary:
	return {"kind": kind, "tick": tick_count, "source_unit_id": source_id, "target_unit_id": target_id}
