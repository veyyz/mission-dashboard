class_name CrewMember
extends CharacterBody2D
## Phase-2 controllable crew. WASD via InputMap actions registered in
## GameState._setup_input_map(). Roles, nameplates, and selection arrive in
## Phase 4 — keep this minimal until then.

const SPEED: float = 140.0

@export var crew_name: String = "Alex"
@export var role_color: Color = Color(0.36, 0.71, 0.84)  # cyan placeholder

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = _build_placeholder_texture()


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1.0
	if Input.is_action_pressed("move_down"):  dir.y += 1.0
	if Input.is_action_pressed("move_left"):  dir.x -= 1.0
	if Input.is_action_pressed("move_right"): dir.x += 1.0
	if dir != Vector2.ZERO:
		velocity = dir.normalized() * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()


## A 20x28 astronaut silhouette so Phase 2 has something to look at while
## the Pixellab character art finishes generating in the background.
func _build_placeholder_texture() -> Texture2D:
	var img := Image.create(20, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Suit body
	for y in range(2, 26):
		for x in range(2, 18):
			img.set_pixel(x, y, Color(0.91, 0.93, 0.95))
	# Visor band
	for y in range(5, 11):
		for x in range(4, 16):
			img.set_pixel(x, y, role_color)
	# Belt
	for x in range(2, 18):
		img.set_pixel(x, 17, Color(0.18, 0.22, 0.28))
	# Outline
	for y in range(2, 26):
		img.set_pixel(1, y, Color(0.07, 0.09, 0.12))
		img.set_pixel(18, y, Color(0.07, 0.09, 0.12))
	for x in range(2, 18):
		img.set_pixel(x, 1, Color(0.07, 0.09, 0.12))
		img.set_pixel(x, 26, Color(0.07, 0.09, 0.12))
	return ImageTexture.create_from_image(img)
