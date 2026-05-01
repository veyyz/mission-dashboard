extends Node
## Global game state singleton.
## Tracks high-level game flow: which scene we're in, paused state,
## current mission day, persistent flags. Also sets up the InputMap
## on boot so input actions are guaranteed to exist before any node
## tries to read them.

enum GameMode { MAIN_MENU, ORBIT_MAP, GROUND, PAUSED }

var current_mode: GameMode = GameMode.MAIN_MENU
var mission_day: int = 0
var is_paused: bool = false

## Tile coordinate selected on the orbit map; applied when the ground
## scene loads in Phase 7.
var selected_landing_tile: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_setup_input_map()
	print("[GameState] Ready.")


func set_mode(mode: GameMode) -> void:
	current_mode = mode
	EventBus.game_mode_changed.emit(mode)
	print("[GameState] Mode → %s" % GameMode.keys()[mode])


func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	EventBus.pause_toggled.emit(is_paused)


## Phase-1 input bindings. Migrate to Project > Project Settings > Input Map
## via the editor any time — this just guarantees they exist on first run.
func _setup_input_map() -> void:
	var bindings := {
		"move_up":         KEY_W,
		"move_down":       KEY_S,
		"move_left":       KEY_A,
		"move_right":      KEY_D,
		"scan":            KEY_R,
		"deploy_probe":    KEY_F,
		"collect_sample": KEY_G,
		"crew_menu":       KEY_C,
		"select_crew_1":   KEY_1,
		"select_crew_2":   KEY_2,
		"select_crew_3":   KEY_3,
		"select_crew_4":   KEY_4,
		"select_crew_5":   KEY_5,
		"select_crew_6":   KEY_6,
		"pause_game":      KEY_SPACE,
		"speed_1x":        KEY_F1,
		"speed_2x":        KEY_F2,
		"speed_4x":        KEY_F3,
	}
	for action_name in bindings:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action_name]
		InputMap.action_add_event(action_name, event)
