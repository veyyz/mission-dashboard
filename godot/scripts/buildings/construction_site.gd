class_name ConstructionSite
extends Node2D
## Construction site. Spawns at placement, renders a wireframe ghost, and
## ticks build progress while at least one Engineer is within
## `ENGINEER_REACH` global pixels. On completion, replaces itself with the
## finished building scene (per `BuildingDatabase.get_scene_path(key)`) and
## fires `EventBus.building_completed` (the building's own `_ready` does the
## emit).

const ENGINEER_REACH: float = 64.0  # pixels — generous grid-cell radius

@export var building_key: String = "solar_array"

var definition: Dictionary = {}
var build_time_seconds: float = 30.0
var progress: float = 0.0  # 0.0 to 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var progress_bar: ProgressBar = $ProgressLayer/ProgressBar


## Tilt + scale the construction-site ghost to match the finished Building
## so the visual transition at completion doesn't snap.
const ISO_LEAN_RAD: float = 0.4636476  # atan(32 / 64)
const PLACEHOLDER_SCALE: Vector2 = Vector2(4.0, 4.0)


func _ready() -> void:
	rotation = ISO_LEAN_RAD
	scale = PLACEHOLDER_SCALE
	definition = BuildingDatabase.get_definition(building_key)
	build_time_seconds = float(definition.get("build_time_seconds", 30))
	if sprite.texture == null:
		sprite.texture = _build_ghost_texture()
	if progress_bar != null:
		progress_bar.value = 0.0




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
