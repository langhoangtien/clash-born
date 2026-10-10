extends Node2D

const ARCHETYPES: Array[UnitStats] = [preload("res://data/units/archetypes/physical_tank.tres"), preload("res://data/units/archetypes/magic_tank.tres"), preload("res://data/units/archetypes/melee_carry.tres"), preload("res://data/units/archetypes/ranged_carry.tres"), preload("res://data/units/archetypes/mage.tres")]
var clock := SimulationClock.new()
var combat := CombatEngine.new(preload("res://data/balance/default_balance.tres"))
var sources: Array[UnitStats] = []
var loadouts: Array[EquipmentManager] = []
var stored_sources: Array[UnitStats] = []
var stored_loadouts: Array[EquipmentManager] = []
var counts: Array[int] = [1, 1]
var count_fields: Array[SpinBox] = []
var archetype_fields: Array[OptionButton] = []
var views: Dictionary = {}
var selected_id: String = "blue_01"
var status_label: Label
var battle_label: Label
var run_button: Button
var step_button: Button
var seed_field: SpinBox
var effect_target: OptionButton
var effect_buttons: Array[Button] = []
var equipment_panel: PanelContainer
var unit_editor: ScrollContainer
var right_tabs: TabContainer
var log_panel: TextEdit
var results_panel: TextEdit
var log_lines: Array[String] = []

func _ready() -> void:
	for team in range(2):
		for slot in range(5):
			stored_sources.append(ARCHETYPES[slot if team == 0 else (4 if slot == 0 else slot - 1)].duplicate(true))
			stored_loadouts.append(EquipmentManager.new())
	$Arena.position = Vector2(24, 230)
	$Arena.scale = Vector2(0.64, 0.64)
	$Arena.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var projectile_view := Node2D.new()
	projectile_view.z_index = 100
	projectile_view.set_script(preload("res://scripts/ui/projectile_view.gd"))
	projectile_view.combat = combat
	$Arena.add_child(projectile_view)
	_build_ui()
	_reset_combat()
	clock.ticked.connect(_on_tick)
	_refresh_ui()

func _process(delta: float) -> void:
	clock.advance(delta)
	_refresh_ui()

func _button(parent: Node, text: String, callback: Callable, width: float = 90) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 36)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _panel(layer: Node, position_value: Vector2, size_value: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.size = size_value
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	return content

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var header := _panel(layer, Vector2(24, 12), Vector2(1552, 72))
	var title := Label.new()
	title.text = "CLASHBORN  /  RANGE & PROJECTILE SANDBOX"
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Configure 1–5 units per team · Click to inspect · Changes reset battle · S: stun / L: slow / A: armor reduction / C: casting"
	subtitle.add_theme_font_size_override("font_size", 14)
	header.add_child(subtitle)
	var team_content := _panel(layer, Vector2(24, 94), Vector2(1552, 98))
	for team in range(2):
		var row := HBoxContainer.new()
		team_content.add_child(row)
		var label := Label.new()
		label.text = "BLUE" if team == 0 else "RED"
		label.custom_minimum_size.x = 64
		label.modulate = Color(0.4, 0.7, 1) if team == 0 else Color(1, 0.45, 0.5)
		row.add_child(label)
		var count := SpinBox.new()
		count.min_value = 1
		count.max_value = 5
		count.value = 1
		count.custom_minimum_size.x = 85
		count.value_changed.connect(func(value: float): counts[team] = int(value); _reset())
		row.add_child(count)
		count_fields.append(count)
		for slot in range(5):
			var select := OptionButton.new()
			select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			select.add_theme_font_size_override("font_size", 14)
			for archetype in ARCHETYPES: select.add_item("%d · %s" % [slot + 1, archetype.display_name])
			select.select(slot if team == 0 else (4 if slot == 0 else slot - 1))
			select.item_selected.connect(func(index: int): stored_sources[team * 5 + slot] = ARCHETYPES[index].duplicate(true); _reset())
			row.add_child(select)
			archetype_fields.append(select)
	battle_label = Label.new()
	battle_label.position = Vector2(24, 198)
	battle_label.size = Vector2(1024, 28)
	battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(battle_label)
	right_tabs = TabContainer.new()
	right_tabs.position = Vector2(1070, 218)
	right_tabs.size = Vector2(506, 584)
	layer.add_child(right_tabs)
	unit_editor = ScrollContainer.new()
	unit_editor.set_script(preload("res://scripts/ui/unit_editor.gd"))
	unit_editor.name = "Stats"
	unit_editor.source_changed.connect(_reset)
	unit_editor.unit_selected.connect(_select_index)
	right_tabs.add_child(unit_editor)
	equipment_panel = PanelContainer.new()
	equipment_panel.set_script(preload("res://scripts/ui/equipment_panel.gd"))
	equipment_panel.name = "Equipment"
	equipment_panel.loadout_changed.connect(_reset)
	equipment_panel.unit_selected.connect(_select_index)
	right_tabs.add_child(equipment_panel)
	log_panel = TextEdit.new()
	log_panel.name = "Log"
	log_panel.editable = false
	log_panel.add_theme_font_size_override("font_size", 14)
	log_panel.add_theme_color_override("font_readonly_color", Color(0.88, 0.91, 0.95))
	right_tabs.add_child(log_panel)
	results_panel = TextEdit.new()
	results_panel.name = "Results"
	results_panel.editable = false
	results_panel.add_theme_font_size_override("font_size", 14)
	results_panel.add_theme_color_override("font_readonly_color", Color(0.88, 0.91, 0.95))
	right_tabs.add_child(results_panel)
	var controls := _panel(layer, Vector2(24, 814), Vector2(1552, 64))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	controls.add_child(row)
	run_button = _button(row, "Start", _toggle_running)
	step_button = _button(row, "Step +1", _step)
	_button(row, "Reset", _reset)
	var speed_select := OptionButton.new()
	for value in SimulationClock.SPEEDS: speed_select.add_item("%sx" % value)
	speed_select.select(1)
	speed_select.item_selected.connect(func(index: int): clock.set_speed(SimulationClock.SPEEDS[index]))
	row.add_child(speed_select)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	row.add_child(seed_label)
	seed_field = SpinBox.new()
	seed_field.max_value = 2147483647
	seed_field.value = 1
	seed_field.custom_minimum_size.x = 110
	row.add_child(seed_field)
	effect_target = OptionButton.new()
	effect_target.custom_minimum_size.x = 116
	row.add_child(effect_target)
	effect_target.tooltip_text = "Debug effect target. Commands apply on the next tick."
	effect_buttons.append(_button(row, "Stun 4 s", func(): _queue_effect(StatusEffect.Kind.STUN, 4, 0)))
	effect_buttons.append(_button(row, "Slow 40% / 5 s", func(): _queue_effect(StatusEffect.Kind.SLOW, 5, 0.4), 128))
	effect_buttons.append(_button(row, "Armor -15 / 6 s", func(): _queue_effect(StatusEffect.Kind.ARMOR_REDUCTION, 6, 15), 134))
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 14)
	row.add_child(status_label)

