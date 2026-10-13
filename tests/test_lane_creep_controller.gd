extends SceneTree
## Contract 5 regression coverage for the migrated lane-creep controller.

var checks := 0
var failures := 0
var controller := LaneCreepController.new()
var settings := MatchSettings.new()

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func actor(id: String, team: int, kind: String, lane: String, position: Vector2, neutral: bool = false, visible: PackedStringArray = []) -> BehaviorActorSnapshot:
	return BehaviorActorSnapshot.new(id, team, true, kind, lane, neutral, position, 20.0, 100.0, "", visible)

func snapshot(tick: int, entries: Array[BehaviorActorSnapshot], facts: Array[BehaviorFact] = []) -> BehaviorWorldSnapshot:
	var result := BehaviorWorldSnapshot.new(tick, facts)
	for entry in entries: result.add_actor(entry)
	result.set_lane_configured(0, "MID", true)
	result.set_lane_configured(1, "MID", true)
	return result

func memory(id: String = "blue_creep") -> LaneCreepMemory:
	return LaneCreepMemory.new(id, "MID", PackedVector2Array([Vector2.ZERO, Vector2(1000, 0)]))

func _run() -> void:
	# Waves select the opposing lane creep before an objective or waypoint.
	var blue := actor("blue_creep", 0, "creep", "MID", Vector2.ZERO, false, PackedStringArray(["red_creep"]))
	var red := actor("red_creep", 1, "creep", "MID", Vector2(300, 0), false, PackedStringArray(["blue_creep"]))
	var view := snapshot(10, [blue, red])
	var first := controller.decide(view, memory(), settings)
	var second := controller.decide(view, memory("red_creep"), settings)
	check(first.state == "LANE_COMBAT" and first.target_id == "red_creep", "Wave creep selects opposing same-lane creep")
	check(second.state == "LANE_COMBAT" and second.target_id == "blue_creep", "Opposing wave selects back before advance")

	# The world snapshot receives its only objective candidate from ObjectiveRegistry.
	var t1 := actor("red_mid_t1_runtime", 1, "tower", "MID", Vector2(300, 0), false, PackedStringArray())
	view = snapshot(11, [blue, t1])
	view.set_lane_objective(0, "MID", t1.actor_id)
	var siege := controller.decide(view, memory(), settings)
	check(siege.state == "STRUCTURE_SIEGE" and siege.target_id == t1.actor_id, "Creep sieges snapshot's next lane T1")
	var t2 := actor("red_mid_t2_runtime", 1, "tower", "MID", Vector2(300, 0), false, PackedStringArray())
	view = snapshot(12, [blue, t2])
	view.set_lane_objective(0, "MID", t2.actor_id)
	siege = controller.decide(view, memory(), settings)
	check(siege.target_id == t2.actor_id, "After registry advances, creep can siege only next T2")
	var t4 := actor("red_base_guard_runtime", 1, "tower", "BASE", Vector2(250, 0), false, PackedStringArray())
	view = snapshot(13, [blue, t4])
	var no_base := controller.decide(view, memory(), settings)
	check(no_base.target_id.is_empty() and no_base.state == "LANE_ADVANCE", "Creep never substitutes T4/Core when lane objective is absent")

	# Nearby neutral creep is not a lane-combat candidate.
	var jungle := actor("jungle", 2, "creep", "MID", Vector2(50, 0), true, PackedStringArray())
	view = snapshot(14, [blue, jungle])
	var no_jungle := controller.decide(view, memory(), settings)
	check(no_jungle.target_id.is_empty(), "Lane creep never selects nearby jungle creep")

	# Direct hero damage is the only hero target entry point and obeys its leash.
	var ally := actor("ally_hero", 0, "hero", "MID", Vector2(100, 0), false, PackedStringArray())
	var aggressor := actor("enemy_hero", 1, "hero", "MID", Vector2(150, 0), false, PackedStringArray())
	blue.visible_target_ids = PackedStringArray(["enemy_hero"])
	var fact := BehaviorFact.new(BehaviorFact.Kind.HERO_DAMAGE, "enemy_hero", "ally_hero", 14, 15, "DIRECT_HERO_DAMAGE")
	view = snapshot(15, [blue, ally, aggressor], [fact])
	var retaliation_memory := memory()
	var retaliation := controller.decide(view, retaliation_memory, settings)
	check(retaliation.state == "HERO_RETALIATE" and retaliation.target_id == "enemy_hero", "Direct hero damage selects only the aggressor")
	aggressor.position = Vector2(settings.creep_hero_leash_range + 1.0, 0)
	view = snapshot(16, [blue, ally, aggressor])
	var return_intent := controller.decide(view, retaliation_memory, settings)
	check(return_intent.state == "RETURN_TO_LANE" and return_intent.target_id.is_empty(), "Hero beyond retaliation leash is dropped and creep returns to lane")

	# Missing registry configuration fails safely; decision replay is deterministic.
	view = snapshot(17, [blue])
	view.set_lane_configured(0, "MID", false)
	var config_error := controller.decide(view, memory(), settings)
	check(config_error.state == "CONFIG_ERROR" and config_error.target_id.is_empty() and not config_error.has_destination, "Missing lane registry enters safe CONFIG_ERROR")
	view = snapshot(18, [blue], [BehaviorFact.new(BehaviorFact.Kind.TARGET_INVALID, "blue_creep", "missing_target", 17, 18, "UNREACHABLE")])
	var path_fallback := controller.decide(view, memory(), settings)
	check(path_fallback.state == "RETURN_TO_LANE" and path_fallback.target_id.is_empty(), "Invalid/path-failed target produces RETURN_TO_LANE intent")
	view = snapshot(19, [blue, red])
	var replay_a := controller.decide(view, memory(), settings)
	var replay_b := controller.decide(view, memory(), settings)
	check(replay_a.state == replay_b.state and replay_a.target_id == replay_b.target_id and replay_a.destination == replay_b.destination, "Same snapshot produces deterministic lane intent")

	print("Lane creep controller: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
