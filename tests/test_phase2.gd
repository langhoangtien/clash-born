extends SceneTree

var failures: int = 0
var checks: int = 0
var balance := BalanceSettings.new()

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _near(actual: float, expected: float, description: String) -> void:
	_check(absf(actual - expected) < 0.000001, "%s: got %.8f, expected %.8f" % [description, actual, expected])

func _duel(blue: UnitStats, red: UnitStats) -> CombatEngine:
	var engine := CombatEngine.new(balance)
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0))
	return engine

func _run() -> void:
	_test_formulas()
	_test_attributes()
	_test_combat()
	await _test_scene()
	print("Phase 2: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_formulas() -> void:
	var cases := {0.0: 100.0, 10.0: 62.5, 20.0: 45.454545454545, 30.0: 35.714285714286, -10.0: 137.5, -20.0: 154.545454545455, -30.0: 164.285714285714, -100.0: 185.714285714286}
	for armor in cases:
		_near(DamageCalculator.calculate(100, DamageCalculator.DamageType.PHYSICAL, armor, 999, balance), cases[armor], "Physical armor %s" % armor)
		_near(DamageCalculator.calculate(100, DamageCalculator.DamageType.MAGICAL, 999, armor, balance), cases[armor], "Magic armor %s" % armor)
	_near(DamageCalculator.calculate(200, DamageCalculator.DamageType.MAGICAL, 0, 20, balance), 90.909090909091, "200 magic vs 20 armor")
	_near(DamageCalculator.calculate(200, DamageCalculator.DamageType.PURE, 50, 50, balance), 200, "Pure ignores both armors")
	_near(DamageCalculator.calculate(100, DamageCalculator.DamageType.PURE, -100, -100, balance), 100, "Pure ignores negative armor")
	_near(DamageCalculator.calculate(100, DamageCalculator.DamageType.PHYSICAL, 0.5, 0, balance), 100 / 1.03, "Fractional armor")
	_near(DamageCalculator.calculate(-10, DamageCalculator.DamageType.PURE, 0, 0, balance), 0, "Negative damage cannot heal")
	var amp0 := DamageCalculator.armor_multiplier(0, 0.06)
	var amp10 := DamageCalculator.armor_multiplier(-10, 0.06)
	var amp20 := DamageCalculator.armor_multiplier(-20, 0.06)
	var amp30 := DamageCalculator.armor_multiplier(-30, 0.06)
	_check(amp30 > amp20 and amp20 > amp10 and amp10 > amp0, "More negative armor increases damage")
	_check(amp30 - amp20 < amp20 - amp10 and amp20 - amp10 < amp10 - amp0, "Negative armor diminishing amplification")

func _test_attributes() -> void:
	var source := UnitStats.new()
	source.attack_range = 700
	source.base_hp = 100
	source.base_mana = 20
	source.strength = 10
	source.agility = 40
	source.intelligence = 20
	source.physical_armor = -10
	source.magic_armor = -5
	source.physical_damage = 100
	source.base_hp_regen = 2
	source.base_mana_regen = 1
	source.primary_attribute = UnitStats.PrimaryAttribute.AGILITY
	var stats := StatCalculator.calculate(source, balance)
	_near(stats.max_hp, 300, "STR max HP")
	_near(stats.max_mana, 260, "INT max mana")
	_near(stats.hp_regen, 2.5, "STR HP regeneration")
	_near(stats.mana_regen, 1.8, "INT mana regeneration")
	_near(stats.physical_armor, -4, "AGI fractional armor, negatives retained")
	_near(stats.magic_armor, -2, "INT magic armor")
	_near(stats.physical_damage, 140, "AGI primary damage")
	source.primary_attribute = UnitStats.PrimaryAttribute.STRENGTH
	_near(StatCalculator.calculate(source, balance).physical_damage, 110, "STR primary damage")
	source.primary_attribute = UnitStats.PrimaryAttribute.INTELLIGENCE
	_near(StatCalculator.calculate(source, balance).physical_damage, 120, "INT primary damage")
	source.primary_attribute = UnitStats.PrimaryAttribute.NONE
	_near(StatCalculator.calculate(source, balance).physical_damage, 100, "NONE primary damage")
	source.primary_attribute = UnitStats.PrimaryAttribute.AGILITY
	source.primary_damage_enabled = false
	_near(StatCalculator.calculate(source, balance).physical_damage, 100, "Per-unit primary toggle")
	source.primary_damage_enabled = true
	balance.primary_damage_enabled = false
	_near(StatCalculator.calculate(source, balance).physical_damage, 100, "Global primary toggle")
	balance.primary_damage_enabled = true
	_check(StatCalculator.calculate(source, balance) == stats, "Recalculation does not accumulate bonuses")
	_check(source.base_hp == 100 and source.physical_damage == 100, "Source data is unchanged")

func _test_combat() -> void:
	var blue := UnitStats.new()
	blue.attack_range = 700
	var red := UnitStats.new()
	red.attack_range = 700
	blue.physical_damage = 100
	blue.magic_damage = 200
	blue.pure_damage = 50
	red.physical_armor = 20
	red.magic_armor = 10
	var engine := _duel(blue, red)
	var events := engine.step()
	_near(engine.units[1].current_hp, 1000 - 100 / 2.2 - 200 / 1.6 - 50, "Mixed attack components reduce HP")
	var components: Array[int] = []
	for event in events:
		if event.kind == "damage":
			components.append(event.damage_type)
			_check(event.source_unit_id == "blue_01" and event.target_unit_id == "red_01" and event.tick == 1, "Structured damage identity and tick")
	_check(components == [0, 1, 2], "Physical, magical, pure component order")
	var decoded: Array = JSON.parse_string(JSON.stringify(events))
	_check(decoded.size() == events.size(), "Combat events are JSON serializable")
	for index in range(events.size()):
		for key in events[index]:
			var expected = events[index][key]
			if expected is float or expected is int:
				_check(is_equal_approx(decoded[index][key], expected), "Serialized event number %s" % key)
			else:
				_check(decoded[index][key] == expected, "Serialized event identity %s" % key)
	var hp_after_first := engine.units[1].current_hp
	for tick in range(29):
		engine.step()
	_near(engine.units[1].current_hp, hp_after_first, "No early attack before tick 31")
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 2 * (100 / 2.2 + 200 / 1.6 + 50), "Second attack exactly on tick 31")
	engine.units[0].current_hp = 500
	engine.units[0].current_mana = 0
	engine.units[0].stats.hp_regen = 30.0
	engine.units[0].stats.max_mana = 20.0
	engine.units[0].stats.mana_regen = 60.0
	engine.step()
	_near(engine.units[0].current_hp, 501, "HP regen per fixed tick")
	_near(engine.units[0].current_mana, 2, "Mana regen per fixed tick")
	engine.units[0].current_hp = 999.5
	engine.units[0].current_mana = 19.5
	engine.step()
	_near(engine.units[0].current_hp, 1000, "HP capped at maximum")
	_near(engine.units[0].current_mana, 20, "Mana capped at maximum")
	engine = CombatEngine.new(balance)
	engine.reset(blue, red, Vector2.ZERO, Vector2(1000, 0))
	engine.step()
	_near(engine.units[1].current_hp, 1000, "Out-of-range units cannot attack; no movement AI")
	blue.physical_damage = 5000
	blue.magic_damage = 0
	blue.pure_damage = 0
	engine = _duel(blue, red)
	events = engine.step()
	_check(engine.finished and engine.winner_team == 0 and not engine.units[1].alive, "Lethal attack ends duel")
	_near(engine.units[1].current_hp, 0, "HP cannot become negative")
	var deaths := 0
	for event in events:
		if event.kind == "death": deaths += 1
		if event.kind == "damage": _near(event.applied_damage, 1000, "Applied damage excludes overkill")
	_check(deaths == 1, "Death emitted once")
	_check(engine.step().is_empty() and engine.tick_count == 1, "Dead unit cannot attack or revive after finish")
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0))
	_check(not engine.finished and engine.tick_count == 0 and engine.units[1].alive and engine.units[1].current_hp == 1000, "Reset restores runtime health and life")
	_check(red.base_hp == 1000, "Damage/reset never mutate base resource")
	red.physical_damage = 5000
	engine = _duel(blue, red)
	engine.step()
	_check(engine.finished and engine.winner_team == -1 and not engine.units[0].alive and not engine.units[1].alive, "Same-tick lethal attacks result in draw")
	var source_blue: UnitStats = load("res://data/units/blue_stats.tres")
	var source_red: UnitStats = load("res://data/units/red_stats.tres")
	var reference: Array[Dictionary] = []
	for speed in SimulationClock.SPEEDS:
		var replay := _duel(source_blue, source_red)
		var clock := SimulationClock.new()
		var replay_events: Array[Dictionary] = []
		var on_tick := func(_index: int):
			for event in replay.step(): replay_events.append(event)
			if replay.finished: clock.set_running(false)
		clock.ticked.connect(on_tick)
		clock.set_speed(speed)
		clock.set_running(true)
		clock.advance(120 / speed)
		clock.ticked.disconnect(on_tick)
		_check(replay.finished and replay.tick_count == clock.tick_count, "Clock stops exactly at duel end at %sx" % speed)
		if reference.is_empty(): reference = replay_events
		else: _check(replay_events == reference, "Identical events at %sx" % speed)

