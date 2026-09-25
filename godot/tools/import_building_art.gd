extends SceneTree
## One-off art import helper.
##
##   godot --headless --path godot -s tools/import_building_art.gd -- \
##       <source.png> <building_key> [bg_tolerance] [max_width]
##
## Pixellab / upscaler exports arrive as a big canvas with the building sitting
## on an opaque background. Buildings render as sprites over regolith, so the
## background has to become alpha and the canvas has to be cropped to the art —
## `building.gd::_apply_iso_transform` scales by the texture rect, so leftover
## empty margin would shrink the visible building inside its footprint.
##
## Background removal is a flood fill inward from the canvas border, NOT a
## global colour threshold: dark pixels *inside* the building (vents, shadow,
## outlines) must survive, and only background connected to the edge is cleared.

const DEST_ROOT := "res://assets/sprites/buildings/"
const DEFAULT_TOLERANCE: int = 24

## Sources arrive far larger than they ever render: an 8-cell footprint fits a
## 512x256 iso box, and the project samples with nearest filtering
## (`textures/canvas_textures/default_texture_filter=0`), so a multi-thousand-
## pixel texture squeezed down at runtime just shimmers. Downscale once, offline,
## with a good filter. 512 keeps headroom for the 2.85x zoom step and matches the
## existing habitat_xl.png.
const DEFAULT_MAX_WIDTH: int = 512


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: -s tools/import_building_art.gd -- <source.png> <building_key> [tolerance]")
		quit(1)
		return
	var source: String = args[0]
	var key: String = args[1]
	var tolerance: int = int(args[2]) if args.size() > 2 else DEFAULT_TOLERANCE
	var max_width: int = int(args[3]) if args.size() > 3 else DEFAULT_MAX_WIDTH

	var img := Image.new()
	if img.load(source) != OK:
		push_error("Cannot load %s" % source)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	print("Source %s  %dx%d" % [source, w, h])

	var cleared: int = _flood_clear_background(img, tolerance)
	print("Background pixels cleared: %d (%.1f%%)" % [cleared, 100.0 * cleared / float(w * h)])

	var rect: Rect2i = img.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		push_error("Nothing left after background removal — tolerance too high?")
		quit(1)
		return
	var cropped: Image = img.get_region(rect)
	print("Cropped to %s  %dx%d" % [rect.position, rect.size.x, rect.size.y])

	if max_width > 0 and cropped.get_width() > max_width:
		var scaled_h: int = int(round(cropped.get_height() * float(max_width) / float(cropped.get_width())))
		cropped.resize(max_width, scaled_h, Image.INTERPOLATE_LANCZOS)
		print("Downscaled to %dx%d" % [max_width, scaled_h])

	var dest_res: String = "%s%s.png" % [DEST_ROOT, key]
	var dest_abs: String = ProjectSettings.globalize_path(dest_res)
	if cropped.save_png(dest_abs) != OK:
		push_error("Cannot write %s" % dest_abs)
		quit(1)
		return
	print("Wrote %s" % dest_res)
	quit()


## Clear every background pixel reachable from the canvas border. A pixel counts
## as background when each channel is within `tolerance` of the sampled corner
## colour, so a near-black-but-not-pure-black export still keys out cleanly.
func _flood_clear_background(img: Image, tolerance: int) -> int:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bg: Color = img.get_pixel(0, 0)
	print("Corner sample: %s" % bg)

	var visited: PackedByteArray = PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []

	for x in range(w):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in range(h):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))

	var tol: float = float(tolerance) / 255.0
	var cleared: int = 0
	var head: int = 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var idx: int = p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var c: Color = img.get_pixel(p.x, p.y)
		if c.a == 0.0:
			cleared += 1
		elif absf(c.r - bg.r) <= tol and absf(c.g - bg.g) <= tol and absf(c.b - bg.b) <= tol:
			img.set_pixel(p.x, p.y, Color(c.r, c.g, c.b, 0.0))
			cleared += 1
		else:
			continue  # hit the artwork — stop expanding through it
		queue.append(Vector2i(p.x + 1, p.y))
		queue.append(Vector2i(p.x - 1, p.y))
		queue.append(Vector2i(p.x, p.y + 1))
		queue.append(Vector2i(p.x, p.y - 1))
	return cleared
