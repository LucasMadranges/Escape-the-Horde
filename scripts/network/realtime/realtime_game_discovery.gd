extends RefCounted


static func find_waiting_game(http_request: HTTPRequest, games_api_url: String) -> Dictionary:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return {
			"ok": false,
			"error": "Recherche deja en cours",
		}

	var err := http_request.request(games_api_url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		return {
			"ok": false,
			"error": "Echec de recherche de game: %s" % err,
		}

	var result: Array = await http_request.request_completed
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": "Echec API games: HTTP %s" % response_code,
		}

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		return {
			"ok": false,
			"error": "Reponse API games invalide",
		}

	var games: Array = parsed
	games.sort_custom(func(a, b):
		if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
			return false
		return str(a.get("createdAt", "")) > str(b.get("createdAt", ""))
	)

	for game in games:
		if typeof(game) == TYPE_DICTIONARY and str(game.get("status", "")) == "waiting":
			return {
				"ok": true,
				"gameId": str(game.get("id", "")),
			}

	return {
		"ok": false,
		"error": "aucune partie trouvé",
	}
