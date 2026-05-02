extends SceneTree
## Phase-8 functional test.
## Verifies:
##   1. Resource nodes spawn under Ground (6 placeholder nodes per Phase-8 ground.gd)
##   2. Scan reveals nodes within radius (Geologist 2× radius)
##   3. Probe deploys when Scientist invokes it; non-Scientist gets blocked
##   4. Sample collection: G action increments `samples` and emits sample_collected
##   5. FogOfWar CanvasLayer exists; reveals cells around vision sources
##   6. Recipe processor converts samples → science via the analyze_sample
##      recipe when a research_lab building exists

var event_bus: Node
var resource_manager: Node
var time_manager: Node
var recipe_processor: Node
var _sample_event: Dictionary = {}
var _probe_event: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	resource_manager = root.get_node_or_null("ResourceManager")
	time_manager = root.get_node_or_null("TimeManager")
	recipe_processor = root.get_node_or_null("RecipeProcessor")
	if event_bus == null or resource_manager == null or recipe_processor == null:
		_done([
			"Autoload(s) missing: EventBus=%s ResourceManager=%s RecipeProcessor=%s" % [
				event_bus, resource_manager, recipe_processor,
			],
		])
		return

	if time_manager != null:
		time_manager.set_time_scale(0.0)

	var ground_packed := load("res://scenes/world/Ground.tscn") as PackedScene
	var ground: Node = ground_packed.instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame
	await physics_frame

	# 1. Resource nodes spawned.
	var nodes: Array = get_nodes_in_group("resource_node")
	if nodes.size() < 6:
		failures.append("Expected ≥6 resource nodes, got %d" % nodes.size())

	# 2. Scan reveals nodes near a Geologist (Rin = crew_id 4).
	var crew_list: Array = get_nodes_in_group("crew")
	var geologist: Node2D = null
	for c in crew_list:
		if c.role == 3:  # Role.GEOLOGIST
			geologist = c
			break
	if geologist == null:
		failures.append("Geologist not found in crew group")
	else:
		# Move Rin to a position with a node nearby and run scan.
		geologist.global_position = Vector2(150, 60)  # near iron node at (180, 60)
		geologist.set_selected(true)
		await physics_frame
		var manager := ground.find_child("CrewContainer", true, false)
		if manager == null or not manager.has_method("_do_scan"):
			failures.append("CrewSelectionManager scan method missing")
		else:
			manager._do_scan(geologist)
			await process_frame
			var revealed: int = 0
			for n in nodes:
				if n.discovered:
					revealed += 1
			if revealed == 0:
				failures.append("Scan revealed no nodes (expected ≥1)")

	# 3. Probe deploy: scientist OK, geologist blocked.
	var scientist: Node2D = null
	for c in crew_list:
		if c.role == 1:  # Role.SCIENTIST
			scientist = c
			break
	if scientist != null:
		var manager := ground.find_child("CrewContainer", true, false)
		var before_probes: int = get_nodes_in_group("probe").size()
		manager._do_deploy_probe(geologist)  # should be blocked (not scientist)
		await process_frame
		if get_nodes_in_group("probe").size() != before_probes:
			failures.append("Probe deploy by non-scientist was not blocked")
		manager._do_deploy_probe(scientist)
		await process_frame
		await process_frame
		if get_nodes_in_group("probe").size() <= before_probes:
			failures.append("Probe deploy by scientist did not spawn a probe")

	# 4. Sample collection — Geologist near a revealed iron node, G triggers.
	event_bus.sample_collected.connect(_on_sample_collected)
	var samples_before: float = resource_manager.get_current("samples")
	if geologist != null:
		var manager := ground.find_child("CrewContainer", true, false)
		manager._do_collect_sample(geologist)
		await process_frame
		var samples_after: float = resource_manager.get_current("samples")
		if samples_after - samples_before < 1.0:
			failures.append(
				"Sample collection did not increment samples: before=%.1f after=%.1f" % [
					samples_before, samples_after,
				]
			)
		if _sample_event.is_empty():
			failures.append("EventBus.sample_collected never fired")

	# 5. FogOfWar exists + revealed cells > 0.
	var fog := ground.find_child("FogOfWar", true, false)
	if fog == null:
		failures.append("FogOfWar layer missing")
	elif not (fog is CanvasLayer):
		failures.append("FogOfWar root is not a CanvasLayer")
	else:
		# Tick physics so fog _physics_process runs and gathers vision sources.
		await physics_frame
		await physics_frame
		if fog.revealed_count() == 0:
			failures.append("FogOfWar revealed_count() == 0 (vision sources not registered)")

	# 6. Recipe processor: spawn a Research Lab, ensure samples available, run cycle.
	var lab_scene: PackedScene = load("res://scenes/buildings/ResearchLab.tscn") as PackedScene
	if lab_scene == null:
		failures.append("ResearchLab.tscn missing")
	else:
		var lab: Node2D = lab_scene.instantiate()
		ground.add_child(lab)
		# Provide samples if collection didn't already.
		if resource_manager.get_current("samples") < 1.0:
			resource_manager.add("samples", 5.0)
		var samples_before2: float = resource_manager.get_current("samples")
		var science_before: float = resource_manager.get_current("science")
		var ran: bool = recipe_processor.try_run("analyze_sample")
		if not ran:
			failures.append("RecipeProcessor.try_run('analyze_sample') returned false")
		else:
			var samples_after2: float = resource_manager.get_current("samples")
			var science_after: float = resource_manager.get_current("science")
			if samples_before2 - samples_after2 < 1.0:
				failures.append("Recipe did not consume samples (before=%.1f after=%.1f)" % [samples_before2, samples_after2])
			if science_after - science_before < 1.0:
				failures.append("Recipe did not produce science (before=%.1f after=%.1f)" % [science_before, science_after])

	if time_manager != null:
		time_manager.set_time_scale(1.0)

	_done(failures)


func _on_sample_collected(sample_type: String, grid_pos: Vector2i) -> void:
	_sample_event = {"type": sample_type, "grid": grid_pos}


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
