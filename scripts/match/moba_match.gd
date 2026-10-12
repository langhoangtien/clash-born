extends Node2D
## Local playable match. The existing engine alone resolves damage/projectiles.
const MatchAudioRouterScript = preload("res://scripts/match/match_audio_router.gd")
@export var layout: MapLayout
@export var settings: MatchSettings
var combat := CombatEngine.new(preload("res://data/balance/default_balance.tres"))
var clock := SimulationClock.new()
var entities: Dictionary = {}
var navigation_cache: Dictionary = {}
var lane_route_cache: Dictionary = {}
var player: MapUnit
var enemy_hero: MapUnit
var cores: Array[MapUnit] = []
var camera: Camera2D
var controls: Control
var hud: Label
var quick_stats: Label
var effects_bar: HBoxContainer
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
var jungle_spawned: bool = false
var jungle_camp_respawn_ticks: Dictionary = {}
var lane_creep_ai = preload("res://scripts/match/lane_creep_ai.gd").new()
var enemy_bot_ai = preload("res://scripts/match/enemy_bot_ai.gd").new()
var runtime_profiler = preload("res://scripts/match/match_runtime_profiler.gd").new()
## Combat mode hides hostile units outside the selected hero's vision.
var full_map_mode: bool = false
var ui_elapsed: float = 0.0
var audio_router: Node
var tower_registry: Dictionary = {}
@export_group("AI Debug")
@export var debug_mid_lane_only: bool = false
@export var debug_ai_trace_enabled: bool = false
var ai_debug_events: Array[String] = []
var _last_ai_debug_signature: Dictionary = {}

func _enter_tree() -> void:
	$World.layout = layout
	$World.towers_overlay = false
	$World.spawns_overlay = false

func _ready() -> void:
	camera = $Camera
	camera.map_size = layout.world_size()
	combat.external_control = true
	combat.damage_filter = Callable(self, "_can_apply_match_damage")
	rewards = MatchRewards.new(settings)
	combat.reset_scenario([
		_entry("player", 0, settings.hero, layout.spawn_points(0)[0]),
		_entry("enemy_hero", 1, settings.hero, layout.spawn_points(1)[0]),
	], 777)
	if settings.hero_profiles.is_empty(): settings.hero_profiles.append(HeroGrowth.new())
	var profile_index := clampi(HeroProgression.selected_profile, 0, settings.hero_profiles.size() - 1)
	var enemy_profile_index := clampi(HeroProgression.selected_enemy_profile, 0, settings.hero_profiles.size() - 1)
	progression.player = HeroProgression.new(combat.get_unit("player"), settings.hero, settings.hero_profiles[profile_index], settings, combat.balance)
	progression.enemy_hero = HeroProgression.new(combat.get_unit("enemy_hero"), settings.hero, settings.hero_profiles[enemy_profile_index], settings, combat.balance)
	progression.player.select_profile_skill()
	progression.enemy_hero.select_profile_skill()
	player = _attach(combat.get_unit("player"), settings.hero, "hero", "MID")
	enemy_hero = _attach(combat.get_unit("enemy_hero"), settings.hero, "hero", "MID")
	player.view.selected = true
	player.view.visual_data.display_name = "BẠN · " + progression.player.profile.display_name
	camera.follow_target = player
	camera.follow_enabled = true
	camera.position = player.position
	camera.set_zoom_level(0.65)
	for team in range(2):
		var point := layout.throne_point(team)
		cores.append(_spawn("core_%d" % team, team, settings.core, point, "core"))
	for index in range(layout.tower_cells.size()):
		var cell: Vector2 = layout.tower_cells[index]
		var team := layout.tower_team(index)
		var tower_id := "tower_%02d" % index
		_spawn(tower_id, team, settings.tower, layout.cell_center(Vector2i(cell)), "tower")
		var tower_info: Dictionary = entities[tower_id]
		tower_info.lane = layout.tower_lanes[index]
		tower_info.tower_tier = layout.tower_tiers[index]
		tower_info.semantic_id = layout.tower_ids[index]
		tower_info.prerequisites = layout.tower_prerequisites[index].duplicate()
		_apply_tower_tier_stats(tower_info)
		tower_registry[tower_info.semantic_id] = tower_id
	var registry_errors := structure_registry_errors()
	for error in registry_errors: push_error("STRUCTURE REGISTRY: " + error)
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
	audio_router = MatchAudioRouterScript.new()
	add_child(audio_router)
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
	if quick_stats != null: quick_stats.get_parent().hide()
	shop.show()
	shop.set_draft_mode(true)
	set_paused(true)
	message.text = "CHỌN HERO VÀ KỸ NĂNG RIÊNG"

func _entry(id: String, team: int, source: UnitStats, point: Vector2) -> Dictionary:
	return {"id": id, "team": team, "source": source, "position": point, "ai": false}

func _navigation(radius: float) -> MapNavigation:
	if not navigation_cache.has(radius): navigation_cache[radius] = MapNavigation.new(layout, radius)
	return navigation_cache[radius]

func _lane_route(actor: MapUnit, lane: String) -> PackedVector2Array:
	var key := "%d|%s|%.1f|%.1f|%.1f" % [actor.runtime.team_id, lane, actor.runtime.stats.collision_radius, actor.position.x, actor.position.y]
	if not lane_route_cache.has(key): lane_route_cache[key] = actor.navigation.lane_path(actor.position, lane, actor.runtime.team_id)
	return PackedVector2Array(lane_route_cache[key])

func _attach(state: UnitRuntimeState, source: UnitStats, kind: String, lane: String, siege: bool = false, ranged_creep: bool = false) -> MapUnit:
	state.is_structure = kind in ["tower", "core"]
	state.structure_damage_multiplier = settings.hero_structure_damage_multiplier if kind == "hero" else (settings.creep_structure_damage_multiplier if kind == "creep" else 1.0)
	if siege: state.structure_damage_multiplier = settings.siege_structure_damage_multiplier
	if kind == "tower": lane = _nearest_lane(state.position)
	var actor := MapUnit.new()
	actor.configure(source, state.team_id, state.position, layout, _navigation(state.stats.collision_radius), state)
	actor.view.visual_data.unit_id = state.unit_id
	actor.view.visual_data.display_name = "BẠN" if state.unit_id == "player" else ("BOT ĐỎ" if kind == "hero" else {"creep": "LÍNH", "tower": "TRỤ", "core": "NHÀ CHÍNH"}[kind])
	# Small compact bars keep last-hit health readable without hero-sized labels.
	actor.view.show_resource_bars = true
	actor.view.compact_visual = kind == "creep"
	actor.view.siege_visual = siege
	actor.view.structure_visual = kind in ["tower", "core"]
	actor.paused = kind in ["tower", "core"]
	actor.view.unit_selected.connect(_clicked_entity)
	add_child(actor)
	var route := PackedVector2Array()
	if kind in ["creep", "hero"] and state.unit_id != "player": route = _lane_route(actor, lane)
	var travel_speed_multiplier := 1.22 if state.unit_id == "enemy_hero" else 1.0
	entities[state.unit_id] = {"actor": actor, "kind": kind, "lane": lane, "route": route, "route_index": 0, "siege": siege, "ranged_creep": ranged_creep, "tower_tier": 0, "lane_buffed": false, "assigned_lane": lane, "ai_state": "GO_TO_LANE" if kind == "hero" and state.unit_id != "player" else "", "ai_state_since": 0, "ai_last_target_tick": 0, "travel_speed_multiplier": travel_speed_multiplier, "ai_phase": absi(state.unit_id.hash()) % 3, "creep_state": "LANE", "creep_chase_origin": state.position, "creep_lost_since": -1, "creep_reacquire_after": 0, "creep_unreachable_since": -1, "intent_state": "", "intent_target_id": "", "intent_destination": state.position, "intent_expiry_tick": -1}
	return actor

