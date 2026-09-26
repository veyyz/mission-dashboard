extends SceneTree
## Phase-5 functional test.
## Verifies:
##   1. Three building scenes exist
##   2. BuildingDatabase autoload exposes definitions loaded from buildings.json
##   3. place_building("solar_array", pos) deducts materials + silicon
##   4. ConstructionSite spawns at the placement
##   5. Calling site.tick(build_time + 1) completes construction → building_completed fires
##   6. After completion, ResourceManager.power rate reflects the SolarArray produces
##   7. Any crew role — not just ENGINEER — advances a construction site

var event_bus: Node
var resource_manager: Node
var building_database: Node

var _building_completed_events: Array[Dictionary] = []
var _last_log: String = ""


func _on_log_message(message: String, _category: String) -> void:
	_last_log = message


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	resource_manager = root.get_node_or_null("ResourceManager")
	building_database = root.get_node_or_null("BuildingDatabase")
	if event_bus == null or resource_manager == null or building_database == null:
		_done([
			"Autoload(s) missing: EventBus=%s ResourceManager=%s BuildingDatabase=%s" % [
				event_bus, resource_manager, building_database,
			],
		])
		return

	# 1. Three building scenes exist.
	var scene_paths := [
		"res://scenes/buildings/SolarArray.tscn",
		"res://scenes/buildings/HabitatModule.tscn",
		"res://scenes/buildings/MiningDrill.tscn",
	]
	for p in scene_paths:
		if not ResourceLoader.exists(p):
			failures.append("Building scene missing: %s" % p)

	# 2. BuildingDatabase populated.
	for key in ["solar_array", "habitat_module", "mining_drill"]:
		if not building_database.has_definition(key):
			failures.append("BuildingDatabase missing definition for '%s'" % key)

	# Boot the world so we can place a building under it.
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

	var placement := ground.find_child("BuildPlacementController", true, false)
	if placement == null:
		_done(failures + ["BuildPlacementController missing in Ground.tscn"])
		return

	# Pause time so resource rates don't drift while we're measuring deductions.
	var time_manager := root.get_node_or_null("TimeManager")
	if time_manager != null:
		time_manager.set_time_scale(0.0)

	# 3. place_building deducts every component in the cost dict
	#    (solar_cells + alloy_beams + wiring for a Solar Array).
	var solar_def: Dictionary = building_database.get_definition("solar_array")
	var cost: Dictionary = solar_def.get("cost", {})
	if cost.is_empty():
		failures.append("solar_array has no cost")
	var before_cost: Dictionary = {}
	for r_name in cost.keys():
		before_cost[r_name] = resource_manager.get_current(r_name)
	var before_power_rate: float = resource_manager.get_rate("power")

	event_bus.building_completed.connect(_on_building_completed)

	# Place at (0, -120) — above Alex (engineer) so she can be moved adjacent.
	var site = placement.place_building("solar_array", Vector2(0, -120))
	if site == null:
		_done(failures + ["place_building returned null"])
		return
	await process_frame

	for r_name in cost.keys():
		var spent: float = before_cost[r_name] - resource_manager.get_current(r_name)
		if not is_equal_approx(spent, float(cost[r_name])):
			failures.append(
				"%s deduction wrong: expected %d, got %.1f" % [r_name, int(cost[r_name]), spent]
			)

	# 4. ConstructionSite spawned.
	if not site.is_inside_tree():
		failures.append("ConstructionSite not in tree after place_building")
	if site.get("building_key") != "solar_array":
		failures.append("ConstructionSite.building_key != 'solar_array'")

	# 5. Drive completion via the public tick() API.
	var build_time: float = float(solar_def.get("build_time_seconds", 30))
	site.tick(build_time + 1.0)
	await process_frame
	await process_frame

	# Construction site should have replaced itself with a finished Building.
	if is_instance_valid(site) and site.is_inside_tree():
		failures.append("ConstructionSite did not free itself after completion")

	# building_completed should have fired with key "solar_array".
	var saw_complete: bool = false
	for ev in _building_completed_events:
		if ev.get("key") == "solar_array":
			saw_complete = true
			break
	if not saw_complete:
		failures.append("EventBus.building_completed never fired for solar_array (saw %d events)" % _building_completed_events.size())

	# 6. Power rate should now reflect the SolarArray's produces (15/min).
	var after_power_rate: float = resource_manager.get_rate("power")
	var expected_delta: float = float(solar_def.get("produces", {}).get("power", 0))
	if not is_equal_approx(after_power_rate - before_power_rate, expected_delta):
		failures.append(
			"power rate delta wrong: expected +%.1f, got +%.2f (before=%.2f after=%.2f)" % [
				expected_delta, after_power_rate - before_power_rate,
				before_power_rate, after_power_rate,
			]
		)

	# 7. Unaffordable placement names every short line in the chat log.
	event_bus.log_message.connect(_on_log_message)
	resource_manager.add("solar_cells", -resource_manager.get_current("solar_cells"))  # → 0
	_last_log = ""
	var refused = placement.place_building("solar_array", Vector2(900, 900))
	if refused != null:
		failures.append("place_building should refuse with 0 solar cells")
	if not _last_log.contains("Solar Cells") or not _last_log.contains("have 0"):
		failures.append("shortfall message should name Solar Cells and the amount held, got: '%s'" % _last_log)
	if not _last_log.contains("Alloy Beams"):
		failures.append("shortfall message should list the full cost, got: '%s'" % _last_log)

	# 8. Any role can build — the ENGINEER gate on construction was removed.
	# Park a non-Engineer next to a fresh site and check the bar advances.
	for r_name in ["solar_cells", "alloy_beams", "wiring"]:
		resource_manager.add(r_name, 100.0)
	var site2 = placement.place_building("solar_array", Vector2(600, 600))
	if site2 == null:
		failures.append("place_building returned null for the any-role check")
	else:
		# Duck-typed on purpose: naming `CrewMember` in a SceneTree test script
		# trips GDScript's order-sensitive class_name discovery in headless mode
		# and Ground._spawn_crew then silently spawns zero crew. Same reason
		# build_placement_controller.gd types ConstructionSite as Node2D.
		const ROLE_ENGINEER: int = 0
		var builder: Node2D = null
		for node in get_nodes_in_group("crew"):
			if int(node.get("role")) != ROLE_ENGINEER:
				builder = node as Node2D
				break
		if builder == null:
			failures.append("No non-Engineer crew available for the any-role check")
		else:
			# Keep every Engineer well clear so only the non-Engineer is in reach.
			for node in get_nodes_in_group("crew"):
				if int(node.get("role")) == ROLE_ENGINEER:
					(node as Node2D).global_position = Vector2(-5000, -5000)
			builder.global_position = site2.global_position
			var progress_before: float = site2.progress
			await process_frame
			await process_frame
			var advanced: bool = not is_instance_valid(site2) or site2.progress > progress_before
			if not advanced:
				failures.append(
					"Non-Engineer %s (role=%s) did not advance construction" % [
						str(builder.get("crew_name")), str(builder.get("role")),
					]
				)

	# Restore time scale so we don't leak state.
	if time_manager != null:
		time_manager.set_time_scale(1.0)

	_done(failures)


func _on_building_completed(key: String, grid_pos: Vector2i) -> void:
	_building_completed_events.append({"key": key, "grid": grid_pos})


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