func _reset() -> void:
	clock.reset()
	_reset_combat()
	_refresh_ui()

func _reset_combat() -> void:
	var entries: Array[Dictionary] = []
	sources.clear()
	loadouts.clear()
	for team in range(2):
		for slot in range(5):
			archetype_fields[team * 5 + slot].disabled = slot >= counts[team]
			if slot >= counts[team]: continue
			var source := stored_sources[team * 5 + slot]
			var loadout := stored_loadouts[team * 5 + slot]
			sources.append(source)
			loadouts.append(loadout)
			var spawn := Vector2(350 if team == 0 else 1250, 450 + (slot - (counts[team] - 1) / 2.0) * 130)
			entries.append({"id": "%s_%02d" % ["blue" if team == 0 else "red", slot + 1], "team": team, "source": source, "position": spawn, "equipment": loadout.items(), "ai": true})
	combat.reset_scenario(entries, int(seed_field.value))
	var active_ids: Array[String] = []
	for unit in combat.units: active_ids.append(unit.unit_id)
	for id in views.keys():
		if id not in active_ids:
			views[id].free()
			views.erase(id)
	for index in range(combat.units.size()):
		var unit := combat.units[index]
		var view: Node2D
		if views.has(unit.unit_id): view = views[unit.unit_id]
		else:
			var name_value := "BlueUnit" if unit.unit_id == "blue_01" else ("RedUnit" if unit.unit_id == "red_01" else unit.unit_id)
			view = $Arena.get_node_or_null(name_value)
			if view == null:
				view = preload("res://scenes/units/combat_unit.tscn").instantiate()
				view.name = name_value
				$Arena.add_child(view)
			view.unit_selected.connect(_select_id)
			views[unit.unit_id] = view
		var visual := UnitVisualData.new()
		visual.unit_id = unit.unit_id
		var short_name: String = {"Physical Tank": "P Tank", "Magic Tank": "M Tank", "Melee Carry": "Melee", "Ranged Carry": "Ranged", "Mage": "Mage"}.get(unit.display_name, unit.display_name)
		visual.display_name = "%s%d · %s" % ["B" if unit.team_id == 0 else "R", int(unit.unit_id.right(2)), short_name]
		visual.team_color = Color(0.22, 0.58, 0.95) if unit.team_id == 0 else Color(0.94, 0.32, 0.36)
		view.visual_data = visual
		view.combat_data = sources[index]
		view.runtime = unit
		view.position = unit.position
		view.damage_flash = 0.0
		view.hit_notice = ""
	if selected_id not in active_ids: selected_id = active_ids[0]
	var selection := active_ids.find(selected_id)
	unit_editor.bind_sources(sources, combat.units, selection)
	equipment_panel.bind_units(combat.units, loadouts, selection)
	_select_index(selection)
	effect_target.clear()
	for team in [1, 0]:
		for unit in combat.units:
			if unit.team_id == team:
				effect_target.add_item(unit.unit_id)
				effect_target.set_item_metadata(effect_target.item_count - 1, unit.unit_id)
	log_lines.clear()
	log_panel.text = "Ready. Start or Step to run simulation."
	results_panel.text = "Run battle to view per-unit results."
	battle_label.text = "%dv%d · Seed %d · Click a unit to inspect" % [counts[0], counts[1], combat.random_seed]

