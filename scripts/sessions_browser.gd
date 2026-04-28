extends Control

const MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const WAITING_ROOM_SCENE_PATH := "res://scenes/waiting_room.tscn"
const REALTIME_CLIENT_SCRIPT := preload("res://scripts/network/realtime_client.gd")
const REALTIME_CONFIG_SCRIPT := preload("res://scripts/network/realtime/realtime_config.gd")
const REALTIME_GAME_DISCOVERY_SCRIPT := preload("res://scripts/network/realtime/realtime_game_discovery.gd")

@onready var game_id_filter: LineEdit = $UI/Panel/Margin/VBox/Filters/GameIdFilter
@onready var status_filter: OptionButton = $UI/Panel/Margin/VBox/Filters/StatusFilter
@onready var min_players_filter: SpinBox = $UI/Panel/Margin/VBox/Filters/MinPlayersFilter
@onready var refresh_button: Button = $UI/Panel/Margin/VBox/Filters/RefreshButton
@onready var sessions_list: VBoxContainer = $UI/Panel/Margin/VBox/ListPanel/ListScroll/SessionsList
@onready var info_label: Label = $UI/Panel/Margin/VBox/InfoLabel
@onready var back_button: Button = $UI/Panel/Margin/VBox/Footer/BackButton
@onready var panel: PanelContainer = $UI/Panel

const HEADER_TEXT_COLOR := Color(0.78, 0.84, 0.95)
const TEXT_DIM := Color(0.72, 0.76, 0.86)
const ROW_BG_A := Color(0.08, 0.09, 0.13, 0.95)
const ROW_BG_B := Color(0.06, 0.07, 0.11, 0.95)
const ROW_BORDER := Color(0.18, 0.2, 0.28, 0.8)
const PANEL_BG := Color(0.06, 0.07, 0.11, 0.92)
const PANEL_BORDER := Color(0.2, 0.22, 0.32, 0.8)
const JOIN_BG := Color(0.12, 0.55, 0.42)
const JOIN_BG_HOVER := Color(0.16, 0.62, 0.48)
const JOIN_BG_PRESSED := Color(0.08, 0.45, 0.35)
const JOIN_BG_DISABLED := Color(0.12, 0.14, 0.18)

var realtime_client: Node
var http_request: HTTPRequest
var sessions: Array = []
var loading := false


func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	_setup_panel_style()
	_setup_filters()
	_setup_actions()
	_reload_sessions()


func _setup_realtime_client() -> void:
	if realtime_client != null and is_instance_valid(realtime_client):
		return

	var existing := get_tree().root.get_node_or_null("RealtimeClient")
	if existing:
		realtime_client = existing
	else:
		realtime_client = REALTIME_CLIENT_SCRIPT.new()
		realtime_client.name = "RealtimeClient"
		get_tree().root.call_deferred("add_child", realtime_client)

	if realtime_client.has_signal("joined") and not realtime_client.joined.is_connected(_on_joined):
		realtime_client.joined.connect(_on_joined)
	if realtime_client.has_signal("realtime_error") and not realtime_client.realtime_error.is_connected(_on_realtime_error):
		realtime_client.realtime_error.connect(_on_realtime_error)


func _setup_filters() -> void:
	status_filter.clear()
	status_filter.add_item("Waiting", 0)
	status_filter.add_item("Started", 1)
	status_filter.add_item("All", 2)
	status_filter.selected = 0

	min_players_filter.min_value = 0
	min_players_filter.max_value = 8
	min_players_filter.step = 1
	min_players_filter.value = 1


func _setup_actions() -> void:
	refresh_button.pressed.connect(_reload_sessions)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE_PATH))
	game_id_filter.text_changed.connect(func(_t: String): _render_filtered_sessions())
	status_filter.item_selected.connect(func(_idx: int): _render_filtered_sessions())
	min_players_filter.value_changed.connect(func(_v: float): _render_filtered_sessions())


func _reload_sessions() -> void:
	if loading:
		return
	if http_request == null or not is_instance_valid(http_request):
		return
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	loading = true
	refresh_button.disabled = true
	info_label.text = "Chargement des sessions..."

	var result: Dictionary = await REALTIME_GAME_DISCOVERY_SCRIPT.list_open_sessions(
		http_request,
		REALTIME_CONFIG_SCRIPT.GAMES_API_URL,
		REALTIME_CONFIG_SCRIPT.SESSIONS_API_URL,
	)
	if not is_inside_tree():
		return

	loading = false
	refresh_button.disabled = false

	if not bool(result.get("ok", false)):
		sessions = []
		info_label.text = "Erreur: %s" % str(result.get("error", "unknown"))
		_render_filtered_sessions()
		return

	sessions = result.get("sessions", [])
	_render_filtered_sessions()


func _render_filtered_sessions() -> void:
	for child in sessions_list.get_children():
		child.queue_free()

	_add_header_row()

	var filtered_count := 0
	var row_index := 0
	for session_variant in sessions:
		if typeof(session_variant) != TYPE_DICTIONARY:
			continue

		var session: Dictionary = session_variant
		if not _matches_filters(session):
			continue

		filtered_count += 1
		_add_session_row(session, row_index)
		row_index += 1

	if filtered_count == 0:
		var empty_label := Label.new()
		empty_label.text = "Aucune session ne correspond aux filtres."
		empty_label.modulate = TEXT_DIM
		sessions_list.add_child(empty_label)

	info_label.text = "%d session(s) affichee(s)" % filtered_count


