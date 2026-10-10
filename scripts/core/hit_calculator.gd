class_name HitCalculator
extends RefCounted

static func combine_evasion(sources: Array[float], balance: BalanceSettings) -> float:
	var combined := 0.0
	for source in sources:
		var chance := clampf(source, 0, 1)
		combined = 1 - (1 - combined) * (1 - chance) if balance.multiplicative_evasion else combined + chance
	return clampf(combined, 0, balance.evasion_cap)

static func effective_evasion(evasion: float, accuracy: float, balance: BalanceSettings) -> float:
	return clampf(evasion - accuracy, 0, balance.evasion_cap)

static func resolve(source: Dictionary, target: Dictionary, rng: RandomNumberGenerator, balance: BalanceSettings) -> Dictionary:
	var missed: bool = source.attacks_can_miss and rng.randf() < effective_evasion(target.evasion, source.accuracy, balance)
	# One hit roll and one eligible critical roll for the entire basic attack.
	# Never roll critical after a miss; pure critical eligibility is separate.
	var critical: bool = false
	var has_eligible_damage: bool = source.physical_damage > 0 or source.magic_damage > 0 or (source.pure_damage > 0 and source.pure_attacks_can_crit)
	if not missed and source.attacks_can_crit and has_eligible_damage:
		critical = rng.randf() < source.critical_chance
	return {"missed": missed, "critical": critical}
