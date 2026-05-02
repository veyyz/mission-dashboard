extends PanelContainer
## Top-center resource bar — six core resources horizontal, with current
## value and +rate/min underneath each. Subscribes to
## EventBus.resource_changed and updates only the affected entry.

const RESOURCE_ORDER: Array[String] = [
	"power", "oxygen", "food", "materials", "science", "crew",
]

const RESOURCE_GLYPH := {
	"power":     "⚡",
	"oxygen":    "O₂",
	"food":      "🌱",
	"materials": "▣",
	"science":   "🧪",
	"crew":      "👥",
}

const RESOURCE_COLOR := {
	"power":     Color(0.95, 0.71, 0.30),
	"oxygen":    Color(0.36, 0.81, 0.95),
	"food":      Color(0.45, 0.78, 0.50),
	"materials": Color(0.70, 0.72, 0.75),
	"science":   Color(0.66, 0.45, 0.85),
	"crew":      Color(0.95, 0.71, 0.30),
}

@onready var hbox: HBoxContainer = $Margin/HBox

var _value_labels: Dictionary = {}
var _rate_labels: Dictionary = {}


func _ready() -> void:
	for r_name in RESOURCE_ORDER:
		_build_entry(r_name)
	for r_name in RESOURCE_ORDER:
		_refresh(
			r_name,
			ResourceManager.get_current(r_name),
			ResourceManager.get_max(r_name),
			ResourceManager.get_rate(r_name),
		)
	EventBus.resource_changed.connect(_on_resource_changed)


func _build_entry(r_name: String) -> void:
	var col := VBoxContainer.new()
	col.name = "Col_" + r_name
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	hbox.add_child(col)

	var glyph_value := HBoxContainer.new()
	glyph_value.alignment = BoxContainer.ALIGNMENT_CENTER
	glyph_value.add_theme_constant_override("separation", 6)
	col.add_child(glyph_value)

	var glyph := Label.new()
	glyph.text = RESOURCE_GLYPH.get(r_name, "?")
	glyph.add_theme_color_override("font_color", RESOURCE_COLOR.get(r_name, Color.WHITE))
	glyph.add_theme_font_size_override("font_size", 18)
	glyph_value.add_child(glyph)

	var value := Label.new()
	value.add_theme_color_override("font_color", Color(0.91, 0.93, 0.95))
	value.add_theme_font_size_override("font_size", 18)
	glyph_value.add_child(value)
	_value_labels[r_name] = value

	var rate := Label.new()
	rate.add_theme_color_override("font_color", Color(0.55, 0.61, 0.7))
	rate.add_theme_font_size_override("font_size", 11)
	rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rate)
	_rate_labels[r_name] = rate


func _on_resource_changed(r_name: String, current: float, maximum: float, rate: float) -> void:
	_refresh(r_name, current, maximum, rate)


func _refresh(r_name: String, current: float, _maximum: float, rate: float) -> void:
	if not _value_labels.has(r_name):
		return
	_value_labels[r_name].text = "%d" % int(current)
	if rate >= 0.0:
		_rate_labels[r_name].text = "+%.1f/min" % rate
	else:
		_rate_labels[r_name].text = "%.1f/min" % rate
