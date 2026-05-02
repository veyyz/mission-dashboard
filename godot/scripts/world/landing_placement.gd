class_name LandingPlacement
extends Node2D
## Phase-7 landing-ghost placement. Lives in world space (under YSort) so
## the cursor-following ghost shares the iso world transform.
##
## Pre-landing: shows a tilted amber landing-module ghost that snaps to
## iso cells under the cursor. Left-click confirms landing at the snapped
## cell, emits `EventBus.landing_confirmed(grid_pos)`, and self-deactivates.
## Mirrors the BuildPlacementController pattern.

const TILE_W: int = 64
const TILE_H: int = 32
const ISO_LEAN_RAD: float = 0.4636476
const PLACEHOLDER_SCALE: Vector2 = Vector2(4.0, 4.0)

var _ghost: Sprite2D = null
var _tile_layer: TileMapLayer = null
var _landed: bool = false


func _ready() -> void:
	# Find the world's iso TileMapLayer so we can snap to iso cells.
	var ground: Node = get_parent().get_parent()  # YSort → Ground
	if ground != null:
		_tile_layer = ground.find_child("TileMapLayer", true, false) as TileMapLayer
	_build_ghost()
	EventBus.landing_confirmed.connect(_on_landing_confirmed)


func _process(_delta: float) -> void:
	if _landed or _ghost == null:
		return
	_ghost.global_position = _snap(get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if _landed:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_confirm_at(get_global_mouse_position())
			get_viewport().set_input_as_handled()


## Public — tests call this to confirm a landing without simulating cursor.
func confirm_at(world_pos: Vector2) -> void:
	_confirm_at(world_pos)


func _confirm_at(world_pos: Vector2) -> void:
	if _landed:
		return
	var cell: Vector2i = _world_to_cell(world_pos)
	GameState.selected_landing_tile = cell
	EventBus.landing_confirmed.emit(cell)
	EventBus.log_message.emit("Landing confirmed at cell %s" % cell, "selection")


func _on_landing_confirmed(_cell: Vector2i) -> void:
	_landed = true
	if _ghost != null:
		_ghost.visible = false


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


func _build_ghost() -> void:
	_ghost = Sprite2D.new()
	_ghost.name = "LandingGhost"
	_ghost.modulate = Color(0.95, 0.71, 0.30, 0.55)
	_ghost.rotation = ISO_LEAN_RAD
	_ghost.scale = PLACEHOLDER_SCALE
	add_child(_ghost)
	_ghost.texture = _build_ghost_texture()


func _build_ghost_texture() -> Texture2D:
	var img := Image.create(48, 56, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Dome body.
	for y in range(20, 40):
		for x in range(8, 40):
			var dx: float = float(x - 24) / 18.0
			var dy: float = float(y - 30) / 12.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	# Landing legs.
	for y in range(36, 52):
		img.set_pixel(12, y, Color(1, 1, 1, 1))
		img.set_pixel(24, y, Color(1, 1, 1, 1))
		img.set_pixel(36, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
