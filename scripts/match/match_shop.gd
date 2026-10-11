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
var shop_columns: HBoxContainer
var draft_panel: VBoxContainer
var draft_player_card: PanelContainer
var draft_enemy_card: PanelContainer
var draft_enemy_select: OptionButton
var shop_note: Label
var draft_confirm: Button
var draft_enabled: bool = false
var preview_progression: HeroProgression

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
	shop_note = note
	note.text = "Click đồ lớn để mua thẳng nếu đủ vàng · nguyên liệu đang có tự trừ giá · Bán hoàn %.0f%%" % [progression.settings.sell_refund * 100]
	note.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	content.add_child(note)
	draft_panel = VBoxContainer.new()
	draft_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(draft_panel)
	var draft_title := Label.new()
	draft_title.text = "CHỌN ĐỘI HÌNH · BLUE VS RED"
	draft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_title.add_theme_font_size_override("font_size", 28)
	draft_title.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0))
	draft_panel.add_child(draft_title)
	var draft_hint := Label.new()
	draft_hint.text = "Chọn hero cho mỗi bên trước khi bắt đầu trận"
	draft_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_panel.add_child(draft_hint)
	var draft_cards := HBoxContainer.new()
	draft_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draft_panel.add_child(draft_cards)
	draft_player_card = _make_draft_card("BLUE · HERO CỦA BẠN", Color(0.2, 0.65, 1.0))
	draft_cards.add_child(draft_player_card)
	draft_enemy_card = _make_draft_card("RED · HERO ĐỐI THỦ", Color(1.0, 0.35, 0.35))
	draft_cards.add_child(draft_enemy_card)
	var draft_selects := HBoxContainer.new()
	draft_panel.add_child(draft_selects)
	var blue_select := OptionButton.new()
	blue_select.name = "BlueHeroSelect"
	for profile in progression.settings.hero_profiles: blue_select.add_item("BLUE · " + profile.display_name)
	blue_select.select(clampi(HeroProgression.selected_profile, 0, blue_select.item_count - 1))
	blue_select.item_selected.connect(func(index: int): hero_select.select(index); _sync_hero_skill(); refresh())
	draft_selects.add_child(blue_select)
	draft_enemy_select = OptionButton.new()
	for profile in progression.settings.hero_profiles: draft_enemy_select.add_item("RED · " + profile.display_name)
	draft_enemy_select.select(clampi(HeroProgression.selected_enemy_profile, 0, draft_enemy_select.item_count - 1))
	draft_enemy_select.item_selected.connect(func(_index: int): refresh())
	draft_selects.add_child(draft_enemy_select)
	draft_confirm = Button.new()
	draft_confirm.text = "XÁC NHẬN ĐỘI HÌNH · BẮT ĐẦU TRẬN"
	draft_confirm.custom_minimum_size.y = 52
	draft_confirm.add_theme_font_size_override("font_size", 21)
	draft_confirm.pressed.connect(func(): HeroProgression.draft_confirmed = true; HeroProgression.selected_enemy_profile = draft_enemy_select.selected; hero_requested.emit(hero_select.selected))
	draft_panel.add_child(draft_confirm)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_columns = columns
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
	hero_select.item_selected.connect(func(_index: int): _sync_hero_skill(); refresh())
	right.add_child(hero_select)
	passive_select = OptionButton.new()
	passive_select.focus_mode = Control.FOCUS_NONE
	passive_select.disabled = true
	right.add_child(passive_select)
	_sync_hero_skill()
	passive_upgrade = Button.new()
	passive_upgrade.focus_mode = Control.FOCUS_NONE
	passive_upgrade.pressed.connect(func(): passive_upgrade_requested.emit())
	right.add_child(passive_upgrade)
	var restart := Button.new()
	restart.text = "Chọn hero & chơi trận mới"
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(func(): HeroProgression.draft_confirmed = true; HeroProgression.selected_enemy_profile = draft_enemy_select.selected; hero_requested.emit(hero_select.selected))
	right.add_child(restart)
	feedback = Label.new()
	content.add_child(feedback)
	draft_panel.hide()
	hide()
	refresh()

func set_draft_mode(enabled: bool) -> void:
	draft_enabled = enabled
	if close_button != null: close_button.disabled = enabled
	if enabled:
		feedback.text = "Mỗi hero có bộ chỉ số, tăng trưởng và một kỹ năng riêng. Chọn hero rồi bắt đầu."
	if draft_panel != null: draft_panel.visible = enabled
	if shop_columns != null: shop_columns.visible = not enabled
	if shop_note != null: shop_note.visible = not enabled

func _make_draft_card(title: String, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 190)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.12, 0.96)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", color)
	label.text = title + "\n\nChọn hero bên dưới"
	card.add_child(label)
	return card

func _set_card_text(card: PanelContainer, value: String) -> void:
	if card != null and card.get_child_count() > 0: card.get_child(0).text = value

