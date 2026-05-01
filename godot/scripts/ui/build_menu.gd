extends CanvasLayer
## Phase-5 build menu (placeholder UX). Lists the 3 v1 buildings and routes
## the click to the BuildPlacementController. Replaced by the proper hotbar
## in Phase 6.

const BUILDABLE_KEYS: Array[String] = [
	"solar_array",
	"habitat_module",
	"mining_drill",
]

@export var placement_controller_path: NodePath

@onready var button_box: VBoxContainer = $Panel/Margin/VBox/Buttons
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

var _placement: Node = null


func _ready() -> void:
	_placement = get_node_or_null(placement_controller_path)
	for key in BUILDABLE_KEYS:
		var def: Dictionary = BuildingDatabase.get_definition(key)
		var label: String = def.get("display_name", key)
		var btn := Button.new()
		btn.text = label
		btn.tooltip_text = _format_cost_tooltip(def)
		btn.pressed.connect(_on_button_pressed.bind(key))
		button_box.add_child(btn)


func _format_cost_tooltip(def: Dictionary) -> String:
	var cost: Dictionary = def.get("cost", {})
	var parts: Array[String] = []
	for r_name in cost.keys():
		parts.append("%s %d" % [r_name, int(cost[r_name])])
	return "Cost: " + ", ".join(parts)


func _on_button_pressed(key: String) -> void:
	if _placement == null:
		status_label.text = "No placement controller wired."
		return
	_placement.start_placement(key)
	status_label.text = "Click to place %s. Right-click to cancel." % key
