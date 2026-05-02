extends PanelContainer
## Bottom-left crew bar. One portrait per spawned crew. Click selects;
## subscribes to EventBus.crew_selected to highlight whichever crew the
## player picked via 1-6 keys or in-world. The crew nodes themselves come
## from `get_tree().get_nodes_in_group("crew")` so this scene doesn't have
## to know how the world is wired.

const ROLE_COLOR := {
	0: Color(0.36, 0.71, 0.84),  # ENGINEER
	1: Color(0.66, 0.45, 0.85),  # SCIENTIST
	2: Color(0.45, 0.78, 0.50),  # BOTANIST
	3: Color(0.95, 0.71, 0.30),  # GEOLOGIST
	4: Color(0.92, 0.40, 0.45),  # MEDIC
	5: Color(0.95, 0.85, 0.45),  # COMMANDER
}

@onready var hbox: HBoxContainer = $Margin/VBox/HBox

var _selected_id: int = -1
var _portraits: Array[Control] = []
var _populated: bool = false


func _ready() -> void:
	EventBus.crew_selected.connect(_on_crew_selected)


func _process(_delta: float) -> void:
	if _populated:
		return
	# Crew are spawned from Ground._ready() asynchronously after Ground.
	# Wait until they exist, then build the bar once.
	var crew_nodes: Array = get_tree().get_nodes_in_group("crew")
	if crew_nodes.size() > 0:
		crew_nodes.sort_custom(func(a, b): return a.crew_id < b.crew_id)
		for crew in crew_nodes:
			_add_portrait(crew)
		_populated = true


func _add_portrait(crew: Node) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 80)
	btn.toggle_mode = true
	btn.text = "%d\n%s\n%d" % [crew.crew_id, crew.crew_name, crew.role_skill]
	btn.add_theme_color_override("font_color", ROLE_COLOR.get(crew.role, Color.WHITE))
	btn.set_meta("crew_id", crew.crew_id)
	btn.pressed.connect(_on_portrait_pressed.bind(crew.crew_id))
	hbox.add_child(btn)
	_portraits.append(btn)


func _on_portrait_pressed(crew_id: int) -> void:
	EventBus.crew_selected.emit(crew_id)


func _on_crew_selected(crew_id: int) -> void:
	_selected_id = crew_id
	for portrait in _portraits:
		portrait.button_pressed = (portrait.get_meta("crew_id") == crew_id)
