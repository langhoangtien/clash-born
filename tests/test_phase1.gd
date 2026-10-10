extends SceneTree
## Native headless tests; -- --capture also verifies a rendered viewport.

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	var clock := SimulationClock.new()
	var emitted: Array[int] = []
	clock.ticked.connect(func(index: int): emitted.append(index))
	clock.advance(1.0)
	_check(clock.tick_count == 0, "Starts paused")
	clock.step()
	_check(clock.tick_count == 1 and emitted == [1], "Step emits one indexed tick")
	clock.set_running(true)
	clock.step()
	_check(clock.tick_count == 1, "Step cannot advance a running clock")
	clock.advance(1.0)
	_check(clock.tick_count == 31, "One second produces 30 ticks")
	clock.set_running(false)
	clock.advance(2.0)
	_check(clock.tick_count == 31, "Pause freezes clock")
	clock.reset()
	_check(clock.tick_count == 0 and not clock.running and clock.elapsed_seconds() == 0, "Reset pauses and clears time")
	for speed in SimulationClock.SPEEDS:
		clock.reset()
		clock.set_speed(speed)
		clock.set_running(true)
		clock.advance(1.0 / speed)
		_check(clock.tick_count == 30, "Speed %s preserves fixed tick count" % speed)
	clock.set_speed(7.0)
	_check(clock.speed == 4.0, "Unsupported speed is ignored")
	var split := SimulationClock.new()
	split.set_running(true)
	for frame in range(144):
		split.advance(1.0 / 144.0)
	_check(split.tick_count == 30, "144 rendering frames yield the same 30 simulation ticks")
	split.reset()
	split.set_running(true)
	split.advance(SimulationClock.TICK_SECONDS * 0.5)
	split.set_running(false)
	split.advance(10)
	split.set_running(true)
	split.advance(SimulationClock.TICK_SECONDS * 0.5)
	_check(split.tick_count == 1, "Pause/resume preserves fractional tick")
	split.reset()
	split.set_running(true)
	split.advance(SimulationClock.TICK_SECONDS * 0.5)
	_check(split.tick_count == 0, "Reset clears fractional time")

	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "Main scene loads")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.views.size() == 2 and main.combat.units.size() == 2, "Arena contains exactly two combat units, plus projectile presentation")
	var blue = main.get_node("Arena/BlueUnit")
	var red = main.get_node("Arena/RedUnit")
	_check(blue.visible and red.visible and blue.position != red.position, "Two visible units at distinct positions")
	_check(blue.visual_data.unit_id == "blue_01" and red.visual_data.unit_id == "red_01", "Stable resource unit identifiers")
	main.run_button.pressed.emit()
	_check(main.clock.running and main.step_button.disabled, "Start button runs clock and disables step")
	main.run_button.pressed.emit()
	_check(not main.clock.running, "Pause button pauses clock")
	main.step_button.pressed.emit()
	_check(main.clock.tick_count == 1 and "Tick 1" in main.status_label.text, "Step button updates clock and UI")
	main.run_button.pressed.emit()
	_check(main.clock.running, "Resume button resumes clock")
	main._reset()
	_check(main.clock.tick_count == 0 and main.run_button.text == "Start", "Reset restores UI state")

	if "--capture" in OS.get_cmdline_user_args():
		_check(DisplayServer.get_name() != "headless", "Capture requires a rendering display")
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			_check(not image.is_empty(), "Rendered viewport is available")
			DirAccess.make_dir_recursive_absolute("res://.local")
			_check(image.save_png("res://.local/phase1-preview.png") == OK, "Rendered screenshot saved")
	main.queue_free()
	await process_frame
	print("Phase 1: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
