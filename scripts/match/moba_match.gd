extends Node2D
## Local playable match. The existing engine alone resolves damage/projectiles.
@export var layout: MapLayout
@export var settings: MatchSettings
var combat := CombatEngine.new(preload("res://data/balance/default_balance.tres"))
var clock := SimulationClock.new()
var entities: Dictionary = {}
var navigation_cache: Dictionary = {}
var player: MapUnit
var enemy_hero: MapUnit
var cores: Array[MapUnit] = []
var camera: Camera2D
var controls: Control
var hud: Label
var message: Label
var result_panel: PanelContainer
var result_label: Label
var minimap: Control
var attack_mode: String = ""
var locked_target: String = ""
var wave_number: int = 0
var next_wave_tick: int = 1
var respawns: Dictionary = {}
var scores: Array[int] = [0, 0]
var creep_kills: int = 0
var paused: bool = false
var match_over: bool = false
var progression: Dictionary = {}
var shop: PanelContainer
var opponent_panel: PanelContainer
var rewards: MatchRewards
var death_gold_losses: Dictionary = {}
var draft_mode: bool = false
var bot_build_index: int = 0

func _enter_tree() -> void:
	$World.layout = layout
	$World.towers_overlay = false
	$World.spawns_overlay = false

func _ready() -> void:
	camera = $Camera
	camera.map_size = layout.world_size()
	combat.external_control = true
	rewards = MatchRewards.new(settings)
	combat.reset_scenario([
		_entry("player", 0, settings.hero, layout.spawn_points(0)[0]),
		_entry("enemy_hero", 1, settings.hero, layout.spawn_points(1)[0]),
	], 777)
	if settings.hero_profiles.is_empty(): settings.hero_profiles.append(HeroGrowth.new())
	var profile_index := clampi(HeroProgression.selected_profile, 0, settings.hero_profiles.size() - 1)
	progression.player = HeroProgression.new(combat.get_unit("player"), settings.hero, settings.hero_profiles[profile_index], settings, combat.balance)
	progression.enemy_hero = HeroProgression.new(combat.get_unit("enemy_hero"), settings.hero, settings.hero_profiles[0], settings, combat.balance)
	progression.player.select_passive(HeroProgression.selected_passive)
	progression.enemy_hero.select_passive(4)
	player = _attach(combat.get_unit("player"), settings.hero, "hero", "MID")
	enemy_hero = _attach(combat.get_unit("enemy_hero"), settings.hero, "hero", "MID")
	player.view.selected = true
	player.view.visual_data.display_name = "BẠN · " + progression.player.profile.display_name
	camera.follow_target = player
	camera.follow_enabled = true
	camera.position = player.position
	camera.set_zoom_level(0.65)
	for team in range(2):
		var point := layout.cell_center(Vector2i(4, 35) if team == 0 else Vector2i(35, 4))
		cores.append(_spawn("core_%d" % team, team, settings.core, point, "core"))
	for index in range(layout.tower_cells.size()):
		var cell: Vector2 = layout.tower_cells[index]
		var team := 0 if cell.y > cell.x else 1
		_spawn("tower_%02d" % index, team, settings.tower, layout.cell_center(Vector2i(cell)), "tower")
	var fountain_view := Node2D.new()
	fountain_view.set_script(preload("res://scripts/match/fountain_view.gd"))
	fountain_view.layout = layout
	fountain_view.settings = settings
	add_child(fountain_view)
	move_child(fountain_view, 2) # Above terrain, below unit views.
	var projectile_view := Node2D.new()
	projectile_view.set_script(preload("res://scripts/ui/projectile_view.gd"))
	projectile_view.combat = combat
	projectile_view.z_index = 100
	add_child(projectile_view)
	_build_ui()
	clock.ticked.connect(_tick)
	clock.set_running(true)
	if settings.show_draft_on_start and not HeroProgression.draft_confirmed:
		_start_draft()
	elif HeroProgression.draft_confirmed:
		HeroProgression.draft_confirmed = false
	_refresh_hud()

func _start_draft() -> void:
	draft_mode = true
	shop.show()
	shop.set_draft_mode(true)
	set_paused(true)
	message.text = "CHỌN HERO + NỘI TẠI KHỞI ĐẦU"

