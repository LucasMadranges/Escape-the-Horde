extends CharacterBody2D

signal died(zombie_id: String)
signal attack_player(player_id: String, damage: int)

const SPEED := 55.0
const MAX_HEALTH := 60
const SPRITE_SCALE := Vector2(4.0, 4.0)
const ATTACK_DAMAGE := 10
const ATTACK_COOLDOWN := 1.2
# Local units; effective range in pixels = ATTACK_RANGE * SPRITE_SCALE.x
const ATTACK_RANGE := 16.0

var health := MAX_HEALTH
var attack_timer := 0.0
var zombie_id := ""
var is_authoritative := true
var target_player_id := ""
var target_position := Vector2.ZERO
var network_position := Vector2.ZERO
var network_velocity := Vector2.ZERO
var has_network_state := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("zombies")
	scale = SPRITE_SCALE
	collision_layer = 2
	collision_mask = 1
	network_position = global_position
	_setup_animations()


func _setup_animations() -> void:
	var sf := SpriteFrames.new()
	sf.clear_all()
	_add_anim(sf, "idle_down", "res://assets/Enemies/Zombie_Small/Zombie_Small_Down_Idle-Sheet6.png", 6, 13, 16)
	_add_anim(sf, "walk_down", "res://assets/Enemies/Zombie_Small/Zombie_Small_Down_walk-Sheet6.png", 6, 12, 16)
	_add_anim(sf, "idle_side", "res://assets/Enemies/Zombie_Small/Zombie_Small_Side_Idle-Sheet6.png", 6, 11, 15)
	_add_anim(sf, "walk_side", "res://assets/Enemies/Zombie_Small/Zombie_Small_Side_Walk-Sheet6.png", 6, 13, 15)
	_add_anim(sf, "idle_up",   "res://assets/Enemies/Zombie_Small/Zombie_Small_Up_Idle-Sheet6.png",   6, 13, 15)
	_add_anim(sf, "walk_up",   "res://assets/Enemies/Zombie_Small/Zombie_Small_Up_Walk-Sheet6.png",   6, 13, 16)
	sprite.sprite_frames = sf
	sprite.play("walk_down")


func _add_anim(sf: SpriteFrames, anim: String, path: String, n: int, fw: int, fh: int, fps := 6.0) -> void:
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
	if is_authoritative:
		_process_authoritative(delta)
	else:
		_process_replica(delta)


func _process_authoritative(delta: float) -> void:
	if target_player_id.is_empty():
		velocity = Vector2.ZERO
		return

	var to_player := target_position - global_position
	var dir := to_player.normalized()
	velocity = dir * SPEED
	move_and_slide()
	_update_animation(dir)

	attack_timer -= delta
	if to_player.length() < ATTACK_RANGE * SPRITE_SCALE.x and attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN
		emit_signal("attack_player", target_player_id, ATTACK_DAMAGE)


func _process_replica(delta: float) -> void:
	if not has_network_state:
		return

	global_position = global_position.lerp(network_position, clampf(delta * 14.0, 0.0, 1.0))
	velocity = network_velocity

	var dir := network_velocity.normalized()
	if dir.length_squared() > 0.001:
		_update_animation(dir)


func _update_animation(dir: Vector2) -> void:
	var angle := dir.angle()
	if abs(angle) < PI * 0.25:
		sprite.flip_h = false
		sprite.play("walk_side")
	elif abs(angle) > PI * 0.75:
		sprite.flip_h = true
		sprite.play("walk_side")
	elif angle > 0.0:
		sprite.play("walk_down")
	else:
		sprite.play("walk_up")


func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color(1.0, 0.3, 0.3)
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(self): modulate = Color.WHITE)
	if health <= 0:
		emit_signal("died", zombie_id)
		queue_free()


func set_authoritative(value: bool) -> void:
	is_authoritative = value
	if is_authoritative:
		has_network_state = false


func set_target(player_id: String, target_pos: Vector2) -> void:
	target_player_id = player_id
	target_position = target_pos


func apply_network_state(net_pos: Vector2, velocity_state: Vector2, target_id: String) -> void:
	network_position = net_pos
	network_velocity = velocity_state
	target_player_id = target_id
	has_network_state = true


func get_target_player_id() -> String:
	return target_player_id
