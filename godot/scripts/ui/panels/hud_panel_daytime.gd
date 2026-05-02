extends PanelContainer
## Top-left mission day + time + phase block. Subscribes to
## EventBus.phase_changed; polls TimeManager every frame for the live clock.

@onready var day_label: Label = $Margin/VBox/DayLabel
@onready var time_label: Label = $Margin/VBox/TimeLabel
@onready var phase_label: Label = $Margin/VBox/PhaseLabel


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(TimeManager.current_phase)


func _process(_delta: float) -> void:
	day_label.text = "MISSION DAY %d" % TimeManager.current_day
	time_label.text = TimeManager.get_time_string()


func _on_phase_changed(phase: String) -> void:
	phase_label.text = phase.to_upper()
