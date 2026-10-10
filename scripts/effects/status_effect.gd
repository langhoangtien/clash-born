class_name StatusEffect
extends RefCounted

enum Kind { STUN, SLOW, ARMOR_REDUCTION, ATTACK_RANGE, CAST_RANGE, ATTACK_SLOW }

var instance_id: String
var source_unit_id: String
var target_unit_id: String
var kind: Kind
var magnitude: float
var duration_ticks: int
var expires_at_tick: int
var stacking_policy: String = "refresh_same_instance"

func remaining_seconds(current_tick: int) -> float:
	return maxi(0, expires_at_tick - current_tick) * SimulationClock.TICK_SECONDS
