class_name CombatEngine
extends RefCounted
## Fixed-step, seeded simulation. No scene, input, rendering or wall-clock state.

var balance: BalanceSettings
var units: Array[UnitRuntimeState] = []
var tick_count: int = 0
var finished: bool = false
var winner_team: int = -1
var finish_reason: String = ""
var rng := RandomNumberGenerator.new()
var random_seed: int = 1
var metrics := CombatMetrics.new()
var projectiles: Array[CombatProjectile] = []
var _next_projectile_id: int = 0
var _cast_requests: Array[Dictionary] = []
var _commands: Array[Dictionary] = []
## Map match supplies movement/targets and decides victory; sandbox stays default.
var external_control: bool = false

func _init(settings: BalanceSettings) -> void:
	balance = settings

## Compatibility entry point for isolated formula/duel tests without AI.
func reset(blue: UnitStats, red: UnitStats, blue_position: Vector2, red_position: Vector2, seed_value: int = 1, blue_items: Array[EquipmentData] = [], red_items: Array[EquipmentData] = []) -> void:
	reset_scenario([
		{"id": "blue_01", "team": 0, "source": blue, "position": blue_position, "equipment": blue_items, "ai": false},
		{"id": "red_01", "team": 1, "source": red, "position": red_position, "equipment": red_items, "ai": false},
	], seed_value)

func reset_scenario(entries: Array[Dictionary], seed_value: int = 1) -> bool:
	var counts := [0, 0]
	var ids: Array[String] = []
	for entry in entries:
		if not entry.has("id") or not entry.has("source") or not entry.source is UnitStats or entry.get("team", -1) not in [0, 1]: return false
		if entry.id.is_empty() or entry.id in ids: return false
		ids.append(entry.id)
		counts[entry.team] += 1
	if counts[0] not in range(1, 6) or counts[1] not in range(1, 6): return false
	units.clear()
	for entry in entries:
		units.append(_make_unit(entry))
	tick_count = 0
	finished = false
	winner_team = -1
	finish_reason = ""
	random_seed = seed_value
	rng.seed = seed_value
	_commands.clear()
	_cast_requests.clear()
	projectiles.clear()
	_next_projectile_id = 0
	metrics.initialize(units)
	return true

func _make_unit(entry: Dictionary) -> UnitRuntimeState:
	var items: Array[EquipmentData] = []
	items.assign(entry.get("equipment", []))
	var unit := UnitRuntimeState.new(entry.id, entry.team, entry.get("position", Vector2.ZERO), entry.source, balance, items)
	unit.ai_enabled = entry.get("ai", true)
	return unit

func add_unit(entry: Dictionary) -> UnitRuntimeState:
	if not entry.has("id") or not entry.has("source") or not entry.source is UnitStats or entry.get("team", -1) not in [0, 1] or entry.id.is_empty() or get_unit(entry.id) != null: return null
	var unit := _make_unit(entry)
	unit.current_tick = tick_count
	units.append(unit)
	metrics.register_unit(unit)
	return unit

func get_unit(id: String) -> UnitRuntimeState:
	for unit in units:
		if unit.unit_id == id: return unit
	return null

## Debug command, intentionally bypasses ability cost/cast rules.
func queue_effect(source_id: String, target_id: String, kind: StatusEffect.Kind, duration: float, magnitude: float, instance_id: String) -> void:
	_commands.append({"source": source_id, "target": target_id, "kind": kind, "duration": duration, "magnitude": magnitude, "id": instance_id})

func _apply_effect(command: Dictionary, events: Array[Dictionary]) -> void:
	var unit := get_unit(command.target)
	if unit == null or not unit.alive or command.duration <= 0 or command.id.is_empty() or command.kind not in StatusEffect.Kind.values(): return
	var effect := StatusEffect.new()
	effect.instance_id = command.id
	effect.source_unit_id = command.source
	effect.target_unit_id = command.target
	effect.kind = command.kind
	effect.magnitude = command.magnitude
	var duration: float = command.duration * (1 - unit.stats.status_resistance) if effect.kind == StatusEffect.Kind.STUN else command.duration
	effect.duration_ticks = maxi(1, ceili(duration * SimulationClock.TICKS_PER_SECOND - 0.000000001))
	effect.expires_at_tick = tick_count + effect.duration_ticks
	unit.effects.apply(effect)
	var applied := _event("effect_applied", effect.source_unit_id, unit.unit_id)
	applied.effect_id = effect.instance_id
	applied.effect_kind = effect.kind
	applied.duration_ticks = effect.duration_ticks
	applied.magnitude = effect.magnitude
	events.append(applied)

