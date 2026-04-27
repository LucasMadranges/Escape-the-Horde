extends StaticBody2D

@onready var col: CollisionShape2D = $Col
@onready var visual: Polygon2D = $Visual
@onready var trigger: Area2D = $TriggerArea


func _ready() -> void:
	trigger.monitoring = false
	trigger.body_entered.connect(_on_body_entered)


func open() -> void:
	col.set_deferred("disabled", true)
	visual.color = Color(0.1, 0.85, 0.2, 1)
	trigger.monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameData.current_level += 1
	if GameData.current_level > 5:
		GameData.current_level = 1
		GameData.wave_reached = 1
		GameData.money = 0
		GameData.weapon_slots = ["pistol", ""]
		GameData.active_slot = 0
		GameData.active_weapon = "pistol"
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/shop.tscn")
