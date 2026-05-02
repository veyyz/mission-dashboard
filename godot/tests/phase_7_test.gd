extends SceneTree
## Phase-7 functional test.
## Verifies:
##   1. data/orbit_deposits.json exists and parses
##   2. OrbitMap.tscn exists and instances under Ground
##   3. OrbitMap loads ≥6 deposits (10×10 strategic grid)
##   4. EventBus.zoom_changed signal exists; world_camera emits it
##   5. Confirm Landing stores GameState.selected_landing_tile and
##      emits EventBus.landing_confirmed
##   6. After confirmation, GameState.selected_landing_tile equals the
##      suggested tile (since no marker was clicked, default applies)

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

	# 1. JSON exists.
	if not ResourceLoader.exists("res://data/orbit_deposits.json"):
		failures.append("data/orbit_deposits.json missing")
	else:
		var f := FileAccess.open("res://data/orbit_deposits.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			failures.append("orbit_deposits.json did not parse to a Dictionary")

	# 2. OrbitMap scene exists.
	if not ResourceLoader.exists("res://scenes/ui/OrbitMap.tscn"):
		_done(failures + ["OrbitMap.tscn missing"])
		return

	# Boot the world.
	var ground_packed := load("res://scenes/world/Ground.tscn") as PackedScene
	var ground: Node = ground_packed.instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame
	await physics_frame

	var orbit_map := ground.find_child("OrbitMap", true, false)
	if orbit_map == null:
		_done(failures + ["OrbitMap not instanced under Ground"])
		return

	# 3. ≥6 deposits loaded.
	if orbit_map.has_method("deposits_count"):
		var count: int = orbit_map.deposits_count()
		if count < 6:
			failures.append("OrbitMap loaded only %d deposits (expected >=6)" % count)
	else:
		failures.append("OrbitMap.deposits_count() method missing")

	# 4. zoom_changed signal exists + emits.
	event_bus.zoom_changed.connect(_on_zoom_changed)
	# Force a couple of zoom-in steps to cross the strategic→gameplay threshold.
	var camera := ground.find_child("Camera2D", true, false)
	if camera == null or not camera.has_method("zoom_in"):
		failures.append("WorldCamera not found or missing zoom_in method")
	else:
		# Initial level should be "strategic" (camera starts at step 0).
		# Click zoom_in until past threshold (step > 2).
		for _i in range(6):
			camera.zoom_in()
			await physics_frame
		await create_timer(0.4).timeout
		if not _zoom_levels_seen.has("gameplay"):
			failures.append("EventBus.zoom_changed never fired 'gameplay' (saw %s)" % str(_zoom_levels_seen))

	# 5 + 6. Confirm Landing — no marker clicked, so it should fall back to suggested tile.
	event_bus.landing_confirmed.connect(_on_landing_confirmed)
	var confirm_btn := orbit_map.find_child("ConfirmButton", true, false)
	if confirm_btn == null:
		failures.append("Confirm Landing button missing")
	else:
		confirm_btn.emit_signal("pressed")
		await process_frame
		var suggested: Vector2i = orbit_map.suggested_tile()
		if game_state.selected_landing_tile != suggested:
			failures.append(
				"GameState.selected_landing_tile != suggested: got %s expected %s" % [
					game_state.selected_landing_tile, suggested,
				]
			)
		if _confirmed_grid != suggested:
			failures.append(
				"EventBus.landing_confirmed grid_pos != suggested: got %s expected %s" % [
					_confirmed_grid, suggested,
				]
			)

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
