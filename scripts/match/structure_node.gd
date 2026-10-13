class_name StructureNode
extends RefCounted
## Typed, semantic definition for a damageable match objective.
## Runtime liveness deliberately remains on the CombatEngine entity; this node
## is immutable authored topology, not a second copy of combat state.

var id: String
var runtime_id: String
var team: int
var lane: String
var tier: int
var prerequisites_all: PackedStringArray = []
var prerequisites_any: PackedStringArray = []

func _init(node_id: String = "", node_runtime_id: String = "", node_team: int = -1, node_lane: String = "", node_tier: int = 0, required_all: PackedStringArray = [], required_any: PackedStringArray = []) -> void:
	id = node_id
	runtime_id = node_runtime_id
	team = node_team
	lane = node_lane
	tier = node_tier
	prerequisites_all = required_all
	prerequisites_any = required_any
