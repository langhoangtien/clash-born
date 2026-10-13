extends SceneTree
## Contract 6.3-6.5 regression coverage: topology and impact-time locks.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _runtime_id(game, semantic_id: String) -> String:
	return str(game.tower_registry.get(semantic_id, ""))

func _destroy(game, semantic_id: String) -> void:
	game.entities[_runtime_id(game, semantic_id)].actor.runtime.alive = false

func _attackable(game, semantic_id: String) -> bool:
	return game.objective_registry.is_attackable(semantic_id, game.entities)

func _impact_allowed(game, semantic_id: String) -> bool:
	var runtime_id := _runtime_id(game, semantic_id)
	return game._can_apply_match_damage({}, null, game.entities[runtime_id].actor.runtime)

func _run() -> void:
	var game = load("res://scenes/match/moba_match.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.clock.set_running(false)
	game.set_physics_process(false)

	check(game.structure_registry_errors().is_empty(), "Objective registry has complete semantic IDs and prerequisites")
	for lane in ["top", "mid", "bot"]:
		check(_attackable(game, "red_%s_t1" % lane), "%s T1 starts attackable" % lane)
		check(not _attackable(game, "red_%s_t2" % lane), "%s T2 starts locked" % lane)
		check(not _attackable(game, "red_%s_t3" % lane), "%s T3 starts locked" % lane)

	# Lane prerequisite chains are independent, including at combat impact.
	check(not _impact_allowed(game, "red_mid_t2"), "Locked MID T2 rejects damage at impact")
	_destroy(game, "red_top_t1")
	check(not _attackable(game, "red_mid_t2"), "Destroying TOP T1 does not unlock MID T2")
	_destroy(game, "red_mid_t1")
	check(_attackable(game, "red_mid_t2") and _impact_allowed(game, "red_mid_t2"), "Destroying MID T1 unlocks MID T2 for selection and impact")
	_destroy(game, "red_mid_t2")
	check(_attackable(game, "red_mid_t3") and _impact_allowed(game, "red_mid_t3"), "Destroying MID T2 unlocks MID T3 for selection and impact")

	# One destroyed T3 opens both shared T4s; both destroyed T4s open Core.
	check(not _attackable(game, "red_base_guard_left") and not _attackable(game, "red_base_guard_right"), "Both T4 guards stay locked before any T3 falls")
	check(not game._core_is_unlocked(1), "Core stays locked before both T4 guards fall")
	_destroy(game, "red_mid_t3")
	check(_attackable(game, "red_base_guard_left") and _attackable(game, "red_base_guard_right"), "One T3 opens both T4 guards")
	check(_impact_allowed(game, "red_base_guard_left") and _impact_allowed(game, "red_base_guard_right"), "Opened T4 guards accept impact damage")
	check(not game._core_is_unlocked(1), "Core remains locked while either T4 is alive")
	_destroy(game, "red_base_guard_left")
	check(not game._core_is_unlocked(1), "One destroyed T4 does not unlock Core")
	_destroy(game, "red_base_guard_right")
	check(game._core_is_unlocked(1), "Both destroyed T4 guards unlock Core")
	check(game._can_apply_match_damage({}, null, game.cores[1].runtime), "Unlocked Core accepts damage at impact")

	# next_lane_objective may never jump to a base guard or another lane.
	var next = game.objective_registry.next_lane_objective(0, "BOT", game.entities)
	check(next != null and next.id == "red_bot_t1", "Lane query returns only BOT T1, not unlocked MID/T4 objectives")
	_destroy(game, "red_bot_t1")
	next = game.objective_registry.next_lane_objective(0, "BOT", game.entities)
	check(next != null and next.id == "red_bot_t2", "Lane query advances only to next tier in the same lane")
	_destroy(game, "red_bot_t2")
	_destroy(game, "red_bot_t3")
	next = game.objective_registry.next_lane_objective(0, "BOT", game.entities)
	check(next == null, "Lane query stops after T3 instead of selecting T4/Core")

	game.queue_free()
	await process_frame
	print("Objective registry: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
