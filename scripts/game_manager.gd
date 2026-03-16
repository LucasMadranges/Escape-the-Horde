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

@onready var enemies_node: Node2D = get_parent().get_node("Enemies")
@onready var wave_label: Label = get_parent().get_node("UI/WaveLabel")
@onready var enemies_label: Label = get_parent().get_node("UI/EnemiesLabel")
@onready var hp_label: Label = get_parent().get_node("UI/HPLabel")


func _ready() -> void:
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
	var z := zombie_scene.instantiate()
	z.global_position = spawn_pos
	enemies_node.add_child(z)
