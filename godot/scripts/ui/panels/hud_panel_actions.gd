extends PanelContainer
## Bottom-center quick-actions strip. Five buttons (Move / Scan / Probe /
## Sample / Crew Menu) with key hints. Phase-6 wiring is visual only —
## click handlers fire EventBus.log_message stubs; the real R/F/G action
## logic lands in Phase 8.

const ACTIONS: Array = [
	{"label": "Move",          "key": "click",   "category": "action"},
	{"label": "Scan",          "key": "R",       "category": "action"},
	{"label": "Deploy Probe",  "key": "F",       "category": "action"},
	{"label": "Collect Sample","key": "G",       "category": "action"},
	{"label": "Crew Menu",     "key": "C",       "category": "action"},
]

@onready var hbox: HBoxContainer = $Margin/HBox


func _ready() -> void:
	for action in ACTIONS:
		var btn := Button.new()
		btn.text = "%s\n[%s]" % [action.label, action.key]
		btn.custom_minimum_size = Vector2(96, 48)
		btn.pressed.connect(_on_action_pressed.bind(action.label, action.category))
		hbox.add_child(btn)


func _on_action_pressed(label: String, category: String) -> void:
	EventBus.log_message.emit("Action: %s (Phase 8 wiring)" % label, category)
