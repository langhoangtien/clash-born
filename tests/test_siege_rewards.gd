extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _run() -> void:
	_test_rewards()
	_test_durability()
	await _test_scene()
	print("Siege/rewards: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _hero(id: String, team: int, point: Vector2, settings: MatchSettings) -> HeroProgression:
	var state := UnitRuntimeState.new(id, team, point, settings.hero, BalanceSettings.new())
	return HeroProgression.new(state, settings.hero, settings.hero_profiles[0], settings, BalanceSettings.new())

func _test_rewards() -> void:
	var settings: MatchSettings = load("res://data/match/default_match.tres")
	var rewards := MatchRewards.new(settings)
	var heroes: Dictionary = {}
	for team in range(2):
		for index in range(5):
			var id := "%d_%d" % [team, index]
			heroes[id] = _hero(id, team, Vector2(index * 100, 0), settings)
	var victim: UnitRuntimeState = heroes["1_0"].unit
	for index in range(2, 5): heroes["0_%d" % index].unit.position = Vector2(3000, 0)
	var payouts := rewards.calculate(victim, "creep", "0_0", 0, 1, 100, heroes)
	check(payouts["0_0"].xp == 23 and payouts["0_1"].xp == 22, "Two nearby heroes share all 45 creep XP with deterministic remainder")
	check(payouts["0_0"].gold == 20 and payouts["0_1"].gold == 0, "Only creep last hitter gets gold")
	check(payouts["0_2"].xp == 0 and not payouts.has("1_1"), "Distant and victim-team heroes receive no XP")
	payouts = rewards.calculate(victim, "creep", "tower", 0, 1, 100, heroes, true)
	check(payouts["0_0"].xp == 45 and payouts["0_1"].xp == 45 and payouts["0_0"].gold == 0, "Siege XP shared, no proximity creep gold")
	heroes["0_1"].unit.alive = false
	payouts = rewards.calculate(victim, "creep", "0_0", 0, 1, 100, heroes)
	check(payouts["0_0"].xp == 45 and payouts["0_1"].xp == 0, "Dead nearby hero neither receives nor dilutes XP")
	heroes["0_1"].unit.alive = true
	payouts = rewards.calculate(victim, "hero", "0_0", 0, 1, 100, heroes)
	check(payouts["0_0"].gold == 133 and payouts["0_1"].gold == 46, "Level-one hero pays kill bounty and nearby assist pool")
	check(payouts["0_0"].xp == 70 and payouts["0_1"].xp == 70, "Hero death XP shared")
	var high := rewards.calculate(victim, "hero", "0_0", 0, 10, 100, heroes)
	check(high["0_0"].gold == 205 and high["0_0"].xp == 250, "Higher victim level increases gold and XP")
	rewards.record_damage(victim.unit_id, "0_0", 50, heroes)
	rewards.record_damage(victim.unit_id, "0_1", 60, heroes)
	payouts = rewards.calculate(victim, "hero", "tower", 0, 1, 100, heroes)
	check(payouts["0_1"].gold == 133 and payouts["0_0"].gold == 46, "Tower credits most recent hostile hero; earlier hero gets assist")
	check(rewards.hero_kill_credit(victim, "tower", 0, 100, heroes) == "0_1", "Tower kill credit is reusable by kill-stack passives")
	payouts = rewards.calculate(victim, "hero", "0_0", 0, 1, 100, heroes)
	check(payouts["0_0"].gold == 133, "Actual hero last hit overrides recent damage credit")
	heroes["0_1"].unit.alive = false
	heroes["0_1"].unit.position = Vector2(4000, 0)
	payouts = rewards.calculate(victim, "hero", "creep", 0, 1, 100, heroes)
	check(payouts["0_1"].gold == 133 and payouts["0_1"].xp == 0, "Dead/distant recent contributor retains kill credit without nearby XP")
	payouts = rewards.calculate(victim, "hero", "tower", 0, 1, 960, heroes)
	check(payouts["0_1"].gold == 133, "Thirty-second credit boundary is inclusive")
	payouts = rewards.calculate(victim, "hero", "tower", 0, 1, 961, heroes)
	var sum := 0
	for id in payouts: sum += payouts[id].gold
	check(sum == 133 and payouts["0_0"].gold == 27 and payouts["0_4"].gold == 26, "Expired damage gives exactly one team bounty split over five heroes, even dead/distant")
	var reversed: Dictionary = {}
	var ids: Array = heroes.keys(); ids.reverse()
	for id in ids: reversed[id] = heroes[id]
	check(payouts == rewards.calculate(victim, "hero", "tower", 0, 1, 961, reversed), "Reward distribution independent of dictionary insertion order")
	rewards.forget(victim.unit_id)
	check(not rewards.damage_history.has(victim.unit_id), "Death/respawn clears prior-life attribution")
	payouts = rewards.calculate(victim, "hero", "tower", 1, 1, 100, heroes)
	check(payouts.is_empty(), "Friendly killer cannot generate enemy rewards")
	check(rewards.hero_kill_credit(victim, "1_1", 1, 100, heroes).is_empty(), "Friendly hero cannot receive kill-stack credit")
	heroes["0_0"].unit.position = Vector2(settings.xp_radius, 0)
	heroes["0_1"].unit.alive = true
	heroes["0_1"].unit.position = Vector2(settings.xp_radius + 1, 0)
	payouts = rewards.calculate(victim, "creep", "0_1", 0, 1, 100, heroes)
	check(payouts["0_0"].xp == 45 and payouts["0_1"].xp == 0 and payouts["0_1"].gold == 20, "XP center-distance boundary and distant last-hit gold remain independent")

func _lifetime(source: UnitStats, tower: UnitStats) -> int:
	var engine := CombatEngine.new(BalanceSettings.new())
	engine.external_control = true
	engine.reset(source, tower, Vector2.ZERO, Vector2(200, 0))
	engine.units[1].target_id = "blue_01"
	for tick in range(2000):
		engine.step()
		if not engine.units[0].alive: return engine.tick_count
	return 2000

func _test_durability() -> void:
	var settings: MatchSettings = load("res://data/match/default_match.tres")
	var melee := _lifetime(settings.melee_creep, settings.tower)
	var siege := _lifetime(settings.siege_creep, settings.tower)
	check(settings.melee_creep.base_hp == 700 and settings.ranged_creep.base_hp == 450, "Both regular creep types more durable")
	check(siege > melee * 2 and siege >= 300, "Real tower projectiles leave siege alive more than twice as long as melee")
	check(settings.siege_creep.ranged_attacks and settings.siege_creep.projectile_speed == 650, "Catapult uses shared projectile attacks")
	check(settings.tower.attack_range == 600 and settings.hero.attack_range == 550 and settings.melee_creep.attack_range == 110 and settings.ranged_creep.attack_range == 390 and settings.siege_creep.attack_range == 300, "Tower, hero and three creep profiles retain independent attack ranges")
	for source in [settings.tower, settings.hero, settings.melee_creep, settings.ranged_creep, settings.siege_creep]:
		var engine := CombatEngine.new(BalanceSettings.new())
		engine.external_control = true
		var center_distance: float = source.collision_radius + settings.hero.collision_radius + source.attack_range
		engine.reset(source, settings.hero, Vector2.ZERO, Vector2(center_distance + 1, 0))
		engine.units[0].target_id = "red_01"
		var hp: float = engine.units[1].current_hp
		engine.step()
		check(engine.projectiles.is_empty() and engine.units[1].current_hp == hp, source.display_name + " cannot attack beyond its own edge range")
		engine.units[1].position.x -= 2
		engine.step()
		check(not engine.projectiles.is_empty() or engine.units[1].current_hp < hp, source.display_name + " can attack within its own edge range")
	print("Tower-only survival: melee %.2fs / siege %.2fs" % [melee / 30.0, siege / 30.0])

func _test_scene() -> void:
	var main = load("res://scenes/match/moba_match.tscn").instantiate()
	main.settings = main.settings.duplicate(true)
	main.settings.show_draft_on_start = false
	main.settings.maximum_live_creeps = 0
	main.settings.fountain_radius = 0
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.clock.set_running(false)
	main.next_wave_tick = 99999
	for info in main.entities.values(): info.actor.paused = true; info.actor.runtime.stats.physical_damage = 0
	main.settings.maximum_live_creeps = 200
	main.spawn_wave()
	var siege := 0
	for info in main.entities.values():
		if info.get("siege", false):
			siege += 1
			check(info.actor.view.siege_visual and info.actor.runtime.structure_damage_multiplier == 1.0 and not info.route.is_empty(), "Siege shares view/runtime/navigation and has full siege multiplier")
	check(siege == 6 and main.wave_number == 1, "First wave adds one siege creep to each team/lane")
	main.spawn_wave(); main.spawn_wave(); main.spawn_wave()
	var total_siege := 0
	for info in main.entities.values():
		if info.get("siege", false): total_siege += 1
	check(total_siege == 12 and main.wave_number == 4, "Siege appears every third wave thereafter")
	main.settings.maximum_live_creeps = 0
	var wave: int = main.wave_number
	main.spawn_wave()
	check(main.wave_number == wave, "Cap includes siege and rejects full wave atomically")
	# Move a real tower duel away from wave spawns and let impacts determine payout.
	var tower: MapUnit = main.entities.tower_00.actor
	var point: Vector2 = main.layout.cell_center(Vector2i(15, 24))
	tower.position = point; tower.runtime.position = point
	main.player.position = point + Vector2(100, 0); main.player.runtime.position = main.player.position
	main.enemy_hero.position = point + Vector2(200, 0); main.enemy_hero.runtime.position = main.enemy_hero.position
	main.enemy_hero.runtime.current_hp = 40
	main.player.runtime.stats.physical_damage = 1
	main.player.runtime.stats.ranged_attacks = false
	main.request_attack("hero"); main.locked_target = "enemy_hero"
	for info in main.entities.values(): info.actor.paused = true
	var before: int = main.progression.player.gold
	main.clock.step()
	check(main.rewards.damage_history.get("enemy_hero", {}).has("player"), "Actual positive hero impact registers credit")
	main._stop_player()
	tower.runtime.stats.physical_damage = 10000
	tower.runtime.next_attack_tick = main.combat.tick_count + 1
	var hp: float = main.enemy_hero.runtime.current_hp
	main.clock.step()
	check(main.enemy_hero.runtime.current_hp >= hp and main.progression.player.gold == before, "Tower launch does not prematurely grant kill gold")
	for tick in range(25): main.clock.step()
	check(not main.enemy_hero.runtime.alive and main.progression.player.gold == before + 133, "Actual tower lethal impact credits recent player exactly once")
	check(not main.rewards.damage_history.has("enemy_hero"), "Scene death clears damage credit")
	main._revive("enemy_hero")
	check(not main.rewards.damage_history.has("enemy_hero"), "Scene revive cannot reuse old credit")
	main.enemy_hero.position = point + Vector2(200, 0)
	main.enemy_hero.runtime.position = main.enemy_hero.position
	main.enemy_hero.runtime.current_hp = 40
	tower.runtime.next_attack_tick = main.combat.tick_count + 1
	for tick in range(25): main.clock.step()
	check(not main.enemy_hero.runtime.alive and main.progression.player.gold == before + 266, "Unassisted real tower kill pays single-player team bounty after respawn")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		main.camera.follow_enabled = false
		main.camera.position = main.layout.spawn_points(0)[0]
		main.camera.set_zoom_level(0.9)
		main._refresh_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/siege-creeps.png") == OK, "Siege silhouettes rendered")
	main.queue_free()
	await process_frame

