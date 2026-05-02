extends SceneTree
## Phase-4 functional test.
## Verifies:
##   1. Six CrewMember instances under CrewContainer
##   2. Each has unique crew_name, a Role enum value, role_skill in [70, 95]
##   3. select_crew_3 input action emits EventBus.crew_selected with crew_id == 3
##   4. crew.move_to(Vector2(100, 100)) sets NavigationAgent2D.target_position
##   5. After 2 physics frames, agent.get_next_path_position() != Vector2.ZERO

var event_bus: Node
var _selected_id: int = -1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	if event_bus == null:
		_done(["EventBus autoload missing"])
		return

	var packed := load("res://scenes/world/Ground.tscn") as PackedScene
	if packed == null:
		_done(["Ground.tscn missing"])
		return
	var ground: Node = packed.instantiate()
	root.add_child(ground)

	# Allow _ready, the deferred crew spawn, and NavigationServer to settle.
	await process_frame
	await physics_frame
	# Phase-7 landing flow: crew don't spawn until landing_confirmed.
	event_bus.landing_confirmed.emit(Vector2i.ZERO)
	await process_frame
	await physics_frame

	# 1. Six crew under CrewContainer.
	var container := ground.find_child("CrewContainer", true, false)
	if container == null:
		_done(["CrewContainer missing"])
		return
	var crew_list: Array = []
	for child in container.get_children():
		if child is CharacterBody2D:
			crew_list.append(child)
	if crew_list.size() != 6:
		failures.append("Expected 6 crew under CrewContainer, got %d" % crew_list.size())

	# 2. Unique names, valid roles, role_skill in [70, 95].
	var seen_names: Dictionary = {}
	var seen_ids: Dictionary = {}
	for c in crew_list:
		if seen_names.has(c.crew_name):
			failures.append("Duplicate crew_name: %s" % c.crew_name)
		seen_names[c.crew_name] = true
		if seen_ids.has(c.crew_id):
			failures.append("Duplicate crew_id: %d" % c.crew_id)
		seen_ids[c.crew_id] = true
		if c.role_skill < 70 or c.role_skill > 95:
			failures.append("crew %s skill %d outside [70, 95]" % [c.crew_name, c.role_skill])
		# Role is the CrewMember.Role enum (0..5)
		if c.role < 0 or c.role > 5:
			failures.append("crew %s role enum out of range: %d" % [c.crew_name, c.role])

	# 3. select_crew_3 emits EventBus.crew_selected with id == 3.
	event_bus.crew_selected.connect(_on_crew_selected)
	Input.action_press("select_crew_3")
	await physics_frame
	await physics_frame
	Input.action_release("select_crew_3")
	await physics_frame
	if _selected_id != 3:
		failures.append("EventBus.crew_selected: expected id=3, got %d" % _selected_id)

	# 4 & 5. move_to and NavigationAgent2D.
	if crew_list.size() > 0:
		var crew = crew_list[0]
		crew.global_position = Vector2.ZERO
		crew.move_to(Vector2(100, 100))
		var agent: NavigationAgent2D = crew.find_child("NavigationAgent2D", true, false) as NavigationAgent2D
		if agent == null:
			failures.append("NavigationAgent2D missing on crew")
		else:
			if not agent.target_position.is_equal_approx(Vector2(100, 100)):
				failures.append(
					"agent.target_position != (100,100): got %s" % str(agent.target_position)
				)
			# Phase-4 gotcha: must wait at least one physics frame before
			# reading the agent's first path. With the enlarged 145x145 nav
			# region, the bake takes a few more frames; wait until the
			# agent actually has a path or we time out.
			var next_pos: Vector2 = Vector2.ZERO
			for _attempt in range(20):
				await physics_frame
				next_pos = agent.get_next_path_position()
				if not next_pos.is_equal_approx(Vector2.ZERO):
					break
			if next_pos.is_equal_approx(Vector2.ZERO):
				failures.append("agent.get_next_path_position() returned Vector2.ZERO after 20 physics frames")

	_done(failures)


func _on_crew_selected(crew_id: int) -> void:
	if _selected_id == -1:
		_selected_id = crew_id


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
