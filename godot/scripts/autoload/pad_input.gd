extends Node
## Generic Bluetooth gamepad driver: one 360-degree analog stick + three buttons.
##
## The pad has nowhere near enough buttons to mirror the 18 keyboard actions,
## so it runs a two-mode scheme toggled by the stick click:
##
##   CREW mode   — stick walks the selected crew (analog). Confirm fires the
##                 crew role action; Cancel cycles focus through crew 1..6 and
##                 then a free-explore slot where the stick flies the camera
##                 instead.
##   CURSOR mode — stick drives an on-screen cursor that warps the real mouse,
##                 so every existing pointer consumer (ghost placement,
##                 demolish, landing confirm, build menu, zoom buttons,
##                 sliders, panel drag) works untouched. Confirm is left
##                 click, Cancel is right click.
##
## Button indices are raw integers from `data/gamepad.json` — this class of pad
## ships without an SDL mapping, so JOY_BUTTON_A/B/X/Y do not describe it.

enum PadMode { CREW, CURSOR }

const CURSOR_SIZE: int = 22
const HINT_MARGIN: float = 14.0

var mode: PadMode = PadMode.CREW

var _pos: Vector2 = Vector2.ZERO
var _held_seconds: float = 0.0
var _prev_pressed: Dictionary = {}
var _last_confirm_msec: int = 0
var _using_pad: bool = false
var _pad_present: bool = false
var _mouse_hidden: bool = false

var _layer: CanvasLayer
var _cursor: Sprite2D
var _hint: Label


func _ready() -> void:
	# Cursor and hints must keep working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_pos = _viewport_size() * 0.5
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_pad_present = not Input.get_connected_joypads().is_empty()
	if _pad_present:
		_using_pad = true
		EventBus.pad_connected.emit(true, Input.get_joy_name(int(_setting("device"))))
	_refresh_overlay()
	print("[PadInput] Ready. Pad connected: %s" % str(_pad_present))
	if bool(_setting("debug_probe")):
		_probe_devices()


func _setting(key: String) -> Variant:
	return GameState.pad_setting(key)


# --- Mode -------------------------------------------------------------------

