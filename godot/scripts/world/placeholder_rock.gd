extends Node2D
## Single-purpose Phase-2 placeholder so Y-sort behavior is visually verifiable:
## walk the crew north of the rock and the rock should draw on top; walk south
## and the crew should draw on top. Removed in Phase 8 (real terrain props).

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = _build_placeholder_texture()


func _build_placeholder_texture() -> Texture2D:
	var img := Image.create(40, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Squat oblong rock silhouette
	for y in range(8, 26):
		for x in range(4, 36):
			var dx: float = float(x - 20) / 18.0
			var dy: float = float(y - 20) / 12.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.40, 0.40, 0.45))
	# Highlight stroke
	for x in range(8, 32):
		img.set_pixel(x, 11, Color(0.55, 0.55, 0.60))
	# Outline
	for y in range(8, 26):
		for x in range(3, 37):
			if img.get_pixel(x, y).a > 0:
				if (x > 0 and img.get_pixel(x - 1, y).a == 0) \
					or (x < 39 and img.get_pixel(x + 1, y).a == 0) \
					or (y > 0 and img.get_pixel(x, y - 1).a == 0) \
					or (y < 27 and img.get_pixel(x, y + 1).a == 0):
					img.set_pixel(x, y, Color(0.07, 0.09, 0.12))
	return ImageTexture.create_from_image(img)
