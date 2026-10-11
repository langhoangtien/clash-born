extends Node2D

signal unit_selected(id: String)
@export var visual_data: UnitVisualData
@export var combat_data: UnitStats
var runtime: UnitRuntimeState
var selected: bool = false
var damage_flash: float = 0.0
var hit_notice: String = ""
var hit_notice_color: Color = Color(1, 0.78, 0.45)
var hit_notices: Array[Dictionary] = []
var show_range_indicators: bool = true
var show_resource_bars: bool = true
var structure_visual: bool = false
var compact_visual: bool = false
var siege_visual: bool = false

func _process(delta: float) -> void:
	damage_flash = maxf(0, damage_flash - delta)
	for index in range(hit_notices.size() - 1, -1, -1):
		hit_notices[index].time = float(hit_notices[index].time) - delta
		if hit_notices[index].time <= 0: hit_notices.remove_at(index)
	if runtime != null: position = runtime.position
	# Compact creep bodies are static between hit notices. Avoid rebuilding every
	# creep draw command each render frame during large lane fights.
	if damage_flash > 0 or not hit_notices.is_empty() or selected or show_resource_bars or show_range_indicators: queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and visual_data != null:
		var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if runtime != null and local_point.length() <= runtime.stats.collision_radius:
			unit_selected.emit(visual_data.unit_id)
			get_viewport().set_input_as_handled()

func show_damage(amount: float, critical: bool = false, damage_type: int = DamageCalculator.DamageType.PHYSICAL) -> void:
	hit_notice = ("CRIT " if critical else "") + "-%.1f" % amount
	hit_notice_color = {
		DamageCalculator.DamageType.PHYSICAL: Color(0.25, 0.68, 1.0),
		DamageCalculator.DamageType.MAGICAL: Color(1.0, 1.0, 1.0),
		DamageCalculator.DamageType.PURE: Color(0.8, 0.35, 1.0),
	}.get(damage_type, Color.WHITE)
	hit_notices.append({"text": hit_notice, "color": hit_notice_color, "time": 0.7})
	if hit_notices.size() > 4: hit_notices.pop_front()
	damage_flash = 0.5

func show_miss() -> void:
	hit_notice = "MISS"
	hit_notice_color = Color(1.0, 0.82, 0.25)
	hit_notices.append({"text": hit_notice, "color": hit_notice_color, "time": 0.7})
	if hit_notices.size() > 4: hit_notices.pop_front()
	damage_flash = 0.5

func _center_text(text: String, y: float, size_value: int, color: Color = Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	draw_string(font, Vector2(-width / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func status_labels() -> PackedStringArray:
	var statuses: PackedStringArray = []
	if runtime == null: return statuses
	for effect in runtime.effects.active:
		var tag: String = ["CHOÁNG", "CHẬM", "TRỪ GIÁP", "TẦM ĐÁNH", "TẦM PHÉP", "CHẬM ĐÁNH"][effect.kind]
		if tag not in statuses: statuses.append(tag)
	if not runtime.casting.is_empty(): statuses.append("ĐANG NIỆM")
	return statuses

func _draw() -> void:
	if visual_data == null or runtime == null: return
	var radius: float = runtime.stats.collision_radius
	if selected and show_range_indicators:
		draw_arc(Vector2.ZERO, runtime.attack_range() + runtime.stats.collision_radius, 0, TAU, 96, Color(1, 1, 1, 0.2), 2, true)
		draw_arc(Vector2.ZERO, runtime.cast_range() + radius, 0, TAU, 96, Color(0.35, 0.65, 1, 0.45), 2, true)
		for ability in runtime.abilities:
			if ability.cast_range > 0: draw_arc(Vector2.ZERO, runtime.cast_range(ability) + radius, 0, TAU, 96, Color(0.35, 0.65, 1, 0.25), 1, true)
		draw_arc(Vector2.ZERO, radius + 6, 0, TAU, 48, Color(1, 0.86, 0.4), 3, true)
	var color := visual_data.team_color if runtime.alive else Color(0.3, 0.32, 0.34)
	if damage_flash > 0 and runtime.alive: color = color.lightened(0.3)
	draw_circle(Vector2(0, 5), radius + 3, Color(0, 0, 0, 0.3))
	if structure_visual: _draw_structure(radius, color)
	elif siege_visual:
		draw_rect(Rect2(Vector2(-radius, -radius * 0.6), Vector2(radius * 2, radius * 1.2)), color)
		for x in [-0.65, 0.65]: draw_circle(Vector2(radius * x, radius * 0.65), radius * 0.3, Color(0.15, 0.12, 0.1))
		draw_line(Vector2(-radius * 0.5, radius * 0.2), Vector2(radius * 0.5, -radius * 0.8), Color.WHITE, 4, true)
		draw_circle(Vector2(radius * 0.5, -radius * 0.8), radius * 0.25, Color(0.65, 0.65, 0.65))
	elif compact_visual and runtime.stats.ranged_attacks:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)]), color)
	else: _draw_hero(radius, color)
	if compact_visual and not siege_visual:
		if runtime.stats.ranged_attacks:
			draw_arc(Vector2.ZERO, radius * 0.65, -PI / 2, PI / 2, 12, Color.WHITE, 2, true)
		else:
			draw_line(Vector2(-radius * 0.55, radius * 0.55), Vector2(radius * 0.55, -radius * 0.55), Color.WHITE, 3, true)
	draw_circle(Vector2.ZERO, 5, Color(1, 1, 1, 0.7))
	if not compact_visual: _center_text(visual_data.display_name, -radius - 12, 20)
	if show_resource_bars:
		_draw_bar(32 if compact_visual else 44, runtime.current_hp / runtime.stats.max_hp, Color(0.25, 0.8, 0.42))
		if not compact_visual: _draw_bar(56, runtime.current_mana / runtime.stats.max_mana if runtime.stats.max_mana > 0 else 0, Color(0.25, 0.55, 0.95))
		if selected: _center_text("%.0f / %.0f" % [runtime.current_hp, runtime.stats.max_hp], 82, 20)
	var statuses := status_labels()
	if not statuses.is_empty() and runtime.alive: _center_text(" ".join(statuses), 8, 18, Color(0.07, 0.08, 0.1))
	if not runtime.alive: _center_text("DEAD", 8, 18)
	else:
		for index in range(hit_notices.size()):
			var notice: Dictionary = hit_notices[hit_notices.size() - 1 - index]
			_center_text(notice.text, -80.0 - index * 25.0, 24, notice.color)

