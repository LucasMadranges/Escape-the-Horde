extends Node2D

const COUNTDOWN_ALL := 3.0
const COUNTDOWN_PARTIAL := 30.0
const SYNC_INTERVAL := 0.25
const ZONE_COLOR := Color(0.2, 0.9, 0.3, 0.35)
const ZONE_BORDER_COLOR := Color(0.2, 1.0, 0.3, 0.9)

@onready var money_label: Label = $UI/MoneyLabel
@onready var exit_door: Area2D = $ExitDoor

var _local_in_zone := false
var _countdown: float = 0.0
var _counting := false
var _launched := false
var _sync_timer := 0.0
var _is_driver := false

var _zone_rect := Rect2(842.0, 240.0, 30.0, 140.0)
var _countdown_overlay: Control
var _countdown_label: Label
var _session_sync: Node
var _realtime: Node


func _ready() -> void:
	GameData.money += 1000
	exit_door.body_entered.connect(_on_zone_entered)
	exit_door.body_exited.connect(_on_zone_exited)
	_session_sync = get_node_or_null("SessionSync")
	_realtime = get_tree().root.get_node_or_null("RealtimeClient")
	if _realtime:
		if _realtime.has_signal("extraction_sync_received"):
			_realtime.extraction_sync_received.connect(_on_extraction_sync_received)
		if _realtime.has_signal("extraction_launch_received"):
			_realtime.extraction_launch_received.connect(_on_extraction_launch_received)
	_build_zone_visuals()
	_build_countdown_overlay()


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


func _process(delta: float) -> void:
	money_label.text = "Argent : %d $" % GameData.money

	if _launched:
		return

	if not _is_driver:
		return

	var total := _total_players()
	var in_zone := _count_in_zone()

	if in_zone == 0:
		_counting = false
		_countdown = 0.0
		_countdown_overlay.visible = false
		_sync_timer = 0.0
		return

	var target := COUNTDOWN_ALL if in_zone >= total else COUNTDOWN_PARTIAL

	if not _counting:
		_counting = true
		_countdown = target
	elif in_zone >= total and _countdown > COUNTDOWN_ALL:
		_countdown = COUNTDOWN_ALL

	_countdown = maxf(_countdown - delta, 0.0)
	_show_countdown(_countdown, in_zone, total)

	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		if _realtime:
			_realtime.send_extraction_sync(_countdown, in_zone, total)

	if _countdown <= 0.0:
		if _realtime:
			_realtime.send_extraction_launch()
		_do_launch()


func _count_in_zone() -> int:
	var count := 1 if _local_in_zone else 0
	count += _count_remote_in_zone()
	return count


func _count_remote_in_zone() -> int:
	if _session_sync == null or not _session_sync.has_method("get_player_states"):
		return 0
	var count := 0
	var local_id := ""
	if _session_sync.has_method("get_local_player_id"):
		local_id = _session_sync.get_local_player_id()
	var states: Dictionary = _session_sync.get_player_states()
	for pid in states:
		if str(pid) == local_id:
			continue
		var state := states[pid] as Dictionary
		var pos := state.get("position", Vector2.ZERO) as Vector2
		if _zone_rect.has_point(pos):
			count += 1
	return count


func _total_players() -> int:
	var local_count := get_tree().get_nodes_in_group("player").size()
	var remote_count := 0
	if _session_sync and _session_sync.has_method("get_player_states"):
		var local_id := ""
		if _session_sync.has_method("get_local_player_id"):
			local_id = _session_sync.get_local_player_id()
		for pid in _session_sync.get_player_states():
			if str(pid) != local_id:
				remote_count += 1
	return max(local_count + remote_count, 1)


func _show_countdown(seconds: float, in_zone: int, total: int) -> void:
	_countdown_overlay.visible = true
	var secs := ceili(seconds)
	if in_zone >= total:
		_countdown_label.text = "Départ dans\n%d" % secs
		_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	else:
		_countdown_label.text = "Extraction\n%d / %d joueurs\n%d s" % [in_zone, total, secs]
		_countdown_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))


func _on_extraction_sync_received(payload: Dictionary) -> void:
	if _is_driver or _launched:
		return
	var countdown := float(payload.get("countdown", 0.0))
	var in_zone := int(payload.get("inZone", 0))
	var total := int(payload.get("total", 1))
	_show_countdown(countdown, in_zone, total)


func _on_extraction_launch_received() -> void:
	if _launched:
		return
	_do_launch()


func _on_zone_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_local_in_zone = true
	_is_driver = true


func _on_zone_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_local_in_zone = false


func _do_launch() -> void:
	_launched = true
	var level_scenes := {
		1: "res://scenes/main.tscn",
		2: "res://scenes/level_2.tscn",
	}
	var target: String = level_scenes.get(GameData.current_level, "res://scenes/main.tscn")
	get_tree().change_scene_to_file(target)
