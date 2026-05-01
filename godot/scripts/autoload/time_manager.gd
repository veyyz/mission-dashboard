extends Node
## Day/night cycle and game time.
## 1 in-game day = REAL_SECONDS_PER_DAY_AT_1X seconds at 1x speed.
## Phase 1 just ticks time; visual day/night tint comes in Phase 3.

const MINUTES_PER_DAY: int = 24 * 60               # 1440
const REAL_SECONDS_PER_DAY_AT_1X: float = 16.0 * 60.0  # 16 real min = 1 game day

var current_minute_of_day: float = 6.0 * 60.0      # start at 06:00
var current_day: int = 0
var time_scale: float = 1.0                        # 0=paused, 1, 2, 4
var current_phase: String = "day"


func _ready() -> void:
	print("[TimeManager] Ready. Starting Day 0, 06:00.")


func _process(delta: float) -> void:
	if time_scale <= 0.0 or GameState.is_paused:
		return
	var minutes_per_real_second: float = MINUTES_PER_DAY / REAL_SECONDS_PER_DAY_AT_1X
	current_minute_of_day += delta * minutes_per_real_second * time_scale

	if current_minute_of_day >= MINUTES_PER_DAY:
		current_minute_of_day -= MINUTES_PER_DAY
		current_day += 1
		EventBus.mission_day_advanced.emit(current_day)

	EventBus.time_tick.emit(int(current_minute_of_day))
	_check_phase()


func _check_phase() -> void:
	var hour: float = current_minute_of_day / 60.0
	var new_phase: String
	if hour >= 6.0 and hour < 18.0:
		new_phase = "day"
	elif hour >= 18.0 and hour < 22.0:
		new_phase = "twilight"
	else:
		new_phase = "night"

	if new_phase != current_phase:
		current_phase = new_phase
		EventBus.phase_changed.emit(new_phase)


func get_time_string() -> String:
	var hour: int = int(current_minute_of_day / 60.0)
	var minute: int = int(current_minute_of_day) % 60
	return "%02d:%02d" % [hour, minute]


func set_time_scale(scale: float) -> void:
	time_scale = maxf(0.0, scale)
