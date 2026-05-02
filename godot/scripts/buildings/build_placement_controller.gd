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

const CONSTRUCTION_SITE_SCENE := preload("res://scenes/buildings/ConstructionSite.tscn")

# Match the iso-diagonal lean + 4× placeholder scale used by ConstructionSite
# and Building so the hover preview, the placed construction site, and the
# finished building all share the same on-screen orientation and size.
const ISO_LEAN_RAD: float = 0.4636476  # atan(TILE_H / TILE_W) for 64×32
const PLACEHOLDER_SCALE: Vector2 = Vector2(4.0, 4.0)

signal placement_failed(reason: String)
signal placement_succeeded(building_key: String, grid_pos: Vector2i)

var _active_key: String = ""
var _ghost: Sprite2D = null
var _tile_layer: TileMapLayer = null


func _ready() -> void:
	EventBus.building_placed.connect(_on_building_placed)
	# Find the world's iso TileMapLayer so we can snap to iso cells.
	# The placement controller lives under YSort which is a sibling of
	# TileMapLayer under Ground.
	var ground: Node = get_parent().get_parent()
	if ground != null:
		_tile_layer = ground.find_child("TileMapLayer", true, false) as TileMapLayer


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

	var grid_pos: Vector2i = _world_to_cell(world_pos)
	EventBus.building_placed.emit(key, grid_pos)
	emit_signal("placement_succeeded", key, grid_pos)
	if is_placing():
		cancel_placement()
	return site


## Snap to the iso cell under the cursor. Uses the TileMapLayer's
## local_to_map / map_to_local helpers — handles iso geometry correctly
## without us hand-rolling the diamond math.
func _snap(global_pos: Vector2) -> Vector2:
	if _tile_layer == null:
		return global_pos
	var local: Vector2 = _tile_layer.to_local(global_pos)
	var cell: Vector2i = _tile_layer.local_to_map(local)
	var snapped_local: Vector2 = _tile_layer.map_to_local(cell)
	return _tile_layer.to_global(snapped_local)


func _world_to_cell(global_pos: Vector2) -> Vector2i:
	if _tile_layer == null:
		return Vector2i.ZERO
	return _tile_layer.local_to_map(_tile_layer.to_local(global_pos))


func _ensure_ghost() -> void:
	if _ghost != null:
		return
	_ghost = Sprite2D.new()
	_ghost.name = "PlacementGhost"
	_ghost.modulate = Color(0.36, 0.71, 0.84, 0.55)
	_ghost.rotation = ISO_LEAN_RAD
	_ghost.scale = PLACEHOLDER_SCALE
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
