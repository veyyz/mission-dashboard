extends Sprite2D
## Maps the terrain rectangle to the iso diamond, with rotation + scale +
## shear applied to image-local coords before the iso projection.
##
## Final transform = iso_baseline * rotation * scale * shear
##
## Tree order between TileMapLayer and YSort: terrain draws OVER tiles
## and UNDER crew/buildings/props.

const HALF_DIAG_X: float = 4608.0
const HALF_DIAG_Y: float = 2304.0

# Defaults baked from in-game tuning session (terrain_xl).
const DEFAULT_ROTATION_DEG: float = 313.0
const DEFAULT_SCALE_X: float = 1.42
const DEFAULT_SCALE_Y: float = 2.08
const DEFAULT_SHEAR_X: float = 0.03
const DEFAULT_SHEAR_Y: float = 0.04
const DEFAULT_OPACITY: float = 1.0

var _rotation_deg: float = DEFAULT_ROTATION_DEG
var _scale_x: float = DEFAULT_SCALE_X
var _scale_y: float = DEFAULT_SCALE_Y
var _shear_x: float = DEFAULT_SHEAR_X
var _shear_y: float = DEFAULT_SHEAR_Y
var _opacity: float = DEFAULT_OPACITY


func _ready() -> void:
	add_to_group("terrain_overlay")
	modulate.a = _opacity
	_rebuild()


func set_rotation_cw_deg(v: float) -> void:
	_rotation_deg = v
	_rebuild()


func set_scale_x(v: float) -> void:
	_scale_x = v
	_rebuild()


func set_scale_y(v: float) -> void:
	_scale_y = v
	_rebuild()


func set_shear_x(v: float) -> void:
	_shear_x = v
	_rebuild()


func set_shear_y(v: float) -> void:
	_shear_y = v
	_rebuild()


func set_opacity(v: float) -> void:
	_opacity = clampf(v, 0.0, 1.0)
	modulate.a = _opacity


func current_rotation_deg() -> float: return _rotation_deg
func current_scale_x() -> float: return _scale_x
func current_scale_y() -> float: return _scale_y
func current_shear_x() -> float: return _shear_x
func current_shear_y() -> float: return _shear_y
func current_opacity() -> float: return _opacity


func _rebuild() -> void:
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var iso_baseline := Transform2D(
		Vector2(HALF_DIAG_X / tex_size.x, HALF_DIAG_Y / tex_size.x),
		Vector2(-HALF_DIAG_X / tex_size.y, HALF_DIAG_Y / tex_size.y),
		Vector2.ZERO,
	)
	var rot := Transform2D(deg_to_rad(_rotation_deg), Vector2.ZERO)
	var scale_m := Transform2D(
		Vector2(_scale_x, 0.0),
		Vector2(0.0, _scale_y),
		Vector2.ZERO,
	)
	var shear := Transform2D(
		Vector2(1.0, _shear_y),
		Vector2(_shear_x, 1.0),
		Vector2.ZERO,
	)
	transform = iso_baseline * rot * scale_m * shear
