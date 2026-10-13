class_name ObjectiveRegistry
extends RefCounted
## Single authority for objective prerequisites and attackability.

var nodes: Dictionary = {} # String -> StructureNode. Keys are semantic IDs.
var configuration_errors: PackedStringArray = []

func register_node(node: StructureNode) -> void:
	if node.id.is_empty() or nodes.has(node.id):
		configuration_errors.append("Invalid or duplicate objective ID: " + node.id)
		return
	nodes[node.id] = node

func validate() -> PackedStringArray:
	var errors := PackedStringArray(configuration_errors)
	for node in nodes.values():
		for prerequisite in node.prerequisites_all + node.prerequisites_any:
			if not nodes.has(prerequisite): errors.append("Unknown objective prerequisite: %s -> %s" % [node.id, prerequisite])
	return errors

## The only objective-damageability rule. Accepting either the typed node or
## its semantic ID keeps consumers from reconstructing prerequisite logic.
func is_attackable(node_or_id: Variant, entities: Dictionary) -> bool:
	var node := _resolve(node_or_id)
	if node == null:
		return false
	if _is_dead_or_missing(node.runtime_id, entities):
		return false
	for prerequisite in node.prerequisites_all:
		if not nodes.has(prerequisite) or not _is_dead_or_missing(nodes[prerequisite].runtime_id, entities): return false
	if not node.prerequisites_any.is_empty():
		var one_destroyed := false
		for prerequisite in node.prerequisites_any:
			if nodes.has(prerequisite) and _is_dead_or_missing(nodes[prerequisite].runtime_id, entities):
				one_destroyed = true
				break
		if not one_destroyed: return false
	return true

func node_for_id(node_id: String) -> StructureNode:
	return nodes.get(node_id) as StructureNode

func next_lane_objective(attacking_team: int, lane: String, entities: Dictionary) -> StructureNode:
	if not lane_is_configured(attacking_team, lane): return null
	var owner := 1 - attacking_team
	for tier in range(1, 4):
		var node = _find(owner, lane, tier)
		if node == null:
			configuration_errors.append("Missing required lane objective: team=%d lane=%s tier=%d" % [owner, lane, tier])
			return null
		if not _is_dead_or_missing(node.runtime_id, entities):
			return node if is_attackable(node, entities) else null
	return null

func lane_is_configured(attacking_team: int, lane: String) -> bool:
	if not configuration_errors.is_empty(): return false
	var owner := 1 - attacking_team
	for tier in range(1, 4):
		var node := _find(owner, lane, tier)
		if node == null or not _has_known_prerequisites(node): return false
	return true

func _find(team_id: int, wanted_lane: String, wanted_tier: int) -> StructureNode:
	for node in nodes.values():
		if node.team == team_id and node.lane == wanted_lane and node.tier == wanted_tier: return node
	return null

func _resolve(node_or_id: Variant) -> StructureNode:
	if node_or_id is StructureNode:
		return node_or_id as StructureNode
	if node_or_id is String:
		return node_for_id(node_or_id)
	return null

func _has_known_prerequisites(node: StructureNode) -> bool:
	for prerequisite in node.prerequisites_all + node.prerequisites_any:
		if not nodes.has(prerequisite): return false
	return true

func _is_dead_or_missing(runtime_id: String, entities: Dictionary) -> bool:
	return not entities.has(runtime_id) or not entities[runtime_id].actor.runtime.alive
