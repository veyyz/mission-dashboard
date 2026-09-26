extends Node
## Window chrome for HUD panels. Install into any PanelContainer that lives
## directly under a CanvasLayer and it becomes:
##   - movable    — drag the header bar; edges snap to the screen margin and
##                  to other chrome'd panels while dragging (magnetic)
##   - collapsible — ▾ button (or double-click the header) folds the panel
##                  down to its header
##   - resizable  — drag the ⋱ grip in the bottom-right corner
##   - dockable   — right-click the header for a dock menu: eight edge /
##                  corner slots, Float (undock), Reset this panel
## Layout (position, size, collapsed, dock) persists per panel name in
## `user://hud_layout.json`. F9 (see hud.gd) resets every panel.
##
## Usage — from the owning script's _ready, or hud.gd for the HUD layer:
##     preload("res://scripts/ui/hud_chrome.gd").install(panel, "TITLE", "Margin/VBox/Header")
## Install is deferred one frame so the panel's own @onready lookups have
## already resolved before its children are re-parented under the chrome.
## No class_name on purpose: headless class discovery is order-sensitive.

const LAYOUT_PATH: String = "user://hud_layout.json"
const GROUP: String = "hud_windows"
const SCREEN_MARGIN: float = 16.0
const SNAP_DISTANCE: float = 14.0
const HEADER_HEIGHT: float = 20.0
const GRIP_SIZE: float = 16.0

const COL_TITLE: Color = Color(0.36, 0.71, 0.84)
const COL_MUTED: Color = Color(0.55, 0.61, 0.70)
const COL_TEXT: Color = Color(0.91, 0.93, 0.95)

enum Dock { FLOAT, TOP_LEFT, TOP, TOP_RIGHT, LEFT, RIGHT, BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT }
const DOCK_LABELS: Array = [
	"Float", "Dock Top-Left", "Dock Top", "Dock Top-Right",
	"Dock Left", "Dock Right", "Dock Bottom-Left", "Dock Bottom", "Dock Bottom-Right",
]
const MENU_RESET_ID: int = 100

var title: String = ""
## Optional path (relative to the panel) of a title Label the panel already
## draws. Hidden once the chrome header takes over, so titles don't double up.
var inner_header_path: NodePath = NodePath()
## Ships folded to its header (debug tools). Reset returns to this state.
var default_collapsed: bool = false

var _panel: Control = null
var _frame: VBoxContainer = null
var _header: HBoxContainer = null
var _content: VBoxContainer = null
var _collapse_btn: Button = null
var _grip: Control = null
var _menu: PopupMenu = null

var _default_rect: Rect2 = Rect2()
var _expanded_size: Vector2 = Vector2.ZERO
var _collapsed: bool = false
var _dock: int = Dock.FLOAT

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _resizing: bool = false
var _resize_origin: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _save_pending: bool = false

## In-memory copy of the layout file, shared by every chrome in the tree.
static var _layout_cache: Dictionary = {}
static var _layout_loaded: bool = false


static func install(panel: Control, panel_title: String, inner_header: String = "", start_collapsed: bool = false) -> Node:
	var chrome: Node = load("res://scripts/ui/hud_chrome.gd").new()
	chrome.name = "HudChrome"
	chrome.title = panel_title
	chrome.default_collapsed = start_collapsed
	if inner_header != "":
		chrome.inner_header_path = NodePath(inner_header)
	panel.add_child(chrome)
	return chrome


## Wipes the saved layout and returns every chrome'd panel to its scene rect.
static func reset_all(tree: SceneTree) -> void:
	_layout_cache = {}
	if FileAccess.file_exists(LAYOUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LAYOUT_PATH))
	tree.call_group(GROUP, "reset_layout")


func _ready() -> void:
	_panel = get_parent() as Control
	if _panel == null:
		push_warning("[HudChrome] parent is not a Control")
		return
	_install.call_deferred()


# --- Install -----------------------------------------------------------------