func _draw_bar(y: float, ratio: float, color: Color) -> void:
	var width := 50.0 if compact_visual else 90.0
	draw_rect(Rect2(Vector2(-width / 2, y), Vector2(width, 8)), Color(0.02, 0.03, 0.04))
	draw_rect(Rect2(Vector2(-width / 2, y), Vector2(width * clampf(ratio, 0, 1), 8)), color)

func _draw_hero(radius: float, color: Color) -> void:
	# Small flat-vector silhouette: cape, body, head and weapon remain legible
	# at the match camera zoom without requiring sprite textures.
	var facing := -1.0 if color.r > color.b else 1.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-radius * 0.75, -radius * 0.15),
		Vector2(-radius * 1.2, radius * 0.9),
		Vector2(radius * 0.15, radius * 0.62),
		Vector2(radius * 0.42, -radius * 0.35)
	]), color.darkened(0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-radius * 0.36, radius * 0.62),
		Vector2(radius * 0.38, radius * 0.62),
		Vector2(radius * 0.58, -radius * 0.15),
		Vector2(0, -radius * 0.66),
		Vector2(-radius * 0.58, -radius * 0.15)
	]), color)
	draw_circle(Vector2(0, -radius * 0.88), radius * 0.34, color.lightened(0.28))
	draw_line(Vector2(facing * radius * 0.24, -radius * 0.1), Vector2(facing * radius * 1.05, -radius * 0.7), Color(0.92, 0.95, 1.0), maxf(3.0, radius * 0.12), true)
	draw_line(Vector2(facing * radius * 0.75, -radius * 0.78), Vector2(facing * radius * 1.1, -radius * 0.52), Color(0.55, 0.72, 0.9), maxf(2.0, radius * 0.08), true)

func _draw_structure(radius: float, color: Color) -> void:
	var is_core := visual_data != null and visual_data.display_name.find("NHÀ") >= 0
	var base_width := radius * (2.2 if is_core else 1.8)
	var base_height := radius * (0.72 if is_core else 0.6)
	draw_rect(Rect2(Vector2(-base_width * 0.5, radius * 0.35), Vector2(base_width, base_height)), Color(0.10, 0.14, 0.19, 0.95))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-radius * 0.62, radius * 0.35), Vector2(-radius * 0.45, -radius * 0.6),
		Vector2(radius * 0.45, -radius * 0.6), Vector2(radius * 0.62, radius * 0.35)
	]), color.darkened(0.18))
	draw_rect(Rect2(Vector2(-radius * 0.3, -radius * 0.42), Vector2(radius * 0.6, radius * 0.72)), color.lightened(0.06))
	var crystal := radius * (0.58 if is_core else 0.42)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -radius * 1.16), Vector2(crystal, -radius * 0.56),
		Vector2(0, -radius * 0.08), Vector2(-crystal, -radius * 0.56)
	]), Color(0.45, 0.9, 1.0) if color.b > color.r else Color(1.0, 0.5, 0.42))