func get_outer_tower(team: int, lane: String) -> MapUnit:
	var id := "%s_%s_t1" % ["blue" if team == 0 else "red", lane.to_lower()]
	return entities[tower_registry[id]].actor if tower_registry.has(id) and entities.has(tower_registry[id]) else null

func get_lane_defensive_tower(team: int, lane: String) -> MapUnit:
	var side := "blue" if team == 0 else "red"
	for tier in range(1, 4):
		var semantic_id := "%s_%s_t%d" % [side, lane.to_lower(), tier]
		if not tower_registry.has(semantic_id): return null
		var runtime_id: String = tower_registry[semantic_id]
		if entities.has(runtime_id) and entities[runtime_id].actor.runtime.alive: return entities[runtime_id].actor
	return null

func get_next_attackable_structure(attacking_team: int, lane: String) -> MapUnit:
	var owner := 1 - attacking_team
	for tier in range(1, 4):
		var id := "%s_%s_t%d" % ["blue" if owner == 0 else "red", lane.to_lower(), tier]
		if not tower_registry.has(id):
			push_error("Missing required structure registry entry: " + id)
			return null
		var runtime_id: String = tower_registry[id]
		if not entities.has(runtime_id): continue # Explicitly destroyed and cleaned up.
		var info: Dictionary = entities[runtime_id]
		var tower: MapUnit = info.actor
		if not tower.runtime.alive: continue
		if not _tower_is_unlocked(info):
			push_error("Structure chain is inconsistent; next living tower is locked: " + id)
			return null
		return tower
	# T4 guards are shared base structures. They become the next legal target
	# only after all lane T3 prerequisites have fallen; select one deterministically
	# so creeps, heroes and bots use the same structure chain.
	var side := "blue" if owner == 0 else "red"
	for guard in [side + "_base_guard_left", side + "_base_guard_right"]:
		if not tower_registry.has(guard):
			push_error("Missing required throne guard registry entry: " + guard)
			return null
		var guard_runtime_id: String = tower_registry[guard]
		if not entities.has(guard_runtime_id): continue
		var guard_info: Dictionary = entities[guard_runtime_id]
		if guard_info.actor.runtime.alive and _tower_is_unlocked(guard_info): return guard_info.actor
	return null

func _structure_chain_configured(attacking_team: int, lane: String) -> bool:
	var owner := 1 - attacking_team
	for tier in range(1, 4):
		var semantic_id := "%s_%s_t%d" % ["blue" if owner == 0 else "red", lane.to_lower(), tier]
		if not tower_registry.has(semantic_id): return false
	return true

func get_defensive_anchor(team: int, lane: String) -> Vector2:
	var tower := get_lane_defensive_tower(team, lane)
	if tower == null: return layout.spawn_points(team)[0]
	# This is deliberately just behind the outer living defense, not deep enough
	# toward the fountain to overlap the next inner tower.
	return tower.position.lerp(layout.spawn_points(team)[0], settings.bot_tower_anchor_backoff_fraction)

func is_inside_enemy_tower_range(position: Vector2, team: int) -> bool:
	for info in entities.values():
		if info.kind != "tower" or info.actor.runtime.team_id == team or not info.actor.runtime.alive: continue
		if info.actor.position.distance_to(position) <= info.actor.runtime.attack_range() + settings.bot_tower_safety_margin: return true
	return false

func _tower_targeting_unit(actor: MapUnit) -> MapUnit:
	for info in entities.values():
		if info.kind != "tower": continue
		var tower: MapUnit = info.actor
		if tower.runtime.alive and tower.runtime.team_id != actor.runtime.team_id and tower.runtime.target_id == actor.runtime.unit_id:
			return tower
	return null

func _tower_escape_point(actor: MapUnit, tower: MapUnit) -> Vector2:
	var retreat_direction := (layout.spawn_points(actor.runtime.team_id)[0] - tower.position).normalized()
	return tower.position + retreat_direction * (tower.runtime.attack_range() + settings.bot_tower_safety_margin + 120.0)

func _tower_is_unlocked(candidate: Dictionary) -> bool:
	if candidate.kind != "tower": return true
	for prerequisite in candidate.get("prerequisites", PackedStringArray()):
		if not tower_registry.has(prerequisite): return false
		var tower_id: String = tower_registry[prerequisite]
		if entities.has(tower_id) and entities[tower_id].actor.runtime.alive: return false
	return true

func _apply_tower_tier_stats(info: Dictionary) -> void:
	var tower: MapUnit = info.actor
	var tier: int = int(info.get("tower_tier", 1))
	var hp_by_tier := {1: settings.tower_t1_hp, 2: settings.tower_t2_hp, 3: settings.tower_t3_hp, 4: settings.tower_t4_hp}
	var damage_by_tier := {1: settings.tower_t1_damage, 2: settings.tower_t2_damage, 3: settings.tower_t3_damage, 4: settings.tower_t4_damage}
	tower.runtime.stats.max_hp = float(hp_by_tier.get(tier, settings.tower_t1_hp))
	tower.runtime.current_hp = tower.runtime.stats.max_hp
	tower.runtime.stats.physical_damage = float(damage_by_tier.get(tier, settings.tower_t1_damage))

func structure_runtime_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index in range(layout.tower_cells.size()):
		var semantic_id: String = layout.tower_ids[index]
		var runtime_id: String = tower_registry.get(semantic_id, "")
		var info: Dictionary = entities.get(runtime_id, {})
		var actor: MapUnit = info.get("actor")
		rows.append({
			"id": semantic_id,
			"runtime_id": runtime_id,
			"team": layout.tower_teams[index],
			"lane": layout.tower_lanes[index],
			"tier": layout.tower_tiers[index],
			"position": layout.cell_center(Vector2i(layout.tower_cells[index])),
			"prerequisites": layout.tower_prerequisites[index],
			"alive": actor != null and actor.runtime.alive,
			"attackable": not info.is_empty() and actor.runtime.alive and _tower_is_unlocked(info),
		})
	for team in range(2):
		var core: MapUnit = cores[team] if team < cores.size() else null
		rows.append({"id": "core_%d" % team, "runtime_id": "core_%d" % team, "team": team, "lane": "BASE", "tier": 5, "position": layout.throne_point(team), "prerequisites": PackedStringArray(["%s_base_guard_left" % ("blue" if team == 0 else "red"), "%s_base_guard_right" % ("blue" if team == 0 else "red")]), "alive": core != null and core.runtime.alive, "attackable": core != null and core.runtime.alive and _core_is_unlocked(team)})
	return rows

