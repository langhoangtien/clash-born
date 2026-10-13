extends Node2D
## Scene coordinator only. No combat ticks, damage, creeps or tower behavior.
@export var layout: MapLayout
var units: Array[MapUnit] = []
var selected_unit: MapUnit
var world: Node2D
var camera: Camera2D
var selection: OptionButton
var follow_toggle: CheckBox
var overlay_controls: Dictionary = {}
var status: Label
var paused: bool = false

func _enter_tree() -> void:
	# A single root Resource configures rendering/collision before child _ready.
	$World.layout = layout

func _ready() -> void:
	if layout == null:
		push_error("Map Prototype requires a MapLayout Resource")
		return
	if not layout.validation_errors().is_empty(): return
	world = $World
	camera = $Camera
	camera.map_size = layout.world_size()
	for team in range(2):
		var unit := MapUnit.new()
		var source: UnitStats = preload("res://data/units/archetypes/physical_tank.tres") if team == 0 else preload("res://data/units/archetypes/ranged_carry.tres")
		unit.configure(source, team, layout.spawn_points(team)[0], layout)
		unit.selected.connect(select_unit)
		add_child(unit)
		units.append(unit)
	world.units = units
	_build_ui()
	select_unit(units[0])
	camera.position = selected_unit.position
	camera.set_zoom_level(0.7)
	camera.follow_enabled = true
	status.text = "Right-click ground to move. Walls reject destinations."

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(350, 0)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var title := Label.new()
	title.text = "CLASHBORN / PHASE 6 · MAP FOUNDATION"
	title.add_theme_font_size_override("font_size", 20)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var help := Label.new()
	help.text = "Right-click: move · WASD: move selected probe\nMiddle-drag / arrows: pan · Wheel: zoom · F: follow · O: overview · D: terrain debug"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 14)
	content.add_child(help)
	var row := HBoxContainer.new()
	content.add_child(row)
	selection = OptionButton.new()
	selection.add_item("Blue probe")
	selection.add_item("Red probe")
	selection.item_selected.connect(func(index: int): select_unit(units[index]))
	row.add_child(selection)
	follow_toggle = CheckBox.new()
	follow_toggle.text = "Follow selected"
	follow_toggle.button_pressed = true
	follow_toggle.toggled.connect(func(value: bool): camera.follow_enabled = value)
	row.add_child(follow_toggle)
	row = HBoxContainer.new()
	content.add_child(row)
	_button(row, "Overview", func(): camera.fit_map())
	_button(row, "Reset", reset_probes)
	_button(row, "Combat Sandbox", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	var label := Label.new()
	label.text = "Route to enemy base:"
	content.add_child(label)
	row = HBoxContainer.new()
	content.add_child(row)
	for lane in ["TOP", "MID", "BOT"]:
		_button(row, lane, func():
			status.text = "%s · %s route" % [selected_unit.view.visual_data.display_name, lane] if selected_unit.follow_lane(lane) else "No valid route"
		)
	_button(row, "Stop", func(): selected_unit.stop())
	var pause := CheckBox.new()
	pause.text = "Pause movement"
	pause.toggled.connect(func(value: bool):
		paused = value
		for unit in units: unit.paused = value
	)
	content.add_child(pause)
	var overlays := GridContainer.new()
	overlays.columns = 2
	content.add_child(overlays)
	for definition in [["grid", "Grid", false], ["walkability", "Walkable / blocked", false], ["waypoints", "Lane waypoints", false], ["paths", "Navigation paths", false], ["collision", "Unit collision", false], ["spawns", "Base spawns", true], ["towers", "Tower markers", true]]:
		var toggle := CheckBox.new()
		toggle.text = definition[1]
		toggle.button_pressed = definition[2]
		toggle.add_theme_font_size_override("font_size", 14)
		toggle.toggled.connect(func(enabled: bool):
			if definition[0] == "collision":
				for unit in units: unit.show_collision = enabled
			else: world.set_overlay(definition[0], enabled)
		)
		overlays.add_child(toggle)
		overlay_controls[definition[0]] = toggle
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	content.add_child(status)
	_button(content, "Chơi trận MOBA", func(): get_tree().change_scene_to_file("res://scenes/match/moba_match.tscn"))

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.name = text.replace(" ", "")
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func select_unit(unit: MapUnit) -> void:
	selected_unit = unit
	for candidate in units: candidate.view.selected = candidate == unit
	camera.follow_target = unit
	if selection != null: selection.select(units.find(unit))

func reset_probes() -> void:
	for unit in units:
		unit.stop()
		unit.position = layout.spawn_points(unit.runtime.team_id)[0]
		unit.runtime.position = unit.position
	status.text = "Probes reset to team spawns"

func _process(_delta: float) -> void:
	if selected_unit != null:
		selected_unit.manual_direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		for unit in units:
			if unit != selected_unit: unit.manual_direction = Vector2.ZERO
	if follow_toggle != null: follow_toggle.set_pressed_no_signal(camera.follow_enabled)

func _unhandled_input(event: InputEvent) -> void:
	if selected_unit == null: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		status.text = "Moving to %.0f, %.0f" % [point.x, point.y] if selected_unit.go_to(point) else "Destination blocked or unreachable"
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F: camera.follow_enabled = not camera.follow_enabled
		elif event.physical_keycode == KEY_O: camera.fit_map()
		elif event.physical_keycode == KEY_D:
			world.set_debug_enabled(not world.debug_enabled)
			status.text = "Terrain debug " + ("enabled" if world.debug_enabled else "disabled")
