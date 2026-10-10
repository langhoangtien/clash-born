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

func _engine(blue: UnitStats, red: UnitStats, seed_value: int = 42) -> CombatEngine:
	var engine := CombatEngine.new(balance)
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0), seed_value)
	return engine

func _count(events: Array[Dictionary], kind: String, source_id: String = "blue_01") -> int:
	var count := 0
	for event in events:
		if event.kind == kind and event.source_unit_id == source_id:
			count += 1
	return count

func _run() -> void:
	_test_stats_and_hits()
	_test_attacks()
	_test_effects()
	_test_replay()
	await _test_scene()
	print("Phase 3: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_stats_and_hits() -> void:
	var source := UnitStats.new()
	source.agility = 40
	source.base_attacks_per_second = 1.5
	source.attack_speed_bonus = 0.3
	source.evasion_sources = [0.3, 0.3]
	source.status_resistance = 0.9
	var stats := StatCalculator.calculate(source, balance)
	_near(stats.attack_speed, 2.25, "AGI and flat bonuses add before multiplying base APS")
	_near(stats.evasion, 0.51, "Independent evasion stacks multiplicatively")
	_near(stats.status_resistance, 0.6, "Status resistance cap")
	_near(stats.critical_multiplier, 2, "Central critical multiplier default")
	source.base_attacks_per_second = 100
	_near(StatCalculator.calculate(source, balance).attack_speed, 3, "Attack speed maximum")
	source.base_attacks_per_second = 0
	_near(StatCalculator.calculate(source, balance).attack_speed, 0.3, "Attack speed minimum")
	balance.minimum_attack_interval = 0.5
	source.base_attacks_per_second = 100
	_near(StatCalculator.calculate(source, balance).attack_speed, 2, "Minimum interval respected")
	balance.minimum_attack_interval = 0.1
	_near(HitCalculator.combine_evasion([0.9, 0.9], balance), 0.75, "Evasion cap")
	balance.multiplicative_evasion = false
	_near(HitCalculator.combine_evasion([0.3, 0.3], balance), 0.6, "Configurable additive evasion")
	balance.multiplicative_evasion = true
	_near(HitCalculator.effective_evasion(0.3, 0.2, balance), 0.1, "Accuracy subtracts percentage points")
	_near(HitCalculator.effective_evasion(0.75, 1.0, balance), 0, "100 point accuracy removes ordinary evasion")
	_near(DamageCalculator.effective_armor(30, 20, 0.5), 5, "Flat reduction before penetration")
	_near(DamageCalculator.effective_armor(10, 20, 0.5), -5, "Negative armor follows same penetration order")
	_near(DamageCalculator.effective_armor(30, 0, 2), 0, "Penetration clamped at 100 percent")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var attacker := StatCalculator.calculate(UnitStats.new(), balance)
	var defender := attacker.duplicate()
	attacker.critical_chance = 0.25
	attacker.physical_damage = 100.0
	defender.evasion = 0.3
	var misses := 0
	var criticals := 0
	for hit_index in range(10000):
		var hit := HitCalculator.resolve(attacker, defender, rng, balance)
		if hit.missed: misses += 1
		if hit.critical: criticals += 1
		if hit.missed and hit.critical:
			_check(false, "A miss cannot critically strike")
	_check(absf(misses / 10000.0 - 0.3) < 0.02, "Observed miss rate approaches 30 percent")
	_check(absf(criticals / float(10000 - misses) - 0.25) < 0.02, "Critical probability measured only among hits")
	attacker.accuracy = 0.3
	misses = 0
	for hit_index in range(1000):
		if HitCalculator.resolve(attacker, defender, rng, balance).missed: misses += 1
	_check(misses == 0, "Accuracy removes misses over 1000 attacks")

func _test_attacks() -> void:
	var blue := UnitStats.new()
	var red := UnitStats.new()
	blue.base_attacks_per_second = 1.7
	var engine := _engine(blue, red)
	var attack_ticks: Array[int] = []
	for tick in range(300):
		for event in engine.step():
			if event.kind == "attack" and event.source_unit_id == "blue_01": attack_ticks.append(event.tick)
	_check(attack_ticks.size() == 17, "1.7 APS gives 17 attacks in ten seconds without rounded interval drift")
	for index in range(attack_ticks.size()):
		_check(attack_ticks[index] == ceili(1 + index * 30.0 / 1.7 - 0.000000001), "Fractional schedule tick %d" % index)
	blue.base_attacks_per_second = 1
	blue.physical_damage = 100
	blue.magic_damage = 100
	blue.pure_damage = 25
	blue.critical_chance = 1
	red.physical_armor = 20
	red.magic_armor = 20
	engine = _engine(blue, red)
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 400 / 2.2 - 25, "Critical before armor, pure excluded by default")
	blue.pure_attacks_can_crit = true
	engine = _engine(blue, red)
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 400 / 2.2 - 50, "Explicit pure critical flag")
	blue.attacks_can_crit = false
	engine = _engine(blue, red)
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 200 / 2.2 - 25, "Critical flag disabled")
	balance.evasion_cap = 1
	red.evasion = 1
	blue.attacks_can_crit = true
	engine = _engine(blue, red)
	var events := engine.step()
	_near(engine.units[1].current_hp, 1000, "Miss blocks every component including pure")
	_check(_count(events, "miss") == 1 and _count(events, "damage") == 0, "Miss emits event and no damage")
	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 42
	control_rng.randf()
	# Red resolves a hit but has no eligible damage for a critical roll.
	control_rng.randf()
	_check(engine.rng.state == control_rng.state, "Miss never consumes critical RNG roll")
	blue.attacks_can_miss = false
	engine = _engine(blue, red)
	engine.step()
	_check(engine.units[1].current_hp < 1000, "Explicit cannot-miss flag bypasses evasion")
	var pure_attacker := StatCalculator.calculate(UnitStats.new(), balance)
	pure_attacker.pure_damage = 100.0
	pure_attacker.critical_chance = 1.0
	var pure_rng := RandomNumberGenerator.new()
	pure_rng.seed = 1
	_check(not HitCalculator.resolve(pure_attacker, pure_attacker, pure_rng, balance).critical, "Pure-only attack cannot emit an ineligible critical")
	pure_attacker.pure_attacks_can_crit = true
	_check(HitCalculator.resolve(pure_attacker, pure_attacker, pure_rng, balance).critical, "Pure-only critical requires explicit eligibility")
	balance.evasion_cap = 0.75
	red.evasion = 0
	blue.armor_reduction = 30
	blue.physical_armor_penetration = 0.5
	blue.magic_armor_reduction = 30
	blue.attacks_can_crit = false
	engine = _engine(blue, red)
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 100 * DamageCalculator.armor_multiplier(-5, 0.06) - 137.5 - 25, "Attack reductions produce negative physical and magic armor")

