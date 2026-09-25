class_name CrewSelectionManager
extends Node2D
## Owns crew selection state. Tab cycles the focus ring forward and Shift+Tab
## backward, through all MAX_CREW crew plus a free-explore slot. Left-click in
## the world dispatches `move_to()` on every selected crew. Emits
## `EventBus.crew_selected` whenever the selection changes.

const MAX_CREW: int = 12
const SCAN_RADIUS: float = 220.0
const SCAN_RADIUS_GEOLOGIST: float = 440.0  # 2× per spec §5.4
const DEPARTURE_STAGGER: float = 0.35  # sec between each crew's move_to start

# Manual rising-edge tracking. Godot's `is_action_just_pressed` is unreliable
# in headless mode when the action is synthesized via `Input.action_press`
# (it may resolve as `false` even on the frame the press was registered).
# Tracking previous-frame state ourselves works for both real key events and
# test-driven synthetic input.
var _prev_pressed: Dictionary = {}

## Index into the gamepad focus ring: 1..MAX_CREW are crew, 0 is free explore.
var _focus_slot: int = 1


func _ready() -> void:
	# PadInput locates the manager by group rather than a hard NodePath, the
	# same way zoom_controls.gd finds the camera.
	add_to_group("crew_manager")


func _physics_process(_delta: float) -> void:
	# Polled in _physics_process (not _process) so headless test runs that
	# only tick `physics_frame` still see the input edge. _process can be
	# skipped in headless mode when there's no render loop.
	# Tab cycles the focus ring forward, Shift+Tab backward. Replaces the old
	# select_crew_1..6 number keys, which stopped scaling once the roster grew
	# past the number row.
	var back: bool = Input.is_key_pressed(KEY_SHIFT)
	var cycle_pressed: bool = Input.is_action_pressed("cycle_crew")
	var cycle_prev: bool = _prev_pressed.get("cycle_crew", false)
	_prev_pressed["cycle_crew"] = cycle_pressed
	if cycle_pressed and not cycle_prev:
		cycle_focus(-1 if back else 1)
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
	var rn: Node2D = _find_sampleable(crew)
	if rn == null:
		EventBus.log_message.emit("No deposit in range to sample", "alert")
		return
	rn.collect_one()


func _find_sampleable(crew: CrewMember) -> Node2D:
	for node in get_tree().get_nodes_in_group("resource_node"):
		var rn: Node2D = node as Node2D
		if rn == null:
			continue
		if rn.has_method("can_be_sampled_by") and rn.can_be_sampled_by(crew.global_position):
			return rn
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Move on left double-click. Single-click left-down is reserved for
		# selection (Phase-9 polish) and to keep trackpad single-tap from
		# misfiring path commands while panning.
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
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

	# Keep the focus ring in step with selection made by any other route (the
	# crew HUD panel, a test calling _select), so the next cycle continues here.
	_focus_slot = crew_id
	EventBus.crew_selected.emit(crew_id)
	EventBus.log_message.emit(
		"Selected %s (crew_id=%d)" % [target.crew_name, crew_id], "selection"
	)


## Every selected crew pathfinds independently to the clicked target,
## with a staggered departure time so a stack of overlapping crew don't
## all leave as one blob — each subsequent crew starts moving
## DEPARTURE_STAGGER seconds after the previous one. (User's
## "follow-the-leader" / convoy-departure pattern.)
func _issue_move(target: Vector2) -> void:
	var i: int = 0
	for child in get_children():
		var crew := child as CrewMember
		if crew != null and crew.selected:
			crew.clear_follow()
			_stagger_move(crew, target, float(i) * DEPARTURE_STAGGER)
			i += 1


func _stagger_move(crew: CrewMember, target: Vector2, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(crew) or not crew.selected:
		return
	crew.move_to(target)


# --- Focus ring -------------------------------------------------------------
# Both Tab and the gamepad cycle button drive one ring: crew 1 -> 2 -> ... ->
# MAX_CREW -> free explore -> crew 1. Free explore deselects everyone, which
# also stops crew walking on its own (crew_member.gd only reads movement input
# while `selected`).

func has_selection() -> bool:
	return _first_selected() != null


func deselect_all() -> void:
	for child in get_children():
		var crew := child as CrewMember
		if crew != null:
			crew.set_selected(false)


## Advance the focus ring by `step` slots and apply the new focus.
## Slot 0 is free explore; slots 1..MAX_CREW are crew ids.
func cycle_focus(step: int = 1) -> void:
	var slots: int = MAX_CREW + 1
	_focus_slot = posmod(_focus_slot + step, slots)
	if _focus_slot == 0:
		deselect_all()
		# crew_id 0 means "nobody" — world_camera.gd switches to PAN on it.
		EventBus.crew_selected.emit(0)
		EventBus.log_message.emit("Free explore — camera unlocked", "selection")
		return
	_select(_focus_slot, false)


## Fire the selected crew role action. Returns false when nothing is selected,
## which is how PadInput knows it is in free explore and should recenter the
## camera instead.
func invoke_context_action() -> bool:
	var primary: CrewMember = _first_selected()
	if primary == null:
		return false
	if primary.role == CrewMember.Role.SCIENTIST:
		_do_deploy_probe(primary)
	elif _find_sampleable(primary) != null:
		_do_collect_sample(primary)
	else:
		_do_scan(primary)
	return true
