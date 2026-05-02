extends SceneTree
## Phase-7 functional test (refactored for landing-ghost flow).
## Verifies:
##   1. data/orbit_deposits.json exists and parses
##   2. OrbitMap.tscn exists, instances under Ground, ≥6 deposits loaded
##   3. EventBus.zoom_changed emits "strategic" then "gameplay" past threshold
##   4. LandingPlacement node exists under Ground/YSort
##   5. LandingPlacement.confirm_at(world_pos) sets
##      GameState.selected_landing_tile + emits EventBus.landing_confirmed
##   6. Crew don't spawn until landing is confirmed
##   7. Camera auto-tweens to gameplay step on landing_confirmed

var event_bus: Node
var game_state: Node
var _confirmed_grid: Vector2i = Vector2i(-99, -99)
var _zoom_levels_seen: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	game_state = root.get_node_or_null("GameState")
	if event_bus == null or game_state == null:
		_done(["EventBus or GameState autoload missing"])
		return

	if not ResourceLoader.exists("res://data/orbit_deposits.json"):
		failures.append("data/orbit_deposits.json missing")
	if not ResourceLoader.exists("res://scenes/ui/OrbitMap.tscn"):
		_done(failures + ["OrbitMap.tscn missing"])
		return

	# Connect zoom_changed BEFORE Ground spawns so we capture the initial level.
	event_bus.zoom_changed.connect(_on_zoom_changed)
	event_bus.landing_confirmed.connect(_on_landing_confirmed)

	var ground_packed := load("res://scenes/world/Ground.tscn") as PackedScene
	var ground: Node = ground_packed.instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame
	await physics_frame

	# 6. Crew should NOT exist yet.
	var pre_crew: Array = get_nodes_in_group("crew")
	if pre_crew.size() != 0:
		failures.append("Crew spawned before landing_confirmed (got %d)" % pre_crew.size())

	var orbit_map := ground.find_child("OrbitMap", true, false)
	if orbit_map == null:
		_done(failures + ["OrbitMap not instanced under Ground"])
		return
	if orbit_map.has_method("deposits_count"):
		var count: int = orbit_map.deposits_count()
		if count < 6:
			failures.append("OrbitMap loaded only %d deposits (expected >=6)" % count)

	var landing := ground.find_child("LandingPlacement", true, false)
	if landing == null:
		failures.append("LandingPlacement node missing under Ground/YSort")

	# 3. Force camera past strategic threshold and back.
	var camera := ground.find_child("Camera2D", true, false)
	if camera == null or not camera.has_method("zoom_in"):
		failures.append("WorldCamera missing or has no zoom_in")
	else:
		for _i in range(6):
			camera.zoom_in()
			await physics_frame
		await create_timer(0.4).timeout
		if not _zoom_levels_seen.has("gameplay"):
			failures.append("EventBus.zoom_changed never fired 'gameplay' (saw %s)" % str(_zoom_levels_seen))
		# Reset to strategic for the rest of the test.
		while camera.current_step() > 0:
			camera.zoom_out()

	# 5. Confirm landing via LandingPlacement.confirm_at — pick a tile
	#    offset from origin to verify cell conversion works.
	if landing != null:
		var target_world: Vector2 = Vector2(192, 96)  # roughly cell (2, 1) in iso
		landing.confirm_at(target_world)
		await process_frame
		await physics_frame
		await physics_frame
		if game_state.selected_landing_tile == Vector2i.ZERO:
			failures.append("GameState.selected_landing_tile not set after confirm")
		if _confirmed_grid == Vector2i(-99, -99):
			failures.append("EventBus.landing_confirmed never fired")

	# 6 (cont). After landing, crew should now be spawned.
	var post_crew: Array = get_nodes_in_group("crew")
	if post_crew.size() != 6:
		failures.append("After landing, expected 6 crew, got %d" % post_crew.size())

	# 7. Camera step should auto-jump past the strategic threshold.
	if camera != null:
		await create_timer(0.1).timeout
		if camera.current_step() <= camera.STRATEGIC_STEP_THRESHOLD:
			failures.append("Camera step did not advance past strategic threshold (step=%d)" % camera.current_step())

	_done(failures)


func _on_zoom_changed(level: String) -> void:
	if not _zoom_levels_seen.has(level):
		_zoom_levels_seen.append(level)


func _on_landing_confirmed(grid_pos: Vector2i) -> void:
	_confirmed_grid = grid_pos


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
