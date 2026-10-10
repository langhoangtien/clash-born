extends PanelContainer
signal buy_requested(item: EquipmentData)
signal sell_requested(slot: int)
signal hero_requested(index: int)
const CATALOG = preload("res://scripts/ui/equipment_panel.gd").CATALOG
var progression: HeroProgression
var header: Label
var stats_label: Label
var feedback: Label
var buy_buttons: Array[Button] = []
var slot_buttons: Array[Button] = []
var hero_select: OptionButton

func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.07, 0.095, 0.98)
	background.border_color = Color(0.3, 0.5, 0.65)
	background.set_border_width_all(2)
	add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	header = Label.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", 22)
	top.add_child(header)
	var close := Button.new()
	close.text = "Đóng [B]"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	top.add_child(close)
	var note := Label.new()
	note.text = "Mua ở mọi nơi · Trận vẫn chạy · Bán hoàn %.0f%% · Giữ tỷ lệ máu khi đổi đồ" % [progression.settings.sell_refund * 100]
	content.add_child(note)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(585, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)
	var catalog := VBoxContainer.new()
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(catalog)
	for item in CATALOG:
		var button := Button.new()
		button.text = "%s · %d vàng\n%s" % [item.display_name, item.price, item.bonus_summary()]
		button.tooltip_text = item.description
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): buy_requested.emit(item))
		catalog.add_child(button)
		buy_buttons.append(button)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 315
	columns.add_child(right)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(stats_label)
	for slot in range(EquipmentManager.SLOT_COUNT):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): sell_requested.emit(slot))
		right.add_child(button)
		slot_buttons.append(button)
	hero_select = OptionButton.new()
	hero_select.focus_mode = Control.FOCUS_NONE
	for profile in progression.settings.hero_profiles: hero_select.add_item(profile.display_name)
	hero_select.select(clampi(HeroProgression.selected_profile, 0, hero_select.item_count - 1))
	right.add_child(hero_select)
	var restart := Button.new()
	restart.text = "Chọn hero & chơi trận mới"
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(func(): hero_requested.emit(hero_select.selected))
	right.add_child(restart)
	feedback = Label.new()
	content.add_child(feedback)
	hide()
	refresh()

func refresh() -> void:
	if header == null: return
	var stats: Dictionary = progression.unit.stats
	header.text = "SHOP · %s · LV %d · %d vàng" % [progression.profile.display_name, progression.level, progression.gold]
	stats_label.text = "Mỗi cấp: %s\nHP %.0f · Mana %.0f\nCông VL %.1f · Phép %.1f\nTốc chạy %.0f · Tốc đánh %.2f\nTRANG BỊ · click để bán" % [progression.profile.growth_summary(), stats.max_hp, stats.max_mana, stats.physical_damage, stats.magic_damage, stats.movement_speed, stats.attack_speed]
	for index in range(CATALOG.size()):
		var reason := progression.purchase_error(CATALOG[index])
		buy_buttons[index].disabled = not reason.is_empty()
		buy_buttons[index].tooltip_text = CATALOG[index].description + ("\n" + reason if not reason.is_empty() else "")
	for slot in range(EquipmentManager.SLOT_COUNT):
		var item := progression.equipment.get_item(slot)
		slot_buttons[slot].disabled = item == null
		slot_buttons[slot].text = "%d · Trống" % [slot + 1] if item == null else "%d · %s · bán %d" % [slot + 1, item.display_name, floori(item.price * progression.settings.sell_refund)]
