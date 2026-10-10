class_name EquipmentData
extends Resource

const SUPPORTED_MODIFIERS: Array[String] = ["strength", "agility", "intelligence", "max_hp", "max_mana", "hp_regen", "mana_regen", "physical_damage", "magic_damage", "pure_damage", "physical_armor", "magic_armor", "attack_speed_bonus", "attack_range", "movement_speed", "evasion", "accuracy", "critical_chance", "critical_multiplier", "status_resistance", "armor_reduction", "magic_armor_reduction", "physical_armor_penetration"]
const PERCENT_MODIFIERS: Array[String] = ["attack_speed_bonus", "evasion", "accuracy", "critical_chance", "status_resistance", "physical_armor_penetration"]

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var price: int = 1000
@export var allow_multiple: bool = true
@export var modifiers: Dictionary[String, float] = {}

func is_valid() -> bool:
	if id.is_empty() or display_name.is_empty() or price < 0:
		return false
	for key in modifiers:
		if key not in SUPPORTED_MODIFIERS or not is_finite(modifiers[key]):
			return false
	return true

func bonus_summary() -> String:
	var parts: PackedStringArray = []
	for key in modifiers:
		var name: String = {"physical_armor": "P armor", "magic_armor": "M armor", "max_hp": "HP", "accuracy": "accuracy", "critical_chance": "crit", "evasion": "evade", "armor_reduction": "armor reduction", "physical_damage": "P damage", "magic_damage": "M damage", "pure_damage": "pure damage", "attack_speed_bonus": "attack speed", "status_resistance": "resistance"}.get(key, key.replace("_", " "))
		var value: float = modifiers[key]
		parts.append("%+.0f%% %s" % [value * 100, name] if key in PERCENT_MODIFIERS else "%+.1f %s" % [value, name])
	return ", ".join(parts)
