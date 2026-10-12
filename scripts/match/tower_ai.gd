extends RefCounted
## Sole target decision owner for towers and throne guards.

func choose(host: Node, info: Dictionary, tick: int) -> MapUnit:
	var tower: MapUnit = info.actor
	var protected_id: String = info.get("protection_target_id", "")
	if not protected_id.is_empty() and tick <= int(info.get("protection_expires_tick", 0)) and host.entities.has(protected_id):
		var aggressor: MapUnit = host.entities[protected_id].actor
		if aggressor.runtime.alive and aggressor.runtime.team_id != tower.runtime.team_id and tower.runtime.distance_to_unit(aggressor.runtime) <= tower.runtime.attack_range():
			info.tower_state = "PROTECT_HERO"
			info.tower_target_locked_until = tick + host.settings.tower_target_lock_ticks
			host._persist_entity_info(info)
			return aggressor
	info.protection_target_id = ""
	info.protection_expires_tick = 0
	var current: MapUnit = host._current_target(tower)
	if current != null and tick <= int(info.get("tower_target_locked_until", 0)) and tower.runtime.distance_to_unit(current.runtime) <= tower.runtime.attack_range():
		info.tower_state = "DEFEND"
		host._persist_entity_info(info)
		return current
	var target: MapUnit = host._choose_target(info, ["creep", "hero"], tower.runtime.attack_range())
	info.tower_state = "DEFEND" if target != null else "IDLE"
	info.tower_target_locked_until = tick + host.settings.tower_target_lock_ticks if target != null else tick
	host._persist_entity_info(info)
	return target
