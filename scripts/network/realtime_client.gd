extends Node

signal connected(socket_id: String)
signal played(game_state: Dictionary)
signal joined(game_state: Dictionary)
signal game_state_updated(game_state: Dictionary)
signal player_sync_received(payload: Dictionary)
signal zombie_spawn_received(payload: Dictionary)
signal zombie_kill_received(payload: Dictionary)
signal realtime_error(message: String)

const WS_URL := "ws://127.0.0.1:3000/ws/game"
const GAMES_API_URL := "http://127.0.0.1:3000/api/games"

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
	player_id = _build_player_id()
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
	var err := ws.connect_to_url(WS_URL)
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
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		emit_signal("realtime_error", "Recherche deja en cours")
		return

	var err := http_request.request(GAMES_API_URL, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		emit_signal("realtime_error", "Echec de recherche de game: %s" % err)
		return

	var result: Array = await http_request.request_completed
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]

	if response_code < 200 or response_code >= 300:
		emit_signal("realtime_error", "Echec API games: HTTP %s" % response_code)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		emit_signal("realtime_error", "Reponse API games invalide")
		return

	var games: Array = parsed
	games.sort_custom(func(a, b):
		if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
			return false
		return str(a.get("createdAt", "")) > str(b.get("createdAt", ""))
	)

	# Rejoindre uniquement une partie en attente.
	for game in games:
		if typeof(game) == TYPE_DICTIONARY and str(game.get("status", "")) == "waiting":
			_join_game(str(game.get("id", "")))
			return

	emit_signal("realtime_error", "aucune partie trouvé")


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

	match event_name:
		"game:connected":
			socket_connected = true
			emit_signal("connected", str(data.get("socketId", "")))
			if not pending_join_game_id.is_empty():
				_join_game(pending_join_game_id)
				return
			if play_requested:
				play()
		"game:played":
			current_game_id = str(data.get("gameId", ""))
			last_game_state = data
			emit_signal("played", data)
		"game:joined":
			current_game_id = str(data.get("gameId", ""))
			last_game_state = data
			emit_signal("joined", data)
		"game:state":
			current_game_id = str(data.get("gameId", current_game_id))
			last_game_state = data
			emit_signal("game_state_updated", data)
		"game:player_sync":
			emit_signal("player_sync_received", data)
		"game:zombie_spawn":
			emit_signal("zombie_spawn_received", data)
		"game:zombie_kill":
			emit_signal("zombie_kill_received", data)
		"game:error":
			emit_signal("realtime_error", str(data.get("message", "unknown")))


func sync_player_state(position: Vector2, velocity: Vector2) -> void:
	if current_game_id.is_empty() or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	_send_event("game:sync_player", {
		"x": position.x,
		"y": position.y,
		"vx": velocity.x,
		"vy": velocity.y,
	})


func send_zombie_spawn(position: Vector2, zombie_id: String) -> void:
	if current_game_id.is_empty() or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	_send_event("game:zombie_spawn", {
		"x": position.x,
		"y": position.y,
		"zombieId": zombie_id,
	})


func send_zombie_kill(zombie_id: String) -> void:
	if zombie_id.is_empty() or current_game_id.is_empty() or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	_send_event("game:zombie_kill", {
		"zombieId": zombie_id,
	})


func is_host() -> bool:
	if not last_game_state.has("players"):
		return false

	var players: Variant = last_game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.size() == 0:
		return false

	var first: Variant = players[0]
	if typeof(first) != TYPE_DICTIONARY:
		return false

	return str(first.get("playerId", "")) == player_id

func _build_player_id() -> String:
	var pattern := "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	var out := ""

	for i in pattern.length():
		var ch := pattern[i]
		if ch == "x":
			out += "%x" % (randi() % 16)
		elif ch == "y":
			out += "%x" % ((randi() % 4) + 8)
		else:
			out += ch

	return out
