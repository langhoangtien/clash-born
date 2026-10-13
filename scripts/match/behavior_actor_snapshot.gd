class_name BehaviorActorSnapshot
extends RefCounted
## Immutable actor view used by behavior controllers and intent validation.

var actor_id: String
var team_id: int
var alive: bool
var kind: String
var position: Vector2
var collision_radius: float
var current_target_id: String
var visible_target_ids: PackedStringArray = []

func _init(id: String = "", team: int = -1, is_alive: bool = false, actor_kind: String = "", actor_position: Vector2 = Vector2.ZERO, radius: float = 0.0, target_id: String = "", visible_ids: PackedStringArray = []) -> void:
	actor_id = id
	team_id = team
	alive = is_alive
	kind = actor_kind
	position = actor_position
	collision_radius = radius
	current_target_id = target_id
	visible_target_ids = visible_ids

func can_see(target_id: String) -> bool:
	return target_id in visible_target_ids
