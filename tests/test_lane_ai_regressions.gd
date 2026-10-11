extends SceneTree
## Reproduces the two lane regressions with the real match scene, navigation,
## MapUnit physics and CombatEngine.  The fixture limits spawning to MID only.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for _frame in range(count): await physics_frame

func _match(debug_trace: bool = false):
	var fixture = load("res://scenes/match/moba_match.tscn").instantiate()
	fixture.settings = fixture.settings.duplicate(true)
	fixture.settings.show_draft_on_start = false
	fixture.settings.wave_interval = 999.0
	fixture.settings.siege_wave_interval = 0
	fixture.settings.creeps_per_lane = 1
	fixture.settings.maximum_live_creeps = 8
	fixture.settings.hero.movement_speed = 900.0
	fixture.settings.melee_creep.movement_speed = 900.0
	fixture.settings.fountain_hp_fraction_per_second = 2.0
	fixture.debug_mid_lane_only = true
	fixture.debug_ai_trace_enabled = debug_trace
	return fixture

func _runtime_id(game, semantic_id: String) -> String:
	return str(game.tower_registry.get(semantic_id, ""))

func _lane_creeps(game, team: int) -> Array[MapUnit]:
	var result: Array[MapUnit] = []
	for info in game.entities.values():
		if info.kind == "creep" and not info.get("neutral", false) and info.lane == "MID" and info.actor.runtime.team_id == team:
			result.append(info.actor)
	return result

func _print_structure_table(game) -> void:
	print("STRUCTURE TABLE | id | team | lane | tier | position | prerequisite | alive | attackable | runtime")
	for row in game.structure_runtime_rows():
		print("STRUCTURE | %s | %d | %s | %d | %s | %s | %s | %s | %s" % [row.id, row.team, row.lane, row.tier, str(row.position), str(row.prerequisites), str(row.alive), str(row.attackable), row.runtime_id])

