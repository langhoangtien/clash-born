class_name BehaviorActorSnapshot
extends RefCounted
## Immutable actor view used by behavior controllers and intent validation.

var actor_id: String
var team_id: int
var alive: bool
var kind: String
var lane: String
var neutral: bool
var position: Vector2
var collision_radius: float
var attack_range: float
var current_target_id: String
var visible_target_ids: PackedStringArray = []

func _init(id: String = "", team: int = -1, is_alive: bool = false, actor_kind: String = "", actor_lane: String = "", is_neutral: bool = false, actor_position: Vector2 = Vector2.ZERO, radius: float = 0.0, actor_attack_range: float = 0.0, target_id: String = "", visible_ids: PackedStringArray = []) -> void:
	actor_id = id
	team_id = team
	alive = is_alive
	kind = actor_kind
	lane = actor_lane
	neutral = is_neutral
	position = actor_position
	collision_radius = radius
	attack_range = actor_attack_range
	current_target_id = target_id
	visible_target_ids = visible_ids

func can_see(target_id: String) -> bool:
	return target_id in visible_target_ids

func edge_distance_to(other: BehaviorActorSnapshot) -> float:
	return maxf(0.0, position.distance_to(other.position) - collision_radius - other.collision_radius)
