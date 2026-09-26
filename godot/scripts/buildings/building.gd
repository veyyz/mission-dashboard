class_name Building
extends StaticBody2D
## Generic finished-building node. Reads its definition from
## `BuildingDatabase` at runtime via `building_key`, applies produce/consume
## rates to `ResourceManager`, and renders a placeholder colored sprite until
## the matching Pixellab isometric tile lands and the art swap-in pass
## connects it.

@export var building_key: String = "solar_array"

const BUILDING_SPRITE_ROOT := "res://assets/sprites/buildings/"

var definition: Dictionary = {}
var _produces_applied: Dictionary = {}
var _consumes_applied: Dictionary = {}
var _caps_applied: Dictionary = {}
var _is_real_sprite: bool = false

@onready var sprite: Sprite2D = $Sprite2D


## Iso projection: image rect renders as an iso diamond covering
## cells_per_side × cells_per_side tiles. Per-building override comes from
## buildings.json `footprint_cells` field; defaults to 6.
const DEFAULT_CELLS_PER_SIDE: float = 6.0
const TILE_HALF_W: float = 32.0
const TILE_HALF_H: float = 16.0

var cells_per_side: float = DEFAULT_CELLS_PER_SIDE


func _ready() -> void:
	add_to_group("buildings")
	definition = BuildingDatabase.get_definition(building_key)
	cells_per_side = float(definition.get("footprint_cells", DEFAULT_CELLS_PER_SIDE))
	if sprite.texture == null:
		var real := _load_building_texture()
		if real != null:
			sprite.texture = real
			_is_real_sprite = true
		else:
			sprite.texture = _build_placeholder_texture()
	_apply_iso_transform()
	_setup_footprint_collision()
	_setup_navigation_obstacle()
	if definition.is_empty():
		push_warning("[Building] No definition for key '%s'" % building_key)
		return

	_apply_rates()
	EventBus.building_completed.emit(building_key, _grid_position())


func _apply_iso_transform() -> void:
	if sprite.texture == null:
		return
	var img: Vector2 = sprite.texture.get_size()
	if img.x <= 0.0 or img.y <= 0.0:
		return
	# Scale ONLY the sprite (not the body). Fit within the iso diamond
	# bounding box (cells × 64 wide, cells × 32 tall) so tall sprites don't
	# overflow the footprint. Feet anchored to body origin.
	var footprint_w: float = cells_per_side * TILE_HALF_W * 2.0
	var footprint_h: float = cells_per_side * TILE_HALF_H * 2.0
	var s: float = min(footprint_w / img.x, footprint_h / img.y)
	sprite.scale = Vector2(s, s)
	sprite.offset = Vector2(0, -img.y * 0.5)


## Inset (in tiles) shrinking the BLOCKING diamond inside the visual one,
## leaving a walkable perimeter of `BLOCK_INSET_TILES` cells around the
## building's interior. Visual size unchanged.
const BLOCK_INSET_TILES: float = 1.0


func _block_diamond_points() -> PackedVector2Array:
	# Inner diamond centered in the visual diamond, shrunk by BLOCK_INSET_TILES
	# tiles per side. Visual diamond has bottom apex at body origin and center
	# at y = -cells_per_side * TILE_HALF_H.
	var inset: float = BLOCK_INSET_TILES
	var inner_cells: float = max(cells_per_side - inset, 0.0)
	var hw: float = inner_cells * TILE_HALF_W
	var hh: float = inner_cells * TILE_HALF_H
	var cy: float = -cells_per_side * TILE_HALF_H
	return PackedVector2Array([
		Vector2(0, cy + hh),
		Vector2(hw, cy),
		Vector2(0, cy - hh),
		Vector2(-hw, cy),
	])


func _setup_footprint_collision() -> void:
	var col: CollisionShape2D = $CollisionShape2D
	if col == null:
		return
	var diamond := ConvexPolygonShape2D.new()
	diamond.points = _block_diamond_points()
	col.shape = diamond


func _setup_navigation_obstacle() -> void:
	if has_node("NavObstacle"):
		return
	var obs := NavigationObstacle2D.new()
	obs.name = "NavObstacle"
	obs.affect_navigation_mesh = true
	obs.vertices = _block_diamond_points()
	add_child(obs)


func _load_building_texture() -> Texture2D:
	var path := "%s%s.png" % [BUILDING_SPRITE_ROOT, building_key]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D




func _exit_tree() -> void:
	# Unwind our contribution to ResourceManager rates so destroy/move ops
	# don't leak buffs.
	for r_name in _produces_applied.keys():
		ResourceManager.add_to_rate(r_name, -_produces_applied[r_name])
	for r_name in _consumes_applied.keys():
		ResourceManager.add_to_rate(r_name, _consumes_applied[r_name])
	for r_name in _caps_applied.keys():
		ResourceManager.set_max(r_name, ResourceManager.get_max(r_name) - _caps_applied[r_name])


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
	# Storage buildings raise caps instead of rates (buildings.json `raises_cap`).
	var raises: Dictionary = definition.get("raises_cap", {})
	for r_name in raises.keys():
		var amount: float = float(raises[r_name])
		ResourceManager.set_max(r_name, ResourceManager.get_max(r_name) + amount)
		_caps_applied[r_name] = amount


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
		"regolith_excavator": return Color(0.80, 0.65, 0.35)
		"sintering_kiln": return Color(0.85, 0.50, 0.30)
		"reduction_plant": return Color(0.60, 0.45, 0.45)
		"mre_smelter":    return Color(0.75, 0.75, 0.60)
		"hospital":       return Color(0.95, 0.95, 0.95)
		_:                return Color(0.60, 0.60, 0.65)
