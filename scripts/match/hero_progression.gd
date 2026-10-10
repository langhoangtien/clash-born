class_name HeroProgression
extends RefCounted
static var selected_profile: int = 0
static var selected_passive: int = 0
static var draft_confirmed: bool = false
var level: int = 1
var experience: int = 0
var gold: int = 0
var equipment := EquipmentManager.new()
var profile: HeroGrowth
var base: UnitStats
var unit: UnitRuntimeState
var balance: BalanceSettings
var settings: MatchSettings
var passive_id: String = "base_power"
var passive_level: int = 0
var skill_points: int = 0

func _init(state: UnitRuntimeState, hero_base: UnitStats, growth: HeroGrowth, rules: MatchSettings, formulas: BalanceSettings) -> void:
	unit = state
	base = hero_base
	profile = growth
	settings = rules
	balance = formulas
	gold = rules.starting_gold
	recalculate()

func required_xp() -> int:
	return settings.first_level_xp + (level - 1) * settings.level_xp_increment

func lose_death_gold() -> int:
	var loss := mini(gold, maxi(0, settings.death_gold_per_level) * level)
	gold -= loss
	return loss

func award(xp: int, coins: int = 0) -> int:
	gold += maxi(0, coins)
	if level >= settings.maximum_level: return 0
	experience += maxi(0, xp)
	var previous := level
	while level < settings.maximum_level and experience >= required_xp():
		experience -= required_xp()
		level += 1
	if level == settings.maximum_level: experience = 0
	if level != previous:
		skill_points += level - previous
		recalculate()
	return level - previous

func recalculate() -> void:
	var hp_ratio: float = unit.current_hp / unit.stats.max_hp
	var mana_ratio: float = unit.current_mana / unit.stats.max_mana if unit.stats.max_mana > 0 else 0
	var source := profile.source_at_level(base, level)
	unit.stats = StatCalculator.calculate(source, balance, equipment.items())
	HeroPassiveCatalog.apply(unit.stats, source, passive_id, passive_level, unit.permanent_damage_bonus)
	unit.passive_id = passive_id
	unit.passive_level = passive_level
	unit.current_hp = unit.stats.max_hp * clampf(hp_ratio, 0, 1) if unit.alive else 0
	unit.current_mana = unit.stats.max_mana * clampf(mana_ratio, 0, 1)

func purchase_error(item: EquipmentData) -> String:
	if item == null or not item.is_valid(): return "Đồ không hợp lệ"
	var cost := purchase_cost(item)
	if gold < cost: return "Không đủ vàng"
	var owned_components := _owned_recipe_components(item)
	var free_slot := not owned_components.is_empty()
	for slot in range(EquipmentManager.SLOT_COUNT):
		var current := equipment.get_item(slot)
		if current == null: free_slot = true
		elif current.id == item.id and (not item.allow_multiple or not current.allow_multiple): return "Không thể mua trùng món này"
	return "" if free_slot else "Đã đầy 6 ô trang bị"

func buy(item: EquipmentData) -> bool:
	if not purchase_error(item).is_empty(): return false
	var cost := purchase_cost(item)
	var owned_components := _owned_recipe_components(item)
	if not owned_components.is_empty() and not equipment.consume_ids(owned_components): return false
	for slot in range(EquipmentManager.SLOT_COUNT):
		if equipment.get_item(slot) == null and equipment.equip(slot, item):
			gold -= cost
			recalculate()
			return true
	return false

func _owned_recipe_components(item: EquipmentData) -> PackedStringArray:
	var result := PackedStringArray()
	var used: Dictionary = {}
	for component in item.recipe_components:
		var count: int = used.get(component, 0)
		if count < equipment.count_id(component):
			result.append(component)
			used[component] = count + 1
	return result

func purchase_cost(item: EquipmentData) -> int:
	if item == null: return 0
	var discount := 0
	for component in _owned_recipe_components(item):
		var data := MatchItemCatalog.by_id(component)
		if data != null: discount += data.price
	return maxi(0, item.price - discount)

func sell(slot: int) -> bool:
	var item := equipment.get_item(slot)
	if item == null: return false
	gold += floori(item.price * settings.sell_refund)
	equipment.remove(slot)
	recalculate()
	return true

func select_passive(index: int) -> void:
	passive_id = HeroPassiveCatalog.id_at(index)
	passive_level = 1
	skill_points = maxi(0, level - 1)
	unit.permanent_damage_bonus = 0
	recalculate()

func select_profile_skill() -> void:
	var index := 0
	for entry in HeroPassiveCatalog.DEFINITIONS:
		if entry.id == profile.passive_id: break
		index += 1
	select_passive(index)

func upgrade_passive() -> bool:
	if skill_points <= 0 or passive_level >= 5: return false
	skill_points -= 1
	passive_level += 1
	recalculate()
	return true

func record_kill(kind: String) -> void:
	if passive_id != "soul_hunter": return
	var rank := clampi(passive_level, 1, 5)
	var creep_gain: float = [1.0, 1.5, 2.0, 2.5, 3.0][rank - 1]
	var hero_gain: float = [5.0, 7.0, 9.0, 11.0, 13.0][rank - 1]
	var cap: float = [100.0, 125.0, 150.0, 175.0, 200.0][rank - 1]
	unit.permanent_damage_bonus = minf(cap, unit.permanent_damage_bonus + (hero_gain if kind == "hero" else (creep_gain if kind == "creep" else 0.0)))
	recalculate()
