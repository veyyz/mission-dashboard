extends Node2D
## Phase-4 ground scene controller.
## - Builds a placeholder regolith tileset and paints a 25x25 patch.
## - Spawns a NavigationRegion2D covering the playable area for crew pathfinding.
## - Spawns 6 crew members (one per role) and parents them under the
##   `CrewSelectionManager` (a.k.a. CrewContainer) so input + selection
##   logic lives in one place.
## - Hands a Camera2D to the first crew (Alex) so the existing follow-camera
##   contract from Phase 2 still holds.

const TILE_SIZE: int = 32
const MAP_RADIUS: int = 12  # cells outward from (0,0); 25x25 painted patch
const NAV_HALF_EXTENT: float = 2000.0

const CREW_SCENE := preload("res://scenes/crew/CrewMember.tscn")

const CREW_ROSTER: Array[Dictionary] = [
	{"name": "Alex",  "role": 0, "skill": 88, "pos": Vector2(  0,   0)},  # ENGINEER
	{"name": "Maya",  "role": 1, "skill": 92, "pos": Vector2( 48,   0)},  # SCIENTIST
	{"name": "Zane",  "role": 2, "skill": 78, "pos": Vector2( 96,   0)},  # BOTANIST
	{"name": "Rin",   "role": 3, "skill": 85, "pos": Vector2(  0,  48)},  # GEOLOGIST
	{"name": "Cora",  "role": 4, "skill": 81, "pos": Vector2( 48,  48)},  # MEDIC
	{"name": "Voss",  "role": 5, "skill": 90, "pos": Vector2( 96,  48)},  # COMMANDER
]

@onready var tile_layer: TileMapLayer = $TileMapLayer
@onready var crew_container: Node2D = $YSort/CrewContainer


func _ready() -> void:
	tile_layer.tile_set = _build_placeholder_tileset()
	_paint_ground()
	_build_navigation_region()
	_spawn_crew()
	print("[Ground] Phase 4 ready. Tiles=%d  Crew=%d" % [
		tile_layer.get_used_cells().size(),
		crew_container.get_child_count(),
	])


func _build_placeholder_tileset() -> TileSet:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.32, 0.34, 0.38))
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


func _build_navigation_region() -> void:
	var nav_region := NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	var nav_poly := NavigationPolygon.new()
	nav_poly.vertices = PackedVector2Array([
		Vector2(-NAV_HALF_EXTENT, -NAV_HALF_EXTENT),
		Vector2( NAV_HALF_EXTENT, -NAV_HALF_EXTENT),
		Vector2( NAV_HALF_EXTENT,  NAV_HALF_EXTENT),
		Vector2(-NAV_HALF_EXTENT,  NAV_HALF_EXTENT),
	])
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)


func _spawn_crew() -> void:
	var first_crew: CrewMember = null
	for i in range(CREW_ROSTER.size()):
		var data: Dictionary = CREW_ROSTER[i]
		var crew: CrewMember = CREW_SCENE.instantiate()
		crew.name = data.name
		crew.crew_name = data.name
		crew.crew_id = i + 1
		crew.role = data.role
		crew.role_skill = data.skill
		crew.position = data.pos
		crew_container.add_child(crew)
		if first_crew == null:
			first_crew = crew

	if first_crew != null:
		# Default selection: Alex, so WASD has someone to drive at boot.
		first_crew.set_selected.call_deferred(true)
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		camera.zoom = Vector2(2, 2)
		first_crew.add_child(camera)
