extends RefCounted

const REMOTE_PLAYER_FACTORY_SCRIPT := preload("res://scripts/network/remote_players/remote_player_factory.gd")
const STATUS_ALIVE := "alive"
const STATUS_DOWNED := "downed"
const STATUS_DEAD := "dead"

var remote_players_root: Node2D
var remote_nodes := {}
var condition_store: RefCounted


func setup(remote_root: Node2D, store: RefCounted) -> void:
	remote_players_root = remote_root
	condition_store = store


func has(player_id: String) -> bool:
	return remote_nodes.has(player_id)


func ensure_player(player_id: String, username: String) -> void:
	if remote_nodes.has(player_id):
		var existing_label: Label = remote_nodes[player_id].get_node_or_null("Name")
		if existing_label:
			existing_label.text = username
		return

	var holder := REMOTE_PLAYER_FACTORY_SCRIPT.create(player_id, username)
	remote_players_root.add_child(holder)
	remote_nodes[player_id] = holder


func remove_player(player_id: String) -> void:
	if not remote_nodes.has(player_id):
		return

	var stale = remote_nodes[player_id]
	if is_instance_valid(stale):
		stale.queue_free()
	remote_nodes.erase(player_id)


func update_transform(player_id: String, position: Vector2, velocity: Vector2) -> void:
	if not remote_nodes.has(player_id):
		return

	var node = remote_nodes[player_id]
	if node == null:
		return

	node.global_position = position
	_update_animation(node, velocity)


func get_player_ids() -> Array:
	return remote_nodes.keys()


func update_status_visuals() -> void:
	for player_id in remote_nodes.keys():
		var node = remote_nodes[player_id]
		if not is_instance_valid(node):
			continue

		var condition: Dictionary = condition_store.get_player_condition(str(player_id))
		var status := str(condition.get("status", STATUS_ALIVE))
		node.visible = status != STATUS_DEAD
		var sprite: AnimatedSprite2D = node.get_node_or_null("AnimatedSprite2D")
		var status_label: Label = node.get_node_or_null("Status")
		var revive_bar: ProgressBar = node.get_node_or_null("ReviveBar")

		if sprite:
			if status == STATUS_DOWNED:
				sprite.modulate = Color(1.0, 0.55, 0.55)
			elif status == STATUS_DEAD:
				sprite.modulate = Color(0.55, 0.55, 0.55)
			else:
				sprite.modulate = Color.WHITE

		if status_label:
			if status == STATUS_DOWNED:
				var remaining: float = maxf(0.0, (float(condition.get("bleedoutEndMs", 0)) - float(_now_ms())) / 1000.0)
				status_label.text = "KO %.1fs" % remaining
			elif status == STATUS_DEAD:
				status_label.text = "MORT"
			else:
				status_label.text = ""

		if revive_bar:
			var revive_state: Dictionary = condition_store.get_revive_state(str(player_id))
			if status == STATUS_DOWNED and not revive_state.is_empty() and bool(revive_state.get("active", false)):
				revive_bar.visible = true
				revive_bar.value = float(revive_state.get("progress", 0.0)) * 100.0
			else:
				revive_bar.visible = false


func play_revive_effect(player_id: String) -> void:
	if not remote_nodes.has(player_id):
		return

	var node = remote_nodes[player_id]
	if not is_instance_valid(node):
		return

	var sprite: AnimatedSprite2D = node.get_node_or_null("AnimatedSprite2D")
	if sprite == null:
		return

	sprite.modulate = Color(0.55, 1.0, 0.55)
	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.35)


func get_alive_remote_nodes() -> Array:
	var nodes: Array = []

	for player_id in remote_nodes.keys():
		if condition_store.get_player_status(str(player_id)) == STATUS_DEAD:
			continue

		var node = remote_nodes[player_id]
		if is_instance_valid(node):
			nodes.append(node)

	return nodes


func _update_animation(node: Node2D, velocity: Vector2) -> void:
	var sprite: AnimatedSprite2D = node.get_node_or_null("AnimatedSprite2D")
	if sprite == null:
		return

	var moving := velocity.length_squared() > 1.0
	if abs(velocity.x) > abs(velocity.y):
		sprite.flip_h = velocity.x < 0.0
		sprite.play("run_side" if moving else "idle_side")
	elif velocity.y > 0.0:
		sprite.flip_h = false
		sprite.play("run_down" if moving else "idle_down")
	else:
		sprite.flip_h = false
		sprite.play("run_up" if moving else "idle_up")


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
