class_name MatchItemCatalog
extends RefCounted
## Match balance copies; Sandbox reference items/formulas remain intact.
static var _items: Array[EquipmentData] = []
static func items() -> Array[EquipmentData]:
	if not _items.is_empty(): return _items
	var prices := {"iron_armor": 900, "mystic_cloak": 900, "vitality_stone": 900, "precision_blade": 900, "critical_blade": 1800, "evasion_blade": 1600, "armor_breaker": 1600, "heavy_sword": 1200, "arcane_staff": 1400, "pure_blade": 1800, "swift_gloves": 650, "resolve_amulet": 1000, "range_lens": 1300, "cast_focus": 1300}
	for original in preload("res://scripts/ui/equipment_panel.gd").CATALOG:
		var item: EquipmentData = original.duplicate(true)
		item.price = prices[item.id]
		for key in ["physical_damage", "magic_damage", "pure_damage", "attack_speed_bonus", "critical_chance", "accuracy", "armor_reduction"]:
			if item.modifiers.has(key): item.modifiers[key] *= 0.5
		item.description = "Trang bị trận MOBA: " + item.bonus_summary()
		_items.append(item)
	return _items
