extends Node
## JSON-based save/load. Phase-9 implementation.
## Persists: GameState, ResourceManager, TimeManager, all crew under
## `crew` group, all buildings under `buildings` group, all resource nodes
## under `resource_node` group, all probes under `probe` group, and the
## fog-of-war revealed-cells dictionary.

const SAVE_DIR: String = "user://saves/"
const AUTOSAVE_NAME: String = "autosave.json"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	print("[SaveSystem] Ready. Save dir: %s" % SAVE_DIR)


func save_game(slot_name: String = AUTOSAVE_NAME) -> bool:
	var data: Dictionary = {
		"_version": 1,
		"game_state": _serialize_game_state(),
		"resources": _serialize_resources(),
		"time": _serialize_time(),
		"crew": _serialize_crew(),
		"buildings": _serialize_buildings(),
		"resource_nodes": _serialize_resource_nodes(),
		"probes": _serialize_probes(),
		"fog_revealed_cells": _serialize_fog(),
	}
	var f := FileAccess.open(SAVE_DIR + slot_name, FileAccess.WRITE)
	if f == null:
		push_error("[SaveSystem] cannot write %s" % (SAVE_DIR + slot_name))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	EventBus.game_saved.emit(slot_name)
	EventBus.log_message.emit("Saved → %s" % slot_name, "build")
	return true


func load_game(slot_name: String = AUTOSAVE_NAME) -> bool:
	if not has_save(slot_name):
		push_warning("[SaveSystem] no save at %s" % (SAVE_DIR + slot_name))
		return false
	var f := FileAccess.open(SAVE_DIR + slot_name, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveSystem] save file did not parse to dict")
		return false
	var data: Dictionary = parsed
	_restore_game_state(data.get("game_state", {}))
	_restore_resources(data.get("resources", {}))
	_restore_time(data.get("time", {}))
	_restore_crew(data.get("crew", []))
	_restore_buildings(data.get("buildings", []))
	_restore_resource_nodes(data.get("resource_nodes", []))
	_restore_probes(data.get("probes", []))
	_restore_fog(data.get("fog_revealed_cells", []))
	EventBus.game_loaded.emit(slot_name)
	EventBus.log_message.emit("Loaded ← %s" % slot_name, "build")
	return true


func has_save(slot_name: String = AUTOSAVE_NAME) -> bool:
	return FileAccess.file_exists(SAVE_DIR + slot_name)


func list_saves() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			result.append(name)
		name = dir.get_next()
	return result


# --- Serializers ---

func _serialize_game_state() -> Dictionary:
	return {
		"current_mode": int(GameState.current_mode),
		"mission_day": GameState.mission_day,
		"is_paused": GameState.is_paused,
		"selected_landing_tile": [GameState.selected_landing_tile.x, GameState.selected_landing_tile.y],
	}


func _serialize_resources() -> Dictionary:
	var out: Dictionary = {}
	for r_name in ResourceManager.resources.keys():
		var d = ResourceManager.resources[r_name]
		out[r_name] = {"current": d.current, "maximum": d.maximum, "rate": d.rate_per_min}
	return out


func _serialize_time() -> Dictionary:
	return {
		"current_minute_of_day": TimeManager.current_minute_of_day,
		"current_day": TimeManager.current_day,
		"time_scale": TimeManager.time_scale,
		"current_phase": TimeManager.current_phase,
	}


func _serialize_crew() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("crew"):
		out.append({
			"crew_id": node.crew_id,
			"crew_name": node.crew_name,
			"role": int(node.role),
			"role_skill": node.role_skill,
			"position": [node.global_position.x, node.global_position.y],
			"current_health": node.current_health,
			"current_stamina": node.current_stamina,
			"current_oxygen": node.current_oxygen,
			"selected": node.selected,
		})
	return out


func _serialize_buildings() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("buildings"):
		out.append({
			"building_key": node.building_key,
			"position": [node.global_position.x, node.global_position.y],
		})
	return out


func _serialize_resource_nodes() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("resource_node"):
		out.append({
			"deposit_type": node.deposit_type,
			"amount": node.amount,
			"discovered": node.discovered,
			"position": [node.global_position.x, node.global_position.y],
		})
	return out


func _serialize_probes() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("probe"):
		out.append({"position": [node.global_position.x, node.global_position.y]})
	return out


func _serialize_fog() -> Array:
	# `revealed_cells` is a dictionary keyed by Vector2i; flatten to [x, y] pairs.
	var fog := get_tree().root.find_child("FogOfWar", true, false)
	if fog == null or not fog.has_method("revealed_count"):
		return []
	var out: Array = []
	for cell in fog._revealed_cells.keys():
		out.append([cell.x, cell.y])
	return out


# --- Restorers ---

