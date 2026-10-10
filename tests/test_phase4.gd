extends SceneTree

var failures: int = 0
var checks: int = 0
var balance := BalanceSettings.new()
var catalog: Array[EquipmentData] = preload("res://scripts/ui/equipment_panel.gd").CATALOG

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _near(actual: float, expected: float, description: String) -> void:
	_check(absf(actual - expected) < 0.000001, "%s: got %.8f, expected %.8f" % [description, actual, expected])

func _item(id: String) -> EquipmentData:
	for item in catalog:
		if item.id == id: return item
	return null

func _run() -> void:
	_test_catalog()
	_test_loadouts()
	_test_combat()
	await _test_ui()
	print("Phase 4: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_catalog() -> void:
	var expected := {
		"iron_armor": ["physical_armor", 15.0, 1000],
		"mystic_cloak": ["magic_armor", 15.0, 1000],
		"vitality_stone": ["max_hp", 500.0, 1000],
		"precision_blade": ["accuracy", 0.3, 1000],
		"critical_blade": ["critical_chance", 0.25, 1000],
		"evasion_blade": ["evasion", 0.25, 1000],
		"armor_breaker": ["armor_reduction", 15.0, 1200],
		"heavy_sword": ["physical_damage", 60.0, 1000],
		"arcane_staff": ["magic_damage", 60.0, 1000],
		"pure_blade": ["pure_damage", 40.0, 1500],
		"swift_gloves": ["attack_speed_bonus", 0.3, 1000],
		"resolve_amulet": ["status_resistance", 0.25, 1000],
	}
	_check(catalog.size() == 12, "All twelve initial items exist")
	var seen: Array[String] = []
	var source := UnitStats.new()
	var baseline := StatCalculator.calculate(source, balance)
	for item in catalog:
		_check(item.is_valid() and item.id not in seen and not item.description.is_empty(), "Valid unique editable Resource %s" % item.id)
		seen.append(item.id)
		_check(expected.has(item.id), "Known initial item %s" % item.id)
		var entry: Array = expected[item.id]
		_check(item.modifiers.size() == 1 and item.modifiers.has(entry[0]), "Correct modifier key %s" % item.id)
		_near(item.modifiers[entry[0]], entry[1], "Correct bonus %s" % item.id)
		_check(item.price == entry[2] and item.allow_multiple, "Price and duplicate policy %s" % item.id)
		var equipped: Array[EquipmentData] = [item]
		var stats := StatCalculator.calculate(source, balance, equipped)
		var key: String = "attack_speed" if entry[0] == "attack_speed_bonus" else entry[0]
		_near(stats[key], baseline[key] + entry[1], "Item changes final stat %s" % item.id)
		_check(StatCalculator.calculate(source, balance) == baseline, "Source unchanged after %s" % item.id)

func _test_loadouts() -> void:
	var source := UnitStats.new()
	source.strength = 10
	source.agility = 7
	source.physical_armor = -5.5
	var baseline := StatCalculator.calculate(source, balance)
	var loadout := EquipmentManager.new()
	var iron := _item("iron_armor")
	_check(not loadout.equip(-1, iron) and not loadout.equip(6, iron) and not loadout.equip(0, null), "Invalid slot/null rejected")
	for iteration in range(100):
		_check(loadout.equip(0, iron), "Equip cycle %d" % iteration)
		_near(StatCalculator.calculate(source, balance, loadout.items()).physical_armor, baseline.physical_armor + 15, "No duplicate bonus cycle %d" % iteration)
		loadout.equip(0, iron)
		_near(StatCalculator.calculate(source, balance, loadout.items()).physical_armor, baseline.physical_armor + 15, "Reassign same slot is idempotent %d" % iteration)
		_check(loadout.remove(0), "Remove cycle %d" % iteration)
		_check(StatCalculator.calculate(source, balance, loadout.items()) == baseline, "Exact restoration without stat drift cycle %d" % iteration)
	for slot in range(6): _check(loadout.equip(slot, iron), "Six copies occupy six slots")
	_near(StatCalculator.calculate(source, balance, loadout.items()).physical_armor, baseline.physical_armor + 90, "Allowed copies stack once each")
	_check(loadout.items().size() == 6 and not loadout.equip(6, iron), "Six-slot capacity enforced")
	loadout.equip(0, _item("mystic_cloak"))
	var stats := StatCalculator.calculate(source, balance, loadout.items())
	_near(stats.physical_armor, baseline.physical_armor + 75, "Replacing item removes old modifier")
	_near(stats.magic_armor, baseline.magic_armor + 15, "Replacing item applies new modifier once")
	loadout.clear()
	_check(loadout.items().is_empty() and StatCalculator.calculate(source, balance, loadout.items()) == baseline, "Clear returns exact baseline")
	var unique: EquipmentData = iron.duplicate(true)
	unique.id = "unique_armor"
	unique.allow_multiple = false
	_check(loadout.equip(0, unique) and not loadout.equip(1, unique), "Nonduplicable item policy enforced")
	_check(loadout.equip(0, unique), "Unique item can be reassigned to its current slot")
	var invalid := EquipmentData.new()
	invalid.id = "invalid"
	invalid.display_name = "Invalid"
	invalid.modifiers = {"unknown_stat": 1.0}
	_check(not loadout.equip(1, invalid), "Unsupported modifier rejected")
	loadout.clear()
	source.evasion = 0.3
	loadout.equip(0, _item("evasion_blade"))
	loadout.equip(1, _item("evasion_blade"))
	_near(StatCalculator.calculate(source, balance, loadout.items()).evasion, 0.60625, "Base and two independent evasion items multiply")
	loadout.clear()
	for slot in range(6): loadout.equip(slot, _item("resolve_amulet"))
	_near(StatCalculator.calculate(source, balance, loadout.items()).status_resistance, 0.6, "Equipment resistance respects cap")
	loadout.clear()
	for slot in range(6): loadout.equip(slot, _item("critical_blade"))
	_near(StatCalculator.calculate(source, balance, loadout.items()).critical_chance, 1, "Equipment critical chance respects cap")
	loadout.clear()
	source.base_attacks_per_second = 2
	for slot in range(6): loadout.equip(slot, _item("swift_gloves"))
	_near(StatCalculator.calculate(source, balance, loadout.items()).attack_speed, 3, "Equipment APS respects cap")
	var attribute_item := EquipmentData.new()
	attribute_item.id = "attributes"
	attribute_item.display_name = "Attribute test"
	attribute_item.modifiers = {"strength": 2.0, "agility": 4.0, "intelligence": 3.0}
	var attribute_items: Array[EquipmentData] = [attribute_item]
	stats = StatCalculator.calculate(source, balance, attribute_items)
	_near(stats.max_hp, baseline.max_hp + 40, "Equipment STR feeds max HP conversion")
	_near(stats.physical_armor, baseline.physical_armor + 0.6, "Equipment AGI feeds fractional armor conversion")
	_near(stats.max_mana, baseline.max_mana + 36, "Equipment INT feeds mana conversion")

func _combat(blue: UnitStats, red: UnitStats, blue_items: Array[EquipmentData] = [], red_items: Array[EquipmentData] = []) -> CombatEngine:
	var engine := CombatEngine.new(balance)
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0), 123, blue_items, red_items)
	return engine

