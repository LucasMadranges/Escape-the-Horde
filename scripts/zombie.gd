extends CharacterBody2D

const SPEED := 55.0
const MAX_HEALTH := 60
const SPRITE_SCALE := Vector2(4.0, 4.0)
const ATTACK_DAMAGE := 10
const ATTACK_COOLDOWN := 1.2
# Local units; effective range in pixels = ATTACK_RANGE * SPRITE_SCALE.x
const ATTACK_RANGE := 16.0

var health := MAX_HEALTH
var attack_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("zombies")
	scale = SPRITE_SCALE
	collision_layer = 2
	collision_mask = 1
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
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return

	var to_player := player.global_position - global_position
	var dir := to_player.normalized()
	velocity = dir * SPEED
	move_and_slide()
	_update_animation(dir)

	attack_timer -= delta
	if to_player.length() < ATTACK_RANGE * SPRITE_SCALE.x and attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN
		if player.has_method("take_damage"):
			player.take_damage(ATTACK_DAMAGE)


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
		queue_free()