func _role_icon(profile: HeroGrowth) -> String:
	if not profile.ranged_attacks: return "⚔"
	if profile.primary_attribute == UnitStats.PrimaryAttribute.INTELLIGENCE: return "✦"
	return "➶"

func _sync_hero_skill() -> void:
	if passive_select == null or hero_select == null or progression == null: return
	passive_select.clear()
	var index := clampi(hero_select.selected, 0, progression.settings.hero_profiles.size() - 1)
	var profile: HeroGrowth = progression.settings.hero_profiles[index]
	var passive := HeroPassiveCatalog.definition(profile.passive_id)
	passive_select.add_item("Kỹ năng riêng: " + passive.name)
	passive_select.set_item_tooltip(0, passive.description)
	var preview_state := UnitRuntimeState.new("hero_preview", 0, Vector2.ZERO, progression.base, progression.balance)
	preview_progression = HeroProgression.new(preview_state, progression.base, profile, progression.settings, progression.balance)
	preview_progression.select_profile_skill()

func refresh() -> void:
	if header == null: return
	var shown := preview_progression if draft_enabled and preview_progression != null else progression
	var stats: Dictionary = shown.unit.stats
	header.text = "SHOP · %s · LV %d · %d vàng" % [shown.profile.display_name, shown.level, progression.gold]
	var reduction := (1.0 - DamageCalculator.armor_multiplier(shown.unit.physical_armor(), shown.balance.armor_coefficient)) * 100.0
	var passive := HeroPassiveCatalog.definition(shown.passive_id)
	if draft_player_card != null:
		_set_card_text(draft_player_card, "%s  BLUE · %s\n\nHP %.0f · Dame %.0f\nSTR %.0f · AGI %.0f · INT %.0f\n%s" % [_role_icon(shown.profile), shown.profile.display_name, stats.max_hp, stats.physical_damage, stats.strength, stats.agility, stats.intelligence, shown.profile.growth_summary()])
	if draft_enemy_card != null and draft_enemy_select != null and not progression.settings.hero_profiles.is_empty():
		var enemy_profile: HeroGrowth = progression.settings.hero_profiles[clampi(draft_enemy_select.selected, 0, progression.settings.hero_profiles.size() - 1)]
		_set_card_text(draft_enemy_card, "%s  RED · %s\n\nĐội hình máy\n%s\nKỹ năng: %s" % [_role_icon(enemy_profile), enemy_profile.display_name, enemy_profile.growth_summary(), HeroPassiveCatalog.definition(enemy_profile.passive_id).name])
	stats_label.text = "KỸ NĂNG: %s · LV %d/5 · điểm %d\n%s\nTĂNG MỖI LV: %s\nSTR %.0f · AGI %.0f · INT %.0f\nHP %.0f · Mana %.0f · Regen %.1f\nDamage VL %.1f / Phép %.1f / Pure %.1f\nGiáp %.1f (giảm %.1f%% VL) · giáp phép %.1f\nNé/miss %.1f%% · chính xác %.1f%%\nCrit %.1f%% × %.2f · kháng %.1f%%\nTầm đánh %.0f · cast %.0f · chạy %.0f\nTốc đánh %.0f%% · %.2f đòn/s · BAT %.1fs\nTRANG BỊ · click để bán" % [passive.name, shown.passive_level, shown.skill_points, passive.description, shown.profile.growth_summary(), stats.strength, stats.agility, stats.intelligence, stats.max_hp, stats.max_mana, stats.hp_regen, stats.physical_damage, stats.magic_damage, stats.pure_damage, shown.unit.physical_armor(), reduction, stats.magic_armor, stats.evasion * 100, stats.accuracy * 100, stats.critical_chance * 100, stats.critical_multiplier, stats.status_resistance * 100, stats.attack_range, stats.cast_range, stats.movement_speed, stats.attack_speed / stats.base_attacks_per_second * 100, shown.unit.attack_speed(), stats.base_attack_time]
	passive_upgrade.text = "Nâng kỹ năng (%d điểm còn lại)" % progression.skill_points
	passive_upgrade.disabled = draft_enabled or progression.skill_points <= 0 or progression.passive_level >= 5
	for index in range(CATALOG.size()):
		var reason := progression.purchase_error(CATALOG[index])
		buy_buttons[index].disabled = not reason.is_empty()
		buy_buttons[index].tooltip_text = CATALOG[index].description + "\nGiá cần trả lúc này: %d" % progression.purchase_cost(CATALOG[index]) + ("\n" + reason if not reason.is_empty() else "")
	for slot in range(EquipmentManager.SLOT_COUNT):
		var item := progression.equipment.get_item(slot)
		slot_buttons[slot].disabled = item == null
		slot_buttons[slot].icon = item.icon if item != null else null
		slot_buttons[slot].add_theme_constant_override("icon_max_width", 28)
		slot_buttons[slot].text = "%d · Trống" % [slot + 1] if item == null else "%d · %s · bán %d" % [slot + 1, item.display_name, floori(item.price * progression.settings.sell_refund)]
