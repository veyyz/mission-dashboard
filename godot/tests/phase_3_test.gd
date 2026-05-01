extends SceneTree
## Phase-3 functional test.
## Verifies:
##   1. ResourceManager.add("power", -50) reduces current power and emits resource_changed
##   2. TimeManager at scale=60 advances at least 1 game minute per real second
##   3. CanvasModulate exists in Ground.tscn and changes color when phase_changed fires
##   4. Fast-forwarding through a full day fires phase_changed for each of day/twilight/night
##
## Run: godot --headless --script tests/phase_3_test.gd
##
## NOTE: `extends SceneTree` doesn't expose autoload globals at compile time, so
## we resolve them via root.get_node() inside _run().

var event_bus: Node
var resource_manager: Node
var time_manager: Node

var _resource_event: Dictionary = {}
var _phases_seen: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	event_bus = root.get_node_or_null("EventBus")
	resource_manager = root.get_node_or_null("ResourceManager")
	time_manager = root.get_node_or_null("TimeManager")
	if event_bus == null or resource_manager == null or time_manager == null:
		_done([
			"Autoload(s) missing — EventBus=%s ResourceManager=%s TimeManager=%s" % [
				event_bus, resource_manager, time_manager,
			],
		])
		return

	# 1. Resource delta + signal
	event_bus.resource_changed.connect(_on_resource_changed)
	var before: float = resource_manager.get_current("power")
	resource_manager.add("power", -50.0)
	await process_frame
	var after: float = resource_manager.get_current("power")
	if not is_equal_approx(before - after, 50.0):
		failures.append("ResourceManager.add did not reduce power by 50: before=%.1f after=%.1f" % [before, after])
	if _resource_event.is_empty() or _resource_event.get("name") != "power":
		failures.append("EventBus.resource_changed not received for power")

	# 2. TimeManager advancement at scale=60 (≥ 1 game minute per real second)
	var t0: float = time_manager.current_minute_of_day
	time_manager.set_time_scale(60.0)
	await create_timer(1.0).timeout
	var t1: float = time_manager.current_minute_of_day
	var advanced: float = t1 - t0
	if advanced < 0.0:
		advanced += float(time_manager.MINUTES_PER_DAY)
	time_manager.set_time_scale(1.0)
	if advanced < 1.0:
		failures.append("TimeManager did not advance >=1 game minute in 1s at scale=60 (got %.2f)" % advanced)

	# 3. Ground.tscn has a CanvasModulate that changes color on phase_changed
	var packed := load("res://scenes/world/Ground.tscn") as PackedScene
	if packed == null:
		_done(failures + ["Ground.tscn missing"])
		return
	var ground: Node = packed.instantiate()
	root.add_child(ground)
	await process_frame
	await physics_frame

	var modulate_node := ground.find_child("DayNightModulate", true, false)
	if modulate_node == null:
		failures.append("DayNightModulate (CanvasModulate) missing from Ground.tscn")
	elif not (modulate_node is CanvasModulate):
		failures.append("DayNightModulate is not a CanvasModulate")
	else:
		var cm: CanvasModulate = modulate_node
		var color_before: Color = cm.color
		event_bus.phase_changed.emit("night")
		# Tween animates over 0.5s; wait long enough.
		await create_timer(0.7).timeout
		var color_after: Color = cm.color
		if color_before.is_equal_approx(color_after):
			failures.append(
				"CanvasModulate color did not change on phase_changed: %s == %s" % [color_before, color_after]
			)
		event_bus.phase_changed.emit("day")
		await create_timer(0.7).timeout

	# 4. Fast-forward through a day; expect phase_changed for day/twilight/night.
	event_bus.phase_changed.connect(_on_phase_changed)
	time_manager.current_minute_of_day = 6.0 * 60.0 + 1.0  # just past 06:00
	time_manager.current_phase = "day"
	_phases_seen.clear()
	time_manager.set_time_scale(10000.0)  # ~0.1 real sec per in-game day
	await create_timer(2.0).timeout
	time_manager.set_time_scale(1.0)

	for required in ["day", "twilight", "night"]:
		if not _phases_seen.has(required):
			failures.append("phase_changed never fired for '%s' (saw: %s)" % [required, _phases_seen])

	_done(failures)


func _on_resource_changed(r_name: String, current: float, maximum: float, rate: float) -> void:
	_resource_event = {"name": r_name, "current": current, "maximum": maximum, "rate": rate}


func _on_phase_changed(phase: String) -> void:
	if not _phases_seen.has(phase):
		_phases_seen.append(phase)


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
