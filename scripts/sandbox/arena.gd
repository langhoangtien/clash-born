extends Node2D

const ARENA_SIZE := Vector2(1600, 900)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.075, 0.095, 0.11))
	for x in range(0, 1601, 80):
		draw_line(Vector2(x, 0), Vector2(x, 900), Color(0.14, 0.18, 0.20, 0.45))
	for y in range(0, 901, 80):
		draw_line(Vector2(0, y), Vector2(1600, y), Color(0.14, 0.18, 0.20, 0.45))
	draw_line(Vector2(800, 180), Vector2(800, 700), Color(0.35, 0.40, 0.44, 0.4), 2)
	draw_arc(Vector2(800, 450), 130, 0, TAU, 96, Color(0.35, 0.40, 0.44, 0.3), 2, true)
