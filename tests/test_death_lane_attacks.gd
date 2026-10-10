extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _run() -> void:
	_test_rules()
	await _test_lane_attacks()
	await _test_death()
	print("Death/lane attacks: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _test_lane_attacks() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	main.settings.maximum_live_creeps = 0
	root.add_child(main)
	await process_frame
	await physics_frame
	main.set_physics_process(false)
	main.clock.set_running(false)
	main.next_wave_tick = 99999
	for info in main.entities.values():
		info.actor.paused = true
		info.actor.runtime.stats.physical_damage = 0
	main.player.runtime.stats.physical_damage = 100
	for lane in ["TOP", "BOT"]:
		var from_cell := Vector2i(12, 19) if lane == "TOP" else Vector2i(19, 25)
		var to_cell := Vector2i(5, 20) if lane == "TOP" else Vector2i(20, 34)
		main.player.position = main.layout.cell_center(from_cell)
		main.player.runtime.position = main.player.position
		var target: MapUnit = main._spawn("probe_" + lane, 1, main.settings.melee_creep, main.layout.cell_center(to_cell), "creep", lane)
		target.paused = true
		target.runtime.stats.physical_damage = 0
		check(main.player.navigation.point_is_clear(main.player.position) and not main.player.navigation.path(main.player.position, target.position).is_empty(), lane + " fixture is walkable and reachable")
		var actual_start: Vector2 = main.player.position + Vector2(17, 17)
		var replanned: PackedVector2Array = main.player.navigation.path(actual_start, target.position)
		check(not replanned.is_empty() and replanned[0] == actual_start, lane + " replan starts at real position without pulling back to cell center")
		check(not main._visible(main.player, target), lane + " reproduces nearby creep occluded by jungle wall")
		main.request_attack("creep")
		check(main._player_target() == target, lane + " auto-attack acquires reachable creep across bend")
		main.player.paused = false
		main.clock.step()
		check(main.player.runtime.target_id.is_empty() and not main.player.path.is_empty(), lane + " approaches via navigation without attacking through terrain")
		var hp: float = target.runtime.current_hp
		for frame in range(600):
			await physics_frame
			if frame % 2 == 0: main.clock.step()
			if target.runtime.current_hp < hp: break
		check(target.runtime.current_hp < hp, lane + " hero rounds obstacle and damages creep at impact")
		check(main.player.navigation.point_is_clear(main.player.position), lane + " approach remains outside blocked terrain")
		check(main._visible(main.player, target) and main.player.runtime.distance_to_unit(target.runtime) <= main.player.runtime.attack_range(), lane + " attack resolves from valid visible range")
		print("%s side-lane creep HP: %.2f -> %.2f" % [lane, hp, target.runtime.current_hp])
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			main.camera.follow_enabled = true
			main.camera.position = main.player.position
			main.camera.force_update_scroll()
			main._refresh_hud()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://.local/attack-%s.png" % lane.to_lower()) == OK, lane + " attack and reduced HP rendered")
		main.player.paused = true
		main._stop_player()
		target.runtime.alive = false
	var friendly: MapUnit = main._spawn("friendly_probe", 0, main.settings.melee_creep, main.player.position, "creep", "BOT")
	main._clicked_entity("friendly_probe")
	check(main.attack_mode.is_empty() and "đồng minh" in main.message.text, "Friendly creep click explains why it cannot be damaged")
	main._drive_target(main.entities.player, friendly, main.combat.tick_count + 1)
	check(main.player.runtime.target_id.is_empty(), "Friendly target never enters external combat attack")
	main.queue_free()
	await process_frame

func _test_rules() -> void:
	var settings: MatchSettings = load("res://data/match/default_match.tres").duplicate(true)
	var hero := HeroProgression.new(UnitRuntimeState.new("test", 0, Vector2.ZERO, settings.hero, BalanceSettings.new()), settings.hero, settings.hero_profiles[0], settings, BalanceSettings.new())
	check(settings.respawn_duration(1) == 8 and settings.respawn_duration(5) == 16 and settings.respawn_duration(15) == 36, "Respawn duration scales from 8s at level one to 36s at cap")
	hero.level = 5
	hero.gold = 1000
	check(hero.lose_death_gold() == 125 and hero.gold == 875, "Death removes 25 gold per level")
	hero.gold = 20
	check(hero.lose_death_gold() == 20 and hero.gold == 0, "Death loss clamps to available gold")
	check(hero.lose_death_gold() == 0 and hero.gold == 0, "Empty wallet never becomes negative")
	settings.respawn_seconds = 3
	settings.respawn_seconds_per_level = 0.5
	settings.death_gold_per_level = 10
	hero.gold = 100
	check(settings.respawn_duration(5) == 5 and hero.lose_death_gold() == 50, "Respawn growth and penalty configurable independently")

func _test_death() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	main.settings.maximum_live_creeps = 0
	main.settings.passive_gold_amount = 0
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.clock.set_running(false)
	main.next_wave_tick = 99999
	for info in main.entities.values():
		info.actor.paused = true
		info.actor.runtime.stats.physical_damage = 0
	var hero: HeroProgression = main.progression.player
	hero.level = 5
	hero.experience = 17
	hero.gold = 2000
	hero.buy(MatchItemCatalog.items()[10])
	var gold_before := hero.gold
	var gear: Array[EquipmentData] = hero.equipment.items().duplicate()
	var point: Vector2 = main.layout.cell_center(Vector2i(15, 24))
	main.player.position = point
	main.player.runtime.position = point
	main.player.runtime.current_hp = 1
	main.enemy_hero.position = point + Vector2(100, 0)
	main.enemy_hero.runtime.position = main.enemy_hero.position
	main.enemy_hero.runtime.stats.physical_damage = 10000
	main.enemy_hero.runtime.stats.ranged_attacks = false
	main.enemy_hero.runtime.next_attack_tick = main.combat.tick_count + 1
	main.clock.step()
	var death_tick: int = main.combat.tick_count
	check(not hero.unit.alive and main.respawns.player == death_tick + 480, "Real level-five lethal damage schedules 16 seconds of simulation time")
	check(hero.gold == gold_before - 125 and hero.equipment.items() == gear and hero.experience == 17, "Real death loses gold once, retaining equipment and XP")
	main._refresh_hud()
	check("Mất 125 vàng" in main.message.text, "Death HUD displays actual penalty")
	main.set_paused(true)
	main.clock.advance(60)
	check(main.combat.tick_count == death_tick and not hero.unit.alive and hero.gold == gold_before - 125, "Pause freezes respawn and cannot charge another penalty")
	main.set_paused(false)
	main.clock.set_running(false)
	for tick in range(479): main.clock.step()
	check(not hero.unit.alive and hero.gold == gold_before - 125, "Hero remains dead until the exact respawn tick without repeated loss")
	main.clock.step()
	check(hero.unit.alive and hero.unit.current_hp == hero.unit.stats.max_hp and hero.unit.position == main.layout.spawn_points(0)[0], "Hero revives precisely at deadline with full grown/equipped HP")
	check(hero.level == 5 and hero.experience == 17 and hero.equipment.items() == gear and hero.gold == gold_before - 125, "Respawn preserves post-penalty progression and gear")
	check(not main.death_gold_losses.has("player"), "Respawn clears death notice")
	main.queue_free()
	await process_frame
