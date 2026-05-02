extends PanelContainer
## Bottom-edge 0–9 hotbar. Each slot is a Button labeled with its key.
## Polled rising-edge detection on KEY_0..KEY_9 (Input.is_action via
## InputMap can't hold dynamic actions cheaply for 10 keys) — toggles
## the matching slot. Slot bindings (build menu, blueprints, flag) wire
## up in Phase 8.

const SLOT_COUNT: int = 10

@onready var hbox: HBoxContainer = $Margin/HBox

var _slot_buttons: Array[Button] = []
var _prev_pressed: Array[bool] = []
var _selected_slot: int = -1


func _ready() -> void:
	for i in range(SLOT_COUNT):
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(56, 40)
		btn.text = "%d\n—" % i
		btn.pressed.connect(_on_slot_pressed.bind(i))
		hbox.add_child(btn)
		_slot_buttons.append(btn)
		_prev_pressed.append(false)


func _physics_process(_delta: float) -> void:
	# Detect rising edges on KEY_0..KEY_9. Same headless-friendly polling
	# pattern the crew selection manager uses. Check both logical and
	# physical key state so synthetic test events using either field work.
	for i in range(SLOT_COUNT):
		var keycode: int = KEY_0 + i
		var pressed: bool = Input.is_key_pressed(keycode) or Input.is_physical_key_pressed(keycode)
		if pressed and not _prev_pressed[i]:
			_select_slot(i)
		_prev_pressed[i] = pressed


func _on_slot_pressed(i: int) -> void:
	_select_slot(i)


func _select_slot(i: int) -> void:
	if _selected_slot == i:
		# Toggle off if reselecting the active slot.
		_selected_slot = -1
		_slot_buttons[i].button_pressed = false
		return
	_selected_slot = i
	for j in range(_slot_buttons.size()):
		_slot_buttons[j].button_pressed = (j == i)
	EventBus.log_message.emit("Hotbar slot %d (Phase 8 wiring)" % i, "hotbar")


func current_slot() -> int:
	return _selected_slot
