extends Node2D

@onready var settings_panel = $UI/SettingsPanel


func _ready() -> void:
	$UI/CenterContainer/VBox/PlayButton.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	$UI/CenterContainer/VBox/SettingsButton.pressed.connect(func(): settings_panel.show())
	$UI/CenterContainer/VBox/QuitButton.pressed.connect(func(): get_tree().quit())
	settings_panel.back_pressed.connect(func(): settings_panel.hide())
	settings_panel.hide()
