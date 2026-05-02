extends Node2D
## Phase-5.5 ground scene controller — true isometric.
## - Builds a placeholder iso regolith tileset (`tile_shape = 1` Isometric,
##   `tile_layout = 5` Diamond Down, `tile_size = Vector2i(64, 32)`) per
##   `futurequest_lunar_mission_godot.md` §6.
## - Paints a square cell range that renders as a diamond patch on screen.
## - Spawns a NavigationRegion2D covering the playable area for crew pathfinding.
## - Spawns 6 crew members under `CrewSelectionManager`.
## - Hands a Camera2D to the first crew (Alex).

const TILE_W: int = 64
const TILE_H: int = 32
const MAP_RADIUS: int = 72  # cells outward from (0,0); 145x145 = 21025 painted cells
const NAV_HALF_EXTENT: float = 8000.0

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


func _enter_tree() -> void:
	# Tag this rotated container BEFORE any child's _ready runs (Godot fires
	# _enter_tree top-down but _ready bottom-up). Surface artifacts call
	# `_apply_screen_upright()` in their own _ready and look this group up;
	# without registering early they'd find nothing and stay tilted.
	add_to_group("world_root")


func _ready() -> void:
	tile_layer.tile_set = _build_placeholder_tileset()
	_paint_ground()
	_build_navigation_region()
	_spawn_crew()
	_spawn_resource_nodes()
	print("[Ground] Phase 4 ready. Tiles=%d  Crew=%d  Nodes=%d" % [
		tile_layer.get_used_cells().size(),
		crew_container.get_child_count(),
		get_tree().get_nodes_in_group("resource_node").size(),
	])


## Phase-8: spawn six placeholder resource nodes near the landing zone.
## Real layout will be seeded from `data/orbit_deposits.json` plus the
## chosen `GameState.selected_landing_tile` once the orbit-map landing
## flow drives world state (Phase 8/9 polish).
func _spawn_resource_nodes() -> void:
	const NODE_LAYOUT: Array = [
		{"type": "iron",        "amount": 8, "pos": Vector2(180, 60)},
		{"type": "silicon",     "amount": 6, "pos": Vector2(-180, 60)},
		{"type": "water_ice",   "amount": 4, "pos": Vector2(60, 220)},
		{"type": "titanium",    "amount": 5, "pos": Vector2(-60, 220)},
		{"type": "helium3",     "amount": 3, "pos": Vector2(220, -180)},
		{"type": "rare_metals", "amount": 2, "pos": Vector2(-220, -180)},
	]
	var node_scene: PackedScene = preload("res://scenes/world/ResourceNode.tscn")
	for entry in NODE_LAYOUT:
		var rn: Node2D = node_scene.instantiate()
		rn.deposit_type = entry.type
		rn.amount = entry.amount
		rn.position = entry.pos
		$YSort.add_child(rn)


## Builds a runtime iso TileSet. Real Pixellab Wang regolith tiles swap in
## via the per-phase art swap-in pass once `art_queue.terrain.regolith_to_rocky`
## lands.
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

	# Anchor the diamond top to the cell's top vertex so adjacent cells
	# tessellate without seams. (Pixellab godot/isometric-tiles doc:
	# tile_size=(32,16) → texture_origin=(0,-8); we use 64x32 → (0,-16).)
	var data: TileData = src.get_tile_data(Vector2i.ZERO, 0)
	data.texture_origin = Vector2i(0, -TILE_H / 2)

	ts.add_source(src, 0)
	return ts


## Procedurally generates a 64x32 diamond filled with `color`, transparent
## outside the diamond, with sparse speckle for visual interest. Inscribed
## diamond uses 2:1 aspect ratio per the iso tile_size.
func _build_diamond_image(color: Color) -> Image:
	var img := Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark: Color = Color(0.27, 0.29, 0.33)
	var hl: Color = Color(0.38, 0.40, 0.44)
	for y in range(TILE_H):
		# Diamond half-width at this row (2:1 aspect, full at center rows).
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


## Paints a diamond patch of cells. With Diamond Down layout, painting a
## square coord range around (0,0) renders as a diamond on screen.
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
	# Counter-rotation so crew sprites + nameplates stay screen-vertical
	# despite the world being tilted 20° clockwise. Buildings + ground tiles
	# still inherit the world rotation; only the crew rigs are upright.
	var counter_rot: float = -rotation
	for i in range(CREW_ROSTER.size()):
		var data: Dictionary = CREW_ROSTER[i]
		var crew: CrewMember = CREW_SCENE.instantiate()
		crew.name = data.name
		crew.crew_name = data.name
		crew.crew_id = i + 1
		crew.role = data.role
		crew.role_skill = data.skill
		crew.position = data.pos
		crew.rotation = counter_rot
		crew_container.add_child(crew)
		if first_crew == null:
			first_crew = crew

	if first_crew != null:
		# Default selection: Alex, so WASD has someone to drive at boot.
		first_crew.set_selected.call_deferred(true)

	# Bird's-eye WorldCamera. Strategic zoom = full map. The Zoom In / Out
	# buttons in `scenes/ui/ZoomControls.tscn` flip between strategic and
	# gameplay (camera centered on the currently selected crew). Loaded via
	# preload + .new() instead of `WorldCamera.new()` to dodge GDScript
	# class_name discovery lag in headless mode.
	var world_camera_script := preload("res://scripts/world/world_camera.gd")
	var camera: Camera2D = world_camera_script.new()
	camera.name = "Camera2D"
	camera.position = world_camera_script.STRATEGIC_CENTER
	camera.zoom = world_camera_script.STRATEGIC_ZOOM
	camera.ignore_rotation = true
	add_child(camera)

	var zoom_ui: CanvasLayer = preload("res://scenes/ui/ZoomControls.tscn").instantiate()
	add_child(zoom_ui)
