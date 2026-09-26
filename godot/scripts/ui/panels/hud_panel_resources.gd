extends PanelContainer
## Top-center resource readout, driven entirely by `data/resources.json`
## through ResourceManager so a new resource needs no UI change.
##
##   Vitals row    — power / O₂ / water / food / science / crew, large, with
##                   a thin stock bar under each.
##   Stockpile     — three labelled tiers (RAW → REFINED → COMPONENTS), one
##                   row each. Every resource is a chip: tier-tinted glyph
##                   badge, value, ▲/▼ rate, and a fill bar of stock vs cap.
##                   Chips go amber when pinned at cap (production wasted)
##                   and dim when empty. Collapsible via the divider button.
##
## Subscribes to EventBus.resource_changed and refreshes one entry at a time.

const TIERS: Array = [
	{"group": "raw",       "label": "RAW",        "color": Color(0.85, 0.62, 0.35)},
	{"group": "refined",   "label": "REFINED",    "color": Color(0.36, 0.71, 0.84)},
	{"group": "component", "label": "COMPONENTS", "color": Color(0.66, 0.45, 0.85)},
]

const COL_TEXT: Color = Color(0.91, 0.93, 0.95)
const COL_DIM: Color = Color(0.45, 0.50, 0.58)
const COL_MUTED: Color = Color(0.55, 0.61, 0.70)
const COL_CAP: Color = Color(0.95, 0.71, 0.30)
const COL_UP: Color = Color(0.45, 0.78, 0.50)
const COL_DOWN: Color = Color(0.92, 0.40, 0.45)
const COL_TRACK: Color = Color(1, 1, 1, 0.08)

@onready var vitals_row: HBoxContainer = $Margin/VBox/Vitals
@onready var toggle: Button = $Margin/VBox/Divider/Toggle
@onready var stock_box: VBoxContainer = $Margin/VBox/Stock

## resource key → {value: Label, rate: Label, bar: ProgressBar,
##                  fill: StyleBoxFlat, chip: StyleBoxFlat|null, tier: Color}
var _entries: Dictionary = {}


func _ready() -> void:
	toggle.add_theme_font_size_override("font_size", 10)
	toggle.add_theme_color_override("font_color", COL_MUTED)
	toggle.add_theme_color_override("font_hover_color", COL_TEXT)
	toggle.pressed.connect(_on_toggle_pressed)

	for r_name in ResourceManager.keys_in_group("vital"):
		_build_vital(r_name)
	for tier in TIERS:
		_build_tier_row(tier)

	for r_name in _entries.keys():
		_refresh(
			r_name,
			ResourceManager.get_current(r_name),
			ResourceManager.get_max(r_name),
			ResourceManager.get_rate(r_name),
		)
	_set_stock_visible(true)
	EventBus.resource_changed.connect(_on_resource_changed)


# --- Builders ----------------------------------------------------------------

func _build_vital(r_name: String) -> void:
	var col := VBoxContainer.new()
	col.name = "Col_" + r_name
	col.custom_minimum_size = Vector2(96, 0)
	col.add_theme_constant_override("separation", 2)
	col.tooltip_text = _tooltip_for(r_name)
	vitals_row.add_child(col)
	_make_clickable(col, r_name)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)

	var glyph := Label.new()
	glyph.text = ResourceManager.glyph(r_name)
	glyph.add_theme_color_override("font_color", ResourceManager.color(r_name))
	glyph.add_theme_font_size_override("font_size", 18)
	top.add_child(glyph)

	var value := Label.new()
	value.add_theme_color_override("font_color", COL_TEXT)
	value.add_theme_font_size_override("font_size", 18)
	top.add_child(value)

	var bar_fill: StyleBoxFlat
	var bar := _make_bar(ResourceManager.color(r_name))
	bar_fill = bar.get_theme_stylebox("fill")
	col.add_child(bar)

	var rate := Label.new()
	rate.add_theme_font_size_override("font_size", 11)
	rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rate)

	_entries[r_name] = {
		"value": value, "rate": rate, "bar": bar, "fill": bar_fill,
		"chip": null, "tier": ResourceManager.color(r_name),
	}


