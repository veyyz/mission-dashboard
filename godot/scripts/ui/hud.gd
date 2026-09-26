extends CanvasLayer
## Phase-6 HUD root. Hosts the eight Section-8 panels (each its own scene) as
## Control children. Panels subscribe to EventBus directly — the HUD root is a
## passive container, except that it wraps every panel in `hud_chrome.gd`
## (move / collapse / resize / dock, layout persisted) and owns the F9
## reset-layout key.

const HudChrome := preload("res://scripts/ui/hud_chrome.gd")

## Panel node name → [chrome title, path of the panel's own title Label to
## hide (or ""), so titles don't double up].
const PANEL_CHROME := {
	"HUDPanelDayTime":   ["MISSION CLOCK", ""],
	"HUDPanelResources": ["RESOURCES", ""],
	"HUDPanelTutorial":  ["GUIDE", "Margin/VBox/Header"],
	"HUDPanelLog":       ["CHAT", "Margin/VBox/Header"],
	"HUDPanelCrew":      ["CREW", "Margin/VBox/Header"],
	"HUDPanelMinimap":   ["MINIMAP", "Margin/VBox/Header"],
	"HUDPanelResourceInfo": ["RESOURCE INFO", ""],
}


func _ready() -> void:
	for child in get_children():
		if not (child is Control):
			continue
		var cfg: Array = PANEL_CHROME.get(child.name, [child.name.trim_prefix("HUDPanel").to_upper(), ""])
		HudChrome.install(child, cfg[0], cfg[1])
	print("[HUD] Ready. Panels: %d" % get_child_count())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_hud"):
		HudChrome.reset_all(get_tree())
		EventBus.log_message.emit("HUD layout reset", "selection")
		get_viewport().set_input_as_handled()
