extends Node2D
## Phase-5.5 ground scene controller — true isometric.
## - Builds a placeholder iso regolith tileset and paints a square cell range.
## - Spawns a NavigationRegion2D covering the playable area.
## - Spawns a Camera2D at boot (always current).
## - Defers crew spawn until `EventBus.landing_confirmed` fires (Phase 7
##   landing-ghost flow): no crew on screen until the player picks a tile.
## - Spawns 6 placeholder resource nodes near the chosen landing site.

const TILE_W: int = 64
const TILE_H: int = 32
const MAP_RADIUS: int = 72  # cells outward from (0,0); 145x145 = 21025 painted cells
const NAV_HALF_EXTENT: float = 8000.0

const CREW_SCENE := preload("res://scenes/crew/CrewMember.tscn")

## `role` is a CrewMember.Role int. `art` overrides the role's default sprite
## folder — required for the SPECIALIST block, since they all share a role.
const CREW_ROSTER: Array[Dictionary] = [
	{"name": "Alex",     "role": 0, "skill": 88, "art": "",         "offset": Vector2(  0,   0)},  # ENGINEER
	{"name": "Maddie",   "role": 1, "skill": 92, "art": "",         "offset": Vector2( 48,   0)},  # SCIENTIST
	{"name": "Marrin",   "role": 2, "skill": 78, "art": "",         "offset": Vector2( 96,   0)},  # BOTANIST
	{"name": "Preston",  "role": 3, "skill": 85, "art": "",         "offset": Vector2(  0,  48)},  # GEOLOGIST
	{"name": "Thorin",   "role": 4, "skill": 81, "art": "",         "offset": Vector2( 48,  48)},  # MEDIC
	{"name": "Vera",     "role": 5, "skill": 90, "art": "",         "offset": Vector2( 96,  48)},  # COMMANDER
	{"name": "Rainbow",  "role": 6, "skill": 76, "art": "rainbow",  "offset": Vector2(  0,  96)},  # SPECIALIST
	{"name": "Rush",     "role": 6, "skill": 83, "art": "rush",     "offset": Vector2( 48,  96)},  # SPECIALIST
	{"name": "Mister E", "role": 6, "skill": 79, "art": "mistere",  "offset": Vector2( 96,  96)},  # SPECIALIST
	{"name": "PrimeMax", "role": 6, "skill": 87, "art": "primemax", "offset": Vector2(  0, 144)},  # SPECIALIST
	{"name": "Brandon",  "role": 6, "skill": 84, "art": "brandon",  "offset": Vector2( 48, 144)},  # SPECIALIST
	{"name": "Athena",   "role": 6, "skill": 89, "art": "athena",   "offset": Vector2( 96, 144)},  # SPECIALIST
]

@onready var tile_layer: TileMapLayer = $TileMapLayer
@onready var crew_container: Node2D = $YSort/CrewContainer

var _crew_spawned: bool = false


func _enter_tree() -> void:
	add_to_group("world_root")


func _ready() -> void:
	tile_layer.tile_set = _build_placeholder_tileset()
	_paint_ground()
	_build_navigation_region()
	_spawn_camera()
	_spawn_zoom_ui()
	_spawn_resource_nodes()
	EventBus.landing_confirmed.connect(_on_landing_confirmed)
	print("[Ground] Phase 7 ready. Tiles=%d  Nodes=%d  awaiting landing." % [
		tile_layer.get_used_cells().size(),
		get_tree().get_nodes_in_group("resource_node").size(),
	])


## Programmatic landing entry point. Tests call this directly to skip the
## ghost-placement UX and spawn crew at a known location.
func confirm_landing_at(world_pos: Vector2) -> void:
	if _crew_spawned:
		return
	_crew_spawned = true
	_spawn_crew(world_pos)
	print("[Ground] Landing complete. Crew=%d  pos=%s" % [
		crew_container.get_child_count(),
		world_pos,
	])


func _on_landing_confirmed(grid_pos: Vector2i) -> void:
	# grid_pos is in iso cell coords; convert via the layer's helper.
	var world_pos: Vector2 = tile_layer.map_to_local(grid_pos)
	confirm_landing_at(world_pos)


