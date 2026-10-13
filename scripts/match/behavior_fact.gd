class_name BehaviorFact
extends RefCounted
## A time-bounded event fact. Facts never issue combat or movement orders.

enum Kind {
	HERO_DAMAGE,
	CAMP_AGGRO,
	TOWER_THREAT,
	TARGET_INVALID,
}

var kind: Kind
var source_id: String
var target_id: String
var created_tick: int
var expiry_tick: int
var reason: String

func _init(fact_kind: Kind = Kind.TARGET_INVALID, fact_source_id: String = "", fact_target_id: String = "", fact_created_tick: int = 0, fact_expiry_tick: int = 0, fact_reason: String = "") -> void:
	kind = fact_kind
	source_id = fact_source_id
	target_id = fact_target_id
	created_tick = fact_created_tick
	expiry_tick = fact_expiry_tick
	reason = fact_reason

func is_active(tick: int) -> bool:
	return tick <= expiry_tick
