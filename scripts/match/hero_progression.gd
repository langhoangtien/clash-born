class_name HeroProgression
extends RefCounted
static var selected_profile: int = 0
var level: int = 1
var experience: int = 0
var gold: int = 0
var equipment := EquipmentManager.new()
var profile: HeroGrowth
var base: UnitStats
var unit: UnitRuntimeState
var balance: BalanceSettings
var settings: MatchSettings

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

func award(xp: int, coins: int = 0) -> int:
	gold += maxi(0, coins)
	if level >= settings.maximum_level: return 0
	experience += maxi(0, xp)
	var previous := level
	while level < settings.maximum_level and experience >= required_xp():
		experience -= required_xp()
		level += 1
	if level == settings.maximum_level: experience = 0
	if level != previous: recalculate()
	return level - previous

func recalculate() -> void:
	var hp_ratio: float = unit.current_hp / unit.stats.max_hp
	var mana_ratio: float = unit.current_mana / unit.stats.max_mana if unit.stats.max_mana > 0 else 0
	unit.stats = StatCalculator.calculate(profile.source_at_level(base, level), balance, equipment.items())
	unit.current_hp = unit.stats.max_hp * clampf(hp_ratio, 0, 1) if unit.alive else 0
	unit.current_mana = unit.stats.max_mana * clampf(mana_ratio, 0, 1)

func purchase_error(item: EquipmentData) -> String:
	if item == null or not item.is_valid(): return "Đồ không hợp lệ"
	if gold < item.price: return "Không đủ vàng"
	var free_slot := false
	for slot in range(EquipmentManager.SLOT_COUNT):
		var current := equipment.get_item(slot)
		if current == null: free_slot = true
		elif current.id == item.id and (not item.allow_multiple or not current.allow_multiple): return "Không thể mua trùng món này"
	return "" if free_slot else "Đã đầy 6 ô trang bị"

func buy(item: EquipmentData) -> bool:
	if not purchase_error(item).is_empty(): return false
	for slot in range(EquipmentManager.SLOT_COUNT):
		if equipment.get_item(slot) == null and equipment.equip(slot, item):
			gold -= item.price
			recalculate()
			return true
	return false

func sell(slot: int) -> bool:
	var item := equipment.get_item(slot)
	if item == null: return false
	gold += floori(item.price * settings.sell_refund)
	equipment.remove(slot)
	recalculate()
	return true
