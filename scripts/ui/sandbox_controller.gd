extends Node2D

var clock := SimulationClock.new()
var status_label: Label
var run_button: Button
var step_button: Button
var combat := CombatEngine.new(preload("res://data/balance/default_balance.tres"))
var battle_label: Label
var seed_field: SpinBox
var effect_target: OptionButton
var effect_buttons: Array[Button] = []

func _ready() -> void:
	_build_ui()
	_reset_combat()
	clock.ticked.connect(_on_tick)
	_refresh_ui()

func _process(delta: float) -> void:
	clock.advance(delta)
	_refresh_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := PanelContainer.new()
	top.position = Vector2(32, 24)
	top.size = Vector2(1536, 112)
	layer.add_child(top)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	top.add_child(margin)
	var header := VBoxContainer.new()
	margin.add_child(header)
	var title := Label.new()
	title.text = "CLASHBORN  /  COMBAT SANDBOX"
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "PHASE 3 · Attack speed · Evasion / Accuracy / Critical · Stun / Slow / Armor reduction"
	subtitle.modulate = Color(0.67, 0.74, 0.8)
	header.add_child(subtitle)
	battle_label = Label.new()
	battle_label.position = Vector2(32, 180)
	battle_label.size = Vector2(1536, 40)
	battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(battle_label)
	var debug_panel := PanelContainer.new()
	debug_panel.position = Vector2(32, 240)
	debug_panel.size = Vector2(1536, 58)
	layer.add_child(debug_panel)
	var debug_margin := MarginContainer.new()
	debug_margin.add_theme_constant_override("margin_left", 12)
	debug_margin.add_theme_constant_override("margin_right", 12)
	debug_panel.add_child(debug_margin)
	var debug_row := HBoxContainer.new()
	debug_row.add_theme_constant_override("separation", 12)
	debug_margin.add_child(debug_row)
	var debug_label := Label.new()
	debug_label.text = "Debug effects →"
	debug_row.add_child(debug_label)
	effect_target = OptionButton.new()
	effect_target.add_item("Red")
	effect_target.add_item("Blue")
	debug_row.add_child(effect_target)
	effect_buttons.append(_button(debug_row, "Stun 4 s", func(): _queue_effect(StatusEffect.Kind.STUN, 4.0, 0.0)))
	effect_buttons.append(_button(debug_row, "Slow 40% / 5 s", func(): _queue_effect(StatusEffect.Kind.SLOW, 5.0, 0.4)))
	effect_buttons.append(_button(debug_row, "Armor -15 / 6 s", func(): _queue_effect(StatusEffect.Kind.ARMOR_REDUCTION, 6.0, 15.0)))
	var seed_label := Label.new()
	seed_label.text = "  Seed (on Reset)"
	debug_row.add_child(seed_label)
	seed_field = SpinBox.new()
	seed_field.min_value = 0
	seed_field.max_value = 2147483647
	seed_field.value = 1
	seed_field.custom_minimum_size.x = 150
	debug_row.add_child(seed_field)
	var bottom := PanelContainer.new()
	bottom.position = Vector2(32, 732)
	bottom.size = Vector2(1536, 140)
	layer.add_child(bottom)
	var bottom_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		bottom_margin.add_theme_constant_override("margin_" + side, 16)
	bottom.add_child(bottom_margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	bottom_margin.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	run_button = _button(row, "Start", _toggle_running)
	step_button = _button(row, "Step +1 tick", _step)
	_button(row, "Reset", _reset)
	var speed_label := Label.new()
	speed_label.text = "   Clock speed"
	row.add_child(speed_label)
	var speed_select := OptionButton.new()
	for value in SimulationClock.SPEEDS:
		speed_select.add_item("%sx" % str(value))
	speed_select.select(1)
	speed_select.item_selected.connect(func(index: int): clock.set_speed(SimulationClock.SPEEDS[index]))
	row.add_child(speed_select)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status_label)
	var note := Label.new()
	note.text = "Debug effects apply on next tick (Step while paused). Reset restores units and RNG. Slow affects movement speed; no movement AI yet."
	note.modulate = Color(0.67, 0.74, 0.8)
	content.add_child(note)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 40)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _toggle_running() -> void:
	if combat.finished:
		return
	clock.set_running(not clock.running)
	_refresh_ui()

func _step() -> void:
	clock.step()
	_refresh_ui()

func _reset() -> void:
	clock.reset()
	_reset_combat()
	_refresh_ui()

func _reset_combat() -> void:
	var blue = $Arena/BlueUnit
	var red = $Arena/RedUnit
	combat.reset(blue.combat_data, red.combat_data, blue.position, red.position, int(seed_field.value))
	blue.runtime = combat.units[0]
	red.runtime = combat.units[1]
	blue.damage_flash = 0.0
	red.damage_flash = 0.0
	battle_label.text = "Blue: physical attacker    vs    Red: mixed damage attacker"

func _queue_effect(kind: StatusEffect.Kind, duration: float, magnitude: float) -> void:
	if combat.finished:
		return
	var target := "red_01" if effect_target.selected == 0 else "blue_01"
	combat.queue_effect("debug", target, kind, duration, magnitude, "debug_%d" % kind)

func _on_tick(_tick_index: int) -> void:
	var events := combat.step()
	var damage_totals: Dictionary = {}
	var critical_hits: Dictionary = {}
	for event in events:
		if event.kind == "damage":
			damage_totals[event.target_unit_id] = damage_totals.get(event.target_unit_id, 0.0) + event.applied_damage
			if event.critical:
				critical_hits[event.target_unit_id] = true
		elif event.kind == "miss":
			for unit in [$Arena/BlueUnit, $Arena/RedUnit]:
				if unit.visual_data.unit_id == event.target_unit_id:
					unit.show_miss()
	for unit in [$Arena/BlueUnit, $Arena/RedUnit]:
		if damage_totals.has(unit.visual_data.unit_id):
			unit.show_damage(damage_totals[unit.visual_data.unit_id], critical_hits.has(unit.visual_data.unit_id))
	if combat.finished:
		clock.set_running(false)
		var result := "Draw" if combat.winner_team < 0 else ("Blue wins" if combat.winner_team == 0 else "Red wins")
		battle_label.text = "%s · %.3f s · Reset to start a new duel" % [result, combat.tick_count * SimulationClock.TICK_SECONDS]

func _refresh_ui() -> void:
	run_button.text = "Pause" if clock.running else ("Resume" if clock.tick_count > 0 else "Start")
	run_button.disabled = combat.finished
	step_button.disabled = clock.running or combat.finished
	for button in effect_buttons:
		button.disabled = combat.finished
	status_label.text = "%s  |  %07.3f s  |  Tick %d  |  30 Hz" % ["RUNNING" if clock.running else "PAUSED", clock.elapsed_seconds(), clock.tick_count]
