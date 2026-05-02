extends Node
## Global signal bus. Decouples emitters from listeners.
## Add new signals here as systems come online — never let one system
## hold a direct reference to another for cross-system events.

# --- Game flow ---
signal game_mode_changed(mode: int)
signal pause_toggled(is_paused: bool)
signal mission_day_advanced(day: int)

# --- Resources ---
signal resource_changed(resource_name: String, current: float, maximum: float, rate_per_min: float)
signal resource_depleted(resource_name: String)

# --- Time ---
signal time_tick(in_game_minutes: int)
signal phase_changed(phase: String)  # "day", "twilight", "night"

# --- Crew ---
signal crew_selected(crew_id: int)
signal crew_health_changed(crew_id: int, current: int, maximum: int)
signal crew_oxygen_changed(crew_id: int, current: float, maximum: float)

# --- Buildings ---
signal building_placed(building_type: String, grid_pos: Vector2i)
signal building_completed(building_type: String, grid_pos: Vector2i)
signal building_destroyed(building_type: String, grid_pos: Vector2i)

# --- Exploration ---
signal sample_collected(sample_type: String, grid_pos: Vector2i)
signal probe_deployed(grid_pos: Vector2i)
signal fog_revealed(grid_pos: Vector2i, radius: int)

# --- UI ---
signal hud_panel_toggled(panel_name: String, visible: bool)
signal log_message(message: String, category: String)

# --- Camera / strategic-vs-gameplay zoom (spec §6 unified-world rewrite) ---
signal zoom_changed(level: String)  # "strategic" or "gameplay"
signal landing_confirmed(grid_pos: Vector2i)


func _ready() -> void:
	print("[EventBus] Ready.")
