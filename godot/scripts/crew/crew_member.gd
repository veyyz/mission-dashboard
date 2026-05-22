class_name CrewMember
extends CharacterBody2D
## Phase-4 crew. Roles, role-tinted placeholder sprites, NavigationAgent2D for
## click-to-move, WASD when selected, glow ring under feet to show selection.
## Real character art swaps in once `art_queue.characters[*].status` flips to
## ready (handled by the per-phase art swap-in pass).

enum Role {
	ENGINEER,
	SCIENTIST,
	BOTANIST,
	GEOLOGIST,
	MEDIC,
	COMMANDER,
}

const ROLE_COLOR := {
	Role.ENGINEER:  Color(0.36, 0.71, 0.84),  # cyan
	Role.SCIENTIST: Color(0.66, 0.45, 0.85),  # purple
	Role.BOTANIST:  Color(0.45, 0.78, 0.50),  # muted green
	Role.GEOLOGIST: Color(0.95, 0.71, 0.30),  # amber
	Role.MEDIC:     Color(0.92, 0.40, 0.45),  # red
	Role.COMMANDER: Color(0.95, 0.85, 0.45),  # gold
}

const ROLE_LABEL := {
	Role.ENGINEER:  "Engineer",
	Role.SCIENTIST: "Scientist",
	Role.BOTANIST:  "Botanist",
	Role.GEOLOGIST: "Geologist",
	Role.MEDIC:     "Medic",
	Role.COMMANDER: "Commander",
}

const CREW_SPRITE_ROOT := "res://assets/sprites/crew/"
const CREW_FOLDER := {
	Role.ENGINEER:  "alex",
	Role.SCIENTIST: "maya",
	Role.BOTANIST:  "zane",
	Role.GEOLOGIST: "rin",
	Role.MEDIC:     "medic",
	Role.COMMANDER: "commander",
}

const SPEED: float = 140.0
const ARRIVAL_DISTANCE: float = 4.0

# 8-way folder names indexed by atan2 wedge (Godot screen-space: y is down,
# angle 0 = +x = east, angle PI/2 = +y = south).
const DIRS := ["east", "south-east", "south", "south-west",
               "west", "north-west", "north", "north-east"]
const WALKING_FPS: float = 8.0

@export var crew_name: String = "Alex"
@export var crew_id: int = 1
@export var role: Role = Role.ENGINEER
@export_range(0, 100) var role_skill: int = 80

@export var max_health: int = 100
@export var max_stamina: int = 100

var current_health: int
var current_stamina: int
var current_oxygen: float = 100.0
var selected: bool = false

# Follow-the-leader: when multi-crew move issued, the first selected becomes
# the leader and pathfinds to the target. Followers track the leader's
# position + a stored offset, recomputed every physics frame so the squad
# maintains formation as the leader walks.
var follow_leader: CrewMember = null
var follow_offset: Vector2 = Vector2.ZERO

var _last_dir: String = "south"
var _use_animated: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_ring: Sprite2D = $SelectionRing
@onready var nameplate: Label = $Nameplate
@onready var agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina

	# ConstructionSite uses get_nodes_in_group("crew") to find adjacent engineers.
	add_to_group("crew")
	# FogOfWar reveals tiles within VISION_RADIUS of any "vision_source" each frame.
	add_to_group("vision_source")

	var sf := _build_sprite_frames()
	if sf != null:
		anim_sprite.sprite_frames = sf
		# Real 180x180 canvas with character feet near bottom. Anchor feet to
		# body origin so y-sort matches the visible feet (consistent with
		# buildings, otherwise crew renders behind same-feet-y objects).
		var first_tex: Texture2D = sf.get_frame_texture("idle_south", 0)
		if first_tex != null:
			anim_sprite.offset = Vector2(0, -first_tex.get_height() / 2)
		anim_sprite.play("idle_%s" % _last_dir)
		anim_sprite.visible = true
		sprite.visible = false
		_use_animated = true
	else:
		if sprite.texture == null:
			sprite.texture = _build_placeholder_texture()
		sprite.visible = true
		anim_sprite.visible = false
		_use_animated = false
	if selection_ring.texture == null:
		selection_ring.texture = _build_selection_ring_texture()
	selection_ring.visible = false
	_apply_nameplate()


