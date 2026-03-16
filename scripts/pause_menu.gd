extends Node2D

@onready var settings_panel = $SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$CenterContainer/VBox/ResumeButton.pressed.connect(close)
	$CenterContainer/VBox/SettingsButton.pressed.connect(func(): settings_panel.show())
	$CenterContainer/VBox/QuitButton.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	settings_panel.back_pressed.connect(func(): settings_panel.hide())
	settings_panel.hide()


func open() -> void:
	get_tree().paused = true
	show()


func close() -> void:
	get_tree().paused = false
	hide()