func _test_effects() -> void:
	var blue := UnitStats.new()
	var red := UnitStats.new()
	red.physical_damage = 10
	red.status_resistance = 0.25
	var engine := _engine(blue, red)
	engine.queue_effect("blue_01", "red_01", StatusEffect.Kind.STUN, 4, 0, "stun_a")
	var events := engine.step()
	var target := engine.units[1]
	_check(target.effects.active[0].duration_ticks == 90, "4 second stun with 25 percent resistance lasts 3 seconds")
	_check(not target.can_move() and not target.can_cast() and not target.can_act(), "Stun blocks movement, casting and attacking")
	_near(target.effects.active[0].remaining_seconds(1), 3, "Remaining stun duration")
	for tick in range(89):
		_check(_count(engine.step(), "attack", "red_01") == 0, "Stunned unit cannot attack")
	_check(target.effects.is_stunned(), "Stun remains through last active tick")
	events = engine.step()
	_check(not target.effects.is_stunned() and target.can_move() and target.can_cast(), "Stun expires on exact boundary")
	_check(_count(events, "attack", "red_01") == 1, "Recovery allows one attack, no backlog burst")
	var expiry_count := 0
	for event in events:
		if event.kind == "effect_expired": expiry_count += 1
	_check(expiry_count == 1, "Expiration event emitted once")
	red.status_resistance = 0
	engine = _engine(blue, red)
	engine.queue_effect("a", "red_01", StatusEffect.Kind.STUN, 3, 0, "a")
	engine.step()
	for tick in range(59): engine.step()
	engine.queue_effect("b", "red_01", StatusEffect.Kind.STUN, 3, 0, "b")
	engine.step()
	for tick in range(89): engine.step()
	_check(engine.units[1].effects.is_stunned() and engine.units[1].effects.active.size() == 1, "Overlapping stuns chain to five seconds, not six")
	engine.step()
	_check(not engine.units[1].effects.is_stunned(), "Last overlapping stun expires at tick 151")
	engine = _engine(blue, red)
	engine.queue_effect("a", "red_01", StatusEffect.Kind.SLOW, 2, 0.4, "a")
	engine.queue_effect("b", "red_01", StatusEffect.Kind.SLOW, 1, 0.2, "b")
	engine.step()
	_near(engine.units[1].movement_speed(balance), 180, "Strongest slow only, 300 becomes 180")
	for tick in range(60): engine.step()
	_near(engine.units[1].movement_speed(balance), 300, "Movement restored after slow expiration")
	engine.queue_effect("a", "red_01", StatusEffect.Kind.SLOW, 1, 0.4, "a")
	engine.queue_effect("b", "red_01", StatusEffect.Kind.SLOW, 2, 0.2, "b")
	engine.step()
	for tick in range(30): engine.step()
	_near(engine.units[1].movement_speed(balance), 240, "Weaker slow remains after strongest expires")
	for tick in range(30): engine.step()
	_near(engine.units[1].movement_speed(balance), 300, "Last slow expires independently")
	engine.queue_effect("a", "red_01", StatusEffect.Kind.SLOW, 1, 0.99, "a")
	engine.step()
	_near(engine.units[1].movement_speed(balance), 100, "Movement speed minimum while heavily slowed")
	engine = _engine(blue, red)
	engine.queue_effect("a", "red_01", StatusEffect.Kind.ARMOR_REDUCTION, 1, 15, "armor")
	engine.queue_effect("b", "red_01", StatusEffect.Kind.ARMOR_REDUCTION, 2, 10, "armor")
	engine.step()
	_near(engine.units[1].physical_armor(), -25, "Distinct sources stack armor reductions")
	engine.queue_effect("a", "red_01", StatusEffect.Kind.ARMOR_REDUCTION, 2, 15, "armor")
	engine.step()
	_check(engine.units[1].effects.active.size() == 2, "Same source/instance refreshes without duplicate")
	for tick in range(59): engine.step()
	_near(engine.units[1].physical_armor(), -15, "Other armor source expires independently")
	engine.step()
	_near(engine.units[1].physical_armor(), 0, "Armor returns exactly after refreshed effect expires")
	_near(red.physical_armor, 0, "Temporary effect does not mutate source armor")
	engine.queue_effect("a", "red_01", StatusEffect.Kind.STUN, 1, 0, "pending")
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0))
	engine.step()
	_check(engine.units[1].effects.active.is_empty(), "Reset clears active effects and pending commands")
	blue.physical_damage = 100
	engine = _engine(blue, red)
	engine.queue_effect("a", "red_01", StatusEffect.Kind.ARMOR_REDUCTION, 1, 15, "armor")
	engine.step()
	_near(engine.units[1].current_hp, 1000 - 100 * (2 - 1 / 1.9), "Active temporary armor reduction amplifies physical damage")
	for tick in range(30): engine.step()
	_near(engine.units[1].current_hp, 900 - 100 * (2 - 1 / 1.9), "Attack on expiration tick uses restored armor")
	_check(engine.units[1].effects.active.is_empty(), "Armor effect removed before attack resolution")

