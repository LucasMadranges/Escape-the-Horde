# Système de champ de vision (FOV) avec tir automatique
extends Node2D

signal target_in_fov(target: Node2D)
signal target_left_fov(target: Node2D)

## Angle du champ de vision en degrés
@export var fov_angle: float = 60.0

## Distance maximale de détection
@export var fov_distance: float = 300.0

## Délai de tir (secondes)
@export var shoot_cooldown: float = 0.3

var _current_target: Node2D = null
var _shoot_timer: float = 0.0
var _player: CharacterBody2D

## Zombies actuellement dans le FOV
var targets_in_fov: Array[Node2D] = []


func _ready() -> void:
	_player = get_parent()
	if not _player:
		push_error("FieldOfView doit être enfant du joueur")


func _process(delta: float) -> void:
	_shoot_timer -= delta
	_update_fov()
	_find_closest_target()
	_try_shoot()
	queue_redraw()  # Redessiner le cône chaque frame

## Met à jour la liste des zombies dans le FOV
func _update_fov() -> void:
	var zombies = get_tree().get_nodes_in_group("zombies")
	var new_targets: Array[Node2D] = []

	for zombie in zombies:
		if _is_in_fov(zombie):
			new_targets.append(zombie)
			if zombie not in targets_in_fov:
				target_in_fov.emit(zombie)

	# Vérifier les zombies qui ont quitté le FOV
	for zombie in targets_in_fov:
		if zombie not in new_targets:
			target_left_fov.emit(zombie)

	targets_in_fov = new_targets


## Vérifie si un zombie est dans le champ de vision
func _is_in_fov(target: Node2D) -> bool:
	if not target or not _player:
		return false

	var to_target = target.global_position - _player.global_position
	var distance = to_target.length()

	# Vérifier la distance
	if distance > fov_distance or distance < 1.0:
		return false

	# Vérifier l'angle
	var aim_direction = _player.get_global_mouse_position() - _player.global_position
	if aim_direction.length_squared() < 0.001:
		return false

	var aim_angle = aim_direction.normalized().angle()
	var target_angle = to_target.normalized().angle()
	var angle_diff = angle_difference(aim_angle, target_angle)

	return abs(angle_diff) <= deg_to_rad(fov_angle / 2.0)


## Calcule la différence d'angle (retourne une valeur entre -PI et PI)
func angle_difference(angle1: float, angle2: float) -> float:
	var diff = angle2 - angle1
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff


## Trouve la cible la plus proche dans le FOV
func _find_closest_target() -> void:
	if targets_in_fov.is_empty():
		_current_target = null
		return

	var closest: Node2D = null
	var min_distance = fov_distance + 1.0

	for target in targets_in_fov:
		if target and not target.is_queued_for_deletion():
			var distance = target.global_position.distance_to(_player.global_position)
			if distance < min_distance:
				min_distance = distance
				closest = target

	_current_target = closest


## Tire sur la cible actuelle si elle est en FOV
func _try_shoot() -> void:
	if _current_target == null or _shoot_timer > 0.0:
		return

	if _current_target.is_queued_for_deletion():
		_current_target = null
		return

	# Vérifier que la cible est toujours en FOV
	if _current_target not in targets_in_fov:
		_current_target = null
		return

	_shoot_at_target(_current_target)
	_shoot_timer = shoot_cooldown


## Tire en direction de la cible
func _shoot_at_target(target: Node2D) -> void:
	if not _player.has_method("_shoot"):
		push_error("Le joueur n'a pas de méthode _shoot")
		return

	# Sauvegarder la position actuelle de la souris
	var original_mouse_pos = _player.get_global_mouse_position()

	# Simuler un clic en changeant temporairement la position de la souris
	var target_pos = target.global_position
	_player.global_position  # Juste une référence pour éviter l'erreur

	# Appeler directement la fonction _shoot avec la direction
	var b = _player.bullet_scene.instantiate()
	b.direction = (target_pos - _player.global_position).normalized()
	b.global_position = _player.global_position
	var root = _player.get_parent()
	if root.has_node("Bullets"):
		root.get_node("Bullets").add_child(b)
	else:
		root.add_child(b)


## Retourne la cible actuelle
func get_current_target() -> Node2D:
	return _current_target


## Retourne l'angle du FOV
func get_fov_angle() -> float:
	return fov_angle


## Retourne la distance du FOV
func get_fov_distance() -> float:
	return fov_distance


## Visualise le champ de vision avec effet lampe de poche blanc chaud
func _draw() -> void:
	if not _player:
		return

	var aim_direction = _player.get_global_mouse_position() - _player.global_position
	if aim_direction.length_squared() < 0.001:
		return

	var aim_angle = aim_direction.normalized().angle()
	var half_fov = deg_to_rad(fov_angle / 2.0)

	# Effet lampe de poche blanc chaud : dessiner plusieurs couches avec alphas décroissants
	var layers = 5  # Nombre de couches pour le dégradé
	var angle_step = deg_to_rad(1.0)
	
	for layer in range(layers):
		var progress = float(layer) / float(layers)  # 0.0 à 1.0
		var current_distance = fov_distance * progress
		var alpha = 0.25 * (1.0 - progress)  # Décroît de 0.25 à 0
		
		# Couleur blanc chaud/orange (comme une lampe de poche)
		# Au centre : blanc chaud, aux bords : orange plus foncé
		var color_center = Color(1.0, 0.85, 0.4)  # Blanc chaud
		var color_edge = Color(0.8, 0.5, 0.2)    # Orange chaud
		var color = color_center.lerp(color_edge, progress)
		color.a = alpha
		
		if current_distance < 10.0:  # Éviter les polygones trop petits
			continue
		
		# Créer le polygone pour cette couche
		var points: PackedVector2Array = []
		points.append(Vector2.ZERO)
		
		var current_angle = aim_angle - half_fov
		var end_angle = aim_angle + half_fov
		
		while current_angle <= end_angle:
			points.append(Vector2(cos(current_angle), sin(current_angle)) * current_distance)
			current_angle += angle_step
		
		points.append(Vector2.ZERO)
		
		# Dessiner cette couche
		draw_colored_polygon(points, color)
	
	# Dessiner les limites du FOV en orange/blanc chaud
	var left_end = Vector2(cos(aim_angle - half_fov), sin(aim_angle - half_fov)) * fov_distance
	var right_end = Vector2(cos(aim_angle + half_fov), sin(aim_angle + half_fov)) * fov_distance
	
	var edge_color = Color(1.0, 0.85, 0.4)
	draw_line(Vector2.ZERO, left_end, edge_color, 2.0)
	draw_line(Vector2.ZERO, right_end, edge_color, 2.0)
	draw_line(left_end, right_end, edge_color, 2.0)

