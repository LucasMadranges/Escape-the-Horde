extends Node2D

const SHADER := preload("res://shaders/fov_overlay.gdshader")
const MAX_ARC_POINTS := 128

var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("arc_count", 0)
	_material.set_shader_parameter("overlay_alpha", 0.85)


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


func get_shader_material() -> ShaderMaterial:
	return _material
