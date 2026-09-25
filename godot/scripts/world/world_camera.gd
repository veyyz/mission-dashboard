class_name WorldCamera
extends Camera2D
## Zoomable bird's-eye camera with 10 incremental steps from full-strategic
## (step 0, centered on map origin) to close-gameplay (step 9, centered on
## the currently selected crew). Each Zoom In / Zoom Out click advances one
## step and animates both zoom and position via Tween.

# 10 levels (geometric) from full-map (0.13×) to close-gameplay (2.85×).
# 0.13 lets a 145x145 iso map (~9216x4608 px) fit inside 1920x1080 with margin.
const ZOOM_LEVELS: Array[Vector2] = [
	Vector2(0.13, 0.13),
	Vector2(0.18, 0.18),
	Vector2(0.25, 0.25),
	Vector2(0.35, 0.35),
	Vector2(0.50, 0.50),
	Vector2(0.70, 0.70),
	Vector2(1.00, 1.00),
	Vector2(1.40, 1.40),
	Vector2(2.00, 2.00),
	Vector2(2.85, 2.85),
]

const ANIM_SECONDS: float = 0.22
const LANDING_ANIM_SECONDS: float = 0.7  # camera fly-in on landing confirm
const LANDING_TARGET_STEP: int = 7  # gameplay zoom after landing (1.40×)
const STRATEGIC_CENTER: Vector2 = Vector2.ZERO
const STRATEGIC_ZOOM: Vector2 = Vector2(0.13, 0.13)  # alias for ground.gd boot setup
const STRATEGIC_STEP_THRESHOLD: int = 2  # step <= threshold ⇒ strategic level

enum CameraMode { FOLLOW, PAN }

var step: int = 0
var mode: CameraMode = CameraMode.FOLLOW
var _selected_crew: Node2D = null
## Last crew actually selected. Survives a deselect so free explore can snap
## back to somebody.
var _last_crew: Node2D = null
## True while the gamepad free-explore slot is active, so leaving it can
## restore FOLLOW without clobbering a PAN the player picked themselves.
var _free_explore: bool = false
var _tween: Tween
var _last_level: String = ""
var _landing_pos: Vector2 = Vector2.INF  # set when landing confirmed; zoom centers on it
var _panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.INF


func _ready() -> void:
	add_to_group("world_camera")
	make_current()
	EventBus.crew_selected.connect(_on_crew_selected)
	EventBus.landing_confirmed.connect(_on_landing_confirmed)
	_emit_level_changed()


func current_level() -> String:
	return "strategic" if step <= STRATEGIC_STEP_THRESHOLD else "gameplay"


func _emit_level_changed() -> void:
	var level: String = current_level()
	if level != _last_level:
		_last_level = level
		EventBus.zoom_changed.emit(level)


func zoom_in() -> void:
	if step >= ZOOM_LEVELS.size() - 1:
		return
	step += 1
	_apply_step()


func zoom_out() -> void:
	if step <= 0:
		return
	step -= 1
	_apply_step()


func current_step() -> int:
	return step


func max_step() -> int:
	return ZOOM_LEVELS.size() - 1


func _apply_step() -> void:
	var target_zoom: Vector2 = ZOOM_LEVELS[step]
	var target_pos: Vector2 = global_position
	if mode == CameraMode.FOLLOW:
		# At strategic zoom, sit at map origin so the whole map shows.
		# Past the threshold, anchor fully on the gameplay anchor (selected
		# crew / landing site / first crew). No lerp blend — user expected
		# FOLLOW to actually center.
		if step <= STRATEGIC_STEP_THRESHOLD:
			target_pos = STRATEGIC_CENTER
		else:
			target_pos = _gameplay_anchor()
	_animate(target_pos, target_zoom, ANIM_SECONDS)
	_emit_level_changed()


func set_mode(m: int) -> void:
	mode = m


func current_mode() -> int:
	return mode


func toggle_mode() -> void:
	mode = CameraMode.PAN if mode == CameraMode.FOLLOW else CameraMode.FOLLOW
	# In FOLLOW, immediately re-anchor to the selected crew at the current step.
	if mode == CameraMode.FOLLOW:
		_apply_step()


func _gameplay_anchor() -> Vector2:
	if _selected_crew != null:
		return _selected_crew.global_position
	if _landing_pos != Vector2.INF:
		return _landing_pos
	return _fallback_crew_pos()