func structure_registry_errors() -> PackedStringArray:
	var errors := layout.validation_errors()
	var expected_ids := {}
	for index in range(layout.tower_cells.size()):
		var semantic_id: String = layout.tower_ids[index]
		expected_ids[semantic_id] = true
		if not tower_registry.has(semantic_id):
			errors.append("Missing runtime registration: " + semantic_id)
			continue
		var runtime_id: String = tower_registry[semantic_id]
		if not entities.has(runtime_id):
			errors.append("Registry points to missing entity: %s -> %s" % [semantic_id, runtime_id])
			continue
		var info: Dictionary = entities[runtime_id]
		var expected_position := layout.cell_center(Vector2i(layout.tower_cells[index]))
		if info.get("semantic_id", "") != semantic_id: errors.append("Runtime ID mismatch: " + semantic_id)
		if info.actor.runtime.team_id != layout.tower_teams[index]: errors.append("Runtime team mismatch: " + semantic_id)
		if info.get("lane", "") != layout.tower_lanes[index]: errors.append("Runtime lane mismatch: " + semantic_id)
		if int(info.get("tower_tier", 0)) != layout.tower_tiers[index]: errors.append("Runtime tier mismatch: " + semantic_id)
		if info.get("prerequisites", PackedStringArray()) != layout.tower_prerequisites[index]: errors.append("Runtime prerequisite mismatch: " + semantic_id)
		if info.actor.position.distance_to(expected_position) > 0.01: errors.append("Runtime position mismatch: " + semantic_id)
	for semantic_id in tower_registry:
		if not expected_ids.has(semantic_id): errors.append("Unexpected runtime registration: " + semantic_id)
	# Tier labels are authored data, but this audit catches an accidental reversal:
	# routes start at the owning base, so T3 < T2 < T1 in route progress.
	for team in range(2):
		for lane in ["TOP", "MID", "BOT"]:
			var progress_by_tier := {}
			for row in structure_runtime_rows():
				if row.team == team and row.lane == lane: progress_by_tier[row.tier] = _lane_progress(row.position, lane, team)
			if progress_by_tier.size() == 3 and not (progress_by_tier[3] < progress_by_tier[2] and progress_by_tier[2] < progress_by_tier[1]):
				errors.append("Reversed tower order: team %d %s (%s)" % [team, lane, str(progress_by_tier)])
	return errors

func _lane_progress(point: Vector2, lane: String, team: int) -> float:
	var route := layout.route(lane, team)
	var accumulated := 0.0
	var best_distance := INF
	var best_progress := 0.0
	for index in range(1, route.size()):
		var segment := route[index] - route[index - 1]
		var length := segment.length()
		if length <= 0.001: continue
		var ratio := clampf((point - route[index - 1]).dot(segment) / (length * length), 0.0, 1.0)
		var projected := route[index - 1] + segment * ratio
		var distance := point.distance_to(projected)
		if distance < best_distance:
			best_distance = distance
			best_progress = accumulated + length * ratio
		accumulated += length
	return best_progress

func _lane_point_at_progress(lane: String, team: int, requested_progress: float) -> Vector2:
	var route := layout.route(lane, team)
	if route.is_empty(): return layout.spawn_points(team)[0]
	var remaining := maxf(0.0, requested_progress)
	for index in range(1, route.size()):
		var start := route[index - 1]
		var segment := route[index] - start
		var length := segment.length()
		if remaining <= length: return start + segment.normalized() * remaining
		remaining -= length
	return route[-1]

func _trace_ai(info: Dictionary, category: String, detail: String) -> void:
	if not debug_ai_trace_enabled: return
	var actor: MapUnit = info.actor
	var key := actor.runtime.unit_id + "|" + category
	if _last_ai_debug_signature.get(key, "") == detail: return
	_last_ai_debug_signature[key] = detail
	var line := "AI[%d] %s %s %s" % [combat.tick_count, actor.runtime.unit_id, category, detail]
	ai_debug_events.append(line)
	print(line)

func _structure_candidate_report(attacking_team: int, lane: String) -> String:
	var owner := 1 - attacking_team
	var parts: PackedStringArray = []
	for tier in range(1, 4):
		var semantic_id := "%s_%s_t%d" % ["blue" if owner == 0 else "red", lane.to_lower(), tier]
		if not tower_registry.has(semantic_id):
			parts.append(semantic_id + ":missing-registry")
			continue
		var runtime_id: String = tower_registry[semantic_id]
		if not entities.has(runtime_id):
			parts.append(semantic_id + ":destroyed")
			continue
		var info: Dictionary = entities[runtime_id]
		parts.append("%s:%s" % [semantic_id, "chosen" if info.actor.runtime.alive and _tower_is_unlocked(info) else ("locked" if info.actor.runtime.alive else "dead")])
	return ",".join(parts)

func _issue_ai_move(info: Dictionary, destination: Vector2, source: String, tick: int) -> bool:
	var actor: MapUnit = info.actor
	if not actor.path.is_empty() and info.get("movement_source", "") == source and Vector2(info.get("movement_destination", Vector2.INF)).distance_to(destination) <= 1.0:
		return true
	var previous_source: String = info.get("movement_source", "")
	runtime_profiler.record_path_request()
	var valid := actor.go_to(destination)
	info.movement_source = source
	info.movement_destination = destination
	info.movement_tick = tick
	# Helper parameters are copied from the entity registry. Store the resulting
	# order now so it is still present when the next simulation tick begins.
	_persist_entity_info(info)
	var state: String = info.get("ai_state", "") if info.kind == "hero" else info.get("creep_state", "")
	if source != "lane-waypoint" or previous_source != source or int(info.get("route_index", 0)) % 5 == 0 or not valid:
		_trace_ai(info, "MOVE", "state=%s lane=%s waypoint=%d source=%s destination=%s navigation=%s" % [state, info.get("assigned_lane", info.get("lane", "")), int(info.get("route_index", 0)), source, str(destination), "ok" if valid else "failed"])
	return valid

func _persist_entity_info(info: Dictionary) -> void:
	# Dictionary arguments are copied by GDScript. AI helpers therefore persist
	# metadata when deciding, rather than relying on a stale outer-loop copy.
	var actor: MapUnit = info.get("actor", null)
	if actor != null and entities.has(actor.runtime.unit_id): entities[actor.runtime.unit_id] = info

