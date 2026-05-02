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

const CREW_ROSTER: Array[Dictionary] = [
	{"name": "Alex",  "role": 0, "skill": 88, "offset": Vector2(  0,   0)},  # ENGINEER
	{"name": "Maya",  "role": 1, "skill": 92, "offset": Vector2( 48,   0)},  # SCIENTIST
	{"name": "Zane",  "role": 2, "skill": 78, "offset": Vector2( 96,   0)},  # BOTANIST
	{"name": "Rin",   "role": 3, "skill": 85, "offset": Vector2(  0,  48)},  # GEOLOGIST
	{"name": "Cora",  "role": 4, "skill": 81, "offset": Vector2( 48,  48)},  # MEDIC
	{"name": "Voss",  "role": 5, "skill": 90, "offset": Vector2( 96,  48)},  # COMMANDER
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
	EventBus.landing_confirmed.connect(_on_landing_confirmed)
	print("[Ground] Phase 7 ready. Tiles=%d  awaiting landing." % tile_layer.get_used_cells().size())


## Programmatic landing entry point. Tests call this directly to skip the
## ghost-placement UX and spawn crew + nodes at a known location.
func confirm_landing_at(world_pos: Vector2) -> void:
	if _crew_spawned:
		return
	_crew_spawned = true
	_spawn_crew(world_pos)
	_spawn_resource_nodes(world_pos)
	print("[Ground] Landing complete. Crew=%d  Nodes=%d  pos=%s" % [
		crew_container.get_child_count(),
		get_tree().get_nodes_in_group("resource_node").size(),
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
		crew.position = landing_pos + data.offset
		crew.rotation = counter_rot
		crew_container.add_child(crew)
		if first_crew == null:
			first_crew = crew
	if first_crew != null:
		first_crew.set_selected.call_deferred(true)


## Phase-8: spawn six placeholder resource nodes around the landing site.
func _spawn_resource_nodes(landing_pos: Vector2) -> void:
	const NODE_LAYOUT: Array = [
		{"type": "iron",        "amount": 8, "offset": Vector2(180, 60)},
		{"type": "silicon",     "amount": 6, "offset": Vector2(-180, 60)},
		{"type": "water_ice",   "amount": 4, "offset": Vector2(60, 220)},
		{"type": "titanium",    "amount": 5, "offset": Vector2(-60, 220)},
		{"type": "helium3",     "amount": 3, "offset": Vector2(220, -180)},
		{"type": "rare_metals", "amount": 2, "offset": Vector2(-220, -180)},
	]
	var node_scene: PackedScene = preload("res://scenes/world/ResourceNode.tscn")
	for entry in NODE_LAYOUT:
		var rn: Node2D = node_scene.instantiate()
		rn.deposit_type = entry.type
		rn.amount = entry.amount
		rn.position = landing_pos + entry.offset
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
