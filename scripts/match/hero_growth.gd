class_name HeroGrowth
extends Resource
## Numeric UnitStats fields; formulas still come from StatCalculator.
@export var display_name: String = "Hero"
@export var ranged_attacks: bool = true
@export var base_overrides: Dictionary[String, float] = {}
@export var per_level: Dictionary[String, float] = {}

func source_at_level(base: UnitStats, level: int) -> UnitStats:
	var source: UnitStats = base.duplicate(true)
	source.display_name = display_name
	source.ranged_attacks = ranged_attacks
	for key in base_overrides: source.set(key, base_overrides[key])
	for key in per_level: source.set(key, source.get(key) + per_level[key] * (level - 1))
	return source

func growth_summary() -> String:
	var parts: PackedStringArray = []
	for key in per_level:
		var label: String = {"base_hp": "máu", "physical_damage": "công vật lý", "magic_damage": "công phép", "movement_speed": "tốc chạy", "attack_speed_bonus": "tốc đánh", "physical_armor": "giáp", "base_mana": "mana"}.get(key, key)
		parts.append("+%.1f%% %s" % [per_level[key] * 100, label] if key == "attack_speed_bonus" else "+%.1f %s" % [per_level[key], label])
	return " / ".join(parts)
