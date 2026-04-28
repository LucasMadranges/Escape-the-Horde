extends Node2D

const SHADER := preload("res://shaders/fov_overlay.gdshader")

var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
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
	_material.set_shader_parameter("player_screen_pos", screen_origin)

	var count := arc_points.size()

	# Aim direction from the middle arc point (center of the beam)
	if count >= 3:
		var mid_screen := canvas_transform * arc_points[count / 2]
		var to_mid := mid_screen - screen_origin
		if to_mid.length_squared() > 0.001:
			_material.set_shader_parameter("aim_dir", to_mid.normalized())

	# Screen-space cone radius from average of first and last arc endpoints
	if count >= 2:
		var r0 := (canvas_transform * arc_points[0] - screen_origin).length()
		var r1 := (canvas_transform * arc_points[count - 1] - screen_origin).length()
		_material.set_shader_parameter("fov_screen_radius", (r0 + r1) * 0.5)


func get_shader_material() -> ShaderMaterial:
	return _material
