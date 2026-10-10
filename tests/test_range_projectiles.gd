extends SceneTree

var checks := 0
var failures := 0
var balance := BalanceSettings.new()

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func near(value: float, expected: float, description: String) -> void:
	check(absf(value - expected) < 0.000001, "%s: %.8f != %.8f" % [description, value, expected])

func actor(ranged: bool = false) -> UnitStats:
	var unit := UnitStats.new()
	unit.physical_damage = 100
	unit.base_attacks_per_second = 0.3
	unit.ranged_attacks = ranged
	unit.attack_range = 550 if ranged else 150
	unit.base_mana = 1000
	return unit

func duel(source: UnitStats, distance: float = 364) -> CombatEngine:
	var engine := CombatEngine.new(balance)
	engine.reset(source, UnitStats.new(), Vector2(100, 450), Vector2(100 + distance, 450), 123)
	return engine

func has(events: Array[Dictionary], kind: String) -> bool:
	for event in events:
		if event.kind == kind: return true
	return false

func skill(kind: int = AbilityData.TargetType.ENEMY, projectile: bool = false) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = "range_test"
	ability.display_name = "Range test"
	ability.target_type = kind
	ability.mana_cost = 50
	ability.cooldown = 20
	ability.effect_radius = 25
	ability.uses_projectile = projectile
	var effect := AbilityEffectData.new()
	effect.kind = StatusEffect.Kind.SLOW
	effect.duration = 5
	effect.magnitude = 0.4
	ability.effects = [effect]
	return ability

