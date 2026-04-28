extends Area2D

const LIFETIME := 3.0

var direction := Vector2.RIGHT
var speed := 480.0
var damage := 25
var is_remote := false
var weapon_type: String = "pistol"
var _lifetime := LIFETIME


func _ready() -> void:
	if is_remote:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 8
		collision_mask = 2
	body_entered.connect(_on_body_hit)
	# Rotate node so local X axis aligns with travel direction → _draw() uses (1,0) as forward
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	# All drawing in local space — forward is Vector2(1, 0) because node is rotated
	var fwd := Vector2(1.0, 0.0)

	var trail_len: float
	var bullet_len: float
	var bullet_w: float
	var core_col: Color
	var glow_col: Color
	var trail_col: Color

	match weapon_type:
		"rifle":
			trail_len  = 36.0
			bullet_len = 10.0
			bullet_w   = 1.6
			core_col   = Color(1.00, 1.00, 0.95, 1.0)
			glow_col   = Color(0.80, 0.95, 1.00, 0.20)
			trail_col  = Color(0.70, 0.90, 1.00, 0.55)
		"shotgun":
			trail_len  = 7.0
			bullet_len = 4.0
			bullet_w   = 2.4
			core_col   = Color(1.00, 0.65, 0.20, 1.0)
			glow_col   = Color(1.00, 0.50, 0.15, 0.22)
			trail_col  = Color(1.00, 0.40, 0.10, 0.40)
		_: # pistol
			trail_len  = 20.0
			bullet_len = 7.0
			bullet_w   = 1.8
			core_col   = Color(1.00, 0.96, 0.45, 1.0)
			glow_col   = Color(1.00, 0.88, 0.25, 0.22)
			trail_col  = Color(1.00, 0.75, 0.15, 0.50)

	var nose := fwd * bullet_len * 0.55
	var tail_end := -fwd * bullet_len * 0.45

	# Traînée lumineuse (fondue vers l'arrière)
	draw_line(Vector2.ZERO, -fwd * trail_len, trail_col, bullet_w * 0.65)

	# Halo doux autour du projectile
	draw_circle(Vector2.ZERO, bullet_w * 3.2, glow_col)

	# Corps principal de la balle (capsule via ligne épaisse avec caps arrondis)
	draw_line(tail_end, nose, core_col, bullet_w)

	# Éclat blanc sur la pointe
	draw_circle(nose, bullet_w * 0.55, Color(1.0, 1.0, 1.0, 0.9))


func _on_body_hit(body: Node2D) -> void:
	if body.is_in_group("zombies"):
		body.take_damage(damage)
		_spawn_impact(body.global_position)
		queue_free()


func _spawn_impact(pos: Vector2) -> void:
	var sparks := CPUParticles2D.new()
	sparks.global_position = pos
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.lifetime = 0.22
	sparks.amount = 8
	sparks.spread = 60.0
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 130.0
	sparks.gravity = Vector2.ZERO
	sparks.scale_amount_min = 1.2
	sparks.scale_amount_max = 2.0
	sparks.color = Color(1.0, 0.85, 0.3, 1.0)

	match weapon_type:
		"shotgun":
			sparks.amount = 10
			sparks.initial_velocity_max = 90.0
			sparks.color = Color(1.0, 0.55, 0.15, 1.0)
		"rifle":
			sparks.amount = 6
			sparks.initial_velocity_max = 180.0
			sparks.color = Color(0.7, 0.95, 1.0, 1.0)

	get_parent().add_child(sparks)
	# Auto-cleanup après fin de l'émission
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(sparks):
			sparks.queue_free()
	)
