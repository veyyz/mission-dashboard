extends CanvasLayer
## Phase-5 build menu (placeholder UX). Lists the 3 v1 buildings and routes
## the click to the BuildPlacementController.

## Listed in bootstrap order (same sequence as the Guide tip and
## economy_test check 9): power → ore → life support → refining → fabrication
## → bulk regolith, then expansion.
const BUILDABLE_KEYS: Array[String] = [
	"solar_array",
	"mining_drill",
	"electrolyzer",
	"reduction_plant",
	"matter_forge",
	"mre_smelter",
	"regolith_excavator",
	"sintering_kiln",
	"comms_dish",
	"rtg",
	"storage_silo",
	"habitat_module",
	"hydroponics_bay",
	"research_lab",
	"hospital",
]

@export var placement_controller_path: NodePath

@onready var button_box: VBoxContainer = $Panel/Margin/VBox/Content/Buttons
@onready var status_label: Label = $Panel/Margin/VBox/Content/StatusLabel

var _placement: Node = null


func _ready() -> void:
	# Header bar (drag / collapse / dock / resize) comes from the shared chrome.
	preload("res://scripts/ui/hud_chrome.gd").install($Panel, "BUILD")
	_placement = get_node_or_null(placement_controller_path)
	for key in BUILDABLE_KEYS:
		var def: Dictionary = BuildingDatabase.get_definition(key)
		var label: String = def.get("display_name", key)
		var btn := Button.new()
		btn.text = label
		btn.tooltip_text = _format_cost_tooltip(def)
		btn.pressed.connect(_on_button_pressed.bind(key))
		button_box.add_child(btn)
	var demolish_btn := Button.new()
	demolish_btn.text = "Demolish"
	demolish_btn.tooltip_text = "Click a building to remove it. Sites refund 100%, completed refund 50%."
	demolish_btn.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	demolish_btn.pressed.connect(_on_demolish_pressed)
	button_box.add_child(demolish_btn)


func _on_demolish_pressed() -> void:
	if _placement == null:
		status_label.text = "No placement controller wired."
		return
	_placement.start_demolish()
	status_label.text = "Click a building to demolish. Right-click to cancel."


func _format_cost_tooltip(def: Dictionary) -> String:
	var cost: Dictionary = def.get("cost", {})
	var text: String = "Cost: " + (ResourceManager.format_cost(cost) if not cost.is_empty() else "free")
	if def.has("description"):
		text = String(def["description"]) + "\n" + text
	return text


func _on_button_pressed(key: String) -> void:
	if _placement == null:
		status_label.text = "No placement controller wired."
		return
	_placement.start_placement(key)
	status_label.text = "Click to place %s. Right-click to cancel." % key
