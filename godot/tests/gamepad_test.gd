extends SceneTree
## Gamepad functional test (generic BT pad: 1 stick + 3 buttons).
## Verifies:
##   1. pad_confirm / pad_cancel / pad_mode exist and carry the joypad button
##      indices from data/gamepad.json
##   2. move_* actions carry a joypad motion event on the configured axes, at
##      the configured deadzone
##   3. PadInput toggles CREW <-> CURSOR and emits EventBus.pad_mode_changed
##   4. Stick deflection in CURSOR mode moves the virtual cursor
##   5. A synthesized pointer click in CURSOR mode reaches
##      BuildPlacementController and spawns a ConstructionSite
##   6. cycle_focus walks the full ring (crew 1..MAX_CREW -> free explore -> 1)
##   7. Stick deflection in free explore pans the camera and moves no crew
##   8. Keyboard crew movement still works after the get_vector rewrite

var event_bus: Node
var game_state: Node
var pad_input: Node
var resource_manager: Node
var time_manager: Node

var _mode_events: Array[int] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	game_state = root.get_node_or_null("GameState")
	pad_input = root.get_node_or_null("PadInput")
	resource_manager = root.get_node_or_null("ResourceManager")
	time_manager = root.get_node_or_null("TimeManager")
	for pair in [
		["EventBus", event_bus], ["GameState", game_state], ["PadInput", pad_input],
		["ResourceManager", resource_manager], ["TimeManager", time_manager],
	]:
		if pair[1] == null:
			failures.append("Autoload missing: %s" % pair[0])
	if not failures.is_empty():
		_done(failures)
		return

	var cfg: Dictionary = game_state.pad_config

	# --- 1. Button actions bound to the configured raw indices ---------------
	var expected_buttons := {
		"pad_confirm": int(cfg.get("button_confirm", -1)),
		"pad_cancel":  int(cfg.get("button_cancel", -1)),
		"pad_mode":    int(cfg.get("button_mode", -1)),
	}
	for action in expected_buttons:
		if not InputMap.has_action(action):
			failures.append("InputMap missing action '%s'" % action)
			continue
		var found: bool = false
		for ev in InputMap.action_get_events(action):
			var btn := ev as InputEventJoypadButton
			if btn != null and btn.button_index == expected_buttons[action]:
				found = true
		if not found:
			failures.append(
				"Action '%s' has no joypad button event at index %d" % [action, expected_buttons[action]]
			)

	# --- 2. Stick bound to the move_* actions, deadzone applied -------------
	var axis_x: int = int(cfg.get("axis_x", 0))
	var axis_y: int = int(cfg.get("axis_y", 1))
	var deadzone: float = float(cfg.get("deadzone", 0.22))
	var expected_axes := {
		"move_left": axis_x, "move_right": axis_x,
		"move_up": axis_y, "move_down": axis_y,
	}
	for action in expected_axes:
		var found: bool = false
		for ev in InputMap.action_get_events(action):
			var motion := ev as InputEventJoypadMotion
			if motion != null and motion.axis == expected_axes[action]:
				found = true
		if not found:
			failures.append("Action '%s' has no joypad motion event on axis %d" % [action, expected_axes[action]])
		if absf(InputMap.action_get_deadzone(action) - deadzone) > 0.001:
			failures.append(
				"Action '%s' deadzone is %.3f, expected %.3f" % [
					action, InputMap.action_get_deadzone(action), deadzone,
				]
			)

	# Re-running the setup must not stack duplicate events.
	var before: int = InputMap.action_get_events("move_up").size()
	game_state._setup_input_map()
	if InputMap.action_get_events("move_up").size() != before:
		failures.append("_setup_input_map is not idempotent — move_up event count changed")

	# --- 3. Mode toggle ------------------------------------------------------
	event_bus.pad_mode_changed.connect(_on_pad_mode_changed)
	pad_input.set_mode(pad_input.PadMode.CREW)
	_mode_events.clear()
	pad_input.toggle_mode()
	if pad_input.mode != pad_input.PadMode.CURSOR:
		failures.append("toggle_mode did not enter CURSOR")
	if not pad_input.suppresses_crew_movement():
		failures.append("CURSOR mode must suppress crew movement")
	pad_input.toggle_mode()
	if pad_input.mode != pad_input.PadMode.CREW:
		failures.append("toggle_mode did not return to CREW")
	if _mode_events.size() != 2:
		failures.append("Expected 2 pad_mode_changed emissions, got %d" % _mode_events.size())

	# --- Boot the world ------------------------------------------------------
	var packed := load("res://scenes/world/Ground.tscn") as PackedScene
	if packed == null:
		_done(failures + ["Ground.tscn missing"])
		return
	var ground: Node = packed.instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame
	# Phase-7 landing flow: crew don't spawn until landing_confirmed.
	event_bus.landing_confirmed.emit(Vector2i.ZERO)
	await process_frame
	await physics_frame

	var manager: Node = get_first_node_in_group("crew_manager")
	var camera: Node = get_first_node_in_group("world_camera")
	if manager == null:
		failures.append("CrewSelectionManager did not join the 'crew_manager' group")
	if camera == null:
		failures.append("WorldCamera missing from the 'world_camera' group")
	if manager == null or camera == null:
		_done(failures)
		return

	# Freeze the economy so placement deductions are measurable.
	time_manager.set_time_scale(0.0)

	# --- 4. Cursor moves on stick deflection --------------------------------
	pad_input.set_mode(pad_input.PadMode.CURSOR)
	pad_input.set_cursor_position(Vector2(400, 300))
	var start_pos: Vector2 = pad_input.cursor_position()
	pad_input.drive_cursor(Vector2(1, 0), 0.1)
	var moved: Vector2 = pad_input.cursor_position()
	if moved.x <= start_pos.x:
		failures.append("Cursor did not move right on stick deflection (%s -> %s)" % [start_pos, moved])
	if not is_equal_approx(moved.y, start_pos.y):
		failures.append("Cursor drifted vertically on a horizontal deflection")

	# Cursor stays inside the viewport.
	pad_input.drive_cursor(Vector2(-1, -1), 10.0)
	var clamped: Vector2 = pad_input.cursor_position()
	if clamped.x < 0.0 or clamped.y < 0.0:
		failures.append("Cursor escaped the viewport: %s" % clamped)

	# --- 5. Synthetic click reaches BuildPlacementController ----------------
	var placement: Node = ground.find_child("BuildPlacementController", true, false)
	if placement == null:
		failures.append("BuildPlacementController missing in Ground.tscn")
	else:
		for r_name in ["solar_cells", "alloy_beams", "wiring"]:
			resource_manager.add(r_name, 100.0)
		var sites_before: int = get_nodes_in_group("construction_sites").size()
		placement.start_placement("solar_array")
		if not placement.is_placing():
			failures.append("start_placement did not enter placement mode")
		pad_input.set_cursor_position(Vector2(600, 400))
		pad_input.send_pointer(MOUSE_BUTTON_LEFT, true)
		pad_input.send_pointer(MOUSE_BUTTON_LEFT, false)
		await process_frame
		await physics_frame
		var sites_after: int = get_nodes_in_group("construction_sites").size()
		if sites_after <= sites_before:
			failures.append(
				"Pad click did not place a construction site (before=%d after=%d)" % [
					sites_before, sites_after,
				]
			)
		# Right click cancels a pending ghost.
		placement.start_placement("solar_array")
		pad_input.send_pointer(MOUSE_BUTTON_RIGHT, true)
		pad_input.send_pointer(MOUSE_BUTTON_RIGHT, false)
		await process_frame
		await physics_frame
		if placement.is_placing():
			failures.append("Pad cancel did not exit placement mode")

	pad_input.set_mode(pad_input.PadMode.CREW)

	# --- 6. The focus ring (MAX_CREW crew + a free-explore slot) ------------
	manager._select(1, false)
	await physics_frame
	for expected_id in range(2, manager.MAX_CREW + 1):
		manager.cycle_focus(1)
		await physics_frame
		if not manager.has_selection():
			failures.append("cycle_focus lost the selection before reaching crew %d" % expected_id)
			break
		var sel: Node = manager._first_selected()
		if sel != null and sel.crew_id != expected_id:
			failures.append("cycle_focus expected crew %d, got %d" % [expected_id, sel.crew_id])

	# Seventh slot is free explore.
	manager.cycle_focus(1)
	await physics_frame
	if manager.has_selection():
		failures.append("Free-explore slot still has a crew selected")
	if camera.current_mode() != camera.CameraMode.PAN:
		failures.append("Free explore did not switch the camera to PAN")
	if pad_input.crew_manager() != manager:
		failures.append("PadInput could not resolve the crew manager by group")

	# --- 7. Stick pans the camera in free explore, moves no crew ------------
	var crew_positions: Array[Vector2] = []
	for node in get_nodes_in_group("crew"):
		crew_positions.append((node as Node2D).global_position)
	var cam_before: Vector2 = (camera as Node2D).global_position
	pad_input.pan_camera(Vector2(1, 0), 0.2)
	await physics_frame
	if (camera as Node2D).global_position.is_equal_approx(cam_before):
		failures.append("Free-explore stick did not pan the camera")
	var i: int = 0
	for node in get_nodes_in_group("crew"):
		if not (node as Node2D).global_position.is_equal_approx(crew_positions[i]):
			failures.append("Crew moved during free explore")
			break
		i += 1

	# Cycling on returns to crew 1 and re-locks FOLLOW.
	manager.cycle_focus(1)
	await physics_frame
	var back: Node = manager._first_selected()
	if back == null or back.crew_id != 1:
		failures.append("Cycling past free explore did not return to crew 1")
	if camera.current_mode() != camera.CameraMode.FOLLOW:
		failures.append("Leaving free explore did not restore FOLLOW")

	# --- 8. Keyboard movement survives the get_vector rewrite ---------------
	var walker: Node2D = manager._first_selected()
	if walker == null:
		failures.append("No crew selected for the movement regression check")
	else:
		walker.set("follow_leader", null)
		walker.get("agent").target_position = Vector2.ZERO
		var pos_before: Vector2 = walker.global_position
		Input.action_press("move_up")
		for _f in range(30):
			await physics_frame
		Input.action_release("move_up")
		if walker.global_position.y >= pos_before.y:
			failures.append(
				"move_up did not move the crew up (before=%s after=%s)" % [
					pos_before, walker.global_position,
				]
			)

	time_manager.set_time_scale(1.0)
	_done(failures)


func _on_pad_mode_changed(mode: int) -> void:
	_mode_events.append(mode)


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
