extends CanvasLayer
## Phase-7 strategic-zoom UI overlay (refactored).
##  - At strategic zoom: visible hint "Click anywhere to land" + the 10×10
##    grid corner labels (A–J × 1–10) + a tile-info panel populated from
##    `data/orbit_deposits.json` once the cursor hovers a known cell.
##  - The actual landing-site ghost lives in world space under
##    YSort/LandingPlacement (see scripts/world/landing_placement.gd).
##  - Fades in/out on EventBus.zoom_changed.
##  - On EventBus.landing_confirmed, hides itself permanently.

const DATA_PATH: String = "res://data/orbit_deposits.json"
const FADE_SECONDS: float = 0.35

@onready var fade_root: Control = $Root
@onready var grid_label_root: Control = $Root/GridLabels
@onready var hint_label: Label = $Root/HintLabel
@onready var tooltip: PanelContainer = $Root/TilePanel
@onready var tooltip_id: Label = $Root/TilePanel/Margin/VBox/IDLabel
@onready var tooltip_terrain: Label = $Root/TilePanel/Margin/VBox/TerrainLabel
@onready var tooltip_hazards: Label = $Root/TilePanel/Margin/VBox/HazardsLabel
@onready var tooltip_reco: Label = $Root/TilePanel/Margin/VBox/RecoLabel

var _data: Dictionary = {}
var _deposits: Array = []
var _suggested_tile: Vector2i = Vector2i(4, 4)
var _tween: Tween
var _landed: bool = false


func _ready() -> void:
	_load_data()
	_build_grid_labels()
	tooltip.visible = false
	hint_label.text = "Click anywhere on the moon to deploy landing module"
	EventBus.zoom_changed.connect(_on_zoom_changed)
	EventBus.landing_confirmed.connect(_on_landing_confirmed)
	fade_root.modulate.a = 1.0


func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_data = parsed
	var s: Array = _data.get("suggested_landing_tile", [4, 4])
	_suggested_tile = Vector2i(int(s[0]), int(s[1]))
	_deposits = _data.get("tiles", [])


func _build_grid_labels() -> void:
	const COLS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
	for i in range(10):
		var col_lbl := Label.new()
		col_lbl.text = COLS[i]
		col_lbl.position = Vector2(80 + i * 32, 8)
		col_lbl.add_theme_color_override("font_color", Color(0.55, 0.61, 0.7))
		grid_label_root.add_child(col_lbl)
		var row_lbl := Label.new()
		row_lbl.text = str(i + 1)
		row_lbl.position = Vector2(20, 40 + i * 32)
		row_lbl.add_theme_color_override("font_color", Color(0.55, 0.61, 0.7))
		grid_label_root.add_child(row_lbl)


func _on_zoom_changed(level: String) -> void:
	if _landed:
		_animate_fade(0.0)
		return
	var target: float = 1.0 if level == "strategic" else 0.0
	_animate_fade(target)


func _animate_fade(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fade_root, "modulate:a", target, FADE_SECONDS)
	fade_root.mouse_filter = Control.MOUSE_FILTER_PASS if target > 0.0 else Control.MOUSE_FILTER_IGNORE


func _on_landing_confirmed(_cell: Vector2i) -> void:
	_landed = true
	_animate_fade(0.0)


# --- Public surface for tests ---

func deposits_count() -> int:
	return _deposits.size()


func suggested_tile() -> Vector2i:
	return _suggested_tile
