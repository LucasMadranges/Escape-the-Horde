class_name ZombieSnapshotCodec
extends RefCounted


static func build_snapshots(zombies_by_id: Dictionary) -> Array:
	var snapshots: Array = []

	for zombie_id in zombies_by_id.keys():
		var zombie = zombies_by_id[zombie_id]
		if not is_instance_valid(zombie):
			continue

		var velocity := Vector2.ZERO
		if zombie is CharacterBody2D:
			velocity = zombie.velocity

		var target_player_id := ""
		if zombie.has_method("get_target_player_id"):
			target_player_id = str(zombie.get_target_player_id())

		snapshots.append({
			"zombieId": str(zombie_id),
			"x": zombie.global_position.x,
			"y": zombie.global_position.y,
			"vx": velocity.x,
			"vy": velocity.y,
			"targetPlayerId": target_player_id,
		})

	return snapshots


static func parse_snapshot(snapshot: Variant) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {}

	var item := snapshot as Dictionary
	var zombie_id := str(item.get("zombieId", ""))
	if zombie_id.is_empty():
		return {}

	return {
		"zombieId": zombie_id,
		"x": float(item.get("x", 0.0)),
		"y": float(item.get("y", 0.0)),
		"vx": float(item.get("vx", 0.0)),
		"vy": float(item.get("vy", 0.0)),
		"targetPlayerId": str(item.get("targetPlayerId", "")),
	}
