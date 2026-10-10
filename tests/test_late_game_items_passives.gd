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

func passive_index(id: String) -> int:
	for index in range(HeroPassiveCatalog.DEFINITIONS.size()):
		if HeroPassiveCatalog.DEFINITIONS[index].id == id: return index
	return 0

func _test_catalog_and_recipes() -> void:
	var items := MatchItemCatalog.items()
	check(items.size() == 29, "Catalog has components, unique icons, lifesteal and late-game recipes")
	var crit1 := MatchItemCatalog.by_id("critical_blade")
	var crit2 := MatchItemCatalog.by_id("critical_blade_2")
	check(crit1.modifiers.physical_damage == 25 and crit1.modifiers.critical_chance == 0.20, "Crit I requested damage/chance")
	near(StatCalculator.calculate(UnitStats.new(), BalanceSettings.new(), [crit1]).critical_multiplier, 1.2, "Crit I multiplier")
	check(crit2.modifiers.physical_damage == 80 and crit2.modifiers.critical_chance == 0.25, "Crit II requested damage/chance")
	near(StatCalculator.calculate(UnitStats.new(), BalanceSettings.new(), [crit2]).critical_multiplier, 2.5, "Crit II multiplier")
	var settings := _settings()
	var hero := _hero(settings)
	hero.gold = 10000
	check(hero.purchase_error(crit1).is_empty() and hero.purchase_cost(crit1) == crit1.price, "Large item can be bought directly for total price")
	var direct := _hero(settings)
	direct.gold = crit1.price
	check(direct.buy(crit1) and direct.equipment.count_id("critical_blade") == 1 and direct.gold == 0, "Clicking a large item directly completes the purchase")
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
	near(capped.attack_speed_cap, 3.5, "BAT 2.0 gives 3.5 APS cap at 700 percent")
	check(capped.attack_speed <= 3.5, "Items respect 700 percent attack-speed cap")
	check(MatchItemCatalog.by_id("heart").modifiers.max_hp == 2400 and MatchItemCatalog.by_id("power_treads").modifiers.strength == 15, "HP specialization and attribute boots are substantial")
	check(MatchItemCatalog.by_id("desolator").modifiers.armor_reduction == 10 and MatchItemCatalog.by_id("desolator_2").modifiers.physical_damage == 80 and MatchItemCatalog.by_id("desolator_2").modifiers.armor_reduction == 15, "Desolator I/II provide requested damage and armor reduction")
	check(MatchItemCatalog.by_id("demon_claw").modifiers.attack_speed_bonus == 1.5 and MatchItemCatalog.by_id("lifesteal_1").modifiers.lifesteal == 0.08 and MatchItemCatalog.by_id("lifesteal_2").modifiers.lifesteal == 0.15, "Demon Claw and both lifesteal tiers use requested values")
	check(MatchItemCatalog.by_id("storm_bow").icon != null and MatchItemCatalog.by_id("desolator").icon != null and MatchItemCatalog.by_id("skull_basher").icon != null and MatchItemCatalog.by_id("storm_bow").icon != MatchItemCatalog.by_id("desolator").icon, "Bow, sickle and hammer use generated distinct icons without import files")