func _physics_process(_delta: float) -> void:
	# Follow-the-leader: re-target leader's current position each frame so
	# followers track a moving leader.
	if follow_leader != null and is_instance_valid(follow_leader) and follow_leader != self:
		move_to(follow_leader.global_position + follow_offset)

	var move := Vector2.ZERO
	var navigating: bool = (
		agent.target_position != Vector2.ZERO
		and not agent.is_navigation_finished()
	)
	if navigating:
		var next_pos: Vector2 = agent.get_next_path_position()
		var to_next: Vector2 = next_pos - global_position
		if to_next.length() > ARRIVAL_DISTANCE:
			move = to_next.normalized() * SPEED
	elif selected:
		var dir := Vector2.ZERO
		if Input.is_action_pressed("move_up"):    dir.y -= 1.0
		if Input.is_action_pressed("move_down"):  dir.y += 1.0
		if Input.is_action_pressed("move_left"):  dir.x -= 1.0
		if Input.is_action_pressed("move_right"): dir.x += 1.0
		if dir != Vector2.ZERO:
			move = dir.normalized() * SPEED
	velocity = move
	move_and_slide()

	if _use_animated:
		var moving: bool = velocity.length() > 1.0
		var dir_name := _vel_to_dir(velocity, moving)
		var action := "walking" if moving else "idle"
		var anim := "%s_%s" % [action, dir_name]
		if anim_sprite.animation != anim:
			anim_sprite.play(anim)
		_last_dir = dir_name


func move_to(target: Vector2) -> void:
	agent.target_position = target


func follow(leader: CrewMember, offset: Vector2) -> void:
	follow_leader = leader
	follow_offset = offset


func clear_follow() -> void:
	follow_leader = null
	follow_offset = Vector2.ZERO


func set_selected(value: bool) -> void:
	selected = value
	if selection_ring != null:
		selection_ring.visible = value


func _apply_nameplate() -> void:
	if nameplate == null:
		return
	nameplate.text = "%s %d" % [crew_name, role_skill]
	nameplate.add_theme_color_override("font_color", ROLE_COLOR.get(role, Color(0.91, 0.93, 0.95)))
	nameplate.add_theme_color_override("font_outline_color", Color(0.07, 0.09, 0.12))
	nameplate.add_theme_constant_override("outline_size", 4)


func _load_crew_texture() -> Texture2D:
	var folder: String = CREW_FOLDER.get(role, "")
	if folder == "":
		return null
	var path := "%s%s/rotations/south.png" % [CREW_SPRITE_ROOT, folder]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _build_sprite_frames() -> SpriteFrames:
	var folder: String = CREW_FOLDER.get(role, "")
	if folder == "":
		return null
	var base := "%s%s/" % [CREW_SPRITE_ROOT, folder]
	# Cheap existence probe — if south rotation absent, no folder yet.
	if not ResourceLoader.exists("%srotations/south.png" % base):
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for d in DIRS:
		var idle := "idle_%s" % d
		sf.add_animation(idle)
		sf.set_animation_loop(idle, true)
		var rot_path := "%srotations/%s.png" % [base, d]
		if ResourceLoader.exists(rot_path):
			sf.add_frame(idle, load(rot_path))

		var walk := "walking_%s" % d
		sf.add_animation(walk)
		sf.set_animation_loop(walk, true)
		sf.set_animation_speed(walk, WALKING_FPS)
		for i in range(6):
			var f := "%sanimations/walking/%s/frame_%03d.png" % [base, d, i]
			if ResourceLoader.exists(f):
				sf.add_frame(walk, load(f))
	return sf


func _vel_to_dir(v: Vector2, moving: bool) -> String:
	if not moving:
		return _last_dir
	# Godot screen-space: angle 0 = east, +PI/2 = south (y-down).
	var idx: int = int(round(v.angle() / (PI / 4.0)))
	if idx < 0:
		idx += 8
	return DIRS[idx % 8]


func _build_placeholder_texture() -> Texture2D:
	var img := Image.create(20, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var role_c: Color = ROLE_COLOR.get(role, Color(0.36, 0.71, 0.84))
	var suit: Color = role_c.lerp(Color(0.91, 0.93, 0.95), 0.55)
	for y in range(2, 26):
		for x in range(2, 18):
			img.set_pixel(x, y, suit)
	# Visor band — saturated role color
	for y in range(5, 11):
		for x in range(4, 16):
			img.set_pixel(x, y, role_c)
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


func _build_selection_ring_texture() -> Texture2D:
	var img := Image.create(40, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(0, 24):
		for x in range(0, 40):
			var dx: float = float(x - 20) / 18.0
			var dy: float = float(y - 12) / 10.0
			var d: float = dx * dx + dy * dy
			if d <= 1.0 and d >= 0.55:
				var alpha: float = 0.85 * (1.0 - abs(d - 0.78) * 4.0)
				img.set_pixel(x, y, Color(0.36, 0.71, 0.84, clampf(alpha, 0.0, 0.85)))
	return ImageTexture.create_from_image(img)
