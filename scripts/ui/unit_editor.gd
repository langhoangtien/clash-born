extends ScrollContainer

signal source_changed
signal unit_selected(index: int)

const FIELDS: Array = [
	["strength", "STR", 0, 500, false], ["agility", "AGI", 0, 500, false], ["intelligence", "INT", 0, 500, false],
	["base_hp", "Base HP", 1, 100000, false], ["base_mana", "Base Mana", 0, 10000, false],
	["base_hp_regen", "Base HP regen / s", 0, 1000, false], ["base_mana_regen", "Base Mana regen / s", 0, 1000, false],
	["physical_damage", "Base physical damage", 0, 10000, false], ["magic_damage", "Base magic damage", 0, 10000, false], ["pure_damage", "Base pure damage", 0, 10000, false],
	["physical_armor", "Base physical armor", -1000, 1000, false], ["magic_armor", "Base magic armor", -1000, 1000, false],
	["base_attacks_per_second", "Base attacks / s", 0.01, 20, false], ["attack_speed_bonus", "Attack speed bonus %", -99, 1000, true],
	["attack_range", "Attack range", 0, 1600, false], ["movement_speed", "Movement speed", 0, 1000, false],
	["evasion", "Base evasion %", 0, 100, true], ["accuracy", "Accuracy points %", 0, 200, true],
	["critical_chance", "Critical chance %", 0, 100, true], ["critical_multiplier", "Crit multiplier (0=default)", 0, 10, false],
	["status_resistance", "Status resistance %", 0, 100, true], ["armor_reduction", "Flat armor reduction", 0, 1000, false],
	["magic_armor_reduction", "Flat magic armor reduction", 0, 1000, false], ["physical_armor_penetration", "Physical penetration %", 0, 100, true],
]

var sources: Array[UnitStats] = []
var units: Array[UnitRuntimeState] = []
var unit_select: OptionButton
var ai_select: OptionButton
var primary_select: OptionButton
var ability_toggle: CheckBox
var primary_toggle: CheckBox
var fields: Dictionary = {}
var final_label: Label

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	unit_select = OptionButton.new()
	unit_select.item_selected.connect(func(index: int): refresh(); unit_selected.emit(index))
	content.add_child(unit_select)
	final_label = Label.new()
	final_label.add_theme_font_size_override("font_size", 14)
	final_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(final_label)
	var note := Label.new()
	note.text = "SOURCE VALUES · Changes reset battle\nPercent fields use 0–100; final stats include equipment."
	note.add_theme_font_size_override("font_size", 14)
	content.add_child(note)
	ai_select = OptionButton.new()
	for name in ["Passive", "Attack nearest", "Attack lowest HP", "Attack highest damage"]: ai_select.add_item(name)
	ai_select.item_selected.connect(func(index: int): sources[unit_select.selected].ai_mode = index; source_changed.emit())
	content.add_child(ai_select)
	ability_toggle = CheckBox.new()
	ability_toggle.text = "AI uses available abilities"
	ability_toggle.toggled.connect(func(value: bool): sources[unit_select.selected].abilities_enabled = value; source_changed.emit())
	content.add_child(ability_toggle)
	primary_select = OptionButton.new()
	for name in ["Primary: None", "Primary: STR", "Primary: AGI", "Primary: INT"]: primary_select.add_item(name)
	primary_select.item_selected.connect(func(index: int): sources[unit_select.selected].primary_attribute = index; source_changed.emit())
	content.add_child(primary_select)
	primary_toggle = CheckBox.new()
	primary_toggle.text = "Enable primary attribute damage"
	primary_toggle.toggled.connect(func(value: bool): sources[unit_select.selected].primary_damage_enabled = value; source_changed.emit())
	content.add_child(primary_toggle)
	for definition in FIELDS:
		var row := HBoxContainer.new()
		content.add_child(row)
		var label := Label.new()
		label.text = definition[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var field := SpinBox.new()
		field.min_value = definition[2]
		field.max_value = definition[3]
		field.step = 0.1 if definition[0] != "base_attacks_per_second" else 0.01
		field.custom_minimum_size.x = 140
		field.value_changed.connect(func(value: float):
			sources[unit_select.selected].set(definition[0], value / 100.0 if definition[4] else value)
			source_changed.emit()
		)
		row.add_child(field)
		fields[definition[0]] = field

func bind_sources(new_sources: Array[UnitStats], new_units: Array[UnitRuntimeState], selection: int) -> void:
	sources = new_sources
	units = new_units
	unit_select.clear()
	for unit in units: unit_select.add_item("%s · %s" % [unit.unit_id, unit.display_name])
	unit_select.select(clampi(selection, 0, units.size() - 1))
	refresh()

func refresh() -> void:
	if sources.is_empty(): return
	var source := sources[unit_select.selected]
	ai_select.select(source.ai_mode)
	primary_select.select(source.primary_attribute)
	ability_toggle.set_pressed_no_signal(source.abilities_enabled)
	primary_toggle.set_pressed_no_signal(source.primary_damage_enabled)
	for definition in FIELDS:
		fields[definition[0]].set_value_no_signal(source.get(definition[0]) * (100.0 if definition[4] else 1.0))
	refresh_stats()

func refresh_stats() -> void:
	if units.is_empty(): return
	var unit := units[unit_select.selected]
	var stats := unit.stats
	final_label.text = "FINAL / CURRENT\nHP %.1f / %.1f · Mana %.1f / %.1f\nSTR %.1f · AGI %.1f · INT %.1f\nDamage P %.1f / M %.1f / Pure %.1f\nArmor P %.2f / M %.2f · APS %.2f\nEvade %.1f%% · Accuracy %.1f%% · Crit %.1f%%\nResist %.1f%% · Move %.1f" % [unit.current_hp, stats.max_hp, unit.current_mana, stats.max_mana, stats.strength, stats.agility, stats.intelligence, stats.physical_damage, stats.magic_damage, stats.pure_damage, unit.physical_armor(), stats.magic_armor, stats.attack_speed, stats.evasion * 100, stats.accuracy * 100, stats.critical_chance * 100, stats.status_resistance * 100, unit.movement_speed(preload("res://data/balance/default_balance.tres"))]
	var statuses: PackedStringArray = []
	for effect in unit.effects.active:
		statuses.append("%s %.2fs" % [["Stun", "Slow", "Armor reduction"][effect.kind], effect.remaining_seconds(unit.current_tick)])
	final_label.text += "\nEffects: " + ("None" if statuses.is_empty() else ", ".join(statuses))
	var skills: PackedStringArray = []
	for ability in unit.abilities:
		var remaining := maxf(0, unit.ability_ready_ticks.get(ability.id, 0) - unit.current_tick) * SimulationClock.TICK_SECONDS
		skills.append("%s %.1fs" % [ability.display_name, remaining])
	final_label.text += "\nAbilities: " + ("None" if skills.is_empty() else ", ".join(skills))
