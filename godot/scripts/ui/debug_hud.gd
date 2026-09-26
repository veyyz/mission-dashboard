extends CanvasLayer
## Phase-3 debug overlay. Replaced by the real HUD in Phase 6.
## Subscribes to EventBus signals — does NOT poll managers.

const RESOURCE_ORDER: Array[String] = [
	"power", "oxygen", "water", "food", "science", "crew",
]

const RESOURCE_GLYPH := {
	"power":     "P",
	"oxygen":    "O",
	"food":      "F",
	"water":     "W",
	"science":   "S",
	"crew":      "C",
}

@onready var resource_box: VBoxContainer = $Panel/Margin/VBox/Resources
@onready var time_label: Label = $Panel/Margin/VBox/TimeLabel
@onready var phase_label: Label = $Panel/Margin/VBox/PhaseLabel

var _resource_labels: Dictionary = {}


func _ready() -> void:
	for r_name in RESOURCE_ORDER:
		var lbl := Label.new()
		lbl.name = "res_" + r_name
		lbl.add_theme_color_override("font_color", Color(0.91, 0.93, 0.95))
		resource_box.add_child(lbl)
		_resource_labels[r_name] = lbl
		_refresh_resource(
			r_name,
			ResourceManager.get_current(r_name),
			ResourceManager.get_max(r_name),
			ResourceManager.get_rate(r_name),
		)

	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(TimeManager.current_phase)


func _process(_delta: float) -> void:
	time_label.text = "Day %d  %s" % [TimeManager.current_day, TimeManager.get_time_string()]


func _on_resource_changed(r_name: String, current: float, maximum: float, rate: float) -> void:
	_refresh_resource(r_name, current, maximum, rate)


func _on_phase_changed(phase: String) -> void:
	phase_label.text = "Phase: " + phase.to_upper()


func _refresh_resource(r_name: String, current: float, maximum: float, rate: float) -> void:
	if not _resource_labels.has(r_name):
		return
	var glyph: String = RESOURCE_GLYPH.get(r_name, "?")
	var rate_str: String = "  +%.1f/min" % rate if rate >= 0.0 else "  %.1f/min" % rate
	_resource_labels[r_name].text = "%s %-10s %d / %d%s" % [
		glyph, r_name, int(current), int(maximum), rate_str,
	]
