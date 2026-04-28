extends Node2D

const ARENA_BOUNDS_LAYER := 1


func _ready() -> void:
	_setup_atmosphere()
	_connect_arena_bounds_to_player()


func _connect_arena_bounds_to_player() -> void:
	var arena_body := get_node_or_null("Area/StaticBody2D") as StaticBody2D
	if arena_body:
		arena_body.collision_layer = ARENA_BOUNDS_LAYER
		arena_body.collision_mask = 0

	var player := get_node_or_null("Player") as CharacterBody2D
	if player:
		player.collision_mask |= ARENA_BOUNDS_LAYER

func _setup_atmosphere() -> void:
	# Teinte vespérale : mauve-orangé chaud, comme l'heure dorée qui bascule dans la nuit
	var canvas_mod := get_node_or_null("CanvasModulate") as CanvasModulate
	if canvas_mod == null:
		canvas_mod = CanvasModulate.new()
		add_child(canvas_mod)
	canvas_mod.color = Color(0.38, 0.22, 0.34)

	# Fond crépusculaire sur un CanvasLayer sous le reste
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)

	var gradient_rect := ColorRect.new()
	gradient_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	gradient_rect.color = Color(0.04, 0.03, 0.08)
	bg_layer.add_child(gradient_rect)

	# Lueur de coucher de soleil en bas de l'écran
	var glow := PointLight2D.new()
	glow.texture = _make_glow_texture(256)
	glow.texture_scale = 12.0
	glow.energy = 0.3
	glow.color = Color(1.0, 0.32, 0.08)
	glow.position = Vector2(0, 500)
	add_child(glow)

func _make_glow_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius: float = size * 0.5
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(x, y).distance_to(center)
			var alpha: float = clampf(1.0 - dist / radius, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(img)