## On landing confirmed, fly the camera from strategic to gameplay range.
## Skips the per-step Tween animation in favor of a longer "fly-in" feel.
func _on_landing_confirmed(grid_pos: Vector2i) -> void:
	# Convert iso cell to world; same math the TileMapLayer uses, but we
	# don't have a layer reference here — use the diamond-down formula
	# (cell (a, b) → ((a-b)*W/2, (a+b)*H/2)). Tile size = 64x32.
	_landing_pos = Vector2(float(grid_pos.x - grid_pos.y) * 32.0, float(grid_pos.x + grid_pos.y) * 16.0)
	step = LANDING_TARGET_STEP
	_animate(_landing_pos, ZOOM_LEVELS[step], LANDING_ANIM_SECONDS)
	_emit_level_changed()


func _fallback_crew_pos() -> Vector2:
	var crew_nodes: Array = get_tree().get_nodes_in_group("crew")
	if crew_nodes.is_empty():
		return STRATEGIC_CENTER
	var first: Node2D = crew_nodes[0]
	return first.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		# Trackpad pinch (macOS / touchscreen).
		var mg: InputEventMagnifyGesture = event
		if mg.factor > 1.0:
			zoom_in()
		elif mg.factor < 1.0:
			zoom_out()
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		# Trackpad two-finger pan → world pan (laptop without middle mouse).
		var pg: InputEventPanGesture = event
		pan_by(pg.delta)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Pan via middle/right-mouse drag — only in PAN mode. FOLLOW mode owns
	# the camera position and continuously tracks the selected crew below.
	var pressed: bool = mode == CameraMode.PAN and (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
	var current: Vector2 = get_viewport().get_mouse_position()
	if pressed and _last_mouse_pos != Vector2.INF:
		# Drag pulls the world with the cursor, so the camera moves opposite.
		pan_by(-(current - _last_mouse_pos))
	_last_mouse_pos = current if pressed else Vector2.INF

	# FOLLOW mode: every frame, snap to the selected crew so the camera
	# tracks them as they walk. Tween-busy check removed — the position
	# snap overrides the tween's position channel; zoom still animates
	# (Tween's zoom channel runs independently).
	if mode == CameraMode.FOLLOW \
			and step > STRATEGIC_STEP_THRESHOLD \
			and _selected_crew != null:
		global_position = _selected_crew.global_position


## Move the camera by a screen-space delta, converting to world space through
## the world root's rotation (Ground.tscn is rotated while the camera runs with
## `ignore_rotation`) and the current zoom. Shared by mouse drag, trackpad pan,
## and the gamepad free-explore stick.
func pan_by(screen_delta: Vector2) -> void:
	# A deliberate pan outranks a zoom/recenter animation still in flight —
	# otherwise the tween writes global_position back every frame and the pan
	# goes nowhere. Snap zoom to the step it was heading for so killing the
	# tween doesn't strand it mid-interpolation.
	if _tween != null and _tween.is_valid():
		_tween.kill()
		zoom = ZOOM_LEVELS[step]
	var world_root: Node = get_tree().get_first_node_in_group("world_root")
	var world_rot: float = (world_root as Node2D).rotation if world_root is Node2D else 0.0
	global_position += screen_delta.rotated(world_rot) / zoom


## Leave free explore: re-lock FOLLOW onto the last crew and re-anchor.
func recenter_on_last_crew() -> void:
	_free_explore = false
	if _selected_crew == null and _last_crew != null and is_instance_valid(_last_crew):
		_selected_crew = _last_crew
	mode = CameraMode.FOLLOW
	_apply_step()


func _on_crew_selected(crew_id: int) -> void:
	# crew_id 0 = nobody (gamepad free-explore slot). Drop the follow target,
	# otherwise FOLLOW keeps snapping to a crew that is no longer selected.
	if crew_id == 0:
		_selected_crew = null
		_free_explore = true
		mode = CameraMode.PAN
		return
	for node in get_tree().get_nodes_in_group("crew"):
		if node.has_method("get") and node.get("crew_id") == crew_id:
			_selected_crew = node
			_last_crew = node
			# Leaving free explore re-locks FOLLOW. A PAN the player chose
			# themselves is left alone.
			if _free_explore:
				_free_explore = false
				mode = CameraMode.FOLLOW
			# Auto-recenter only in FOLLOW mode. PAN mode preserves user's
			# manual camera position when crew selection changes.
			if mode == CameraMode.FOLLOW and step > 0:
				_apply_step()
			return


func _animate(target_pos: Vector2, target_zoom: Vector2, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_pos, seconds)
	_tween.tween_property(self, "zoom", target_zoom, seconds)
