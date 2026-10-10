class_name StatCalculator
extends RefCounted

static func calculate(source: UnitStats, balance: BalanceSettings) -> Dictionary:
	var primary: float = 0.0
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
	}
