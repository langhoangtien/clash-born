extends Node2D
var layout: MapLayout
var settings: MatchSettings

func _draw() -> void:
	for team in range(2):
		var center := layout.fountain_point(team)
		var color := Color(0.3, 0.75, 1) if team == 0 else Color(1, 0.4, 0.45)
		draw_circle(center, settings.fountain_radius, Color(color, 0.10))
		draw_arc(center, settings.fountain_radius, 0, TAU, 64, color.lightened(0.12), 3, true)
		draw_circle(center + Vector2(0, 18), 88, Color(0.03, 0.08, 0.12, 0.28))
		draw_colored_polygon(PackedVector2Array([
		center + Vector2(-72, 22), center + Vector2(72, 22),
		center + Vector2(48, 66), center + Vector2(-48, 66)
	]), Color(0.12, 0.16, 0.22, 0.95))
		draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -78), center + Vector2(48, 5),
		center + Vector2(0, 44), center + Vector2(-48, 5)
	]), color.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -54), center + Vector2(27, 5),
		center + Vector2(0, 27), center + Vector2(-27, 5)
	]), color.lightened(0.2))
		draw_string(ThemeDB.fallback_font, center + Vector2(-65, -settings.fountain_radius - 12), "FOUNTAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