func _test_replay() -> void:
	var blue := UnitStats.new()
	var red := UnitStats.new()
	blue.physical_damage = 5
	blue.evasion = 0.3
	blue.critical_chance = 0.25
	blue.base_attacks_per_second = 1.7
	red.magic_damage = 7
	red.evasion = 0.4
	red.critical_chance = 0.2
	var reference: Array[Dictionary] = []
	for speed in SimulationClock.SPEEDS:
		var engine := _engine(blue, red, 12345)
		var events: Array[Dictionary] = []
		var clock := SimulationClock.new()
		var on_tick := func(tick: int):
			if tick == 30: engine.queue_effect("blue_01", "red_01", StatusEffect.Kind.STUN, 1, 0, "stun")
			if tick == 150: engine.queue_effect("red_01", "blue_01", StatusEffect.Kind.ARMOR_REDUCTION, 2, 15, "armor")
			events.append_array(engine.step())
		clock.ticked.connect(on_tick)
		clock.set_speed(speed)
		clock.set_running(true)
		clock.advance(10 / speed)
		clock.ticked.disconnect(on_tick)
		_check(engine.tick_count == 300, "Replay fixed tick count at %sx" % speed)
		if reference.is_empty(): reference = events
		else: _check(events == reference, "Seeded commands/events reproduce at %sx" % speed)
	var engine := _engine(blue, red, 12345)
	var first: Array[Dictionary] = []
	for tick in range(100): first.append_array(engine.step())
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0), 12345)
	var second: Array[Dictionary] = []
	for tick in range(100): second.append_array(engine.step())
	_check(first == second, "Reset repeats RNG sequence")
	engine.reset(blue, red, Vector2.ZERO, Vector2(100, 0), 54321)
	second.clear()
	for tick in range(100): second.append_array(engine.step())
	_check(first != second, "Different seed changes random events")

func _test_scene() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.effect_buttons[0].pressed.emit()
	_check(main.combat.units[1].effects.active.is_empty(), "UI queues effect without mutating state while paused")
	main.step_button.pressed.emit()
	_check(main.combat.units[1].effects.is_stunned(), "Debug effect applied on next Step")
	main.effect_buttons[1].pressed.emit()
	main.effect_buttons[2].pressed.emit()
	main.step_button.pressed.emit()
	_check(main.combat.units[1].effects.active.size() == 3, "Debug buttons apply all three supported effects")
	if "--capture" in OS.get_cmdline_user_args():
		_check(DisplayServer.get_name() != "headless", "Capture uses real renderer")
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.local")
			_check(root.get_texture().get_image().save_png("res://.local/phase3-preview.png") == OK, "Rendered status effects screenshot saved")
	main.seed_field.value = 55
	main._reset()
	_check(main.combat.random_seed == 55 and main.combat.units[1].effects.active.is_empty(), "UI Reset sets seed and removes effects")
	main.queue_free()
	await process_frame
