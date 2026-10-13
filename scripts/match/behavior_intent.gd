class_name BehaviorIntent
extends RefCounted
## A controller's single, immutable decision for one actor and simulation tick.

var actor_id: String
var state: String
var target_id: String
var destination: Vector2
var has_destination: bool
var expiry_tick: int
var reason: String

func _init(intent_actor_id: String = "", intent_state: String = "IDLE", intent_target_id: String = "", intent_destination: Vector2 = Vector2.ZERO, destination_is_set: bool = false, intent_expiry_tick: int = -1, intent_reason: String = "") -> void:
	actor_id = intent_actor_id
	state = intent_state
	target_id = intent_target_id
	destination = intent_destination
	has_destination = destination_is_set
	expiry_tick = intent_expiry_tick
	reason = intent_reason

func is_expired(tick: int) -> bool:
	return expiry_tick >= 0 and tick > expiry_tick
