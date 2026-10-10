extends PanelContainer
## Presentation selects loadouts; the controller rebuilds the combat snapshot.

signal loadout_changed
signal unit_selected(index: int)

const CATALOG: Array[EquipmentData] = [
	preload("res://data/equipment/iron_armor.tres"),
	preload("res://data/equipment/mystic_cloak.tres"),
	preload("res://data/equipment/vitality_stone.tres"),
	preload("res://data/equipment/precision_blade.tres"),
	preload("res://data/equipment/critical_blade.tres"),
	preload("res://data/equipment/evasion_blade.tres"),
	preload("res://data/equipment/armor_breaker.tres"),
	preload("res://data/equipment/heavy_sword.tres"),
	preload("res://data/equipment/arcane_staff.tres"),
	preload("res://data/equipment/pure_blade.tres"),
	preload("res://data/equipment/swift_gloves.tres"),
	preload("res://data/equipment/resolve_amulet.tres"),
]

var loadouts: Array[EquipmentManager] = []
var units: Array[UnitRuntimeState] = []
var unit_select: OptionButton
var slot_selectors: Array[OptionButton] = []
var reset_button: Button
var stats_label: Label
var bonus_label: Label

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var title := Label.new()
	title.text = "EQUIPMENT · 6 SLOTS"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	unit_select = OptionButton.new()
	unit_select.add_item("Blue Unit")
	unit_select.add_item("Red Unit")
	unit_select.item_selected.connect(func(index: int): refresh(); unit_selected.emit(index))
	content.add_child(unit_select)
	var note := Label.new()
	note.text = "Empty removes item. Changes reset battle."
	note.tooltip_text = "Prices are reference values only. No shop or gold economy."
	note.add_theme_font_size_override("font_size", 14)
	content.add_child(note)
	for slot in range(EquipmentManager.SLOT_COUNT):
		var row := HBoxContainer.new()
		content.add_child(row)
		var slot_label := Label.new()
		slot_label.text = "%d" % (slot + 1)
		slot_label.custom_minimum_size.x = 18
		row.add_child(slot_label)
		var select := OptionButton.new()
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.add_theme_font_size_override("font_size", 14)
		select.add_item("Empty")
		for item in CATALOG:
			select.add_item("%s · %s" % [item.display_name, item.bonus_summary()])
			select.set_item_tooltip(select.item_count - 1, "%s\n%s\nReference price: %d" % [item.description, item.bonus_summary(), item.price])
		select.item_selected.connect(func(item_index: int): _change_slot(slot, item_index))
		row.add_child(select)
		slot_selectors.append(select)
	reset_button = Button.new()
	reset_button.text = "Reset equipment (selected unit)"
	reset_button.pressed.connect(_clear_selected)
	content.add_child(reset_button)
	bonus_label = Label.new()
	bonus_label.add_theme_font_size_override("font_size", 14)
	bonus_label.clip_text = true
	bonus_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(bonus_label)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 14)
	content.add_child(stats_label)

func _change_slot(slot: int, item_index: int) -> void:
	if loadouts.is_empty() or item_index < 0 or item_index > CATALOG.size():
		return
	var loadout := loadouts[unit_select.selected]
	var changed := loadout.remove(slot) if item_index == 0 else loadout.equip(slot, CATALOG[item_index - 1])
	if changed:
		loadout_changed.emit()
	refresh()

func _clear_selected() -> void:
	if loadouts.is_empty():
		return
	loadouts[unit_select.selected].clear()
	loadout_changed.emit()
	refresh()

func refresh() -> void:
	if loadouts.is_empty() or loadouts.size() != units.size():
		return
	var loadout := loadouts[unit_select.selected]
	for slot in range(EquipmentManager.SLOT_COUNT):
		var item := loadout.get_item(slot)
		var selected := 0
		if item != null:
			for index in range(CATALOG.size()):
				if CATALOG[index].id == item.id:
					selected = index + 1
					break
		slot_selectors[slot].select(selected)
	var combined := EquipmentManager.aggregate(loadout.items())
	var bonuses: Dictionary = combined.bonuses
	var evasion_sources: Array[float] = combined.evasion_sources
	var summary := EquipmentData.new()
	for key in bonuses: summary.modifiers[key] = bonuses[key]
	# Preserve independent evasion in the summary, rather than claiming additive bonus.
	var bonus_text := summary.bonus_summary()
	if not evasion_sources.is_empty():
		bonus_text += ("; " if not bonus_text.is_empty() else "") + "%d independent evade source(s)" % evasion_sources.size()
	bonus_label.text = "Gear: " + ("None" if bonus_text.is_empty() else bonus_text)
	bonus_label.tooltip_text = bonus_label.text
	refresh_stats()

func refresh_stats() -> void:
	if units.is_empty():
		return
	var stats: Dictionary = units[unit_select.selected].stats
	stats_label.text = "FINAL · HP %.0f · Mana %.0f\nDamage P %.1f / M %.1f / Pure %.1f\nArmor P %.2f / M %.2f · APS %.2f\nEvade %.1f%% · Accuracy %.0f%%\nCrit %.0f%% × %.1f · Resist %.0f%%" % [stats.max_hp, stats.max_mana, stats.physical_damage, stats.magic_damage, stats.pure_damage, units[unit_select.selected].physical_armor(), stats.magic_armor, stats.attack_speed, stats.evasion * 100, stats.accuracy * 100, stats.critical_chance * 100, stats.critical_multiplier, stats.status_resistance * 100]

func bind_units(new_units: Array[UnitRuntimeState], new_loadouts: Array[EquipmentManager], selection: int) -> void:
	units = new_units
	loadouts = new_loadouts
	unit_select.clear()
	for unit in units: unit_select.add_item("%s · %s" % [unit.unit_id, unit.display_name])
	unit_select.select(clampi(selection, 0, units.size() - 1))
	refresh()
