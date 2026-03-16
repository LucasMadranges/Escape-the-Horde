extends CharacterBody3D

@export var speed = 5.0
@export var jump_force = 10.0
@export var gravity = 9.8

var is_jumping = false

func _physics_process(delta):
	# Récupérer l'entrée du joueur
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Appliquer la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("ui_accept"):
			velocity.y = jump_force
	
	# Mouvement horizontal
	var direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Appliquer le mouvement
	move_and_slide()
