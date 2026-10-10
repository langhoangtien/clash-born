extends PanelContainer
var heroes: Dictionary
var rows: Dictionary = {}
var slot_buttons: Dictionary = {}

func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.07, 0.095, 0.98)
	background.border_color = Color(0.3, 0.5, 0.65)
	background.set_border_width_all(2)
	add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	var title := Label.new()
	title.text = "TRANG BỊ HAI ĐỘI · rê chuột vào icon để xem chỉ số"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	top.add_child(title)
	var close := Button.new()
	close.text = "Đóng [Tab]"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	top.add_child(close)
	for id in ["player", "enemy_hero"]:
		var row := HBoxContainer.new()
		content.add_child(row)
		var label := Label.new()
		label.custom_minimum_size = Vector2(320, 90)
		row.add_child(label)
		rows[id] = label
		var slots: Array[Button] = []
		for index in range(EquipmentManager.SLOT_COUNT):
			var slot := Button.new()
			slot.custom_minimum_size = Vector2(90, 90)
			slot.focus_mode = Control.FOCUS_NONE
			slot.add_theme_constant_override("icon_max_width", 56)
			row.add_child(slot)
			slots.append(slot)
		slot_buttons[id] = slots
	refresh()
	hide()

func refresh() -> void:
	for id in rows:
		var hero: HeroProgression = heroes[id]
		var stats: Dictionary = hero.unit.stats
		rows[id].text = "%s · %s · LV %d\nHP %.0f / %.0f\nCông VL %.0f / Phép %.0f" % ["BLUE · BẠN" if id == "player" else "RED · BOT", hero.profile.display_name, hero.level, hero.unit.current_hp, stats.max_hp, stats.physical_damage, stats.magic_damage]
		rows[id].modulate = Color(0.5, 0.75, 1) if id == "player" else Color(1, 0.5, 0.5)
		for index in range(EquipmentManager.SLOT_COUNT):
			var item := hero.equipment.get_item(index)
			var slot: Button = slot_buttons[id][index]
			slot.icon = item.icon if item != null else null
			slot.text = "—" if item == null else ""
			slot.tooltip_text = "Ô trống" if item == null else item.display_name + "\n" + item.bonus_summary()
