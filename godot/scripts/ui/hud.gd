extends CanvasLayer
## Phase-6 HUD root. Hosts the eight Section-8 panels (each its own scene) as
## anchored Control children. Panels subscribe to EventBus directly — the
## HUD root is a passive container.

func _ready() -> void:
	print("[HUD] Ready. Panels: %d" % get_child_count())
