class_name BehaviorOwnership
extends RefCounted
## Canonical controller ownership. Phase 2 registers no live actor migration.

enum Controller {
	LANE_CREEP,
	JUNGLE_CREEP,
	STRUCTURE,
	BOT_HERO,
	PLAYER_COMMAND,
}

static func controller_for(kind: String, neutral: bool = false, is_player: bool = false) -> Controller:
	if is_player: return Controller.PLAYER_COMMAND
	if kind == "tower" or kind == "core": return Controller.STRUCTURE
	if kind == "creep" and neutral: return Controller.JUNGLE_CREEP
	if kind == "creep": return Controller.LANE_CREEP
	return Controller.BOT_HERO
