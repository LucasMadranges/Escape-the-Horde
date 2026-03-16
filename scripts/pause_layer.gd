extends CanvasLayer

@onready var pause_menu = $PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			pause_menu.close()
		else:
			pause_menu.open()
