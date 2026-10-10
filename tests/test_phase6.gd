extends SceneTree
var checks := 0
var failures := 0
var data: MapLayout = preload("res://data/maps/moba_foundation.tres")

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func near(value: float, expected: float, message: String) -> void:
	check(absf(value - expected) < 0.001, "%s: %.3f != %.3f" % [message, value, expected])

func _run() -> void:
	_test_data_and_navigation()
	await _test_scene()
	print("Phase 6: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_data_and_navigation() -> void:
	check(data.validation_errors().is_empty(), "Authored map validates")
	check(data.dimensions == Vector2i(40, 40) and data.tile_size == 128, "Configurable dimensions and tile size loaded")
	check(data.spawn_points(0)[0].x < data.world_size().x * 0.5 and data.spawn_points(0)[0].y > data.world_size().y * 0.5, "Blue base bottom-left")
	check(data.spawn_points(1)[0].x > data.world_size().x * 0.5 and data.spawn_points(1)[0].y < data.world_size().y * 0.5, "Red base top-right")
	var terrain_counts: Dictionary = {}
	for row in data.cells:
		for symbol in row: terrain_counts[symbol] = terrain_counts.get(symbol, 0) + 1
	for symbol in [".", "J", "L", "W", "#", "B", "R"]: check(terrain_counts.get(symbol, 0) > 0, "Required terrain exists: " + symbol)
	check(data.tower_cells.size() >= 6 and data.spawn_points(0).size() == 5 and data.spawn_points(1).size() == 5, "Tower markers and future 5v5 spawn locations configured")
	check(data.route("TOP", 0) != data.route("MID", 0) and data.route("MID", 0) != data.route("BOT", 0), "Three distinct data-driven routes")
	var navigation := MapNavigation.new(data)
	for lane in ["TOP", "MID", "BOT"]:
		for team in range(2):
			var route := data.route(lane, team)
			check(route[0] == data.spawn_points(team)[0] and route[-1] == data.spawn_points(1 - team)[0], "%s team %d ordered base-to-base route" % [lane, team])
			var path := navigation.lane_path(route[0], lane, team)
			check(not path.is_empty() and path[-1] == route[-1], "Navigable lane " + lane)
			for point in path: check(navigation.point_is_clear(point), "Lane navigation respects terrain and radius")
			var waypoint_index := 0
			for point in path:
				if waypoint_index < route.size() and point == route[waypoint_index]: waypoint_index += 1
			check(waypoint_index == route.size(), "All lane waypoints visited in order")
	check(not navigation.path(data.spawn_points(0)[0], data.spawn_points(1)[0]).is_empty(), "Both bases reachable")
	check(navigation.path(data.spawn_points(0)[0], data.cell_center(Vector2i(10, 8))).is_empty(), "Blocked target rejected")
	check(navigation.path(data.spawn_points(0)[0], Vector2(-100, -100)).is_empty(), "Out-of-map target rejected")
	check(not navigation.point_is_clear(Vector2(128 + 31, 400)), "Disk clearance prevents terrain overlap")
	var passage := data.cell_center(Vector2i(14, 24))
	check(not navigation.path(data.spawn_points(0)[0], passage).is_empty(), "Jungle passage reachable")
	check(navigation.grid.diagonal_mode == AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES, "No diagonal corner cutting")
	var large_agent := MapNavigation.new(data, 70)
	check(not large_agent.path(data.spawn_points(0)[0], data.spawn_points(1)[0]).is_empty(), "Larger future agents can navigate map corridors")
	var small_map := MapLayout.new()
	small_map.dimensions = Vector2i(6, 4)
	small_map.tile_size = 80
	small_map.cells = ["######", "#....#", "#....#", "######"]
	small_map.terrain_definitions = data.terrain_definitions
	var other_navigation := MapNavigation.new(small_map, 16)
	check(other_navigation.path(Vector2(120, 120), Vector2(360, 200))[-1] == Vector2(360, 200), "Different dimensions/tile size work without gameplay edits")
	check(other_navigation.path(Vector2(120, 120), Vector2(350, 210))[-1] == Vector2(350, 210), "Exact non-cell-center world destination retained")
	var invalid: MapLayout = data.duplicate(true)
	invalid.cells[0] = "bad"
	check(not invalid.validation_errors().is_empty(), "Invalid layout reports authoring errors")

func frames(count: int) -> void:
	for frame in range(count): await physics_frame

func _test_scene() -> void:
	var main = load("res://scenes/map/map_prototype.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await frames(2)
	main.set_process(false) # Input steering is tested separately.
	var camera = main.camera
	camera.set_process(false)
	check(main.units.size() == 2 and main.selected_unit == main.units[0], "Map scene creates/selects two existing unit probes")
	check(main.world.get_node("TerrainCollision").get_child_count() > 0, "Blocked terrain has real physics shapes")
	var blue: MapUnit = main.units[0]
	var red: MapUnit = main.units[1]
	check(blue.runtime.stats.physical_damage > 0 and blue.view.show_resource_bars == false, "Existing unit data/view reused without combat")
	for lane in ["TOP", "MID", "BOT"]:
		for unit in main.units:
			unit.position = data.spawn_points(unit.runtime.team_id)[0]
			unit.runtime.position = unit.position
			unit.runtime.stats.movement_speed = 24000
			check(unit.follow_lane(lane), "Probe accepts route " + lane)
			var reached := false
			for tick in range(180):
				await physics_frame
				check(unit.navigation.point_is_clear(unit.position), "Continuous movement never overlaps blocked terrain")
				if unit.position.distance_to(data.spawn_points(1 - unit.runtime.team_id)[0]) < 1:
					reached = true
					break
			check(reached, "Physical probe navigates entire %s route for team %d" % [lane, unit.runtime.team_id])
			unit.stop()
	main.reset_probes()
	blue.runtime.stats.movement_speed = 300
	var before := blue.position
	check(blue.go_to(before + Vector2(40, 20)), "World coordinate destination accepted")
	await frames(2)
	check(blue.position != before and blue.position.distance_to(before) < data.tile_size, "Unit moves continuously, not tile jumps")
	blue.paused = true
	before = blue.position
	await frames(3)
	check(blue.position == before, "Pause freezes navigation probe")
	blue.paused = false
	blue.stop()
	# Direct high-speed drive against the solid perimeter tests physics, not A*.
	blue.position = Vector2(300, 800)
	blue.manual_direction = Vector2.LEFT
	blue.runtime.stats.movement_speed = 20000
	await frames(8)
	check(blue.position.x >= 128 + blue.runtime.stats.collision_radius - 0.1, "Collision prevents crossing wall even at high velocity")
	check(blue.navigation.point_is_clear(blue.position), "Physics position stays clear of wall")
	blue.manual_direction = Vector2.ZERO
	blue.stop()
	main.select_unit(red)
	check(camera.follow_target == red and main.selection.selected == 1, "Selection updates camera follow target")
	camera.follow_enabled = true
	camera._process(0)
	check(camera.position.distance_to(red.position) < 1500, "Camera follows selected unit subject to bounds")
	camera.follow_enabled = false
	camera.set_zoom_level(0.8)
	camera.position = data.world_size() * 0.5
	before = camera.position
	camera.pan_by(Vector2(100, 50))
	check(camera.position == before + Vector2(100, 50), "Camera pan works")
	red.position = data.world_size() * 0.5 + Vector2(100, 100)
	camera.follow_enabled = true
	camera._process(0)
	check(camera.position == red.position, "Camera follows selected probe after it moves")
	camera.follow_enabled = false
	camera.position = data.world_size() * 0.5
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	middle.position = Vector2(1000, 650)
	root.push_input(middle, true)
	before = camera.position
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1040, 670)
	motion.relative = Vector2(40, 20)
	root.push_input(motion, true)
	check(camera.position == before - motion.relative / camera.zoom, "Desktop middle-drag pans camera")
	middle.pressed = false
	middle.position = Vector2(30, 30)
	root.push_input(middle, true)
	check(not camera.dragging, "Dragging releases safely over UI")
	for value in [0.15, 0.5, 1.6]:
		camera.set_zoom_level(value)
		near(camera.zoom.x, value, "Camera zoom level")
		for point in [Vector2(-10000, -10000), Vector2(10000, 10000)]:
			camera.position = point
			camera.clamp_to_map()
			var half_view: Vector2 = camera.get_viewport_rect().size / (camera.zoom * 2)
			for axis in range(2):
				if half_view[axis] >= data.world_size()[axis] * 0.5:
					near(camera.position[axis], data.world_size()[axis] * 0.5, "Oversized viewport axis centered")
				else:
					check(camera.position[axis] >= half_view[axis] - 0.001 and camera.position[axis] <= data.world_size()[axis] - half_view[axis] + 0.001, "Camera viewport stays in map bounds")
	camera.set_zoom_level(100)
	near(camera.zoom.x, camera.maximum_zoom, "Maximum zoom clamped")
	camera.set_zoom_level(0.001)
	near(camera.zoom.x, camera.minimum_zoom, "Minimum zoom clamped")
	for key in main.overlay_controls:
		main.overlay_controls[key].button_pressed = true
		check(blue.show_collision if key == "collision" else main.world.get(key + "_overlay"), "Debug overlay enabled: " + key)
		main.overlay_controls[key].button_pressed = false
		check(not blue.show_collision if key == "collision" else not main.world.get(key + "_overlay"), "Debug overlay disabled: " + key)
	main.reset_probes()
	main.select_unit(blue)
	blue.runtime.stats.movement_speed = 300
	blue.paused = true
	camera.follow_enabled = true
	camera.set_zoom_level(0.7)
	camera._process(0)
	camera.force_update_scroll()
	await process_frame
	# Use the viewport event path, including camera and project stretch transforms.
	var target := blue.position + Vector2(60, -60)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = main.get_global_transform_with_canvas() * target
	root.push_input(event, true)
	check(not blue.path.is_empty() and blue.path[-1].distance_to(target) < 0.001, "Right-click converts screen to correct map world destination")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(1000, 650)
	var zoom_before: float = camera.zoom.x
	root.push_input(wheel, true)
	check(camera.zoom.x > zoom_before, "Desktop wheel zoom input works")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		camera.fit_map()
		main.overlay_controls.waypoints.button_pressed = true
		main.overlay_controls.spawns.button_pressed = true
		main.overlay_controls.towers.button_pressed = true
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/phase6-map-overview.png") == OK, "Map overview captured with renderer")
		camera.set_zoom_level(0.7)
		camera.follow_enabled = true
		camera._process(0)
		main.overlay_controls.grid.button_pressed = true
		main.overlay_controls.walkability.button_pressed = true
		main.overlay_controls.collision.button_pressed = true
		main.overlay_controls.paths.button_pressed = true
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.local/phase6-map-navigation.png") == OK, "Map closeup captured with renderer")
	main.queue_free()
	await process_frame
	var sandbox = load("res://scenes/main.tscn").instantiate()
	root.add_child(sandbox)
	await process_frame
	check(sandbox.combat.units.size() == 2, "Separate Combat Sandbox still loads")
	sandbox.clock.set_running(true)
	sandbox.clock.advance(2)
	check(sandbox.combat.tick_count == 60, "Existing fixed-step combat still runs")
	current_scene = sandbox
	sandbox.find_child("MapPrototypeButton", true, false).pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "MapPrototype", "Project button opens Map Prototype mode")
	current_scene.find_child("CombatSandbox", true, false).pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "Clashborn" and current_scene.combat.units.size() == 2, "Map button returns to preserved Combat Sandbox")
	current_scene.queue_free()
	await process_frame
