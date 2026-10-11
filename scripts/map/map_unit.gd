class_name MapUnit
extends CharacterBody2D
## Continuous map actor sharing existing combat data/view; resolves no damage itself.
signal selected(unit: MapUnit)
signal arrived
var runtime: UnitRuntimeState
var navigation: MapNavigation
var path: PackedVector2Array = []
var path_index: int = 0
var view: Node2D
var show_collision: bool = false
var paused: bool = false
var manual_direction := Vector2.ZERO
var movement_speed_multiplier: float = 1.0
var balance: BalanceSettings = preload("res://data/balance/default_balance.tres")

func configure(source: UnitStats, team: int, point: Vector2, data: MapLayout, shared_navigation: MapNavigation = null, existing_state: UnitRuntimeState = null) -> void:
	position = point
	runtime = existing_state if existing_state != null else UnitRuntimeState.new("map_blue" if team == 0 else "map_red", team, point, source, balance)
	navigation = shared_navigation if shared_navigation != null else MapNavigation.new(data, runtime.stats.collision_radius)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 # Static terrain only; no dynamic avoidance in this phase.
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = runtime.stats.collision_radius
	collision.shape = shape
	add_child(collision)
	view = preload("res://scenes/units/combat_unit.tscn").instantiate()
	view.top_level = true
	view.runtime = runtime
	view.show_range_indicators = false
	view.show_resource_bars = false
	var visual := UnitVisualData.new()
	visual.unit_id = runtime.unit_id
	visual.display_name = "BLUE PROBE" if team == 0 else "RED PROBE"
	visual.team_color = Color(0.25, 0.6, 1) if team == 0 else Color(1, 0.35, 0.35)
	view.visual_data = visual
	view.unit_selected.connect(func(_id: String): selected.emit(self))
	add_child(view)

func go_to(point: Vector2) -> bool:
	var next := navigation.path(position, point)
	if next.is_empty(): return false
	set_path(next)
	return true

func follow_lane(lane: String) -> bool:
	var next := navigation.lane_path(position, lane, runtime.team_id)
	if next.is_empty(): return false
	set_path(next)
	return true

func set_path(points: PackedVector2Array) -> void:
	path = points
	path_index = 0

func stop() -> void:
	path.clear()
	path_index = 0
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	if not paused and runtime.can_move():
		var speed := runtime.movement_speed(balance) * movement_speed_multiplier
		if not manual_direction.is_zero_approx():
			stop()
			velocity = manual_direction.normalized() * speed
		else:
			while path_index < path.size() and position.distance_to(path[path_index]) <= 0.1: path_index += 1
			if path_index < path.size():
				var offset := path[path_index] - position
				velocity = offset.normalized() * minf(speed, offset.length() / maxf(delta, 0.000001))
	if not velocity.is_zero_approx(): move_and_slide()
	runtime.position = position
	if not path.is_empty() and path_index >= path.size():
		stop()
		arrived.emit()
	if show_collision or (view != null and view.selected): queue_redraw()

func _draw() -> void:
	if view != null and view.selected:
		draw_arc(Vector2.ZERO, runtime.stats.collision_radius + 9, 0, TAU, 40, Color(1, 0.85, 0.2), 3, true)
	if show_collision and runtime != null:
		draw_arc(Vector2.ZERO, runtime.stats.collision_radius, 0, TAU, 40, Color(1, 0.85, 0.2), 3, true)
