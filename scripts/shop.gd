extends Node2D

@onready var money_label: Label = $UI/MoneyLabel
@onready var exit_door: Area2D = $ExitDoor

var _players_at_door: int = 0
var _door_prompt: Label


func _ready() -> void:
	GameData.money += 1000
	exit_door.body_entered.connect(_on_exit_entered)
	exit_door.body_exited.connect(_on_exit_exited)
	_build_door_prompt()


func _build_door_prompt() -> void:
	_door_prompt = Label.new()
	_door_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door_prompt.add_theme_font_size_override("font_size", 14)
	_door_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_door_prompt.add_theme_constant_override("outline_size", 3)
	_door_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_door_prompt.visible = false
	exit_door.add_child(_door_prompt)
	_door_prompt.position = Vector2(-80, -40)


func _process(_delta: float) -> void:
	money_label.text = "Argent : %d $" % GameData.money


func _required_players() -> int:
	return max(get_tree().get_nodes_in_group("player").size(), 1)


func _on_exit_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_players_at_door += 1
	_refresh_door_prompt()
	var needed := _required_players()
	if _players_at_door >= needed:
		_launch_next_level()


func _on_exit_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_players_at_door = max(_players_at_door - 1, 0)
	_refresh_door_prompt()


func _refresh_door_prompt() -> void:
	var needed := _required_players()
	if _players_at_door == 0:
		_door_prompt.visible = false
		return
	_door_prompt.visible = true
	if _players_at_door >= needed:
		_door_prompt.text = "Lancement..."
	else:
		_door_prompt.text = "%d / %d joueurs" % [_players_at_door, needed]


func _launch_next_level() -> void:
	var level_scenes := {
		1: "res://scenes/main.tscn",
		2: "res://scenes/level_2.tscn",
	}
	var target: String = level_scenes.get(GameData.current_level, "res://scenes/main.tscn")
	get_tree().change_scene_to_file(target)
