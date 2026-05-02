class_name ResourceNode
extends Node2D
## Phase-8 deposit node. Sits on the iso ground; starts undiscovered (faint
## tint, name hidden). `reveal()` flips it to discovered when a crew Scan
## (R) sweeps within radius. `collect_one()` decrements `amount` and emits
## `EventBus.sample_collected`.

@export var deposit_type: String = "iron"
@export var amount: int = 5

const SAMPLE_RANGE: float = 80.0  # crew must be within this to G-collect

var discovered: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("resource_node")
	_apply_screen_upright()
	if sprite.texture == null:
		sprite.texture = _build_placeholder()
	_refresh()


func reveal() -> void:
	if discovered:
		return
	discovered = true
	_refresh()
	EventBus.log_message.emit("Discovered %s deposit" % deposit_type, "selection")


func can_be_sampled_by(crew_pos: Vector2) -> bool:
	return discovered and amount > 0 and global_position.distance_to(crew_pos) <= SAMPLE_RANGE


func collect_one() -> bool:
	if amount <= 0:
		return false
	amount -= 1
	_refresh()
	ResourceManager.add("samples", 1.0)
	EventBus.sample_collected.emit(deposit_type, _grid_pos())
	return true


func _grid_pos() -> Vector2i:
	return Vector2i(int(global_position.x / 64.0), int(global_position.y / 32.0))


func _refresh() -> void:
	if discovered:
		modulate = Color(1, 1, 1, 1)
		label.text = "%s (%d)" % [deposit_type, amount]
		label.visible = true
	else:
		modulate = Color(0.5, 0.5, 0.55, 0.45)
		label.visible = false


func _apply_screen_upright() -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world is Node2D:
		rotation = -(world as Node2D).rotation


func _build_placeholder() -> Texture2D:
	const TYPE_COLOR := {
		"water_ice":   Color(0.36, 0.81, 0.95),
		"helium3":     Color(0.66, 0.45, 0.85),
		"iron":        Color(0.85, 0.45, 0.40),
		"titanium":    Color(0.55, 0.75, 0.85),
		"silicon":     Color(0.50, 0.85, 0.55),
		"rare_metals": Color(0.95, 0.71, 0.30),
	}
	var c: Color = TYPE_COLOR.get(deposit_type, Color(0.7, 0.7, 0.75))
	var img := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(24):
		for x in range(32):
			var dx: float = float(x - 16) / 14.0
			var dy: float = float(y - 12) / 10.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
