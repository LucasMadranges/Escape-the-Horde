class_name RemotePlayerFactory
extends RefCounted


static func create(player_id: String, username: String) -> CharacterBody2D:
	var holder := CharacterBody2D.new()
	holder.name = "Remote_%s" % player_id
	holder.scale = Vector2(4.0, 4.0)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _build_sprite_frames()
	sprite.play("idle_down")
	holder.add_child(sprite)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = username
	name_label.position = Vector2(-40, -34)
	holder.add_child(name_label)

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