func _run() -> void:
	_ranges()
	_projectiles()
	_abilities()
	_movement()
	_determinism()
	await _ui()
	print("Range/projectile: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _ranges() -> void:
	var melee := actor()
	var engine := duel(melee, 214.001)
	check(not has(engine.step(), "damage"), "Melee cannot hit just beyond edge range")
	engine = duel(melee, 214)
	check(has(engine.step(), "damage"), "Melee hits exact edge boundary instantly")
	near(engine.units[1].current_hp, 900, "Instant melee damage")
	var ranged := actor(true)
	engine = duel(ranged, 614.001)
	check(not has(engine.step(), "projectile_launched"), "Ranged cannot launch beyond range")
	engine = duel(ranged, 614)
	check(has(engine.step(), "projectile_launched"), "Ranged reaches farther than melee")
	melee.collision_radius = 20
	engine = duel(melee, 202)
	check(has(engine.step(), "damage"), "Different unit radii used at boundary")
	var lens: EquipmentData = load("res://data/equipment/range_lens.tres")
	var focus: EquipmentData = load("res://data/equipment/cast_focus.tres")
	var items: Array[EquipmentData] = [lens, focus]
	engine.reset(melee, UnitStats.new(), Vector2(100, 450), Vector2(352, 450), 123, items)
	near(engine.units[0].attack_range(), 250, "Attack equipment bonus")
	near(engine.units[0].cast_range(), 850, "Cast equipment bonus")
	check(has(engine.step(), "damage"), "Bonus permits actual attack")
	engine.reset(melee, UnitStats.new(), Vector2(100, 450), Vector2(352, 450))
	near(engine.units[0].attack_range(), 150, "Equipment removal restores attack range")
	near(engine.units[0].cast_range(), 700, "Equipment removal restores cast range")
	engine.queue_effect("debug", "blue_01", StatusEffect.Kind.ATTACK_RANGE, 1, 100, "attack_bonus")
	engine.step()
	near(engine.units[0].attack_range(), 250, "Temporary attack bonus")
	near(engine.units[0].cast_range(), 700, "Attack bonus does not change cast range")
	engine.queue_effect("debug", "blue_01", StatusEffect.Kind.CAST_RANGE, 1, -200, "cast_penalty")
	engine.step()
	near(engine.units[0].cast_range(), 500, "Temporary cast penalty")
	near(engine.units[0].attack_range(), 250, "Cast penalty does not change attack range")
	for tick in range(30): engine.step()
	near(engine.units[0].attack_range(), 150, "Attack bonus expires")
	near(engine.units[0].cast_range(), 700, "Cast penalty expires")

func _projectiles() -> void:
	var source := actor(true)
	var engine := duel(source)
	var events := engine.step()
	check(has(events, "projectile_launched") and not has(events, "damage"), "Launch does not damage")
	near(engine.projectiles[0].position.x, 132, "Projectile starts at source edge")
	for index in range(9):
		engine.step()
		near(engine.units[1].current_hp, 1000, "No damage before impact tick")
	near(engine.projectiles[0].position.x, 402, "Nine fixed ticks travel 270 units")
	events = engine.step()
	check(has(events, "projectile_impact") and has(events, "damage"), "300 edge units at 900/s impact after ten ticks")
	near(engine.units[1].current_hp, 900, "Impact damage exactly once")
	check(engine.projectiles.is_empty(), "Impacted projectile removed")
	engine = duel(source)
	engine.step()
	engine.units[0].stats.physical_damage = 1000
	engine.units[1].stats.physical_armor = 10
	for tick in range(10): engine.step()
	near(engine.units[1].current_hp, 937.5, "Launch snapshots attacker damage; impact uses current target armor")
	source.critical_chance = 1
	engine = duel(source)
	engine.step()
	for tick in range(10): engine.step()
	near(engine.units[1].current_hp, 800, "Projectile crit preserves damage formula")
	source.critical_chance = 0
	var original_cap := balance.evasion_cap
	balance.evasion_cap = 1
	engine = duel(source)
	engine.units[1].stats.evasion = 1
	engine.step()
	for tick in range(10): engine.step()
	near(engine.units[1].current_hp, 1000, "Miss rolled at impact causes no damage")
	check(engine.metrics.by_unit.blue_01.missed_attacks == 1, "Projectile miss metrics recorded once")
	balance.evasion_cap = original_cap
	engine = duel(source)
	engine.step()
	engine.units[1].position.x += 90
	for tick in range(12): engine.step()
	near(engine.units[1].current_hp, 1000, "Homing follows moving target with longer travel")
	engine.step()
	near(engine.units[1].current_hp, 900, "Homing hits after thirteen travel ticks")
	source.projectile_hit_behavior = CombatProjectile.HitBehavior.FIXED_POSITION
	engine = duel(source)
	engine.step()
	engine.units[1].position.y += 100
	var evaded := false
	for tick in range(12): evaded = has(engine.step(), "projectile_evaded") or evaded
	check(evaded and engine.units[1].current_hp == 1000, "Fixed-position projectile safely misses moving target")
	source.projectile_hit_behavior = CombatProjectile.HitBehavior.HOMING
	engine = duel(source)
	engine.step()
	engine.units[1].alive = false
	engine.units[1].current_hp = 0
	check(has(engine.step(), "projectile_canceled") and engine.projectiles.is_empty(), "Dead target cancels projectile safely")
	source.projectile_dead_target_behavior = CombatProjectile.DeadTargetBehavior.CONTINUE_TO_POSITION
	engine = duel(source)
	engine.step()
	engine.units[1].alive = false
	engine.units[1].current_hp = 0
	var impact := false
	for tick in range(12):
		events = engine.step()
		impact = impact or has(events, "projectile_impact")
		check(not has(events, "damage"), "Dead target never takes projectile damage")
	check(impact and engine.projectiles.is_empty(), "Configured projectile continues visually to dead target position")
	source.projectile_dead_target_behavior = CombatProjectile.DeadTargetBehavior.CANCEL
	engine = duel(source)
	engine.step()
	engine.units[0].alive = false
	engine.units[0].current_hp = 0
	for tick in range(10): engine.step()
	near(engine.units[1].current_hp, 900, "In-flight attack survives caster death")
	check(engine.finished and engine.winner_team == 1, "Victory waits for in-flight projectiles")
	engine = duel(source)
	engine.step()
	var clock := SimulationClock.new()
	clock.ticked.connect(func(_tick: int): engine.step())
	var position := engine.projectiles[0].position
	clock.advance(100)
	check(engine.projectiles[0].position == position and engine.tick_count == 1, "Pause freezes projectile simulation")
	clock.step()
	near(engine.projectiles[0].position.x, position.x + 30, "Paused single-step advances projectile once")
	engine.reset(source, UnitStats.new(), Vector2(100, 450), Vector2(464, 450))
	check(engine.projectiles.is_empty(), "Reset clears projectiles")
	var limited := BalanceSettings.new()
	limited.projectile_lifetime_seconds = 0.1
	engine = CombatEngine.new(limited)
	engine.reset(source, UnitStats.new(), Vector2(100, 450), Vector2(464, 450))
	engine.step()
	for tick in range(2): engine.step()
	check(has(engine.step(), "projectile_canceled"), "Finite configurable lifetime prevents endless homing")

func _abilities() -> void:
	var source := actor()
	source.physical_damage = 0
	var ability := skill()
	source.abilities = [ability]
	var engine := duel(source, 764.001)
	engine.queue_cast("blue_01", 0, "red_01", engine.units[1].position)
	check(not has(engine.step(), "cast"), "Cast outside unit edge range rejected")
	near(engine.units[0].current_mana, 1000, "Rejected cast costs no mana")
	engine = duel(source, 764)
	engine.queue_cast("blue_01", 0, "red_01", engine.units[1].position)
	check(has(engine.step(), "effect_applied"), "Independent 700 cast range works outside attack range")
	var focus: Array[EquipmentData] = [load("res://data/equipment/cast_focus.tres")]
	engine.reset(source, UnitStats.new(), Vector2(100, 450), Vector2(1000, 450), 123, focus)
	engine.queue_cast("blue_01", 0, "red_01", engine.units[1].position)
	check(has(engine.step(), "effect_applied"), "Cast equipment permits longer cast")
	near(engine.units[0].attack_range(), 150, "Cast equipment leaves attack range unchanged")
	ability.cast_range = 100
	near(engine.units[0].cast_range(ability), 250, "Ability override still receives cast equipment")
	ability.cast_range = 0
	ability.uses_projectile = true
	engine = duel(source)
	engine.queue_cast("blue_01", 0, "red_01", engine.units[1].position)
	check(has(engine.step(), "projectile_launched") and engine.units[1].effects.active.is_empty(), "Ability projectile delays status effect")
	for tick in range(9): engine.step()
	check(engine.units[1].effects.active.is_empty(), "Ability has no effect in transit")
	engine.step()
	check(engine.units[1].effects.strongest_slow() == 0.4, "Ability effect applied at impact")
	for mode in [AbilityData.TargetType.GROUND, AbilityData.TargetType.DIRECTIONAL]:
		ability = skill(mode)
		source.abilities = [ability]
		engine = duel(source)
		engine.units[1].position = Vector2(300, 450)
		engine.queue_cast("blue_01", 0, "", Vector2(464, 450))
		engine.step()
		check(engine.units[1].effects.active.is_empty() if mode == AbilityData.TargetType.GROUND else not engine.units[1].effects.active.is_empty(), "Ground disk versus directional capsule geometry")
		engine = duel(source)
		engine.units[1].position = Vector2(464, 508)
		engine.queue_cast("blue_01", 0, "", Vector2(464, 450))
		engine.step()
		check(engine.units[1].effects.active.is_empty(), "Outside radius plus target collision radius rejected")
		engine = duel(source)
		engine.units[1].position = Vector2(464, 507)
		engine.queue_cast("blue_01", 0, "", Vector2(464, 450))
		engine.step()
		check(not engine.units[1].effects.active.is_empty(), "Effect radius boundary includes target collision radius")
		engine = duel(source)
		engine.queue_cast("blue_01", 0, "", Vector2(833, 450))
		check(not has(engine.step(), "cast"), "Ground/directional range uses caster radius only")
	ability = skill(AbilityData.TargetType.GROUND, true)
	source.abilities = [ability]
	engine = duel(source)
	engine.queue_cast("blue_01", 0, "", Vector2(464, 450))
	engine.step()
	for tick in range(11): engine.step()
	check(engine.units[1].effects.active.is_empty(), "Ground projectile travels to point rather than target edge")
	engine.step()
	check(not engine.units[1].effects.active.is_empty(), "Ground projectile resolves disk at arrival")

func _movement() -> void:
	for ranged in [false, true]:
		var source := actor(ranged)
		var target := UnitStats.new()
		target.ai_mode = CombatAI.Mode.PASSIVE
		var engine := CombatEngine.new(balance)
		engine.reset_scenario([{"id": "blue", "team": 0, "source": source, "position": Vector2(100, 450)}, {"id": "red", "team": 1, "source": target, "position": Vector2(1000, 450)}])
		for tick in range(80): engine.step()
		near(engine.units[0].distance_to_unit(engine.units[1]), source.attack_range, "AI moves to exact melee/ranged edge range")
		var before := engine.units[0].position
		engine.step()
		check(engine.units[0].position == before, "AI stops approaching within valid range")
	var source := actor()
	source.attack_range = 550
	var ability := skill()
	ability.cast_range = 100
	source.abilities = [ability]
	var target := UnitStats.new()
	target.ai_mode = CombatAI.Mode.PASSIVE
	var engine := CombatEngine.new(balance)
	engine.reset_scenario([{"id": "blue", "team": 0, "source": source, "position": Vector2(100, 450)}, {"id": "red", "team": 1, "source": target, "position": Vector2(800, 450)}])
	var cast := false
	for tick in range(70): cast = has(engine.step(), "cast") or cast
	check(cast and engine.units[0].distance_to_unit(engine.units[1]) <= 100, "AI approaches shorter cast range despite longer attack range")

func _determinism() -> void:
	var reference: Array[Dictionary] = []
	var result: Dictionary = {}
	for speed in SimulationClock.SPEEDS:
		var source := actor(true)
		source.critical_chance = 0.4
		source.accuracy = 0.1
		var target := actor(true)
		target.evasion = 0.35
		var engine := CombatEngine.new(balance)
		engine.reset(source, target, Vector2(100, 450), Vector2(464, 450), 4321)
		var events: Array[Dictionary] = []
		var clock := SimulationClock.new()
		var on_tick := func(tick: int):
			if tick == 5: engine.queue_effect("blue_01", "red_01", StatusEffect.Kind.CAST_RANGE, 1, 25, "command")
			events.append_array(engine.step())
			if engine.finished: clock.set_running(false)
		clock.ticked.connect(on_tick)
		clock.set_speed(speed)
		clock.set_running(true)
		clock.advance(200 / speed)
		clock.ticked.disconnect(on_tick)
		check(engine.finished, "Seeded projectile battle completes")
		if reference.is_empty():
			reference = events
			result = engine.result()
		else:
			check(events == reference and engine.result() == result, "Seed and tick commands reproduce at %sx" % speed)

func _ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.unit_editor.fields.has("cast_range") and main.unit_editor.fields.has("projectile_speed"), "UI exposes independent range and projectile speed")
	main.count_fields[0].value = 5
	main.count_fields[1].value = 5
	main._select_id("blue_04")
	main.clock.set_running(true)
	main.clock.advance(1)
	main.clock.set_running(false)
	check(not main.combat.projectiles.is_empty(), "5v5 UI has visible in-flight projectiles")
	var before: Vector2 = main.combat.projectiles[0].position
	await process_frame
	await process_frame
	check(main.combat.projectiles[0].position == before, "Renderer never advances paused projectiles")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/range-projectile-preview.png") == OK, "Rendered projectile and range indicators captured")
	main.queue_free()
	await process_frame
