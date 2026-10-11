class_name CombatMetrics
extends RefCounted

var by_unit: Dictionary = {}

func initialize(units: Array[UnitRuntimeState]) -> void:
	by_unit.clear()
	for unit in units:
		register_unit(unit)

func register_unit(unit: UnitRuntimeState) -> void:
	by_unit[unit.unit_id] = {"name": unit.display_name, "team": unit.team_id, "damage_dealt": 0.0, "damage_received": 0.0, "physical_damage": 0.0, "magic_damage": 0.0, "pure_damage": 0.0, "missed_attacks": 0, "critical_strikes": 0, "stun_duration_applied": 0.0, "time_stunned": 0.0, "healing_received": 0.0, "survival_time": 0.0}

func forget_unit(unit_id: String) -> void:
	by_unit.erase(unit_id)

func consume(events: Array[Dictionary]) -> void:
	for event in events:
		var source: Dictionary = by_unit.get(event.source_unit_id, {})
		var target: Dictionary = by_unit.get(event.target_unit_id, {})
		match event.kind:
			"damage":
				if not source.is_empty():
					source.damage_dealt += event.applied_damage
					source[["physical_damage", "magic_damage", "pure_damage"][event.damage_type]] += event.applied_damage
				if not target.is_empty():
					target.damage_received += event.applied_damage
			"miss":
				if not source.is_empty():
					source.missed_attacks += 1
			"attack":
				if event.critical and not source.is_empty():
					source.critical_strikes += 1
			"effect_applied":
				if event.effect_kind == StatusEffect.Kind.STUN and not source.is_empty():
					source.stun_duration_applied += event.duration_ticks * SimulationClock.TICK_SECONDS
			"death":
				if not target.is_empty():
					target.survival_time = event.tick * SimulationClock.TICK_SECONDS

func record_tick(units: Array[UnitRuntimeState], tick: int) -> void:
	for unit in units:
		if not by_unit.has(unit.unit_id): continue
		if unit.alive:
			by_unit[unit.unit_id].survival_time = tick * SimulationClock.TICK_SECONDS
			if unit.effects.is_stunned(): by_unit[unit.unit_id].time_stunned += SimulationClock.TICK_SECONDS
