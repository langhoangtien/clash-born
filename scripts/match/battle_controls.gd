extends Control
signal attack_requested(category: String)
var direction := Vector2.ZERO
var direction_buttons: Dictionary = {}
var held_mouse: Dictionary = {}
var touches: Dictionary = {}
var attack_buttons: Dictionary = {}

func _ready() -> void:
	for definition in [["up", Vector2(115, 0), Vector2.UP, "↑"], ["left", Vector2(30, 80), Vector2.LEFT, "←"], ["down", Vector2(115, 80), Vector2.DOWN, "↓"], ["right", Vector2(200, 80), Vector2.RIGHT, "→"]]:
		var button := Button.new()
		button.name = definition[0]
		button.position = definition[1]
		button.size = Vector2(78, 74)
		button.text = definition[3]
		button.add_theme_font_size_override("font_size", 32)
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(func(): held_mouse[definition[0]] = definition[2]; _refresh_direction())
		button.button_up.connect(func(): held_mouse.erase(definition[0]); _refresh_direction())
		add_child(button)
		direction_buttons[definition[0]] = button
	for definition in [["creep", "ĐÁNH LÍNH / TRỤ\n[J]", Vector2(1260, 55)], ["hero", "ĐÁNH HERO\n[K]", Vector2(1430, 0)]]:
		var button := Button.new()
		button.name = definition[0]
		button.position = definition[2]
		button.size = Vector2(150, 100)
		button.text = definition[1]
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): attack_requested.emit(definition[0]))
		add_child(button)
		attack_buttons[definition[0]] = button

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed:
			touches.erase(event.index)
		else:
			_track_touch(event.index, event.position)
			for category in attack_buttons:
				if attack_buttons[category].get_global_rect().has_point(event.position): attack_requested.emit(category)
		_refresh_direction()
	elif event is InputEventScreenDrag:
		_track_touch(event.index, event.position)
		_refresh_direction()

func _track_touch(index: int, point: Vector2) -> void:
	touches.erase(index)
	for key in direction_buttons:
		if direction_buttons[key].get_global_rect().has_point(point):
			touches[index] = {"up": Vector2.UP, "left": Vector2.LEFT, "down": Vector2.DOWN, "right": Vector2.RIGHT}[key]

func _refresh_direction() -> void:
	direction = Vector2.ZERO
	for value in held_mouse.values(): direction += value
	for value in touches.values(): direction += value
	direction = direction.limit_length(1)

func release_all() -> void:
	held_mouse.clear()
	touches.clear()
	_refresh_direction()