func _entry(id: String, team: int, source: UnitStats, point: Vector2) -> Dictionary:
	return {"id": id, "team": team, "source": source, "position": point, "ai": false}

func _navigation(radius: float) -> MapNavigation:
	if not navigation_cache.has(radius): navigation_cache[radius] = MapNavigation.new(layout, radius)
	return navigation_cache[radius]

func _attach(state: UnitRuntimeState, source: UnitStats, kind: String, lane: String, siege: bool = false, ranged_creep: bool = false) -> MapUnit:
	state.is_structure = kind in ["tower", "core"]
	state.structure_damage_multiplier = settings.hero_structure_damage_multiplier if kind == "hero" else (settings.creep_structure_damage_multiplier if kind == "creep" else 1.0)
	if siege: state.structure_damage_multiplier = settings.siege_structure_damage_multiplier
	if kind == "tower": lane = _nearest_lane(state.position)
	var actor := MapUnit.new()
	actor.configure(source, state.team_id, state.position, layout, _navigation(state.stats.collision_radius), state)
	actor.view.visual_data.unit_id = state.unit_id
	actor.view.visual_data.display_name = "BẠN" if state.unit_id == "player" else ("BOT ĐỎ" if kind == "hero" else {"creep": "LÍNH", "tower": "TRỤ", "core": "NHÀ CHÍNH"}[kind])
	actor.view.show_resource_bars = true
	actor.view.compact_visual = kind == "creep"
	actor.view.siege_visual = siege
	actor.view.structure_visual = kind in ["tower", "core"]
	actor.paused = kind in ["tower", "core"]
	actor.view.unit_selected.connect(_clicked_entity)
	add_child(actor)
	var route := PackedVector2Array()
	if kind in ["creep", "hero"] and state.unit_id != "player": route = actor.navigation.lane_path(actor.position, lane, state.team_id)
	entities[state.unit_id] = {"actor": actor, "kind": kind, "lane": lane, "route": route, "route_index": 0, "siege": siege, "ranged_creep": ranged_creep}
	return actor

func _nearest_lane(point: Vector2) -> String:
	var closest := INF
	var result := "MID"
	for lane in ["TOP", "MID", "BOT"]:
		var route := layout.route(lane, 0)
		for index in range(1, route.size()):
			var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, route[index - 1], route[index]))
			if distance < closest: closest = distance; result = lane
	return result

func _spawn(id: String, team: int, source: UnitStats, point: Vector2, kind: String, lane: String = "", siege: bool = false, ranged_creep: bool = false) -> MapUnit:
	var state := combat.add_unit(_entry(id, team, source, point))
	return _attach(state, source, kind, lane, siege, ranged_creep)

func spawn_wave() -> void:
	var live := 0
	for info in entities.values():
		if info.kind == "creep" and info.actor.runtime.alive: live += 1
	var has_siege := settings.siege_creep != null and settings.siege_wave_interval > 0 and wave_number % settings.siege_wave_interval == 0
	var per_lane := settings.creeps_per_lane + (1 if has_siege else 0)
	if live + per_lane * 6 > settings.maximum_live_creeps: return
	wave_number += 1
	for team in range(2):
		for lane in ["TOP", "MID", "BOT"]:
			for slot in range(per_lane):
				var siege := has_siege and slot == settings.creeps_per_lane
				var ranged_creep := not siege and slot == settings.creeps_per_lane - 1
				var source := settings.ranged_creep if ranged_creep else settings.melee_creep
				if siege: source = settings.siege_creep
				var point := layout.spawn_points(team)[0] + Vector2((slot - 1) * 45, 35 if lane == "TOP" else (-35 if lane == "BOT" else 0))
				_spawn("creep_%d_%d_%s_%d" % [wave_number, team, lane, slot], team, source, point, "creep", lane, siege, ranged_creep)

func _physics_process(delta: float) -> void:
	if player == null: return
	var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var movement: Vector2 = (keyboard + controls.direction).limit_length(1) if not paused and not match_over and not shop.visible and not opponent_panel.visible else Vector2.ZERO
	player.manual_direction = movement
	if not movement.is_zero_approx():
		attack_mode = ""
		locked_target = ""
		player.runtime.target_id = ""
	clock.advance(delta)
	_refresh_hud()

