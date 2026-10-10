class_name DamageCalculator
extends RefCounted

enum DamageType { PHYSICAL, MAGICAL, PURE }

static func armor_multiplier(armor: float, coefficient: float) -> float:
	var positive_curve := 1.0 / (1.0 + coefficient * absf(armor))
	return positive_curve if armor >= 0.0 else 2.0 - positive_curve

static func calculate(raw_damage: float, damage_type: DamageType, physical_armor: float, magic_armor: float, balance: BalanceSettings) -> float:
	var raw := maxf(0.0, raw_damage)
	match damage_type:
		DamageType.PHYSICAL:
			return raw * armor_multiplier(physical_armor, balance.armor_coefficient)
		DamageType.MAGICAL:
			return raw * armor_multiplier(magic_armor, balance.armor_coefficient)
		DamageType.PURE:
			return raw
	return 0.0
