extends CanvasLayer

signal back_pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_checkmark_anim()
	var slider: HSlider = $CenterContainer/Panel/VBox/VolumeRow/VolumeSlider
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	slider.value_changed.connect(func(v: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(v)))
	$CenterContainer/Panel/VBox/FullscreenRow/CheckBody.gui_input.connect(_on_fs_toggle)
	$CenterContainer/Panel/VBox/BackButton.pressed.connect(func(): back_pressed.emit())
	_update_checkmark()


func _setup_checkmark_anim() -> void:
	var anim: AnimatedSprite2D = $CenterContainer/Panel/VBox/FullscreenRow/CheckBody/CheckAnim
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation("check")
	sf.set_animation_loop("check", false)
	sf.set_animation_speed("check", 12.0)
	var tex := load("res://assets/UI/Menu/Checkmark-Sheet5.png") as Texture2D
	if tex:
		for i in 5:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 7, 0, 7, 5)
			sf.add_frame("check", at)
	anim.sprite_frames = sf
	anim.scale = Vector2(4.0, 4.0)
	anim.position = Vector2(14.0, 14.0)


func _on_fs_toggle(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var is_fs := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if is_fs else DisplayServer.WINDOW_MODE_WINDOWED)
		_update_checkmark()


func _update_checkmark() -> void:
	var anim: AnimatedSprite2D = $CenterContainer/Panel/VBox/FullscreenRow/CheckBody/CheckAnim
	var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_fs:
		anim.show()
		anim.play("check")
	else:
		anim.hide()
