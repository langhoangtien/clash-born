extends Node2D

@export var visual_data: UnitVisualData

func _draw() -> void:
	if visual_data == null:
		return
	var radius := visual_data.radius
	draw_circle(Vector2(0, 6), radius + 5, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, radius, visual_data.team_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, visual_data.team_color.lightened(0.45), 2.0, true)
	draw_circle(Vector2.ZERO, 6, Color(1, 1, 1, 0.7))
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(visual_data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, Vector2(-text_size.x / 2, -radius - 18), visual_data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.88, 0.91, 0.95))
