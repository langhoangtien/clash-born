extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _run() -> void:
	_test_siege()
	await _test_match()
	if "--controlled-soak" in OS.get_cmdline_user_args(): await _test_controlled_soak()
	elif "--soak" in OS.get_cmdline_user_args(): await _test_soak()
	print("Match balance/navigation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_siege() -> void:
	var source := UnitStats.new()
	source.physical_damage = 100
	source.magic_damage = 50
	source.pure_damage = 10
	source.attack_range = 1000
	source.base_attacks_per_second = 0.05
	source.attacks_can_miss = false
	source.attacks_can_crit = false
	var building := UnitStats.new()
	building.base_hp = 10000
	var engine := CombatEngine.new(BalanceSettings.new())
	engine.external_control = true
	engine.reset(source, building, Vector2.ZERO, Vector2(200, 0))
	engine.units[0].structure_damage_multiplier = 0.4
	engine.units[1].is_structure = true
	engine.units[0].target_id = "red_01"
	engine.step()
	check(is_equal_approx(engine.units[1].current_hp, 10000 - 64), "Hero siege multiplier applies to all damage types")
	engine.units[1].is_structure = false
	engine.units[0].next_attack_tick = engine.tick_count + 1
	engine.step()
	check(is_equal_approx(engine.units[1].current_hp, 10000 - 64 - 160), "Unit damage remains unscaled")
	engine.units[1].is_structure = true
	engine.units[0].structure_damage_multiplier = 0.65
	engine.units[0].next_attack_tick = engine.tick_count + 1
	engine.step()
	check(is_equal_approx(engine.units[1].current_hp, 10000 - 64 - 160 - 104), "Creep siege modifier is independent")
	source.ranged_attacks = true
	engine.reset(source, building, Vector2.ZERO, Vector2(200, 0))
	engine.units[0].structure_damage_multiplier = 0.4
	engine.units[1].is_structure = true
	engine.units[0].target_id = "red_01"
	engine.step()
	check(engine.units[1].current_hp == 10000, "Siege projectile still damages only at impact")
	engine.units[0].alive = false
	engine.units[0].structure_damage_multiplier = 1
	for tick in range(10): engine.step()
	check(is_equal_approx(engine.units[1].current_hp, 10000 - 64), "Projectile snapshots siege modifier and survives source death")

func _test_match() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	main.settings.maximum_live_creeps = 0
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.clock.set_running(false)
	for info in main.entities.values(): info.actor.paused = true
	check(main.settings.tower.base_hp == 5000 and main.settings.tower.physical_damage == 220, "Towers use the revised siege tuning")
	check(main.settings.core.base_hp == 10000 and main.player.runtime.stats.physical_damage > 110 and main.progression.player.profile.display_name.begins_with("Aelira"), "Core durability and named hero skill applied")
	check(main.progression.player.gold == 250, "Opening budget cannot buy a full damage item")
	var original = preload("res://scripts/ui/equipment_panel.gd").CATALOG
	var catalog := MatchItemCatalog.items()
	for index in range(catalog.size()):
		check(catalog[index].icon != null and catalog[index].icon.get_width() > 0, "Equipment icon loads: " + catalog[index].id)
	check(original[7].modifiers.physical_damage == 60 and MatchItemCatalog.by_id("heavy_sword").modifiers.physical_damage == 25, "Buffed match sword; Sandbox source intact")
	check(MatchItemCatalog.by_id("critical_blade_2").modifiers.physical_damage == 80 and MatchItemCatalog.by_id("swift_gloves").modifiers.attack_speed_bonus == 0.40, "Late offense and component attack speed buffed")
	var opening_tick: int = main.combat.tick_count
	for tick in range(59 - opening_tick): main.clock.step()
	check(main.progression.player.gold == 250, "No passive gold before two seconds")
	main.clock.step()
	check(main.progression.player.gold == 251, "Passive income is one gold per two seconds")
	main.progression.enemy_hero.gold = 650
	for tick in range(240): main.clock.step()
	check(main.progression.enemy_hero.equipment.items().size() == 1, "Bot buys gear through the same budget/shop rules")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	key.pressed = true
	root.push_input(key, true)
	check(main.opponent_panel.visible and not main.shop.visible, "Tab opens equipment comparison")
	check(main.opponent_panel.slot_buttons.enemy_hero[0].icon != null and "Giày Tốc Độ" in main.opponent_panel.slot_buttons.enemy_hero[0].tooltip_text, "Opponent actual equipped icon/tooltip displayed")
	root.push_input(key, true)
	check(not main.opponent_panel.visible, "Tab closes equipment comparison")
	# Six physical lane recovery runs after a chase into another lane/jungle edge.
	var probes: Array[Dictionary] = []
	for team in range(2):
		for lane in ["TOP", "MID", "BOT"]:
			var actor: MapUnit = main._spawn("resume_%d_%s" % [team, lane], team, main.settings.melee_creep, main.layout.spawn_points(team)[0], "creep", lane)
			actor.runtime.stats.movement_speed = 5000
			var cell := Vector2i(15, 24) if team == 0 else Vector2i(24, 15)
			if lane == "MID": cell = Vector2i(5, 24) if team == 0 else Vector2i(34, 15)
			actor.position = main.layout.cell_center(cell)
			actor.runtime.position = actor.position
			var info: Dictionary = main.entities[actor.runtime.unit_id]
			info.chasing = true
			main._drive_target(info, null, 1)
			check(actor.path.size() > 1, "Lane recovery finds A* route for %d/%s" % [team, lane])
			probes.append(info)
	for frame in range(720):
		await physics_frame
		for info in probes: main._drive_target(info, null, frame + 2)
	for info in probes:
		var actor: MapUnit = info.actor
		check(actor.position.distance_to(main.layout.spawn_points(1 - actor.runtime.team_id)[0]) < 12, "Recovered creep reaches opposing base on " + info.lane)
		check(actor.navigation.point_is_clear(actor.position), "Recovered creep respects collision on " + info.lane)
	# Three types share one combat engine, now visually distinguishable.
	main.settings.maximum_live_creeps = 108
	main.spawn_wave()
	var melee := 0
	var ranged := 0
	for id in main.entities:
		if id.begins_with("creep_"):
			if main.entities[id].get("siege", false): continue
			if main.entities[id].actor.runtime.stats.ranged_attacks: ranged += 1
			else: melee += 1
	check(melee == 12 and ranged == 6, "Regular wave units remain two melee and one ranged per team/lane")
	var top: Dictionary = main.entities.resume_0_TOP
	var wrong_lane: Dictionary = main.entities.resume_1_BOT
	wrong_lane.actor.position = top.actor.position + Vector2(20, 0)
	wrong_lane.actor.runtime.position = wrong_lane.actor.position
	check(main._choose_target(top, ["creep"], 25) != wrong_lane.actor, "Creeps do not abandon their lane to acquire other-lane creeps")
	if not main.entities.has("jungle_00_0"): main.spawn_jungle_camps()
	var camp_info: Dictionary = main.entities["jungle_00_0"]
	main.player.position = camp_info.camp_center
	main.player.runtime.position = main.player.position
	main.settings.hero_acquisition_range = 300.0
	main.request_attack("creep")
	var jungle_target: MapUnit = main._player_target()
	check(jungle_target != null and main.entities[jungle_target.runtime.unit_id].get("neutral", false), "Player creep command can select a nearby jungle creep")
	# A level-six bot has an unspent point after its only five-rank skill is full.
	# The AI must leave that point for future skills instead of retrying forever.
	var bot: HeroProgression = main.progression.enemy_hero
	bot.passive_level = 5
	bot.skill_points = 1
	var before_skill_tick: int = main.combat.tick_count
	main.clock.step()
	check(main.combat.tick_count == before_skill_tick + 1 and bot.skill_points == 1, "Bot with a max-rank skill cannot freeze the match tick")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		main.toggle_opponents()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/opponent-equipment.png") == OK, "Equipment comparison rendered")
		main.toggle_shop()
		main.progression.player.gold = 2500
		main.shop.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/balanced-shop.png") == OK, "Shop icons and balanced prices rendered")
	main.queue_free()
	await process_frame

func _test_soak() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	root.add_child(main)
	var lane_damage: Dictionary = {"TOP": 0.0, "MID": 0.0, "BOT": 0.0}
	var samples: Dictionary = {}
	var stalled: Array[String] = []
	var target_ticks := 10800 if "--long-soak" in OS.get_cmdline_user_args() else 5400
	var frame_budget := 60 * (361 if target_ticks > 5400 else 181)
	var last_report_usec := Time.get_ticks_usec()
	for frame in range(frame_budget):
		await physics_frame
		if frame % 600 == 0:
			var now := Time.get_ticks_usec()
			var load := _runtime_load(main)
			print("Soak progress: tick=%d entities=%d projectiles=%d metrics=%d effects=%d paths=%d notices=%d memory=%.1fMB nodes=%d wall=%.2fs" % [main.combat.tick_count, main.entities.size(), main.combat.projectiles.size(), main.combat.metrics.by_unit.size(), load.effects, load.paths, load.notices, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), (now - last_report_usec) / 1000000.0])
			last_report_usec = now
		if frame % 240 == 0:
			for id in main.entities:
				var info: Dictionary = main.entities[id]
				var actor: MapUnit = info.actor
				if info.kind != "creep" or not actor.runtime.alive: continue
				var navigating: bool = actor.runtime.target_id.is_empty() and info.route_index < info.route.size() - 1
				var old: Dictionary = samples.get(id, {"point": actor.position, "idle": 0})
				var idle: int = old.idle + 1 if navigating and actor.position.distance_to(old.point) < 2 else 0
				samples[id] = {"point": actor.position, "idle": idle}
				if idle >= 3 and id not in stalled: stalled.append(id)
		if main.match_over or main.combat.tick_count >= target_ticks: break
	for id in main.combat.metrics.by_unit:
		for lane in lane_damage:
			if ("_" + lane + "_") in id: lane_damage[lane] += main.combat.metrics.by_unit[id].damage_dealt
	check(not main.match_over and main.combat.tick_count >= target_ticks, "Default autonomous match remains playable through the soak duration")
	for lane in lane_damage: check(lane_damage[lane] > 0, "Live creep combat occurs on " + lane)
	check(stalled.is_empty(), "No creep stalls without a target for eight simulation seconds: " + str(stalled))
	print("Match soak: tick=%d waves=%d cores=%.0f/%.0f lane_damage=%s" % [main.combat.tick_count, main.wave_number, main.cores[0].runtime.current_hp, main.cores[1].runtime.current_hp, str(lane_damage)])
	main.queue_free()
	await process_frame