func set_mode(new_mode: PadMode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	if mode == PadMode.CURSOR:
		# Start the cursor under the last known mouse position so it does not
		# jump across the screen when the player flips modes.
		var vp: Viewport = get_viewport()
		if vp != null:
			_pos = vp.get_mouse_position()
	_held_seconds = 0.0
	_refresh_overlay()
	EventBus.pad_mode_changed.emit(mode)
	EventBus.log_message.emit(
		"Gamepad: %s mode" % ("CURSOR" if mode == PadMode.CURSOR else "CREW"), "input"
	)


func toggle_mode() -> void:
	set_mode(PadMode.CREW if mode == PadMode.CURSOR else PadMode.CURSOR)


## In CURSOR mode the stick drives the pointer, so the shared move_* actions
## must not also walk the selected crew. Read by crew_member.gd.
func suppresses_crew_movement() -> bool:
	return mode == PadMode.CURSOR


# --- Frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	_poll_buttons()
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		_held_seconds = 0.0
	else:
		_held_seconds += delta
	match mode:
		PadMode.CURSOR:
			drive_cursor(dir, delta)
		PadMode.CREW:
			# Crew walking is handled by crew_member.gd off the same actions.
			# Only free explore (nothing selected) needs us to fly the camera.
			if dir != Vector2.ZERO and not _has_selection():
				pan_camera(dir, delta)


## Rising/falling edge tracking done by hand. `is_action_just_pressed` is
## unreliable under synthetic input in headless runs — same reasoning as
## crew_selection_manager.gd.
func _poll_buttons() -> void:
	for action in ["pad_confirm", "pad_cancel", "pad_mode"]:
		var pressed: bool = Input.is_action_pressed(action)
		var prev: bool = _prev_pressed.get(action, false)
		_prev_pressed[action] = pressed
		if pressed == prev:
			continue
		_using_pad = true
		match action:
			"pad_mode":
				if pressed:
					toggle_mode()
			"pad_confirm":
				on_confirm(pressed)
			"pad_cancel":
				on_cancel(pressed)


func on_confirm(pressed: bool) -> void:
	if mode == PadMode.CURSOR:
		var double: bool = false
		if pressed:
			var now: int = Time.get_ticks_msec()
			var gap: float = float(now - _last_confirm_msec) / 1000.0
			double = gap <= float(_setting("double_tap_seconds"))
			_last_confirm_msec = now
		# Mirror the physical button so press-and-hold still drags panels.
		send_pointer(MOUSE_BUTTON_LEFT, pressed, double)
		return
	if not pressed:
		return
	var manager: Node = crew_manager()
	if manager != null and manager.invoke_context_action():
		return
	# Free explore (or nothing selected): snap the camera back to the crew.
	var cam: Node = camera()
	if cam != null:
		cam.recenter_on_last_crew()


func on_cancel(pressed: bool) -> void:
	if mode == PadMode.CURSOR:
		send_pointer(MOUSE_BUTTON_RIGHT, pressed)
		return
	if not pressed:
		return
	var manager: Node = crew_manager()
	if manager != null:
		manager.cycle_focus(1)
	_refresh_overlay()


# --- Cursor -----------------------------------------------------------------

## Public so the test suite can step the cursor without a real stick.
func drive_cursor(dir: Vector2, delta: float) -> void:
	if dir != Vector2.ZERO:
		var ramp: float = maxf(0.01, float(_setting("cursor_ramp_seconds")))
		var t: float = clampf(_held_seconds / ramp, 0.0, 1.0)
		var speed: float = lerpf(
			float(_setting("cursor_speed_min")), float(_setting("cursor_speed_max")), t
		)
		_pos += dir * speed * delta
	var size: Vector2 = _viewport_size()
	_pos = Vector2(clampf(_pos.x, 0.0, size.x), clampf(_pos.y, 0.0, size.y))
	if _cursor != null:
		_cursor.position = _pos
	if dir != Vector2.ZERO:
		_warp(_pos)


## `Input.warp_mouse` takes window coordinates, while everything downstream
## works in viewport coordinates — with `stretch/mode=viewport` those diverge
## as soon as the window is resized, so convert through the screen transform.
func _warp(viewport_pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	Input.warp_mouse(vp.get_screen_transform() * viewport_pos)


## Feed a synthetic mouse event through the full input pipeline. A motion
## event goes first: `warp_mouse` only updates the internal mouse position
## once the resulting OS motion event lands, which may be after this click.
func send_pointer(button: int, pressed: bool, double: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _pos
	motion.global_position = _pos
	Input.parse_input_event(motion)

	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = pressed
	click.double_click = double
	click.position = _pos
	click.global_position = _pos
	Input.parse_input_event(click)


func cursor_position() -> Vector2:
	return _pos


func set_cursor_position(viewport_pos: Vector2) -> void:
	_pos = viewport_pos
	if _cursor != null:
		_cursor.position = _pos


# --- Free explore -----------------------------------------------------------

func pan_camera(dir: Vector2, delta: float) -> void:
	var cam: Node = camera()
	if cam == null:
		return
	cam.pan_by(dir * float(_setting("camera_pan_speed")) * delta)


func _has_selection() -> bool:
	var manager: Node = crew_manager()
	return manager != null and manager.has_selection()


func crew_manager() -> Node:
	return get_tree().get_first_node_in_group("crew_manager")


func camera() -> Node:
	return get_tree().get_first_node_in_group("world_camera")


# --- Overlay ----------------------------------------------------------------

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "PadOverlay"
	_layer.layer = 100  # above HUD (1), FogOfWar (2) and every other UI layer
	add_child(_layer)

	_cursor = Sprite2D.new()
	_cursor.name = "PadCursor"
	_cursor.texture = _build_cursor_texture()
	_cursor.centered = false
	_cursor.visible = false
	_layer.add_child(_cursor)

	_hint = Label.new()
	_hint.name = "PadHint"
	_hint.visible = false
	_hint.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_top = -34.0
	_hint.offset_bottom = -HINT_MARGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_hint)


func _refresh_overlay() -> void:
	if _cursor != null:
		_cursor.visible = _pad_present and mode == PadMode.CURSOR
		_cursor.position = _pos
	if _hint != null:
		_hint.visible = _pad_present
		_hint.text = _hint_text()
	_apply_mouse_visibility()


func _apply_mouse_visibility() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want_hidden: bool = _pad_present and _using_pad and mode == PadMode.CURSOR
	if want_hidden == _mouse_hidden:
		return
	_mouse_hidden = want_hidden
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE


func _hint_text() -> String:
	var confirm: int = int(_setting("button_confirm"))
	var cancel: int = int(_setting("button_cancel"))
	var mode_btn: int = int(_setting("button_mode"))
	if mode == PadMode.CURSOR:
		return "PAD - CURSOR    [%d] click (double-tap = move order)    [%d] cancel    [%d / stick-click] crew mode" % [confirm, cancel, mode_btn]
	if not _has_selection():
		return "PAD - FREE EXPLORE    stick = fly camera    [%d] back to crew    [%d] next    [%d / stick-click] cursor mode" % [confirm, cancel, mode_btn]
	return "PAD - CREW    stick = walk    [%d] action    [%d] next crew    [%d / stick-click] cursor mode" % [confirm, cancel, mode_btn]


## Arrow pointer drawn at runtime, matching the generated-placeholder approach
## used elsewhere (build_placement_controller.gd). No art dependency.
func _build_cursor_texture() -> Texture2D:
	var s: int = CURSOR_SIZE
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body_limit: float = float(s) * 0.72
	for y in range(s):
		for x in range(s):
			var fx: float = float(x)
			var fy: float = float(y)
			# Classic arrow: vertical left edge, diagonal right edge, short tail.
			var inside: bool = fx <= fy * 0.62 and fy <= body_limit
			var tail: bool = fy > body_limit and fx >= fy * 0.30 and fx <= fy * 0.30 + 4.0
			if not (inside or tail):
				continue
			var edge: bool = fx <= 1.0 \
				or absf(fx - fy * 0.62) <= 1.4 \
				or (inside and absf(fy - body_limit) <= 1.0)
			img.set_pixel(x, y, Color(0.05, 0.07, 0.1) if edge else Color(0.95, 0.98, 1.0))
	return ImageTexture.create_from_image(img)


func _viewport_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2(1920, 1080)
	return vp.get_visible_rect().size


# --- Device tracking --------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not _using_pad:
			_using_pad = true
			_refresh_overlay()
		return
	if event is InputEventMouseMotion:
		# Ignore the motion our own warp/synthesis produced.
		var mm: InputEventMouseMotion = event
		if mm.position.distance_to(_pos) < 2.0:
			return
		if _using_pad:
			_using_pad = false
			_refresh_overlay()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_pad_present = not Input.get_connected_joypads().is_empty()
	var device_name: String = Input.get_joy_name(device) if connected else ""
	if connected:
		_using_pad = true
	EventBus.pad_connected.emit(connected, device_name)
	EventBus.log_message.emit(
		"Gamepad %s%s" % ["connected: " if connected else "disconnected", device_name], "input"
	)
	_refresh_overlay()


## One-shot diagnostic for an unmapped pad: prints the device identity, then
## every deflected axis / held button index. Enable via data/gamepad.json.
func _probe_devices() -> void:
	for device in Input.get_connected_joypads():
		print("[PadInput] Joypad %d: name=%s guid=%s known_mapping=%s" % [
			device, Input.get_joy_name(device), Input.get_joy_guid(device),
			str(Input.is_joy_known(device)),
		])
	_probe_loop()


func _probe_loop() -> void:
	while bool(_setting("debug_probe")) and is_inside_tree():
		await get_tree().create_timer(0.1).timeout
		for device in Input.get_connected_joypads():
			for axis in range(JOY_AXIS_MAX):
				var v: float = Input.get_joy_axis(device, axis)
				if absf(v) > 0.35:
					print("[PadInput] probe: device=%d axis=%d value=%.2f" % [device, axis, v])
			for button in range(JOY_BUTTON_MAX):
				if Input.is_joy_button_pressed(device, button):
					print("[PadInput] probe: device=%d button=%d DOWN" % [device, button])
