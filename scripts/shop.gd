extends Node2D

@onready var money_label: Label = $UI/MoneyLabel
@onready var exit_door: Area2D = $ExitDoor


func _ready() -> void:
	GameData.money += 1000
	exit_door.body_entered.connect(_on_exit_entered)


func _process(_delta: float) -> void:
	money_label.text = "Argent : %d $" % GameData.money


func _on_exit_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://scenes/level_1.tscn")
