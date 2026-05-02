class_name Probe
extends Node2D
## Phase-8 scientist probe. Static, persistent vision source. Adds itself
## to the "vision_source" group so the FogOfWar layer can sample its
## position each frame to keep the local area revealed permanently.

const VISION_RADIUS: float = 240.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("vision_source")
	add_to_group("probe")
	_apply_screen_upright()
	if sprite.texture == null:
		sprite.texture = _build_placeholder()
	EventBus.probe_deployed.emit(_grid_pos())
	EventBus.log_message.emit("Probe deployed", "selection")


func _grid_pos() -> Vector2i:
	return Vector2i(int(global_position.x / 64.0), int(global_position.y / 32.0))


func vision_radius() -> float:
	return VISION_RADIUS


func _apply_screen_upright() -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world is Node2D:
		rotation = -(world as Node2D).rotation


func _build_placeholder() -> Texture2D:
	var img := Image.create(20, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Antenna mast.
	for y in range(0, 14):
		img.set_pixel(10, y, Color(0.91, 0.93, 0.95))
	# Probe body.
	for y in range(14, 26):
		for x in range(4, 16):
			img.set_pixel(x, y, Color(0.85, 0.88, 0.92))
	# Cyan readout window.
	for y in range(17, 21):
		for x in range(7, 13):
			img.set_pixel(x, y, Color(0.36, 0.71, 0.84))
	return ImageTexture.create_from_image(img)