func _tick(_index: int) -> void:
	if match_over: return
	var tick := combat.tick_count + 1
	var income_interval := maxi(1, ceili(settings.passive_gold_interval_seconds * SimulationClock.TICKS_PER_SECOND))
	if tick % income_interval == 0:
		for hero in progression.values(): hero.award(0, settings.passive_gold_amount)
	if tick % 300 == 0:
		var bot: HeroProgression = progression.enemy_hero
		var order := ["boots", "swift_gloves", "heavy_sword", "ogre_axe", "critical_blade", "heavy_sword", "skull_basher"]
		if bot_build_index < order.size():
			var item := MatchItemCatalog.by_id(order[bot_build_index])
			if item != null and bot.buy(item): bot_build_index += 1
	if tick >= next_wave_tick:
		spawn_wave()
		next_wave_tick = tick + maxi(1, ceili(settings.wave_interval * SimulationClock.TICKS_PER_SECOND))
	for id in respawns.keys():
		if tick >= respawns[id]:
			_revive(id)
			respawns.erase(id)
	for id in entities.keys():
		var info: Dictionary = entities[id]
		var actor: MapUnit = info.actor
		if not actor.runtime.alive: continue
		if id == "player":
			if not attack_mode.is_empty(): _drive_target(info, _player_target(), tick)
			else: actor.runtime.target_id = ""
		elif info.kind in ["tower", "core"]:
			var target := _choose_target(info, ["creep", "hero"], actor.runtime.attack_range())
			actor.runtime.target_id = target.runtime.unit_id if target != null else ""
		else:
			var categories: Array = ["hero", "creep", "tower", "core"] if info.kind == "hero" else ["creep", "hero", "tower", "core"]
			var target := _choose_target(info, categories, settings.aggro_range)
			_drive_target(info, target, tick)
	_heal_fountains()
	var events := combat.step()
	for event in events:
		if event.kind == "damage" and entities.has(event.target_unit_id):
			entities[event.target_unit_id].actor.view.show_damage(event.applied_damage, event.critical)
			if event.applied_damage > 0: rewards.record_damage(event.target_unit_id, event.source_unit_id, combat.tick_count, progression)
		elif event.kind == "death": _on_death(event.target_unit_id, events)
	for id in entities.keys():
		if entities[id].kind == "creep" and not entities[id].actor.runtime.alive:
			var actor: MapUnit = entities[id].actor
			combat.units.erase(actor.runtime)
			actor.queue_free()
			entities.erase(id)
	$World.units.assign(_actors())
	for team in range(2):
		if not cores[team].runtime.alive:
			_end_match(1 - team)
			break

func in_fountain(unit: UnitRuntimeState) -> bool:
	return unit.alive and unit.position.distance_to(layout.spawn_points(unit.team_id)[0]) <= settings.fountain_radius

func _heal_fountains() -> void:
	for hero in progression.values():
		var unit: UnitRuntimeState = hero.unit
		if not in_fountain(unit): continue
		var before := unit.current_hp
		unit.current_hp = minf(unit.stats.max_hp, unit.current_hp + unit.stats.max_hp * settings.fountain_hp_fraction_per_second * SimulationClock.TICK_SECONDS)
		unit.current_mana = minf(unit.stats.max_mana, unit.current_mana + unit.stats.max_mana * settings.fountain_mana_fraction_per_second * SimulationClock.TICK_SECONDS)
		combat.metrics.by_unit[unit.unit_id].healing_received += unit.current_hp - before

func _actors() -> Array[MapUnit]:
	var result: Array[MapUnit] = []
	for info in entities.values(): result.append(info.actor)
	return result

