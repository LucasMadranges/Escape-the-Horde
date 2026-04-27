extends Area2D

@export var weapon_name: String = "Arme"
@export var price: int = 50
@export var weapon_id: String = "pistol"
@export var weapon_slot: int = 0  # 0 = leger (pistolet), 1 = lourd (fusil)

var player_inside := false
var _busy := false

@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not player_inside or _busy:
		return
	if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		_try_buy()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		_update_prompt()
		prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt_label.visible = false


func _update_prompt() -> void:
	if GameData.weapon_slots[weapon_slot] == weapon_id:
		prompt_label.text = "Deja equipe"
	else:
		prompt_label.text = "[E] Acheter — %d $" % price


func _try_buy() -> void:
	_busy = true
	if GameData.weapon_slots[weapon_slot] == weapon_id:
		prompt_label.text = "Deja equipe !"
		await get_tree().create_timer(1.0).timeout
	elif GameData.money >= price:
		GameData.money -= price
		GameData.weapon_slots[weapon_slot] = weapon_id
		if GameData.active_slot == weapon_slot:
			GameData.active_weapon = weapon_id
		prompt_label.text = "Equipe !"
		await get_tree().create_timer(0.8).timeout
	else:
		prompt_label.text = "Pas assez d'argent !"
		await get_tree().create_timer(1.5).timeout
	_busy = false
	if player_inside:
		_update_prompt()
