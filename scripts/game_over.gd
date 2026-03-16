extends Node2D


func _ready() -> void:
	$UI/CenterContainer/VBox/WaveLabel.text = "Vague atteinte : %d" % GameData.wave_reached
	$UI/CenterContainer/VBox/RetryButton.pressed.connect(func():
		GameData.wave_reached = 1
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	$UI/CenterContainer/VBox/MenuButton.pressed.connect(func():
		GameData.wave_reached = 1
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