func _visible(source: MapUnit, target: MapUnit) -> bool:
	var query := PhysicsRayQueryParameters2D.create(source.position, target.position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _choose_target(info: Dictionary, categories: Array, radius: float, allow_approach: bool = false) -> MapUnit:
	var source: MapUnit = info.actor
	var best: MapUnit
	var best_priority := 100
	var best_distance := INF
	for candidate in entities.values():
		var target: MapUnit = candidate.actor
		if not target.runtime.alive or target.runtime.team_id == source.runtime.team_id or candidate.kind not in categories: continue
		if info.kind == "creep" and candidate.kind in ["creep", "tower"] and candidate.lane != info.lane: continue
		var distance := source.runtime.distance_to_unit(target.runtime)
		var priority := categories.find(candidate.kind)
		if distance > radius or priority > best_priority or (priority == best_priority and distance >= best_distance): continue
		if not _visible(source, target):
			if not allow_approach or source.navigation.path(source.position, target.position).is_empty(): continue
		best = target
		best_priority = priority
		best_distance = distance
	return best

func _player_target() -> MapUnit:
	if entities.has(locked_target):
		var target: MapUnit = entities[locked_target].actor
		if target.runtime.alive and target.runtime.team_id != player.runtime.team_id and player.runtime.distance_to_unit(target.runtime) <= settings.hero_acquisition_range: return target
	locked_target = ""
	var categories: Array = ["hero"] if attack_mode == "hero" else ["creep", "tower", "core"]
	return _choose_target(entities.player, categories, settings.hero_acquisition_range, true)

func _drive_target(info: Dictionary, target: MapUnit, tick: int) -> void:
	var actor: MapUnit = info.actor
	if target != null and (not target.runtime.alive or target.runtime.team_id == actor.runtime.team_id): target = null
	actor.runtime.target_id = target.runtime.unit_id if target != null and _visible(actor, target) else ""
	if target != null:
		if actor.runtime.distance_to_unit(target.runtime) <= actor.runtime.attack_range() and _visible(actor, target):
			actor.stop()
		elif tick % 10 == 1 or actor.path.is_empty(): actor.go_to(target.position)
	elif info.actor != player:
		var route: PackedVector2Array = info.route
		# After chasing, resume at the nearest forward point through A*, never
		# shortcut directly across jungle terrain to a stale lane point.
		if info.get("chasing", false):
			var closest := INF
			for index in range(info.route_index, route.size()):
				var distance := actor.position.distance_to(route[index])
				if distance < closest: closest = distance; info.route_index = index
		info.chasing = false
		while info.route_index < route.size() and actor.position.distance_to(route[info.route_index]) < 8: info.route_index += 1
		if info.route_index < route.size():
			var waypoint := route[info.route_index]
			if actor.path.is_empty() or actor.path[-1].distance_to(waypoint) > 0.1: actor.go_to(waypoint)
	else: actor.stop()
	if target != null: info.chasing = true

func request_attack(category: String) -> void:
	if match_over or paused or shop.visible or opponent_panel.visible or not player.runtime.alive: return
	attack_mode = category
	locked_target = ""
	camera.follow_enabled = true
	message.text = "Tự đánh hero · di chuyển để hủy" if category == "hero" else "Tự đánh lính / trụ · di chuyển để hủy"

func _clicked_entity(id: String) -> void:
	if not entities.has(id): return
	if entities[id].actor.runtime.team_id == player.runtime.team_id:
		message.text = "Mục tiêu đồng minh · chỉ có thể đánh lính/tướng địch"
		return
	request_attack("hero" if entities[id].kind == "hero" else "creep")
	locked_target = id

func _on_death(id: String, events: Array[Dictionary]) -> void:
	if not entities.has(id): return
	var info: Dictionary = entities[id]
	var killer := ""
	for event in events:
		if event.kind == "damage" and event.target_unit_id == id and event.applied_damage > 0: killer = event.source_unit_id
	var credited_killer := killer
	if info.kind == "hero":
		var killer_state := combat.get_unit(killer)
		var killer_team: int = killer_state.team_id if killer_state != null else 1 - info.actor.runtime.team_id
		credited_killer = rewards.hero_kill_credit(info.actor.runtime, killer, killer_team, combat.tick_count, progression)
	_reward_death(info, killer)
	rewards.forget(id)
	if info.kind == "hero":
		var hero: HeroProgression = progression[id]
		death_gold_losses[id] = hero.lose_death_gold()
		scores[1 - info.actor.runtime.team_id] += 1
		respawns[id] = combat.tick_count + maxi(1, ceili(settings.respawn_duration(hero.level) * SimulationClock.TICKS_PER_SECOND))
		info.actor.stop()
		if id == "player": attack_mode = ""; locked_target = ""
	elif info.kind == "creep" and killer == "player": creep_kills += 1
	if progression.has(credited_killer): progression[credited_killer].record_kill(info.kind)

func _reward_death(info: Dictionary, killer: String) -> void:
	var victim: MapUnit = info.actor
	var killer_state := combat.get_unit(killer)
	# Projectiles can outlive a removed creep. This two-team match can still
	# identify the hostile team without retaining freed scene nodes.
	var killer_team: int = killer_state.team_id if killer_state != null else 1 - victim.runtime.team_id
	var level: int = progression[victim.runtime.unit_id].level if progression.has(victim.runtime.unit_id) else 1
	var payouts := rewards.calculate(victim.runtime, info.kind, killer, killer_team, level, combat.tick_count, progression, info.get("siege", false), info.get("ranged_creep", false))
	for hero_id in payouts:
		var hero: HeroProgression = progression[hero_id]
		var levels := hero.award(payouts[hero_id].xp, payouts[hero_id].gold)
		if levels > 0 and hero_id == "player": message.text = "LÊN CẤP %d! · %s" % [hero.level, hero.profile.display_name]

func buy_item(item: EquipmentData) -> bool:
	if match_over: return false
	var hero: HeroProgression = progression.player
	var reason := hero.purchase_error(item)
	var success := hero.buy(item) if reason.is_empty() else false
	shop.feedback.text = "Đã mua " + item.display_name if success else reason
	shop.refresh()
	_refresh_hud()
	return success

func sell_item(slot: int) -> bool:
	if match_over: return false
	var success: bool = progression.player.sell(slot)
	shop.feedback.text = "Đã bán trang bị" if success else "Ô trang bị trống"
	shop.refresh()
	_refresh_hud()
	return success

func toggle_shop() -> void:
	if match_over or draft_mode: return
	_stop_player()
	controls.release_all()
	shop.visible = not shop.visible
	opponent_panel.hide()
	shop.refresh()

func toggle_opponents() -> void:
	if draft_mode:
		message.text = "Hãy chọn hero và nội tại trước"
		return
	_stop_player()
	controls.release_all()
	shop.hide()
	opponent_panel.visible = not opponent_panel.visible
	opponent_panel.refresh()

func _revive(id: String) -> void:
	rewards.forget(id)
	var info: Dictionary = entities[id]
	var actor: MapUnit = info.actor
	actor.position = layout.spawn_points(actor.runtime.team_id)[0]
	actor.runtime.position = actor.position
	actor.runtime.alive = true
	actor.runtime.current_hp = actor.runtime.stats.max_hp
	actor.runtime.current_mana = actor.runtime.stats.max_mana
	actor.runtime.effects.active.clear()
	actor.runtime.target_id = ""
	actor.runtime.casting.clear()
	actor.runtime.next_attack_tick = combat.tick_count + 1
	death_gold_losses.erase(id)
	info.route_index = 0
	if id == "player": message.text = "Đã hồi sinh · J đánh lính/trụ, K đánh hero"

func _end_match(winner: int) -> void:
	match_over = true
	clock.set_running(false)
	combat.finished = true
	combat.winner_team = winner
	combat.finish_reason = "base_destroyed"
	for info in entities.values(): info.actor.paused = true
	controls.release_all()
	result_label.text = "CHIẾN THẮNG!" if winner == 0 else "THẤT BẠI"
	result_panel.show()

func set_paused(value: bool) -> void:
	if draft_mode and not value: return
	paused = value
	clock.set_running(not value and not match_over)
	for info in entities.values(): info.actor.paused = value or info.kind in ["tower", "core"] or match_over
	controls.release_all()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(520, 135)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 20)
	content.add_child(hud)
	message = Label.new()
	message.text = "WASD / mũi tên / 4 nút: di chuyển · J/K: đánh"
	message.add_theme_font_size_override("font_size", 15)
	content.add_child(message)
	var row := HBoxContainer.new()
	content.add_child(row)
	_button(row, "Theo hero [F]", func(): camera.follow_enabled = true)
	_button(row, "Ra MID", func(): attack_mode = ""; player.go_to(layout.cell_center(Vector2i(17, 22))))
	_button(row, "Dừng [Space]", _stop_player)
	_button(row, "Tạm dừng [P]", func(): set_paused(not paused))
	row = HBoxContainer.new()
	content.add_child(row)
	_button(row, "Chơi lại", func(): get_tree().reload_current_scene())
	_button(row, "Map Prototype", func(): get_tree().change_scene_to_file("res://scenes/map/map_prototype.tscn"))
	_button(row, "Combat Sandbox", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_button(row, "Shop / Hero [B]", toggle_shop)
	row = HBoxContainer.new()
	content.add_child(row)
	_button(row, "Trang bị hai đội [Tab]", toggle_opponents)
	controls = Control.new()
	controls.set_script(preload("res://scripts/match/battle_controls.gd"))
	controls.position = Vector2(0, 720)
	controls.size = Vector2(1600, 170)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.attack_requested.connect(request_attack)
	layer.add_child(controls)
	minimap = Control.new()
	minimap.set_script(preload("res://scripts/match/match_minimap.gd"))
	minimap.position = Vector2(1365, 18)
	minimap.size = Vector2(215, 215)
	minimap.layout = layout
	minimap.entities = entities
	minimap.map_clicked.connect(func(point: Vector2): camera.follow_enabled = false; camera.position = point; camera.clamp_to_map())
	layer.add_child(minimap)
	shop = PanelContainer.new()
	shop.set_script(preload("res://scripts/match/match_shop.gd"))
	shop.progression = progression.player
	shop.position = Vector2(200, 95)
	shop.size = Vector2(1200, 710)
	shop.buy_requested.connect(buy_item)
	shop.sell_requested.connect(sell_item)
	shop.passive_upgrade_requested.connect(func():
		if progression.player.upgrade_passive(): shop.feedback.text = "Đã nâng nội tại lên cấp %d" % progression.player.passive_level
		else: shop.feedback.text = "Không có điểm hoặc nội tại đã tối đa"
		shop.refresh()
	)
	shop.hero_requested.connect(func(index: int): HeroProgression.selected_profile = index; get_tree().reload_current_scene())
	layer.add_child(shop)
	opponent_panel = PanelContainer.new()
	opponent_panel.set_script(preload("res://scripts/match/opponent_panel.gd"))
	opponent_panel.position = Vector2(300, 250)
	opponent_panel.size = Vector2(1000, 360)
	opponent_panel.heroes = progression
	layer.add_child(opponent_panel)
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(530, 330)
	result_panel.size = Vector2(540, 220)
	layer.add_child(result_panel)
	content = VBoxContainer.new()
	result_panel.add_child(content)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 40)
	content.add_child(result_label)
	_button(content, "Chơi trận mới", func(): get_tree().reload_current_scene())
	result_panel.hide()

