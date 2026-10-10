extends SceneTree

var failures: int = 0
var checks: int = 0
var balance := BalanceSettings.new()
var archetypes: Array[UnitStats] = preload("res://scripts/ui/sandbox_controller.gd").ARCHETYPES

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _near(actual: float, expected: float, description: String) -> void:
	_check(absf(actual - expected) < 0.000001, "%s: got %.8f expected %.8f" % [description, actual, expected])

func _entry(id: String, team: int, source: UnitStats, position_value: Vector2) -> Dictionary:
	return {"id": id, "team": team, "source": source, "position": position_value, "ai": true}

func _scenario() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for team in range(2):
		for slot in range(5):
			var source: UnitStats = archetypes[slot].duplicate(true)
			source.evasion = 0.15
			source.accuracy = 0.05
			source.critical_chance = 0.2
			entries.append(_entry("%s_%02d" % ["blue" if team == 0 else "red", slot + 1], team, source, Vector2(350 if team == 0 else 1250, 190 + slot * 130)))
	return entries

func _run() -> void:
	_test_data()
	_test_ai()
	_test_abilities()
	_test_metrics()
	_test_full_battle()
	await _test_ui()
	print("Phase 5: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_data() -> void:
	_check(archetypes.size() == 5, "Five editable archetypes")
	for archetype in archetypes:
		_check(not archetype.display_name.is_empty() and archetype.abilities.size() == 1, "Archetype has name and test ability")
		var ability := archetype.abilities[0]
		_check(not ability.id.is_empty() and ability.effects.size() == 1 and ability.target_type == AbilityData.TargetType.ENEMY, "Ability target and effect data loaded")
	var stun: AbilityData = load("res://data/abilities/stun_strike.tres")
	_check(stun.mana_cost == 80 and stun.cooldown == 15 and stun.effects[0].duration == 3, "Stun Strike prescribed values")
	var slow: AbilityData = load("res://data/abilities/heavy_slow.tres")
	_check(slow.mana_cost == 50 and slow.cooldown == 10 and slow.effects[0].duration == 5 and slow.effects[0].magnitude == 0.4, "Heavy Slow prescribed values")
	var armor: AbilityData = load("res://data/abilities/armor_shatter.tres")
	_check(armor.mana_cost == 60 and armor.cooldown == 12 and armor.effects[0].duration == 6 and armor.effects[0].magnitude == 15, "Armor Shatter prescribed values")

func _test_ai() -> void:
	var actor := UnitStats.new()
	actor.attack_range = 100
	actor.movement_speed = 300
	actor.physical_damage = 10
	var passive := UnitStats.new()
	passive.attack_range = 700
	passive.ai_mode = CombatAI.Mode.PASSIVE
	var high_damage: UnitStats = passive.duplicate(true)
	high_damage.physical_damage = 200
	var engine := CombatEngine.new(balance)
	var entries: Array[Dictionary] = [_entry("blue", 0, actor, Vector2(100, 450)), _entry("near", 1, passive, Vector2(500, 450)), _entry("far", 1, high_damage, Vector2(1000, 450))]
	_check(engine.reset_scenario(entries), "Valid 1v2 scenario accepted")
	_near(CombatAI.select_target(engine.units[0], engine.units).position.x, 500, "Nearest targeting")
	engine.units[2].current_hp = 100
	engine.units[0].ai_mode = CombatAI.Mode.LOWEST_HP
	_check(CombatAI.select_target(engine.units[0], engine.units).unit_id == "far", "Lowest absolute HP targeting")
	engine.units[0].ai_mode = CombatAI.Mode.HIGHEST_DAMAGE
	_check(CombatAI.select_target(engine.units[0], engine.units).unit_id == "far", "Highest basic DPS targeting")
	engine.units[0].ai_mode = CombatAI.Mode.NEAREST
	engine.step()
	_near(engine.units[0].position.x, 110, "Movement advances speed times fixed dt")
	_near(engine.units[1].position.x, 500, "Passive AI stays stationary")
	engine.queue_effect("debug", "blue", StatusEffect.Kind.STUN, 1, 0, "stun")
	engine.step()
	_near(engine.units[0].position.x, 110, "Stun prevents movement")
	for tick in range(30): engine.step()
	_check(engine.units[0].position.x > 110, "Movement resumes after stun")
	for tick in range(100): engine.step()
	_near(engine.units[0].position.distance_to(engine.units[1].position), 164, "Melee stops at attack range")
	engine.units[1].alive = false
	engine.units[1].current_hp = 0
	engine.step()
	_check(not engine.finished and engine.units[0].target_id == "far", "Retarget after death; battle continues while enemy team has survivors")
	var ranged: UnitStats = actor.duplicate(true)
	ranged.attack_range = 450
	entries = [_entry("blue", 0, ranged, Vector2(100, 450)), _entry("red", 1, passive, Vector2(1000, 450))]
	engine.reset_scenario(entries)
	for tick in range(100): engine.step()
	_near(engine.units[0].position.distance_to(engine.units[1].position), 514, "Ranged unit maintains attack distance without kiting")
	entries = [_entry("blue", 0, actor, Vector2(500, 450)), _entry("red", 1, actor, Vector2(500, 450))]
	engine.reset_scenario(entries)
	engine.step()
	_check(engine.units[0].position.distance_to(engine.units[1].position) >= balance.unit_radius * 2 - 0.000001, "Coincident units separate deterministically")
	var prior_count := engine.units.size()
	entries.append(_entry("blue", 0, actor, Vector2.ZERO))
	_check(not engine.reset_scenario(entries) and engine.units.size() == prior_count, "Duplicate IDs rejected without replacing valid state")
	entries = _scenario()
	entries.append(_entry("sixth", 0, actor, Vector2.ZERO))
	_check(not engine.reset_scenario(entries), "More than five units per team rejected")
	var short_balance := BalanceSettings.new()
	short_balance.battle_time_limit_seconds = 1
	engine = CombatEngine.new(short_balance)
	entries = [_entry("blue", 0, passive, Vector2(100, 450)), _entry("red", 1, passive, Vector2(1000, 450))]
	engine.reset_scenario(entries)
	for tick in range(30): engine.step()
	_check(engine.finished and engine.winner_team == -1 and engine.finish_reason == "time_limit", "Passive stalemate ends as configurable timeout draw")

func _test_abilities() -> void:
	var caster := UnitStats.new()
	caster.attack_range = 700
	caster.base_mana = 200
	caster.abilities = [load("res://data/abilities/stun_strike.tres")]
	var target := UnitStats.new()
	target.attack_range = 700
	target.ai_mode = CombatAI.Mode.PASSIVE
	target.status_resistance = 0.25
	var engine := CombatEngine.new(balance)
	var entries: Array[Dictionary] = [_entry("caster", 0, caster, Vector2(400, 450)), _entry("target", 1, target, Vector2(500, 450))]
	engine.reset_scenario(entries)
	var events := engine.step()
	_near(engine.units[0].current_mana, 120, "Cast spends 80 mana")
	_check(engine.units[1].effects.is_stunned() and engine.units[1].effects.active[0].duration_ticks == 68, "Ability applies resisted stun rounded to ticks")
	var casts := 0
	for tick in range(449):
		for event in engine.step():
			if event.kind == "cast": casts += 1
	_check(casts == 0 and engine.units[0].current_mana == 120, "Cooldown blocks recasting before tick 451")
	events = engine.step()
	_near(engine.units[0].current_mana, 40, "Recast after cooldown spends mana again")
	for tick in range(451): engine.step()
	_near(engine.units[0].current_mana, 40, "Insufficient mana prevents later cast")
	var delayed: AbilityData = caster.abilities[0].duplicate(true)
	delayed.cast_time = 1
	caster.abilities = [delayed]
	engine.reset_scenario(entries)
	engine.step()
	_check(not engine.units[0].casting.is_empty() and not engine.units[1].effects.is_stunned(), "Cast time delays effect")
	engine.queue_effect("debug", "caster", StatusEffect.Kind.STUN, 1, 0, "interrupt")
	events = engine.step()
	_check(engine.units[0].casting.is_empty() and not engine.units[1].effects.is_stunned(), "Stun interrupts casting without applying effect")
	_near(engine.units[0].current_mana, 120, "Interrupted cast does not refund mana")
	caster.abilities_enabled = false
	engine.reset_scenario(entries)
	engine.step()
	_near(engine.units[0].current_mana, 200, "Ability toggle disables auto casts")
	caster.abilities_enabled = true
	caster.abilities = [load("res://data/abilities/heavy_slow.tres"), load("res://data/abilities/armor_shatter.tres")]
	engine.reset_scenario(entries)
	engine.step()
	engine.step()
	_check(engine.units[1].effects.active.size() == 2, "AI uses multiple available abilities in data order")
	_near(engine.units[1].effects.strongest_slow(), 0.4, "Heavy Slow applies magnitude")
	_near(engine.units[1].physical_armor(), -15, "Armor Shatter applies armor reduction")
	caster.abilities = [delayed]
	engine.reset_scenario(entries)
	engine.step()
	for tick in range(30): engine.step()
	_check(engine.units[0].casting.is_empty() and engine.units[1].effects.is_stunned(), "Cast completes on its scheduled tick")
	engine.reset_scenario(entries)
	engine.step()
	engine.units[1].position = Vector2(1500, 450)
	for tick in range(30): engine.step()
	_check(not engine.units[1].effects.is_stunned(), "Out-of-range target causes cast completion to fizzle")
	engine.reset_scenario(entries)
	engine.queue_effect("debug", "caster", StatusEffect.Kind.STUN, 1, 0, "stun")
	engine.step()
	_near(engine.units[0].current_mana, 200, "Already stunned caster cannot spend mana or begin cast")

func _test_metrics() -> void:
	var attacker := UnitStats.new()
	attacker.attack_range = 700
	attacker.physical_damage = 100
	attacker.magic_damage = 20
	attacker.pure_damage = 10
	attacker.critical_chance = 1
	var target := UnitStats.new()
	target.attack_range = 700
	target.base_hp = 50
	var engine := CombatEngine.new(balance)
	engine.reset(attacker, target, Vector2.ZERO, Vector2(100, 0))
	engine.step()
	var result := engine.result()
	_near(result.units.blue_01.damage_dealt, 50, "Damage metrics exclude overkill")
	_near(result.units.red_01.damage_received, 50, "Received damage equals applied HP loss")
	_near(result.units.blue_01.physical_damage, 50, "Damage type totals use applied damage in component order")
	_near(result.units.blue_01.magic_damage, 0, "Overkill later components record zero applied damage")
	_check(result.units.blue_01.critical_strikes == 1, "Critical metric counts attacks, not components")
	_near(result.units.red_01.survival_time, 1.0 / 30, "Death survival timestamp")
	attacker.physical_damage = 0
	attacker.magic_damage = 0
	attacker.pure_damage = 0
	target.base_hp = 1000
	target.base_hp_regen = 30
	engine.reset(attacker, target, Vector2.ZERO, Vector2(100, 0))
	engine.units[1].current_hp = 998.5
	engine.queue_effect("blue_01", "red_01", StatusEffect.Kind.STUN, 1, 0, "stun")
	for tick in range(31): engine.step()
	result = engine.result()
	_near(result.units.red_01.healing_received, 1.5, "Healing excludes max-HP overflow")
	_near(result.units.red_01.time_stunned, 1, "Overlapping stun metric counts active ticks only")
	_near(result.units.blue_01.stun_duration_applied, 1, "Stun applied metric uses resisted scheduled duration")
	engine.reset(attacker, target, Vector2.ZERO, Vector2(100, 0))
	_check(engine.metrics.by_unit.blue_01.damage_dealt == 0 and engine.metrics.by_unit.red_01.healing_received == 0, "Reset clears metrics")

func _test_full_battle() -> void:
	var entries := _scenario()
	var reference: Array[Dictionary] = []
	var reference_result: Dictionary = {}
	for speed in SimulationClock.SPEEDS:
		var engine := CombatEngine.new(balance)
		engine.reset_scenario(entries, 991)
		var initial_positions: Array[Vector2] = []
		for unit in engine.units: initial_positions.append(unit.position)
		var events: Array[Dictionary] = []
		var clock := SimulationClock.new()
		var on_tick := func(_index: int):
			events.append_array(engine.step())
			if engine.finished: clock.set_running(false)
		clock.ticked.connect(on_tick)
		clock.set_running(true)
		clock.set_speed(speed)
		clock.advance(200 / speed)
		clock.ticked.disconnect(on_tick)
		_check(engine.finished and engine.finish_reason == "elimination", "5v5 completes by elimination at %sx" % speed)
		_check(engine.units.size() == 10 and clock.tick_count == engine.tick_count, "Ten units and aligned clock at %sx" % speed)
		var cast_ids: Array[String] = []
		var attacked: Array[String] = []
		for event in events:
			if event.kind == "cast" and event.ability_id not in cast_ids: cast_ids.append(event.ability_id)
			if event.kind == "attack" and event.source_unit_id not in attacked: attacked.append(event.source_unit_id)
		_check(cast_ids.size() == 3 and attacked.size() == 10, "All ten units attack and all three abilities are used")
		var dealt := 0.0
		var received := 0.0
		for unit in engine.units:
			var m: Dictionary = engine.metrics.by_unit[unit.unit_id]
			dealt += m.damage_dealt
			received += m.damage_received
			_near(m.damage_dealt, m.physical_damage + m.magic_damage + m.pure_damage, "Per-unit damage components sum")
			_check(m.survival_time <= engine.tick_count * SimulationClock.TICK_SECONDS + 0.000001 and m.time_stunned <= m.survival_time + 0.000001, "Survival/stun metric bounds")
		_near(dealt, received, "Total dealt equals total received")
		if reference.is_empty():
			reference = events
			reference_result = engine.result()
		else:
			_check(events == reference and engine.result() == reference_result, "Full AI battle and metrics reproduce at %sx" % speed)

func _test_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.count_fields[0].value = 5
	main.count_fields[1].value = 5
	_check(main.combat.units.size() == 10 and main.views.size() == 10, "Team count UI creates ten combat units/views")
	main.archetype_fields[0].select(3)
	main.archetype_fields[0].item_selected.emit(3)
	_check(main.sources[0].display_name == "Ranged Carry", "Archetype selection replaces editable source")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = main.views["red_05"].get_global_transform_with_canvas().origin
		root.push_input(click, true)
		await process_frame
		_check(main.selected_id == "red_05", "Clicking unit in rendered arena selects it")
	main._select_id("red_05")
	_check(main.selected_id == "red_05" and main.unit_editor.unit_select.selected == 9 and main.equipment_panel.unit_select.selected == 9, "Unit selection syncs Stats and Equipment")
	main.unit_editor.fields.strength.value = 42
	_near(main.sources[9].strength, 42, "Stats editor changes selected source")
	_check(main.combat.units[9].stats.strength == 42 and main.clock.tick_count == 0, "Stats edit recalculates final and resets battle")
	main.unit_editor.fields.evasion.value = 30
	_near(main.sources[9].evasion, 0.3, "Editor percent field converts 30 into fraction 0.3")
	main.unit_editor.ai_select.select(CombatAI.Mode.HIGHEST_DAMAGE)
	main.unit_editor.ai_select.item_selected.emit(CombatAI.Mode.HIGHEST_DAMAGE)
	_check(main.combat.units[9].ai_mode == CombatAI.Mode.HIGHEST_DAMAGE, "Editor changes AI mode")
	main.unit_editor.ability_toggle.button_pressed = false
	_check(main.combat.units[9].abilities.is_empty(), "Editor ability toggle updates runtime")
	main.unit_editor.ability_toggle.button_pressed = true
	_check(main.combat.units[9].abilities.size() == 1, "Editor restores available abilities")
	main.equipment_panel.slot_selectors[0].item_selected.emit(1)
	_check(main.loadouts[9].items().size() == 1 and main.combat.units[9].stats.physical_armor > main.sources[9].physical_armor, "Equipment supports tenth selected unit")
	main._select_id("blue_01")
	main.seed_field.value = 991
	main._reset()
	main.run_button.pressed.emit()
	main.clock.advance(4)
	main._refresh_ui()
	_check(not main.log_lines.is_empty() and "cast" in main.log_panel.text, "Live combat log contains ability events")
	if "--capture" in OS.get_cmdline_user_args():
		_check(DisplayServer.get_name() != "headless", "Capture uses real renderer")
		if DisplayServer.get_name() != "headless":
			main.clock.set_running(false)
			main._select_id("red_05")
			main.right_tabs.current_tab = 1
			await process_frame
			await RenderingServer.frame_post_draw
			_check(main.right_tabs.get_global_rect().end.y <= 814 and main.right_tabs.get_global_rect().end.x <= 1600, "Inspector fits beside arena and above controls")
			DirAccess.make_dir_recursive_absolute("res://.local")
			_check(root.get_texture().get_image().save_png("res://.local/phase5-preview.png") == OK, "Rendered 5v5 screenshot saved")
	main.clock.set_running(true)
	main.clock.advance(200)
	main._refresh_ui()
	_check(main.combat.finished and not main.clock.running and main.run_button.disabled, "UI stops completed battle")
	_check("Damage dealt" in main.results_panel.text and "Survival" in main.results_panel.text and "red_05" in main.results_panel.text, "Results contain per-unit required metrics")
	_check(main.log_lines.size() <= 300 and "Battle finished" in main.log_panel.text, "Bounded log retains ending")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://.local/phase5-results.png") == OK, "Rendered results screenshot saved")
	main._reset()
	_check(main.combat.units.size() == 10 and main.clock.tick_count == 0 and main.loadouts[9].items().size() == 1 and main.log_lines.is_empty(), "Reset restores configured 5v5 and preserves loadout")
	main.count_fields[1].value = 1
	await process_frame
	_check(main.combat.units.size() == 6 and main.views.size() == 6 and main.selected_id == "blue_01", "Reducing team removes inactive views safely")
	main.count_fields[1].value = 5
	_check(main.loadouts[9].items().size() == 1 and main.sources[9].strength == 42, "Re-enabling slot preserves its source edits and equipment")
	main.queue_free()
	await process_frame
