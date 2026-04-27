extends CharacterBody2D

const SPEED := 220.0
const MAX_HEALTH := 100
const SPRITE_SCALE := Vector2(4.0, 4.0)
const ARENA_HALF := Vector2(1100.0, 800.0)
const PLAYER_STATUS_CONTROLLER_SCRIPT := preload("res://scripts/game/player/player_status_controller.gd")
const FIELD_OF_VIEW_SCRIPT := preload("res://scripts/field_of_view.gd")
const FOV_OVERLAY_SCRIPT := preload("res://scripts/fov_overlay.gd")

var health := MAX_HEALTH
var life_state_name := "alive"
var bullet_scene := preload("res://scenes/bullet.tscn")
var status_controller: Node
var field_of_view: Node2D
var _fov_canvas_layer: CanvasLayer

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	scale = SPRITE_SCALE
	collision_layer = 1
	collision_mask = 2
	_setup_animations()
	_setup_light()

	status_controller = PLAYER_STATUS_CONTROLLER_SCRIPT.new()
	status_controller.name = "PlayerStatusController"
	add_child(status_controller)
	if status_controller.has_method("setup"):
		status_controller.setup(self, camera, MAX_HEALTH)

	# Initialiser le système de champ de vision (détection + tir automatique)
	field_of_view = FIELD_OF_VIEW_SCRIPT.new()
	field_of_view.name = "FieldOfView"
	field_of_view.fov_angle = 90.0
	field_of_view.fov_distance = 400.0
	field_of_view.shoot_cooldown = 0.3
	add_child(field_of_view)

	_fov_canvas_layer = CanvasLayer.new()
	_fov_canvas_layer.layer = 10
	get_parent().add_child(_fov_canvas_layer)

	var fov_overlay := FOV_OVERLAY_SCRIPT.new()
	fov_overlay.name = "FovOverlay"
	_fov_canvas_layer.add_child(fov_overlay)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = fov_overlay.get_shader_material()
	_fov_canvas_layer.add_child(rect)

	field_of_view.visibility_polygon_updated.connect(
		func(origin: Vector2, arc: PackedVector2Array) -> void:
			fov_overlay.on_visibility_polygon_updated(origin, arc)
	)


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
	if status_controller and status_controller.has_method("allows_player_control") and not bool(status_controller.allows_player_control()):
		velocity = Vector2.ZERO
		if status_controller.has_method("physics_update"):
			status_controller.physics_update(delta)
		return

	var dir := _get_input()
	velocity = dir * SPEED
	move_and_slide()
	global_position = global_position.clamp(-ARENA_HALF, ARENA_HALF)
	_update_animation(dir)


func _process(delta: float) -> void:
	if status_controller and status_controller.has_method("process_update"):
		status_controller.process_update(delta)


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
	if status_controller and status_controller.has_method("blocks_input") and bool(status_controller.blocks_input()):
		return

	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
			_shoot()


func _shoot() -> void:
	var mouse_world := get_global_mouse_position()
	_shoot_at((mouse_world - global_position).normalized())


func _shoot_at(direction: Vector2) -> void:
	var b := bullet_scene.instantiate()
	b.direction = direction
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
	if status_controller and status_controller.has_method("apply_damage"):
		status_controller.apply_damage(amount)
		return

	health = max(0, health - amount)
