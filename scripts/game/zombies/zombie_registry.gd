extends RefCounted

const ZOMBIE_TARGET_SELECTOR_SCRIPT := preload("res://scripts/game/zombies/zombie_target_selector.gd")
const ZOMBIE_SNAPSHOT_CODEC_SCRIPT := preload("res://scripts/game/zombies/zombie_snapshot_codec.gd")

var zombie_scene: PackedScene
var enemies_node: Node2D
var is_host := true
var zombies_by_id := {}
var suppress_kill_broadcast := {}

var on_zombie_died: Callable
var on_zombie_attack_player: Callable


func setup(
	zombie_scene_resource: PackedScene,
	enemies_root: Node2D,
	host: bool,
	zombie_died_callback: Callable,
	zombie_attack_callback: Callable,
) -> void:
	zombie_scene = zombie_scene_resource
	enemies_node = enemies_root
	is_host = host
	on_zombie_died = zombie_died_callback
	on_zombie_attack_player = zombie_attack_callback


func set_authority(host: bool) -> void:
	is_host = host
	for zombie in zombies_by_id.values():
		if is_instance_valid(zombie) and zombie.has_method("set_authoritative"):
			zombie.set_authoritative(is_host)


func spawn_at(spawn_pos: Vector2, zombie_id: String) -> void:
	if zombie_scene == null or enemies_node == null or zombie_id.is_empty() or zombies_by_id.has(zombie_id):
		return

	var zombie := zombie_scene.instantiate()
	zombie.global_position = spawn_pos
	zombie.zombie_id = zombie_id

	if zombie.has_method("set_authoritative"):
		zombie.set_authoritative(is_host)
	if zombie.has_signal("attack_player") and on_zombie_attack_player.is_valid():
		zombie.attack_player.connect(on_zombie_attack_player)
	if zombie.has_signal("died") and on_zombie_died.is_valid():
		zombie.died.connect(on_zombie_died)

	enemies_node.add_child(zombie)
	zombies_by_id[zombie_id] = zombie


func reconcile(zombies: Array) -> void:
	var expected_ids := {}

	for zombie_data in zombies:
		var parsed := ZOMBIE_SNAPSHOT_CODEC_SCRIPT.parse_snapshot(zombie_data)
		if parsed.is_empty():
			continue

		var zombie_id := str(parsed.get("zombieId", ""))
		if zombie_id.is_empty():
			continue

		expected_ids[zombie_id] = true
		var x := float(parsed.get("x", 0.0))
		var y := float(parsed.get("y", 0.0))
		spawn_at(Vector2(x, y), zombie_id)

		if is_host:
			continue

		var zombie = zombies_by_id.get(zombie_id)
		if zombie and zombie.has_method("apply_network_state"):
			zombie.apply_network_state(
				Vector2(x, y),
				Vector2(float(parsed.get("vx", 0.0)), float(parsed.get("vy", 0.0))),
				str(parsed.get("targetPlayerId", "")),
			)

	for zombie_id in zombies_by_id.keys():
		if expected_ids.has(zombie_id):
			continue

		remove_and_free(zombie_id, true)


func remove_and_free(zombie_id: String, suppress_broadcast := false) -> void:
	if zombie_id.is_empty() or not zombies_by_id.has(zombie_id):
		return

	var zombie = zombies_by_id[zombie_id]
	zombies_by_id.erase(zombie_id)
	if suppress_broadcast:
		suppress_kill_broadcast[zombie_id] = true

	if is_instance_valid(zombie):
		zombie.queue_free()


func erase_only(zombie_id: String) -> void:
	if zombie_id.is_empty():
		return
	zombies_by_id.erase(zombie_id)


func consume_suppress_kill(zombie_id: String) -> bool:
	if suppress_kill_broadcast.has(zombie_id):
		suppress_kill_broadcast.erase(zombie_id)
		return true
	return false


func has(zombie_id: String) -> bool:
	return zombies_by_id.has(zombie_id)


func update_targets(player_states: Dictionary) -> void:
	if not is_host or player_states.is_empty():
		return

	for zombie_id in zombies_by_id.keys():
		var zombie = zombies_by_id[zombie_id]
		if not is_instance_valid(zombie) or not zombie.has_method("set_target"):
			continue

		var target := ZOMBIE_TARGET_SELECTOR_SCRIPT.select_nearest_target(zombie.global_position, player_states)
		if target.is_empty():
			continue

		zombie.set_target(
			str(target.get("playerId", "")),
			target.get("position", zombie.global_position),
		)


func build_snapshots() -> Array:
	return ZOMBIE_SNAPSHOT_CODEC_SCRIPT.build_snapshots(zombies_by_id)
