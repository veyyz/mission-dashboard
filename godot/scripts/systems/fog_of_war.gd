extends CanvasLayer
## Phase-8 placeholder fog-of-war. Renders a darkened overlay above the
## world but below the HUD; tracks "vision_source" group nodes (crew +
## probes) and clears the fog within their radius. The real WGSL/shader
## punch-through with soft falloff lands in Phase 10 polish — for Phase 8
## we just maintain a list of revealed grid cells and store them so
## later phases can drive a real shader off the same dataset.

const REVEAL_GRID_SIZE: int = 64  # iso world pixels per fog grid cell
const VISION_RADIUS: float = 200.0  # crew vision radius (probes carry their own)

var _revealed_cells: Dictionary = {}  # Vector2i → true


func _ready() -> void:
	visible = true
	# Hide the placeholder dim ColorRect under HUD, since we don't yet have
	# a real shader. Layer ordering is set in the .tscn (layer = 1 vs HUD's
	# default 0+ panels).


func _physics_process(_delta: float) -> void:
	# Sweep all vision sources and mark cells under their radius as revealed.
	for node in get_tree().get_nodes_in_group("vision_source"):
		var n: Node2D = node as Node2D
		if n == null:
			continue
		var radius: float = VISION_RADIUS
		if n.has_method("vision_radius"):
			radius = n.vision_radius()
		_reveal_radius(n.global_position, radius)


func _reveal_radius(world_pos: Vector2, radius: float) -> void:
	var cell_radius: int = int(ceil(radius / REVEAL_GRID_SIZE))
	var center_cell: Vector2i = Vector2i(
		int(world_pos.x / REVEAL_GRID_SIZE),
		int(world_pos.y / REVEAL_GRID_SIZE),
	)
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			if Vector2(dx, dy).length() <= cell_radius:
				_revealed_cells[center_cell + Vector2i(dx, dy)] = true


func is_revealed(world_pos: Vector2) -> bool:
	var cell: Vector2i = Vector2i(
		int(world_pos.x / REVEAL_GRID_SIZE),
		int(world_pos.y / REVEAL_GRID_SIZE),
	)
	return _revealed_cells.has(cell)


func revealed_count() -> int:
	return _revealed_cells.size()
