extends RefCounted

const STATUS_ALIVE := "alive"
const STATUS_DOWNED := "downed"
const STATUS_DEAD := "dead"

var player_conditions := {}


func set_status_from_game_state(player_id: String, status: String) -> void:
	var condition := _get_or_create_condition(player_id)
	condition["status"] = status
	player_conditions[player_id] = condition


func remove_player(player_id: String) -> void:
	player_conditions.erase(player_id)


func on_player_downed(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	if player_id.is_empty():
		return

	var downed_at_ms := int(payload.get("downedAtMs", _now_ms()))
	var bleedout_duration_ms: int = maxi(1000, int(payload.get("bleedoutDurationMs", 30000)))
	var condition := _get_or_create_condition(player_id)
	condition["status"] = STATUS_DOWNED
	condition["bleedoutEndMs"] = downed_at_ms + bleedout_duration_ms
	condition["revive"] = {}
	player_conditions[player_id] = condition


func on_player_revive_started(payload: Dictionary) -> void:
	var target_player_id := str(payload.get("targetPlayerId", ""))
	if target_player_id.is_empty():
		return

	var reviver_player_id := str(payload.get("reviverPlayerId", ""))
	var started_at_ms := int(payload.get("startedAtMs", _now_ms()))
	var duration_ms: int = maxi(500, int(payload.get("durationMs", 3000)))
	var condition := _get_or_create_condition(target_player_id)
	condition["revive"] = {
		"reviverPlayerId": reviver_player_id,
		"startedAtMs": started_at_ms,
		"durationMs": duration_ms,
	}
	player_conditions[target_player_id] = condition


func on_player_revive_canceled(payload: Dictionary) -> void:
	var target_player_id := str(payload.get("targetPlayerId", ""))
	if target_player_id.is_empty() or not player_conditions.has(target_player_id):
		return

	var condition := _get_or_create_condition(target_player_id)
	condition["revive"] = {}
	player_conditions[target_player_id] = condition


func on_player_revived(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	if player_id.is_empty():
		return

	var condition := _get_or_create_condition(player_id)
	condition["status"] = STATUS_ALIVE
	condition["bleedoutEndMs"] = 0
	condition["revive"] = {}
	condition["lastRevivedAtMs"] = int(payload.get("revivedAtMs", _now_ms()))
	player_conditions[player_id] = condition


func on_player_dead(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	if player_id.is_empty():
		return

	var condition := _get_or_create_condition(player_id)
	condition["status"] = STATUS_DEAD
	condition["bleedoutEndMs"] = 0
	condition["revive"] = {}
	player_conditions[player_id] = condition


func set_local_status(player_id: String, status: String, bleedout_end_ms: int = 0) -> void:
	if player_id.is_empty():
		return

	var condition := _get_or_create_condition(player_id)
	condition["status"] = status
	condition["bleedoutEndMs"] = bleedout_end_ms
	if status != STATUS_DOWNED:
		condition["revive"] = {}
	player_conditions[player_id] = condition


func get_player_condition(player_id: String) -> Dictionary:
	return _get_or_create_condition(player_id).duplicate()


func get_player_status(player_id: String) -> String:
	return str(_get_or_create_condition(player_id).get("status", STATUS_ALIVE))


func get_revive_state(player_id: String) -> Dictionary:
	var condition := _get_or_create_condition(player_id)
	var revive: Variant = condition.get("revive", {})
	if typeof(revive) != TYPE_DICTIONARY:
		return {}

	var revive_dict := revive as Dictionary
	if revive_dict.is_empty():
		return {"active": false}

	var started_at_ms := int(revive_dict.get("startedAtMs", 0))
	var duration_ms: int = maxi(1, int(revive_dict.get("durationMs", 3000)))
	var elapsed: int = maxi(0, _now_ms() - started_at_ms)
	var progress := clampf(float(elapsed) / float(duration_ms), 0.0, 1.0)

	return {
		"active": true,
		"reviverPlayerId": str(revive_dict.get("reviverPlayerId", "")),
		"startedAtMs": started_at_ms,
		"durationMs": duration_ms,
		"progress": progress,
		"remainingMs": maxi(0, duration_ms - elapsed),
	}


func find_revivable_target(
	remote_states: Dictionary,
	from_position: Vector2,
	max_distance: float,
	reviver_player_id: String,
) -> String:
	var best_id := ""
	var best_distance_sq := max_distance * max_distance

	for player_id in remote_states.keys():
		if str(player_id) == reviver_player_id:
			continue

		if get_player_status(str(player_id)) != STATUS_DOWNED:
			continue

		var revive_state := get_revive_state(str(player_id))
		if bool(revive_state.get("active", false)) and str(revive_state.get("reviverPlayerId", "")) != reviver_player_id:
			continue

		var state := remote_states[player_id] as Dictionary
		if not state.has("position"):
			continue

		var position: Vector2 = state.get("position", Vector2.ZERO)
		var distance_sq := from_position.distance_squared_to(position)
		if distance_sq > best_distance_sq:
			continue

		best_distance_sq = distance_sq
		best_id = str(player_id)

	return best_id


func _get_or_create_condition(player_id: String) -> Dictionary:
	if player_conditions.has(player_id):
		var existing: Variant = player_conditions[player_id]
		if typeof(existing) == TYPE_DICTIONARY:
			return existing

	return {
		"status": STATUS_ALIVE,
		"bleedoutEndMs": 0,
		"revive": {},
	}


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