func _test_combat() -> void:
	var blue := UnitStats.new()
	var red := UnitStats.new()
	blue.physical_damage = 100
	var iron_items: Array[EquipmentData] = [_item("iron_armor")]
	var cloak_items: Array[EquipmentData] = [_item("mystic_cloak")]
	var engine := _combat(blue, red)
	engine.step()
	_near(engine.units[1].current_hp, 900, "Unequipped physical baseline")
	engine = _combat(blue, red, [], iron_items)
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 100 / 1.9, "Iron Armor mitigates physical attack")
	engine = _combat(blue, red, [], cloak_items)
	engine.step()
	_near(engine.units[1].current_hp, 900, "Mystic Cloak does not mitigate physical damage")
	blue.physical_damage = 0
	blue.magic_damage = 100
	engine = _combat(blue, red, [], cloak_items)
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 100 / 1.9, "Mystic Cloak mitigates magic attack")
	blue.magic_damage = 0
	blue.physical_damage = 100
	var breaker: Array[EquipmentData] = [_item("armor_breaker")]
	engine = _combat(blue, red, breaker)
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 100 * (2 - 1 / 1.9), "Armor Breaker affects wearer's physical attack")
	_near(engine.units[1].stats.physical_armor, 0, "Armor Breaker does not permanently modify target armor")
	blue.physical_damage = 0
	blue.critical_chance = 1
	red.physical_armor = 50
	red.magic_armor = 50
	var pure: Array[EquipmentData] = [_item("pure_blade")]
	engine = _combat(blue, red, pure)
	engine.step()
	_near(engine.units[1].current_hp, 960, "Pure Blade adds separate pure damage, ignores armor, no implicit critical")
	blue.physical_damage = 100
	blue.critical_chance = 0
	red.physical_armor = 0
	red.magic_armor = 0
	var heavy: Array[EquipmentData] = [_item("heavy_sword")]
	engine = _combat(blue, red, heavy)
	var events := engine.step()
	_near(engine.units[1].current_hp, 840, "Heavy Sword increases basic attack damage")
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0), 123, heavy)
	_check(engine.step() == events, "Same loadout/seed reproduces events on reset")
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0), 123)
	engine.step()
	_near(engine.units[1].current_hp, 900, "Unequipped combat returns exactly to baseline")
	var amulet: Array[EquipmentData] = [_item("resolve_amulet")]
	engine = _combat(blue, red, [], amulet)
	engine.queue_effect("debug", "red_01", StatusEffect.Kind.STUN, 4, 0, "stun")
	engine.step()
	_check(engine.units[1].effects.active[0].duration_ticks == 90, "Equipment status resistance shortens stun")
	var vitality: Array[EquipmentData] = [_item("vitality_stone")]
	engine = _combat(blue, red, [], vitality)
	_near(engine.units[1].current_hp, 1500, "Vitality Stone initializes current/max HP together")
	blue.physical_damage = 0
	var gloves: Array[EquipmentData] = [_item("swift_gloves")]
	engine = _combat(blue, red, gloves)
	var attacks := 0
	for tick in range(300):
		for event in engine.step():
			if event.kind == "attack" and event.source_unit_id == "blue_01": attacks += 1
	_check(attacks == 13, "Swift Gloves produces 13 attacks in ten seconds")

