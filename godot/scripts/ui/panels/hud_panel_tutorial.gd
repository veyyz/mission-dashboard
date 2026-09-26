extends PanelContainer
## Top-right tutorial guide. F1 toggles. Visible by default on first run;
## once dismissed, stays dismissed for the session.

const TIPS: Array[String] = [
	"WASD / arrows move the selected crew · click the ground to send them",
	"Tab / Shift+Tab cycle the selected crew",
	"R  Scan for deposits    F  Deploy probe    G  Collect sample",
	"Build menu (right) places sites; any adjacent crew builds",
	"+ / − (top-right) zoom in 10 steps    Space pause    F1–F3 speed",
	"Drag a panel header to move; ▾ collapses; right-click docks; F9 resets layout",
	"Build order: Solar ×2 → Drill (ilmenite) → Electrolyzer → Reduction Plant → Solar ×3 → MatterForge → MRE Smelter → Excavator → Kiln. Keep power positive — 0 power = mission lost",
	"F1 hides this guide",
]


func _ready() -> void:
	var box: VBoxContainer = $Margin/VBox/Tips
	for tip in TIPS:
		var lbl := Label.new()
		lbl.text = "•  " + tip
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color(0.91, 0.93, 0.95))
		lbl.add_theme_font_size_override("font_size", 12)
		box.add_child(lbl)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		if key.keycode == KEY_F1 or key.physical_keycode == KEY_F1:
			visible = not visible
			get_viewport().set_input_as_handled()
