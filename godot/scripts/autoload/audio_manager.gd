extends Node
## Centralized audio playback. Bus volumes, SFX pool, music crossfades.
## Phase 1 is stubs only — wire up real sounds in Phase 10.

var sfx_volume: float = 1.0
var music_volume: float = 0.7
var ambient_volume: float = 0.5


func _ready() -> void:
	print("[AudioManager] Ready.")


func play_sfx(_sfx_name: String) -> void:
	pass  # Phase 10


func play_music(_track_name: String, _fade_seconds: float = 1.0) -> void:
	pass  # Phase 10


func stop_music(_fade_seconds: float = 1.0) -> void:
	pass  # Phase 10


func set_sfx_volume(volume_linear: float) -> void:
	sfx_volume = clampf(volume_linear, 0.0, 1.0)


func set_music_volume(volume_linear: float) -> void:
	music_volume = clampf(volume_linear, 0.0, 1.0)
