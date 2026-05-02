class_name CrewSelectionManager
extends Node2D
## Owns crew selection state. Listens for `select_crew_1..6` to single- or
## multi-select (shift held). Left-click in the world dispatches `move_to()`
## on every selected crew. Emits `EventBus.crew_selected` whenever the
## selection changes.

const MAX_CREW: int = 6

# Manual rising-edge tracking. Godot's `is_action_just_pressed` is unreliable
# in headless mode when the action is synthesized via `Input.action_press`
# (it may resolve as `false` even on the frame the press was registered).
# Tracking previous-frame state ourselves works for both real key events and
# test-driven synthetic input.
var _prev_pressed: Dictionary = {}


func _physics_process(_delta: float) -> void:
	# Polled in _physics_process (not _process) so headless test runs that
	# only tick `physics_frame` still see the input edge. _process can be
	# skipped in headless mode when there's no render loop.
	var multi: bool = Input.is_key_pressed(KEY_SHIFT)
	for i in range(1, MAX_CREW + 1):
		var action: String = "select_crew_%d" % i
		var pressed: bool = Input.is_action_pressed(action)
		var prev: bool = _prev_pressed.get(action, false)
		_prev_pressed[action] = pressed
		if pressed and not prev:
			_select(i, multi)
			return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_issue_move(get_global_mouse_position())


func _select(crew_id: int, multi: bool) -> void:
	var target: CrewMember = null
	for child in get_children():
		var crew := child as CrewMember
		if crew != null and crew.crew_id == crew_id:
			target = crew
			break
	if target == null:
		return

	if multi:
		target.set_selected(not target.selected)
	else:
		for child in get_children():
			var crew := child as CrewMember
			if crew != null:
				crew.set_selected(crew == target)

	EventBus.crew_selected.emit(crew_id)
	EventBus.log_message.emit(
		"Selected %s (crew_id=%d)" % [target.crew_name, crew_id], "selection"
	)


func _issue_move(target: Vector2) -> void:
	for child in get_children():
		var crew := child as CrewMember
		if crew != null and crew.selected:
			crew.move_to(target)