func _build_tier_row(tier: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "Tier_" + String(tier["group"])
	row.add_theme_constant_override("separation", 6)
	stock_box.add_child(row)

	# Tier label: small caps, tier colour, with an accent tick to its left.
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(96, 0)
	header.add_theme_constant_override("separation", 6)
	row.add_child(header)
	var tick := ColorRect.new()
	tick.custom_minimum_size = Vector2(3, 0)
	tick.color = tier["color"]
	header.add_child(tick)
	var label := Label.new()
	label.text = String(tier["label"])
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", tier["color"])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	for r_name in ResourceManager.keys_in_group(String(tier["group"])):
		row.add_child(_build_chip(r_name, tier["color"]))


func _build_chip(r_name: String, tier_color: Color) -> Control:
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(1, 1, 1, 0.04)
	chip_style.border_color = Color(tier_color, 0.28)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(4)
	chip_style.content_margin_left = 5
	chip_style.content_margin_right = 7
	chip_style.content_margin_top = 3
	chip_style.content_margin_bottom = 3

	var chip := PanelContainer.new()
	chip.name = "Chip_" + r_name
	chip.custom_minimum_size = Vector2(88, 0)
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.tooltip_text = _tooltip_for(r_name)
	_make_clickable(chip, r_name)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(h)

	# Glyph badge — tier-tinted square with the resource glyph in its colour.
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(tier_color, 0.16)
	badge_style.set_corner_radius_all(3)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(34, 24)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", badge_style)
	h.add_child(badge)
	var glyph := Label.new()
	glyph.text = ResourceManager.glyph(r_name)
	glyph.add_theme_font_size_override("font_size", 11)
	glyph.add_theme_color_override("font_color", ResourceManager.color(r_name))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(glyph)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 1)
	h.add_child(body)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	body.add_child(line)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", COL_TEXT)
	line.add_child(value)
	var rate := Label.new()
	rate.add_theme_font_size_override("font_size", 9)
	rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rate.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	line.add_child(rate)

	var bar := _make_bar(ResourceManager.color(r_name))
	body.add_child(bar)

	_entries[r_name] = {
		"value": value, "rate": rate, "bar": bar,
		"fill": bar.get_theme_stylebox("fill"), "chip": chip_style, "tier": tier_color,
	}
	return chip


## 3-px stock bar. Track is a faint strip; fill takes the resource colour.
func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 3)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	var track := StyleBoxFlat.new()
	track.bg_color = COL_TRACK
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Left-click on a vital column or a stockpile chip opens the resource
## inspector panel for it (HUDPanelResourceInfo listens on EventBus).
func _make_clickable(ctrl: Control, r_name: String) -> void:
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			EventBus.resource_inspect_requested.emit(r_name)
			ctrl.accept_event()
	)


func _tooltip_for(r_name: String) -> String:
	var def: Dictionary = ResourceManager.get_definition(r_name)
	var text: String = "%s  (cap %d)" % [ResourceManager.display_name(r_name), int(ResourceManager.get_max(r_name))]
	if def.has("description"):
		text += "\n" + String(def["description"])
	var drain: float = ResourceManager.life_support_drain(r_name)
	if drain > 0.0:
		text += "\nCrew life support: -%.1f/min" % drain
	return text


# --- Toggle ------------------------------------------------------------------

func _on_toggle_pressed() -> void:
	_set_stock_visible(not stock_box.visible)


func _set_stock_visible(shown: bool) -> void:
	stock_box.visible = shown
	toggle.text = "▾ STOCKPILE" if shown else "▸ STOCKPILE"


# --- Refresh -----------------------------------------------------------------

func _on_resource_changed(r_name: String, current: float, maximum: float, rate: float) -> void:
	_refresh(r_name, current, maximum, rate)


func _refresh(r_name: String, current: float, maximum: float, rate: float) -> void:
	if not _entries.has(r_name):
		return
	var e: Dictionary = _entries[r_name]
	var value: Label = e["value"]
	var rate_label: Label = e["rate"]
	var bar: ProgressBar = e["bar"]
	var fill: StyleBoxFlat = e["fill"]
	var chip: StyleBoxFlat = e["chip"]
	var tier: Color = e["tier"]
	var base_color: Color = ResourceManager.color(r_name)

	value.text = "%d" % int(current)
	bar.value = (current / maximum * 100.0) if maximum > 0.0 else 0.0

	var capped: bool = maximum > 0.0 and current >= maximum
	var empty: bool = current <= 0.0
	if capped:
		value.add_theme_color_override("font_color", COL_CAP)
		fill.bg_color = COL_CAP
		if chip != null:
			chip.border_color = Color(COL_CAP, 0.7)
			chip.bg_color = Color(COL_CAP, 0.08)
	elif empty:
		value.add_theme_color_override("font_color", COL_DIM)
		fill.bg_color = base_color
		if chip != null:
			chip.border_color = Color(tier, 0.18)
			chip.bg_color = Color(1, 1, 1, 0.02)
	else:
		value.add_theme_color_override("font_color", COL_TEXT)
		fill.bg_color = base_color
		if chip != null:
			chip.border_color = Color(tier, 0.28)
			chip.bg_color = Color(1, 1, 1, 0.04)

	if is_zero_approx(rate):
		rate_label.text = ""
	elif rate > 0.0:
		rate_label.text = "▲%.1f" % rate
		rate_label.add_theme_color_override("font_color", COL_UP)
	else:
		rate_label.text = "▼%.1f" % -rate
		rate_label.add_theme_color_override("font_color", COL_DOWN)
