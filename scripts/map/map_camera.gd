extends Camera2D
## Camera has no knowledge of combat or navigation calculations.
@export var minimum_zoom: float = 0.15
@export var maximum_zoom: float = 1.6
@export var pan_speed: float = 1000.0
@export var keyboard_pan_enabled: bool = true
var map_size := Vector2(5120, 5120)
var follow_target: Node2D
var dragging := false
var follow_enabled := true

func _ready() -> void:
	position_smoothing_enabled = false
	clamp_to_map()

func _process(delta: float) -> void:
	if follow_enabled and is_instance_valid(follow_target): position = follow_target.global_position
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	if keyboard_pan_enabled and not direction.is_zero_approx(): pan_by(direction.normalized() * pan_speed * delta / zoom.x)
	clamp_to_map()

func pan_by(world_offset: Vector2) -> void:
	follow_enabled = false
	position += world_offset
	clamp_to_map()

func set_zoom_level(value: float) -> void:
	var level := clampf(value, minimum_zoom, maximum_zoom)
	zoom = Vector2.ONE * level
	clamp_to_map()

func fit_map() -> void:
	var viewport_size := get_viewport_rect().size
	follow_enabled = false
	# The full map must fit even in a small window; fit is a special overview.
	zoom = Vector2.ONE * minf(viewport_size.x / map_size.x, viewport_size.y / map_size.y) * 0.92
	position = map_size * 0.5
	clamp_to_map()

func clamp_to_map() -> void:
	var half_view := get_viewport_rect().size / (zoom * 2)
	position.x = map_size.x * 0.5 if half_view.x >= map_size.x * 0.5 else clampf(position.x, half_view.x, map_size.x - half_view.x)
	position.y = map_size.y * 0.5 if half_view.y >= map_size.y * 0.5 else clampf(position.y, half_view.y, map_size.y - half_view.y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			if dragging: follow_enabled = false
			get_viewport().set_input_as_handled()
		# Match camera zoom is fixed for consistent vision and targeting.
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		pan_by(-event.relative / zoom)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Release must work even when the pointer is over a UI control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		dragging = false
