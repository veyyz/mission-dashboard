class_name CrewSelectionManager
extends Node2D
## Owns crew selection state. Listens for `select_crew_1..6` to single- or
## multi-select (shift held). Left-click in the world dispatches `move_to()`
## on every selected crew. Emits `EventBus.crew_selected` whenever the
## selection changes.

const MAX_CREW: int = 6
const SCAN_RADIUS: float = 220.0
const SCAN_RADIUS_GEOLOGIST: float = 440.0  # 2× per spec §5.4

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
	# Phase 8: scan / deploy probe / collect sample, all gated on the
	# selected crew's role.
	for action in ["scan", "deploy_probe", "collect_sample"]:
		var pressed: bool = Input.is_action_pressed(action)
		var prev: bool = _prev_pressed.get(action, false)
		_prev_pressed[action] = pressed
		if pressed and not prev:
			_invoke_action(action)


func _invoke_action(action: String) -> void:
	var primary: CrewMember = _first_selected()
	if primary == null:
		return
	match action:
		"scan":           _do_scan(primary)
		"deploy_probe":   _do_deploy_probe(primary)
		"collect_sample": _do_collect_sample(primary)


func _first_selected() -> CrewMember:
	for child in get_children():
		var crew := child as CrewMember
		if crew != null and crew.selected:
			return crew
	return null


func _do_scan(crew: CrewMember) -> void:
	var radius: float = SCAN_RADIUS_GEOLOGIST if crew.role == CrewMember.Role.GEOLOGIST else SCAN_RADIUS
	var revealed: int = 0
	for node in get_tree().get_nodes_in_group("resource_node"):
		var rn: Node2D = node as Node2D
		if rn == null:
			continue
		if rn.global_position.distance_to(crew.global_position) <= radius:
			if rn.has_method("reveal") and not rn.get("discovered"):
				rn.reveal()
				revealed += 1
	EventBus.log_message.emit(
		"%s scanned (radius=%d) — revealed %d nodes" % [crew.crew_name, int(radius), revealed],
		"selection",
	)


func _do_deploy_probe(crew: CrewMember) -> void:
	if crew.role != CrewMember.Role.SCIENTIST:
		EventBus.log_message.emit("Probe deploy requires Scientist", "alert")
		return
	var probe: Node2D = preload("res://scenes/world/Probe.tscn").instantiate()
	get_parent().add_child(probe)  # parented under YSort alongside crew
	probe.global_position = crew.global_position


func _do_collect_sample(crew: CrewMember) -> void:
	for node in get_tree().get_nodes_in_group("resource_node"):
		var rn: Node2D = node as Node2D
		if rn == null:
			continue
		if rn.has_method("can_be_sampled_by") and rn.can_be_sampled_by(crew.global_position):
			rn.collect_one()
			return
	EventBus.log_message.emit("No deposit in range to sample", "alert")


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
