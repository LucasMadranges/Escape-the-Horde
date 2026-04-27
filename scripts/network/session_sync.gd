extends Node

const SYNC_INTERVAL := 0.06
const PLAYER_CONDITION_STORE_SCRIPT := preload("res://scripts/network/players/player_condition_store.gd")
const REMOTE_PLAYER_VISUALS_SCRIPT := preload("res://scripts/network/remote_players/remote_player_visuals.gd")
const STATUS_ALIVE := "alive"

var realtime_client: Node
var remote_players_root: Node2D
var remote_states := {}
var sync_accumulator := 0.0
var local_player_id := ""
var condition_store: RefCounted
var remote_visuals: RefCounted

func _ready() -> void:
	remote_players_root = get_parent().get_node_or_null("RemotePlayers")
	realtime_client = get_tree().root.get_node_or_null("RealtimeClient")
	if realtime_client == null or remote_players_root == null:
		return

	condition_store = PLAYER_CONDITION_STORE_SCRIPT.new()
	remote_visuals = REMOTE_PLAYER_VISUALS_SCRIPT.new()
	remote_visuals.setup(remote_players_root, condition_store)
	local_player_id = str(realtime_client.get("player_id"))

	if realtime_client.has_signal("played") and not realtime_client.played.is_connected(_on_game_state_updated):
		realtime_client.played.connect(_on_game_state_updated)
	if realtime_client.has_signal("joined") and not realtime_client.joined.is_connected(_on_game_state_updated):
		realtime_client.joined.connect(_on_game_state_updated)
	if realtime_client.has_signal("game_state_updated") and not realtime_client.game_state_updated.is_connected(_on_game_state_updated):
		realtime_client.game_state_updated.connect(_on_game_state_updated)
	if realtime_client.has_signal("player_sync_received") and not realtime_client.player_sync_received.is_connected(_on_player_sync_received):
		realtime_client.player_sync_received.connect(_on_player_sync_received)
	if realtime_client.has_signal("player_downed_received") and not realtime_client.player_downed_received.is_connected(_on_player_downed_received):
		realtime_client.player_downed_received.connect(_on_player_downed_received)
	if realtime_client.has_signal("player_revive_started_received") and not realtime_client.player_revive_started_received.is_connected(_on_player_revive_started_received):
		realtime_client.player_revive_started_received.connect(_on_player_revive_started_received)
	if realtime_client.has_signal("player_revive_canceled_received") and not realtime_client.player_revive_canceled_received.is_connected(_on_player_revive_canceled_received):
		realtime_client.player_revive_canceled_received.connect(_on_player_revive_canceled_received)
	if realtime_client.has_signal("player_revived_received") and not realtime_client.player_revived_received.is_connected(_on_player_revived_received):
		realtime_client.player_revived_received.connect(_on_player_revived_received)
	if realtime_client.has_signal("player_dead_received") and not realtime_client.player_dead_received.is_connected(_on_player_dead_received):
		realtime_client.player_dead_received.connect(_on_player_dead_received)

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
		var local_status := _read_local_status(local_player)
		remote_states[local_player_id] = {
			"position": local_player.global_position,
			"velocity": local_player.velocity,
			"username": str(realtime_client.get("username")),
			"status": local_status,
		}

	_update_remote_status_visuals()


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

		var username := _display_name(str(player_data.get("username", player_id)), player_id)
		var has_status: bool = player_data.has("status")
		var status: String = condition_store.get_player_status(player_id)
		if has_status:
			status = str(player_data.get("status", status))
		alive_ids[player_id] = true
		remote_visuals.ensure_player(player_id, username)
		if has_status:
			condition_store.set_status_from_game_state(player_id, status)

		if remote_states.has(player_id):
			var state := remote_states[player_id] as Dictionary
			state["username"] = username
			state["status"] = status
			remote_states[player_id] = state
		else:
			remote_states[player_id] = {
				"position": Vector2.ZERO,
				"velocity": Vector2.ZERO,
				"username": username,
				"status": status,
			}

	for id in remote_visuals.get_player_ids():
		if not alive_ids.has(id):
			remote_visuals.remove_player(str(id))
			remote_states.erase(id)
			condition_store.remove_player(str(id))

	_update_remote_status_visuals()

