extends SceneTree
## Phase-5 functional test.
## Verifies:
##   1. Three building scenes exist
##   2. BuildingDatabase autoload exposes definitions loaded from buildings.json
##   3. place_building("solar_array", pos) deducts materials + silicon
##   4. ConstructionSite spawns at the placement
##   5. Calling site.tick(build_time + 1) completes construction → building_completed fires
##   6. After completion, ResourceManager.power rate reflects the SolarArray's produces

var event_bus: Node
var resource_manager: Node
var building_database: Node

var _building_completed_events: Array[Dictionary] = []


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
	await physics_frame

	var placement := ground.find_child("BuildPlacementController", true, false)
	if placement == null:
		_done(failures + ["BuildPlacementController missing in Ground.tscn"])
		return

	# Pause time so resource rates don't drift while we're measuring deductions.
	var time_manager := root.get_node_or_null("TimeManager")
	if time_manager != null:
		time_manager.set_time_scale(0.0)

	# 3. place_building deducts materials + silicon.
	var solar_def: Dictionary = building_database.get_definition("solar_array")
	var cost: Dictionary = solar_def.get("cost", {})
	var before_materials: float = resource_manager.get_current("materials")
	var before_silicon: float = resource_manager.get_current("silicon")
	var before_power_rate: float = resource_manager.get_rate("power")

	event_bus.building_completed.connect(_on_building_completed)

	# Place at (0, -120) — above Alex (engineer) so she can be moved adjacent.
	var site = placement.place_building("solar_array", Vector2(0, -120))
	if site == null:
		_done(failures + ["place_building returned null"])
		return
	await process_frame

	var after_materials: float = resource_manager.get_current("materials")
	var after_silicon: float = resource_manager.get_current("silicon")
	if not is_equal_approx(before_materials - after_materials, float(cost.get("materials", 0))):
		failures.append(
			"materials deduction wrong: expected %d, got %.1f" % [
				int(cost.get("materials", 0)),
				before_materials - after_materials,
			]
		)
	if not is_equal_approx(before_silicon - after_silicon, float(cost.get("silicon", 0))):
		failures.append(
			"silicon deduction wrong: expected %d, got %.1f" % [
				int(cost.get("silicon", 0)),
				before_silicon - after_silicon,
			]
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
