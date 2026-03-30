extends RefCounted


static func find_waiting_game(http_request: HTTPRequest, games_api_url: String) -> Dictionary:
	var games_result: Dictionary = await _request_array(http_request, games_api_url, "games")
	if not bool(games_result.get("ok", false)):
		return games_result

	var games: Array = games_result.get("items", [])
	games.sort_custom(func(a, b):
		if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
			return false
		return str(a.get("createdAt", "")) > str(b.get("createdAt", ""))
	)

	for game_variant in games:
		if typeof(game_variant) != TYPE_DICTIONARY:
			continue

		var game: Dictionary = game_variant
		if str(game.get("status", "")) != "waiting":
			continue

		var game_id := str(game.get("id", ""))
		if not game_id.is_empty():
			return {
				"ok": true,
				"gameId": game_id,
			}

	return {
		"ok": false,
		"error": "aucune partie trouvee",
	}


static func list_open_sessions(
	http_request: HTTPRequest,
	games_api_url: String,
	sessions_api_url: String,
) -> Dictionary:
	var games_result: Dictionary = await _request_array(http_request, games_api_url, "games")
	if not bool(games_result.get("ok", false)):
		return games_result

	var sessions_result: Dictionary = await _request_array(http_request, sessions_api_url, "sessions")
	if not bool(sessions_result.get("ok", false)):
		return sessions_result

	var games: Array = games_result.get("items", [])
	var sessions: Array = sessions_result.get("items", [])
	var players_by_game_id := {}

	for session_variant in sessions:
		if typeof(session_variant) != TYPE_DICTIONARY:
			continue

		var session: Dictionary = session_variant
		var game_id := str(session.get("gameId", ""))
		if game_id.is_empty():
			continue

		players_by_game_id[game_id] = int(players_by_game_id.get(game_id, 0)) + 1

	var open_sessions: Array = []
	for game_variant in games:
		if typeof(game_variant) != TYPE_DICTIONARY:
			continue

		var game: Dictionary = game_variant
		var status := str(game.get("status", ""))
		if status == "finished":
			continue

		var game_id := str(game.get("id", ""))
		if game_id.is_empty():
			continue

		open_sessions.append({
			"gameId": game_id,
			"status": status,
			"playerCount": int(players_by_game_id.get(game_id, 0)),
			"createdAt": str(game.get("createdAt", "")),
			"updatedAt": str(game.get("updatedAt", "")),
		})

	open_sessions.sort_custom(func(a, b):
		if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
			return false
		return str(a.get("createdAt", "")) > str(b.get("createdAt", ""))
	)

	return {
		"ok": true,
		"sessions": open_sessions,
	}


static func _request_array(http_request: HTTPRequest, url: String, label: String) -> Dictionary:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return {
			"ok": false,
			"error": "Requete deja en cours",
		}

	var err := http_request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		return {
			"ok": false,
			"error": "Echec API %s: %s" % [label, err],
		}

	var result: Array = await http_request.request_completed
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": "Echec API %s: HTTP %s" % [label, response_code],
		}

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		return {
			"ok": false,
			"error": "Reponse API %s invalide" % label,
		}

	return {
		"ok": true,
		"items": parsed,
	}