func _install() -> void:
	add_to_group(GROUP)
	# Freeze the scene's anchored rect into absolute top-left coordinates so
	# position and size can be set directly from here on.
	var rect: Rect2 = _panel.get_global_rect()
	var grow_h: int = _panel.grow_horizontal
	var grow_v: int = _panel.grow_vertical
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.position = rect.position
	_panel.size = rect.size
	_default_rect = rect
	_expanded_size = rect.size

	if inner_header_path != NodePath():
		var inner: Node = _panel.get_node_or_null(inner_header_path)
		if inner is CanvasItem:
			(inner as CanvasItem).visible = false

	# Re-parent the panel's existing children under Frame/Content.
	var existing: Array = []
	for child in _panel.get_children():
		if child != self:
			existing.append(child)
	_frame = VBoxContainer.new()
	_frame.name = "Frame"
	_frame.add_theme_constant_override("separation", 2)
	_panel.add_child(_frame)
	_frame.add_child(_build_header())
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(_content)
	for child in existing:
		_panel.remove_child(child)
		_content.add_child(child)
		if child is Control:
			(child as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL

	_grip = _build_grip()
	_panel.add_child(_grip)
	_panel.item_rect_changed.connect(_place_grip)
	_place_grip()

	_menu = PopupMenu.new()
	for i in range(DOCK_LABELS.size()):
		_menu.add_item(DOCK_LABELS[i], i)
	_menu.add_separator()
	_menu.add_item("Reset this panel", MENU_RESET_ID)
	_menu.id_pressed.connect(_on_menu_id)
	_panel.add_child(_menu)

	_settle.call_deferred(grow_h, grow_v)


## Runs one frame after install, once the header has been laid out. The
## header makes the panel taller than the scene said; keep whichever edge the
## scene anchored fixed (a bottom-anchored hotbar must grow upward, not off
## the screen), then clamp and apply any saved layout on top.
func _settle(grow_h: int, grow_v: int) -> void:
	# Re-assert the scene's size. During the re-parent, autowrapped labels
	# briefly measure at zero width and report a giant minimum height, and a
	# container only ever grows — so take the scene rect back and let the
	# real minimum (measured now, at the right width) win only if larger.
	# Same failure can already have happened in the panel's own _ready (the
	# tutorial panel arrived 7000 px tall). A scene rect larger than the
	# screen is never authored, so treat it as blown and fall back to the
	# real minimum.
	var min_size: Vector2 = _panel.get_combined_minimum_size()
	var cap: Vector2 = _viewport_size() - Vector2(SCREEN_MARGIN, SCREEN_MARGIN) * 2.0
	var authored: Vector2 = _default_rect.size
	if authored.x > cap.x:
		authored.x = min_size.x
	if authored.y > cap.y:
		authored.y = min_size.y
	_panel.size = authored.max(min_size)
	var delta: Vector2 = _panel.size - _default_rect.size
	if grow_h == Control.GROW_DIRECTION_BEGIN:
		_panel.position.x -= delta.x
	elif grow_h == Control.GROW_DIRECTION_BOTH:
		_panel.position.x -= delta.x * 0.5
	if grow_v == Control.GROW_DIRECTION_BEGIN:
		_panel.position.y -= delta.y
	elif grow_v == Control.GROW_DIRECTION_BOTH:
		_panel.position.y -= delta.y * 0.5
	_panel.position = _clamp_to_screen(_panel.position, _panel.size)
	_default_rect = Rect2(_panel.position, _panel.size)
	_expanded_size = _panel.size
	if default_collapsed:
		set_collapsed(true, false)
	_place_grip()
	_load_layout()


func _build_header() -> Control:
	_header = HBoxContainer.new()
	_header.name = "Header"
	_header.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_header.add_theme_constant_override("separation", 4)
	_header.gui_input.connect(_on_header_input)

	var grip_glyph := Label.new()
	grip_glyph.text = "⠿"
	grip_glyph.add_theme_font_size_override("font_size", 11)
	grip_glyph.add_theme_color_override("font_color", COL_MUTED)
	grip_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(grip_glyph)

	var label := Label.new()
	label.name = "Title"
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COL_TITLE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(label)

	_collapse_btn = Button.new()
	_collapse_btn.name = "Collapse"
	_collapse_btn.flat = true
	_collapse_btn.text = "▾"
	_collapse_btn.custom_minimum_size = Vector2(22, HEADER_HEIGHT)
	_collapse_btn.add_theme_font_size_override("font_size", 12)
	_collapse_btn.add_theme_color_override("font_color", COL_MUTED)
	_collapse_btn.add_theme_color_override("font_hover_color", COL_TEXT)
	_collapse_btn.tooltip_text = "Collapse / expand  (double-click header)\nRight-click header to dock"
	_collapse_btn.pressed.connect(toggle_collapsed)
	_header.add_child(_collapse_btn)
	return _header


## Resize handle. Marked top_level so the PanelContainer's layout skips it;
## it is positioned by hand in the panel's bottom-right corner.
func _build_grip() -> Control:
	var grip := Control.new()
	grip.name = "ResizeGrip"
	grip.top_level = true
	grip.size = Vector2(GRIP_SIZE, GRIP_SIZE)
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.tooltip_text = "Drag to resize"
	grip.gui_input.connect(_on_grip_input)
	grip.draw.connect(_draw_grip.bind(grip))
	return grip


func _draw_grip(grip: Control) -> void:
	# Three diagonal dots, bottom-right, in the header colour.
	var c: Color = Color(COL_TITLE, 0.75)
	var s: float = GRIP_SIZE
	for i in range(3):
		var off: float = 4.0 * i
		grip.draw_circle(Vector2(s - 3.0 - off, s - 3.0), 1.2, c)
		grip.draw_circle(Vector2(s - 3.0, s - 3.0 - off), 1.2, c)
	grip.draw_circle(Vector2(s - 7.0, s - 7.0), 1.2, c)


func _place_grip() -> void:
	if _grip == null or _panel == null:
		return
	_grip.global_position = _panel.global_position + _panel.size - Vector2(GRIP_SIZE, GRIP_SIZE)
	_grip.visible = not _collapsed
	_grip.queue_redraw()


# --- Header: drag / collapse / dock menu -------------------------------------

func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click:
				_dragging = false
				toggle_collapsed()
				_header.accept_event()
				return
			_dragging = mb.pressed
			if _dragging:
				_drag_offset = _panel.global_position - _panel.get_global_mouse_position()
				_panel.move_to_front()
			else:
				_dock = Dock.FLOAT
				_queue_save()
			_header.accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_menu.position = Vector2i(_panel.get_global_mouse_position())
			_menu.popup()
			_header.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var wanted: Vector2 = _panel.get_global_mouse_position() + _drag_offset
		_panel.global_position = _snap(_clamp_to_screen(wanted, _panel.size))
		_header.accept_event()


func toggle_collapsed() -> void:
	set_collapsed(not _collapsed)


## `persist` is false when applying a default or a loaded layout — booting
## must never write the layout file, or defaults could no longer change.
func set_collapsed(collapsed: bool, persist: bool = true) -> void:
	if collapsed == _collapsed:
		return
	_collapsed = collapsed
	if _collapsed:
		_expanded_size = _panel.size
		_content.visible = false
		_collapse_btn.text = "▸"
		# Containers grow to fit but never shrink on their own: force the
		# height down and let the minimum size (header only) win.
		_panel.size = Vector2(_panel.size.x, 0.0)
	else:
		_content.visible = true
		_collapse_btn.text = "▾"
		_panel.size = _expanded_size
	_place_grip()
	_apply_dock()
	if persist:
		_queue_save()


func _on_menu_id(id: int) -> void:
	if id == MENU_RESET_ID:
		reset_layout()
		return
	_dock = id
	_apply_dock()
	_queue_save()


## Re-seat the panel in its dock slot (no-op when floating). Called after
## collapse / resize so a bottom-docked panel stays on the bottom edge.
func _apply_dock() -> void:
	if _dock == Dock.FLOAT:
		return
	var vp: Vector2 = _viewport_size()
	var s: Vector2 = _panel.size
	var m: float = SCREEN_MARGIN
	var x_left: float = m
	var x_mid: float = (vp.x - s.x) * 0.5
	var x_right: float = vp.x - s.x - m
	var y_top: float = m
	var y_mid: float = (vp.y - s.y) * 0.5
	var y_bottom: float = vp.y - s.y - m
	var pos: Vector2
	match _dock:
		Dock.TOP_LEFT:     pos = Vector2(x_left, y_top)
		Dock.TOP:          pos = Vector2(x_mid, y_top)
		Dock.TOP_RIGHT:    pos = Vector2(x_right, y_top)
		Dock.LEFT:         pos = Vector2(x_left, y_mid)
		Dock.RIGHT:        pos = Vector2(x_right, y_mid)
		Dock.BOTTOM_LEFT:  pos = Vector2(x_left, y_bottom)
		Dock.BOTTOM:       pos = Vector2(x_mid, y_bottom)
		Dock.BOTTOM_RIGHT: pos = Vector2(x_right, y_bottom)
		_:                 return
	_panel.global_position = pos


# --- Resize grip -------------------------------------------------------------

func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_resizing = mb.pressed
			if _resizing:
				_resize_origin = _panel.get_global_mouse_position()
				_resize_start_size = _panel.size
				_panel.move_to_front()
			else:
				_expanded_size = _panel.size
				_apply_dock()
				_queue_save()
			_grip.accept_event()
	elif event is InputEventMouseMotion and _resizing:
		var delta: Vector2 = _panel.get_global_mouse_position() - _resize_origin
		var wanted: Vector2 = _resize_start_size + delta
		var min_size: Vector2 = _panel.get_combined_minimum_size()
		var max_size: Vector2 = _viewport_size() - _panel.global_position - Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
		_panel.size = wanted.clamp(min_size, max_size.max(min_size))
		_grip.accept_event()


# --- Snapping ----------------------------------------------------------------

func _clamp_to_screen(pos: Vector2, size: Vector2) -> Vector2:
	var vp: Vector2 = _viewport_size()
	return Vector2(
		clampf(pos.x, 0.0, maxf(0.0, vp.x - size.x)),
		clampf(pos.y, 0.0, maxf(0.0, vp.y - size.y)),
	)


## Magnetic edges: the panel's left/right/top/bottom snap to the screen
## margin and to any other chrome'd panel's edges within SNAP_DISTANCE.
func _snap(pos: Vector2) -> Vector2:
	var s: Vector2 = _panel.size
	var vp: Vector2 = _viewport_size()
	var xs: Array[float] = [SCREEN_MARGIN, vp.x - SCREEN_MARGIN - s.x]
	var ys: Array[float] = [SCREEN_MARGIN, vp.y - SCREEN_MARGIN - s.y]
	for other in get_tree().get_nodes_in_group(GROUP):
		if other == self or other.get("_panel") == null:
			continue
		var r: Rect2 = other._panel.get_global_rect()
		if not other._panel.visible:
			continue
		# Our left edge to their left/right edge; our right edge to theirs.
		xs.append(r.position.x)
		xs.append(r.end.x)
		xs.append(r.position.x - s.x)
		xs.append(r.end.x - s.x)
		ys.append(r.position.y)
		ys.append(r.end.y)
		ys.append(r.position.y - s.y)
		ys.append(r.end.y - s.y)
	var out: Vector2 = pos
	var best_x: float = SNAP_DISTANCE
	for x in xs:
		if absf(x - pos.x) < best_x:
			best_x = absf(x - pos.x)
			out.x = x
	var best_y: float = SNAP_DISTANCE
	for y in ys:
		if absf(y - pos.y) < best_y:
			best_y = absf(y - pos.y)
			out.y = y
	return out


func _viewport_size() -> Vector2:
	return _panel.get_viewport().get_visible_rect().size


# --- Persistence -------------------------------------------------------------

## "BuildMenu/Panel", "HUD/HUDPanelLog" — prefixed with the owning scene so
## the three CanvasLayer tools whose panel is just named "Panel" don't share
## one entry.
func _layout_key() -> String:
	var owner_node: Node = _panel.owner
	if owner_node != null and owner_node != _panel:
		return "%s/%s" % [owner_node.name, _panel.name]
	return _panel.name


func _queue_save() -> void:
	if _save_pending:
		return
	_save_pending = true
	# Coalesce a burst of drag events into one write.
	get_tree().create_timer(0.5).timeout.connect(_save_layout)


func _save_layout() -> void:
	_save_pending = false
	if _panel == null:
		return
	_layout_cache[_layout_key()] = {
		"x": _panel.position.x, "y": _panel.position.y,
		"w": _expanded_size.x if _collapsed else _panel.size.x,
		"h": _expanded_size.y if _collapsed else _panel.size.y,
		"collapsed": _collapsed, "dock": _dock,
	}
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_layout_cache, "\t"))


