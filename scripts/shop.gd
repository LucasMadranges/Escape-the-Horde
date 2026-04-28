extends Node2D

const ZONE_COLOR := Color(0.2, 0.9, 0.3, 0.35)
const ZONE_BORDER_COLOR := Color(0.2, 1.0, 0.3, 0.9)

@onready var money_label: Label = $UI/MoneyLabel
@onready var exit_door: Area2D = $ExitDoor

var _launched := false
var _in_zone := false
var _countdown_overlay: Control
var _countdown_label: Label
var _session_sync: Node
var _realtime: Node

var _zone_rect := Rect2(842.0, 240.0, 30.0, 140.0)


func _ready() -> void:
	GameData.money += 1000
	exit_door.body_entered.connect(_on_zone_entered)
	exit_door.body_exited.connect(_on_zone_exited)
	_session_sync = get_node_or_null("SessionSync")
	_realtime = get_tree().root.get_node_or_null("RealtimeClient")
	if _realtime:
		if _realtime.has_signal("extraction_update_received"):
			_realtime.extraction_update_received.connect(_on_extraction_update)
		if _realtime.has_signal("extraction_launch_received"):
			_realtime.extraction_launch_received.connect(_on_extraction_launch)
	_build_zone_visuals()
	_build_countdown_overlay()


func _process(_delta: float) -> void:
	money_label.text = "Argent : %d $" % GameData.money


func _build_zone_visuals() -> void:
	var pts := PackedVector2Array([
		Vector2(_zone_rect.position.x, _zone_rect.position.y),
		Vector2(_zone_rect.end.x, _zone_rect.position.y),
		Vector2(_zone_rect.end.x, _zone_rect.end.y),
		Vector2(_zone_rect.position.x, _zone_rect.end.y),
	])
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = ZONE_COLOR
	add_child(poly)
	move_child(poly, 1)

	var border := Line2D.new()
	border.points = PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	border.width = 3.0
	border.default_color = ZONE_BORDER_COLOR
	add_child(border)

	var zone_label := Label.new()
	zone_label.text = "EXTRACTION"
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label.add_theme_font_size_override("font_size", 9)
	zone_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	zone_label.add_theme_constant_override("outline_size", 2)
	zone_label.add_theme_color_override("font_outline_color", Color.BLACK)
	zone_label.position = Vector2(_zone_rect.position.x - 14.0, _zone_rect.position.y - 16.0)
	add_child(zone_label)


func _build_countdown_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	_countdown_overlay = Control.new()
	_countdown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_overlay.visible = false
	canvas.add_child(_countdown_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_overlay.add_child(bg)

	_countdown_label = Label.new()
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 72)
	_countdown_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	_countdown_label.add_theme_constant_override("outline_size", 6)
	_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_countdown_overlay.add_child(_countdown_label)


func _on_zone_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _in_zone:
		return
	_in_zone = true
	if _realtime and _realtime.has_method("send_extraction_enter"):
		_realtime.send_extraction_enter(_total_players())


func _on_zone_exited(body: Node2D) -> void:
	if not body.is_in_group("player") or not _in_zone:
		return
	_in_zone = false
	if _realtime and _realtime.has_method("send_extraction_exit"):
		_realtime.send_extraction_exit(_total_players())


func _on_extraction_update(payload: Dictionary) -> void:
	if _launched:
		return
	var countdown := int(payload.get("countdown", 0))
	var in_zone := int(payload.get("inZone", 0))
	var total := int(payload.get("total", 1))

	if in_zone == 0:
		_countdown_overlay.visible = false
		return

	_countdown_overlay.visible = true
	if in_zone >= total:
		_countdown_label.text = "Départ dans\n%d" % countdown
		_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	else:
		_countdown_label.text = "%d / %d dans la zone\n%d s" % [in_zone, total, countdown]
		_countdown_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))


func _on_extraction_launch() -> void:
	if _launched:
		return
	_do_launch()


func _total_players() -> int:
	var local := get_tree().get_nodes_in_group("player").size()
	var remote := 0
	if _session_sync and _session_sync.has_method("get_player_states"):
		var local_id := ""
		if _session_sync.has_method("get_local_player_id"):
			local_id = _session_sync.get_local_player_id()
		for pid in _session_sync.get_player_states():
			if str(pid) != local_id:
				remote += 1
	return max(local + remote, 1)


func _do_launch() -> void:
	_launched = true
	var level_scenes := {
		1: "res://scenes/main.tscn",
		2: "res://scenes/level_2.tscn",
	}
	var target: String = level_scenes.get(GameData.current_level, "res://scenes/main.tscn")
	get_tree().change_scene_to_file(target)
