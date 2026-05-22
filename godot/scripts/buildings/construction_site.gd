class_name ConstructionSite
extends Node2D
## Construction site. Spawns at placement, renders a wireframe ghost, and
## ticks build progress while at least one Engineer is within
## `ENGINEER_REACH` global pixels. On completion, replaces itself with the
## finished building scene (per `BuildingDatabase.get_scene_path(key)`) and
## fires `EventBus.building_completed` (the building's own `_ready` does the
## emit).

const ENGINEER_REACH: float = 128.0  # pixels — generous grid-cell radius

@export var building_key: String = "solar_array"

var definition: Dictionary = {}
var build_time_seconds: float = 30.0
var progress: float = 0.0  # 0.0 to 1.0

const BUILDING_SPRITE_ROOT := "res://assets/sprites/buildings/"

@onready var sprite: Sprite2D = $Sprite2D
@onready var progress_bar: ProgressBar = $ProgressLayer/ProgressBar


## Iso projection identical to finished Building. Footprint comes from
## buildings.json `footprint_cells` field; defaults to 6.
const DEFAULT_CELLS_PER_SIDE: float = 6.0
const TILE_HALF_W: float = 32.0
const TILE_HALF_H: float = 16.0

var cells_per_side: float = DEFAULT_CELLS_PER_SIDE


func _ready() -> void:
	add_to_group("construction_sites")
	definition = BuildingDatabase.get_definition(building_key)
	cells_per_side = float(definition.get("footprint_cells", DEFAULT_CELLS_PER_SIDE))
	# Temporary: 1s build time for all buildings (testing).
	build_time_seconds = 1.0
	if sprite.texture == null:
		var real := _load_building_texture()
		if real != null:
			sprite.texture = real
			# Grayscale shader + slight transparency so the site reads as
			# "under construction" and crew behind it stays visible.
			sprite.material = _make_grayscale_material()
			sprite.modulate = Color(1, 1, 1, 1.0)
		else:
			sprite.texture = _build_ghost_texture()
	_apply_iso_transform()
	_position_progress_bar()
	_setup_block()
	if progress_bar != null:
		progress_bar.value = 0.0


func _apply_iso_transform() -> void:
	if sprite.texture == null:
		return
	var img: Vector2 = sprite.texture.get_size()
	if img.x <= 0.0 or img.y <= 0.0:
		return
	# Scale ONLY the sprite (not the body). Fit within iso diamond bounding
	# box so tall sprites don't overflow the footprint. Feet anchored to
	# body origin.
	var footprint_w: float = cells_per_side * TILE_HALF_W * 2.0
	var footprint_h: float = cells_per_side * TILE_HALF_H * 2.0
	var s: float = min(footprint_w / img.x, footprint_h / img.y)
	sprite.scale = Vector2(s, s)
	sprite.offset = Vector2(0, -img.y * 0.5)




func _process(delta: float) -> void:
	if _engineer_in_reach():
		tick(delta)


## Public so tests / cheat menus can advance directly without simulating crew.
func tick(seconds: float) -> void:
	if progress >= 1.0:
		return
	progress = clampf(progress + (seconds / build_time_seconds), 0.0, 1.0)
	if progress_bar != null:
		progress_bar.value = progress * 100.0
	if progress >= 1.0:
		_complete()


func _engineer_in_reach() -> bool:
	# CrewMember._ready() registers itself in the "crew" group.
	for node in get_tree().get_nodes_in_group("crew"):
		var crew := node as CrewMember
		if crew == null or crew.role != CrewMember.Role.ENGINEER:
			continue
		if crew.global_position.distance_to(global_position) <= ENGINEER_REACH:
			return true
	return false


func _complete() -> void:
	var scene_path: String = BuildingDatabase.get_scene_path(building_key)
	if scene_path == "":
		push_error("[ConstructionSite] No scene for key '%s'" % building_key)
		queue_free()
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("[ConstructionSite] Failed to load %s" % scene_path)
		queue_free()
		return
	var building: Node2D = packed.instantiate()
	# Insert into the same parent FIRST so the child receives the parent's
	# transform; then assign global_position. Setting global_position before
	# add_child is a no-op because the node has no parent transform yet.
	var spawn_pos: Vector2 = global_position
	get_parent().add_child(building)
	building.global_position = spawn_pos
	queue_free()


func _position_progress_bar() -> void:
	# Anchor ProgressLayer just above the sprite top in body-local coords.
	# Sprite is feet-anchored at body origin and extends UP by img.y * scale.
	if sprite.texture == null:
		return
	var img: Vector2 = sprite.texture.get_size()
	var sprite_top_y: float = -img.y * sprite.scale.y
	var layer: Control = $ProgressLayer
	if layer != null:
		layer.position = Vector2(-32, sprite_top_y - 14)


## Same inset rule as Building so crew has a walkable perimeter around the
## site too (matches completed-building behavior).
const BLOCK_INSET_TILES: float = 1.0


func _block_diamond_points() -> PackedVector2Array:
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


func _setup_block() -> void:
	# StaticBody2D + CollisionShape2D + NavigationObstacle2D using the inset
	# diamond — crew can walk on the outer 1-tile ring of the visual footprint.
	if has_node("StaticBody2D"):
		return
	var body := StaticBody2D.new()
	body.name = "StaticBody2D"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var diamond := ConvexPolygonShape2D.new()
	diamond.points = _block_diamond_points()
	col.shape = diamond
	body.add_child(col)
	add_child(body)
	var obs := NavigationObstacle2D.new()
	obs.name = "NavObstacle"
	obs.affect_navigation_mesh = true
	obs.vertices = _block_diamond_points()
	add_child(obs)


func _make_grayscale_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray), c.a);
}
"""
	mat.shader = sh
	return mat


func _load_building_texture() -> Texture2D:
	var path := "%s%s.png" % [BUILDING_SPRITE_ROOT, building_key]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _build_ghost_texture() -> Texture2D:
	var size: int = 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ghost: Color = Color(0.36, 0.71, 0.84, 0.45)
	for y in range(8, size - 4):
		for x in range(4, size - 4):
			img.set_pixel(x, y, ghost)
	# Crosshatch
	for y in range(8, size - 4):
		for x in range(4, size - 4):
			if (x + y) % 6 == 0:
				img.set_pixel(x, y, Color(0.36, 0.71, 0.84, 0.85))
	return ImageTexture.create_from_image(img)