func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished or units.is_empty(): return events
	tick_count += 1
	# Stable order: expire -> debug commands -> regen -> targets/movement ->
	# in-flight impacts -> casting/effects -> collect attacks -> stun tick -> damage -> deaths.
	for unit in units:
		unit.current_tick = tick_count
		for effect in unit.effects.expire(tick_count):
			var expired := _event("effect_expired", effect.source_unit_id, unit.unit_id)
			expired.effect_id = effect.instance_id
			expired.effect_kind = effect.kind
			events.append(expired)
	for command in _commands: _apply_effect(command, events)
	_commands.clear()
	for unit in units:
		if not unit.alive: continue
		var before := unit.current_hp
		unit.current_hp = minf(unit.stats.max_hp, unit.current_hp + unit.stats.hp_regen * SimulationClock.TICK_SECONDS)
		unit.current_mana = minf(unit.stats.max_mana, unit.current_mana + unit.stats.mana_regen * SimulationClock.TICK_SECONDS)
		metrics.by_unit[unit.unit_id].healing_received += unit.current_hp - before
		if external_control: continue
		var target := CombatAI.select_target(unit, units)
		if not unit.ai_enabled:
			for candidate in units:
				if candidate.alive and candidate.team_id != unit.team_id:
					target = candidate
					break
		unit.target_id = target.unit_id if target != null else ""
	if not external_control: CombatAI.move_units(units, balance)
	var pending: Array[Dictionary] = []
	_advance_projectiles(events, pending)
	_resolve_abilities(events)
	for source in units:
		var target := get_unit(source.target_id)
		if not source.can_act() or not source.casting.is_empty() or target == null or not target.alive or (source.ai_enabled and source.ai_mode == CombatAI.Mode.PASSIVE): continue
		if tick_count + 0.000000001 < source.next_attack_tick or source.distance_to_unit(target) > source.attack_range() + 0.000001: continue
		if tick_count - source.next_attack_tick >= 1.0: source.next_attack_tick = tick_count
		source.next_attack_tick += SimulationClock.TICKS_PER_SECOND / source.stats.attack_speed
		var payload := {"type": "attack", "stats": source.stats.duplicate(true)}
		if source.stats.ranged_attacks:
			_launch_projectile(source, target.unit_id, target.position, source.stats.projectile_speed, source.stats.projectile_hit_behavior, payload, events)
		else:
			_resolve_attack(source.unit_id, target, payload.stats, events, pending)
	metrics.record_tick(units, tick_count)
	for damage in pending:
		var target := get_unit(damage.target_unit_id)
		damage.applied_damage = minf(target.current_hp, damage.final_damage)
		target.current_hp = maxf(0, target.current_hp - damage.final_damage)
		events.append(damage)
	var teams_alive := [false, false]
	for unit in units:
		if unit.alive and unit.current_hp <= 0:
			unit.alive = false
			unit.casting.clear()
			events.append(_event("death", "", unit.unit_id))
		if unit.alive: teams_alive[unit.team_id] = true
	if not external_control and (not teams_alive[0] or not teams_alive[1]) and projectiles.is_empty():
		finished = true
		winner_team = 0 if teams_alive[0] else (1 if teams_alive[1] else -1)
		finish_reason = "elimination"
	elif not external_control and tick_count >= ceili(balance.battle_time_limit_seconds * SimulationClock.TICKS_PER_SECOND):
		finished = true
		finish_reason = "time_limit"
	if finished:
		var result_event := _event("finished", "", "")
		result_event.winner_team = winner_team
		result_event.reason = finish_reason
		events.append(result_event)
	metrics.consume(events)
	return events

## Commands are consumed next tick; same validation as AI. Ground/directional
## points are captured when casting starts and never follow the target.
func queue_cast(source_id: String, ability_index: int, target_id: String, point: Vector2) -> void:
	_cast_requests.append({"source": source_id, "index": ability_index, "target": target_id, "point": point})

