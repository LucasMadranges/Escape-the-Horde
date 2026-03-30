extends Node2D

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

	$UI/CenterContainer/VBox/PlayButton.pressed.connect(
		func():
			realtime_client.play()
	)
	$UI/CenterContainer/VBox/JoinButton.pressed.connect(
		func():
			realtime_client.join_existing_game()
	)
	$UI/CenterContainer/VBox/SettingsButton.pressed.connect(func(): settings_panel.show())
	$UI/CenterContainer/VBox/QuitButton.pressed.connect(func(): get_tree().quit())
	settings_panel.back_pressed.connect(func(): settings_panel.hide())
	settings_panel.hide()


func _on_played(_game_state: Dictionary) -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_joined(_game_state: Dictionary) -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_realtime_error(message: String) -> void:
	push_error("Realtime error: %s" % message)
