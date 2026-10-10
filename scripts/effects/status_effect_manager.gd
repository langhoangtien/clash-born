class_name StatusEffectManager
extends RefCounted

var active: Array[StatusEffect] = []

func range_bonus(kind: StatusEffect.Kind) -> float:
	var total := 0.0
	for effect in active:
		if effect.kind == kind: total += effect.magnitude
	return total

func expire(tick: int) -> Array[StatusEffect]:
	var expired: Array[StatusEffect] = []
	for index in range(active.size() - 1, -1, -1):
		if active[index].expires_at_tick <= tick:
			expired.push_front(active[index])
			active.remove_at(index)
	return expired

func apply(effect: StatusEffect) -> void:
	for index in range(active.size()):
		if active[index].instance_id == effect.instance_id and active[index].source_unit_id == effect.source_unit_id and active[index].kind == effect.kind:
			active[index] = effect
			return
	active.append(effect)

func is_stunned() -> bool:
	for effect in active:
		if effect.kind == StatusEffect.Kind.STUN:
			return true
	return false

func strongest_slow() -> float:
	var slow := 0.0
	for effect in active:
		if effect.kind == StatusEffect.Kind.SLOW:
			slow = maxf(slow, clampf(effect.magnitude, 0, 1))
	return slow

func armor_reduction() -> float:
	var reduction := 0.0
	for effect in active:
		if effect.kind == StatusEffect.Kind.ARMOR_REDUCTION:
			reduction += maxf(0, effect.magnitude)
	return reduction