func _restore_game_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	GameState.current_mode = d.get("current_mode", GameState.GameMode.MAIN_MENU)
	GameState.mission_day = d.get("mission_day", 0)
	GameState.is_paused = d.get("is_paused", false)
	var t: Array = d.get("selected_landing_tile", [0, 0])
	GameState.selected_landing_tile = Vector2i(int(t[0]), int(t[1]))


func _restore_resources(d: Dictionary) -> void:
	for r_name in d.keys():
		if not ResourceManager.resources.has(r_name):
			continue
		var entry: Dictionary = d[r_name]
		var data = ResourceManager.resources[r_name]
		data.current = float(entry.get("current", data.current))
		data.maximum = float(entry.get("maximum", data.maximum))
		data.rate_per_min = float(entry.get("rate", data.rate_per_min))
		EventBus.resource_changed.emit(r_name, data.current, data.maximum, data.rate_per_min)


func _restore_time(d: Dictionary) -> void:
	if d.is_empty():
		return
	TimeManager.current_minute_of_day = float(d.get("current_minute_of_day", TimeManager.current_minute_of_day))
	TimeManager.current_day = int(d.get("current_day", TimeManager.current_day))
	TimeManager.time_scale = float(d.get("time_scale", TimeManager.time_scale))
	TimeManager.current_phase = d.get("current_phase", TimeManager.current_phase)
	EventBus.phase_changed.emit(TimeManager.current_phase)


## Restore crew positions + state by matching crew_id. Crew nodes themselves
## are preserved (no respawn) — the world is unified per spec §5.6, so
## load doesn't tear down/rebuild the scene.
func _restore_crew(arr: Array) -> void:
	for entry in arr:
		var target_id: int = int(entry.get("crew_id", -1))
		for node in get_tree().get_nodes_in_group("crew"):
			if node.crew_id == target_id:
				var pos: Array = entry.get("position", [0, 0])
				node.global_position = Vector2(pos[0], pos[1])
				node.current_health = int(entry.get("current_health", node.current_health))
				node.current_stamina = int(entry.get("current_stamina", node.current_stamina))
				node.current_oxygen = float(entry.get("current_oxygen", node.current_oxygen))
				node.set_selected(bool(entry.get("selected", false)))
				break


## Buildings: clear current then re-instantiate from saved data.
func _restore_buildings(arr: Array) -> void:
	# Free existing.
	for node in get_tree().get_nodes_in_group("buildings"):
		node.queue_free()
	var ground := get_tree().root.find_child("Ground", true, false)
	if ground == null:
		return
	var ysort := ground.find_child("YSort", true, false)
	if ysort == null:
		return
	for entry in arr:
		var key: String = entry.get("building_key", "")
		if not BuildingDatabase.has_scene(key):
			continue
		var packed: PackedScene = load(BuildingDatabase.get_scene_path(key)) as PackedScene
		if packed == null:
			continue
		var b: Node2D = packed.instantiate()
		ysort.add_child(b)
		var pos: Array = entry.get("position", [0, 0])
		b.global_position = Vector2(pos[0], pos[1])


func _restore_resource_nodes(arr: Array) -> void:
	for node in get_tree().get_nodes_in_group("resource_node"):
		node.queue_free()
	var ground := get_tree().root.find_child("Ground", true, false)
	if ground == null:
		return
	var ysort := ground.find_child("YSort", true, false)
	if ysort == null:
		return
	var packed: PackedScene = load("res://scenes/world/ResourceNode.tscn") as PackedScene
	for entry in arr:
		var rn: Node2D = packed.instantiate()
		rn.deposit_type = entry.get("deposit_type", "ilmenite")
		rn.amount = int(entry.get("amount", 0))
		var pos: Array = entry.get("position", [0, 0])
		rn.position = Vector2(pos[0], pos[1])
		ysort.add_child(rn)
		if bool(entry.get("discovered", false)):
			rn.reveal()


func _restore_probes(arr: Array) -> void:
	for node in get_tree().get_nodes_in_group("probe"):
		node.queue_free()
	var ground := get_tree().root.find_child("Ground", true, false)
	if ground == null:
		return
	var ysort := ground.find_child("YSort", true, false)
	if ysort == null:
		return
	var packed: PackedScene = load("res://scenes/world/Probe.tscn") as PackedScene
	for entry in arr:
		var p: Node2D = packed.instantiate()
		var pos: Array = entry.get("position", [0, 0])
		p.position = Vector2(pos[0], pos[1])
		ysort.add_child(p)


func _restore_fog(arr: Array) -> void:
	var fog := get_tree().root.find_child("FogOfWar", true, false)
	if fog == null:
		return
	fog._revealed_cells.clear()
	for pair in arr:
		fog._revealed_cells[Vector2i(int(pair[0]), int(pair[1]))] = true
