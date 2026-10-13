extends SceneTree
## Phase-2 executor regressions. Controllers remain intentionally unmigrated.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _actor_snapshot(game, actor_id: String, visible: PackedStringArray) -> BehaviorActorSnapshot:
	var info: Dictionary = game.entities[actor_id]
	var actor: MapUnit = info.actor
	return BehaviorActorSnapshot.new(actor_id, actor.runtime.team_id, actor.runtime.alive, info.kind, actor.position, actor.runtime.stats.collision_radius, actor.runtime.target_id, visible)

func _snapshot(game, tick: int, source_id: String, visible: PackedStringArray) -> BehaviorWorldSnapshot:
	var result := BehaviorWorldSnapshot.new(tick)
	for actor_id in game.entities.keys():
		result.add_actor(_actor_snapshot(game, actor_id, visible if actor_id == source_id else PackedStringArray()))
	return result

func _intent(actor_id: String, target_id: String, destination: Vector2, state: String = "TEST") -> BehaviorIntent:
	return BehaviorIntent.new(actor_id, state, target_id, destination, true, 100, "phase2-test")

func _run() -> void:
	var game = load("res://scenes/match/moba_match.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.clock.set_running(false)
	game.set_physics_process(false)
	var source_id := "player"
	var enemy_id := "enemy_hero"
	var source: MapUnit = game.entities[source_id].actor
	var enemy: MapUnit = game.entities[enemy_id].actor
	var executor := IntentExecutor.new()

	# A visible, alive enemy applies target and one movement order.
	var snapshot := _snapshot(game, 10, source_id, PackedStringArray([enemy_id]))
	executor.begin_tick(10)
	var destination := source.position + Vector2(80, 0)
	check(executor.apply(_intent(source_id, enemy_id, destination), snapshot, game.entities, game.objective_registry), "Legal target intent is applied")
	check(source.runtime.target_id == enemy_id, "Executor writes the approved combat target")
	check(not source.path.is_empty() and source.path[-1].distance_to(destination) < 0.01, "Executor writes the approved navigation destination")
	check(executor.traces.size() == 1 and "tick=10 actor_id=player state=TEST" in executor.traces[0], "Executor trace includes tick, actor, state and reason")

	# A dead target is canceled and clears legacy state rather than leaving stale combat.
	enemy.runtime.alive = false
	snapshot = _snapshot(game, 11, source_id, PackedStringArray([enemy_id]))
	executor.begin_tick(11)
	check(not executor.apply(_intent(source_id, enemy_id, destination), snapshot, game.entities, game.objective_registry), "Dead target intent is rejected")
	check(source.runtime.target_id.is_empty() and source.path.is_empty(), "Rejected target clears target and path")
	enemy.runtime.alive = true

	# A visible but locked T2 cannot be selected, independent of controller logic.
	var locked_t2_id: String = game.tower_registry["red_mid_t2"]
	snapshot = _snapshot(game, 12, source_id, PackedStringArray([locked_t2_id]))
	executor.begin_tick(12)
	check(not executor.apply(_intent(source_id, locked_t2_id, destination, "STRUCTURE_SIEGE"), snapshot, game.entities, game.objective_registry), "Locked objective intent is rejected")
	check(source.runtime.target_id.is_empty(), "Locked objective never becomes combat target")

	# An actor gets at most one order in a tick; second apply cannot replace path.
	var first_destination := source.position + Vector2(110, 0)
	var second_destination := source.position + Vector2(220, 0)
	snapshot = _snapshot(game, 13, source_id, PackedStringArray([enemy_id]))
	executor.begin_tick(13)
	check(executor.apply(_intent(source_id, enemy_id, first_destination), snapshot, game.entities, game.objective_registry), "First order in tick is accepted")
	check(not executor.apply(_intent(source_id, enemy_id, second_destination), snapshot, game.entities, game.objective_registry), "Second movement order in same tick is rejected")
	check(not source.path.is_empty() and source.path[-1].distance_to(first_destination) < 0.01, "First movement order remains authoritative")

	# Equal snapshot and intent produce byte-for-byte identical trace output.
	var deterministic_intent := _intent(source_id, enemy_id, source.position + Vector2(60, 40), "LANE_ADVANCE")
	var traces: Array[String] = []
	for tick in [20, 20]:
		snapshot = _snapshot(game, tick, source_id, PackedStringArray([enemy_id]))
		executor.begin_tick(tick)
		executor.apply(deterministic_intent, snapshot, game.entities, game.objective_registry)
		traces.append(executor.traces[0])
	check(traces[0] == traces[1], "Same snapshot and intent produce deterministic trace")

	game.queue_free()
	await process_frame
	print("Behavior intents: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
