extends PanelContainer
## Bottom-right minimap + system status. Phase 6 ships a placeholder
## ColorRect; the real minimap (with crew/buildings dots and fog-of-war
## blackout) lands in Phase 8 alongside the fog shader.

@onready var power_bar: ProgressBar = $Margin/VBox/PowerBar
@onready var oxygen_bar: ProgressBar = $Margin/VBox/OxygenBar


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	_refresh("power")
	_refresh("oxygen")


func _on_resource_changed(r_name: String, _current: float, _maximum: float, _rate: float) -> void:
	if r_name == "power" or r_name == "oxygen":
		_refresh(r_name)


func _refresh(r_name: String) -> void:
	var bar: ProgressBar = power_bar if r_name == "power" else oxygen_bar
	bar.max_value = ResourceManager.get_max(r_name)
	bar.value = ResourceManager.get_current(r_name)
