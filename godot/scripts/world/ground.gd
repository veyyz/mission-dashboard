extends Node2D
## Phase-2 ground scene controller. Builds a placeholder regolith tileset at
## runtime and paints a square map around the origin. Real Wang tilesets from
## Pixellab swap in once `art_queue.terrain.regolith_to_rocky` lands (handled
## in the per-phase art swap-in pass — see docs/pixellab_godot.md).

const TILE_SIZE: int = 32
const MAP_RADIUS: int = 12  # cells outward from (0,0); produces a 25x25 patch

@onready var tile_layer: TileMapLayer = $TileMapLayer


func _ready() -> void:
	tile_layer.tile_set = _build_placeholder_tileset()
	_paint_ground()
	print("[Ground] Phase 2 ready. Tiles painted: %d" % tile_layer.get_used_cells().size())


func _build_placeholder_tileset() -> TileSet:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.32, 0.34, 0.38))  # regolith grey
	# Sparse dust speckle for visual texture without committing to a real asset.
	for x in range(0, TILE_SIZE):
		for y in range(0, TILE_SIZE):
			if (x * 7 + y * 13) % 23 == 0:
				img.set_pixel(x, y, Color(0.27, 0.29, 0.33))
			elif (x * 5 + y * 3) % 31 == 0:
				img.set_pixel(x, y, Color(0.38, 0.40, 0.44))

	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	return ts


func _paint_ground() -> void:
	for x in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for y in range(-MAP_RADIUS, MAP_RADIUS + 1):
			tile_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