func _test_controlled_soak() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	root.add_child(main)
	var target_ticks := 10800
	var last_report_usec := Time.get_ticks_usec()
	var directions := [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]
	var movement_origin: Vector2 = main.player.position
	var moved_with_controls := false
	var creep_command_accepted := false
	var hero_command_accepted := false
	for frame in range(60 * 361):
		await physics_frame
		var phase := frame % 480
		if phase == 0:
			main.controls.direction = directions[int(frame / 480) % directions.size()]
			movement_origin = main.player.position
		elif phase == 120:
			moved_with_controls = moved_with_controls or main.player.position.distance_to(movement_origin) > 20.0
			main.controls.direction = Vector2.ZERO
			main.request_attack("creep")
			creep_command_accepted = creep_command_accepted or main.attack_mode == "creep"
		elif phase == 240:
			main.request_attack("hero")
			hero_command_accepted = hero_command_accepted or main.attack_mode == "hero"
		elif phase == 360:
			main._stop_player()
			main.camera.follow_enabled = not main.camera.follow_enabled
		if frame % 600 == 0:
			var now := Time.get_ticks_usec()
			var load := _runtime_load(main)
			print("Controlled soak: tick=%d entities=%d projectiles=%d metrics=%d effects=%d paths=%d notices=%d memory=%.1fMB nodes=%d wall=%.2fs" % [main.combat.tick_count, main.entities.size(), main.combat.projectiles.size(), main.combat.metrics.by_unit.size(), load.effects, load.paths, load.notices, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), (now - last_report_usec) / 1000000.0])
			last_report_usec = now
		if main.match_over or main.combat.tick_count >= target_ticks: break
	main.controls.direction = Vector2.ZERO
	check(not main.match_over and main.combat.tick_count >= target_ticks, "Controlled match remains responsive for six simulation minutes")
	check(moved_with_controls, "Four-direction controls move the player during the soak")
	check(creep_command_accepted and hero_command_accepted, "Creep/structure and hero attack controls remain responsive")
	print("Controlled soak complete: tick=%d waves=%d entities=%d" % [main.combat.tick_count, main.wave_number, main.entities.size()])
	main.queue_free()
	await process_frame

func _runtime_load(main) -> Dictionary:
	var effects := 0
	var paths := 0
	var notices := 0
	for info in main.entities.values():
		effects += info.actor.runtime.effects.active.size()
		paths += info.actor.path.size()
		notices += info.actor.view.hit_notices.size()
	return {"effects": effects, "paths": paths, "notices": notices}
