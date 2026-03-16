extends Node

const SYNC_INTERVAL := 0.06

var realtime_client: Node
var remote_players_root: Node2D
var remote_nodes := {}
var sync_accumulator := 0.0
var local_player_id := ""

func _ready() -> void:
	remote_players_root = get_parent().get_node_or_null("RemotePlayers")
	realtime_client = get_tree().root.get_node_or_null("RealtimeClient")
	if realtime_client == null or remote_players_root == null:
		return

	local_player_id = str(realtime_client.get("player_id"))

	if realtime_client.has_signal("played") and not realtime_client.played.is_connected(_on_game_state_updated):
		realtime_client.played.connect(_on_game_state_updated)
	if realtime_client.has_signal("joined") and not realtime_client.joined.is_connected(_on_game_state_updated):
		realtime_client.joined.connect(_on_game_state_updated)
	if realtime_client.has_signal("game_state_updated") and not realtime_client.game_state_updated.is_connected(_on_game_state_updated):
		realtime_client.game_state_updated.connect(_on_game_state_updated)
	if realtime_client.has_signal("player_sync_received") and not realtime_client.player_sync_received.is_connected(_on_player_sync_received):
		realtime_client.player_sync_received.connect(_on_player_sync_received)

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

		alive_ids[player_id] = true
		_ensure_remote_player(player_id, str(player_data.get("username", player_id)))

	for id in remote_nodes.keys():
		if not alive_ids.has(id):
			var stale = remote_nodes[id]
			if is_instance_valid(stale):
				stale.queue_free()
			remote_nodes.erase(id)

func _on_player_sync_received(payload: Dictionary) -> void:
	var player_id := str(payload.get("playerId", ""))
	if player_id.is_empty() or player_id == local_player_id:
		return

	_ensure_remote_player(player_id, player_id)
	var node = remote_nodes.get(player_id)
	if node == null:
		return

	var x := float(payload.get("x", 0.0))
	var y := float(payload.get("y", 0.0))
	node.global_position = Vector2(x, y)

func _ensure_remote_player(player_id: String, username: String) -> void:
	if remote_nodes.has(player_id):
		var existing_label: Label = remote_nodes[player_id].get_node_or_null("Name")
		if existing_label:
			existing_label.text = username
		return

	var holder := Node2D.new()
	holder.name = "Remote_%s" % player_id

	var body := Polygon2D.new()
	body.name = "Body"
	body.color = Color(0.2, 0.75, 1.0, 0.9)
	body.polygon = PackedVector2Array([
		Vector2(-10, -10),
		Vector2(10, -10),
		Vector2(10, 10),
		Vector2(-10, 10),
	])
	holder.add_child(body)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = username
	name_label.position = Vector2(-40, -34)
	holder.add_child(name_label)

	remote_players_root.add_child(holder)
	remote_nodes[player_id] = holder
