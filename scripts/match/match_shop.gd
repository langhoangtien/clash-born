extends PanelContainer
signal buy_requested(item: EquipmentData)
signal sell_requested(slot: int)
signal hero_requested(index: int)
signal passive_upgrade_requested
var CATALOG: Array[EquipmentData] = MatchItemCatalog.items()
var progression: HeroProgression
var header: Label
var stats_label: Label
var feedback: Label
var buy_buttons: Array[Button] = []
var slot_buttons: Array[Button] = []
var hero_select: OptionButton
var passive_select: OptionButton
var passive_upgrade: Button
var close_button: Button

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
	close_button = Button.new()
	close_button.text = "Đóng [B]"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(hide)
	top.add_child(close_button)
	var note := Label.new()
	note.text = "Mua ở mọi nơi · Trận vẫn chạy · Bán hoàn %.0f%% · Giữ tỷ lệ máu khi đổi đồ" % [progression.settings.sell_refund * 100]
	content.add_child(note)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 500)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)
	var catalog := VBoxContainer.new()
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(catalog)
	for item in CATALOG:
		var button := Button.new()
		button.text = "%s · tổng %d vàng%s\n%s" % [item.display_name, item.price, " · phí ghép %d" % item.recipe_cost if not item.recipe_components.is_empty() else "", item.bonus_summary()]
		button.icon = item.icon
		button.add_theme_constant_override("icon_max_width", 42)
		button.tooltip_text = item.description
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): buy_requested.emit(item))
		catalog.add_child(button)
		buy_buttons.append(button)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 400
	columns.add_child(right)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(stats_label)
	var slot_grid := GridContainer.new()
	slot_grid.columns = 2
	right.add_child(slot_grid)
	for slot in range(EquipmentManager.SLOT_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): sell_requested.emit(slot))
		slot_grid.add_child(button)
		slot_buttons.append(button)
	hero_select = OptionButton.new()
	hero_select.focus_mode = Control.FOCUS_NONE
	for profile in progression.settings.hero_profiles: hero_select.add_item(profile.display_name)
	hero_select.select(clampi(HeroProgression.selected_profile, 0, hero_select.item_count - 1))
	right.add_child(hero_select)
	passive_select = OptionButton.new()
	passive_select.focus_mode = Control.FOCUS_NONE
	for passive in HeroPassiveCatalog.DEFINITIONS:
		passive_select.add_item(passive.name)
		passive_select.set_item_tooltip(passive_select.item_count - 1, passive.description)
	passive_select.select(clampi(HeroProgression.selected_passive, 0, passive_select.item_count - 1))
	right.add_child(passive_select)
	passive_upgrade = Button.new()
	passive_upgrade.focus_mode = Control.FOCUS_NONE
	passive_upgrade.pressed.connect(func(): passive_upgrade_requested.emit())
	right.add_child(passive_upgrade)
	var restart := Button.new()
	restart.text = "Chọn hero + nội tại & chơi trận mới"
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(func(): HeroProgression.selected_passive = passive_select.selected; HeroProgression.draft_confirmed = true; hero_requested.emit(hero_select.selected))
	right.add_child(restart)
	feedback = Label.new()
	content.add_child(feedback)
	hide()
	refresh()

func set_draft_mode(enabled: bool) -> void:
	if close_button != null: close_button.disabled = enabled
	if enabled:
		feedback.text = "Chọn hero và một nội tại khởi đầu, sau đó bấm nút chơi trận mới."

func refresh() -> void:
	if header == null: return
	var stats: Dictionary = progression.unit.stats
	header.text = "SHOP · %s · LV %d · %d vàng" % [progression.profile.display_name, progression.level, progression.gold]
	var reduction := (1.0 - DamageCalculator.armor_multiplier(progression.unit.physical_armor(), progression.balance.armor_coefficient)) * 100.0
	var passive := HeroPassiveCatalog.definition(progression.passive_id)
	stats_label.text = "NỘI TẠI: %s · LV %d/5 · điểm %d\n%s\nSTR %.0f · AGI %.0f · INT %.0f\nHP %.0f · Mana %.0f · Regen %.1f\nDamage VL %.1f / Phép %.1f / Pure %.1f\nGiáp %.1f (giảm %.1f%% VL) · giáp phép %.1f\nNé/miss %.1f%% · chính xác %.1f%%\nCrit %.1f%% × %.2f · kháng %.1f%%\nTầm đánh %.0f · cast %.0f · chạy %.0f\nTốc đánh %.0f%% · %.2f đòn/s · BAT %.1fs\nTRANG BỊ · click để bán" % [passive.name, progression.passive_level, progression.skill_points, passive.description, stats.strength, stats.agility, stats.intelligence, stats.max_hp, stats.max_mana, stats.hp_regen, stats.physical_damage, stats.magic_damage, stats.pure_damage, progression.unit.physical_armor(), reduction, stats.magic_armor, stats.evasion * 100, stats.accuracy * 100, stats.critical_chance * 100, stats.critical_multiplier, stats.status_resistance * 100, stats.attack_range, stats.cast_range, stats.movement_speed, stats.attack_speed / progression.base.base_attacks_per_second * 100, progression.unit.attack_speed(), 1.0 / progression.base.base_attacks_per_second]
	passive_upgrade.text = "Nâng nội tại (%d điểm còn lại)" % progression.skill_points
	passive_upgrade.disabled = progression.skill_points <= 0 or progression.passive_level >= 5
	for index in range(CATALOG.size()):
		var reason := progression.purchase_error(CATALOG[index])
		buy_buttons[index].disabled = not reason.is_empty()
		buy_buttons[index].tooltip_text = CATALOG[index].description + ("\n" + reason if not reason.is_empty() else "")
	for slot in range(EquipmentManager.SLOT_COUNT):
		var item := progression.equipment.get_item(slot)
		slot_buttons[slot].disabled = item == null
		slot_buttons[slot].icon = item.icon if item != null else null
		slot_buttons[slot].add_theme_constant_override("icon_max_width", 28)
		slot_buttons[slot].text = "%d · Trống" % [slot + 1] if item == null else "%d · %s · bán %d" % [slot + 1, item.display_name, floori(item.price * progression.settings.sell_refund)]
