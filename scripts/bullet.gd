extends Area2D

const LIFETIME := 3.0

var direction := Vector2.RIGHT
var speed := 480.0
var damage := 25
var is_remote := false
var _lifetime := LIFETIME


func _ready() -> void:
	if is_remote:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 8
		collision_mask = 2
	body_entered.connect(_on_body_hit)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.95, 0.5))
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)


func _on_body_hit(body: Node2D) -> void:
	if body.is_in_group("zombies"):
		body.take_damage(damage)
		queue_free()
