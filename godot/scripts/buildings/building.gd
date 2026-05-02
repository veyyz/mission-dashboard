class_name Building
extends StaticBody2D
## Generic finished-building node. Reads its definition from
## `BuildingDatabase` at runtime via `building_key`, applies produce/consume
## rates to `ResourceManager`, and renders a placeholder colored sprite until
## the matching Pixellab isometric tile lands and the art swap-in pass
## connects it.

@export var building_key: String = "solar_array"

var definition: Dictionary = {}
var _produces_applied: Dictionary = {}
var _consumes_applied: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D


## Tilt the building to lean along the iso grid's diagonal
## (atan(TILE_H/TILE_W) for a 2:1 iso = atan(0.5) ≈ 26.57°). With the
## world also rotated 5°, the on-screen tilt is ~31.6° — visually anchors
## the building to the iso grid instead of looking screen-upright.
const ISO_LEAN_RAD: float = 0.4636476  # atan(32 / 64)
const PLACEHOLDER_SCALE: Vector2 = Vector2(4.0, 4.0)


func _ready() -> void:
	rotation = ISO_LEAN_RAD
	scale = PLACEHOLDER_SCALE
	definition = BuildingDatabase.get_definition(building_key)
	if definition.is_empty():
		push_warning("[Building] No definition for key '%s'" % building_key)
		return

	if sprite.texture == null:
		sprite.texture = _build_placeholder_texture()

	_apply_rates()
	EventBus.building_completed.emit(building_key, _grid_position())




func _exit_tree() -> void:
	# Unwind our contribution to ResourceManager rates so destroy/move ops
	# don't leak buffs.
	for r_name in _produces_applied.keys():
		ResourceManager.add_to_rate(r_name, -_produces_applied[r_name])
	for r_name in _consumes_applied.keys():
		ResourceManager.add_to_rate(r_name, _consumes_applied[r_name])


func _apply_rates() -> void:
	var produces: Dictionary = definition.get("produces", {})
	for r_name in produces.keys():
		var amount: float = float(produces[r_name])
		ResourceManager.add_to_rate(r_name, amount)
		_produces_applied[r_name] = amount
	var consumes: Dictionary = definition.get("consumes", {})
	for r_name in consumes.keys():
		var amount: float = float(consumes[r_name])
		ResourceManager.add_to_rate(r_name, -amount)
		_consumes_applied[r_name] = amount


func _grid_position() -> Vector2i:
	return Vector2i(int(global_position.x / 32.0), int(global_position.y / 32.0))


func _build_placeholder_texture() -> Texture2D:
	var size: int = 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var palette: Color = _palette_for_key()
	var dark: Color = palette.darkened(0.4)
	for y in range(8, size - 4):
		for x in range(4, size - 4):
			img.set_pixel(x, y, palette)
	# Top trim band to give a sense of structure.
	for x in range(4, size - 4):
		for y in range(6, 12):
			img.set_pixel(x, y, dark)
	# Outline
	for y in range(6, size - 4):
		for x in range(4, size - 4):
			if img.get_pixel(x, y).a > 0:
				if (x > 0 and img.get_pixel(x - 1, y).a == 0) \
					or (x < size - 1 and img.get_pixel(x + 1, y).a == 0) \
					or (y > 0 and img.get_pixel(x, y - 1).a == 0) \
					or (y < size - 1 and img.get_pixel(x, y + 1).a == 0):
					img.set_pixel(x, y, Color(0.07, 0.09, 0.12))
	return ImageTexture.create_from_image(img)


func _palette_for_key() -> Color:
	match building_key:
		"solar_array":    return Color(0.30, 0.45, 0.85)
		"habitat_module": return Color(0.85, 0.85, 0.90)
		"mining_drill":   return Color(0.90, 0.70, 0.30)
		"rtg":            return Color(0.45, 0.45, 0.50)
		"electrolyzer":   return Color(0.55, 0.75, 0.85)
		"hydroponics_bay":return Color(0.50, 0.75, 0.55)
		"storage_silo":   return Color(0.55, 0.55, 0.60)
		"comms_dish":     return Color(0.80, 0.80, 0.85)
		"research_lab":   return Color(0.65, 0.55, 0.85)
		_:                return Color(0.60, 0.60, 0.65)