func _sync_intent(info: Dictionary, tick: int) -> void:
	# Phase-one intent telemetry mirrors the live order without changing behavior.
	# Later controllers will construct this data before movement is applied.
	var actor: MapUnit = info.actor
	info.intent_state = info.get("ai_state", "") if info.kind == "hero" else info.get("creep_state", "")
	info.intent_target_id = actor.runtime.target_id
	info.intent_destination = info.get("movement_destination", actor.position)
	info.intent_expiry_tick = tick + maxi(1, settings.bot_decision_ticks if info.kind == "hero" else settings.creep_target_scan_ticks)
	_persist_entity_info(info)

func runtime_profile_snapshot() -> Dictionary:
	return runtime_profiler.snapshot()

func _can_apply_match_damage(_damage: Dictionary, _source: UnitRuntimeState, target: UnitRuntimeState) -> bool:
	if target == null or not entities.has(target.unit_id): return true
	var target_info: Dictionary = entities[target.unit_id]
	# Ranged attacks snapshot their damage at launch. The firing creep can be
	# removed before impact, in which case CombatEngine deliberately supplies no
	# live source. Structure locks still apply to the target, but no source-only
	# adjustment may dereference a removed unit.
	var source_info: Dictionary = entities.get(_source.unit_id, {}) if _source != null else {}
	if source_info.get("kind", "") == "tower" and target_info.get("siege", false):
		_damage.final_damage *= settings.tower_damage_to_siege_multiplier
	if target_info.kind == "tower": return _tower_is_unlocked(target_info)
	if target_info.kind == "core": return _core_is_unlocked(target.team_id)
	return true

func _core_is_unlocked(team: int) -> bool:
	# Lane towers gate their T4 guards through authored prerequisites. The core
	# itself is gated only by both guards.
	var side := "blue" if team == 0 else "red"
	for guard in [side + "_base_guard_left", side + "_base_guard_right"]:
		if not tower_registry.has(guard):
			push_error("Missing required throne guard registry entry: " + guard)
			return false
		var runtime_id: String = tower_registry[guard]
		if entities.has(runtime_id) and entities[runtime_id].actor.runtime.alive: return false
	return true

func _lane_push_buff_active(team: int, lane: String) -> bool:
	for info in entities.values():
		if info.kind == "tower" and info.actor.runtime.team_id == team and info.lane == lane and int(info.get("tower_tier", 0)) == 3 and info.actor.runtime.alive: return false
	return true

func _buff_lane_creep(actor: MapUnit, info: Dictionary) -> void:
	if info.get("lane_buffed", false): return
	info.lane_buffed = true
	actor.runtime.stats.max_hp *= 2.0
	actor.runtime.current_hp = actor.runtime.stats.max_hp
	actor.runtime.stats.physical_damage *= 2.0
	actor.runtime.stats.magic_damage *= 2.0
	actor.runtime.stats.pure_damage *= 2.0

func _apply_lane_push_buff(team: int, lane: String) -> void:
	for info in entities.values():
		if info.kind == "creep" and not info.get("neutral", false) and info.lane == lane and info.actor.runtime.team_id == team and info.actor.runtime.alive:
			_buff_lane_creep(info.actor, info)

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
		if info.kind == "creep" and not info.get("neutral", false) and info.actor.runtime.alive: live += 1
	var has_siege := settings.siege_creep != null and settings.siege_wave_interval > 0 and wave_number % settings.siege_wave_interval == 0
	var per_lane := settings.creeps_per_lane + (1 if has_siege else 0)
	if live + per_lane * 6 > settings.maximum_live_creeps: return
	wave_number += 1
	var active_lanes: Array[String] = []
	active_lanes.assign(["MID"] if debug_mid_lane_only else ["TOP", "MID", "BOT"])
	for team in range(2):
		for lane in active_lanes:
			for slot in range(per_lane):
				var siege := has_siege and slot == settings.creeps_per_lane
				var ranged_creep := not siege and slot == settings.creeps_per_lane - 1
				var source := settings.ranged_creep if ranged_creep else settings.melee_creep
				if siege: source = settings.siege_creep
				var point := layout.spawn_points(team)[0] + Vector2((slot - 1) * 45, 35 if lane == "TOP" else (-35 if lane == "BOT" else 0))
				var creep := _spawn("creep_%d_%d_%s_%d" % [wave_number, team, lane, slot], team, source, point, "creep", lane, siege, ranged_creep)
				if _lane_push_buff_active(1 - team, lane): _buff_lane_creep(creep, entities[creep.runtime.unit_id])

func spawn_jungle_camps() -> void:
	for camp_index in range(layout.jungle_camps.size()): spawn_jungle_camp(camp_index)

func spawn_jungle_camp(camp_index: int) -> void:
	var center := layout.cell_center(Vector2i(layout.jungle_camps[camp_index]))
	for slot in range(3):
		var id := "jungle_%02d_%d" % [camp_index, slot]
		if entities.has(id) and entities[id].actor.runtime.alive: continue
		var source := settings.melee_creep if slot < 2 else settings.ranged_creep
		var point := center + Vector2((slot - 1) * 34, -18 if slot % 2 == 0 else 20)
		var actor := _spawn(id, 2, source, point, "creep", "JUNGLE", false, slot == 2)
		actor.view.visual_data.display_name = "QUÁI RỪNG"
		actor.view.visual_data.team_color = Color(0.85, 0.58, 0.18)
		var info: Dictionary = entities[actor.runtime.unit_id]
		info.neutral = true
		info.camp_index = camp_index
		info.camp_center = center
		info.leash_range = 420.0
		info.aggro_target = ""
		info.aggro_expires_tick = 0
		_persist_entity_info(info)

func _schedule_cleared_jungle_camps(tick: int) -> void:
	if not jungle_spawned: return
	for camp_index in range(layout.jungle_camps.size()):
		if jungle_camp_respawn_ticks.has(camp_index): continue
		var camp_alive := false
		for info in entities.values():
			if info.get("neutral", false) and int(info.get("camp_index", -1)) == camp_index and info.actor.runtime.alive:
				camp_alive = true
				break
		if not camp_alive:
			jungle_camp_respawn_ticks[camp_index] = tick + maxi(1, ceili(settings.jungle_respawn_seconds * SimulationClock.TICKS_PER_SECOND))

func _respawn_jungle_camps(tick: int) -> void:
	for camp_index in jungle_camp_respawn_ticks.keys().duplicate():
		if tick < int(jungle_camp_respawn_ticks[camp_index]): continue
		spawn_jungle_camp(int(camp_index))
		jungle_camp_respawn_ticks.erase(camp_index)

func _physics_process(delta: float) -> void:
	if player == null: return
	var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var movement: Vector2 = (keyboard + controls.direction).limit_length(1) if not paused and not match_over and not shop.visible and not opponent_panel.visible else Vector2.ZERO
	player.manual_direction = movement
	if not movement.is_zero_approx():
		attack_mode = ""
		locked_target = ""
		player.runtime.target_id = ""
	ui_elapsed += delta
	if ui_elapsed >= 0.1:
		ui_elapsed = 0.0
		_update_vision()
		_refresh_hud()
	clock.advance(delta)