func _select_id(id: String) -> void:
	for index in range(combat.units.size()):
		if combat.units[index].unit_id == id: _select_index(index); return

func _select_index(index: int) -> void:
	if index < 0 or index >= combat.units.size(): return
	selected_id = combat.units[index].unit_id
	unit_editor.unit_select.select(index)
	unit_editor.refresh()
	equipment_panel.unit_select.select(index)
	equipment_panel.refresh()
	for id in views: views[id].selected = id == selected_id

func _toggle_running() -> void:
	if not combat.finished: clock.set_running(not clock.running)
	_refresh_ui()

func _step() -> void:
	clock.step()
	_refresh_ui()

func _queue_effect(kind: StatusEffect.Kind, duration: float, magnitude: float) -> void:
	if not combat.finished:
		combat.queue_effect("debug", effect_target.get_item_metadata(effect_target.selected), kind, duration, magnitude, "debug_%d" % kind)

func _on_tick(_tick_index: int) -> void:
	var events := combat.step()
	var totals: Dictionary = {}
	var criticals: Dictionary = {}
	for event in events:
		if event.kind == "damage":
			totals[event.target_unit_id] = totals.get(event.target_unit_id, 0.0) + event.applied_damage
			if event.critical: criticals[event.target_unit_id] = true
		elif event.kind == "miss" and views.has(event.target_unit_id): views[event.target_unit_id].show_miss()
		_log_event(event)
	for id in totals: views[id].show_damage(totals[id], criticals.has(id))
	log_panel.text = "\n".join(log_lines)
	log_panel.set_v_scroll(log_panel.get_line_count())
	unit_editor.refresh_stats()
	equipment_panel.refresh_stats()
	if combat.finished:
		clock.set_running(false)
		var result := "Draw" if combat.winner_team < 0 else ("Blue wins" if combat.winner_team == 0 else "Red wins")
		battle_label.text = "%s · %.3f s · %s" % [result, clock.elapsed_seconds(), combat.finish_reason]
		_show_results()
		right_tabs.current_tab = 3

func _log_event(event: Dictionary) -> void:
	var text := "%s → %s" % [event.source_unit_id, event.target_unit_id]
	match event.kind:
		"attack": text += " attack" + (" CRIT" if event.critical else "")
		"miss": text += " MISS"
		"damage": text += " %s damage %.2f" % [["physical", "magic", "pure"][event.damage_type], event.applied_damage]
		"cast": text += " casts %s (mana %.0f)" % [event.ability_name, event.mana_cost]
		"cast_interrupted": text += " cast interrupted"
		"effect_applied": text += " %s %.2fs" % [["stun", "slow", "armor reduction", "attack range", "cast range"][event.effect_kind], event.duration_ticks * SimulationClock.TICK_SECONDS]
		"effect_expired": text = "%s recovered from %s" % [event.target_unit_id, ["stun", "slow", "armor reduction", "attack range", "cast range"][event.effect_kind]]
		"projectile_launched", "projectile_impact", "projectile_evaded", "projectile_canceled": text += " " + event.kind + " #" + str(event.get("projectile_id", ""))
		"death": text = "%s died" % event.target_unit_id
		"finished": text = "Battle finished · %s" % event.reason
	log_lines.append("%07.3f  %s" % [event.tick * SimulationClock.TICK_SECONDS, text])
	if log_lines.size() > 300: log_lines.pop_front()

func _show_results() -> void:
	var result := combat.result()
	var output := "RESULT · %s · %.3f s\nReason: %s · Seed %d\n\n" % ["Draw" if result.winner_team < 0 else ("Blue wins" if result.winner_team == 0 else "Red wins"), result.duration, result.reason, combat.random_seed]
	for id in result.units:
		var m: Dictionary = result.units[id]
		output += "%s · %s\nDamage dealt %.2f / received %.2f\nPhysical %.2f · Magic %.2f · Pure %.2f\nMisses %d · Critical attacks %d\nStun applied %.3fs / time stunned %.3fs\nHealing %.2f · Survival %.3fs\n\n" % [id, m.name, m.damage_dealt, m.damage_received, m.physical_damage, m.magic_damage, m.pure_damage, m.missed_attacks, m.critical_strikes, m.stun_duration_applied, m.time_stunned, m.healing_received, m.survival_time]
	results_panel.text = output

func _refresh_ui() -> void:
	run_button.text = "Pause" if clock.running else ("Resume" if clock.tick_count > 0 else "Start")
	run_button.disabled = combat.finished
	step_button.disabled = clock.running or combat.finished
	for button in effect_buttons: button.disabled = combat.finished
	status_label.text = "%s | %.3fs | Tick %d | 30 Hz" % ["RUN" if clock.running else "PAUSED", clock.elapsed_seconds(), clock.tick_count]
