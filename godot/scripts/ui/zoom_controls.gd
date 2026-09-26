extends CanvasLayer
## Zoom in / out buttons. Finds the WorldCamera via the "world_camera" group.

@onready var zoom_in_btn: Button = $Panel/Margin/HBox/ZoomIn
@onready var zoom_out_btn: Button = $Panel/Margin/HBox/ZoomOut
@onready var step_label: Label = $Panel/Margin/HBox/StepLabel
@onready var mode_button: Button = $Panel/Margin/HBox/ModeButton

# Typed as Camera2D rather than WorldCamera to dodge GDScript's class_name
# discovery lag in headless mode. Methods are called dynamically.
var _camera: Camera2D = null


func _ready() -> void:
	preload("res://scripts/ui/hud_chrome.gd").install($Panel, "ZOOM")
	zoom_in_btn.pressed.connect(_on_zoom_in)
	zoom_out_btn.pressed.connect(_on_zoom_out)
	mode_button.pressed.connect(_on_mode_pressed)
	_refresh_label()


func _process(_delta: float) -> void:
	# Refresh on each frame so the label tracks the camera's actual step
	# (in case zoom is driven from somewhere other than these buttons).
	_refresh_label()
	_refresh_mode_button()


func _resolve_camera() -> Camera2D:
	if _camera != null:
		return _camera
	var nodes: Array = get_tree().get_nodes_in_group("world_camera")
	if nodes.is_empty():
		return null
	_camera = nodes[0] as Camera2D
	return _camera


func _on_zoom_in() -> void:
	var cam: Camera2D = _resolve_camera()
	if cam != null and cam.has_method("zoom_in"):
		cam.zoom_in()


func _on_zoom_out() -> void:
	var cam: Camera2D = _resolve_camera()
	if cam != null and cam.has_method("zoom_out"):
		cam.zoom_out()


func _refresh_label() -> void:
	if step_label == null:
		return
	var cam: Camera2D = _resolve_camera()
	if cam != null and cam.has_method("current_step") and cam.has_method("max_step"):
		step_label.text = "%d / %d" % [int(cam.current_step()) + 1, int(cam.max_step()) + 1]
	else:
		step_label.text = "—"


func _refresh_mode_button() -> void:
	if mode_button == null:
		return
	var cam: Camera2D = _resolve_camera()
	if cam == null or not cam.has_method("current_mode"):
		return
	# CameraMode.FOLLOW = 0, PAN = 1.
	var m: int = int(cam.current_mode())
	mode_button.text = "FOLLOW" if m == 0 else "PAN"
	mode_button.button_pressed = (m == 1)


func _on_mode_pressed() -> void:
	var cam: Camera2D = _resolve_camera()
	if cam != null and cam.has_method("toggle_mode"):
		cam.toggle_mode()
