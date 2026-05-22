extends Node2D
## Draws an iso-aligned grid over the painted diamond. Cell coords from
## -MAP_RADIUS to +MAP_RADIUS, subdivided into STRATEGIC_DIVS segments
## (default 10 → 10×10 strategic grid matching A-J × 1-10 of the orbit
## map). Lives between TerrainOverlay and YSort so it draws over terrain
## but under crew/buildings.

const MAP_RADIUS: int = 72         # match ground.gd
const TILE_W: int = 64
const TILE_H: int = 32
const CELL_STEP: int = 6           # 1 line per N iso cells. Integer = perfect tile-edge alignment.
const LINE_COLOR: Color = Color(0.36, 0.71, 0.84, 0.45)
const LINE_WIDTH: float = 2.0


func _ready() -> void:
	z_as_relative = false
	queue_redraw()


func _draw() -> void:
	# Iso cell (a, b) → world (Diamond Down): ((a-b)*W/2, (a+b)*H/2).
	# Constant-a lines run along the cell-Y axis (from b=-R to b=+R).
	# Constant-b lines run along the cell-X axis (from a=-R to a=+R).
	# Stepping `a` and `b` by integer CELL_STEP guarantees every grid line
	# coincides with a real iso tile-edge.
	var a: int = -MAP_RADIUS
	while a <= MAP_RADIUS:
		var s: Vector2 = Vector2(
			(a - (-MAP_RADIUS)) * (TILE_W / 2.0),
			(a + (-MAP_RADIUS)) * (TILE_H / 2.0),
		)
		var e: Vector2 = Vector2(
			(a - MAP_RADIUS) * (TILE_W / 2.0),
			(a + MAP_RADIUS) * (TILE_H / 2.0),
		)
		draw_line(s, e, LINE_COLOR, LINE_WIDTH, true)
		a += CELL_STEP

	var b: int = -MAP_RADIUS
	while b <= MAP_RADIUS:
		var s2: Vector2 = Vector2(
			(-MAP_RADIUS - b) * (TILE_W / 2.0),
			(-MAP_RADIUS + b) * (TILE_H / 2.0),
		)
		var e2: Vector2 = Vector2(
			(MAP_RADIUS - b) * (TILE_W / 2.0),
			(MAP_RADIUS + b) * (TILE_H / 2.0),
		)
		draw_line(s2, e2, LINE_COLOR, LINE_WIDTH, true)
		b += CELL_STEP
