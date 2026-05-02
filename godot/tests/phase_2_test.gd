extends SceneTree
## Phase-2 functional test (regression).
## Verifies: Ground.tscn loads; TileMapLayer painted; at least one CrewMember
## (CharacterBody2D) with a Sprite2D child; a Camera2D somewhere in the scene;
## YSort node has y_sort_enabled = true; pressing "move_up" for ~0.5s
## decreases the controllable crew's position.y.
##
## Updated in Phase 4: crew is now spawned under CrewContainer instead of
## being a single inline node named "CrewMember", so we find by class.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	var packed := load("res://scenes/world/Ground.tscn") as PackedScene
	if packed == null:
		_done(["Ground.tscn missing or failed to load"])
		return

	var ground: Node = packed.instantiate()
	root.add_child(ground)

	# Allow _ready() / call_deferred() to run.
	await process_frame
	await physics_frame
	# Phase-7 landing flow: crew don't spawn until landing_confirmed.
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus != null:
		event_bus.landing_confirmed.emit(Vector2i.ZERO)
	await process_frame
	await physics_frame

	# 1. TileMapLayer painted.
	var tml := ground.find_child("TileMapLayer", true, false)
	if tml == null:
		failures.append("TileMapLayer node missing")
	elif tml.get_used_cells().size() == 0:
		failures.append("TileMapLayer has no painted tiles")

	# 2. At least one CharacterBody2D with a Sprite2D child.
	var crew := _find_first_character_body(ground)
	if crew == null:
		failures.append("No CharacterBody2D crew found in Ground scene")
	else:
		var spr := crew.find_child("Sprite2D", true, false)
		if spr == null:
			failures.append("Sprite2D under CrewMember missing")

	# 3. Camera2D somewhere in the scene.
	if ground.find_child("Camera2D", true, false) == null:
		failures.append("Camera2D missing")

	# 4. Parent Node2D with y_sort_enabled.
	var ysort := ground.find_child("YSort", true, false)
	if ysort == null:
		failures.append("YSort node missing")
	elif not ysort.y_sort_enabled:
		failures.append("YSort.y_sort_enabled is false")

	# 5. Movement: press move_up for ~0.5s, expect position.y to decrease.
	if crew != null:
		var initial_y: float = crew.position.y
		Input.action_press("move_up")
		var elapsed: float = 0.0
		while elapsed < 0.5:
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
		Input.action_release("move_up")
		var final_y: float = crew.position.y
		if final_y >= initial_y - 1.0:
			failures.append(
				"crew position.y did not decrease enough: initial=%.2f final=%.2f" % [initial_y, final_y]
			)

	_done(failures)


func _find_first_character_body(node: Node) -> CharacterBody2D:
	if node is CharacterBody2D:
		return node
	for child in node.get_children():
		var hit := _find_first_character_body(child)
		if hit != null:
			return hit
	return null


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
