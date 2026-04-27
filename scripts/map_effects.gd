extends Node2D

const BEACON_TEXTURE_SIZE := 96
const MIST_TEXTURE_SIZE := 128
const DEFAULT_BEACON_SCALE := 2.9
const DEFAULT_BEACON_ENERGY := 0.9

var _time := 0.0
var _beacon_states: Array[Dictionary] = []
var _mist_states: Array[Dictionary] = []


func _ready() -> void:
	randomize()
	var spawn_root := get_parent().get_node_or_null("ZombieSpawnZones")
	if spawn_root == null:
		return

	var beacon_texture := _make_radial_texture(BEACON_TEXTURE_SIZE, 2.4)
	var mist_texture := _make_radial_texture(MIST_TEXTURE_SIZE, 1.6)

	_add_spawn_beacon(spawn_root, "NorthGate", Vector2(-10, -48), Color(1.0, 0.2, 0.18), beacon_texture)
	_add_spawn_beacon(spawn_root, "WestBreach", Vector2(-38, -26), Color(1.0, 0.37, 0.2), beacon_texture)
	_add_spawn_beacon(spawn_root, "EastLoading", Vector2(20, -32), Color(1.0, 0.3, 0.2), beacon_texture)
	_add_spawn_beacon(spawn_root, "SouthSewer", Vector2(0, -26), Color(0.95, 0.55, 0.2), beacon_texture)
	_add_spawn_beacon(spawn_root, "SouthWestHatch", Vector2(0, -30), Color(0.95, 0.45, 0.22), beacon_texture)
	_add_spawn_beacon(spawn_root, "NorthEastServiceGate", Vector2(14, -34), Color(1.0, 0.2, 0.2), beacon_texture)
	_add_spawn_beacon(spawn_root, "CentralMetroPit", Vector2(0, -42), Color(1.0, 0.42, 0.22), beacon_texture)
	_add_spawn_beacon(spawn_root, "ParkTunnel", Vector2(-2, -30), Color(1.0, 0.26, 0.18), beacon_texture)

	_add_ambient_beacon(Vector2(-950, -420), Color(0.95, 0.74, 0.26), 4.4, 0.18, 0.2, beacon_texture)
	_add_ambient_beacon(Vector2(980, 420), Color(0.78, 0.88, 0.92), 4.8, 0.12, 0.16, beacon_texture)

	_add_mist_blob(Vector2(0, -980), 5.4, 0.16, 34.0, mist_texture)
	_add_mist_blob(Vector2(1450, -1030), 4.3, 0.14, 28.0, mist_texture)
	_add_mist_blob(Vector2(-1520, 860), 4.8, 0.15, 36.0, mist_texture)
	_add_mist_blob(Vector2(1320, 1080), 4.7, 0.16, 30.0, mist_texture)
	_add_mist_blob(Vector2(420, -140), 3.8, 0.12, 22.0, mist_texture)

	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_update_beacons()
	_update_mist()


func _add_spawn_beacon(spawn_root: Node, zone_name: String, offset: Vector2, color: Color, texture: Texture2D) -> void:
	var zone := spawn_root.get_node_or_null(zone_name) as Node2D
	if zone == null:
		return

	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = DEFAULT_BEACON_SCALE
	light.energy = DEFAULT_BEACON_ENERGY
	light.color = color
	light.position = offset
	zone.add_child(light)

	_beacon_states.append({
		"light": light,
		"base": randf_range(0.85, 1.1),
		"pulse": randf_range(0.35, 0.62),
		"speed": randf_range(3.8, 5.8),
		"phase": randf() * TAU,
		"jitter": randf_range(0.05, 0.16),
	})


func _add_ambient_beacon(light_pos: Vector2, color: Color, scale_value: float, energy_value: float, pulse: float, texture: Texture2D) -> void:
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = scale_value
	light.energy = energy_value
	light.color = color
	light.position = light_pos
	add_child(light)

	_beacon_states.append({
		"light": light,
		"base": energy_value,
		"pulse": pulse,
		"speed": randf_range(0.65, 1.2),
		"phase": randf() * TAU,
		"jitter": 0.04,
	})


func _update_beacons() -> void:
	for state in _beacon_states:
		var light := state.get("light") as PointLight2D
		if not is_instance_valid(light):
			continue

		var base := float(state.get("base", 1.0))
		var pulse := float(state.get("pulse", 0.4))
		var speed := float(state.get("speed", 1.0))
		var phase := float(state.get("phase", 0.0))
		var jitter := float(state.get("jitter", 0.1))

		var wave := sin(_time * speed + phase)
		var noise := randf_range(-jitter, jitter)
		light.energy = clampf(base + wave * pulse + noise, 0.08, 2.6)


func _add_mist_blob(origin: Vector2, base_scale: float, base_alpha: float, drift: float, texture: Texture2D) -> void:
	var blob := Sprite2D.new()
	blob.texture = texture
	blob.position = origin
	blob.scale = Vector2(base_scale, base_scale)
	blob.modulate = Color(0.62, 0.68, 0.72, base_alpha)
	blob.z_index = -5
	add_child(blob)

	_mist_states.append({
		"blob": blob,
		"origin": origin,
		"base_scale": base_scale,
		"base_alpha": base_alpha,
		"drift": drift,
		"phase": randf() * TAU,
		"speed": randf_range(0.22, 0.46),
	})


func _update_mist() -> void:
	for state in _mist_states:
		var blob := state.get("blob") as Sprite2D
		if not is_instance_valid(blob):
			continue

		var origin := state.get("origin") as Vector2
		var base_scale := float(state.get("base_scale", 4.0))
		var base_alpha := float(state.get("base_alpha", 0.14))
		var drift := float(state.get("drift", 20.0))
		var phase := float(state.get("phase", 0.0))
		var speed := float(state.get("speed", 0.3))

		var wave := sin(_time * speed + phase)
		var wave_b := cos(_time * speed * 0.75 + phase * 0.6)
		blob.position = origin + Vector2(wave, wave_b) * drift

		var scale_factor := base_scale * (0.88 + (wave * 0.5 + 0.5) * 0.26)
		blob.scale = Vector2(scale_factor, scale_factor)

		var alpha_factor := base_alpha * (0.72 + (wave_b * 0.5 + 0.5) * 0.45)
		blob.modulate.a = alpha_factor


func _make_radial_texture(size: int, softness: float) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5

	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(center)
			var n := clampf(1.0 - d / radius, 0.0, 1.0)
			var a := pow(n, softness)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))

	return ImageTexture.create_from_image(image)
