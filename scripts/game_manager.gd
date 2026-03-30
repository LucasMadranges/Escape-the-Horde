extends Node

@export var zombie_scene: PackedScene

const SPAWN_RADIUS := 600.0
const BASE_ENEMIES := 5
const ZOMBIE_SYNC_INTERVAL := 0.08
const ZOMBIE_REGISTRY_SCRIPT := preload("res://scripts/game/zombies/zombie_registry.gd")

var wave := 1
var enemies_per_wave: int
var enemies_spawned := 0
var spawn_timer := 0.0
var spawn_interval := 1.8
var wave_active := false
var realtime_client: Node
var is_host := true
var zombie_sync_timer := 0.0
var zombie_registry: RefCounted

@onready var enemies_node: Node2D = get_parent().get_node("Enemies")
@onready var session_sync: Node = get_parent().get_node_or_null("SessionSync")
@onready var wave_label: Label = get_parent().get_node("UI/WaveLabel")
@onready var enemies_label: Label = get_parent().get_node("UI/EnemiesLabel")
@onready var hp_label: Label = get_parent().get_node("UI/HPLabel")


func _ready() -> void:
	zombie_registry = ZOMBIE_REGISTRY_SCRIPT.new()
	zombie_registry.setup(
		zombie_scene,
		enemies_node,
		is_host,
		Callable(self, "_on_zombie_died"),
		Callable(self, "_on_zombie_attack_player"),
	)

	realtime_client = get_tree().root.get_node_or_null("RealtimeClient")
	if realtime_client:
		if realtime_client.has_signal("game_state_updated") and not realtime_client.game_state_updated.is_connected(_on_game_state_updated):
			realtime_client.game_state_updated.connect(_on_game_state_updated)
		if realtime_client.has_signal("zombie_spawn_received") and not realtime_client.zombie_spawn_received.is_connected(_on_zombie_spawn_received):
			realtime_client.zombie_spawn_received.connect(_on_zombie_spawn_received)
		if realtime_client.has_signal("zombie_sync_received") and not realtime_client.zombie_sync_received.is_connected(_on_zombie_sync_received):
			realtime_client.zombie_sync_received.connect(_on_zombie_sync_received)
		if realtime_client.has_signal("zombie_kill_received") and not realtime_client.zombie_kill_received.is_connected(_on_zombie_kill_received):
			realtime_client.zombie_kill_received.connect(_on_zombie_kill_received)
		if realtime_client.has_signal("player_damage_received") and not realtime_client.player_damage_received.is_connected(_on_player_damage_received):
			realtime_client.player_damage_received.connect(_on_player_damage_received)
		if realtime_client.has_method("is_host"):
			is_host = bool(realtime_client.is_host())
		if realtime_client.has_method("request_game_state"):
			realtime_client.request_game_state()

		var cached_state: Variant = realtime_client.get("last_game_state")
		if typeof(cached_state) == TYPE_DICTIONARY:
			_on_game_state_updated(cached_state)

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

	if is_host:
		_update_host_zombie_targets()
		_sync_zombies_to_session(delta)

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
	zombie_registry.spawn_at(spawn_pos, zombie_id)
	if realtime_client and realtime_client.has_method("send_zombie_spawn"):
		realtime_client.send_zombie_spawn(spawn_pos, zombie_id)


func _on_game_state_updated(_state: Dictionary) -> void:
	if realtime_client and realtime_client.has_method("is_host"):
		is_host = bool(realtime_client.is_host())
	if zombie_registry:
		zombie_registry.set_authority(is_host)

	if not _state.has("zombies"):
		return

	var zombies_variant: Variant = _state.get("zombies", [])
	if typeof(zombies_variant) != TYPE_ARRAY:
		return

	zombie_registry.reconcile(zombies_variant)


func _on_zombie_spawn_received(payload: Dictionary) -> void:
	if is_host:
		return

	var zombie_id := str(payload.get("zombieId", ""))
	if zombie_id.is_empty():
		return

	var x := float(payload.get("x", 0.0))
	var y := float(payload.get("y", 0.0))
	zombie_registry.spawn_at(Vector2(x, y), zombie_id)


func _on_zombie_sync_received(payload: Dictionary) -> void:
	if is_host:
		return

	var zombies_variant: Variant = payload.get("zombies", [])
	if typeof(zombies_variant) != TYPE_ARRAY:
		return

	zombie_registry.reconcile(zombies_variant)


func _on_zombie_died(zombie_id: String) -> void:
	if zombie_id.is_empty():
		return

	zombie_registry.erase_only(zombie_id)
	if zombie_registry.consume_suppress_kill(zombie_id):
		return

	if realtime_client and realtime_client.has_method("send_zombie_kill"):
		realtime_client.send_zombie_kill(zombie_id)


func _on_zombie_attack_player(player_id: String, damage: int) -> void:
	if not is_host or player_id.is_empty() or damage <= 0:
		return

	if realtime_client and realtime_client.has_method("send_player_damage"):
		realtime_client.send_player_damage(player_id, damage)


func _on_player_damage_received(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	if player_id.is_empty() or player_id != _get_local_player_id():
		return

	var amount := int(payload.get("amount", 0))
	if amount <= 0:
		return

	var local_player := get_parent().get_node_or_null("Player")
	if is_instance_valid(local_player) and local_player.has_method("take_damage"):
		local_player.take_damage(amount)


func _on_zombie_kill_received(payload: Dictionary) -> void:
	var zombie_id := str(payload.get("zombieId", ""))
	if zombie_id.is_empty() or not zombie_registry.has(zombie_id):
		return

	zombie_registry.remove_and_free(zombie_id, true)


func _update_host_zombie_targets() -> void:
	if not is_host:
		return

	var player_states := _get_player_states()
	if player_states.is_empty():
		return

	zombie_registry.update_targets(player_states)


func _sync_zombies_to_session(delta: float) -> void:
	if not realtime_client or not realtime_client.has_method("send_zombie_sync"):
		return

	zombie_sync_timer -= delta
	if zombie_sync_timer > 0.0:
		return

	zombie_sync_timer = ZOMBIE_SYNC_INTERVAL
	var snapshots: Array = zombie_registry.build_snapshots()
	realtime_client.send_zombie_sync(snapshots)


func _get_player_states() -> Dictionary:
	if session_sync and session_sync.has_method("get_player_states"):
		return session_sync.get_player_states()

	var local_player := get_parent().get_node_or_null("Player")
	if not local_player:
		return {}

	return {
		_get_local_player_id(): {
			"position": local_player.global_position,
			"velocity": local_player.velocity,
		}
	}


func _get_local_player_id() -> String:
	if realtime_client:
		return str(realtime_client.get("player_id"))
	return ""


func _generate_zombie_id() -> String:
	return "%s-%s" % [str(Time.get_ticks_msec()), str(randi() % 1000000)]
