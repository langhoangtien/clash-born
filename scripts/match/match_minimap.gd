extends Control
signal map_clicked(point: Vector2)
var layout: MapLayout
var entities: Dictionary

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if layout == null: return
	var cell_size := size / Vector2(layout.dimensions)
	for y in range(layout.dimensions.y):
		for x in range(layout.dimensions.x):
			draw_rect(Rect2(Vector2(x, y) * cell_size, cell_size), layout.terrain_at(Vector2i(x, y)).get("color", Color.BLACK))
	for info in entities.values():
		var state: UnitRuntimeState = info.actor.runtime
		if not state.alive: continue
		var point := state.position / layout.world_size() * size
		var color := Color(0.3, 0.7, 1) if state.team_id == 0 else Color(1, 0.35, 0.3)
		if info.kind == "hero": draw_circle(point, 5, color)
		elif info.kind in ["tower", "core"]: draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), color)
		else: draw_circle(point, 2, color)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.85, 0.9), false, 2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		map_clicked.emit(event.position / size * layout.world_size())
		accept_event()
