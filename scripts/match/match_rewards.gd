class_name MatchRewards
extends RefCounted
## Match-only rewards, based on simulation-time damage at impact.
var settings: MatchSettings
var damage_history: Dictionary = {}

func _init(rules: MatchSettings) -> void:
	settings = rules

func record_damage(victim: String, attacker: String, tick: int, heroes: Dictionary) -> void:
	if not heroes.has(attacker): return
	if not damage_history.has(victim): damage_history[victim] = {}
	damage_history[victim][attacker] = tick

func forget(victim: String) -> void:
	damage_history.erase(victim)

func calculate(victim: UnitRuntimeState, kind: String, killer: String, killer_team: int, victim_level: int, tick: int, heroes: Dictionary, siege: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var team_ids: Array[String] = []
	var nearby: Array[String] = []
	for id in heroes:
		var hero: HeroProgression = heroes[id]
		if hero.unit.team_id == victim.team_id or hero.unit.team_id != killer_team: continue
		team_ids.append(id)
		result[id] = {"xp": 0, "gold": 0}
		if hero.unit.alive and hero.unit.position.distance_to(victim.position) <= settings.xp_radius: nearby.append(id)
	team_ids.sort()
	nearby.sort()
	var xp: int = {"creep": settings.siege_xp if siege else settings.creep_xp, "hero": settings.hero_xp + settings.hero_xp_per_level * maxi(1, victim_level), "tower": settings.tower_xp}.get(kind, 0)
	_split(result, nearby, "xp", xp)
	if kind != "hero":
		var gold: int = {"creep": settings.siege_gold if siege else settings.creep_gold, "tower": settings.tower_gold}.get(kind, 0)
		if result.has(killer): result[killer].gold += gold
		return result
	var bounty := settings.hero_gold + settings.hero_gold_per_level * maxi(1, victim_level)
	var credited := killer if result.has(killer) else ""
	var recent: Array[String] = []
	var newest := -1
	var window := ceili(settings.hero_credit_seconds * SimulationClock.TICKS_PER_SECOND)
	var history: Dictionary = damage_history.get(victim.unit_id, {})
	for id in team_ids:
		var hit_tick: int = history.get(id, -1)
		if hit_tick < 0 or tick - hit_tick > window: continue
		recent.append(id)
		# Sorted IDs break simultaneous-impact ties deterministically.
		if credited.is_empty() and hit_tick > newest: newest = hit_tick
	if credited.is_empty():
		for id in recent:
			if history[id] == newest: credited = id; break
	if credited.is_empty():
		# An unassisted enemy tower/creep kill pays the entire allied roster.
		_split(result, team_ids, "gold", bounty)
	else:
		result[credited].gold += bounty
		var assists: Array[String] = []
		for id in team_ids:
			if id != credited and (id in recent or id in nearby): assists.append(id)
		_split(result, assists, "gold", settings.hero_assist_gold + settings.hero_assist_gold_per_level * maxi(1, victim_level))
	return result

func _split(result: Dictionary, ids: Array[String], field: String, amount: int) -> void:
	if ids.is_empty(): return
	var total := maxi(0, amount)
	var share: int = total / ids.size()
	var remainder := total % ids.size()
	for index in range(ids.size()): result[ids[index]][field] += share + (1 if index < remainder else 0)