func _spawn_camera() -> void:
	var world_camera_script := preload("res://scripts/world/world_camera.gd")
	var camera: Camera2D = world_camera_script.new()
	camera.name = "Camera2D"
	camera.position = world_camera_script.STRATEGIC_CENTER
	camera.zoom = world_camera_script.STRATEGIC_ZOOM
	camera.ignore_rotation = true
	add_child(camera)
	camera.make_current()


func _spawn_zoom_ui() -> void:
	var zoom_ui: CanvasLayer = preload("res://scenes/ui/ZoomControls.tscn").instantiate()
	add_child(zoom_ui)


func _spawn_crew(landing_pos: Vector2) -> void:
	var first_crew: CrewMember = null
	var counter_rot: float = -rotation
	for i in range(CREW_ROSTER.size()):
		var data: Dictionary = CREW_ROSTER[i]
		var crew: CrewMember = CREW_SCENE.instantiate()
		crew.name = data.name
		crew.crew_name = data.name
		crew.crew_id = i + 1
		crew.role = data.role
		crew.role_skill = data.skill
		crew.sprite_folder = data.get("art", "")
		crew.position = landing_pos + data.offset
		crew.rotation = counter_rot
		crew_container.add_child(crew)
		if first_crew == null:
			first_crew = crew
	if first_crew != null:
		first_crew.set_selected.call_deferred(true)


## Spread 6 resource hotspots across the painted tile diamond (at boot,
## before landing). Cell coordinates chosen well inside the 145×145
## painted range so all sit on regolith. Converted to world via the
## tile layer's map_to_local helper.
func _spawn_resource_nodes() -> void:
	const NODE_LAYOUT: Array = [
		{"type": "iron",        "amount": 12, "cell": Vector2i(-50, -10)},
		{"type": "silicon",     "amount": 10, "cell": Vector2i( 50, -10)},
		{"type": "water_ice",   "amount":  8, "cell": Vector2i(-15, -45)},
		{"type": "titanium",    "amount":  9, "cell": Vector2i( 15, -45)},
		{"type": "helium3",     "amount":  7, "cell": Vector2i(-15,  45)},
		{"type": "rare_metals", "amount":  5, "cell": Vector2i( 15,  45)},
	]
	var node_scene: PackedScene = preload("res://scenes/world/ResourceNode.tscn")
	for entry in NODE_LAYOUT:
		var rn: Node2D = node_scene.instantiate()
		rn.deposit_type = entry.type
		rn.amount = entry.amount
		rn.position = tile_layer.map_to_local(entry.cell)
		$YSort.add_child(rn)


func _build_placeholder_tileset() -> TileSet:
	var img := _build_diamond_image(Color(0.32, 0.34, 0.38))
	var tex := ImageTexture.create_from_image(img)

	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(TILE_W, TILE_H)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_W, TILE_H)
	src.create_tile(Vector2i.ZERO)

	var data: TileData = src.get_tile_data(Vector2i.ZERO, 0)
	data.texture_origin = Vector2i(0, -TILE_H / 2)

	ts.add_source(src, 0)
	return ts


func _build_diamond_image(color: Color) -> Image:
	var img := Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark: Color = Color(0.27, 0.29, 0.33)
	var hl: Color = Color(0.38, 0.40, 0.44)
	for y in range(TILE_H):
		var dy_from_center: int
		if y < TILE_H / 2:
			dy_from_center = TILE_H / 2 - 1 - y
		else:
			dy_from_center = y - TILE_H / 2
		var hw: int = (TILE_W / 2) - dy_from_center * (TILE_W / TILE_H)
		var start_x: int = TILE_W / 2 - hw
		var end_x: int = TILE_W / 2 + hw
		for x in range(maxi(0, start_x), mini(TILE_W, end_x)):
			var c: Color = color
			if (x * 5 + y * 7) % 13 == 0:
				c = dark
			elif (x * 3 + y * 11) % 17 == 0:
				c = hl
			img.set_pixel(x, y, c)
	return img


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
