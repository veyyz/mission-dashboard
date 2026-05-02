extends CanvasLayer
## Phase-7 strategic-zoom UI overlay.
##  - Loads `data/orbit_deposits.json` and renders deposit markers + the
##    suggested-landing-zone box on top of the world's tilemap.
##  - 10×10 grid label overlay (A–J × 1–10).
##  - Hover-tooltip with terrain type, hazards, recommendation.
##  - Confirm Landing button stores `GameState.selected_landing_tile` and
##    fires `EventBus.landing_confirmed`.
##  - Whole overlay fades in at strategic zoom, out at gameplay zoom
##    (`EventBus.zoom_changed`).
##
## Critically, this is NOT a separate scene — it's a CanvasLayer overlay
## on the same Ground scene. Per spec §5.6 the world is unified.

const DATA_PATH: String = "res://data/orbit_deposits.json"
const FADE_SECONDS: float = 0.35

const DEPOSIT_COLOR := {
	"water_ice":   Color(0.36, 0.81, 0.95),
	"helium3":     Color(0.66, 0.45, 0.85),
	"iron":        Color(0.85, 0.45, 0.40),
	"titanium":    Color(0.55, 0.75, 0.85),
	"silicon":     Color(0.50, 0.85, 0.55),
	"rare_metals": Color(0.95, 0.71, 0.30),
}

@onready var fade_root: Control = $Root
@onready var deposit_root: Control = $Root/Markers
@onready var grid_label_root: Control = $Root/GridLabels
@onready var tooltip: PanelContainer = $Root/TilePanel
@onready var tooltip_id: Label = $Root/TilePanel/Margin/VBox/IDLabel
@onready var tooltip_terrain: Label = $Root/TilePanel/Margin/VBox/TerrainLabel
@onready var tooltip_hazards: Label = $Root/TilePanel/Margin/VBox/HazardsLabel
@onready var tooltip_reco: Label = $Root/TilePanel/Margin/VBox/RecoLabel
@onready var confirm_button: Button = $Root/ConfirmButton

var _data: Dictionary = {}
var _deposits: Array = []
var _suggested_tile: Vector2i = Vector2i(4, 4)
var _selected_tile: Vector2i = Vector2i(-1, -1)
var _tween: Tween
var _landed: bool = false


func _ready() -> void:
	_load_data()
	_build_grid_labels()
	_build_deposit_markers()
	tooltip.visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	EventBus.zoom_changed.connect(_on_zoom_changed)
	# Default visibility: visible until crew has landed; the camera-level
	# signal will fade us out the moment the player zooms past the threshold.
	fade_root.modulate.a = 1.0


func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("[OrbitMap] cannot open %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[OrbitMap] data not a dict")
		return
	_data = parsed
	var s: Array = _data.get("suggested_landing_tile", [4, 4])
	_suggested_tile = Vector2i(int(s[0]), int(s[1]))
	_deposits = _data.get("tiles", [])


func _build_grid_labels() -> void:
	# Static A–J × 1–10 corner labels (top + left edge of the 10×10 grid).
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


func _build_deposit_markers() -> void:
	for tile in _deposits:
		var marker := _make_marker(tile)
		deposit_root.add_child(marker)


func _make_marker(tile: Dictionary) -> Button:
	var col: int = int(tile.get("col", 0))
	var row: int = int(tile.get("row", 0))
	var deposits_dict: Dictionary = tile.get("deposits", {})
	var first_key: String = deposits_dict.keys()[0] if not deposits_dict.is_empty() else "rare_metals"
	var color: Color = DEPOSIT_COLOR.get(first_key, Color.WHITE)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(96, 48)
	btn.position = _grid_to_screen(Vector2i(col, row)) - Vector2(48, 24)
	btn.text = "%s\n%s" % [tile.get("id", "?"), first_key.to_upper()]
	btn.add_theme_color_override("font_color", color)
	btn.tooltip_text = "%s — %s" % [tile.get("id", "?"), tile.get("terrain", "")]
	btn.set_meta("tile_data", tile)
	btn.pressed.connect(_on_marker_pressed.bind(tile, btn))

	# Pulse the suggested landing zone marker.
	if Vector2i(col, row) == _suggested_tile:
		var pulse := create_tween().set_loops()
		pulse.tween_property(btn, "modulate", Color(1, 1, 1, 0.55), 0.8)
		pulse.tween_property(btn, "modulate", Color(1, 1, 1, 1.0), 0.8)
	return btn


## Map a 10×10 grid coord to a screen pixel position. The strategic UI
## hangs over the world; we draw it in viewport-space, not world-space.
func _grid_to_screen(grid: Vector2i) -> Vector2:
	const ORIGIN := Vector2(120, 80)
	const STEP: float = 110.0
	return ORIGIN + Vector2(grid.x * STEP, grid.y * STEP)


func _on_marker_pressed(tile: Dictionary, btn: Button) -> void:
	# Single-select: untoggle other markers.
	for m in deposit_root.get_children():
		if m != btn and m is Button:
			(m as Button).button_pressed = false
	_selected_tile = Vector2i(int(tile.get("col", 0)), int(tile.get("row", 0)))
	tooltip_id.text = "TILE %s" % tile.get("id", "?")
	tooltip_terrain.text = "Terrain: " + tile.get("terrain", "?")
	tooltip_hazards.text = "Hazards: " + tile.get("hazards", "?")
	tooltip_reco.text = "Recommendation: " + tile.get("recommendation", "?")
	tooltip.visible = true
	confirm_button.disabled = _landed


func _on_confirm_pressed() -> void:
	if _landed:
		return
	if _selected_tile == Vector2i(-1, -1):
		_selected_tile = _suggested_tile
	GameState.selected_landing_tile = _selected_tile
	EventBus.landing_confirmed.emit(_selected_tile)
	EventBus.log_message.emit("Landing confirmed at %s" % _tile_label(_selected_tile), "selection")
	_landed = true
	confirm_button.disabled = true
	confirm_button.text = "LANDED"


func _tile_label(t: Vector2i) -> String:
	const COLS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
	if t.x < 0 or t.x >= COLS.size():
		return "?"
	return "%s%d" % [COLS[t.x], t.y + 1]


func _on_zoom_changed(level: String) -> void:
	var target: float = 1.0 if level == "strategic" else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fade_root, "modulate:a", target, FADE_SECONDS)
	# Also disable input on the strategic UI when faded out so cursor clicks
	# fall through to the gameplay world.
	fade_root.mouse_filter = Control.MOUSE_FILTER_PASS if target > 0.0 else Control.MOUSE_FILTER_IGNORE


## Public for tests — surfaces internal state without scraping nodes.
func selected_tile() -> Vector2i:
	return _selected_tile


func suggested_tile() -> Vector2i:
	return _suggested_tile


func deposits_count() -> int:
	return _deposits.size()
