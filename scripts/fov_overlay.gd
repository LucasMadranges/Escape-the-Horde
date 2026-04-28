extends Node2D

const SHADER := preload("res://shaders/fov_overlay.gdshader")
const MAX_ARC_POINTS := 128

var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("arc_count", 0)
	_material.set_shader_parameter("overlay_alpha", 0.85)
	_material.set_shader_parameter("aim_dir", Vector2(1.0, 0.0))
	_material.set_shader_parameter("fov_screen_radius", 280.0)
	_material.set_shader_parameter("fov_half_cos", 0.707)


func set_fov_params(fov_angle_deg: float) -> void:
	if _material:
		_material.set_shader_parameter("fov_half_cos", cos(deg_to_rad(fov_angle_deg * 0.5)))


func on_visibility_polygon_updated(origin: Vector2, arc_points: PackedVector2Array) -> void:
	if not _material:
		return

	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_origin := canvas_transform * origin

	var count := mini(arc_points.size(), MAX_ARC_POINTS)
	var screen_arc: Array[Vector2] = []
	for i in range(count):
		screen_arc.append(canvas_transform * arc_points[i])

	var last := screen_arc[-1] if screen_arc.size() > 0 else screen_origin
	while screen_arc.size() < MAX_ARC_POINTS:
		screen_arc.append(last)

	_material.set_shader_parameter("player_screen_pos", screen_origin)
	_material.set_shader_parameter("arc_points", screen_arc)
	_material.set_shader_parameter("arc_count", count)

	# Compute aim direction from the middle arc point (points toward center of cone)
	if count >= 3:
		var mid_screen: Vector2 = screen_arc[count / 2]
		var to_mid := mid_screen - screen_origin
		if to_mid.length_squared() > 0.001:
			_material.set_shader_parameter("aim_dir", to_mid.normalized())

	# Compute average screen-space cone radius from first and last arc endpoints
	if count >= 2:
		var r0 := (screen_arc[0] - screen_origin).length()
		var r1 := (screen_arc[count - 1] - screen_origin).length()
		_material.set_shader_parameter("fov_screen_radius", (r0 + r1) * 0.5)

	# fov_half_cos passed from FieldOfView via set_fov_params



func get_shader_material() -> ShaderMaterial:
	return _material
