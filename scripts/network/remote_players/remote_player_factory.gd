class_name RemotePlayerFactory
extends RefCounted


static func create(player_id: String, username: String, player_scale: Vector2 = Vector2(4.0, 4.0)) -> CharacterBody2D:
	var holder := CharacterBody2D.new()
	holder.name = "Remote_%s" % player_id
	holder.scale = player_scale

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _build_sprite_frames()
	sprite.play("idle_down")
	holder.add_child(sprite)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = username
	name_label.scale = Vector2(0.25, 0.25)
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.position = Vector2(-25, -26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	holder.add_child(name_label)

	var status_label := Label.new()
	status_label.name = "Status"
	status_label.text = ""
	status_label.position = Vector2(-34, -46)
	status_label.scale = Vector2(0.45, 0.45)
	status_label.modulate = Color(1.0, 0.6, 0.6)
	holder.add_child(status_label)

	var revive_bar := ProgressBar.new()
	revive_bar.name = "ReviveBar"
	revive_bar.min_value = 0.0
	revive_bar.max_value = 100.0
	revive_bar.value = 0.0
	revive_bar.show_percentage = false
	revive_bar.custom_minimum_size = Vector2(84, 8)
	revive_bar.position = Vector2(-42, -58)
	revive_bar.scale = Vector2(0.25, 0.25)
	revive_bar.visible = false
	holder.add_child(revive_bar)

	return holder


static func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.clear_all()
	_add_anim(sf, "idle_down", "res://assets/Character/Main/Idle/Character_down_idle-Sheet6.png", 6, 13, 16)
	_add_anim(sf, "run_down", "res://assets/Character/Main/Run/Character_down_run-Sheet6.png", 6, 13, 17)
	_add_anim(sf, "idle_side", "res://assets/Character/Main/Idle/Character_side_idle-Sheet6.png", 6, 12, 16)
	_add_anim(sf, "run_side", "res://assets/Character/Main/Run/Character_side_run-Sheet6.png", 6, 14, 17)
	_add_anim(sf, "idle_up", "res://assets/Character/Main/Idle/Character_up_idle-Sheet6.png", 6, 11, 16)
	_add_anim(sf, "run_up", "res://assets/Character/Main/Run/Character_up_run-Sheet6.png", 6, 13, 17)
	return sf


static func _add_anim(sf: SpriteFrames, anim: String, path: String, n: int, fw: int, fh: int, fps := 8.0) -> void:
	var tex := load(path) as Texture2D
	if not tex:
		return

	sf.add_animation(anim)
	sf.set_animation_loop(anim, true)
	sf.set_animation_speed(anim, fps)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, at)