func _on_player_sync_received(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	if player_id.is_empty() or player_id == local_player_id:
		return

	var sync_username := _display_name(str(payload.get("username", player_id)), player_id)
	remote_visuals.ensure_player(player_id, sync_username)
	if not remote_visuals.has(player_id):
		return

	var x := float(payload.get("x", 0.0))
	var y := float(payload.get("y", 0.0))
	var vx := float(payload.get("vx", 0.0))
	var vy := float(payload.get("vy", 0.0))
	var status: String = condition_store.get_player_status(player_id)
	remote_states[player_id] = {
		"position": Vector2(x, y),
		"velocity": Vector2(vx, vy),
		"username": str(payload.get("username", player_id)),
		"status": status,
	}
	remote_visuals.update_transform(player_id, Vector2(x, y), Vector2(vx, vy))


func _on_player_downed_received(payload: Dictionary) -> void:
	condition_store.on_player_downed(payload)
	_update_remote_status_visuals()


func _on_player_revive_started_received(payload: Dictionary) -> void:
	condition_store.on_player_revive_started(payload)
	_update_remote_status_visuals()


func _on_player_revive_canceled_received(payload: Dictionary) -> void:
	condition_store.on_player_revive_canceled(payload)
	_update_remote_status_visuals()


func _on_player_revived_received(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	condition_store.on_player_revived(payload)
	remote_visuals.play_revive_effect(player_id)
	_update_remote_status_visuals()


func _on_player_dead_received(payload: Dictionary) -> void:
	condition_store.on_player_dead(payload)
	_update_remote_status_visuals()

func _update_remote_status_visuals() -> void:
	remote_visuals.update_status_visuals()


func _read_local_status(local_player: Node) -> String:
	var local_status := STATUS_ALIVE
	if local_player.has_method("get"):
		var status_variant: Variant = local_player.get("life_state_name")
		if typeof(status_variant) == TYPE_STRING and not str(status_variant).is_empty():
			local_status = str(status_variant)
	return local_status


func get_player_states() -> Dictionary:
	var states := {}

	for player_id in remote_states.keys():
		var state := remote_states[player_id] as Dictionary
		var merged_state := state.duplicate()
		merged_state["status"] = condition_store.get_player_status(str(player_id))
		states[player_id] = merged_state

	if local_player_id.is_empty():
		return states

	var local_player := get_parent().get_node_or_null("Player")
	if local_player:
		var local_status := _read_local_status(local_player)
		states[local_player_id] = {
			"position": local_player.global_position,
			"velocity": local_player.velocity,
			"username": str(realtime_client.get("username")),
			"status": local_status,
		}

	return states


func get_local_player_id() -> String:
	return local_player_id


func set_local_player_status(status: String, bleedout_end_ms: int = 0) -> void:
	if local_player_id.is_empty():
		return
	condition_store.set_local_status(local_player_id, status, bleedout_end_ms)


func get_player_condition(player_id: String) -> Dictionary:
	return condition_store.get_player_condition(player_id)


func find_revivable_target(from_position: Vector2, max_distance: float, reviver_player_id: String) -> String:
	return condition_store.find_revivable_target(
		remote_states,
		from_position,
		max_distance,
		reviver_player_id,
	)


func get_revive_state(player_id: String) -> Dictionary:
	return condition_store.get_revive_state(player_id)


func get_alive_remote_nodes() -> Array:
	return remote_visuals.get_alive_remote_nodes()


func _display_name(raw: String, player_id: String) -> String:
	if raw.is_empty() or raw == player_id or (raw.length() == 36 and raw.count("-") == 4):
		return "Player_%s" % player_id.substr(0, 6)
	return raw