func _tick(_index: int) -> void:
	if match_over: return
	var tick := combat.tick_count + 1
	runtime_profiler.begin(tick, entities.size())
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
		if audio_router != null: audio_router.play_wave(tick, PackedVector2Array([layout.spawn_points(0)[0], layout.spawn_points(1)[0]]), _audio_listener_position(), _audio_listener_radius())
		next_wave_tick = tick + maxi(1, ceili(settings.wave_interval * SimulationClock.TICKS_PER_SECOND))
	if not jungle_spawned and tick >= maxi(1, ceili(settings.jungle_initial_spawn_seconds * SimulationClock.TICKS_PER_SECOND)):
		spawn_jungle_camps()
		jungle_spawned = true
	var bot_progression: HeroProgression = progression.enemy_hero
	# The current prototype has one five-rank skill. Past rank five the bot keeps
	# earning points for future skills, so stop when no further upgrade is valid.
	while bot_progression.skill_points > 0:
		if not bot_progression.upgrade_passive(): break
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
			var target := _current_target(actor)
			if target == null or actor.runtime.distance_to_unit(target.runtime) > actor.runtime.attack_range() or tick % 3 == info.ai_phase:
				target = _choose_target(info, ["creep", "hero"], actor.runtime.attack_range())
				actor.runtime.target_id = target.runtime.unit_id if target != null else ""
		elif info.get("neutral", false):
			if tick % 3 == info.ai_phase: _drive_jungle_creep(info, tick)
		elif info.kind == "hero":
			if tick % maxi(1, settings.bot_decision_ticks) == info.ai_phase or actor.position.distance_to(player.position) <= settings.bot_chase_range:
				var bot_target := _bot_target(info, tick)
				# Target selection persists state at its decision site. Re-read it so a
				# movement order never overwrites that state with this loop's old copy.
				_drive_bot(entities.get(id, info), bot_target, tick)
		else:
			if tick % maxi(1, settings.creep_target_scan_ticks) == info.ai_phase or _current_target(actor) == null:
				var creep_target := _choose_lane_creep_target(info, tick)
				_drive_lane_creep(entities.get(id, info), creep_target, tick)
	_heal_fountains()
	var events := combat.step()
	if audio_router != null: audio_router.consume(events, entities, combat.tick_count, _audio_listener_position(), _audio_listener_radius())
	for event in events:
		if event.kind == "damage" and entities.has(event.target_unit_id):
			# Keep combat readable: ordinary physical hits stay silent. Special hits remain visible.
			if event.critical or event.damage_type != DamageCalculator.DamageType.PHYSICAL:
				entities[event.target_unit_id].actor.view.show_damage(event.applied_damage, event.critical, event.damage_type)
			if event.applied_damage > 0:
				rewards.record_damage(event.target_unit_id, event.source_unit_id, combat.tick_count, progression)
				_arm_jungle_retaliation(event.target_unit_id, event.source_unit_id)
				_arm_lane_defenders(event)
		elif event.kind == "miss" and entities.has(event.target_unit_id):
			entities[event.target_unit_id].actor.view.show_miss()
		elif event.kind == "death":
			_on_death(event.target_unit_id, events)
	for info in entities.values():
		info.actor.runtime.current_tick = combat.tick_count
		if info.kind == "tower": info.actor.view.structure_locked = not _tower_is_unlocked(info)
		_sync_intent(info, tick)
	_update_vision()
	# Separation is visual/physical housekeeping. Running it at 3 Hz avoids a
	# combat-tick O(n²) spike once lane waves and all jungle camps are alive.
	if tick % 10 == 0: _separate_mobile_units()
	for id in entities.keys().duplicate():
		if entities[id].kind in ["creep", "tower"] and not entities[id].actor.runtime.alive:
			var actor: MapUnit = entities[id].actor
			# Wave entities have no post-death UI. Drop their metrics too so a long
			# match does not retain one Dictionary per historical creep.
			combat.remove_unit(actor.runtime, true)
			actor.queue_free()
			entities.erase(id)
	_schedule_cleared_jungle_camps(tick)
	_respawn_jungle_camps(tick)
	$World.units.assign(_actors())
	for team in range(2):
		if not cores[team].runtime.alive:
			_end_match(1 - team)
			break
	runtime_profiler.finish()

func in_fountain(unit: UnitRuntimeState) -> bool:
	return unit.alive and unit.team_id in [0, 1] and unit.position.distance_to(layout.fountain_point(unit.team_id)) <= settings.fountain_radius

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

func _has_vision(source: MapUnit, target: MapUnit) -> bool:
	runtime_profiler.record_vision_check()
	if source == null or target == null: return false
	if full_map_mode or source.runtime.team_id == target.runtime.team_id: return true
	# Brush hides only opposing playable teams. Neutral camps remain discoverable;
	# a player must physically enter the same brush to reveal an enemy waiting in it.
	if source.runtime.team_id in [0, 1] and target.runtime.team_id in [0, 1] and layout.is_brush_world(target.position) and not layout.is_brush_world(source.position): return false
	var vision := float(source.runtime.stats.get("vision_range", 1200.0))
	# Vision is a deterministic radial rule. Navigation/terrain visibility still
	# controls whether an actor can approach, but does not make UI targetability
	# depend on physics-ray timing.
	return source.position.distance_to(target.position) <= vision

func _update_vision() -> void:
	if player == null: return
	for info in entities.values():
		var actor: MapUnit = info.actor
		if actor == player or actor.runtime.team_id == player.runtime.team_id or full_map_mode:
			actor.view.visible = true
		else:
			actor.view.visible = actor.runtime.alive and _team_has_vision(player.runtime.team_id, actor)

func _team_has_vision(team: int, target: MapUnit) -> bool:
	for info in entities.values():
		runtime_profiler.record_vision_observer()
		var observer: MapUnit = info.actor
		if not observer.runtime.alive or observer.runtime.team_id != team: continue
		if info.kind not in ["hero", "creep", "tower", "core"]: continue
		if _has_vision(observer, target): return true
	return false

func _audio_listener_position() -> Vector2:
	if camera == null or camera.follow_enabled: return player.position
	return camera.position

func _audio_listener_radius() -> float:
	if camera == null or camera.follow_enabled: return float(player.runtime.stats.get("vision_range", 1200.0))
	# A detached map camera can listen inside its current local viewing area.
	return 1200.0

func _current_target(source: MapUnit) -> MapUnit:
	var id := source.runtime.target_id
	if id.is_empty() or not entities.has(id): return null
	var target: MapUnit = entities[id].actor
	if not target.runtime.alive or target.runtime.team_id == source.runtime.team_id: return null
	return target

