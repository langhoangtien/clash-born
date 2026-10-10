class_name MatchItemCatalog
extends RefCounted
## Match-only component/recipe catalog. Sandbox reference items stay unchanged.
static var _items: Array[EquipmentData] = []

static func _generated_icon(kind: String) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color("202836"))
	for y in range(64):
		for x in range(64):
			var point := Vector2(x, y)
			var painted := false
			match kind:
				"bow":
					painted = (absf(point.distance_to(Vector2(12, 32)) - 31.0) < 2.4 and x >= 12) or absf(x - 13) < 1.5 or (absf(y - 32) < 1.5 and x >= 13 and x <= 54)
				"sickle":
					painted = (absf(point.distance_to(Vector2(34, 29)) - 20.0) < 3.0 and x <= 47 and y <= 43) or point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(22, 42), Vector2(10, 56))) < 3.0
				"hammer":
					painted = Rect2(11, 12, 34, 15).has_point(point) or point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(36, 25), Vector2(16, 54))) < 3.5
				"claw":
					for offset in [0.0, 9.0, 18.0]:
						if point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(14 + offset, 51), Vector2(25 + offset, 13))) < 3.0: painted = true
				"blood":
					painted = point.distance_to(Vector2(32, 40)) < 15.0 or (y >= 10 and y <= 40 and absf(x - 32) < (y - 8) * 0.42)
			if painted: image.set_pixel(x, y, {"bow": Color("75d8ff"), "sickle": Color("f06b9d"), "hammer": Color("d7b078"), "claw": Color("ff755f"), "blood": Color("e83e64")}.get(kind, Color.WHITE))
	return ImageTexture.create_from_image(image)

static func _item(id: String, name: String, price: int, modifiers: Dictionary, icon_name: String, components: PackedStringArray = [], recipe_cost: int = 0) -> EquipmentData:
	var item := EquipmentData.new()
	item.id = id
	item.display_name = name
	item.price = price
	item.modifiers.assign(modifiers)
	item.icon = _generated_icon(icon_name.trim_prefix("generated:")) if icon_name.begins_with("generated:") else load("res://assets/items/%s.svg" % icon_name)
	item.allow_multiple = components.is_empty()
	item.recipe_components = components
	item.recipe_cost = recipe_cost
	item.description = item.bonus_summary() + ("\n" + item.recipe_summary() if not components.is_empty() else "")
	return item

