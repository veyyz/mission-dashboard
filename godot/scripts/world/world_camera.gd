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
const STRATEGIC_CENTER: Vector2 = Vector2.ZERO
const STRATEGIC_ZOOM: Vector2 = Vector2(0.13, 0.13)  # alias for ground.gd boot setup
const STRATEGIC_STEP_THRESHOLD: int = 2  # step <= threshold ⇒ strategic level

var step: int = 0
var _selected_crew: Node2D = null
var _tween: Tween
var _last_level: String = ""


func _ready() -> void:
	add_to_group("world_camera")
	EventBus.crew_selected.connect(_on_crew_selected)
	# Fire an initial zoom_changed so subscribers (OrbitMap UI) can sync.
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
	# Lerp the camera position from the strategic origin (step 0) toward the
	# selected crew (step max). Intermediate steps blend smoothly so the
	# user gets both more zoom AND more focus on the selected crew per click.
	var t: float = float(step) / float(ZOOM_LEVELS.size() - 1)
	var crew_pos: Vector2 = _selected_crew.global_position if _selected_crew != null else _fallback_crew_pos()
	var target_pos: Vector2 = STRATEGIC_CENTER.lerp(crew_pos, t)
	_animate(target_pos, target_zoom)
	_emit_level_changed()


func _fallback_crew_pos() -> Vector2:
	var crew_nodes: Array = get_tree().get_nodes_in_group("crew")
	if crew_nodes.is_empty():
		return STRATEGIC_CENTER
	var first: Node2D = crew_nodes[0]
	return first.global_position


func _on_crew_selected(crew_id: int) -> void:
	for node in get_tree().get_nodes_in_group("crew"):
		if node.has_method("get") and node.get("crew_id") == crew_id:
			_selected_crew = node
			# Re-apply the current step so the camera re-centers on the new
			# selection — at high zoom the previous crew is off-screen
			# otherwise.
			if step > 0:
				_apply_step()
			return


func _animate(target_pos: Vector2, target_zoom: Vector2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_pos, ANIM_SECONDS)
	_tween.tween_property(self, "zoom", target_zoom, ANIM_SECONDS)
