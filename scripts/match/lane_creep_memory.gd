class_name LaneCreepMemory
extends RefCounted
## Mutable controller-owned memory; world state stays in BehaviorWorldSnapshot.

var actor_id: String
var lane: String
var route: PackedVector2Array
var route_index: int = 0
var state: String = "LANE_ADVANCE"
var retaliation_target_id: String = ""
var retaliation_origin: Vector2 = Vector2.ZERO
var retaliation_expiry_tick: int = -1
var return_required: bool = false

func _init(id: String, assigned_lane: String, lane_route: PackedVector2Array) -> void:
	actor_id = id
	lane = assigned_lane
	route = lane_route
