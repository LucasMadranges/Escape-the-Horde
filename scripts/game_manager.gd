extends Node

@export var zombie_scene: PackedScene

const SPAWN_RADIUS := 600.0
const BASE_ENEMIES := 5

var wave := 1
var enemies_per_wave: int
var enemies_spawned := 0
var spawn_timer := 0.0
var spawn_interval := 1.8
var wave_active := false
var realtime_client: Node
var is_host := true
var zombies_by_id := {}
var suppress_kill_broadcast := {}

@onready var enemies_node: Node2D = get_parent().get_node("Enemies")
@onready var wave_label: Label = get_parent().get_node("UI/WaveLabel")
@onready var enemies_label: Label = get_parent().get_node("UI/EnemiesLabel")
@onready var hp_label: Label = get_parent().get_node("UI/HPLabel")


func _ready() -> void:
	realtime_client = get_tree().root.get_node_or_null("RealtimeClient")
	if realtime_client:
		if realtime_client.has_signal("game_state_updated") and not realtime_client.game_state_updated.is_connected(_on_game_state_updated):
			realtime_client.game_state_updated.connect(_on_game_state_updated)
		if realtime_client.has_signal("zombie_spawn_received") and not realtime_client.zombie_spawn_received.is_connected(_on_zombie_spawn_received):
			realtime_client.zombie_spawn_received.connect(_on_zombie_spawn_received)
		if realtime_client.has_signal("zombie_kill_received") and not realtime_client.zombie_kill_received.is_connected(_on_zombie_kill_received):
			realtime_client.zombie_kill_received.connect(_on_zombie_kill_received)
		if realtime_client.has_method("is_host"):
			is_host = bool(realtime_client.is_host())

	enemies_per_wave = BASE_ENEMIES
	_announce_wave()


func _announce_wave() -> void:
	wave_label.text = "Vague %d" % wave
	wave_active = false
	await get_tree().create_timer(2.5).timeout
	wave_active = true
	enemies_spawned = 0
	spawn_timer = 0.5


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and player.has_method("take_damage"):
		hp_label.text = "PV: %d" % player.get("health")

	if not wave_active:
		return

	if not is_host:
		return

	var alive := enemies_node.get_child_count()
	enemies_label.text = "Ennemis: %d" % alive

	if enemies_spawned < enemies_per_wave:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_zombie()
			enemies_spawned += 1
			spawn_timer = spawn_interval
	elif alive == 0:
		wave_active = false
		wave += 1
		GameData.wave_reached = wave
		enemies_per_wave = BASE_ENEMIES + (wave - 1) * 3
		enemies_label.text = "Ennemis: 0"
		_announce_wave()


func _spawn_zombie() -> void:
	if zombie_scene == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	var angle := randf() * TAU
	var spawn_pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS
	var zombie_id := _generate_zombie_id()
	_spawn_zombie_at(spawn_pos, zombie_id)
	if realtime_client and realtime_client.has_method("send_zombie_spawn"):
		realtime_client.send_zombie_spawn(spawn_pos, zombie_id)


func _spawn_zombie_at(spawn_pos: Vector2, zombie_id: String) -> void:
	if zombies_by_id.has(zombie_id):
		return

	var z := zombie_scene.instantiate()
	z.global_position = spawn_pos
	z.zombie_id = zombie_id
	if z.has_signal("died"):
		z.died.connect(_on_zombie_died)
	enemies_node.add_child(z)
	zombies_by_id[zombie_id] = z


func _on_game_state_updated(_state: Dictionary) -> void:
	if realtime_client and realtime_client.has_method("is_host"):
		is_host = bool(realtime_client.is_host())


func _on_zombie_spawn_received(payload: Dictionary) -> void:
	if is_host:
		return

	var zombie_id := str(payload.get("zombieId", ""))
	if zombie_id.is_empty():
		return

	var x := float(payload.get("x", 0.0))
	var y := float(payload.get("y", 0.0))
	_spawn_zombie_at(Vector2(x, y), zombie_id)


func _on_zombie_died(zombie_id: String) -> void:
	if zombie_id.is_empty():
		return

	zombies_by_id.erase(zombie_id)
	if suppress_kill_broadcast.has(zombie_id):
		suppress_kill_broadcast.erase(zombie_id)
		return

	if realtime_client and realtime_client.has_method("send_zombie_kill"):
		realtime_client.send_zombie_kill(zombie_id)


func _on_zombie_kill_received(payload: Dictionary) -> void:
	var zombie_id := str(payload.get("zombieId", ""))
	if zombie_id.is_empty() or not zombies_by_id.has(zombie_id):
		return

	var zombie = zombies_by_id[zombie_id]
	zombies_by_id.erase(zombie_id)
	if is_instance_valid(zombie):
		suppress_kill_broadcast[zombie_id] = true
		zombie.queue_free()


func _generate_zombie_id() -> String:
	return "%s-%s" % [str(Time.get_ticks_msec()), str(randi() % 1000000)]
