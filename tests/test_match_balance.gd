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
	var args := OS.get_cmdline_user_args()
	if "--controlled-soak" in args: await _test_controlled_soak()
	elif "--soak" in args or "--long-soak" in args or "--medium-soak" in args or "--smoke-soak" in args: await _test_soak()
	print("Match balance/navigation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_siege() -> void:
	var audio_router = preload("res://scripts/match/match_audio_router.gd").new()
	check(audio_router.can_hear(Vector2(900, 0), Vector2.ZERO, 1000) and not audio_router.can_hear(Vector2(1001, 0), Vector2.ZERO, 1000), "Combat audio is limited to the active listener radius")
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
	check(main._can_apply_match_damage({}, null, main.player.runtime), "Projectile impact remains safe after its removed source no longer exists")
	var expired_event := {"kind": "damage", "source_unit_id": "removed_creep", "target_unit_id": main.player.runtime.unit_id, "damage_type": DamageCalculator.DamageType.PHYSICAL, "applied_damage": 1.0}
	var received_before: float = main.combat.metrics.by_unit[main.player.runtime.unit_id].damage_received
	var expired_events: Array[Dictionary] = [expired_event]
	main.combat.metrics.consume(expired_events)
	check(is_equal_approx(main.combat.metrics.by_unit[main.player.runtime.unit_id].damage_received, received_before + 1.0), "Metrics safely ignore a removed projectile source while keeping target damage")
	var brush_point: Vector2 = main.layout.cell_center(Vector2i(main.layout.brush_cells[0]))
	var brush_enemy: MapUnit = main._spawn("brush_enemy", 1, main.settings.melee_creep, brush_point, "creep", "JUNGLE")
	main.player.position = brush_point + Vector2(650, 0)
	main.player.runtime.position = main.player.position
	check(not main._has_vision(main.player, brush_enemy), "Enemy inside brush is hidden from a player outside brush")
	main.player.position = brush_point
	main.player.runtime.position = main.player.position
	check(main._has_vision(main.player, brush_enemy), "Player entering brush reveals enemy in the same brush")
	# Keep this vision-only fixture out of later farming/AI target selection.
	brush_enemy.position = brush_point + Vector2(3000, 0)
	brush_enemy.runtime.position = brush_enemy.position
	var allied_observer: MapUnit = main._spawn("vision_creep", 0, main.settings.melee_creep, Vector2(3800, 1100), "creep", "TOP")
	brush_enemy.position = allied_observer.position + Vector2(300, 0)
	brush_enemy.runtime.position = brush_enemy.position
	main.player.position = main.layout.cell_center(Vector2i(4, 35))
	main.player.runtime.position = main.player.position
	main._update_vision()
	check(brush_enemy.view.visible, "Allied creep vision reveals nearby enemies outside the player's personal sight")
	# A healthy bot must continue behind a winning allied wave instead of falling
	# back to its tower after the opposing wave has been cleared.
	var bot_info: Dictionary = main.entities.enemy_hero
	var bot_actor: MapUnit = bot_info.actor
	bot_actor.position = main.get_defensive_anchor(1, "MID")
	bot_actor.runtime.position = bot_actor.position
	bot_actor.runtime.current_hp = bot_actor.runtime.stats.max_hp
	bot_info.ai_state = "GO_TO_LANE"
	var red_frontline: MapUnit = main._spawn("bot_frontline", 1, main.settings.melee_creep, main.layout.route("MID", 1)[1], "creep", "MID")
	red_frontline.runtime.current_hp = red_frontline.runtime.stats.max_hp
	var front_progress: float = main._lane_progress(red_frontline.position, "MID", 1)
	var expected_rally: Vector2 = main._lane_point_at_progress("MID", 1, front_progress - main.settings.bot_frontline_trail_distance)
	main.entities[bot_actor.runtime.unit_id] = bot_info
	for unused in range(4): main._tick(unused)
	var persisted_bot: Dictionary = main.entities[bot_actor.runtime.unit_id]
	check(persisted_bot.get("movement_source", "") == "frontline-rally", "Healthy bot receives a persisted movement order to follow its surviving lane wave")
	check(Vector2(persisted_bot.get("movement_destination", Vector2.ZERO)).distance_to(expected_rally) < 2.0, "Bot rally point trails the wave by a fixed lane distance instead of moving toward base")
	# Creep hero aggro is a deliberate, short retaliation rather than ordinary
	# lane targeting. It must expire at its leash instead of dragging a wave home.
	var leash_creep: MapUnit = main._spawn("hero_leash_creep", 0, main.settings.melee_creep, Vector2(2600, 2600), "creep", "MID")
	var leash_info: Dictionary = main.entities[leash_creep.runtime.unit_id]
	bot_actor.position = leash_creep.position + Vector2(main.settings.creep_hero_leash_range + 80.0, 0)
	bot_actor.runtime.position = bot_actor.position
	leash_creep.runtime.target_id = bot_actor.runtime.unit_id
	leash_info.creep_chase_origin = leash_creep.position
	leash_info.hero_aggro_until = main.combat.tick_count + main.settings.creep_hero_aggro_ticks
	main.entities[leash_creep.runtime.unit_id] = leash_info
	check(main._choose_lane_creep_target(leash_info, main.combat.tick_count + 1) != bot_actor and leash_creep.runtime.target_id.is_empty(), "Lane creep drops a hero beyond its retaliation leash instead of chasing through towers")
	# Normal lane scanning must never pick a hero merely because no enemy creep is
	# nearby. Only _arm_lane_defenders may install a hero target.
	bot_actor.position = leash_creep.position + Vector2(100.0, 0)
	bot_actor.runtime.position = bot_actor.position
	leash_info = main.entities[leash_creep.runtime.unit_id]
	leash_info.creep_reacquire_after = 0
	main.entities[leash_creep.runtime.unit_id] = leash_info
	var ordinary_target: MapUnit = main._choose_lane_creep_target(leash_info, main.combat.tick_count + 2)
	check(ordinary_target != bot_actor, "Lane creep does not auto-acquire a nearby enemy hero")
	# A tower shot creates only a local exit order. It is distinct from the
	# fountain-recovery state and must not send a healthy bot all the way home.
	var blue_mid_t1: MapUnit = main.entities[main.tower_registry["blue_mid_t1"]].actor
	bot_actor.position = blue_mid_t1.position + Vector2(40, 0)
	bot_actor.runtime.position = bot_actor.position
	bot_actor.runtime.current_hp = bot_actor.runtime.stats.max_hp
	blue_mid_t1.runtime.target_id = bot_actor.runtime.unit_id
	bot_info = main.entities[bot_actor.runtime.unit_id]
	var tower_escape_target: MapUnit = main._bot_target(bot_info, main.combat.tick_count + 3)
	check(tower_escape_target == null and main.entities[bot_actor.runtime.unit_id].ai_state == "EXIT_TOWER_RANGE", "Healthy bot enters local tower-exit state instead of fountain retreat")
	main._drive_bot(main.entities[bot_actor.runtime.unit_id], tower_escape_target, main.combat.tick_count + 3)
	check(main.entities[bot_actor.runtime.unit_id].get("movement_source", "") == "tower-range-escape", "Tower-exit state issues only an outside-range movement order")
	blue_mid_t1.runtime.target_id = ""
	# A recovered bot clears hostile lane creeps that actually reached its base
	# before returning to its forward rally point.
	var base_intruder: MapUnit = main._spawn("base_intruder", 0, main.settings.melee_creep, main.layout.fountain_point(1) + Vector2(180, 0), "creep", "MID")
	bot_actor.position = main.layout.fountain_point(1)
	bot_actor.runtime.position = bot_actor.position
	bot_info = main.entities[bot_actor.runtime.unit_id]
	bot_info.assigned_lane = "MID"
	bot_info.ai_state = "GO_TO_LANE"
	bot_actor.runtime.current_hp = bot_actor.runtime.stats.max_hp
	main.entities[bot_actor.runtime.unit_id] = bot_info
	check(main._bot_base_intruder(bot_info, "MID") == base_intruder, "Recovered bot recognizes hostile lane creeps that reached its fountain area")
	check(main._bot_target(bot_info, main.combat.tick_count + 3) == base_intruder, "Recovered bot targets a base intruder before attempting to rally forward")
	# Retaliation metadata survives the helper boundary: this is what enforces the
	# short hero leash for a wave protecting its own hero.
	main.player.position = bot_actor.position + Vector2(120, 0)
	main.player.runtime.position = main.player.position
	var response_creep: MapUnit = main._spawn("response_creep", 1, main.settings.melee_creep, bot_actor.position + Vector2(45, 0), "creep", "MID")
	main._arm_lane_defenders({"source_unit_id": main.player.runtime.unit_id, "target_unit_id": bot_actor.runtime.unit_id, "reflected": false})
	var response_info: Dictionary = main.entities[response_creep.runtime.unit_id]
	check(response_info.get("retaliation_target_id", "") == main.player.runtime.unit_id, "Nearby lane creep receives direct hero-aggression retaliation fact")
	check(int(response_info.get("hero_aggro_until", 0)) == main.combat.tick_count + main.settings.creep_hero_aggro_ticks, "Hero retaliation leash metadata persists in the runtime registry")
	var retaliation_target: MapUnit = main._choose_lane_creep_target(response_info, main.combat.tick_count + 1)
	main._drive_lane_creep(main.entities[response_creep.runtime.unit_id], retaliation_target, main.combat.tick_count + 1)
	check(response_creep.runtime.target_id == main.player.runtime.unit_id and main.entities[response_creep.runtime.unit_id].creep_state == "HERO_RETALIATE", "Only the lane-creep state machine turns retaliation into a combat target")
	check(main.settings.tower_t1_hp == 3200 and main.settings.tower_t4_hp == 4200 and main.settings.tower_t1_damage < main.settings.tower_t4_damage, "Tower durability is reduced while damage increases toward T4")
	var red_guards := [main.entities[main.tower_registry["red_base_guard_left"]].actor, main.entities[main.tower_registry["red_base_guard_right"]].actor]
	check(not main._core_is_unlocked(1), "Living T4 guards keep the red core locked")
	for info in main.entities.values():
		if info.kind == "tower" and info.actor not in red_guards: info.actor.runtime.alive = false
	check(not main._core_is_unlocked(1), "Only the two T4 guards gate the core after lane towers fall")
	red_guards[0].runtime.alive = false
	check(not main._core_is_unlocked(1), "One remaining T4 guard still locks the core")
	# Once all three lane chains are gone, the shared T4 guards are the next
	# attackable structures for every lane rather than an unreachable dead end.
	var t4_target: MapUnit = main.get_next_attackable_structure(0, "MID")
	check(t4_target == red_guards[1], "T4 guard becomes the next legal structure after all lane T3 towers fall")
	main.player.position = red_guards[1].position + Vector2(100, 0)
	main.player.runtime.position = main.player.position
	main.request_attack("creep")
	main.locked_target = red_guards[1].runtime.unit_id
	check(main._player_target() == red_guards[1], "Player structure command can acquire an unlocked T4 guard")
	red_guards[1].runtime.alive = false
	check(main._core_is_unlocked(1), "Destroying both T4 guards unlocks the core")
	# J at a jungle camp must farm the nearby neutral before a lane creep/trụ.
	var red_mid_t1: MapUnit = main.entities[main.tower_registry["red_mid_t1"]].actor
	red_mid_t1.runtime.alive = true
	var camp_center: Vector2 = main.layout.cell_center(Vector2i(main.layout.jungle_camps[0]))
	main.player.position = camp_center
	main.player.runtime.position = main.player.position
	var priority_creep: MapUnit = main._spawn("priority_creep", 1, main.settings.melee_creep, main.player.position + Vector2(80, 0), "creep", "MID")
	if not main.entities.has("jungle_00_0"):
		main.spawn_jungle_camps()
		main.jungle_spawned = true
	main.request_attack("creep")
	var camp_target: MapUnit = main._player_target()
	check(camp_target != null and main.entities[camp_target.runtime.unit_id].get("neutral", false), "J attack selection prioritizes a nearby jungle camp over lane creep and tower")
	# A fully cleared camp gets one short configurable respawn timer and returns
	# as a complete three-unit camp, rather than disappearing for the whole match.
	main.settings.jungle_respawn_seconds = 0.1
	for slot in range(3):
		var camp_id := "jungle_11_%d" % slot
		if not main.entities.has(camp_id): continue
		var camp_actor: MapUnit = main.entities[camp_id].actor
		main.combat.remove_unit(camp_actor.runtime, true)
		camp_actor.queue_free()
		main.entities.erase(camp_id)
	main._schedule_cleared_jungle_camps(main.combat.tick_count)
	var camp_respawn_tick: int = int(main.jungle_camp_respawn_ticks.get(11, -1))
	main._respawn_jungle_camps(camp_respawn_tick)
	check(main.entities.has("jungle_11_0") and main.entities.has("jungle_11_1") and main.entities.has("jungle_11_2"), "A cleared jungle camp respawns its complete camp on the configured timer")
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
	var camp_info: Dictionary = main.entities["jungle_00_0"]
	main.player.position = camp_info.camp_center
	main.player.runtime.position = main.player.position
	main.settings.hero_acquisition_range = 300.0
	for candidate in main.entities.values():
		if candidate.get("neutral", false) or candidate.actor == main.player: continue
		candidate.actor.position = camp_info.camp_center + Vector2(3000, 0)
		candidate.actor.runtime.position = candidate.actor.position
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
	var soak_args := OS.get_cmdline_user_args()
	var target_ticks := 300 if "--smoke-soak" in soak_args else (1200 if "--medium-soak" in soak_args else (18000 if "--long-soak" in soak_args else 5400))
	var frame_budget := 60 * (ceili(target_ticks / 30.0) + 1)
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
	check(main.combat.metrics.by_unit.size() <= main.entities.size() + 2, "Retired creep metrics are released during the soak")
	if target_ticks >= 5400:
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
