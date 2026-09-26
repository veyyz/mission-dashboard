extends SceneTree
## Boots Ground.tscn, confirms a landing, waits for the HUD to settle, then
## saves the rendered viewport to the path given after `--`.
## Needs a real renderer (no --headless):
##   Godot_console.exe --path godot -s tools/screenshot.gd -- out.png [frames]

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 90

	var ground: Node = (load("res://scenes/world/Ground.tscn") as PackedScene).instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame
	root.get_node("EventBus").landing_confirmed.emit(Vector2i.ZERO)
	# Optional third arg "seed": fill stockpiles to varied levels so the HUD
	# shows partial / full / empty states instead of a wall of zeros.
	if args.size() > 2 and args[2] == "seed":
		var rm: Node = root.get_node("ResourceManager")
		var i: int = 0
		for r_name in rm.ordered_keys():
			var frac: float = [0.0, 0.15, 0.4, 0.7, 1.0][i % 5]
			rm.add(r_name, rm.get_max(r_name) * frac - rm.get_current(r_name))
			rm.set_rate(r_name, [0.0, 2.5, -1.2, 0.8, 0.0][(i + 1) % 5])
			i += 1
	# Optional "place:SceneA,SceneB" arg: drop finished building scenes in a
	# row beside the landing site so art swaps can be eyeballed at game scale.
	for a in args:
		if a.begins_with("place:"):
			var ysort: Node = ground.get_node_or_null("YSort")
			var x: float = -420.0
			for scene_name in a.trim_prefix("place:").split(","):
				var packed := load("res://scenes/buildings/%s.tscn" % scene_name) as PackedScene
				if packed == null or ysort == null:
					continue
				var b: Node2D = packed.instantiate()
				b.position = Vector2(x, 120.0)
				ysort.add_child(b)
				x += 300.0
		# Optional "inspect:<resource>" arg: open the resource inspector panel.
		if a.begins_with("inspect:"):
			root.get_node("EventBus").resource_inspect_requested.emit(a.trim_prefix("inspect:"))
	for i in range(frames):
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: int = img.save_png(out_path)
	print("[screenshot] %s -> %s (%dx%d)" % [error_string(err), out_path, img.get_width(), img.get_height()])
	quit()
