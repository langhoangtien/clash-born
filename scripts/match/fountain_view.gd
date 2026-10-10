extends Node2D
var layout: MapLayout
var settings: MatchSettings

func _draw() -> void:
	for team in range(2):
		var center := layout.spawn_points(team)[0]
		var color := Color(0.3, 0.75, 1) if team == 0 else Color(1, 0.4, 0.45)
		draw_circle(center, settings.fountain_radius, Color(color, 0.12))
		draw_arc(center, settings.fountain_radius, 0, TAU, 64, color, 3, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-65, -settings.fountain_radius - 12), "FOUNTAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
