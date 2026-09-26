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

# Iso projection so ghost preview matches ConstructionSite + Building.
# Footprint pulled per-key from buildings.json `footprint_cells`.
const DEFAULT_CELLS_PER_SIDE: float = 6.0
const TILE_HALF_W: float = 32.0
const TILE_HALF_H: float = 16.0

var _ghost_cells: float = DEFAULT_CELLS_PER_SIDE

signal placement_failed(reason: String)
signal placement_succeeded(building_key: String, grid_pos: Vector2i)

var _active_key: String = ""
var _demolish_mode: bool = false
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


func is_demolishing() -> bool:
	return _demolish_mode


func start_placement(key: String) -> void:
	if not BuildingDatabase.has_definition(key):
		push_warning("[BuildPlacementController] Unknown building key: %s" % key)
		return
	_demolish_mode = false
	_active_key = key
	_ghost_cells = float(BuildingDatabase.get_definition(key).get("footprint_cells", DEFAULT_CELLS_PER_SIDE))
	_ensure_ghost()
	_ghost.modulate = Color(0.36, 0.71, 0.84, 0.55)
	_ghost.visible = true


func cancel_placement() -> void:
	_active_key = ""
	if _ghost != null:
		_ghost.visible = false


func start_demolish() -> void:
	_active_key = ""
	_demolish_mode = true
	_ensure_ghost()
	_ghost.modulate = Color(0.95, 0.32, 0.32, 0.65)
	_ghost.visible = true


func cancel_demolish() -> void:
	_demolish_mode = false
	if _ghost != null:
		_ghost.visible = false


func _process(_delta: float) -> void:
	if _ghost != null and _ghost.visible:
		_apply_iso_transform_to_ghost()
		_ghost.global_position = _snap(get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing() and not is_demolishing():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if is_demolishing():
				_demolish_at(get_global_mouse_position())
			else:
				place_building(_active_key, get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if is_demolishing():
				cancel_demolish()
			else:
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
		# Spell out every line that is short: "Solar Cells 8 (have 3)".
		var short: Array[String] = []
		for r_name in cost.keys():
			var have: float = ResourceManager.get_current(r_name)
			var need: float = float(cost[r_name])
			if have < need:
				short.append("%s %d (have %d)" % [ResourceManager.display_name(r_name), int(need), int(have)])
		EventBus.log_message.emit(
			"Cannot build %s — need %s. Full cost: %s." % [
				def.get("display_name", key), ", ".join(short), ResourceManager.format_cost(cost),
			],
			"alert",
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
	add_child(_ghost)
	_ghost.texture = _build_ghost_texture()
	_apply_iso_transform_to_ghost()


func _apply_iso_transform_to_ghost() -> void:
	if _ghost == null or _ghost.texture == null:
		return
	var img: Vector2 = _ghost.texture.get_size()
	if img.x <= 0.0 or img.y <= 0.0:
		return
	# Fit within iso diamond bounding box so ghost matches construction_site
	# + building scale (which both use min(w_fit, h_fit)).
	var footprint_w: float = _ghost_cells * TILE_HALF_W * 2.0
	var footprint_h: float = _ghost_cells * TILE_HALF_H * 2.0
	var s: float = min(footprint_w / img.x, footprint_h / img.y)
	_ghost.offset = Vector2(0, -img.y * 0.5)
	var pos: Vector2 = _ghost.position
	_ghost.transform = Transform2D(Vector2(s, 0), Vector2(0, s), pos)


func _build_ghost_texture() -> Texture2D:
	# Iso diamond outline matching one tile (64×32). Drawn directly so the
	# texture itself looks isometric — no skew transform needed.
	var w: int = 64
	var h: int = 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = (w - 1) * 0.5
	var cy: float = (h - 1) * 0.5
	var hw: float = (w - 1) * 0.5
	var hh: float = (h - 1) * 0.5
	for y in range(0, h):
		for x in range(0, w):
			# Diamond inequality: |dx|/hw + |dy|/hh ≈ 1
			var d: float = abs(x - cx) / hw + abs(y - cy) / hh
			if d <= 1.0 and d >= 0.85:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif d < 0.85:
				img.set_pixel(x, y, Color(1, 1, 1, 0.18))
	return ImageTexture.create_from_image(img)


func _on_building_placed(_key: String, _grid_pos: Vector2i) -> void:
	pass  # reserved for future bookkeeping (heatmap, undo stack, etc.)


## Find a building or construction site whose anchor cell matches the snapped
## click cell, then refund + remove + emit destroyed signal.
func _demolish_at(world_pos: Vector2) -> void:
	var target_cell: Vector2i = _world_to_cell(world_pos)
	var hit: Node2D = _find_node_at_cell(target_cell)
	if hit == null:
		return
	var key: String = hit.get("building_key")
	var def: Dictionary = BuildingDatabase.get_definition(key)
	var cost: Dictionary = def.get("cost", {})
	var is_site: bool = hit.is_in_group("construction_sites")
	var refund_ratio: float = 1.0 if is_site else 0.5
	for r_name in cost.keys():
		var amount: float = float(cost[r_name]) * refund_ratio
		ResourceManager.add(r_name, amount)
	EventBus.building_destroyed.emit(key, target_cell)
	EventBus.log_message.emit(
		"Demolished %s. Refund: %d%%." % [def.get("display_name", key), int(refund_ratio * 100)],
		"build",
	)
	hit.queue_free()


func _find_node_at_cell(cell: Vector2i) -> Node2D:
	for n in get_tree().get_nodes_in_group("buildings"):
		var node := n as Node2D
		if node != null and _world_to_cell(node.global_position) == cell:
			return node
	for n in get_tree().get_nodes_in_group("construction_sites"):
		var node := n as Node2D
		if node != null and _world_to_cell(node.global_position) == cell:
			return node
	return null
