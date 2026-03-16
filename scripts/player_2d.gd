extends CharacterBody2D

const SPEED := 220.0
const MAX_HEALTH := 100
const SPRITE_SCALE := Vector2(4.0, 4.0)
const ARENA_HALF := Vector2(1100.0, 800.0)

var health := MAX_HEALTH
var bullet_scene := preload("res://scenes/bullet.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	scale = SPRITE_SCALE
	collision_layer = 1
	collision_mask = 2
	_setup_animations()
	_setup_light()


func _setup_light() -> void:
	var light := PointLight2D.new()
	light.texture = _make_radial_texture(96)
	light.texture_scale = 3.2
	light.energy = 0.95
	light.color = Color(1.0, 0.92, 0.75)
	add_child(light)


func _make_radial_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	var r: float = size * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x, y).distance_to(c)
			var a: float = clampf(1.0 - d / r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _setup_animations() -> void:
	var sf := SpriteFrames.new()
	sf.clear_all()
	_add_anim(sf, "idle_down", "res://assets/Character/Main/Idle/Character_down_idle-Sheet6.png", 6, 13, 16)
	_add_anim(sf, "run_down",  "res://assets/Character/Main/Run/Character_down_run-Sheet6.png",   6, 13, 17)
	_add_anim(sf, "idle_side", "res://assets/Character/Main/Idle/Character_side_idle-Sheet6.png", 6, 12, 16)
	_add_anim(sf, "run_side",  "res://assets/Character/Main/Run/Character_side_run-Sheet6.png",   6, 14, 17)
	_add_anim(sf, "idle_up",   "res://assets/Character/Main/Idle/Character_up_idle-Sheet6.png",   6, 11, 16)
	_add_anim(sf, "run_up",    "res://assets/Character/Main/Run/Character_up_run-Sheet6.png",     6, 13, 17)
	sprite.sprite_frames = sf
	sprite.play("idle_down")


func _add_anim(sf: SpriteFrames, anim: String, path: String, n: int, fw: int, fh: int, fps := 8.0) -> void:
	var tex := load(path) as Texture2D
	if not tex:
		return
	sf.add_animation(anim)
	sf.set_animation_loop(anim, true)
	sf.set_animation_speed(anim, fps)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, at)


func _physics_process(delta: float) -> void:
	var dir := _get_input()
	velocity = dir * SPEED
	move_and_slide()
	global_position = global_position.clamp(-ARENA_HALF, ARENA_HALF)
	_update_animation(dir)


func _get_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		v.x += 1.0
	return v.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
			_shoot()


func _shoot() -> void:
	var b := bullet_scene.instantiate()
	var mouse_world := get_global_mouse_position()
	b.direction = (mouse_world - global_position).normalized()
	b.global_position = global_position
	var root := get_parent()
	if root.has_node("Bullets"):
		root.get_node("Bullets").add_child(b)
	else:
		root.add_child(b)


func _update_animation(move_dir: Vector2) -> void:
	var aim := get_global_mouse_position() - global_position
	var angle := aim.angle()
	var moving := move_dir.length_squared() > 0.01

	if abs(angle) < PI * 0.25:
		sprite.flip_h = false
		sprite.play("run_side" if moving else "idle_side")
	elif abs(angle) > PI * 0.75:
		sprite.flip_h = true
		sprite.play("run_side" if moving else "idle_side")
	elif angle > 0.0:
		sprite.flip_h = false
		sprite.play("run_down" if moving else "idle_down")
	else:
		sprite.flip_h = false
		sprite.play("run_up" if moving else "idle_up")


func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color(1, 0.2, 0.2)
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_instance_valid(self): modulate = Color.WHITE)
	if health <= 0:
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