func _test_scene() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var blue = main.get_node("Arena/BlueUnit")
	var red = main.get_node("Arena/RedUnit")
	var initial_hp: float = red.runtime.current_hp
	main.step_button.pressed.emit()
	# Phase 5 starts outside melee range; allow AI approach/cast/recovery first.
	for tick in range(600):
		if (red.runtime.current_hp < initial_hp and blue.runtime.current_hp < blue.runtime.stats.max_hp) or main.combat.finished: break
		main.clock.step()
	_check(red.runtime.current_hp < initial_hp and blue.runtime.current_hp < blue.runtime.stats.max_hp, "AI approach eventually attacks both units and updates bound state")
	main.run_button.pressed.emit()
	main.clock.advance(120)
	main._refresh_ui()
	_check(main.combat.finished and not main.clock.running and main.run_button.disabled and main.step_button.disabled, "UI pauses and disables combat controls after death")
	_check("wins" in main.battle_label.text or "Draw" in main.battle_label.text, "UI shows battle outcome")
	main._reset()
	_check(red.runtime.alive and red.runtime.current_hp == initial_hp and not main.run_button.disabled, "UI reset restores combat")
	if "--capture" in OS.get_cmdline_user_args():
		_check(DisplayServer.get_name() != "headless", "Capture requires real renderer")
		if DisplayServer.get_name() != "headless":
			for tick in range(121): main.clock.step()
			main._refresh_ui()
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.local")
			_check(root.get_texture().get_image().save_png("res://.local/phase2-preview.png") == OK, "Save mid-battle rendered screenshot")
	main.queue_free()
	await process_frame
