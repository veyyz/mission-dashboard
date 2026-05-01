extends CanvasModulate
## Tints the world Canvas based on the current TimeManager phase.
## Subscribes to EventBus.phase_changed so it stays decoupled from the
## TimeManager directly. Tween animates the transition over half a second.

const PHASE_COLOR := {
	"day":      Color(1.00, 0.98, 0.92),
	"twilight": Color(1.00, 0.70, 0.55),
	"night":    Color(0.50, 0.60, 0.80),
}

const FADE_SECONDS: float = 0.5

var _tween: Tween


func _ready() -> void:
	color = PHASE_COLOR.get(TimeManager.current_phase, Color.WHITE)
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: String) -> void:
	var target: Color = PHASE_COLOR.get(phase, Color.WHITE)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color", target, FADE_SECONDS)