func _choose_target(info: Dictionary, categories: Array, radius: float, allow_approach: bool = false, allow_neutral: bool = false, lane_filter: String = "", require_vision: bool = false, neutral_only: bool = false) -> MapUnit:
	runtime_profiler.record_target_query()
	var source: MapUnit = info.actor
	var best: MapUnit
	var best_priority := 100
	var best_distance := INF
	var ids: Array = entities.keys()
	ids.sort()
	for id in ids:
		runtime_profiler.record_target_candidate()
		var candidate: Dictionary = entities[id]
		var target: MapUnit = candidate.actor
		if not target.runtime.alive or target.runtime.team_id == source.runtime.team_id or candidate.kind not in categories: continue
		if candidate.kind == "tower" and not _tower_is_unlocked(candidate): continue
		if candidate.kind == "core" and not _core_is_unlocked(target.runtime.team_id): continue
		if info.kind == "hero" and source.runtime.unit_id != "player" and candidate.kind == "tower" and not _tower_has_creep_cover(candidate.actor): continue
		# Neutral camps never pull lane AI or bot auto-attack selection off route.
		# The player's creep command may opt into neutral targets.
		if candidate.get("neutral", false) and not allow_neutral: continue
		if neutral_only and not candidate.get("neutral", false): continue
		if not lane_filter.is_empty() and candidate.kind in ["creep", "tower"] and candidate.lane != lane_filter: continue
		if info.kind == "creep" and candidate.kind in ["creep", "tower"] and candidate.lane != info.lane: continue
		if require_vision and not _has_vision(source, target): continue
		var distance := source.runtime.distance_to_unit(target.runtime)
		var priority := categories.find(candidate.kind)
		if distance > radius or priority > best_priority or (priority == best_priority and (distance > best_distance or (is_equal_approx(distance, best_distance) and target.runtime.unit_id > (best.runtime.unit_id if best != null else "")))): continue
		if not _visible(source, target):
			if not allow_approach or source.navigation.path(source.position, target.position).is_empty(): continue
		best = target
		best_priority = priority
		best_distance = distance
	return best

func _tower_has_creep_cover(tower: MapUnit) -> bool:
	for info in entities.values():
		if info.kind != "creep" or info.get("neutral", false): continue
		var creep: MapUnit = info.actor
		if creep.runtime.alive and creep.runtime.team_id == tower.runtime.team_id and creep.runtime.distance_to_unit(tower.runtime) <= tower.runtime.attack_range() + 180.0:
			return true
	return false

func _tower_has_attacking_creep_cover(tower: MapUnit, attacking_team: int) -> bool:
	for info in entities.values():
		if info.kind != "creep" or info.get("neutral", false): continue
		var creep: MapUnit = info.actor
		if creep.runtime.alive and creep.runtime.team_id == attacking_team and creep.runtime.distance_to_unit(tower.runtime) <= tower.runtime.attack_range() + 180.0:
			return true
	return false

func _choose_lane_creep_target(info: Dictionary, tick: int) -> MapUnit:
	return lane_creep_ai.choose(self, info, tick)

func _drive_lane_creep(info: Dictionary, target: MapUnit, tick: int) -> void:
	lane_creep_ai.drive(self, info, target, tick)

func _unsafe_tower_dive(source: MapUnit, target: MapUnit) -> bool:
	if source == null or target == null: return false
	for info in entities.values():
		if info.kind != "tower": continue
		var tower: MapUnit = info.actor
		if not tower.runtime.alive or tower.runtime.team_id != target.runtime.team_id: continue
		if tower.runtime.distance_to_unit(target.runtime) > tower.runtime.attack_range() + 80.0: continue
		for ally_info in entities.values():
			if ally_info.kind != "creep" or ally_info.get("neutral", false): continue
			var ally: MapUnit = ally_info.actor
			if ally.runtime.alive and ally.runtime.team_id == source.runtime.team_id and tower.runtime.distance_to_unit(ally.runtime) <= tower.runtime.attack_range(): return false
		return true
	return false

func _player_target() -> MapUnit:
	if entities.has(locked_target):
		var target: MapUnit = entities[locked_target].actor
		var leash := settings.player_hero_command_radius if attack_mode == "hero" else settings.player_creep_command_radius
		if target.runtime.alive and target.runtime.team_id != player.runtime.team_id and player.runtime.distance_to_unit(target.runtime) <= leash and _has_vision(player, target): return target
	locked_target = ""
	if attack_mode == "hero":
		return _choose_target(entities.player, ["hero"], settings.player_hero_command_radius, true, false, "", true)
	# J attacks the closest creep of any kind: lane, ranged, siege, or jungle.
	# Once no creep remains in the command radius, it falls back to a structure.
	var target := _choose_target(entities.player, ["creep"], settings.player_creep_command_radius, true, true, "", true)
	if target != null: return target
	# Structure targeting remains local: it cannot select a third tower merely
	# because that target exists elsewhere on the map.
	var lane := _nearest_lane(player.position)
	target = _choose_target(entities.player, ["tower"], settings.player_structure_command_radius, true, false, lane, true)
	if target == null:
		target = _choose_target(entities.player, ["tower"], settings.player_structure_command_radius, true, false, "BASE", true)
	if target == null:
		target = _choose_target(entities.player, ["core"], settings.player_structure_command_radius, true, false, "", true)
	return target

func _drive_target(info: Dictionary, target: MapUnit, tick: int) -> void:
	var actor: MapUnit = info.actor
	if target != null and (not target.runtime.alive or target.runtime.team_id == actor.runtime.team_id): target = null
	actor.movement_speed_multiplier = 1.0 if target != null else float(info.get("travel_speed_multiplier", 1.0))
	actor.runtime.target_id = target.runtime.unit_id if target != null and _visible(actor, target) else ""
	if target != null:
		if actor.runtime.distance_to_unit(target.runtime) <= actor.runtime.attack_range() and _visible(actor, target):
			actor.stop()
			var state: String = info.get("ai_state", "") if info.kind == "hero" else info.get("creep_state", "")
			_trace_ai(info, "MOVE", "state=%s source=attack-stop target=%s distance=%.1f" % [state, target.runtime.unit_id, actor.runtime.distance_to_unit(target.runtime)])
		else:
			var target_moved := not actor.path.is_empty() and actor.path[-1].distance_to(target.position) > 96.0
			if actor.path.is_empty() or (target_moved and tick % 30 == info.ai_phase): _issue_ai_move(info, target.position, "target:" + target.runtime.unit_id, tick)
	elif info.actor != player:
		if info.kind == "hero":
			var home := layout.spawn_points(actor.runtime.team_id)[0]
			if actor.position.distance_to(home) > 900.0:
				actor.stop()
				actor.runtime.target_id = ""
				_persist_entity_info(info)
				return
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
			if actor.path.is_empty() or actor.path[-1].distance_to(waypoint) > 0.1: _issue_ai_move(info, waypoint, "lane-waypoint", tick)
	else: actor.stop()
	if target != null: info.chasing = true
	_persist_entity_info(info)

func _drive_jungle_creep(info: Dictionary, tick: int) -> void:
	var actor: MapUnit = info.actor
	var center: Vector2 = info.camp_center
	var leash: float = info.leash_range
	if actor.position.distance_to(center) > leash:
		actor.runtime.target_id = ""
		info.aggro_target = ""
		info.aggro_expires_tick = 0
		if tick % 10 == 1 or actor.path.is_empty(): actor.go_to(center)
		return
	_continue_jungle_creep(info, tick)

