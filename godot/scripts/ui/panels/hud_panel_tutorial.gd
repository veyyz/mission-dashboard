extends PanelContainer
## Top-right tutorial guide. F1 toggles. Visible by default on first run;
## once dismissed, stays dismissed for the session.

const TIPS: Array[String] = [
	"WASD or arrow keys move the selected crew",
	"Press 1–6 to select crew (Shift+# to multi-select)",
	"Click on the ground to send selected crew there",
	"Build menu (bottom-left) places construction sites",
	"Any crew member ticks the construction bar when adjacent",
	"+ / − (top-right) zoom the camera in 10 steps",
	"Press F1 to hide this guide",
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
