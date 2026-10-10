class_name CombatEngine
extends RefCounted
## Fixed two-unit duel; no scene nodes, AI, input, wall time or randomness.

var balance: BalanceSettings
var units: Array[UnitRuntimeState] = []
var tick_count: int = 0
var finished: bool = false
var winner_team: int = -1

func _init(settings: BalanceSettings) -> void:
	balance = settings

func reset(blue: UnitStats, red: UnitStats, blue_position: Vector2, red_position: Vector2) -> void:
	units = [
		UnitRuntimeState.new("blue_01", 0, blue_position, blue, balance),
		UnitRuntimeState.new("red_01", 1, red_position, red, balance),
	]
	tick_count = 0
	finished = false
	winner_team = -1

func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished or units.size() != 2:
		return events
	tick_count += 1
	# 1. Regenerate living units; 2. collect due attacks; 3. apply damage;
	# 4. process deaths and finish. Attacks collected together allow mutual kills.
	for unit in units:
		if unit.alive:
			unit.current_hp = minf(unit.stats.max_hp, unit.current_hp + unit.stats.hp_regen * SimulationClock.TICK_SECONDS)
			unit.current_mana = minf(unit.stats.max_mana, unit.current_mana + unit.stats.mana_regen * SimulationClock.TICK_SECONDS)
	var pending: Array[Dictionary] = []
	for index in range(2):
		var source := units[index]
		var target := units[1 - index]
		if not source.alive or not target.alive or tick_count < source.next_attack_tick:
			continue
		if source.position.distance_to(target.position) > source.stats.attack_range:
			continue
		source.next_attack_tick = tick_count + maxi(1, balance.basic_attack_interval_ticks)
		events.append(_event("attack", source.unit_id, target.unit_id))
		var damage_keys := ["physical_damage", "magic_damage", "pure_damage"]
		for damage_type in range(3):
			var raw: float = source.stats[damage_keys[damage_type]]
			if raw <= 0.0:
				continue
			var damage := _event("damage", source.unit_id, target.unit_id)
			damage.damage_type = damage_type
			damage.raw_damage = raw
			damage.final_damage = DamageCalculator.calculate(raw, damage_type, target.stats.physical_armor, target.stats.magic_armor, balance)
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
