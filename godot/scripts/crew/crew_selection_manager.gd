class_name CrewSelectionManager
extends Node2D
## Owns crew selection state. Listens for `select_crew_1..6` to single- or
## multi-select (shift held). Left-click in the world dispatches `move_to()`
## on every selected crew. Emits `EventBus.crew_selected` whenever the
## selection changes.

const MAX_CREW: int = 6


func _process(_delta: float) -> void:
	var multi: bool = Input.is_key_pressed(KEY_SHIFT)
	for i in range(1, MAX_CREW + 1):
		if Input.is_action_just_pressed("select_crew_%d" % i):
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
