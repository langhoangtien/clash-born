extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func place(actor: MapUnit, point: Vector2) -> void:
	actor.position = point
	actor.runtime.position = point
func _run() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	main.settings.maximum_live_creeps = 0
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.clock.set_running(false)
	for info in main.entities.values(): info.actor.paused = true
	var player: UnitRuntimeState = main.player.runtime
	var enemy: UnitRuntimeState = main.enemy_hero.runtime
	var blue: Vector2 = main.layout.fountain_point(0)
	var red: Vector2 = main.layout.fountain_point(1)
	place(main.player, blue)
	place(main.enemy_hero, red)
	player.current_hp = 200
	player.current_mana = 0
	enemy.current_hp = 200
	enemy.current_mana = 0
	var player_max_hp: float = player.stats.max_hp
	var player_max_mana: float = player.stats.max_mana
	var enemy_max_hp: float = enemy.stats.max_hp
	var enemy_max_mana: float = enemy.stats.max_mana
	check(main.in_fountain(player) and main.in_fountain(enemy), "Both teams have allied spawn fountain")
	for tick in range(30): main.clock.step()
	check(is_equal_approx(player.current_hp, 200 + player_max_hp * 0.2 + player.stats.hp_regen), "One second restores 20 percent max HP plus normal regen")
	check(is_equal_approx(player.current_mana, player_max_mana * 0.25 + player.stats.mana_regen), "One second restores 25 percent max mana plus regen")
	check(is_equal_approx(enemy.current_hp, 200 + enemy_max_hp * 0.2 + enemy.stats.hp_regen) and is_equal_approx(enemy.current_mana, enemy_max_mana * 0.25 + enemy.stats.mana_regen), "Red fountain scales restoration to its named hero")
	for tick in range(150): main.clock.step()
	check(player.current_hp == player.stats.max_hp and player.current_mana == player.stats.max_mana, "Fountain reaches full resources without overflow")
	check(is_equal_approx(main.combat.metrics.by_unit.player.healing_received, player_max_hp - 200), "Healing metrics count actual capped recovery only")
	place(main.player, blue + Vector2(main.settings.fountain_radius + 1, 0))
	player.current_hp = 500
	player.current_mana = 0
	for tick in range(30): main.clock.step()
	check(absf(player.current_hp - (500 + player.stats.hp_regen)) < 0.01 and absf(player.current_mana - player.stats.mana_regen) < 0.01, "Leaving fountain immediately returns to ordinary regen")
	place(main.player, red)
	var before := player.current_hp
	main._heal_fountains()
	check(player.current_hp == before and not main.in_fountain(player), "Enemy fountain does not heal player")
	place(main.player, blue + Vector2(main.settings.fountain_radius, 0))
	check(main.in_fountain(player), "Fountain boundary uses inclusive hero-center radius")
	place(main.player, blue)
	player.alive = false
	player.current_hp = 0
	main._heal_fountains()
	check(not player.alive and player.current_hp == 0, "Fountain cannot heal or revive a dead hero")
	main._revive("player")
	player.current_hp = 500
	player.current_mana = 0
	main.set_paused(true)
	main.clock.advance(5)
	check(player.current_hp == 500 and player.current_mana == 0, "Pause freezes fountain restoration")
	main.set_paused(false)
	main.clock.set_running(false)
	main.settings.fountain_hp_fraction_per_second = 0.1
	main.settings.fountain_mana_fraction_per_second = 0.1
	main.progression.player.award(100, 1000)
	main.buy_item(preload("res://data/equipment/vitality_stone.tres"))
	before = player.current_hp
	main._heal_fountains()
	check(is_equal_approx(player.current_hp - before, player.stats.max_hp * 0.1 / 30), "Configurable healing scales with leveled/equipped maximum HP")
	main.settings.fountain_hp_fraction_per_second = 0
	before = player.current_hp
	main._heal_fountains()
	check(player.current_hp == before, "Zero rate disables extra HP restoration")
	main.settings.fountain_hp_fraction_per_second = 0.2
	main.settings.fountain_mana_fraction_per_second = 0.25
	for speed in [0.5, 1.0, 2.0, 4.0]:
		main.clock.reset()
		main.clock.set_speed(speed)
		player.current_hp = 200
		player.current_mana = 0
		main.clock.set_running(true)
		main.clock.advance(1.0 / speed)
		main.clock.set_running(false)
		check(is_equal_approx(player.current_hp, 200 + player.stats.max_hp * 0.2 + player.stats.hp_regen) and is_equal_approx(player.current_mana, player.stats.max_mana * 0.25 + player.stats.mana_regen), "Same healing per simulation second at speed %.1f" % speed)
	main._refresh_hud()
	check("FOUNTAIN" in main.hud.text, "HUD shows fountain status")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		main.camera._process(0)
		main.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/fountain-preview.png") == OK, "Fountain circle and status rendered")
	main.queue_free()
	await process_frame
	print("Fountain: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
