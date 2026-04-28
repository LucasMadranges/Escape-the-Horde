extends Node

const REALTIME_CONFIG_SCRIPT := preload("res://scripts/network/realtime/realtime_config.gd")
const REALTIME_IDENTITY_SCRIPT := preload("res://scripts/network/realtime/realtime_identity.gd")
const REALTIME_GAME_DISCOVERY_SCRIPT := preload("res://scripts/network/realtime/realtime_game_discovery.gd")
const REALTIME_EVENT_DISPATCHER_SCRIPT := preload("res://scripts/network/realtime/realtime_event_dispatcher.gd")

signal connected(socket_id: String)
signal played(game_state: Dictionary)
signal joined(game_state: Dictionary)
signal launched(game_state: Dictionary)
signal game_state_updated(game_state: Dictionary)
signal player_sync_received(payload: Dictionary)
signal zombie_spawn_received(payload: Dictionary)
signal zombie_sync_received(payload: Dictionary)
signal zombie_kill_received(payload: Dictionary)
signal player_damage_received(payload: Dictionary)
signal player_downed_received(payload: Dictionary)
signal player_revive_started_received(payload: Dictionary)
signal player_revive_canceled_received(payload: Dictionary)
signal player_revived_received(payload: Dictionary)
signal player_dead_received(payload: Dictionary)
signal scene_change_received(payload: Dictionary)
signal extraction_update_received(payload: Dictionary)
signal extraction_launch_received
signal realtime_error(message: String)

var ws := WebSocketPeer.new()
var socket_connected := false
var play_requested := false
var pending_join_game_id := ""

var player_id := ""
var username := ""
var http_request: HTTPRequest
var current_game_id := ""
var last_game_state: Dictionary = {}

func _ready() -> void:
	randomize()
	player_id = REALTIME_IDENTITY_SCRIPT.build_player_id()
	if not GameData.username.is_empty():
		username = GameData.username
	else:
		username = "Player_%s" % player_id.substr(0, 6)
	http_request = HTTPRequest.new()
	add_child(http_request)
	connect_socket()

func _process(_delta: float) -> void:
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
		ws.poll()

	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var raw := ws.get_packet().get_string_from_utf8()
			_handle_message(raw)

func connect_socket() -> void:
	var err := ws.connect_to_url(REALTIME_CONFIG_SCRIPT.WS_URL)
	if err != OK:
		emit_signal("realtime_error", "WebSocket connection failed: %s" % err)

func play() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN or not socket_connected:
		play_requested = true
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			connect_socket()
		return

	play_requested = false
	_send_event("game:play", {
		"playerId": player_id,
		"username": username,
	})


func join_existing_game() -> void:
	var result: Dictionary = await REALTIME_GAME_DISCOVERY_SCRIPT.find_waiting_game(
		http_request,
		REALTIME_CONFIG_SCRIPT.GAMES_API_URL,
	)
	if not bool(result.get("ok", false)):
		emit_signal("realtime_error", str(result.get("error", "unknown")))
		return

	_join_game(str(result.get("gameId", "")))


func join_game_by_id(game_id: String) -> void:
	_join_game(game_id)


func _join_game(game_id: String) -> void:
	if game_id.is_empty():
		emit_signal("realtime_error", "Game ID invalide")
		return

	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN or not socket_connected:
		pending_join_game_id = game_id
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			connect_socket()
		return

	pending_join_game_id = ""
	_send_event("game:join", {
		"gameId": game_id,
		"playerId": player_id,
		"username": username,
	})

func _send_event(event_name: String, data: Dictionary) -> void:
	ws.send_text(JSON.stringify({
		"event": event_name,
		"data": data,
	}))

