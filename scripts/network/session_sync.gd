extends Node

const SYNC_INTERVAL := 0.06
const RemotePlayerFactory := preload("res://scripts/network/remote_players/remote_player_factory.gd")

var realtime_client: Node
var remote_players_root: Node2D
var remote_nodes := {}
var remote_states := {}
var sync_accumulator := 0.0
var local_player_id := ""

func _ready() -> void:
	remote_players_root = get_parent().get_node_or_null("RemotePlayers")
	realtime_client = get_tree().root.get_node_or_null("RealtimeClient")
	if realtime_client == null or remote_players_root == null:
		return

	local_player_id = str(realtime_client.get("player_id"))

	if realtime_client.has_signal("played") and not realtime_client.played.is_connected(_on_game_state_updated):
		realtime_client.played.connect(_on_game_state_updated)
	if realtime_client.has_signal("joined") and not realtime_client.joined.is_connected(_on_game_state_updated):
		realtime_client.joined.connect(_on_game_state_updated)
	if realtime_client.has_signal("game_state_updated") and not realtime_client.game_state_updated.is_connected(_on_game_state_updated):
		realtime_client.game_state_updated.connect(_on_game_state_updated)
	if realtime_client.has_signal("player_sync_received") and not realtime_client.player_sync_received.is_connected(_on_player_sync_received):
		realtime_client.player_sync_received.connect(_on_player_sync_received)

	var cached_state: Variant = realtime_client.get("last_game_state")
	if typeof(cached_state) == TYPE_DICTIONARY:
		_on_game_state_updated(cached_state)

func _process(delta: float) -> void:
	if realtime_client == null:
		return

	var local_player := get_parent().get_node_or_null("Player")
	if local_player == null:
		return

	sync_accumulator += delta
	if sync_accumulator < SYNC_INTERVAL:
		return

	sync_accumulator = 0.0
	realtime_client.sync_player_state(local_player.global_position, local_player.velocity)

	if not local_player_id.is_empty():
		remote_states[local_player_id] = {
			"position": local_player.global_position,
			"velocity": local_player.velocity,
			"username": str(realtime_client.get("username")),
		}

func _on_game_state_updated(game_state: Dictionary) -> void:
	if not game_state.has("players"):
		return

	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return

	var alive_ids := {}
	for player_data in players:
		if typeof(player_data) != TYPE_DICTIONARY:
			continue

		var player_id := str(player_data.get("playerId", ""))
		if player_id.is_empty() or player_id == local_player_id:
			continue

		var username := str(player_data.get("username", player_id))
		alive_ids[player_id] = true
		_ensure_remote_player(player_id, username)
		if remote_states.has(player_id):
			var state := remote_states[player_id] as Dictionary
			state["username"] = username
			remote_states[player_id] = state

	for id in remote_nodes.keys():
		if not alive_ids.has(id):
			var stale = remote_nodes[id]
			if is_instance_valid(stale):
				stale.queue_free()
			remote_nodes.erase(id)
			remote_states.erase(id)

func _on_player_sync_received(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	if player_id.is_empty() or player_id == local_player_id:
		return

	_ensure_remote_player(player_id, player_id)
	var node = remote_nodes.get(player_id)
	if node == null:
		return

	var x := float(payload.get("x", 0.0))
	var y := float(payload.get("y", 0.0))
	var vx := float(payload.get("vx", 0.0))
	var vy := float(payload.get("vy", 0.0))
	remote_states[player_id] = {
		"position": Vector2(x, y),
		"velocity": Vector2(vx, vy),
		"username": str(payload.get("username", player_id)),
	}
	node.global_position = Vector2(x, y)
	_update_remote_animation(node, Vector2(vx, vy))

func _ensure_remote_player(player_id: String, username: String) -> void:
	if remote_nodes.has(player_id):
		var existing_label: Label = remote_nodes[player_id].get_node_or_null("Name")
		if existing_label:
			existing_label.text = username
		return

	var holder := RemotePlayerFactory.create(player_id, username)
	remote_players_root.add_child(holder)
	remote_nodes[player_id] = holder

func _update_remote_animation(node: Node2D, vel: Vector2) -> void:
	var sprite: AnimatedSprite2D = node.get_node_or_null("AnimatedSprite2D")
	if sprite == null:
		return

	var moving := vel.length_squared() > 1.0
	if abs(vel.x) > abs(vel.y):
		sprite.flip_h = vel.x < 0.0
		sprite.play("run_side" if moving else "idle_side")
	elif vel.y > 0.0:
		sprite.flip_h = false
		sprite.play("run_down" if moving else "idle_down")
	else:
		sprite.flip_h = false
		sprite.play("run_up" if moving else "idle_up")


func get_player_states() -> Dictionary:
	var states := {}

	for player_id in remote_states.keys():
		states[player_id] = remote_states[player_id]

	if local_player_id.is_empty():
		return states

	var local_player := get_parent().get_node_or_null("Player")
	if local_player:
		states[local_player_id] = {
			"position": local_player.global_position,
			"velocity": local_player.velocity,
			"username": str(realtime_client.get("username")),
		}

	return states


func get_local_player_id() -> String:
	return local_player_id
