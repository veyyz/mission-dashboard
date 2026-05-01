extends Node
## JSON-based save/load. Phase 1 is a stub — full implementation lands in Phase 9.
## Saves go to user:// (cross-platform: %APPDATA%/Godot/app_userdata/<project>/saves
## on Windows, ~/.local/share/godot/app_userdata/<project>/saves on Linux).

const SAVE_DIR: String = "user://saves/"
const AUTOSAVE_NAME: String = "autosave.json"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	print("[SaveSystem] Ready. Save dir: %s" % SAVE_DIR)


func save_game(slot_name: String = AUTOSAVE_NAME) -> bool:
	# TODO Phase 9: serialize GameState, ResourceManager, TimeManager,
	# all crew, all buildings, fog-of-war bitmap.
	push_warning("[SaveSystem] save_game() not yet implemented (Phase 9).")
	return false


func load_game(slot_name: String = AUTOSAVE_NAME) -> bool:
	push_warning("[SaveSystem] load_game() not yet implemented (Phase 9).")
	return false


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
