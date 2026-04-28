# Système de champ de vision (FOV) avec tir automatique
extends Node2D

signal target_in_fov(target: Node2D)
signal target_left_fov(target: Node2D)
signal visibility_polygon_updated(origin: Vector2, arc_points: PackedVector2Array)

## Angle du champ de vision en degrés
@export var fov_angle: float = 90.0

## Distance maximale de détection (pixels monde)
@export var fov_distance: float = 400.0

## Délai de tir (secondes)
@export var shoot_cooldown: float = 0.3

## Pas angulaire des raycasts (degrés) — plus petit = plus précis mais plus coûteux
@export var ray_step_degrees: float = 2.0

## Opacité de l'overlay sombre (0 = transparent, 1 = noir total)
@export var overlay_alpha: float = 0.85

## Masque de couche physique des murs (Layer 4 = valeur 8)
@export_flags_2d_physics var wall_layer_mask: int = 8

var _current_target: Node2D = null
var _shoot_timer: float = 0.0
var _player: CharacterBody2D

## Zombies actuellement dans le FOV
var targets_in_fov: Array[Node2D] = []
var _visibility_arc: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_player = get_parent()
	if not _player:
		push_error("FieldOfView doit être enfant du joueur")


func _process(delta: float) -> void:
	_shoot_timer -= delta
	_visibility_arc = _cast_visibility_polygon()
	visibility_polygon_updated.emit(_player.global_position, _visibility_arc)
	_update_fov()
	_find_closest_target()
	_try_shoot()
	queue_redraw()

## Lance des rayons dans le cône et retourne les points de collision (coordonnées monde)
func _cast_visibility_polygon() -> PackedVector2Array:
	if not _player:
		return PackedVector2Array()

	var aim_direction := _player.get_global_mouse_position() - _player.global_position
	if aim_direction.length_squared() < 0.001:
		return PackedVector2Array()

	var space_state := get_world_2d().direct_space_state
	var origin := _player.global_position
	var aim_angle := aim_direction.normalized().angle()
	var half_fov := deg_to_rad(fov_angle / 2.0)
	var step := deg_to_rad(ray_step_degrees)

	var arc := PackedVector2Array()
	var num_rays := int(ceil(fov_angle / ray_step_degrees)) + 1

	for i in range(num_rays):
		var angle := aim_angle - half_fov + i * step
		var dir := Vector2(cos(angle), sin(angle))
		var query := PhysicsRayQueryParameters2D.create(
			origin, origin + dir * fov_distance, wall_layer_mask
		)
		query.exclude = [_player.get_rid()]
		var result := space_state.intersect_ray(query)

		if result.is_empty():
			arc.append(origin + dir * fov_distance)
		else:
			arc.append(result.position)

	return arc


## Met à jour la liste des zombies dans le FOV
func _update_fov() -> void:
	var zombies = get_tree().get_nodes_in_group("zombies")
	var new_targets: Array[Node2D] = []

	for zombie in zombies:
		if not is_instance_valid(zombie):
			continue
		if _is_in_fov(zombie):
			new_targets.append(zombie)
			zombie.visible = true
			if zombie not in targets_in_fov:
				target_in_fov.emit(zombie)
		else:
			zombie.visible = false

	for zombie in targets_in_fov:
		if zombie not in new_targets:
			target_left_fov.emit(zombie)

	targets_in_fov = new_targets


func _is_in_fov(target: Node2D) -> bool:
	if not target or not _player:
		return false

	var to_target := target.global_position - _player.global_position
	var distance := to_target.length()

	if distance > fov_distance or distance < 1.0:
		return false

	var aim_direction := _player.get_global_mouse_position() - _player.global_position
	if aim_direction.length_squared() < 0.001:
		return false

	var aim_angle := aim_direction.normalized().angle()
	var target_angle := to_target.normalized().angle()
	var angle_diff := angle_difference(aim_angle, target_angle)

	if abs(angle_diff) > deg_to_rad(fov_angle / 2.0):
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		_player.global_position, target.global_position, wall_layer_mask
	)
	query.exclude = [_player.get_rid()]
	var result := space_state.intersect_ray(query)
	return result.is_empty()


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


## Tire en direction de la cible avec tous les pellets et spread de l'arme active
func _shoot_at_target(target: Node2D) -> void:
	var direction := (target.global_position - _player.global_position).normalized()
	if _player.has_method("_shoot_weapon_at"):
		_player._shoot_weapon_at(direction)
	elif _player.has_method("_shoot_at"):
		_player._shoot_at(direction)


## Retourne la cible actuelle
func get_current_target() -> Node2D:
	return _current_target


func _draw() -> void:
	if not _player or _visibility_arc.is_empty():
		return

	# Polygone en éventail avec gradient : centre lumineux → bords transparents
	var fan := PackedVector2Array()
	var colors := PackedColorArray()

	fan.append(Vector2.ZERO)
	colors.append(Color(1.0, 0.92, 0.65, 0.72))

	for world_point in _visibility_arc:
		fan.append(to_local(world_point))
		colors.append(Color(1.0, 0.85, 0.5, 0.0))

	draw_polygon(fan, colors)

	if _current_target and is_instance_valid(_current_target):
		_draw_target_indicator(_current_target)


func _draw_target_indicator(target: Node2D) -> void:
	var local_pos := to_local(target.global_position)
	var s := 5.0 / _player.scale.x
	var tip := local_pos + Vector2(0, -10.0 / _player.scale.x)
	var tri := PackedVector2Array([tip, tip + Vector2(-s, -s * 1.5), tip + Vector2(s, -s * 1.5)])
	draw_colored_polygon(tri, Color(1.0, 0.25, 0.25, 0.9))

