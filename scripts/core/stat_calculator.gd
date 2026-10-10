class_name StatCalculator
extends RefCounted

static func calculate(source: UnitStats, balance: BalanceSettings) -> Dictionary:
	var primary: float = 0.0
	var evasion_sources: Array[float] = [source.evasion]
	evasion_sources.append_array(source.evasion_sources)
	var attack_speed := clampf(source.base_attacks_per_second * (1 + source.agility * balance.attack_speed_per_agility + source.attack_speed_bonus), balance.minimum_attack_speed, balance.maximum_attack_speed)
	attack_speed = minf(attack_speed, 1.0 / maxf(balance.minimum_attack_interval, SimulationClock.TICK_SECONDS))
	if source.primary_damage_enabled and balance.primary_damage_enabled:
		match source.primary_attribute:
			UnitStats.PrimaryAttribute.STRENGTH: primary = source.strength
			UnitStats.PrimaryAttribute.AGILITY: primary = source.agility
			UnitStats.PrimaryAttribute.INTELLIGENCE: primary = source.intelligence
	return {
		"max_hp": maxf(1.0, source.base_hp + source.strength * balance.hp_per_strength),
		"max_mana": maxf(0.0, source.base_mana + source.intelligence * balance.mana_per_intelligence),
		"hp_regen": maxf(0.0, source.base_hp_regen + source.strength * balance.hp_regen_per_strength),
		"mana_regen": maxf(0.0, source.base_mana_regen + source.intelligence * balance.mana_regen_per_intelligence),
		"physical_damage": maxf(0.0, source.physical_damage + primary * balance.primary_damage_coefficient),
		"magic_damage": maxf(0.0, source.magic_damage),
		"pure_damage": maxf(0.0, source.pure_damage),
		"physical_armor": source.physical_armor + source.agility * balance.armor_per_agility,
		"magic_armor": source.magic_armor + source.intelligence * balance.magic_armor_per_intelligence,
		"attack_range": maxf(0.0, source.attack_range),
		"attack_speed": attack_speed,
		"movement_speed": maxf(balance.minimum_movement_speed, source.movement_speed),
		"evasion": HitCalculator.combine_evasion(evasion_sources, balance),
		"accuracy": maxf(0.0, source.accuracy),
		"critical_chance": clampf(source.critical_chance, 0, 1),
		"critical_multiplier": maxf(1, source.critical_multiplier if source.critical_multiplier > 0 else balance.default_critical_multiplier),
		"status_resistance": clampf(source.status_resistance, 0, balance.status_resistance_cap),
		"armor_reduction": maxf(0, source.armor_reduction),
		"magic_armor_reduction": maxf(0, source.magic_armor_reduction),
		"physical_armor_penetration": clampf(source.physical_armor_penetration, 0, 1),
		"attacks_can_miss": source.attacks_can_miss,
		"attacks_can_crit": source.attacks_can_crit,
		"pure_attacks_can_crit": source.pure_attacks_can_crit,
	}
