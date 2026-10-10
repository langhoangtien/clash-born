extends Node2D

@export var visual_data: UnitVisualData
@export var combat_data: UnitStats
var runtime: UnitRuntimeState
var last_damage: float = 0.0
var damage_flash: float = 0.0
var hit_notice: String = ""

func _process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta)
	queue_redraw()

func show_damage(amount: float, critical: bool = false) -> void:
	last_damage = amount
	hit_notice = ("CRIT " if critical else "") + "-%.1f" % amount
	damage_flash = 0.5

func show_miss() -> void:
	hit_notice = "MISS"
	damage_flash = 0.5

func _draw() -> void:
	if visual_data == null:
		return
	var radius := visual_data.radius
	draw_circle(Vector2(0, 6), radius + 5, Color(0, 0, 0, 0.3))
	var color := visual_data.team_color
	if runtime != null and not runtime.alive:
		color = Color(0.3, 0.32, 0.34)
	elif damage_flash > 0:
		color = color.lightened(0.3)
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, visual_data.team_color.lightened(0.45), 2.0, true)
	draw_circle(Vector2.ZERO, 6, Color(1, 1, 1, 0.7))
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(visual_data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, Vector2(-text_size.x / 2, -radius - 18), visual_data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.88, 0.91, 0.95))
	if runtime == null:
		return
	_draw_bar(Vector2(-80, 52), runtime.current_hp / runtime.stats.max_hp, Color(0.25, 0.8, 0.42))
	var mana_ratio: float = runtime.current_mana / runtime.stats.max_mana if runtime.stats.max_mana > 0 else 0.0
	_draw_bar(Vector2(-80, 68), mana_ratio, Color(0.25, 0.55, 0.95))
	var hp_text := "HP %.1f / %.1f   MP %.1f / %.1f" % [runtime.current_hp, runtime.stats.max_hp, runtime.current_mana, runtime.stats.max_mana]
	var width := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(-width / 2, 104), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var details := "STR %.1f · AGI %.1f · INT %.1f\nDMG P %.1f / M %.1f / Pure %.1f\nArmor P %.2f / M %.2f · APS %.2f\nEvade %.0f%% · Accuracy %.0f%% · Crit %.0f%%\nResist %.0f%% · Move %.0f" % [runtime.stats.strength, runtime.stats.agility, runtime.stats.intelligence, runtime.stats.physical_damage, runtime.stats.magic_damage, runtime.stats.pure_damage, runtime.physical_armor(), runtime.stats.magic_armor, runtime.stats.attack_speed, runtime.stats.evasion * 100, runtime.stats.accuracy * 100, runtime.stats.critical_chance * 100, runtime.stats.status_resistance * 100, runtime.movement_speed(preload("res://data/balance/default_balance.tres"))]
	var y := 135.0
	for line in details.split("\n"):
		width = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2(-width / 2, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.67, 0.74, 0.8))
		y += 24
	var status: PackedStringArray = []
	for effect in runtime.effects.active:
		var kind_name: String = ["STUN", "SLOW", "ARMOR -"][effect.kind]
		status.append("%s %.1fs" % [kind_name, effect.remaining_seconds(runtime.current_tick)])
	if not status.is_empty():
		var effect_text := " · ".join(status)
		width = font.get_string_size(effect_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2(-width / 2, y), effect_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.78, 0.45))
	if not runtime.alive:
		draw_string(font, Vector2(-27, 8), "DEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	elif damage_flash > 0:
		draw_string(font, Vector2(-30, -95), hit_notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.78, 0.45))

func _draw_bar(origin: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(origin, Vector2(160, 10)), Color(0.02, 0.03, 0.04))
	draw_rect(Rect2(origin, Vector2(160 * clampf(ratio, 0, 1), 10)), color)