func _test_passives() -> void:
	var settings := _settings()
	var names: Dictionary = {}
	for profile in settings.hero_profiles:
		names[profile.display_name] = true
		var source := profile.source_at_level(settings.hero, 1)
		check(not profile.passive_id.is_empty() and source.strength > 0 and source.agility > 0 and source.intelligence > 0, "Named hero has fixed skill and starting attributes: " + profile.display_name)
	check(names.size() == 12, "All twelve heroes have unique names")
	var hero := _hero(settings)
	hero.select_passive(0)
	var rank_one_damage: float = hero.unit.stats.physical_damage
	check(rank_one_damage > hero.unit.stats.base_physical_damage, "Base-power passive starts at plus 15 percent source damage")
	hero.award(100)
	check(hero.skill_points == 1 and hero.upgrade_passive() and hero.passive_level == 2, "Level-up grants selectable passive point")
	check(hero.unit.stats.physical_damage > rank_one_damage, "Passive rank combines with attribute/level growth")
	hero.select_passive(1)
	for index in range(95): hero.record_kill("creep")
	hero.record_kill("hero")
	check(hero.unit.permanent_damage_bonus == 100 and hero.unit.stats.physical_damage >= hero.unit.stats.base_physical_damage + 100, "Soul Hunter gains creep/hero damage and caps at rank-one 100")
	hero.select_passive(2)
	near(hero.unit.stats.attack_range, 630, "Long Shot adds range at rank one")
	hero.select_passive(passive_index("giant_strength"))
	check(hero.unit.stats.strength >= 41 and hero.unit.stats.max_hp > 1700, "Strength passive updates attribute-derived HP")
	hero.select_passive(passive_index("wind_agility"))
	check(hero.unit.stats.agility >= 47 and hero.unit.stats.physical_armor >= 15, "Agility passive updates armor and speed")
	hero.select_passive(passive_index("assassin"))
	near(hero.unit.stats.critical_chance, 0.15, "Assassin rank-one chance")
	near(hero.unit.stats.critical_multiplier, 2.0, "Assassin rank-one multiplier")
	hero.select_passive(passive_index("feast"))
	near(hero.unit.stats.passive_max_hp_fraction, 0.015, "Feast rank-one percent max HP")
	hero.select_passive(passive_index("pure_throw"))
	near(hero.unit.stats.passive_pure_fraction, 0.20, "Pure skill starts at 20 percent")
	hero.skill_points = 4
	for index in range(4): hero.upgrade_passive()
	near(hero.unit.stats.passive_pure_fraction, 0.40, "Pure skill scales 20/25/30/35/40 percent")
	hero.select_passive(passive_index("bat_mastery"))
	near(hero.unit.stats.base_attack_time, 1.9, "Melee BAT mastery begins at 1.9")
	hero.skill_points = 4
	for index in range(4): hero.upgrade_passive()
	near(hero.unit.stats.base_attack_time, 1.5, "Melee BAT mastery reaches 1.5")

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
	var lifesteal := MatchItemCatalog.by_id("lifesteal_2")
	engine.reset(source, target, Vector2.ZERO, Vector2(100, 0), 7, [lifesteal])
	engine.external_control = true
	engine.units[0].current_hp = 1000
	engine.units[0].target_id = "red_01"
	engine.step()
	near(engine.units[0].current_hp - 1000, (target.base_hp - engine.units[1].current_hp) * 0.15, "Lifesteal II heals 15 percent of applied attack damage")
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
	check(main.player.runtime.stats.movement_speed == 280 and main.player.runtime.stats.attack_speed_cap == 3.5, "Match hero uses slower movement and 700 percent BAT cap")
	check(main.settings.tower.attack_range == 550, "Tower range reduced")
	check(main.shop.buy_buttons.size() == 29 and main.shop.passive_select.item_count == 1 and main.shop.passive_select.disabled, "Shop exposes recipes and hero-locked skill")
	check(is_equal_approx(main.settings.tower.base_attacks_per_second, 1.0 / 3.0) and is_equal_approx(main.settings.siege_creep.base_attacks_per_second, 1.0 / 3.0), "Tower and catapult use BAT 3.0")
	check(main.settings.melee_creep.base_attacks_per_second == 0.4 and main.settings.ranged_creep.base_attacks_per_second == 0.4, "Regular creeps use BAT 2.5")
	main.toggle_shop()
	main.shop.refresh()
	check("STR" in main.shop.stats_label.text and "giảm" in main.shop.stats_label.text and "miss" in main.shop.stats_label.text and "BAT" in main.shop.stats_label.text, "Hero panel displays detailed requested combat stats")
	check("TĂNG MỖI LV" in main.shop.stats_label.text and main.settings.maximum_level == 20, "Hero draft displays per-level growth and level 20 cap")
	check("HP" in main.quick_stats.text and "Mana" in main.quick_stats.text and "AGI" in main.quick_stats.text and "BAT" in main.quick_stats.text, "Always-visible bottom panel shows compact combat stats")
	main.player.view.show_damage(10, false, DamageCalculator.DamageType.PHYSICAL)
	check(main.player.view.hit_notice_color == Color(0.25, 0.68, 1.0), "Physical damage text is blue")
	main.player.view.show_damage(10, false, DamageCalculator.DamageType.MAGICAL)
	check(main.player.view.hit_notice_color == Color.WHITE, "Magic damage text is white")
	main.player.view.show_damage(10, false, DamageCalculator.DamageType.PURE)
	check(main.player.view.hit_notice_color == Color(0.8, 0.35, 1.0), "Pure damage text is purple")
	main.player.view.show_miss()
	check(main.player.view.hit_notice == "MISS" and main.player.view.hit_notices.size() == 4, "Mixed damage colors and MISS remain simultaneously visible")
	var visible_effect := StatusEffect.new()
	visible_effect.kind = StatusEffect.Kind.STUN
	visible_effect.instance_id = "ui_bash"
	visible_effect.source_unit_id = "enemy_hero"
	visible_effect.target_unit_id = "player"
	visible_effect.expires_at_tick = 30
	main.player.runtime.effects.apply(visible_effect)
	check("CHOÁNG" in main.player.view.status_labels(), "Bash/stun status is displayed explicitly")
	var visible_slow := StatusEffect.new()
	visible_slow.kind = StatusEffect.Kind.ATTACK_SLOW
	visible_slow.instance_id = "ui_slow"
	visible_slow.source_unit_id = "enemy_hero"
	visible_slow.target_unit_id = "player"
	visible_slow.expires_at_tick = 30
	main.player.runtime.effects.apply(visible_slow)
	check("CHẬM ĐÁNH" in main.player.view.status_labels(), "Attack slow status is displayed explicitly")
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
	check(draft.draft_mode and draft.paused and draft.shop.visible and draft.shop.close_button.disabled, "Fresh game requires named-hero draft before simulation")
	check(draft.shop.hero_select.item_count == 12 and draft.shop.passive_select.item_count == 1, "Draft offers twelve named heroes with one fixed skill each")
	draft.shop.hero_select.select(1)
	draft.shop.hero_select.item_selected.emit(1)
	check("Nhịp Chiến" in draft.shop.passive_select.get_item_text(0) and "Brakk" in draft.shop.header.text and "BAT 1.9s" in draft.shop.stats_label.text, "Changing hero previews that hero's locked skill and full stats")
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
