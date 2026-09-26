extends Node
## Global game state singleton.
## Tracks high-level game flow: which scene we're in, paused state,
## current mission day, persistent flags. Also sets up the InputMap
## on boot so input actions are guaranteed to exist before any node
## tries to read them.

enum GameMode { MAIN_MENU, ORBIT_MAP, GROUND, PAUSED }

const GAMEPAD_PATH: String = "res://data/gamepad.json"

## Fallback used when data/gamepad.json is missing or unparseable. Mirrors the
## shipped file so the pad still works on a broken install.
const PAD_DEFAULTS := {
	"device": 0,
	"axis_x": 0,
	"axis_y": 1,
	"deadzone": 0.22,
	"invert_y": false,
	"button_cancel": 2,
	"button_confirm": 3,
	"button_mode": 4,
	"cursor_speed_min": 600.0,
	"cursor_speed_max": 1700.0,
	"cursor_ramp_seconds": 0.6,
	"camera_pan_speed": 900.0,
	"double_tap_seconds": 0.28,
	"debug_probe": false,
}

var current_mode: GameMode = GameMode.MAIN_MENU
var mission_day: int = 0
var is_paused: bool = false

## Tile coordinate selected on the orbit map; applied when the ground
## scene loads in Phase 7.
var selected_landing_tile: Vector2i = Vector2i.ZERO

## Parsed `data/gamepad.json`, merged over PAD_DEFAULTS. Read by PadInput so
## the config is loaded once, not per-consumer.
var pad_config: Dictionary = {}


func _ready() -> void:
	_load_pad_config()
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


## Forward-compatible loader per `data/README.md` — unknown keys are kept,
## missing keys fall back to PAD_DEFAULTS.
func _load_pad_config() -> void:
	pad_config = PAD_DEFAULTS.duplicate(true)
	var f := FileAccess.open(GAMEPAD_PATH, FileAccess.READ)
	if f == null:
		push_warning("[GameState] Cannot open %s — using pad defaults." % GAMEPAD_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[GameState] %s did not parse to a dictionary — using pad defaults." % GAMEPAD_PATH)
		return
	for key in (parsed as Dictionary):
		pad_config[key] = parsed[key]


func pad_setting(key: String) -> Variant:
	return pad_config.get(key, PAD_DEFAULTS.get(key))


## Phase-1 input bindings. Migrate to Project > Project Settings > Input Map
## via the editor any time — this just guarantees they exist on first run.
## Each action maps to one or more physical keys (movement supports both
## WASD and arrow keys). Joypad events are layered on afterwards so the pad
## and the keyboard drive the *same* actions.
func _setup_input_map() -> void:
	var bindings := {
		"move_up":         [KEY_W, KEY_UP],
		"move_down":       [KEY_S, KEY_DOWN],
		"move_left":       [KEY_A, KEY_LEFT],
		"move_right":      [KEY_D, KEY_RIGHT],
		"scan":             [KEY_R],
		"deploy_probe":     [KEY_F],
		"collect_sample":   [KEY_G],
		"crew_menu":        [KEY_C],
		# The roster outgrew the number row (11 crew), so selection is a cycle:
		# Tab steps forward through crew then a free-explore slot, Shift+Tab
		# steps back. Same ring the gamepad cycle button drives.
		"cycle_crew":       [KEY_TAB],
		"pause_game":       [KEY_SPACE],
		"speed_1x":         [KEY_F1],
		"speed_2x":         [KEY_F2],
		"speed_4x":         [KEY_F3],
		"reset_hud":        [KEY_F9],
	}
	for action_name in bindings:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		for keycode in bindings[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)
	_setup_joypad_bindings()


## Generic Bluetooth pad: one 360° analog stick + three usable buttons.
## The stick is added to the existing move_* actions (so crew walking is
## analog for free), and the three buttons become their own actions that
## PadInput reads. Indices come from `data/gamepad.json` because the pad has
## no SDL mapping — its buttons arrive as raw integers, not JOY_BUTTON_A/B/X/Y.
func _setup_joypad_bindings() -> void:
	var device: int = int(pad_setting("device"))
	var axis_x: int = int(pad_setting("axis_x"))
	var axis_y: int = int(pad_setting("axis_y"))
	var deadzone: float = float(pad_setting("deadzone"))
	var invert_y: float = -1.0 if bool(pad_setting("invert_y")) else 1.0

	var axis_bindings := {
		"move_left":  [axis_x, -1.0],
		"move_right": [axis_x, 1.0],
		"move_up":    [axis_y, -1.0 * invert_y],
		"move_down":  [axis_y, 1.0 * invert_y],
	}
	for action_name in axis_bindings:
		var motion := InputEventJoypadMotion.new()
		motion.device = device
		motion.axis = axis_bindings[action_name][0]
		motion.axis_value = axis_bindings[action_name][1]
		_add_event_once(action_name, motion)
		# Godot's default 0.5 deadzone is far too high for a drifty cheap pad.
		InputMap.action_set_deadzone(action_name, deadzone)

	var button_bindings := {
		"pad_cancel":  int(pad_setting("button_cancel")),
		"pad_confirm": int(pad_setting("button_confirm")),
		"pad_mode":    int(pad_setting("button_mode")),
	}
	for action_name in button_bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var btn := InputEventJoypadButton.new()
		btn.device = device
		btn.button_index = button_bindings[action_name]
		_add_event_once(action_name, btn)


## Idempotent add — re-running _setup_input_map (tests, hot reload) must not
## stack duplicate events on an action.
func _add_event_once(action_name: String, event: InputEvent) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing in InputMap.action_get_events(action_name):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action_name, event)
