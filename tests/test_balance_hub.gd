extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://scripts/balance/balance_hub.gd")
	var hub = load("res://data/balance/balance_hub.tres")
	var errors: PackedStringArray = hub.validation_errors()
	if not errors.is_empty():
		push_error("Balance hub invalid: " + "; ".join(errors))
		quit(1)
		return
	if hub.all_match_items().size() < 20:
		push_error("Balance hub item catalog is unexpectedly small")
		quit(1)
		return
	print("Balance hub: %d item entries, %d hero archetypes, %d abilities, 0 failures" % [hub.all_match_items().size(), hub.hero_archetypes.size(), hub.abilities.size()])
	quit(0)