func _handle_message(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var event_name: String = parsed.get("event", "")
	var data: Variant = parsed.get("data", {})
	REALTIME_EVENT_DISPATCHER_SCRIPT.dispatch(self, event_name, data)


func _on_connected_event(data: Dictionary) -> void:
	socket_connected = true
	emit_signal("connected", str(data.get("socketId", "")))
	if not pending_join_game_id.is_empty():
		_join_game(pending_join_game_id)
		return
	if play_requested:
		play()


func _on_played_event(data: Dictionary) -> void:
	current_game_id = str(data.get("gameId", ""))
	last_game_state = data
	emit_signal("played", data)


func _on_joined_event(data: Dictionary) -> void:
	current_game_id = str(data.get("gameId", ""))
	last_game_state = data
	emit_signal("joined", data)


func _on_launched_event(data: Dictionary) -> void:
	current_game_id = str(data.get("gameId", current_game_id))
	last_game_state = data
	emit_signal("launched", data)


func _on_state_event(data: Dictionary) -> void:
	current_game_id = str(data.get("gameId", current_game_id))
	last_game_state = data
	emit_signal("game_state_updated", data)


func _on_player_sync_event(data: Dictionary) -> void:
	player_sync_received.emit(data)


func _on_zombie_spawn_event(data: Dictionary) -> void:
	zombie_spawn_received.emit(data)


func _on_zombie_sync_event(data: Dictionary) -> void:
	zombie_sync_received.emit(data)


func _on_zombie_kill_event(data: Dictionary) -> void:
	zombie_kill_received.emit(data)


func _on_player_damage_event(data: Dictionary) -> void:
	player_damage_received.emit(data)


func _on_player_downed_event(data: Dictionary) -> void:
	player_downed_received.emit(data)


func _on_player_revive_started_event(data: Dictionary) -> void:
	player_revive_started_received.emit(data)


func _on_player_revive_canceled_event(data: Dictionary) -> void:
	player_revive_canceled_received.emit(data)


func _on_player_revived_event(data: Dictionary) -> void:
	player_revived_received.emit(data)


func _on_player_dead_event(data: Dictionary) -> void:
	player_dead_received.emit(data)


func sync_player_state(position: Vector2, velocity: Vector2) -> void:
	if not _can_send(true):
		return

	_send_event("game:sync_player", {
		"x": position.x,
		"y": position.y,
		"vx": velocity.x,
		"vy": velocity.y,
		"username": username,
	})


func send_zombie_spawn(position: Vector2, zombie_id: String) -> void:
	if not _can_send(true):
		return

	_send_event("game:zombie_spawn", {
		"x": position.x,
		"y": position.y,
		"zombieId": zombie_id,
	})


func send_zombie_kill(zombie_id: String) -> void:
	if zombie_id.is_empty() or not _can_send(true):
		return

	_send_event("game:zombie_kill", {
		"zombieId": zombie_id,
	})


func send_zombie_sync(zombies: Array) -> void:
	if not _can_send(true):
		return

	_send_event("game:zombie_sync", {
		"zombies": zombies,
	})


func send_player_damage(player_target_id: String, amount: int) -> void:
	if player_target_id.is_empty() or amount <= 0 or not _can_send(true):
		return

	_send_event("game:player_damage", {
		"playerId": player_target_id,
		"amount": amount,
	})


func send_player_downed(bleedout_duration_ms: int = 30000) -> void:
	if not _can_send(true):
		return

	_send_event("game:player_down", {
		"bleedoutDurationMs": max(1000, bleedout_duration_ms),
	})


func send_player_revive_start(target_player_id: String, duration_ms: int = 3000) -> void:
	if target_player_id.is_empty() or not _can_send(true):
		return

	_send_event("game:player_revive_start", {
		"targetPlayerId": target_player_id,
		"durationMs": max(500, duration_ms),
	})


func send_player_revive_cancel(target_player_id: String) -> void:
	if target_player_id.is_empty() or not _can_send(true):
		return

	_send_event("game:player_revive_cancel", {
		"targetPlayerId": target_player_id,
	})


func send_player_revived(target_player_id: String) -> void:
	if target_player_id.is_empty() or not _can_send(true):
		return

	_send_event("game:player_revived", {
		"targetPlayerId": target_player_id,
	})


func send_player_dead() -> void:
	if not _can_send(true):
		return

	_send_event("game:player_dead", {})


func send_scene_change(target: String) -> void:
	if not _can_send(true):
		return

	_send_event("game:scene_change", {"target": target})


func _on_scene_change_event(data: Dictionary) -> void:
	scene_change_received.emit(data)

func _on_extraction_update_event(data: Dictionary) -> void:
	extraction_update_received.emit(data)

func _on_extraction_launch_event(_data: Dictionary) -> void:
	extraction_launch_received.emit()

func send_extraction_enter(total_players: int) -> void:
	if not _can_send(true):
		return
	_send_event("game:extraction_enter", {"totalPlayers": total_players})

func send_extraction_exit(total_players: int) -> void:
	if not _can_send(true):
		return
	_send_event("game:extraction_exit", {"totalPlayers": total_players})


func launch_game() -> void:
	if not _can_send(true):
		return

	_send_event("game:launch", {
		"gameId": current_game_id,
	})


func request_game_state() -> void:
	if not _can_send(true):
		return

	_send_event("game:get", {
		"gameId": current_game_id,
	})


func is_host() -> bool:
	if last_game_state.has("hostPlayerId"):
		return str(last_game_state.get("hostPlayerId", "")) == player_id

	if not last_game_state.has("players"):
		return false

	var players: Variant = last_game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.size() == 0:
		return false

	var first: Variant = players[0]
	if typeof(first) != TYPE_DICTIONARY:
		return false

	return str(first.get("playerId", "")) == player_id


func _can_send(require_game_id := false) -> bool:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	if require_game_id and current_game_id.is_empty():
		return false
	return true
