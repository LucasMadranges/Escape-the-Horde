extends Node2D

const WAITING_ROOM_SCENE_PATH := "res://scenes/waiting_room.tscn"
const SESSIONS_BROWSER_SCENE_PATH := "res://scenes/sessions_browser.tscn"

@onready var settings_panel = $UI/SettingsPanel
var realtime_client: Node


func _ready() -> void:
	var existing := get_tree().root.get_node_or_null("RealtimeClient")
	if existing:
		realtime_client = existing
	else:
		realtime_client = preload("res://scripts/network/realtime_client.gd").new()
		realtime_client.name = "RealtimeClient"
		get_tree().root.call_deferred("add_child", realtime_client)

	if not realtime_client.played.is_connected(_on_played):
		realtime_client.played.connect(_on_played)
	if not realtime_client.joined.is_connected(_on_joined):
		realtime_client.joined.connect(_on_joined)
	if not realtime_client.realtime_error.is_connected(_on_realtime_error):
		realtime_client.realtime_error.connect(_on_realtime_error)

	$UI/CenterContainer/VBox/UsernameInput.text_changed.connect(func(text: String) -> void:
		var trimmed := text.strip_edges()
		if not trimmed.is_empty():
			GameData.username = trimmed
			realtime_client.username = trimmed
	)

	$UI/CenterContainer/VBox/PlayButton.pressed.connect(
		func():
			_apply_username()
			realtime_client.play()
	)
	$UI/CenterContainer/VBox/JoinButton.pressed.connect(
		func():
			_apply_username()
			get_tree().change_scene_to_file(SESSIONS_BROWSER_SCENE_PATH)
	)
	$UI/CenterContainer/VBox/SettingsButton.pressed.connect(func(): settings_panel.show())
	$UI/CenterContainer/VBox/QuitButton.pressed.connect(func(): get_tree().quit())
	settings_panel.back_pressed.connect(func(): settings_panel.hide())
	settings_panel.hide()
	$UI/CenterContainer/VBox/TestShopButton.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/shop.tscn")
	)
	$UI/CenterContainer/VBox/TestLevel2Button.pressed.connect(
		func():
			GameData.current_level = 2
			get_tree().change_scene_to_file("res://scenes/level_2.tscn")
	)


func _apply_username() -> void:
	var input := $UI/CenterContainer/VBox/UsernameInput as LineEdit
	var trimmed := input.text.strip_edges()
	if not trimmed.is_empty():
		GameData.username = trimmed
		realtime_client.username = trimmed


func _on_played(_game_state: Dictionary) -> void:
	get_tree().change_scene_to_file(WAITING_ROOM_SCENE_PATH)


func _on_joined(_game_state: Dictionary) -> void:
	get_tree().change_scene_to_file(WAITING_ROOM_SCENE_PATH)


func _on_realtime_error(message: String) -> void:
	push_error("Realtime error: %s" % message)
