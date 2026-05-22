extends CanvasLayer
## Debug-only sliders for tuning terrain overlay rotation + scale + shear +
## opacity. Values reported in labels so user can read them and bake
## into `terrain_overlay.gd` as defaults.

@onready var collapse_btn: Button = $Panel/Margin/VBox/Header/CollapseButton
@onready var content: VBoxContainer = $Panel/Margin/VBox/Content
@onready var rot_slider: HSlider = $Panel/Margin/VBox/Content/RotSlider
@onready var rot_label: Label = $Panel/Margin/VBox/Content/RotLabel
@onready var scale_x_slider: HSlider = $Panel/Margin/VBox/Content/ScaleXSlider
@onready var scale_x_label: Label = $Panel/Margin/VBox/Content/ScaleXLabel
@onready var scale_y_slider: HSlider = $Panel/Margin/VBox/Content/ScaleYSlider
@onready var scale_y_label: Label = $Panel/Margin/VBox/Content/ScaleYLabel
@onready var shear_x_slider: HSlider = $Panel/Margin/VBox/Content/ShearXSlider
@onready var shear_x_label: Label = $Panel/Margin/VBox/Content/ShearXLabel
@onready var shear_y_slider: HSlider = $Panel/Margin/VBox/Content/ShearYSlider
@onready var shear_y_label: Label = $Panel/Margin/VBox/Content/ShearYLabel
@onready var opacity_slider: HSlider = $Panel/Margin/VBox/Content/OpacitySlider
@onready var opacity_label: Label = $Panel/Margin/VBox/Content/OpacityLabel

var _terrain: Sprite2D = null


func _ready() -> void:
	collapse_btn.pressed.connect(_on_collapse_pressed)
	var nodes: Array = get_tree().get_nodes_in_group("terrain_overlay")
	if not nodes.is_empty():
		_terrain = nodes[0]

	if _terrain != null:
		rot_slider.value     = _terrain.current_rotation_deg()
		scale_x_slider.value = _terrain.current_scale_x()
		scale_y_slider.value = _terrain.current_scale_y()
		shear_x_slider.value = _terrain.current_shear_x()
		shear_y_slider.value = _terrain.current_shear_y()
		opacity_slider.value = _terrain.current_opacity()

	rot_slider.value_changed.connect(_on_rot)
	scale_x_slider.value_changed.connect(_on_scale_x)
	scale_y_slider.value_changed.connect(_on_scale_y)
	shear_x_slider.value_changed.connect(_on_shear_x)
	shear_y_slider.value_changed.connect(_on_shear_y)
	opacity_slider.value_changed.connect(_on_opacity)
	_refresh_labels()


func _on_collapse_pressed() -> void:
	content.visible = not content.visible
	collapse_btn.text = "▼" if content.visible else "▶"


func _on_rot(v: float) -> void:
	if _terrain != null: _terrain.set_rotation_cw_deg(v)
	_refresh_labels()


func _on_scale_x(v: float) -> void:
	if _terrain != null: _terrain.set_scale_x(v)
	_refresh_labels()


func _on_scale_y(v: float) -> void:
	if _terrain != null: _terrain.set_scale_y(v)
	_refresh_labels()


func _on_shear_x(v: float) -> void:
	if _terrain != null: _terrain.set_shear_x(v)
	_refresh_labels()


func _on_shear_y(v: float) -> void:
	if _terrain != null: _terrain.set_shear_y(v)
	_refresh_labels()


func _on_opacity(v: float) -> void:
	if _terrain != null and _terrain.has_method("set_opacity"):
		_terrain.set_opacity(v)
	_refresh_labels()


func _refresh_labels() -> void:
	rot_label.text     = "rotation: %d°" % int(round(rot_slider.value))
	scale_x_label.text = "scale_x: %.2f" % scale_x_slider.value
	scale_y_label.text = "scale_y: %.2f" % scale_y_slider.value
	shear_x_label.text = "shear_x: %.2f" % shear_x_slider.value
	shear_y_label.text = "shear_y: %.2f" % shear_y_slider.value
	opacity_label.text = "opacity: %.2f" % opacity_slider.value
