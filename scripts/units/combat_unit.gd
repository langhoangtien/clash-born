extends Node2D

signal unit_selected(id: String)
@export var visual_data: UnitVisualData
@export var combat_data: UnitStats
var runtime: UnitRuntimeState
var selected: bool = false
var damage_flash: float = 0.0
var hit_notice: String = ""
var show_range_indicators: bool = true
var show_resource_bars: bool = true
var structure_visual: bool = false
var compact_visual: bool = false

func _process(delta: float) -> void:
	damage_flash = maxf(0, damage_flash - delta)
	if runtime != null: position = runtime.position
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and visual_data != null:
		var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if runtime != null and local_point.length() <= runtime.stats.collision_radius:
			unit_selected.emit(visual_data.unit_id)
			get_viewport().set_input_as_handled()

func show_damage(amount: float, critical: bool = false) -> void:
	hit_notice = ("CRIT " if critical else "") + "-%.1f" % amount
	damage_flash = 0.5

func show_miss() -> void:
	hit_notice = "MISS"
	damage_flash = 0.5

func _center_text(text: String, y: float, size_value: int, color: Color = Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	draw_string(font, Vector2(-width / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

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
	if structure_visual: draw_rect(Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), color)
	else: draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, 5, Color(1, 1, 1, 0.7))
	if not compact_visual: _center_text(visual_data.display_name, -radius - 12, 20)
	if show_resource_bars:
		_draw_bar(32 if compact_visual else 44, runtime.current_hp / runtime.stats.max_hp, Color(0.25, 0.8, 0.42))
		if not compact_visual: _draw_bar(56, runtime.current_mana / runtime.stats.max_mana if runtime.stats.max_mana > 0 else 0, Color(0.25, 0.55, 0.95))
		if selected: _center_text("%.0f / %.0f" % [runtime.current_hp, runtime.stats.max_hp], 82, 20)
	var statuses: PackedStringArray = []
	for effect in runtime.effects.active:
		var tag: String = ["S", "L", "A", "AR", "CR"][effect.kind]
		if tag not in statuses: statuses.append(tag)
	if not runtime.casting.is_empty(): statuses.append("C")
	if not statuses.is_empty() and runtime.alive: _center_text(" ".join(statuses), 8, 18, Color(0.07, 0.08, 0.1))
	if not runtime.alive: _center_text("DEAD", 8, 18)
	elif damage_flash > 0: _center_text(hit_notice, -80, 24, Color(1, 0.78, 0.45))

func _draw_bar(y: float, ratio: float, color: Color) -> void:
	var width := 50.0 if compact_visual else 90.0
	draw_rect(Rect2(Vector2(-width / 2, y), Vector2(width, 8)), Color(0.02, 0.03, 0.04))
	draw_rect(Rect2(Vector2(-width / 2, y), Vector2(width * clampf(ratio, 0, 1), 8)), color)