static func items() -> Array[EquipmentData]:
	if not _items.is_empty(): return _items
	_items = [
		_item("boots", "Giày Tốc Độ", 500, {"movement_speed": 55.0}, "swift_gloves"),
		_item("swift_gloves", "Găng Tốc Độ", 650, {"attack_speed_bonus": 0.40}, "swift_gloves"),
		_item("heavy_sword", "Kiếm Lớn", 700, {"physical_damage": 25.0}, "heavy_sword"),
		_item("vitality_stone", "Đá Sinh Lực", 900, {"max_hp": 650.0, "hp_regen": 4.0}, "vitality_stone"),
		_item("iron_armor", "Giáp Sắt", 800, {"physical_armor": 10.0}, "iron_armor"),
		_item("mystic_cloak", "Áo Kháng Phép", 850, {"magic_armor": 12.0, "status_resistance": 0.10}, "mystic_cloak"),
		_item("ogre_axe", "Rìu Sức Mạnh", 850, {"strength": 20.0}, "resolve_amulet"),
		_item("agility_blade", "Đao Nhanh Nhẹn", 850, {"agility": 20.0}, "evasion_blade"),
		_item("wizard_staff", "Trượng Trí Tuệ", 850, {"intelligence": 20.0}, "arcane_staff"),
		_item("precision_blade", "Kiếm Chính Xác", 950, {"physical_damage": 25.0, "accuracy": 0.20}, "precision_blade"),
		_item("range_lens", "Ống Ngắm", 900, {"attack_range": 140.0}, "range_lens"),
		_item("cast_focus", "Tinh Thạch Phép", 900, {"magic_damage": 35.0, "cast_range": 160.0}, "cast_focus"),
		_item("critical_blade", "Kiếm Crit I", 1600, {"physical_damage": 25.0, "critical_chance": 0.20, "critical_multiplier_override": 1.2}, "critical_blade", ["heavy_sword"], 900),
		_item("power_treads", "Giày Sức Mạnh", 2300, {"movement_speed": 75.0, "attack_speed_bonus": 0.65, "strength": 15.0, "agility": 15.0, "intelligence": 15.0}, "swift_gloves", ["boots", "swift_gloves", "ogre_axe"], 300),
		_item("critical_blade_2", "Kiếm Crit II", 4100, {"physical_damage": 80.0, "critical_chance": 0.25, "critical_multiplier_override": 2.5}, "critical_blade", ["critical_blade", "heavy_sword"], 1800),
		_item("skull_basher", "Búa Bash", 2900, {"physical_damage": 60.0, "strength": 15.0, "bash_chance": 0.20, "bash_duration": 2.0, "bash_damage": 70.0}, "generated:hammer", ["heavy_sword", "ogre_axe"], 1350),
		_item("frost_armor", "Giáp Băng", 3600, {"physical_armor": 28.0, "magic_armor": 12.0, "max_mana": 400.0, "attack_slow": 0.35, "attack_slow_duration": 2.5}, "mystic_cloak", ["iron_armor", "mystic_cloak", "wizard_staff"], 1100),
		_item("blade_mail", "Giáp Phản", 3000, {"physical_armor": 20.0, "physical_damage": 45.0, "damage_reflect": 0.15}, "iron_armor", ["iron_armor", "heavy_sword"], 1500),
		_item("heart", "Trái Tim Khổng Lồ", 4300, {"max_hp": 2400.0, "strength": 40.0, "hp_regen": 25.0}, "vitality_stone", ["vitality_stone", "vitality_stone", "ogre_axe"], 1650),
		_item("butterfly", "Cánh Bướm", 4200, {"agility": 45.0, "physical_damage": 55.0, "attack_speed_bonus": 0.80, "evasion": 0.30}, "evasion_blade", ["agility_blade", "swift_gloves", "heavy_sword"], 2000),
		_item("assault_armor", "Giáp Cường Công", 4400, {"physical_armor": 35.0, "attack_speed_bonus": 1.00, "strength": 25.0, "armor_reduction": 12.0}, "armor_breaker", ["iron_armor", "swift_gloves", "ogre_axe"], 2100),
		_item("arcane_staff", "Đại Trượng Phép", 3900, {"intelligence": 50.0, "magic_damage": 110.0, "max_mana": 700.0, "cast_range": 200.0}, "arcane_staff", ["wizard_staff", "wizard_staff", "cast_focus"], 1300),
		_item("pure_blade", "Kiếm Pure", 4500, {"physical_damage": 70.0, "pure_damage": 65.0, "strength": 20.0, "agility": 20.0}, "pure_blade", ["heavy_sword", "ogre_axe", "agility_blade"], 2100),
		_item("desolator", "Desolator I", 2600, {"physical_damage": 50.0, "armor_reduction": 10.0}, "generated:sickle", ["heavy_sword", "heavy_sword"], 1200),
		_item("desolator_2", "Desolator II", 4700, {"physical_damage": 80.0, "armor_reduction": 15.0}, "generated:sickle", ["desolator", "heavy_sword"], 1400),
		_item("storm_bow", "Cung Bão Tố", 3200, {"physical_damage": 45.0, "attack_speed_bonus": 0.90, "attack_range": 80.0}, "generated:bow", ["swift_gloves", "range_lens", "heavy_sword"], 750),
		_item("demon_claw", "Móng Vuốt Quỷ", 2800, {"attack_speed_bonus": 1.50}, "generated:claw", ["swift_gloves", "swift_gloves"], 1500),
		_item("lifesteal_1", "Huyết Kiếm I", 2200, {"physical_damage": 35.0, "lifesteal": 0.08}, "generated:blood", ["heavy_sword", "vitality_stone"], 600),
		_item("lifesteal_2", "Huyết Kiếm II", 4200, {"physical_damage": 65.0, "lifesteal": 0.15}, "generated:blood", ["lifesteal_1", "heavy_sword"], 1300),
	]
	return _items

static func by_id(id: String) -> EquipmentData:
	for item in items():
		if item.id == id: return item
	return null
