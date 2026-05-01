class_name BuildPlacementController
extends Node2D
## Owns the build placement workflow.
##   1. `start_placement(building_key)` enters placement mode and shows a
##      ghost preview that tracks the cursor.
##   2. Left-click in placement mode validates affordability and calls
##      `place_building(key, world_pos)`.
##   3. `place_building` deducts cost from `ResourceManager`, instantiates
##      a `ConstructionSite` at the snapped grid position, and returns it.
##
## Test entry point: `place_building(key, world_pos)` bypasses the ghost
## preview UI so tests don't need to simulate cursor movement.

const TILE_SIZE: int = 32
const CONSTRUCTION_SITE_SCENE := preload("res://scenes/buildings/ConstructionSite.tscn")

signal placement_failed(reason: String)
signal placement_succeeded(building_key: String, grid_pos: Vector2i)

var _active_key: String = ""
var _ghost: Sprite2D = null


func _ready() -> void:
	EventBus.building_placed.connect(_on_building_placed)


func is_placing() -> bool:
	return _active_key != ""


func start_placement(key: String) -> void:
	if not BuildingDatabase.has_definition(key):
		push_warning("[BuildPlacementController] Unknown building key: %s" % key)
		return
	_active_key = key
	_ensure_ghost()
	_ghost.visible = true


func cancel_placement() -> void:
	_active_key = ""
	if _ghost != null:
		_ghost.visible = false


func _process(_delta: float) -> void:
	if _ghost != null and _ghost.visible:
		_ghost.global_position = _snap(get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			place_building(_active_key, get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()


## Returns the spawned ConstructionSite (typed as Node2D to avoid load-order
## issues with class_name discovery in headless mode) on success, null on
## failure. Public for tests + UI.
func place_building(key: String, world_pos: Vector2) -> Node2D:
	var def: Dictionary = BuildingDatabase.get_definition(key)
	if def.is_empty():
		emit_signal("placement_failed", "unknown building")
		return null
	var cost: Dictionary = def.get("cost", {})
	if not ResourceManager.can_afford(cost):
		emit_signal("placement_failed", "insufficient resources")
		EventBus.log_message.emit(
			"Cannot afford %s — short on resources." % def.get("display_name", key),
			"build",
		)
		return null
	if not ResourceManager.deduct(cost):
		emit_signal("placement_failed", "deduct failed")
		return null

	var site: Node2D = CONSTRUCTION_SITE_SCENE.instantiate()
	site.building_key = key
	get_parent().add_child(site)
	site.global_position = _snap(world_pos)

	var grid_pos := Vector2i(int(site.global_position.x / TILE_SIZE), int(site.global_position.y / TILE_SIZE))
	EventBus.building_placed.emit(key, grid_pos)
	emit_signal("placement_succeeded", key, grid_pos)
	if is_placing():
		cancel_placement()
	return site


func _snap(pos: Vector2) -> Vector2:
	var sx: float = floorf(pos.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5
	var sy: float = floorf(pos.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5
	return Vector2(sx, sy)


func _ensure_ghost() -> void:
	if _ghost != null:
		return
	_ghost = Sprite2D.new()
	_ghost.name = "PlacementGhost"
	_ghost.modulate = Color(0.36, 0.71, 0.84, 0.55)
	add_child(_ghost)
	_ghost.texture = _build_ghost_texture()


func _build_ghost_texture() -> Texture2D:
	var img := Image.create(40, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(0, 32):
		for x in range(0, 40):
			if x == 0 or x == 39 or y == 0 or y == 31 or (x + y) % 4 == 0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _on_building_placed(_key: String, _grid_pos: Vector2i) -> void:
	pass  # reserved for future bookkeeping (heatmap, undo stack, etc.)
