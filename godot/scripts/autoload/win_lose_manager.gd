extends Node
## Phase-9 win/lose tracker. Subscribes to `EventBus.resource_changed` and
## `EventBus.mission_day_advanced`.
##
## Win condition (per spec §4): three consecutive in-game days where the
## net rate on power, oxygen, and food are all > 0. Streak resets if any
## go non-positive at the daily checkpoint.
##
## Lose condition: any of those three resources hits 0.
##
## Once either fires, fires `EventBus.victory` or `EventBus.defeat(reason)`
## and locks itself out (no double-fires).

const CRITICAL: Array[String] = ["power", "oxygen", "food"]
const WIN_STREAK_DAYS: int = 3

var sustainable_streak: int = 0
var _ended: bool = false


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.mission_day_advanced.connect(_on_day_advanced)


func reset() -> void:
	sustainable_streak = 0
	_ended = false


func _on_resource_changed(r_name: String, current: float, _maximum: float, _rate: float) -> void:
	if _ended:
		return
	if not (r_name in CRITICAL):
		return
	if current <= 0.0:
		_ended = true
		EventBus.defeat.emit("%s depleted" % r_name)


func _on_day_advanced(_day: int) -> void:
	if _ended:
		return
	# At each daily checkpoint, evaluate net rate on the three critical resources.
	var all_positive: bool = true
	for r_name in CRITICAL:
		if ResourceManager.get_rate(r_name) <= 0.0:
			all_positive = false
			break
	if all_positive:
		sustainable_streak += 1
	else:
		sustainable_streak = 0
	if sustainable_streak >= WIN_STREAK_DAYS:
		_ended = true
		EventBus.victory.emit()


func is_ended() -> bool:
	return _ended