func _run() -> void:
	var game = _match(false)
	root.add_child(game)
	game.clock.set_running(false)
	game.set_physics_process(false)
	_print_structure_table(game)
	check(game.structure_registry_errors().is_empty(), "Scene, MapLayout resource and runtime structure registry agree")
	for team in range(2):
		for lane in ["TOP", "MID", "BOT"]:
			var t1: MapUnit = game.entities[_runtime_id(game, "%s_%s_t1" % ["blue" if team == 0 else "red", lane.to_lower()])].actor
			var t2: MapUnit = game.entities[_runtime_id(game, "%s_%s_t2" % ["blue" if team == 0 else "red", lane.to_lower()])].actor
			var t3: MapUnit = game.entities[_runtime_id(game, "%s_%s_t3" % ["blue" if team == 0 else "red", lane.to_lower()])].actor
			check(game._lane_progress(t3.position, lane, team) < game._lane_progress(t2.position, lane, team) and game._lane_progress(t2.position, lane, team) < game._lane_progress(t1.position, lane, team), "Team %d %s tower order is BASE T3 -> T2 -> outer T1" % [team, lane])
	game.queue_free()
	await process_frame

	var live = _match(true)
	root.add_child(live)
	live.jungle_spawned = true
	await frames(3)
	var blue_wave := _lane_creeps(live, 0)
	var red_wave := _lane_creeps(live, 1)
	check(blue_wave.size() == 1 and red_wave.size() == 1, "Controlled fixture spawns exactly one MID creep for each team")
	var blue: MapUnit = blue_wave[0]
	var red: MapUnit = red_wave[0]
	var red_id: String = red.runtime.unit_id
	var blue_start_progress: float = live._lane_progress(blue.position, "MID", 0)
	var fought := false
	for _frame in range(700):
		await physics_frame
		if blue.runtime.current_hp < blue.runtime.stats.max_hp or red.runtime.current_hp < red.runtime.stats.max_hp:
			fought = true
			break
	check(fought and live._lane_progress(blue.position, "MID", 0) > blue_start_progress, "Real blue/red MID entities follow their lane, meet and deal combat damage")
	# Let the real next attack remove the red wave, then make the surviving blue
	# creep durable enough to observe the complete structure sequence.
	red.runtime.current_hp = 1.0
	for _frame in range(240):
		await physics_frame
		if not live.entities.has(red_id): break
	check(not live.entities.has(red_id), "Blue creep finishes the opposing MID wave through CombatEngine")
	blue.runtime.stats.max_hp = 50000.0
	blue.runtime.current_hp = 50000.0
	var bot: MapUnit = live.enemy_hero
	var bot_info: Dictionary = live.entities.enemy_hero
	var red_fountain: Vector2 = live.layout.fountain_point(1)
	var anchor: Vector2 = live.get_defensive_anchor(1, "MID")
	var red_t1: MapUnit = live.entities[_runtime_id(live, "red_mid_t1")].actor
	var red_t2: MapUnit = live.entities[_runtime_id(live, "red_mid_t2")].actor
	for _frame in range(180):
		await physics_frame
		if live.ai_debug_events.any(func(line: String): return "enemy_hero STATE" in line and "->FIGHT" in line): break
	check(bot_info.assigned_lane == "MID" and anchor.distance_to(red_fountain) > live.settings.fountain_radius and anchor.distance_to(red_t1.position) < anchor.distance_to(red_t2.position), "Red bot anchor is outside fountain and stays nearer MID T1 than T2")
	check(bot.position.distance_to(red_fountain) > live.settings.fountain_radius, "Red bot physically leaves base during the controlled lane run")
	check(live.ai_debug_events.any(func(line: String): return "enemy_hero STATE" in line and "->FIGHT" in line), "Bot reaches lane and changes to FIGHT from an actual nearby wave")
	# Exercise retreat, recovery and return while MID T1 still exists.
	bot.runtime.current_hp = bot.runtime.stats.max_hp * 0.2
	for _frame in range(600):
		await physics_frame
		if live.in_fountain(bot.runtime) and bot.runtime.current_hp >= bot.runtime.stats.max_hp * live.settings.bot_recover_hp_fraction: break
	check(live.in_fountain(bot.runtime), "Low-HP bot follows a valid navigation path back to fountain")
	for _frame in range(300):
		await physics_frame
		if bot.position.distance_to(red_fountain) > live.settings.fountain_radius: break
	check(bot.position.distance_to(red_fountain) > live.settings.fountain_radius and bot_info.ai_state != "RETREAT", "Recovered bot exits fountain and returns to lane")
	# Park it safely in RECOVER so hero priority cannot obscure the independent
	# structure-order assertion below.
	live.settings.fountain_hp_fraction_per_second = 0.0
	bot.runtime.current_hp = bot.runtime.stats.max_hp * 0.2
	for _frame in range(600):
		await physics_frame
		if live.in_fountain(bot.runtime): break
	var expected_towers := ["red_mid_t1", "red_mid_t2", "red_mid_t3"]
	for semantic_id in expected_towers:
		var runtime_id := _runtime_id(live, semantic_id)
		check(not runtime_id.is_empty() and live.entities.has(runtime_id), semantic_id + " exists before its turn")
		var tower: MapUnit = live.entities[runtime_id].actor
		tower.runtime.current_hp = 1.0
		var selected_expected := false
		var selected_wrong := false
		for _frame in range(900):
			await physics_frame
			if blue.runtime.target_id == runtime_id: selected_expected = true
			if blue.runtime.target_id.begins_with("tower_") and blue.runtime.target_id != runtime_id and live.entities.has(blue.runtime.target_id) and live.entities[blue.runtime.target_id].actor.runtime.alive: selected_wrong = true
			if not live.entities.has(runtime_id): break
		check(selected_expected and not selected_wrong, "Blue creep entity targets %s without skipping tiers" % semantic_id)
		check(not live.entities.has(runtime_id), semantic_id + " is destroyed by a real creep attack")
		if semantic_id == "red_mid_t1":
			check(live.get_lane_defensive_tower(1, "MID") == live.entities[_runtime_id(live, "red_mid_t2")].actor, "Bot defensive anchor advances from destroyed T1 to living T2")

	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		live.set_full_map_mode(true)
		live.camera.follow_enabled = false
		live.camera.position = blue.position
		live.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.local"))
		check(root.get_texture().get_image().save_png("res://.local/lane-ai-regression.png") == OK, "Controlled MID regression scene rendered")
	live.queue_free()
	await process_frame

	var restarted = _match(false)
	root.add_child(restarted)
	restarted.clock.set_running(false)
	check(restarted.structure_registry_errors().is_empty() and restarted.get_outer_tower(1, "MID").position == restarted.layout.cell_center(Vector2i(22, 17)), "Restart rebuilds the corrected registry and red MID outer tower")
	restarted.queue_free()
	await process_frame
	print("Lane AI regressions: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
