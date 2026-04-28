extends Node2D

const COUNTDOWN_ALL := 3.0
const COUNTDOWN_PARTIAL := 30.0
const ZONE_COLOR := Color(0.2, 0.9, 0.3, 0.35)
const ZONE_BORDER_COLOR := Color(0.2, 1.0, 0.3, 0.9)

@onready var money_label: Label = $UI/MoneyLabel
@onready var exit_door: Area2D = $ExitDoor

var _players_in_zone: int = 0
var _countdown: float = 0.0
var _counting: bool = false
var _launched: bool = false

var _zone_polygon: Polygon2D
var _zone_border: Line2D
var _countdown_label: Label
var _session_sync: Node

# ExitDoor position + Sh_Exit shape size (30x140)
var _zone_rect := Rect2(842.0, 240.0, 30.0, 140.0)


func _ready() -> void:
	GameData.money += 1000
	exit_door.body_entered.connect(_on_zone_entered)
	exit_door.body_exited.connect(_on_zone_exited)
	_session_sync = get_node_or_null("SessionSync")
	_build_zone_visuals()
	_build_countdown_label()


func _build_zone_visuals() -> void:
	var pts := PackedVector2Array([
		Vector2(_zone_rect.position.x, _zone_rect.position.y),
		Vector2(_zone_rect.end.x, _zone_rect.position.y),
		Vector2(_zone_rect.end.x, _zone_rect.end.y),
		Vector2(_zone_rect.position.x, _zone_rect.end.y),
	])

	_zone_polygon = Polygon2D.new()
	_zone_polygon.polygon = pts
	_zone_polygon.color = ZONE_COLOR
	add_child(_zone_polygon)
	move_child(_zone_polygon, 1)

	_zone_border = Line2D.new()
	_zone_border.points = PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	_zone_border.width = 3.0
	_zone_border.default_color = ZONE_BORDER_COLOR
	add_child(_zone_border)


func _build_countdown_label() -> void:
	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 22)
	_countdown_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	_countdown_label.add_theme_constant_override("outline_size", 4)
	_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_countdown_label.visible = false
	_countdown_label.position = Vector2(_zone_rect.position.x - 40.0, _zone_rect.position.y - 36.0)
	add_child(_countdown_label)


func _process(delta: float) -> void:
	money_label.text = "Argent : %d $" % GameData.money

	if _launched:
		return

	var total := _total_players()
	var in_zone := _players_in_zone + _count_remote_in_zone()

	if in_zone == 0:
		_counting = false
		_countdown = 0.0
		_countdown_label.visible = false
		return

	var target_time := COUNTDOWN_ALL if in_zone >= total else COUNTDOWN_PARTIAL

	if not _counting:
		_counting = true
		_countdown = target_time
	elif in_zone >= total and _countdown > COUNTDOWN_ALL:
		_countdown = COUNTDOWN_ALL

	_countdown = maxf(_countdown - delta, 0.0)
	_countdown_label.visible = true
	_countdown_label.text = "Départ dans\n%d s" % ceili(_countdown)

	if _countdown <= 0.0:
		_launch_next_level()


func _total_players() -> int:
	var local_count := get_tree().get_nodes_in_group("player").size()
	var remote_count := 0
	if _session_sync and _session_sync.has_method("get_player_states"):
		var states: Dictionary = _session_sync.get_player_states()
		var local_id := ""
		if _session_sync.has_method("get_local_player_id"):
			local_id = _session_sync.get_local_player_id()
		for pid in states:
			if str(pid) != local_id:
				remote_count += 1
	return max(local_count + remote_count, 1)


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


func _on_zone_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_players_in_zone += 1


func _on_zone_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_players_in_zone = max(_players_in_zone - 1, 0)
		if _players_in_zone == 0 and _count_remote_in_zone() == 0:
			_counting = false
			_countdown = 0.0


func _launch_next_level() -> void:
	_launched = true
	var level_scenes := {
		1: "res://scenes/main.tscn",
		2: "res://scenes/level_2.tscn",
	}
	var target: String = level_scenes.get(GameData.current_level, "res://scenes/main.tscn")
	get_tree().change_scene_to_file(target)
