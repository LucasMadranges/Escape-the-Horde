extends Node2D

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MENU_SCENE_PATH := "res://scenes/main_menu.tscn"

@onready var game_id_label: Label = $UI/Panel/Margin/VBox/GameIdLabel
@onready var room_status_label: Label = $UI/Panel/Margin/VBox/RoomStatusLabel
@onready var players_count_label: Label = $UI/Panel/Margin/VBox/PlayersCountLabel
@onready var players_list: VBoxContainer = $UI/Panel/Margin/VBox/PlayersPanel/PlayersScroll/PlayersList
@onready var launch_button: Button = $UI/Panel/Margin/VBox/Footer/LaunchButton
@onready var leave_button: Button = $UI/Panel/Margin/VBox/Footer/LeaveButton

var realtime_client: Node
var switched_to_game := false


func _ready() -> void:
	_setup_atmosphere()
	realtime_client = get_tree().root.get_node_or_null("RealtimeClient")
	if realtime_client == null:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
		return

	if realtime_client.has_signal("game_state_updated") and not realtime_client.game_state_updated.is_connected(_on_game_state):
		realtime_client.game_state_updated.connect(_on_game_state)
	if realtime_client.has_signal("played") and not realtime_client.played.is_connected(_on_game_state):
		realtime_client.played.connect(_on_game_state)
	if realtime_client.has_signal("joined") and not realtime_client.joined.is_connected(_on_game_state):
		realtime_client.joined.connect(_on_game_state)
	if realtime_client.has_signal("launched") and not realtime_client.launched.is_connected(_on_game_state):
		realtime_client.launched.connect(_on_game_state)
	if realtime_client.has_signal("realtime_error") and not realtime_client.realtime_error.is_connected(_on_realtime_error):
		realtime_client.realtime_error.connect(_on_realtime_error)

	launch_button.pressed.connect(_on_launch_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	var cached_state: Variant = realtime_client.get("last_game_state")
	if typeof(cached_state) == TYPE_DICTIONARY and not (cached_state as Dictionary).is_empty():
		_apply_state(cached_state)
	elif realtime_client.has_method("request_game_state"):
		realtime_client.request_game_state()


func _setup_atmosphere() -> void:
	# Teinte vespérale : mauve-orangé chaud, comme l'heure dorée qui bascule dans la nuit
	var canvas_mod := get_node_or_null("CanvasModulate") as CanvasModulate
	if canvas_mod == null:
		canvas_mod = CanvasModulate.new()
		add_child(canvas_mod)
	canvas_mod.color = Color(0.38, 0.22, 0.34)

	# Fond crépusculaire sur un CanvasLayer sous le reste
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)

	var gradient_rect := ColorRect.new()
	gradient_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	gradient_rect.color = Color(0.04, 0.03, 0.08)
	bg_layer.add_child(gradient_rect)

	# Lueur de coucher de soleil en bas de l'écran
	var glow := PointLight2D.new()
	glow.texture = _make_glow_texture(256)
	glow.texture_scale = 12.0
	glow.energy = 0.3
	glow.color = Color(1.0, 0.32, 0.08)
	glow.position = Vector2(0, 500)
	add_child(glow)


func _make_glow_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius: float = size * 0.5
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(x, y).distance_to(center)
			var alpha: float = clampf(1.0 - dist / radius, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(img)


func _on_game_state(game_state: Dictionary) -> void:
	_apply_state(game_state)


func _apply_state(game_state: Dictionary) -> void:
	if switched_to_game:
		return

	var game_id := str(game_state.get("gameId", realtime_client.get("current_game_id")))
	var status := str(game_state.get("status", "waiting"))
	var host_player_id := str(game_state.get("hostPlayerId", ""))
	var local_player_id := str(realtime_client.get("player_id"))
	var is_host := not host_player_id.is_empty() and host_player_id == local_player_id
	var players: Array = []
	var players_variant: Variant = game_state.get("players", [])
	if typeof(players_variant) == TYPE_ARRAY:
		players = players_variant
	var connected_count := 0

	game_id_label.text = "Session: %s" % game_id

	for child in players_list.get_children():
		child.queue_free()

	for player_variant in players:
		if typeof(player_variant) != TYPE_DICTIONARY:
			continue

		var player: Dictionary = player_variant
		var username := str(player.get("username", str(player.get("playerId", "unknown"))))
		var player_id := str(player.get("playerId", ""))
		var connected := bool(player.get("connected", false))
		if connected:
			connected_count += 1
		var tags := ""
		if player_id == host_player_id:
			tags += " [HOST]"
		if player_id == local_player_id:
			tags += " [YOU]"
		if not connected:
			tags += " [OFFLINE]"

		var row := Label.new()
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "- %s%s" % [username, tags]
		players_list.add_child(row)

	players_count_label.text = "Joueurs connectes: %d" % connected_count

	if status == "started":
		switched_to_game = true
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return

	if status == "finished":
		room_status_label.text = "La partie est terminee."
	else:
		room_status_label.text = "En attente des joueurs..."

	launch_button.visible = is_host
	launch_button.disabled = not (status == "waiting" and connected_count >= 2)
	if is_host:
		if launch_button.disabled:
			launch_button.text = "Lancer la partie (attendre 1 joueur)"
		else:
			launch_button.text = "Lancer la partie"


func _on_launch_pressed() -> void:
	if realtime_client and realtime_client.has_method("launch_game"):
		realtime_client.launch_game()


func _on_leave_pressed() -> void:
	if is_instance_valid(realtime_client):
		realtime_client.queue_free()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _on_realtime_error(message: String) -> void:
	room_status_label.text = "Erreur realtime: %s" % message