func _load_layout() -> void:
	if not _layout_loaded:
		_layout_loaded = true
		if FileAccess.file_exists(LAYOUT_PATH):
			var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
			if typeof(parsed) == TYPE_DICTIONARY:
				_layout_cache = parsed
	var entry: Variant = _layout_cache.get(_layout_key(), null)
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var min_size: Vector2 = _panel.get_combined_minimum_size()
	_expanded_size = Vector2(float(entry.get("w", _panel.size.x)), float(entry.get("h", _panel.size.y))).max(min_size)
	_panel.size = _expanded_size
	_panel.position = _clamp_to_screen(
		Vector2(float(entry.get("x", _panel.position.x)), float(entry.get("y", _panel.position.y))), _panel.size
	)
	_dock = int(entry.get("dock", Dock.FLOAT))
	set_collapsed(bool(entry.get("collapsed", false)), false)
	_apply_dock()
	_place_grip()


## Back to the rect the scene shipped with, floating and expanded.
func reset_layout() -> void:
	_dock = Dock.FLOAT
	if _collapsed:
		set_collapsed(false)
	_expanded_size = _default_rect.size
	_panel.position = _default_rect.position
	_panel.size = _default_rect.size
	if default_collapsed:
		set_collapsed(true)
	_place_grip()
	_layout_cache.erase(_layout_key())
	_queue_save()
