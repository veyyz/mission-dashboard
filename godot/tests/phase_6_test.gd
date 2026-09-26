extends SceneTree
## Phase-6 functional test.
## Verifies:
##   1. HUD.tscn exists as a CanvasLayer
##   2. All 6 panels exist as their own .tscn files under scenes/ui/panels/
##   3. Each panel scene loads and is instantiated under HUD
##   4. Resource bar binds to EventBus.resource_changed
##   5. Crew bar binds to crew selection (EventBus.crew_selected)
##   6. Tutorial guide can be toggled with F1

var event_bus: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	if event_bus == null:
		_done(["EventBus autoload missing"])
		return

	# 1. HUD.tscn exists.
	var hud_packed := load("res://scenes/ui/HUD.tscn") as PackedScene
	if hud_packed == null:
		_done(["HUD.tscn missing"])
		return

	# 2. All 8 panel scenes exist.
	var panel_paths := [
		"res://scenes/ui/panels/HUDPanelDayTime.tscn",
		"res://scenes/ui/panels/HUDPanelResources.tscn",
		"res://scenes/ui/panels/HUDPanelTutorial.tscn",
		"res://scenes/ui/panels/HUDPanelLog.tscn",
		"res://scenes/ui/panels/HUDPanelCrew.tscn",
		"res://scenes/ui/panels/HUDPanelMinimap.tscn",
	]
	for p in panel_paths:
		if not ResourceLoader.exists(p):
			failures.append("Panel scene missing: %s" % p)

	# 3. Boot the world (which instances HUD) and verify panels are present.
	var ground_packed := load("res://scenes/world/Ground.tscn") as PackedScene
	if ground_packed == null:
		_done(failures + ["Ground.tscn missing"])
		return
	var ground: Node = ground_packed.instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame
	# Phase-7 landing flow: crew don't spawn until landing_confirmed.
	event_bus.landing_confirmed.emit(Vector2i.ZERO)
	await process_frame
	await physics_frame

	var hud := ground.find_child("HUD", true, false)
	if hud == null:
		_done(failures + ["HUD instance missing under Ground"])
		return
	if not (hud is CanvasLayer):
		failures.append("HUD root is not a CanvasLayer")

	for panel_name in [
		"HUDPanelDayTime", "HUDPanelResources", "HUDPanelTutorial",
		"HUDPanelLog", "HUDPanelCrew",
		"HUDPanelMinimap",
	]:
		if hud.find_child(panel_name, true, false) == null:
			failures.append("Panel instance missing: %s" % panel_name)

	# 4. Resource bar binds to EventBus.resource_changed.
	var resources_panel := hud.find_child("HUDPanelResources", true, false)
	var power_label := resources_panel.find_child("Col_power", true, false) if resources_panel != null else null
	if power_label == null:
		failures.append("Resources panel did not build per-resource entries")
	else:
		var resource_manager := root.get_node_or_null("ResourceManager")
		var before: float = resource_manager.get_current("power")
		var time_manager := root.get_node_or_null("TimeManager")
		if time_manager != null:
			time_manager.set_time_scale(0.0)
		resource_manager.add("power", -50.0)
		await process_frame
		await process_frame
		# Find the value Label inside the Col_power VBox: glyph_value HBox -> [glyph, value].
		var glyph_value_hbox: Node = power_label.get_child(0)
		var value_label: Label = glyph_value_hbox.get_child(1) as Label
		if value_label == null:
			failures.append("Could not locate power value label")
		else:
			var displayed_value: int = int(value_label.text)
			if displayed_value != int(before - 50.0):
				failures.append("Resources panel power value did not update: expected %d, got %d" % [int(before - 50.0), displayed_value])
		if time_manager != null:
			time_manager.set_time_scale(1.0)

	# 5. Crew bar binds to crew_selected.
	var crew_panel := hud.find_child("HUDPanelCrew", true, false)
	if crew_panel == null:
		failures.append("HUDPanelCrew not found")
	else:
		# Wait for the crew bar to populate from the "crew" group.
		var settle: int = 0
		while settle < 20:
			var hbox = crew_panel.find_child("HBox", true, false)
			if hbox != null and hbox.get_child_count() >= 6:
				break
			await process_frame
			settle += 1
		var hbox = crew_panel.find_child("HBox", true, false)
		if hbox == null or hbox.get_child_count() < 6:
			failures.append("Crew bar did not populate with 6 portraits (got %d)" % (hbox.get_child_count() if hbox else 0))
		else:
			# Emit crew_selected for id 4 and verify the matching portrait is pressed.
			event_bus.crew_selected.emit(4)
			await process_frame
			var portrait_4: Button = null
			for c in hbox.get_children():
				if c.get_meta("crew_id", -1) == 4:
					portrait_4 = c as Button
					break
			if portrait_4 == null:
				failures.append("No crew portrait with crew_id==4")
			elif not portrait_4.button_pressed:
				failures.append("Crew bar did not press portrait 4 after crew_selected emission")

	# 6. Tutorial guide can be toggled with F1.
	var tutorial := hud.find_child("HUDPanelTutorial", true, false)
	if tutorial == null:
		failures.append("HUDPanelTutorial not found")
	else:
		var was_visible: bool = tutorial.visible
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F1
		ev.pressed = true
		Input.parse_input_event(ev)
		await process_frame
		await process_frame
		if tutorial.visible == was_visible:
			failures.append("Tutorial visibility did not toggle on F1")

	# 7. Resource inspector: hidden by default, opens on resource_inspect_requested
	#    with the right subject, and lists a building that costs that resource.
	var info := hud.find_child("HUDPanelResourceInfo", true, false)
	if info == null:
		failures.append("HUDPanelResourceInfo not found")
	else:
		if info.visible:
			failures.append("Resource inspector should start hidden")
		event_bus.resource_inspect_requested.emit("alloy_beams")
		await process_frame
		if not info.visible:
			failures.append("Resource inspector did not open on resource_inspect_requested")
		if info.subject != "alloy_beams":
			failures.append("Resource inspector subject is '%s', expected alloy_beams" % info.subject)
		# find_child: hud_chrome re-parents the panel's content under Frame/Content.
		var body_text: String = info.find_child("Body", true, false).text
		if not body_text.contains("Solar Array") or not body_text.contains("to build"):
			failures.append("Resource inspector REQUIRED BY does not list Solar Array build cost")

	_done(failures)


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
