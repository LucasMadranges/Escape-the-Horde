class_name ZombieTargetSelector
extends RefCounted


static func select_nearest_target(zombie_position: Vector2, player_states: Dictionary) -> Dictionary:
	var best_player_id := ""
	var best_position := Vector2.ZERO
	var best_distance_sq := INF

	for player_id in player_states.keys():
		var state: Variant = player_states[player_id]
		if typeof(state) != TYPE_DICTIONARY:
			continue

		var state_dict := state as Dictionary
		if not state_dict.has("position"):
			continue
		if str(state_dict.get("status", "alive")) != "alive":
			continue

		var position: Vector2 = state_dict.get("position", Vector2.ZERO)
		var distance_sq := zombie_position.distance_squared_to(position)
		if distance_sq >= best_distance_sq:
			continue

		best_distance_sq = distance_sq
		best_player_id = str(player_id)
		best_position = position

	if best_player_id.is_empty():
		return {}

	return {
		"playerId": best_player_id,
		"position": best_position,
	}
