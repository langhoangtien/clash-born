class_name StatCalculator
extends RefCounted

static func calculate(source: UnitStats, balance: BalanceSettings, equipment: Array[EquipmentData] = []) -> Dictionary:
	var combined := EquipmentManager.aggregate(equipment)
	var bonuses: Dictionary = combined.bonuses
	var item_evasion: Array[float] = combined.evasion_sources
	var strength: float = source.strength + bonuses.get("strength", 0.0)
	var agility: float = source.agility + bonuses.get("agility", 0.0)
	var intelligence: float = source.intelligence + bonuses.get("intelligence", 0.0)
	var primary: float = 0.0
	var evasion_sources: Array[float] = [source.evasion]
	evasion_sources.append_array(source.evasion_sources)
	evasion_sources.append_array(item_evasion)
	var attack_speed := clampf(source.base_attacks_per_second * (1 + agility * balance.attack_speed_per_agility + source.attack_speed_bonus + bonuses.get("attack_speed_bonus", 0.0)), balance.minimum_attack_speed, balance.maximum_attack_speed)
	attack_speed = minf(attack_speed, 1.0 / maxf(balance.minimum_attack_interval, SimulationClock.TICK_SECONDS))
	if source.primary_damage_enabled and balance.primary_damage_enabled:
		match source.primary_attribute:
			UnitStats.PrimaryAttribute.STRENGTH: primary = strength
			UnitStats.PrimaryAttribute.AGILITY: primary = agility
			UnitStats.PrimaryAttribute.INTELLIGENCE: primary = intelligence
	return {
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence,
		"max_hp": maxf(1.0, source.base_hp + strength * balance.hp_per_strength + bonuses.get("max_hp", 0.0)),
		"max_mana": maxf(0.0, source.base_mana + intelligence * balance.mana_per_intelligence + bonuses.get("max_mana", 0.0)),
		"hp_regen": maxf(0.0, source.base_hp_regen + strength * balance.hp_regen_per_strength + bonuses.get("hp_regen", 0.0)),
		"mana_regen": maxf(0.0, source.base_mana_regen + intelligence * balance.mana_regen_per_intelligence + bonuses.get("mana_regen", 0.0)),
		"physical_damage": maxf(0.0, source.physical_damage + primary * balance.primary_damage_coefficient + bonuses.get("physical_damage", 0.0)),
		"magic_damage": maxf(0.0, source.magic_damage + bonuses.get("magic_damage", 0.0)),
		"pure_damage": maxf(0.0, source.pure_damage + bonuses.get("pure_damage", 0.0)),
		"physical_armor": source.physical_armor + agility * balance.armor_per_agility + bonuses.get("physical_armor", 0.0),
		"magic_armor": source.magic_armor + intelligence * balance.magic_armor_per_intelligence + bonuses.get("magic_armor", 0.0),
		"attack_range": maxf(0.0, source.attack_range + bonuses.get("attack_range", 0.0)),
		"cast_range": maxf(0.0, source.cast_range + bonuses.get("cast_range", 0.0)),
		"cast_range_bonus": bonuses.get("cast_range", 0.0),
		"collision_radius": maxf(0.0, source.collision_radius),
		"ranged_attacks": source.ranged_attacks,
		"projectile_speed": maxf(1.0, source.projectile_speed),
		"projectile_hit_behavior": source.projectile_hit_behavior,
		"projectile_dead_target_behavior": source.projectile_dead_target_behavior,
		"attack_speed": attack_speed,
		"movement_speed": maxf(balance.minimum_movement_speed, source.movement_speed + bonuses.get("movement_speed", 0.0)),
		"evasion": HitCalculator.combine_evasion(evasion_sources, balance),
		"accuracy": maxf(0.0, source.accuracy + bonuses.get("accuracy", 0.0)),
		"critical_chance": clampf(source.critical_chance + bonuses.get("critical_chance", 0.0), 0, 1),
		"critical_multiplier": maxf(1, (source.critical_multiplier if source.critical_multiplier > 0 else balance.default_critical_multiplier) + bonuses.get("critical_multiplier", 0.0)),
		"status_resistance": clampf(source.status_resistance + bonuses.get("status_resistance", 0.0), 0, balance.status_resistance_cap),
		"armor_reduction": maxf(0, source.armor_reduction + bonuses.get("armor_reduction", 0.0)),
		"magic_armor_reduction": maxf(0, source.magic_armor_reduction + bonuses.get("magic_armor_reduction", 0.0)),
		"physical_armor_penetration": clampf(source.physical_armor_penetration + bonuses.get("physical_armor_penetration", 0.0), 0, 1),
		"attacks_can_miss": source.attacks_can_miss,
		"attacks_can_crit": source.attacks_can_crit,
		"pure_attacks_can_crit": source.pure_attacks_can_crit,
	}
