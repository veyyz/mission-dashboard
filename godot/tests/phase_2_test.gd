extends SceneTree
## Phase-2 functional test.
## Verifies: Ground.tscn loads; TileMapLayer painted; CrewMember +
## Sprite2D + Camera2D present; YSort.y_sort_enabled = true; pressing
## "move_up" for 0.5s decreases crew.position.y.
##
## Run: godot --headless --script tests/phase_2_test.gd

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

	# Let _ready() run for both Ground and child nodes.
	await process_frame
	await physics_frame

	# 1. TileMapLayer with at least one painted tile.
	var tml := ground.find_child("TileMapLayer", true, false)
	if tml == null:
		failures.append("TileMapLayer node missing")
	elif tml.get_used_cells().size() == 0:
		failures.append("TileMapLayer has no painted tiles")

	# 2. CharacterBody2D named CrewMember with a Sprite2D child.
	var crew_node := ground.find_child("CrewMember", true, false)
	if crew_node == null or not (crew_node is CharacterBody2D):
		failures.append("CrewMember (CharacterBody2D) missing")
	else:
		var spr := crew_node.find_child("Sprite2D", true, false)
		if spr == null:
			failures.append("Sprite2D under CrewMember missing")

	# 3. Camera2D somewhere in the scene (script attaches it to crew).
	if ground.find_child("Camera2D", true, false) == null:
		failures.append("Camera2D missing")

	# 4. Parent Node2D with y_sort_enabled = true.
	var ysort := ground.find_child("YSort", true, false)
	if ysort == null:
		failures.append("YSort node missing")
	elif not ysort.y_sort_enabled:
		failures.append("YSort.y_sort_enabled is false")

	# 5. Simulate move_up for ~0.5s, expect crew.position.y to decrease.
	if crew_node != null and crew_node is CharacterBody2D:
		var crew: CharacterBody2D = crew_node
		var initial_y: float = crew.position.y
		Input.action_press("move_up")

		# Run physics for ~0.5s. Headless can be uncapped fps; loop on the
		# physics_frame signal until enough simulated time has elapsed.
		var elapsed: float = 0.0
		while elapsed < 0.5:
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second

		Input.action_release("move_up")

		var final_y: float = crew.position.y
		if final_y >= initial_y - 1.0:
			failures.append(
				"position.y did not decrease enough: initial=%.2f final=%.2f" % [initial_y, final_y]
			)

	_done(failures)


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
