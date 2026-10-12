extends SceneTree
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
	for frame in range(count): await physics_frame

func _run() -> void:
	_test_engine_bridge()
	await _test_match()
	print("Playable match: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_engine_bridge() -> void:
	var engine := CombatEngine.new(BalanceSettings.new())
	var source := UnitStats.new()
	engine.reset(source, source, Vector2(3000, 3000), Vector2(3200, 3000))
	engine.external_control = true
	var before := engine.units[0].position
	engine.units[0].target_id = ""
	engine.step()
	check(engine.units[0].position == before and engine.units[0].target_id.is_empty(), "External map mode preserves supplied position/target")
	var extra := engine.add_unit({"id": "creep", "team": 0, "source": source, "position": Vector2(3100, 3000), "ai": false})
	check(extra != null and engine.units.size() == 3 and engine.metrics.by_unit.has("creep"), "Dynamic spawning registers runtime and metrics")
	check(engine.add_unit({"id": "creep", "team": 0, "source": source}) == null, "Duplicate dynamic IDs rejected")
	engine.remove_unit(extra, true)
	check(not engine.metrics.by_unit.has("creep"), "Disposable wave metrics are released when the unit is removed")
	check(engine.add_unit({"id": "bad", "team": 9, "source": source}) == null, "Invalid dynamic team rejected")
	for unit in engine.units:
		if unit.team_id == 1: unit.alive = false
	engine.step()
	check(not engine.finished, "Hero/creep elimination does not prematurely end external match")

func _test_match() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	root.add_child(main)
	await process_frame
	await frames(2)
	main.set_physics_process(false)
	main.clock.set_running(false)
	check(main.entities.size() == 50, "Two heroes, twenty-two towers, two cores and first twenty-four-creep wave (actual %d)" % main.entities.size())
	check(main.layout.tower_cells.size() == 22 and main.layout.tower_teams.count(0) == 11 and main.layout.tower_teams.count(1) == 11, "Each team has three towers per lane and two throne guards")
	check(main.layout.fountain_point(0).distance_to(main.layout.throne_point(0)) > main.settings.fountain_radius and main.layout.fountain_point(1).distance_to(main.layout.throne_point(1)) > main.settings.fountain_radius, "Thrones stand outside both fountain healing zones")
	check(main.layout.fountain_point(0).distance_to(main.layout.throne_point(0)) < main.layout.tile_size * 2.5 and main.layout.fountain_point(1).distance_to(main.layout.throne_point(1)) < main.layout.tile_size * 2.5, "Thrones stay compactly placed beside their fountains")
	var blue_guard_a: Vector2 = main.layout.cell_center(Vector2i(main.layout.tower_cells[9]))
	var blue_guard_b: Vector2 = main.layout.cell_center(Vector2i(main.layout.tower_cells[10]))
	var red_guard_a: Vector2 = main.layout.cell_center(Vector2i(main.layout.tower_cells[20]))
	var red_guard_b: Vector2 = main.layout.cell_center(Vector2i(main.layout.tower_cells[21]))
	check(is_equal_approx(blue_guard_a.distance_to(main.layout.throne_point(0)), blue_guard_b.distance_to(main.layout.throne_point(0))) and is_equal_approx(red_guard_a.distance_to(main.layout.throne_point(1)), red_guard_b.distance_to(main.layout.throne_point(1))), "Two throne guards flank each throne at equal distance")
	check(main.layout.jungle_camps.size() == 12, "Three authored jungle camps exist in each map quadrant")
	check(main.player.runtime == main.combat.get_unit("player") and main.player.view.runtime == main.player.runtime, "Map/visual/combat share a single runtime state")
	var lanes: Dictionary = {}
	for info in main.entities.values():
		if info.kind == "creep": lanes["%d_%s" % [info.actor.runtime.team_id, info.lane]] = true
	check(lanes.size() == 6, "Creeps spawn for both teams in all three lanes (actual %s)" % [str(lanes.keys())])
	var overlap_pair: Array[MapUnit] = []
	for info in main.entities.values():
		if info.kind == "creep" and info.actor.runtime.team_id == 0 and overlap_pair.size() < 2: overlap_pair.append(info.actor)
	var saved_overlap_positions := [overlap_pair[0].position, overlap_pair[1].position]
	var overlap_point: Vector2 = main.layout.cell_center(Vector2i(15, 24))
	for actor in overlap_pair: actor.position = overlap_point; actor.runtime.position = overlap_point
	main._separate_mobile_units()
	check(overlap_pair[0].position.distance_to(overlap_pair[1].position) > 0, "Mobile unit separation resolves exact hero/creep-style overlap deterministically")
	for index in range(2): overlap_pair[index].position = saved_overlap_positions[index]; overlap_pair[index].runtime.position = saved_overlap_positions[index]
	# A real opposing lane pair must leave lane advance as soon as it enters the
	# local detection/attack area, then exchange engine-resolved damage.
	var duel_point: Vector2 = main.layout.cell_center(Vector2i(20, 22))
	var blue_lane_probe: MapUnit = main._spawn("blue_lane_duel", 0, main.settings.melee_creep, duel_point + Vector2(-60, 0), "creep", "MID")
	var red_lane_probe: MapUnit = main._spawn("red_lane_duel", 1, main.settings.melee_creep, duel_point + Vector2(60, 0), "creep", "MID")
	var blue_lane_info: Dictionary = main.entities[blue_lane_probe.runtime.unit_id]
	var red_lane_info: Dictionary = main.entities[red_lane_probe.runtime.unit_id]
	var blue_target: MapUnit = main._choose_lane_creep_target(blue_lane_info, main.combat.tick_count + 1)
	var red_target: MapUnit = main._choose_lane_creep_target(red_lane_info, main.combat.tick_count + 1)
	main._drive_lane_creep(main.entities[blue_lane_probe.runtime.unit_id], blue_target, main.combat.tick_count + 1)
	main._drive_lane_creep(main.entities[red_lane_probe.runtime.unit_id], red_target, main.combat.tick_count + 1)
	check(blue_target == red_lane_probe and red_target == blue_lane_probe and blue_lane_probe.runtime.target_id == red_lane_probe.runtime.unit_id and red_lane_probe.runtime.target_id == blue_lane_probe.runtime.unit_id, "Opposing lane creeps acquire one another before advancing")
	var blue_duel_hp := blue_lane_probe.runtime.current_hp
	var red_duel_hp := red_lane_probe.runtime.current_hp
	for tick in range(100): main.clock.step()
	check(blue_lane_probe.runtime.current_hp < blue_duel_hp and red_lane_probe.runtime.current_hp < red_duel_hp, "Opposing lane creeps exchange actual combat damage after acquisition")
	var player: MapUnit = main.player
	var enemy: MapUnit = main.enemy_hero
	var bot: HeroProgression = main.progression.enemy_hero
	bot.award(100)
	main.clock.step()
	check(bot.level == 2 and bot.passive_level == 2 and bot.skill_points == 0, "Enemy hero spends its new skill point automatically")
	var player_home := player.position
	var enemy_home := enemy.position
	var blue_tower: MapUnit = main.entities.tower_00.actor
	player.position = blue_tower.position; player.runtime.position = player.position
	enemy.position = player.position + Vector2(180, 0); enemy.runtime.position = enemy.position
	check(main._unsafe_tower_dive(enemy, player), "Enemy hero recognizes an unsupported dive into an allied tower")
	player.position = player_home; player.runtime.position = player_home
	enemy.position = enemy_home; enemy.runtime.position = enemy_home
	main.camera.set_process(false)
	# Let native physics execute: keyboard-style steering stays continuous/collidable.
	var before := player.position
	player.manual_direction = Vector2.RIGHT
	await frames(5)
	check(player.position.x > before.x and player.navigation.point_is_clear(player.position), "Player drives with continuous world movement")
	player.manual_direction = Vector2.ZERO
	player.stop()
	# Mouse buttons and independent touch fingers both feed the direction pad.
	main.controls.direction_buttons.up.button_down.emit()
	check(main.controls.direction == Vector2.UP, "Up direction button works")
	main.controls.direction_buttons.up.button_up.emit()
	check(main.controls.direction == Vector2.ZERO, "Direction release stops movement")
	for key in ["left", "down", "right"]:
		main.controls.direction_buttons[key].button_down.emit()
		check(not main.controls.direction.is_zero_approx(), "Direction button " + key)
		main.controls.direction_buttons[key].button_up.emit()
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = main.controls.direction_buttons.right.get_global_rect().get_center()
	main.controls._input(touch)
	var attack_touch := InputEventScreenTouch.new()
	attack_touch.index = 2
	attack_touch.pressed = true
	attack_touch.position = main.controls.attack_buttons.hero.get_global_rect().get_center()
	main.controls._input(attack_touch)
	check(main.controls.direction == Vector2.RIGHT and main.attack_mode == "hero", "Multi-touch movement and hero attack can be used simultaneously")
	touch.pressed = false
	main.controls._input(touch)
	check(main.controls.direction.is_zero_approx(), "Touch release clears movement")
	main.controls.release_all()
	var move_key := InputEventKey.new()
	move_key.physical_keycode = KEY_D
	move_key.keycode = KEY_D
	move_key.pressed = true
	Input.parse_input_event(move_key)
	Input.flush_buffered_events()
	main._physics_process(0)
	check(player.manual_direction == Vector2.RIGHT and main.attack_mode.is_empty(), "Actual keyboard polling steers hero and cancels auto attack")
	before = player.position
	await frames(5)
	check(player.position.x > before.x, "Keyboard command moves the hero through native physics")
	move_key.pressed = false
	Input.parse_input_event(move_key)
	Input.flush_buffered_events()
	main._physics_process(0)
	check(player.manual_direction.is_zero_approx() and not main.camera.keyboard_pan_enabled, "Keyboard release stops steering; arrows belong to hero instead of camera")
	player.position = main.layout.cell_center(Vector2i(15, 24))
	player.runtime.position = player.position
	enemy.position = player.position + Vector2(200, -200)
	enemy.runtime.position = enemy.position
	enemy.stop()
	var creep: MapUnit = main._spawn("test_creep", 1, main.settings.melee_creep, player.position + Vector2(100, 0), "creep", "MID")
	main.request_attack("hero")
	check(main._player_target() == enemy, "Hero button ignores a closer enemy creep")
	main.request_attack("creep")
	check(main._player_target() == creep, "Creep button ignores enemy hero")
	main.settings.player_creep_command_radius = 50.0
	var local_creep_target: MapUnit = main._player_target()
	check(local_creep_target == null or player.runtime.distance_to_unit(local_creep_target.runtime) <= 50.0, "Creep command stays local instead of selecting a distant target")
	main.settings.player_creep_command_radius = 650.0
	main.controls.attack_buttons.hero.pressed.emit()
	check(main.attack_mode == "hero", "On-screen hero attack button connects to match")
	main.controls.attack_buttons.creep.pressed.emit()
	check(main.attack_mode == "creep", "On-screen creep attack button connects to match")
	# Freeze bodies while ticking combat; projectile engine is still the real engine.
	for info in main.entities.values(): info.actor.paused = true
	main.request_attack("hero")
	var hp_before := enemy.runtime.current_hp
	main.clock.step()
	var profile: Dictionary = main.runtime_profile_snapshot()
	check(int(profile.get("entities", 0)) > 0 and int(profile.get("target_queries", -1)) >= 0 and int(profile.get("vision_checks", -1)) >= 0 and int(profile.get("tick_usec", 0)) >= 0, "Runtime profiler records entity, targeting, vision, and tick-cost counters")
	check(enemy.runtime.current_hp == hp_before and not main.combat.projectiles.is_empty(), "Player launches projectile without immediate damage")
	for tick in range(15): main.clock.step()
	check(enemy.runtime.current_hp < hp_before, "Player hero button actually damages enemy hero at impact")
	# Isolate last-hit attribution from allied towers/creeps in this fixture.
	creep.runtime.current_hp = 1
	var timers: Dictionary = {}
	main.combat.projectiles.clear()
	for unit in main.combat.units:
		if unit != player.runtime:
			timers[unit.unit_id] = unit.next_attack_tick
			unit.next_attack_tick = 99999
	main.request_attack("creep")
	main.locked_target = "test_creep"
	for tick in range(300):
		main.clock.step()
		if not main.entities.has("test_creep"): break
	check(not main.entities.has("test_creep") and main.creep_kills > 0, "Player kills creep and dead creep is cleaned up")
	var jungle_units: Array[String] = []
	for id in main.entities:
		if main.entities[id].get("neutral", false): jungle_units.append(id)
	check(jungle_units.size() == 36, "Twelve camps spawn three neutral creeps each")
	var jungle_info: Dictionary = main.entities[jungle_units[0]]
	var jungle_actor: MapUnit = jungle_info.actor
	jungle_actor.position = jungle_info.camp_center
	jungle_actor.runtime.position = jungle_actor.position
	player.position = jungle_info.camp_center + Vector2(120, 0)
	player.runtime.position = player.position
	main._drive_jungle_creep(jungle_info, main.combat.tick_count + 1)
	check(jungle_actor.runtime.target_id.is_empty(), "Jungle creep stays passive when an unaggressive hero enters its camp")
	main._arm_jungle_retaliation(jungle_actor.runtime.unit_id, player.runtime.unit_id)
	main._drive_jungle_creep(jungle_info, main.combat.tick_count + 1)
	check(jungle_actor.runtime.target_id == player.runtime.unit_id, "Jungle creep retaliates after the hero damages it")
	jungle_actor.position = jungle_info.camp_center + Vector2(jungle_info.leash_range + 60.0, 0)
	jungle_actor.runtime.position = jungle_actor.position
	jungle_actor.runtime.target_id = "player"
	main._drive_jungle_creep(jungle_info, main.combat.tick_count + 1)
	check(jungle_actor.runtime.target_id.is_empty() and not jungle_actor.path.is_empty(), "Jungle creep drops aggro and returns after crossing its leash")
	for unit in main.combat.units:
		if timers.has(unit.unit_id): unit.next_attack_tick = timers[unit.unit_id]
	# Tower picks a creep before a hero and deals damage through the same engine.
	var locked_tower: MapUnit = main.entities[main.tower_registry["red_mid_t2"]].actor
	check(not main._tower_is_unlocked(main.entities[locked_tower.runtime.unit_id]), "Inner tower starts locked behind its own lane outer tower")
	var tower: MapUnit = main.entities[main.tower_registry["red_mid_t1"]].actor
	var lane_probe: MapUnit = main._spawn("lane_order_probe", 0, main.settings.melee_creep, locked_tower.position, "creep", "MID")
	var probe_info: Dictionary = main.entities[lane_probe.runtime.unit_id]
	check(main._choose_lane_creep_target(probe_info, main.combat.tick_count + 1) == null, "Creep cannot skip a living MID T1 to attack MID T2")
	tower.runtime.alive = false
	check(main._choose_lane_creep_target(probe_info, main.combat.tick_count + 2) == locked_tower, "Creep advances to MID T2 as soon as MID T1 is gone")
	tower.runtime.alive = true
	main.combat.remove_unit(lane_probe.runtime)
	main.entities.erase(lane_probe.runtime.unit_id)
	lane_probe.queue_free()
	player.position = tower.position + Vector2(-180, 180)
	player.runtime.position = player.position
	creep = main._spawn("test_tower_creep", 0, main.settings.melee_creep, tower.position + Vector2(-230, 170), "creep", "MID")
	creep.paused = true
	var info: Dictionary = main.entities[tower.runtime.unit_id]
	check(main._choose_target(info, ["creep", "hero"], tower.runtime.attack_range()) == creep, "Enemy tower prioritizes friendly creep over player")
	main._stop_player()
	var creep_hp := creep.runtime.current_hp
	for tick in range(40): main.clock.step()
	check(creep.runtime.current_hp < creep_hp, "Tower automatically fires and damages creep")
	var saved_player_damage: float = player.runtime.stats.physical_damage
	var saved_player_ranged: bool = player.runtime.stats.ranged_attacks
	player.runtime.stats.physical_damage = 10000
	player.runtime.stats.ranged_attacks = false
	tower.runtime.current_hp = 1
	player.runtime.next_attack_tick = main.combat.tick_count + 1
	main.request_attack("creep")
	main.locked_target = tower.runtime.unit_id
	main.clock.step()
	check(not main.entities.has(tower.runtime.unit_id), "Destroyed tower is removed from collision and scene entities")
	player.runtime.stats.physical_damage = saved_player_damage
	player.runtime.stats.ranged_attacks = saved_player_ranged
	# Wave timing is simulation time and bounded; paused clock does not spawn.
	main.settings.wave_interval = 1
	main.settings.maximum_live_creeps = 200
	main.next_wave_tick = main.combat.tick_count + 1
	var waves: int = main.wave_number
	main.clock.step()
	check(main.wave_number == waves + 1, "Next scheduled wave appears automatically")
	main.set_paused(true)
	var tick_before: int = main.combat.tick_count
	main.clock.advance(10)
	check(main.combat.tick_count == tick_before, "Pause freezes combat/projectiles/wave timer")
	main.set_paused(false)
	main.clock.set_running(false)
	main.settings.maximum_live_creeps = 0
	waves = main.wave_number
	main.spawn_wave()
	check(main.wave_number == waves, "Live-creep cap prevents unbounded spawning")
	# A real lethal damage event triggers respawn; do not fake a view-only death.
	main._revive("enemy_hero")
	# Run the combat assertion outside every tower's range; the bot now correctly
	# breaks off when an enemy tower has it targeted.
	for tower_info in main.entities.values():
		if tower_info.kind == "tower": tower_info.actor.runtime.alive = false
	player.position = main.layout.cell_center(Vector2i(20, 10))
	player.runtime.position = player.position
	enemy.position = player.position + Vector2(100, 0)
	enemy.runtime.position = enemy.position
	var saved_damage: float = enemy.runtime.stats.physical_damage
	var saved_ranged: bool = enemy.runtime.stats.ranged_attacks
	enemy.runtime.stats.physical_damage = 10000
	enemy.runtime.stats.ranged_attacks = false
	enemy.runtime.next_attack_tick = main.combat.tick_count + 1
	player.runtime.current_hp = 1
	main.clock.step()
	enemy.runtime.stats.physical_damage = saved_damage
	enemy.runtime.stats.ranged_attacks = saved_ranged
	check(not player.runtime.alive and main.respawns.has("player"), "Hero death schedules respawn")
	main.settings.respawn_seconds = 0.1
	main.respawns.player = main.combat.tick_count + 3
	for tick in range(4): main.clock.step()
	check(player.runtime.alive and player.runtime.current_hp == player.runtime.stats.max_hp and player.position == main.layout.spawn_points(0)[0], "Hero respawns at base with full HP")
	main._clicked_entity("enemy_hero")
	check(main.locked_target == "enemy_hero" and main.attack_mode == "hero", "Clicking enemy locks the correct target category")
	# Keyboard input invokes attack and stop without a GUI button.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	root.push_input(key, true)
	check(main.attack_mode == "creep", "J keyboard attack command")
	key.physical_keycode = KEY_K
	root.push_input(key, true)
	check(main.attack_mode == "hero", "K keyboard attack command")
	key.physical_keycode = KEY_SPACE
	root.push_input(key, true)
	check(main.attack_mode.is_empty(), "Space stops automatic attacking")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		player.position = main.layout.cell_center(Vector2i(20, 19))
		player.runtime.position = player.position
		enemy.position = player.position + Vector2(200, -160)
		enemy.runtime.position = enemy.position
		main.camera.follow_enabled = true
		main.camera._process(0)
		main.camera.force_update_scroll()
		main.request_attack("hero")
		main.clock.step()
		main._refresh_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/playable-match.png") == OK, "Playable battle controls/hero/minimap rendered")
	# Destroying the core ends the match, not killing a creep or hero.
	main.cores[1].runtime.current_hp = 0
	main.clock.step()
	check(main.match_over and main.combat.winner_team == 0 and main.result_panel.visible and not main.clock.running, "Destroy enemy core produces victory and freezes match")
	main.queue_free()
	await process_frame
	# A short autonomous native-physics run exercises movement, combat and waves together.
	var live = load("res://scenes/match/moba_match.tscn").instantiate()
	live.settings = live.settings.duplicate(true)
	live.settings.show_draft_on_start = false
	live.settings.wave_interval = 2
	live.settings.creeps_per_lane = 1
	live.settings.melee_creep.movement_speed = 5000
	live.settings.ranged_creep.movement_speed = 5000
	root.add_child(live)
	await frames(240)
	check(live.wave_number >= 2 and live.combat.tick_count > 60, "Live physics match continuously spawns waves")
	var damage := 0.0
	for metric in live.combat.metrics.by_unit.values(): damage += metric.damage_dealt
	check(damage > 0, "Autonomous creep/tower battle resolves actual damage")
	for info_live in live.entities.values():
		if info_live.actor.runtime.alive: check(info_live.actor.navigation.point_is_clear(info_live.actor.position), "Active match entity respects terrain")
	live.queue_free()
	await process_frame