func _resolve_abilities(events: Array[Dictionary]) -> void:
	var completed: Array[Dictionary] = []
	for source in units:
		if not source.alive: continue
		if not source.casting.is_empty() and not source.can_cast():
			events.append(_event("cast_interrupted", source.unit_id, source.casting.target))
			source.casting.clear()
		if not source.can_cast(): continue
		if source.casting.is_empty():
			var requests: Array[Dictionary] = []
			for request in _cast_requests:
				if request.source == source.unit_id: requests.append(request)
			var target := get_unit(source.target_id)
			if requests.is_empty() and source.ai_enabled and source.ai_mode != CombatAI.Mode.PASSIVE and target != null:
				for index in range(source.abilities.size()):
					requests.append({"index": index, "target": target.unit_id, "point": target.position})
			for request in requests:
				if request.index < 0 or request.index >= source.abilities.size(): continue
				var ability := source.abilities[request.index]
				if ability == null or ability.id.is_empty() or tick_count < source.ability_ready_ticks.get(ability.id, 0) or source.current_mana < ability.mana_cost: continue
				if not _valid_cast(source, ability, request.target, request.point): continue
				source.current_mana -= maxf(0, ability.mana_cost)
				source.ability_ready_ticks[ability.id] = tick_count + maxi(1, ceili(ability.cooldown * SimulationClock.TICKS_PER_SECOND))
				source.casting = {"index": request.index, "target": request.target, "point": request.point, "complete_tick": tick_count + maxi(0, ceili(ability.cast_time * SimulationClock.TICKS_PER_SECOND))}
				var cast := _event("cast", source.unit_id, request.target)
				cast.ability_id = ability.id
				cast.ability_name = ability.display_name
				cast.mana_cost = ability.mana_cost
				events.append(cast)
				break
		if not source.casting.is_empty() and source.casting.complete_tick <= tick_count:
			completed.append({"source": source, "target": source.casting.target, "point": source.casting.point, "ability": source.abilities[source.casting.index]})
			source.casting.clear()
	_cast_requests.clear()
	for cast in completed:
		if not _valid_cast(cast.source, cast.ability, cast.target, cast.point):
			events.append(_event("cast_interrupted", cast.source.unit_id, cast.target))
			continue
		var target := get_unit(cast.target)
		var point: Vector2 = target.position if cast.ability.target_type == AbilityData.TargetType.ENEMY else cast.point
		var payload := {"type": "ability", "ability": cast.ability.duplicate(true), "team": cast.source.team_id, "origin": cast.source.position, "point": point}
		if cast.ability.uses_projectile:
			var behavior: int = cast.ability.projectile_hit_behavior if cast.ability.target_type == AbilityData.TargetType.ENEMY else CombatProjectile.HitBehavior.FIXED_POSITION
			_launch_projectile(cast.source, cast.target if cast.ability.target_type == AbilityData.TargetType.ENEMY else "", point, cast.ability.projectile_speed, behavior, payload, events)
		else:
			_resolve_ability(cast.source.unit_id, cast.target, point, payload, events)

func _valid_cast(source: UnitRuntimeState, ability: AbilityData, target_id: String, point: Vector2) -> bool:
	if ability.target_type == AbilityData.TargetType.ENEMY:
		var target := get_unit(target_id)
		return target != null and target.alive and target.team_id != source.team_id and source.distance_to_unit(target) <= source.cast_range(ability) + 0.000001
	return point.is_finite() and source.distance_to_point(point) <= source.cast_range(ability) + 0.000001

func _resolve_ability(source_id: String, target_id: String, point: Vector2, payload: Dictionary, events: Array[Dictionary]) -> void:
	var ability: AbilityData = payload.ability
	var targets: Array[UnitRuntimeState] = []
	if ability.target_type == AbilityData.TargetType.ENEMY:
		var target := get_unit(target_id)
		if target != null and target.alive: targets.append(target)
	else:
		for target in units:
			if not target.alive or target.team_id == payload.team: continue
			var nearest: Vector2 = point
			if ability.target_type == AbilityData.TargetType.DIRECTIONAL:
				var line: Vector2 = point - payload.origin
				var fraction: float = clampf((target.position - payload.origin).dot(line) / line.length_squared(), 0, 1) if line.length_squared() > 0 else 0
				nearest = payload.origin + line * fraction
			if target.position.distance_to(nearest) <= maxf(0, ability.effect_radius) + target.stats.collision_radius + 0.000001: targets.append(target)
	for target in targets:
		for index in range(ability.effects.size()):
			var effect := ability.effects[index]
			if effect == null: continue
			_apply_effect({"source": source_id, "target": target.unit_id, "kind": effect.kind, "duration": effect.duration, "magnitude": effect.magnitude, "id": "%s_%d" % [ability.id, index]}, events)

