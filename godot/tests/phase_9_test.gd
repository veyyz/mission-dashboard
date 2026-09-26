extends SceneTree
## Phase-9 functional test.
## Verifies:
##   1. Lose: any of power/oxygen/food hitting 0 fires EventBus.defeat
##   2. Win: 3 consecutive day-advanced events with all 3 critical rates
##      positive fires EventBus.victory
##   3. EventManager.try_event applies an `add_resource` effect and emits
##      random_event_fired
##   4. SaveSystem.save_game writes user://saves/test_slot.json
##   5. SaveSystem round-trip — modify state, load, state restored
##   6. Save file contains every required top-level section

var event_bus: Node
var resource_manager: Node
var time_manager: Node
var save_system: Node
var event_manager: Node
var win_lose: Node
var game_state: Node

var _victory_fired: bool = false
var _defeat_reason: String = ""
var _random_event_id: String = ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	resource_manager = root.get_node_or_null("ResourceManager")
	time_manager = root.get_node_or_null("TimeManager")
	save_system = root.get_node_or_null("SaveSystem")
	event_manager = root.get_node_or_null("EventManager")
	win_lose = root.get_node_or_null("WinLoseManager")
	game_state = root.get_node_or_null("GameState")

	for pair in [
		["EventBus", event_bus], ["ResourceManager", resource_manager],
		["TimeManager", time_manager], ["SaveSystem", save_system],
		["EventManager", event_manager], ["WinLoseManager", win_lose],
		["GameState", game_state],
	]:
		if pair[1] == null:
			failures.append("Autoload missing: %s" % pair[0])
	if not failures.is_empty():
		_done(failures)
		return

	# Pause game time so resource rates don't drift mid-test.
	time_manager.set_time_scale(0.0)

	event_bus.victory.connect(_on_victory)
	event_bus.defeat.connect(_on_defeat)
	event_bus.random_event_fired.connect(_on_random_event)

	# Boot the world.
	var ground_packed := load("res://scenes/world/Ground.tscn") as PackedScene
	var ground: Node = ground_packed.instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame
	event_bus.landing_confirmed.emit(Vector2i.ZERO)
	await process_frame
	await physics_frame

	# 1. Lose condition — drop oxygen to 0.
	win_lose.reset()
	var oxygen_before: float = resource_manager.get_current("oxygen")
	resource_manager.add("oxygen", -oxygen_before)  # → 0
	await process_frame
	if not _defeat_reason.begins_with("oxygen"):
		failures.append("EventBus.defeat did not fire on oxygen=0 (reason='%s')" % _defeat_reason)

	# 2. Win condition — set positive rates on all 3 critical resources, advance 3 days.
	win_lose.reset()
	resource_manager.add("oxygen", 500.0)  # restore to non-zero
	resource_manager.set_rate("power", 5.0)
	resource_manager.set_rate("oxygen", 4.0)
	resource_manager.set_rate("food", 3.0)
	for d in range(1, 4):
		event_bus.mission_day_advanced.emit(d)
		await process_frame
	if not _victory_fired:
		failures.append("EventBus.victory did not fire after 3 sustainable day-advances")

	# 3. EventManager.try_event applies add_resource effect.
	var materials_before: float = resource_manager.get_current("machine_parts")
	var ran: bool = event_manager.try_event("supply_drop")
	await process_frame
	if not ran:
		failures.append("EventManager.try_event('supply_drop') returned false")
	var materials_after: float = resource_manager.get_current("machine_parts")
	if materials_after - materials_before < 1.0:
		failures.append("supply_drop did not add machine_parts (before=%.1f after=%.1f)" % [materials_before, materials_after])
	if _random_event_id != "supply_drop":
		failures.append("EventBus.random_event_fired event_id mismatch: '%s' vs 'supply_drop'" % _random_event_id)

	# 4. Save.
	var saved: bool = save_system.save_game("test_slot.json")
	if not saved:
		failures.append("SaveSystem.save_game returned false")
	if not save_system.has_save("test_slot.json"):
		failures.append("save file does not exist after save_game")

	# 6. Save file contains every top-level section.
	var f := FileAccess.open("user://saves/test_slot.json", FileAccess.READ)
	if f == null:
		failures.append("could not open save file for inspection")
	else:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			failures.append("save file is not a JSON dict")
		else:
			for section in ["_version", "game_state", "resources", "time", "crew", "buildings", "resource_nodes", "probes", "fog_revealed_cells"]:
				if not parsed.has(section):
					failures.append("save missing section: %s" % section)

	# 5. Round-trip — modify state, then load, verify restored.
	var saved_power: float = resource_manager.get_current("power")
	var crew_nodes: Array = get_nodes_in_group("crew")
	var first_crew: Node2D = null
	if not crew_nodes.is_empty():
		first_crew = crew_nodes[0]
	var saved_crew_pos: Vector2 = first_crew.global_position if first_crew else Vector2.ZERO

	# Mutate state.
	resource_manager.add("power", -100.0)
	if first_crew != null:
		first_crew.global_position = Vector2(9999, 9999)

	# Load.
	var loaded: bool = save_system.load_game("test_slot.json")
	if not loaded:
		failures.append("SaveSystem.load_game returned false")
	await process_frame

	var restored_power: float = resource_manager.get_current("power")
	if not is_equal_approx(restored_power, saved_power):
		failures.append("Power not restored: saved=%.1f restored=%.1f" % [saved_power, restored_power])
	if first_crew != null:
		var restored_pos: Vector2 = first_crew.global_position
		if restored_pos.distance_to(saved_crew_pos) > 1.0:
			failures.append("Crew position not restored: saved=%s restored=%s" % [saved_crew_pos, restored_pos])

	# Cleanup.
	DirAccess.remove_absolute("user://saves/test_slot.json")
	time_manager.set_time_scale(1.0)
	_done(failures)


func _on_victory() -> void:
	_victory_fired = true


func _on_defeat(reason: String) -> void:
	_defeat_reason = reason


func _on_random_event(event_id: String, _summary: String) -> void:
	_random_event_id = event_id


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
