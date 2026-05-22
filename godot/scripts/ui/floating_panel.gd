extends Control
## Drag handle. Attach as a child Control (header bar) of any floating panel.
## Left-mouse drag on this Control moves the target Control (the panel) by
## the drag delta. Auto-finds the nearest PanelContainer ancestor if no
## explicit target_path is set.

@export var target_path: NodePath

var _target: Control = null
var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target = get_node_or_null(target_path) if target_path != NodePath() else _find_panel_ancestor()
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)


func _find_panel_ancestor() -> Control:
	var n: Node = get_parent()
	while n != null:
		if n is PanelContainer or n is Panel:
			return n as Control
		n = n.get_parent()
	return null


func _on_input(event: InputEvent) -> void:
	if _target == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if _dragging:
				_grab_offset = _target.global_position - get_global_mouse_position()
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_target.global_position = get_global_mouse_position() + _grab_offset
		accept_event()
