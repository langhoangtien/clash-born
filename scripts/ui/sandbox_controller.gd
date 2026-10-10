extends Node2D

var clock := SimulationClock.new()
var status_label: Label
var run_button: Button
var step_button: Button

func _ready() -> void:
	_build_ui()
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
	subtitle.text = "PHASE 1 · Project foundation · 1600 × 900 arena · Two primitive units"
	subtitle.modulate = Color(0.67, 0.74, 0.8)
	header.add_child(subtitle)
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
	note.text = "Clock controls only. Units remain stationary in Phase 1. Combat systems begin in Phase 2."
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
	clock.set_running(not clock.running)
	_refresh_ui()

func _step() -> void:
	clock.step()
	_refresh_ui()

func _reset() -> void:
	clock.reset()
	_refresh_ui()

func _refresh_ui() -> void:
	run_button.text = "Pause" if clock.running else ("Resume" if clock.tick_count > 0 else "Start")
	step_button.disabled = clock.running
	status_label.text = "%s  |  %07.3f s  |  Tick %d  |  30 Hz" % ["RUNNING" if clock.running else "PAUSED", clock.elapsed_seconds(), clock.tick_count]