func _test_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var panel = main.equipment_panel
	var initial_stats: Dictionary = main.combat.units[0].stats.duplicate()
	_check(panel.slot_selectors.size() == 6 and panel.slot_selectors[0].item_count == 13, "UI has six slots and twelve items plus Empty")
	panel.slot_selectors[0].item_selected.emit(1)
	_near(main.combat.units[0].stats.physical_armor, initial_stats.physical_armor + 15, "UI equip updates stats immediately")
	_check(panel.slot_selectors[0].selected == 1 and "Iron" in panel.slot_selectors[0].get_item_text(1), "UI selection reflects equipped item")
	_check("+15.0 P armor" in panel.bonus_label.text, "UI shows aggregate equipment bonus")
	panel.slot_selectors[0].item_selected.emit(0)
	_check(main.combat.units[0].stats == initial_stats, "UI removal restores entire stats dictionary")
	panel.slot_selectors[0].item_selected.emit(3)
	_near(main.combat.units[0].current_hp, initial_stats.max_hp + 500, "UI maximum HP bonus starts a full-health duel")
	main.step_button.pressed.emit()
	main.run_button.pressed.emit()
	panel.slot_selectors[1].item_selected.emit(8)
	_check(not main.clock.running and main.clock.tick_count == 0 and main.combat.tick_count == 0, "Equipment change pauses and resets running duel")
	main._reset()
	_check(main.loadouts[0].items().size() == 2, "Battle Reset retains loadout")
	panel.unit_select.select(1)
	panel.unit_select.item_selected.emit(1)
	panel.slot_selectors[0].item_selected.emit(2)
	_check(main.loadouts[1].items().size() == 1 and main.loadouts[0].items().size() == 2, "Independent equipment for Blue and Red")
	panel.reset_button.pressed.emit()
	_check(main.loadouts[1].items().is_empty() and main.loadouts[0].items().size() == 2, "Reset equipment clears only selected unit")
	panel.unit_select.select(0)
	panel.unit_select.item_selected.emit(0)
	if "--capture" in OS.get_cmdline_user_args():
		_check(DisplayServer.get_name() != "headless", "Capture uses real renderer")
		if DisplayServer.get_name() != "headless":
			panel.slot_selectors[2].item_selected.emit(11)
			panel.slot_selectors[3].item_selected.emit(4)
			main.step_button.pressed.emit()
			main.right_tabs.current_tab = 1
			await process_frame
			await RenderingServer.frame_post_draw
			_check(panel.get_global_rect().end.y <= 814, "Equipment panel stays above simulation controls")
			_check(panel.get_global_rect().end.x <= 1600, "Equipment panel stays within logical viewport")
			_check(panel.stats_label.get_global_rect().end.y <= panel.get_global_rect().end.y, "All final stats fit inside equipment panel")
			DirAccess.make_dir_recursive_absolute("res://.local")
			_check(root.get_texture().get_image().save_png("res://.local/phase4-preview.png") == OK, "Rendered equipment screenshot saved")
	panel.reset_button.pressed.emit()
	_check(main.combat.units[0].stats == initial_stats and main.loadouts[0].items().is_empty(), "Equipment reset restores exact baseline stats")
	main.queue_free()
	await process_frame