func _set_bot_state(info: Dictionary, state: String, tick: int, reason: String = "") -> void:
	if info.get("ai_state", "") == state: return
	var previous: String = info.get("ai_state", "")
	info.ai_state = state
	info.ai_state_since = tick
	var actor: MapUnit = info.actor
	_persist_entity_info(info)
	_trace_ai(info, "STATE", "%s->%s reason=%s lane=%s hp=%.0f/%.0f" % [previous, state, reason, info.get("assigned_lane", ""), actor.runtime.current_hp, actor.runtime.stats.max_hp])

func _bot_target(info: Dictionary, tick: int) -> MapUnit:
	return enemy_bot_ai.choose(self, info, tick)

func _bot_base_intruder(info: Dictionary, lane: String) -> MapUnit:
	var actor: MapUnit = info.actor
	var fountain := layout.fountain_point(actor.runtime.team_id)
	var best: MapUnit
	var best_distance := INF
	for candidate_info in entities.values():
		if candidate_info.kind != "creep" or candidate_info.get("neutral", false) or candidate_info.lane != lane: continue
		var candidate: MapUnit = candidate_info.actor
		if not candidate.runtime.alive or candidate.runtime.team_id == actor.runtime.team_id: continue
		if candidate.position.distance_to(fountain) > settings.bot_base_defense_radius: continue
		var distance := actor.runtime.distance_to_unit(candidate.runtime)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func _drive_bot(info: Dictionary, target: MapUnit, tick: int) -> void:
	enemy_bot_ai.drive(self, info, target, tick)

func _bot_frontline(team: int, lane: String) -> MapUnit:
	var best: MapUnit
	var best_progress := -INF
	var ids: Array = entities.keys()
	ids.sort()
	for id in ids:
		var candidate: Dictionary = entities[id]
		if candidate.kind != "creep" or candidate.get("neutral", false) or candidate.lane != lane: continue
		var actor: MapUnit = candidate.actor
		if not actor.runtime.alive or actor.runtime.team_id != team: continue
		var progress := _lane_progress(actor.position, lane, team)
		if progress > best_progress:
			best = actor
			best_progress = progress
	return best

func _continue_jungle_creep(info: Dictionary, tick: int) -> void:
	var actor: MapUnit = info.actor
	var center: Vector2 = info.camp_center
	var leash: float = info.leash_range
	var target: MapUnit
	var target_id: String = info.get("aggro_target", "")
	if not target_id.is_empty() and tick <= int(info.get("aggro_expires_tick", 0)) and entities.has(target_id):
		target = entities[target_id].actor
		if not target.runtime.alive or target.position.distance_to(center) > leash: target = null
	if target != null:
		_drive_target(info, target, tick)
	else:
		info.aggro_target = ""
		info.aggro_expires_tick = 0
		actor.movement_speed_multiplier = 1.0
	if target == null and actor.position.distance_to(center) > 35.0:
		actor.runtime.target_id = ""
		if tick % 10 == 1 or actor.path.is_empty(): actor.go_to(center)
	elif target == null:
		actor.runtime.target_id = ""
		actor.stop()

func _arm_jungle_retaliation(target_id: String, source_id: String) -> void:
	if not entities.has(target_id) or not entities.has(source_id): return
	var info: Dictionary = entities[target_id]
	if not info.get("neutral", false): return
	var source: MapUnit = entities[source_id].actor
	if source.runtime.team_id not in [0, 1] or not source.runtime.alive: return
	info.aggro_target = source_id
	info.aggro_expires_tick = combat.tick_count + 300

func _separate_mobile_units() -> void:
	var ids: Array = []
	for id in entities:
		var info: Dictionary = entities[id]
		var actor: MapUnit = info.actor
		if info.kind in ["tower", "core"] or not actor.runtime.alive: continue
		if info.kind == "hero" and in_fountain(actor.runtime): continue
		ids.append(id)
	ids.sort()
	var order := {}
	var buckets := {}
	const BUCKET_SIZE := 128.0
	for index in range(ids.size()):
		var id: String = ids[index]
		order[id] = index
		var actor: MapUnit = entities[id].actor
		var cell := Vector2i(floori(actor.position.x / BUCKET_SIZE), floori(actor.position.y / BUCKET_SIZE))
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(id)
	for first_id in ids:
		var first: MapUnit = entities[first_id].actor
		var first_cell := Vector2i(floori(first.position.x / BUCKET_SIZE), floori(first.position.y / BUCKET_SIZE))
		var resolved_neighbors := 0
		for y in range(first_cell.y - 1, first_cell.y + 2):
			for x in range(first_cell.x - 1, first_cell.x + 2):
				for second_id in buckets.get(Vector2i(x, y), []):
					if order[second_id] <= order[first_id]: continue
					var second: MapUnit = entities[second_id].actor
					var minimum: float = first.runtime.stats.collision_radius + second.runtime.stats.collision_radius + 3.0
					var offset := second.position - first.position
					var distance := offset.length()
					if distance >= minimum: continue
					var direction := offset / distance if distance > 0.001 else Vector2.RIGHT.rotated(float(order[first_id] + order[second_id]))
					var correction := direction * minf((minimum - distance) * 0.5, 12.0)
					var first_next := first.position - correction
					var second_next := second.position + correction
					if first.navigation.point_is_clear(first_next): first.position = first_next; first.runtime.position = first_next
					if second.navigation.point_is_clear(second_next): second.position = second_next; second.runtime.position = second_next
					resolved_neighbors += 1
					if resolved_neighbors >= 4: break
				if resolved_neighbors >= 4: break
			if resolved_neighbors >= 4: break

func request_attack(category: String) -> void:
	if match_over or paused or shop.visible or opponent_panel.visible or not player.runtime.alive: return
	attack_mode = category
	locked_target = ""
	camera.follow_enabled = true
	message.text = "Tự đánh hero · di chuyển để hủy" if category == "hero" else "Tự đánh lính / trụ · di chuyển để hủy"

func _clicked_entity(id: String) -> void:
	if not entities.has(id): return
	var clicked_info: Dictionary = entities[id]
	var clicked: MapUnit = entities[id].actor
	if clicked.runtime.team_id == player.runtime.team_id:
		message.text = "Mục tiêu đồng minh · chỉ có thể đánh lính/tướng địch"
		return
	if clicked_info.kind == "tower" and not _tower_is_unlocked(clicked_info):
		message.text = "TRỤ ĐANG KHOÁ · phá trụ cùng lane phía ngoài trước"
		return
	if clicked_info.kind == "core" and not _core_is_unlocked(clicked.runtime.team_id):
		message.text = "NHÀ CHÍNH ĐANG KHOÁ · phá toàn bộ trụ trước"
		return
	request_attack("hero" if clicked_info.kind == "hero" else "creep")
	locked_target = id
	if not _has_vision(player, clicked): message.text = "Mục tiêu ngoài tầm nhìn · chưa thể tấn công"

