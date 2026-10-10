class_name EquipmentData
extends Resource

const SUPPORTED_MODIFIERS: Array[String] = ["strength", "agility", "intelligence", "max_hp", "max_mana", "hp_regen", "mana_regen", "physical_damage", "magic_damage", "pure_damage", "physical_armor", "magic_armor", "attack_speed_bonus", "attack_range", "cast_range", "movement_speed", "evasion", "accuracy", "critical_chance", "critical_multiplier", "critical_multiplier_override", "status_resistance", "armor_reduction", "magic_armor_reduction", "physical_armor_penetration", "bash_chance", "bash_duration", "bash_damage", "damage_reflect", "attack_slow", "attack_slow_duration", "lifesteal"]
const PERCENT_MODIFIERS: Array[String] = ["attack_speed_bonus", "evasion", "accuracy", "critical_chance", "status_resistance", "physical_armor_penetration", "bash_chance", "damage_reflect", "attack_slow", "lifesteal"]

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export_multiline var description: String = ""
@export var price: int = 1000
@export var allow_multiple: bool = true
@export var modifiers: Dictionary[String, float] = {}
@export var recipe_components: PackedStringArray = []
@export var recipe_cost: int = 0

func is_valid() -> bool:
	if id.is_empty() or display_name.is_empty() or price < 0 or recipe_cost < 0:
		return false
	for key in modifiers:
		if key not in SUPPORTED_MODIFIERS or not is_finite(modifiers[key]):
			return false
	return true

func bonus_summary() -> String:
	var parts: PackedStringArray = []
	for key in modifiers:
		var name: String = {"physical_armor": "giáp VL", "magic_armor": "giáp phép", "max_hp": "HP", "accuracy": "chính xác", "critical_chance": "crit", "critical_multiplier": "hệ số crit", "critical_multiplier_override": "hệ số crit", "evasion": "né", "armor_reduction": "trừ giáp", "physical_damage": "damage", "magic_damage": "damage phép", "pure_damage": "damage pure", "attack_speed_bonus": "tốc đánh", "movement_speed": "tốc chạy", "status_resistance": "kháng hiệu ứng", "strength": "STR", "agility": "AGI", "intelligence": "INT", "bash_chance": "bash", "bash_duration": "giây choáng", "bash_damage": "damage bash", "damage_reflect": "phản damage", "attack_slow": "giảm tốc đánh", "attack_slow_duration": "giây làm chậm", "lifesteal": "hút máu"}.get(key, key.replace("_", " "))
		var value: float = modifiers[key]
		if key in PERCENT_MODIFIERS:
			var percent := value * 100
			var format_text := "%+.0f%% %s" if is_equal_approx(percent, roundf(percent)) else "%+.1f%% %s"
			parts.append(format_text % [percent, name])
		else: parts.append("%+.1f %s" % [value, name])
	return ", ".join(parts)

func recipe_summary() -> String:
	if recipe_components.is_empty(): return ""
	return "Ghép: %s + %d vàng công thức" % [" + ".join(recipe_components), recipe_cost]