func _launch_projectile(source: UnitRuntimeState, target_id: String, point: Vector2, speed: float, behavior: int, payload: Dictionary, events: Array[Dictionary]) -> void:
	var projectile := CombatProjectile.new()
	_next_projectile_id += 1
	projectile.id = _next_projectile_id
	projectile.source_id = source.unit_id
	projectile.target_id = target_id
	projectile.destination = point
	projectile.position = source.position + (point - source.position).normalized() * source.stats.collision_radius
	projectile.speed = maxf(1, speed)
	projectile.hit_behavior = behavior
	projectile.dead_target_behavior = payload.stats.projectile_dead_target_behavior if payload.type == "attack" else payload.ability.projectile_dead_target_behavior
	projectile.launch_tick = tick_count
	projectile.expires_tick = tick_count + maxi(1, ceili(balance.projectile_lifetime_seconds * SimulationClock.TICKS_PER_SECOND))
	projectile.payload = payload
	projectiles.append(projectile)
	var event := _event("projectile_launched", source.unit_id, target_id)
	event.projectile_id = projectile.id
	events.append(event)

func _advance_projectiles(events: Array[Dictionary], pending: Array[Dictionary]) -> void:
	var remaining: Array[CombatProjectile] = []
	for projectile in projectiles:
		var target := get_unit(projectile.target_id)
		var canceled := tick_count >= projectile.expires_tick or (projectile.dead_target_behavior == CombatProjectile.DeadTargetBehavior.CANCEL and not projectile.target_id.is_empty() and (target == null or not target.alive))
		if canceled:
			var event := _event("projectile_canceled", projectile.source_id, projectile.target_id)
			event.projectile_id = projectile.id
			events.append(event)
			continue
		if not projectile.advance(target):
			remaining.append(projectile)
			continue
		var event := _event("projectile_impact", projectile.source_id, projectile.target_id)
		event.projectile_id = projectile.id
		events.append(event)
		if target != null and projectile.hit_behavior == CombatProjectile.HitBehavior.FIXED_POSITION and target.position.distance_to(projectile.destination) > target.stats.collision_radius + 0.000001:
			events.append(_event("projectile_evaded", projectile.source_id, projectile.target_id))
			continue
		if projectile.payload.type == "attack":
			_resolve_attack(projectile.source_id, target, projectile.payload.stats, events, pending)
		else:
			_resolve_ability(projectile.source_id, projectile.target_id, projectile.destination, projectile.payload, events)
	projectiles = remaining

func _resolve_attack(source_id: String, target: UnitRuntimeState, stats: Dictionary, events: Array[Dictionary], pending: Array[Dictionary]) -> void:
	if target == null or not target.alive: return
	var hit := HitCalculator.resolve(stats, target.stats, rng, balance)
	var attack := _event("attack", source_id, target.unit_id)
	attack.can_miss = stats.attacks_can_miss
	attack.can_crit = stats.attacks_can_crit
	attack.missed = hit.missed
	attack.critical = hit.critical
	events.append(attack)
	if hit.missed:
		events.append(_event("miss", source_id, target.unit_id))
		return
	for damage_type in range(3):
		var raw: float = stats[["physical_damage", "magic_damage", "pure_damage"][damage_type]]
		if raw <= 0: continue
		var damage := _event("damage", source_id, target.unit_id)
		damage.damage_type = damage_type
		damage.critical = hit.critical and (stats.pure_attacks_can_crit or damage_type != DamageCalculator.DamageType.PURE)
		damage.raw_damage = raw * stats.critical_multiplier if damage.critical else raw
		var physical := DamageCalculator.effective_armor(target.physical_armor(), stats.armor_reduction, stats.physical_armor_penetration)
		var magical := DamageCalculator.effective_armor(target.stats.magic_armor, stats.magic_armor_reduction)
		damage.final_damage = DamageCalculator.calculate(damage.raw_damage, damage_type, physical, magical, balance)
		pending.append(damage)

func result() -> Dictionary:
	return {"winner_team": winner_team, "duration": tick_count * SimulationClock.TICK_SECONDS, "reason": finish_reason, "finished": finished, "units": metrics.by_unit.duplicate(true)}

func _event(kind: String, source_id: String, target_id: String) -> Dictionary:
	return {"kind": kind, "tick": tick_count, "source_unit_id": source_id, "target_unit_id": target_id}