func _matches_filters(session: Dictionary) -> bool:
	var game_id := str(session.get("gameId", ""))
	var status := str(session.get("status", ""))
	var players := int(session.get("playerCount", 0))
	var query := game_id_filter.text.strip_edges().to_lower()

	if not query.is_empty() and game_id.to_lower().find(query) == -1:
		return false

	var selected := status_filter.get_selected_id()
	if selected == 0 and status != "waiting":
		return false
	if selected == 1 and status != "started":
		return false

	if players < int(min_players_filter.value):
		return false

	return true


func _add_session_row(session: Dictionary, row_index: int) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_row_style(row_index))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var game_id := str(session.get("gameId", ""))
	var status := str(session.get("status", "unknown"))
	var players := int(session.get("playerCount", 0))
	var created_at := str(session.get("createdAt", ""))

	var id_label := Label.new()
	var short_len: int = mini(8, game_id.length())
	id_label.text = "ID: %s" % game_id.substr(0, short_len)
	id_label.tooltip_text = game_id
	id_label.custom_minimum_size = Vector2(170, 0)
	id_label.modulate = TEXT_DIM
	row.add_child(id_label)

	var status_label := Label.new()
	status_label.text = _format_status(status)
	status_label.custom_minimum_size = Vector2(110, 0)
	status_label.modulate = _status_color(status)
	row.add_child(status_label)

	var players_label := Label.new()
	players_label.text = "Joueurs: %d" % players
	players_label.custom_minimum_size = Vector2(110, 0)
	players_label.modulate = TEXT_DIM
	row.add_child(players_label)

	var date_label := Label.new()
	date_label.text = "Creee: %s" % _format_date(created_at)
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.modulate = TEXT_DIM
	row.add_child(date_label)

	var join_button := Button.new()
	join_button.text = "Rejoindre"
	join_button.disabled = status != "waiting"
	join_button.custom_minimum_size = Vector2(120, 36)
	join_button.add_theme_stylebox_override("normal", _make_join_style(JOIN_BG, ROW_BORDER))
	join_button.add_theme_stylebox_override("hover", _make_join_style(JOIN_BG_HOVER, ROW_BORDER))
	join_button.add_theme_stylebox_override("pressed", _make_join_style(JOIN_BG_PRESSED, ROW_BORDER))
	join_button.add_theme_stylebox_override("disabled", _make_join_style(JOIN_BG_DISABLED, ROW_BORDER))
	join_button.add_theme_color_override("font_color", Color(1, 1, 1))
	join_button.add_theme_color_override("font_color_disabled", Color(0.7, 0.74, 0.82))
	join_button.pressed.connect(func(): _join_session(game_id))
	row.add_child(join_button)

	card.add_child(row)
	sessions_list.add_child(card)


func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)


func _add_header_row() -> void:
	var header_card := PanelContainer.new()
	header_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.9)
	style.border_color = ROW_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	header_card.add_theme_stylebox_override("panel", style)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 12)

	var id_label := Label.new()
	id_label.text = "SESSION"
	id_label.custom_minimum_size = Vector2(170, 0)
	id_label.modulate = HEADER_TEXT_COLOR
	header.add_child(id_label)

	var status_label := Label.new()
	status_label.text = "STATUS"
	status_label.custom_minimum_size = Vector2(110, 0)
	status_label.modulate = HEADER_TEXT_COLOR
	header.add_child(status_label)

	var players_label := Label.new()
	players_label.text = "JOUEURS"
	players_label.custom_minimum_size = Vector2(110, 0)
	players_label.modulate = HEADER_TEXT_COLOR
	header.add_child(players_label)

	var date_label := Label.new()
	date_label.text = "CREEE"
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.modulate = HEADER_TEXT_COLOR
	header.add_child(date_label)

	var action_label := Label.new()
	action_label.text = "ACTION"
	action_label.custom_minimum_size = Vector2(120, 0)
	action_label.modulate = HEADER_TEXT_COLOR
	header.add_child(action_label)

	header_card.add_child(header)
	sessions_list.add_child(header_card)


func _make_row_style(row_index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG_A if row_index % 2 == 0 else ROW_BG_B
	style.border_color = ROW_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


func _make_join_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _format_status(status: String) -> String:
	if status == "waiting":
		return "Status: WAITING"
	if status == "started":
		return "Status: STARTED"
	return "Status: %s" % status.to_upper()


func _status_color(status: String) -> Color:
	if status == "waiting":
		return Color(0.4, 0.9, 0.7)
	if status == "started":
		return Color(0.98, 0.78, 0.35)
	return TEXT_DIM


func _format_date(raw: String) -> String:
	if raw.is_empty():
		return "-"
	var normalized := raw.replace("T", " ")
	normalized = normalized.replace("Z", "")
	if normalized.length() > 19:
		normalized = normalized.substr(0, 19)
	return normalized


func _join_session(game_id: String) -> void:
	if game_id.is_empty():
		return

	_setup_realtime_client()
	if realtime_client == null:
		info_label.text = "Impossible d'initialiser le realtime client."
		return

	info_label.text = "Connexion a la session..."
	if realtime_client.has_method("join_game_by_id"):
		realtime_client.join_game_by_id(game_id)


func _on_joined(_game_state: Dictionary) -> void:
	get_tree().change_scene_to_file(WAITING_ROOM_SCENE_PATH)


func _on_realtime_error(message: String) -> void:
	info_label.text = "Erreur realtime: %s" % message
