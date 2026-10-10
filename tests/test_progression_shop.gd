extends SceneTree
var checks := 0
var failures := 0
const SWORD = preload("res://data/equipment/heavy_sword.tres")
const HEALTH = preload("res://data/equipment/vitality_stone.tres")
const STAFF = preload("res://data/equipment/arcane_staff.tres")
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func new_hero(settings: MatchSettings, index: int) -> HeroProgression:
	var balance := BalanceSettings.new()
	var hero := HeroProgression.new(UnitRuntimeState.new("hero", 0, Vector2.ZERO, settings.hero, balance), settings.hero, settings.hero_profiles[index], settings, balance)
	hero.select_profile_skill()
	return hero
func _run() -> void:
	var settings: MatchSettings = load("res://data/match/default_match.tres").duplicate(true)
	settings.starting_gold = 1000 # Isolated purchase tests use original reference items.
	var ranger := new_hero(settings, 0)
	var tank := new_hero(settings, 1)
	var mage := new_hero(settings, 2)
	check(tank.unit.stats.max_hp > ranger.unit.stats.max_hp and not tank.unit.stats.ranged_attacks, "Tank has own base stats and melee attack")
	check(mage.profile.display_name.begins_with("Myra") and mage.unit.stats.magic_damage == 75 and mage.passive_id == "pure_throw", "Named mage has fixed skill and magic component")
	check(ranger.award(99) == 0 and ranger.level == 1, "XP below threshold does not level")
	check(ranger.award(1) == 1 and ranger.level == 2 and ranger.experience == 0, "Exact XP threshold raises level")
	check(ranger.unit.stats.strength == 23 and ranger.unit.stats.agility == 30.2 and ranger.unit.stats.intelligence == 18.6, "Ranger gains hero-specific STR/AGI/INT")
	check(ranger.unit.stats.attack_speed > 0.5 and ranger.unit.stats.movement_speed == 281, "Ranger attack/move speed growth")
	tank.award(100)
	mage.award(100)
	check(tank.unit.stats.strength == 33.8 and tank.unit.stats.physical_armor > 10 and tank.unit.stats.base_attack_time == 1.9, "Tank prioritizes STR/armor and BAT skill")
	check(mage.unit.stats.intelligence == 33.7 and mage.unit.stats.magic_damage == 83 and mage.unit.stats.max_mana > 700, "Mage intelligence, magic and mana growth")
	check(ranger.award(400) == 2 and ranger.level == 4 and ranger.experience == 50, "Multiple levels retain overflow XP")
	ranger.award(100000)
	check(ranger.level == 20 and ranger.experience == 0, "Level cap clamps XP")
	var previous: Dictionary = ranger.unit.stats.duplicate(true)
	ranger.award(10000)
	check(previous == ranger.unit.stats, "Capped XP does not keep growing stats")
	check(settings.hero.base_hp == 1600 and settings.hero.magic_damage == 0, "Growth does not mutate shared hero source")
	var hero := new_hero(settings, 0)
	var hp_ratio: float = 800.0 / hero.unit.stats.max_hp
	hero.unit.current_hp = 800
	hero.unit.current_mana = 100
	hero.unit.next_attack_tick = 123
	hero.unit.target_id = "enemy"
	check(hero.buy(HEALTH) and hero.gold == 0, "Purchase pays price and equips")
	check(is_equal_approx(hero.unit.current_hp, hero.unit.stats.max_hp * hp_ratio), "HP ratio preserved rather than full heal on purchase")
	check(hero.unit.current_mana == 100 and hero.unit.next_attack_tick == 123 and hero.unit.target_id == "enemy", "Buying preserves mana, target and attack timer")
	check(not hero.buy(SWORD) and hero.equipment.items().size() == 1 and hero.gold == 0, "Insufficient gold rejects purchase atomically")
	hero.award(100, 1000)
	check(hero.unit.stats.max_hp > 1800 and hero.unit.current_hp > 0, "Equipment survives attribute growth and stacks once")
	check(hero.sell(0) and hero.gold == 1500 and hero.unit.stats.max_hp < 1800, "Sell refunds half and removes modifier")
	check(not hero.sell(0) and not hero.sell(-1), "Empty/invalid slot cannot generate gold")
	var exclusive: EquipmentData = SWORD.duplicate(true)
	exclusive.allow_multiple = false
	hero.gold = 10000
	check(hero.buy(exclusive) and not hero.buy(exclusive) and hero.gold == 9000, "Non-stackable item cannot be bought twice")
	for slot in range(5): check(hero.buy(HEALTH), "Fill valid remaining inventory slot")
	var coins := hero.gold
	check(not hero.buy(STAFF) and hero.gold == coins and hero.equipment.items().size() == 6, "Full inventory rejects without charging")
	check(hero.sell(2) and hero.buy(STAFF), "Sell releases slot for another item")
	hero.unit.alive = false
	hero.unit.current_hp = 0
	hero.award(500)
	check(hero.unit.current_hp == 0 and not hero.unit.alive, "Level-up does not revive a dead hero")
	await _test_scene()
	print("Progression/shop: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_scene() -> void:
	HeroProgression.selected_profile = 0
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	main.settings.creep_xp = 100
	main.settings.starting_gold = 1200
	root.add_child(main)
	await process_frame
	await physics_frame
	main.set_physics_process(false)
	main.clock.set_running(false)
	var hero: HeroProgression = main.progression.player
	check(main.shop.hero_select.item_count == 12 and main.shop.buy_buttons.size() == 29 and main.shop.slot_buttons.size() == 6, "Shop has named hero roster, expanded recipes and six slots")
	var input := InputEventKey.new()
	input.physical_keycode = KEY_B
	input.pressed = true
	root.push_input(input, true)
	check(main.shop.visible, "B opens shop through real viewport input")
	var tick: int = main.combat.tick_count
	main.shop.buy_buttons[2].pressed.emit()
	var damage_with_sword: float = hero.unit.stats.physical_damage
	check(hero.equipment.items().size() == 1 and damage_with_sword > 130 and main.combat.tick_count == tick, "Shop button equips buffed sword without restarting combat")
	check(not main.buy_item(STAFF), "Controller enforces affordability")
	main.shop.slot_buttons[0].pressed.emit()
	check(hero.gold == 850 and hero.unit.stats.physical_damage < damage_with_sword, "UI sell button removes sword")
	root.push_input(input, true)
	check(not main.shop.visible, "B closes shop")
	main.player.position = main.layout.cell_center(Vector2i(15, 24))
	main.player.runtime.position = main.player.position
	var victim: MapUnit = main._spawn("xp_victim", 1, main.settings.melee_creep, main.player.position + Vector2(100, 0), "creep", "MID")
	victim.runtime.current_hp = 1
	for info in main.entities.values(): info.actor.paused = true
	main.request_attack("creep")
	var gold_before := hero.gold
	for step in range(10): main.clock.step()
	check(not main.entities.has("xp_victim") and hero.level == 2, "Actual creep projectile kill grants XP and levels hero")
	check(hero.gold == gold_before + main.settings.creep_gold, "Last hit gives gold exactly once")
	var info := {"actor": main.enemy_hero, "kind": "hero"}
	main.enemy_hero.runtime.position = main.player.position + Vector2(100, 0)
	main.enemy_hero.position = main.enemy_hero.runtime.position
	gold_before = hero.gold
	var xp_before := hero.experience
	main._reward_death(info, "tower_00")
	check(hero.level == 2 and hero.experience == main.settings.hero_xp + main.settings.hero_xp_per_level and hero.gold == gold_before + main.settings.hero_gold + main.settings.hero_gold_per_level, "Unassisted allied tower kill grants team bounty and nearby XP")
	main.enemy_hero.position = main.player.position + Vector2(3000, 0)
	main.enemy_hero.runtime.position = main.enemy_hero.position
	xp_before = hero.experience
	var level_before := hero.level
	main._reward_death(info, "tower_00")
	check(hero.experience == xp_before and hero.level == level_before, "Distant kill awards no nearby XP")
	main._stop_player()
	main.next_wave_tick = 99999
	gold_before = hero.gold
	for step in range(60): main.clock.step()
	check(hero.gold == gold_before + main.settings.passive_gold_amount, "Passive gold uses simulation seconds")
	main.set_paused(true)
	gold_before = hero.gold
	main.clock.advance(5)
	check(hero.gold == gold_before, "Pause freezes passive income")
	main._revive("player")
	check(hero.level == level_before and hero.unit.current_hp == hero.unit.stats.max_hp, "Respawn preserves level and restores grown maximum HP")
	main.shop.show()
	main.shop.refresh()
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		hero.gold = 4000
		main.buy_item(main.shop.CATALOG[2])
		main.buy_item(main.shop.CATALOG[8])
		main._refresh_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/shop-level-preview.png") == OK, "Shop and progression rendered")
	main._end_match(0)
	check(not main.buy_item(SWORD) and not main.sell_item(0), "Ended match blocks economic commands")
	main.queue_free()
	await process_frame
	HeroProgression.selected_profile = 2
	var mage_scene = load("res://scenes/match/moba_match.tscn").instantiate()
	mage_scene.settings = mage_scene.settings.duplicate(true)
	mage_scene.settings.show_draft_on_start = false
	root.add_child(mage_scene)
	await process_frame
	check(mage_scene.player.runtime.stats.magic_damage == 75 and mage_scene.progression.player.passive_id == "pure_throw" and mage_scene.progression.player.level == 1, "New match uses named mage with fixed skill and fresh progression")
	mage_scene.queue_free()
	await process_frame
	HeroProgression.selected_profile = 0
