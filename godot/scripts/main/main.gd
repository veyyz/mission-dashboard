extends Control
## Boot scene controller. Verifies every autoload came up and prints a
## status report to the output panel. This is replaced by MainMenu.tscn
## in Phase 7 once the orbit map is in.

@onready var status_label: Label = $Center/VBox/Status


func _ready() -> void:
	var divider := "=".repeat(60)
	print(divider)
	print("LUNAR COLONY — Phase 1 boot")
	print(divider)

	var ok: bool = _verify_autoloads()

	if ok:
		status_label.text = "All systems online. Ready for Phase 2."
		status_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	else:
		status_label.text = "Boot failed — see Output panel."
		status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	_print_smoke_test()
	print(divider)
	print("Press Esc to quit. Hand the project to your agent and say:")
	print("    \"Begin Phase 2.\"")
	print(divider)


func _verify_autoloads() -> bool:
	var autoloads := {
		"GameState":       GameState,
		"EventBus":        EventBus,
		"ResourceManager": ResourceManager,
		"TimeManager":     TimeManager,
		"SaveSystem":      SaveSystem,
		"AudioManager":    AudioManager,
	}

	var ok := true
	for n in autoloads:
		if autoloads[n] == null:
			push_error("Autoload missing: %s" % n)
			ok = false
		else:
			print("  ✓ %s" % n)
	return ok


func _print_smoke_test() -> void:
	print("\nResources at boot:")
	for r_name in ["power", "oxygen", "food", "materials", "science", "crew"]:
		print("  %-10s %d / %d" % [
			r_name,
			ResourceManager.get_current(r_name),
			ResourceManager.get_max(r_name)
		])

	print("\nTime: Day %d, %s, phase=%s" % [
		TimeManager.current_day,
		TimeManager.get_time_string(),
		TimeManager.current_phase
	])

	print("\nInput actions registered: %d" % InputMap.get_actions().size())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
