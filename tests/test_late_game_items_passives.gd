extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func near(a: float, b: float, label: String) -> void: check(is_equal_approx(a, b), "%s (%.3f != %.3f)" % [label, a, b])
func _run() -> void:
	_test_catalog_and_recipes()
	_test_passives()
	_test_combat_effects()
	await _test_match_ui()
	print("Late-game items/passives: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _settings() -> MatchSettings:
	return load("res://data/match/default_match.tres").duplicate(true)

func _hero(settings: MatchSettings) -> HeroProgression:
	var state := UnitRuntimeState.new("hero", 0, Vector2.ZERO, settings.hero, BalanceSettings.new())
	return HeroProgression.new(state, settings.hero, settings.hero_profiles[0], settings, BalanceSettings.new())

func _test_catalog_and_recipes() -> void:
	var items := MatchItemCatalog.items()
	check(items.size() == 23, "Catalog has components and late-game recipes")
	var crit1 := MatchItemCatalog.by_id("critical_blade")
	var crit2 := MatchItemCatalog.by_id("critical_blade_2")
	check(crit1.modifiers.physical_damage == 25 and crit1.modifiers.critical_chance == 0.20, "Crit I requested damage/chance")
	near(StatCalculator.calculate(UnitStats.new(), BalanceSettings.new(), [crit1]).critical_multiplier, 1.2, "Crit I multiplier")
	check(crit2.modifiers.physical_damage == 80 and crit2.modifiers.critical_chance == 0.25, "Crit II requested damage/chance")
	near(StatCalculator.calculate(UnitStats.new(), BalanceSettings.new(), [crit2]).critical_multiplier, 2.5, "Crit II multiplier")
	var settings := _settings()
	var hero := _hero(settings)
	hero.gold = 10000
	check("Thiếu nguyên liệu" in hero.purchase_error(crit1), "Recipe rejects purchase without component")
	check(hero.buy(MatchItemCatalog.by_id("heavy_sword")), "Buy sword component")
	var gold := hero.gold
	check(hero.buy(crit1) and hero.gold == gold - crit1.recipe_cost, "Craft consumes component and charges recipe fee")
	check(hero.equipment.count_id("heavy_sword") == 0 and hero.equipment.count_id("critical_blade") == 1, "Craft replaces component in inventory")
	check(hero.buy(MatchItemCatalog.by_id("heavy_sword")), "Buy second sword for Crit II")
	gold = hero.gold
	check(hero.buy(crit2) and hero.gold == gold - crit2.recipe_cost, "Crit II crafts from Crit I plus sword")
	check(hero.equipment.count_id("critical_blade_2") == 1 and hero.equipment.items().size() == 1, "Upgrade leaves one final item")
	var full := _hero(settings)
	full.gold = 20000
	for index in range(2): check(full.buy(MatchItemCatalog.by_id("vitality_stone")), "Full-slot recipe component vitality")
	check(full.buy(MatchItemCatalog.by_id("ogre_axe")), "Full-slot recipe component strength")
	for index in range(3): check(full.buy(MatchItemCatalog.by_id("boots")), "Fill remaining slot")
	check(full.equipment.items().size() == 6 and full.buy(MatchItemCatalog.by_id("heart")), "Recipe can craft while all six slots occupied")
	check(full.equipment.items().size() == 4 and full.equipment.count_id("heart") == 1, "Three components become one item")
	var capped := StatCalculator.calculate(settings.hero, BalanceSettings.new(), [MatchItemCatalog.by_id("swift_gloves"), MatchItemCatalog.by_id("butterfly"), MatchItemCatalog.by_id("assault_armor")])
	near(capped.attack_speed_cap, 2.5, "BAT 2.0 gives 2.5 APS cap at 500 percent")
	check(capped.attack_speed <= 2.5, "Items respect 500 percent attack-speed cap")
	check(MatchItemCatalog.by_id("heart").modifiers.max_hp == 2400 and MatchItemCatalog.by_id("power_treads").modifiers.strength == 15, "HP specialization and attribute boots are substantial")

func _test_passives() -> void:
	var settings := _settings()
	var hero := _hero(settings)
	hero.select_passive(0)
	near(hero.unit.stats.physical_damage, 115, "Base-power passive starts at plus 15 percent base damage")
	hero.award(100)
	check(hero.skill_points == 1 and hero.upgrade_passive() and hero.passive_level == 2, "Level-up grants selectable passive point")
	near(hero.unit.stats.physical_damage, 139.1, "Passive rank combines with level growth base damage")
	hero.select_passive(1)
	for index in range(95): hero.record_kill("creep")
	hero.record_kill("hero")
	check(hero.unit.permanent_damage_bonus == 100 and hero.unit.stats.physical_damage == 207, "Soul Hunter gains creep/hero damage and caps at 100")
	hero.select_passive(2)
	near(hero.unit.stats.attack_range, 630, "Long Shot adds range at rank one")
	hero.select_passive(7)
	check(hero.unit.stats.strength == 20 and hero.unit.stats.max_hp >= 2120, "Strength passive updates attribute-derived HP")
	hero.select_passive(8)
	check(hero.unit.stats.agility == 20 and hero.unit.stats.physical_armor >= 11, "Agility passive updates armor and speed")
	hero.select_passive(9)
	near(hero.unit.stats.critical_chance, 0.15, "Assassin rank-one chance")
	near(hero.unit.stats.critical_multiplier, 2.0, "Assassin rank-one multiplier")
	hero.select_passive(10)
	near(hero.unit.stats.passive_max_hp_fraction, 0.015, "Feast rank-one percent max HP")

func _unit(hp: float = 2000, damage: float = 100) -> UnitStats:
	var unit := UnitStats.new()
	unit.base_hp = hp
	unit.physical_damage = damage
	unit.attack_range = 1000
	unit.base_attacks_per_second = 0.5
	unit.attacks_can_miss = false
	unit.attacks_can_crit = false
	return unit

func _test_combat_effects() -> void:
	var source := _unit()
	var target := _unit()
	var bash := MatchItemCatalog.by_id("skull_basher").duplicate(true)
	bash.modifiers.bash_chance = 1.0
	var engine := CombatEngine.new(BalanceSettings.new())
	engine.external_control = true
	engine.reset(source, target, Vector2.ZERO, Vector2(100, 0), 7, [bash])
	engine.external_control = true
	engine.units[0].target_id = "red_01"
	engine.step()
	check(engine.units[1].effects.is_stunned(), "Guaranteed basher applies stun on hit")
	check(engine.units[1].current_hp < target.base_hp - source.physical_damage, "Bash adds bonus physical damage")
	source.ranged_attacks = true
	source.projectile_speed = 300
	engine.reset(source, target, Vector2.ZERO, Vector2(600, 0), 7, [bash])
	engine.external_control = true
	engine.units[0].target_id = "red_01"
	engine.step()
	check(not engine.units[1].effects.is_stunned() and engine.units[1].current_hp == target.base_hp, "Ranged bash does nothing at projectile launch")
	for tick in range(90):
		engine.step()
		if engine.units[1].effects.is_stunned(): break
	check(engine.units[1].effects.is_stunned() and engine.units[1].current_hp < target.base_hp, "Ranged bash resolves only at impact")
	source.ranged_attacks = false
	var frost := MatchItemCatalog.by_id("frost_armor")
	engine.reset(source, target, Vector2.ZERO, Vector2(100, 0), 7, [], [frost])
	engine.external_control = true
	engine.units[0].target_id = "red_01"
	engine.step()
	near(engine.units[0].effects.strongest_attack_slow(), 0.35, "Frost armor slows attack speed of attacker")
	near(engine.units[0].attack_speed(), engine.units[0].stats.attack_speed * 0.65, "Attack slow changes effective APS")
	var reflect := MatchItemCatalog.by_id("blade_mail")
	engine.reset(source, target, Vector2.ZERO, Vector2(100, 0), 7, [], [reflect])
	engine.external_control = true
	engine.units[0].target_id = "red_01"
	engine.step()
	var reflected := DamageCalculator.calculate(100, DamageCalculator.DamageType.PHYSICAL, 20, 0, BalanceSettings.new()) * 0.15
	near(engine.units[0].current_hp, source.base_hp - reflected, "Reflect returns 15 percent of applied attack damage as pure")
	check(engine.units[1].current_hp < target.base_hp, "Original reflected attack still damages defender")
	var feast_state := UnitRuntimeState.new("blue", 0, Vector2.ZERO, source, BalanceSettings.new())
	feast_state.passive_id = "feast"
	feast_state.passive_level = 1
	feast_state.stats.passive_max_hp_fraction = 0.015
	engine.reset(source, target, Vector2.ZERO, Vector2(100, 0), 7)
	engine.external_control = true
	engine.units[0].passive_id = "feast"
	engine.units[0].passive_level = 1
	engine.units[0].stats.passive_max_hp_fraction = 0.015
	engine.units[0].target_id = "red_01"
	engine.step()
	near(engine.units[1].current_hp, 1870, "Feast adds 1.5 percent max-HP pure damage")

func _test_match_ui() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	main.settings.maximum_live_creeps = 0
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.clock.set_running(false)
	check(main.player.runtime.stats.movement_speed == 320 and main.player.runtime.stats.attack_speed_cap == 2.5, "Match hero uses slower movement and BAT 2.0 cap")
	check(main.settings.tower.attack_range == 600, "Tower range reduced")
	check(main.shop.buy_buttons.size() == 23 and main.shop.passive_select.item_count == 11, "Shop exposes recipe catalog and passive chooser")
	main.toggle_shop()
	main.shop.refresh()
	check("STR" in main.shop.stats_label.text and "giảm" in main.shop.stats_label.text and "miss" in main.shop.stats_label.text and "BAT" in main.shop.stats_label.text, "Hero panel displays detailed requested combat stats")
	main.progression.player.award(100)
	main.shop.refresh()
	check(not main.shop.passive_upgrade.disabled, "Earned skill point enables passive upgrade button")
	main.shop.passive_upgrade.pressed.emit()
	check(main.progression.player.passive_level == 2, "UI button spends a point on selected passive")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/late-game-shop.png") == OK, "Detailed late-game shop rendered")
	main.queue_free()
	await process_frame
	var draft = load("res://scenes/match/moba_match.tscn").instantiate()
	draft.settings = draft.settings.duplicate(true)
	draft.settings.maximum_live_creeps = 0
	root.add_child(draft)
	await process_frame
	check(draft.draft_mode and draft.paused and draft.shop.visible and draft.shop.close_button.disabled, "Fresh game requires hero and passive draft before simulation")
	check(draft.shop.hero_select.item_count == 3 and draft.shop.passive_select.item_count == 11, "Draft offers hero and starting passive")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/hero-passive-draft.png") == OK, "Hero/passive draft rendered")
	draft.queue_free()
	await process_frame
	HeroProgression.draft_confirmed = true
	var confirmed = load("res://scenes/match/moba_match.tscn").instantiate()
	confirmed.settings = confirmed.settings.duplicate(true)
	confirmed.settings.maximum_live_creeps = 0
	root.add_child(confirmed)
	await process_frame
	check(not confirmed.draft_mode and not confirmed.paused and not confirmed.shop.visible and not HeroProgression.draft_confirmed, "Confirmed draft starts exactly one match instead of reopening forever")
	confirmed.queue_free()
	await process_frame