func _arm_lane_defenders(event: Dictionary) -> void:
	# Direct hero-vs-hero damage asks nearby allied creeps and towers to protect
	# their hero on their next simulation decision.  Reflections are deliberately
	# excluded because they are not an intentional attack command.
	if event.get("reflected", false) or not entities.has(event.source_unit_id) or not entities.has(event.target_unit_id): return
	var source_info: Dictionary = entities[event.source_unit_id]
	var target_info: Dictionary = entities[event.target_unit_id]
	if source_info.kind != "hero" or target_info.kind != "hero": return
	var source: MapUnit = source_info.actor
	var victim: MapUnit = target_info.actor
	if source.runtime.team_id == victim.runtime.team_id: return
	for info in entities.values():
		var defender: MapUnit = info.actor
		if not defender.runtime.alive or defender.runtime.team_id != victim.runtime.team_id: continue
		if info.kind == "tower":
			if defender.runtime.distance_to_unit(source.runtime) <= defender.runtime.attack_range() and defender.runtime.distance_to_unit(victim.runtime) <= settings.tower_protection_range:
				defender.runtime.target_id = source.runtime.unit_id
		elif info.kind == "creep" and not info.get("neutral", false) and info.lane == target_info.get("assigned_lane", target_info.lane):
			if defender.runtime.distance_to_unit(source.runtime) <= settings.creep_hero_protection_range:
				# Retaliation is a fact for the lane-creep decision state machine, not
				# a competing movement/target command from the damage event.
				info.retaliation_target_id = source.runtime.unit_id
				info.creep_chase_origin = defender.position
				info.hero_aggro_until = combat.tick_count + settings.creep_hero_aggro_ticks
				_persist_entity_info(info)

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
	if info.kind == "tower":
		_apply_lane_push_buff(1 - info.actor.runtime.team_id, info.lane)
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
		message.text = "Hãy chọn hero trước"
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
	if info.kind == "hero" and id != "player":
		# A respawn must not inherit a stale RETREAT/FIGHT destination from the
		# previous life. The next AI decision starts from lane rallying again.
		info.ai_state = "GO_TO_LANE"
		info.ai_state_since = combat.tick_count
		actor.stop()
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
	_button(row, "Tầm nhìn: Giao tranh [V]", func(): set_full_map_mode(not full_map_mode))
	controls = Control.new()
	controls.set_script(preload("res://scripts/match/battle_controls.gd"))
	controls.position = Vector2(0, 720)
	controls.size = Vector2(1600, 170)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.attack_requested.connect(request_attack)
	layer.add_child(controls)
	var quick_panel := PanelContainer.new()
	quick_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	quick_panel.position = Vector2(-410, -105)
	quick_panel.size = Vector2(820, 95)
	quick_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick_stats = Label.new()
	quick_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quick_stats.add_theme_font_size_override("font_size", 17)
	var quick_content := VBoxContainer.new()
	quick_panel.add_child(quick_content)
	quick_content.add_child(quick_stats)
	effects_bar = HBoxContainer.new()
	effects_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_content.add_child(effects_bar)
	layer.add_child(quick_panel)
	minimap = Control.new()
	minimap.set_script(preload("res://scripts/match/match_minimap.gd"))
	minimap.position = Vector2(1365, 18)
	minimap.size = Vector2(215, 215)
	minimap.layout = layout
	minimap.entities = entities
	minimap.player = player
	minimap.full_map_mode = full_map_mode
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
		if progression.player.upgrade_passive(): shop.feedback.text = "Đã nâng kỹ năng lên cấp %d" % progression.player.passive_level
		else: shop.feedback.text = "Không có điểm hoặc kỹ năng đã tối đa"
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
	var stats := state.stats
	var reduction := (1.0 - DamageCalculator.armor_multiplier(state.physical_armor(), combat.balance.armor_coefficient)) * 100.0
	quick_stats.text = "%s · LV %d · %s LV%d · %d vàng\nHP %.0f/%.0f · Mana %.0f/%.0f · Dmg %.0f/%.0f/%.0f · AS %.2f/s (%0.f%%) · BAT %.1fs\nGiáp %.1f (giảm %.0f%%) · Miss %.0f%% · STR %.0f · AGI %.0f · INT %.0f" % [hero.profile.display_name, hero.level, HeroPassiveCatalog.definition(hero.passive_id).name, hero.passive_level, hero.gold, state.current_hp, stats.max_hp, state.current_mana, stats.max_mana, stats.physical_damage, stats.magic_damage, stats.pure_damage, state.attack_speed(), state.attack_speed() / maxf(stats.base_attacks_per_second, 0.001) * 100.0, stats.base_attack_time, state.physical_armor(), reduction, stats.evasion * 100, stats.strength, stats.agility, stats.intelligence]
	_refresh_effects_bar()
	if in_fountain(state): hud.text += " · FOUNTAIN +HP/MANA"
	if shop.visible: shop.refresh()
	if opponent_panel.visible: opponent_panel.refresh()
	if not state.alive: message.text = "Hồi sinh sau %.1f giây · Mất %d vàng" % [respawn, death_gold_losses.get("player", 0)]
	elif paused: message.text = "TẠM DỪNG · nhấn P để tiếp tục"

func _refresh_effects_bar() -> void:
	if effects_bar == null: return
	for child in effects_bar.get_children(): child.queue_free()
	var badges: Array[Dictionary] = player.view.status_badges()
	if badges.is_empty():
		var label := Label.new()
		label.text = "HIỆU ỨNG: —"
		label.add_theme_font_size_override("font_size", 14)
		effects_bar.add_child(label)
		return
	for badge in badges:
		var label := Label.new()
		label.text = "%s %.1fs" % [badge.icon, float(badge.seconds)]
		label.add_theme_color_override("font_color", badge.color)
		label.add_theme_font_size_override("font_size", 15)
		effects_bar.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_J: request_attack("creep")
			KEY_K: request_attack("hero")
			KEY_SPACE: _stop_player()
			KEY_P: set_paused(not paused) if not draft_mode else message.set_text("Hãy chọn hero trước")
			KEY_F: camera.follow_enabled = true
			KEY_B: toggle_shop()
			KEY_TAB: toggle_opponents()
			KEY_V: set_full_map_mode(not full_map_mode)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and player.runtime.alive and not paused and not match_over and not shop.visible and not opponent_panel.visible:
		_stop_player()
		player.go_to(get_global_transform_with_canvas().affine_inverse() * event.position)

func set_full_map_mode(value: bool) -> void:
	full_map_mode = value
	_update_vision()
	if minimap != null: minimap.full_map_mode = full_map_mode
	if message != null:
		message.text = "TOÀN MAP · nhìn và chọn mọi mục tiêu" if full_map_mode else "GIAO TRANH · chỉ thấy mục tiêu trong tầm nhìn"