func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)

func _stop_player() -> void:
	attack_mode = ""
	locked_target = ""
	player.stop()
	player.runtime.target_id = ""

func _refresh_hud() -> void:
	if hud == null: return
	var state := player.runtime
	var respawn: float = maxf(0, respawns.get("player", combat.tick_count) - combat.tick_count) * SimulationClock.TICK_SECONDS
	hud.text = "CLASHBORN · %02d:%02d · BLUE %d : %d RED\nHP %.0f / %.0f · Lính hạ: %d · Đợt lính: %d" % [combat.tick_count / 1800, (combat.tick_count / 30) % 60, scores[0], scores[1], state.current_hp, state.stats.max_hp, creep_kills, wave_number]
	var hero: HeroProgression = progression.player
	hud.text += "\n%s · LV %d · XP %d/%d · Vàng %d [B]" % [hero.profile.display_name, hero.level, hero.experience, hero.required_xp(), hero.gold]
	if in_fountain(state): hud.text += " · FOUNTAIN +HP/MANA"
	if shop.visible: shop.refresh()
	if opponent_panel.visible: opponent_panel.refresh()
	if not state.alive: message.text = "Hồi sinh sau %.1f giây · Mất %d vàng" % [respawn, death_gold_losses.get("player", 0)]
	elif paused: message.text = "TẠM DỪNG · nhấn P để tiếp tục"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_J: request_attack("creep")
			KEY_K: request_attack("hero")
			KEY_SPACE: _stop_player()
			KEY_P: set_paused(not paused) if not draft_mode else message.set_text("Hãy chọn hero và nội tại trước")
			KEY_F: camera.follow_enabled = true
			KEY_B: toggle_shop()
			KEY_TAB: toggle_opponents()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and player.runtime.alive and not paused and not match_over and not shop.visible and not opponent_panel.visible:
		_stop_player()
		player.go_to(get_global_transform_with_canvas().affine_inverse() * event.position)
