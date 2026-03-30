extends Node

const REVIVE_RANGE := 72.0
const REVIVE_DURATION_MS := 3000
const KNOCKOUT_BLEEDOUT_MS := 30000
const STATUS_ALIVE := "alive"
const STATUS_DOWNED := "downed"
const STATUS_DEAD := "dead"
const PLAYER_STATUS_UI_FACTORY_SCRIPT := preload("res://scripts/game/player/player_status_ui_factory.gd")

enum LifeState {
	ALIVE,
	DOWNED,
	DEAD,
}

var player_ref: CharacterBody2D
var camera_ref: Camera2D
var session_sync: Node
var realtime_client: Node
var max_health := 100

var life_state := LifeState.ALIVE
var downed_end_at_ms := 0
var revive_target_player_id := ""
var revive_complete_sent := false
var spectate_index := 0

var ko_overlay: ColorRect
var ko_title_label: Label
var ko_subtitle_label: Label
var revive_prompt_label: Label
var revive_progress_bar: ProgressBar


func setup(player: CharacterBody2D, camera: Camera2D, max_health_value: int) -> void:
	player_ref = player
	camera_ref = camera
	max_health = max_health_value
	_setup_status_ui()

	session_sync = player_ref.get_parent().get_node_or_null("SessionSync")
	realtime_client = get_tree().root.get_node_or_null("RealtimeClient")
	if realtime_client:
		if realtime_client.has_signal("player_downed_received") and not realtime_client.player_downed_received.is_connected(_on_player_downed_received):
			realtime_client.player_downed_received.connect(_on_player_downed_received)
		if realtime_client.has_signal("player_revived_received") and not realtime_client.player_revived_received.is_connected(_on_player_revived_received):
			realtime_client.player_revived_received.connect(_on_player_revived_received)
		if realtime_client.has_signal("player_dead_received") and not realtime_client.player_dead_received.is_connected(_on_player_dead_received):
			realtime_client.player_dead_received.connect(_on_player_dead_received)

	_set_health(max_health)
	_set_life_state_name(STATUS_ALIVE)


func allows_player_control() -> bool:
	return life_state == LifeState.ALIVE


func blocks_input() -> bool:
	return life_state != LifeState.ALIVE


func process_update(_delta: float) -> void:
	match life_state:
		LifeState.ALIVE:
			_update_overlay_visibility(false)
			_handle_revive_input()
		LifeState.DOWNED:
			_update_downed_overlay()
			_cancel_revive(false)
			if _now_ms() >= downed_end_at_ms:
				_enter_dead(false)
		LifeState.DEAD:
			_update_dead_overlay()
			_cancel_revive(false)


func physics_update(delta: float) -> void:
	if life_state == LifeState.DEAD:
		_update_spectator_camera(delta)


func apply_damage(amount: int) -> void:
	if life_state != LifeState.ALIVE:
		return

	_set_health(_get_health() - amount)
	player_ref.modulate = Color(1, 0.2, 0.2)
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_instance_valid(player_ref):
			player_ref.modulate = Color.WHITE)

	if _get_health() <= 0:
		_enter_downed(false)


func _setup_status_ui() -> void:
	var ui: Dictionary = PLAYER_STATUS_UI_FACTORY_SCRIPT.build(player_ref)
	ko_overlay = ui.get("overlay") as ColorRect
	ko_title_label = ui.get("title") as Label
	ko_subtitle_label = ui.get("subtitle") as Label
	revive_prompt_label = ui.get("prompt") as Label
	revive_progress_bar = ui.get("progress") as ProgressBar


func _handle_revive_input() -> void:
	if session_sync == null or realtime_client == null:
		_hide_revive_ui()
		return

	var local_player_id := _get_local_player_id()
	if local_player_id.is_empty() or not session_sync.has_method("find_revivable_target"):
		_hide_revive_ui()
		return

	var target_id := str(session_sync.find_revivable_target(player_ref.global_position, REVIVE_RANGE, local_player_id))
	if target_id.is_empty():
		_cancel_revive(true)
		_hide_revive_ui()
		return

	revive_prompt_label.text = "Maintenir E pour revive"
	revive_prompt_label.visible = true

	if Input.is_physical_key_pressed(KEY_E):
		if revive_target_player_id != target_id:
			_start_revive(target_id)

		if session_sync.has_method("get_revive_state"):
			var revive_state: Dictionary = session_sync.get_revive_state(target_id)
			var active := bool(revive_state.get("active", false))
			var reviver_id := str(revive_state.get("reviverPlayerId", ""))
			if active and reviver_id == local_player_id:
				var progress := float(revive_state.get("progress", 0.0))
				revive_progress_bar.visible = true
				revive_progress_bar.value = progress * 100.0
				if progress >= 1.0 and not revive_complete_sent:
					revive_complete_sent = true
					realtime_client.send_player_revived(target_id)
			else:
				revive_progress_bar.visible = false
	else:
		if revive_target_player_id == target_id:
			_cancel_revive(true)
		_hide_revive_progress()


func _start_revive(target_player_id: String) -> void:
	if realtime_client == null:
		return

	revive_target_player_id = target_player_id
	revive_complete_sent = false
	realtime_client.send_player_revive_start(target_player_id, REVIVE_DURATION_MS)


func _cancel_revive(send_network_cancel: bool) -> void:
	if revive_target_player_id.is_empty():
		return

	if send_network_cancel and realtime_client:
		realtime_client.send_player_revive_cancel(revive_target_player_id)

	revive_target_player_id = ""
	revive_complete_sent = false
	_hide_revive_progress()


func _hide_revive_ui() -> void:
	revive_prompt_label.visible = false
	_hide_revive_progress()


func _hide_revive_progress() -> void:
	revive_progress_bar.visible = false
	revive_progress_bar.value = 0.0


func _enter_downed(from_network: bool, downed_at_ms: int = 0, duration_ms: int = KNOCKOUT_BLEEDOUT_MS) -> void:
	if life_state == LifeState.DEAD:
		return

	life_state = LifeState.DOWNED
	player_ref.visible = true
	_set_life_state_name(STATUS_DOWNED)
	_set_health(0)
	player_ref.velocity = Vector2.ZERO

	var started_at_ms := downed_at_ms if downed_at_ms > 0 else _now_ms()
	downed_end_at_ms = started_at_ms + maxi(1000, duration_ms)

	if session_sync and session_sync.has_method("set_local_player_status"):
		session_sync.set_local_player_status(STATUS_DOWNED, downed_end_at_ms)

	if not from_network and realtime_client:
		realtime_client.send_player_downed(duration_ms)


func _enter_alive_from_revive() -> void:
	life_state = LifeState.ALIVE
	player_ref.visible = true
	_set_life_state_name(STATUS_ALIVE)
	_set_health(int(max_health * 0.45))
	downed_end_at_ms = 0
	revive_target_player_id = ""
	revive_complete_sent = false
	_update_overlay_visibility(false)
	player_ref.modulate = Color(0.55, 1.0, 0.55)
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(player_ref):
			player_ref.modulate = Color.WHITE)

	if session_sync and session_sync.has_method("set_local_player_status"):
		session_sync.set_local_player_status(STATUS_ALIVE, 0)


func _enter_dead(from_network: bool) -> void:
	if life_state == LifeState.DEAD:
		return

	life_state = LifeState.DEAD
	player_ref.visible = false
	_set_life_state_name(STATUS_DEAD)
	_set_health(0)
	player_ref.velocity = Vector2.ZERO
	revive_target_player_id = ""
	revive_complete_sent = false
	_update_overlay_visibility(true)

	if session_sync and session_sync.has_method("set_local_player_status"):
		session_sync.set_local_player_status(STATUS_DEAD, 0)

	if not from_network and realtime_client:
		realtime_client.send_player_dead()


func _update_overlay_visibility(show_overlay: bool) -> void:
	if ko_overlay:
		ko_overlay.visible = show_overlay


func _update_downed_overlay() -> void:
	_update_overlay_visibility(true)
	ko_overlay.color = Color(0.45, 0.03, 0.03, 0.36)

	var remaining: float = maxf(0.0, (float(downed_end_at_ms) - float(_now_ms())) / 1000.0)
	ko_title_label.text = "KO"
	ko_subtitle_label.text = "Mort definitive dans %.1fs" % remaining


func _update_dead_overlay() -> void:
	_update_overlay_visibility(true)
	ko_overlay.color = Color(0.22, 0.03, 0.03, 0.52)
	ko_title_label.text = "MORT"
	ko_subtitle_label.text = "Mode spectateur (fleches gauche/droite pour changer de cible)"


func _update_spectator_camera(delta: float) -> void:
	if session_sync == null or not session_sync.has_method("get_alive_remote_nodes"):
		return

	var candidates: Array = session_sync.get_alive_remote_nodes()
	if candidates.is_empty():
		return

	if Input.is_action_just_pressed("ui_right"):
		spectate_index = (spectate_index + 1) % candidates.size()
	elif Input.is_action_just_pressed("ui_left"):
		spectate_index = (spectate_index - 1 + candidates.size()) % candidates.size()

	if spectate_index >= candidates.size():
		spectate_index = 0

	var target: Node2D = candidates[spectate_index]
	if not is_instance_valid(target):
		return

	camera_ref.global_position = camera_ref.global_position.lerp(target.global_position, clampf(delta * 5.0, 0.0, 1.0))


func _on_player_downed_received(payload: Dictionary) -> void:
	if _get_local_player_id() != str(payload.get("playerId", "")):
		return

	_enter_downed(
		true,
		int(payload.get("downedAtMs", _now_ms())),
		int(payload.get("bleedoutDurationMs", KNOCKOUT_BLEEDOUT_MS)),
	)


func _on_player_revived_received(payload: Dictionary) -> void:
	if _get_local_player_id() != str(payload.get("playerId", "")):
		return

	_enter_alive_from_revive()


func _on_player_dead_received(payload: Dictionary) -> void:
	if _get_local_player_id() != str(payload.get("playerId", "")):
		return

	_enter_dead(true)


func _get_local_player_id() -> String:
	if realtime_client == null:
		return ""
	return str(realtime_client.get("player_id"))


func _set_health(value: int) -> void:
	player_ref.health = max(0, value)


func _get_health() -> int:
	return int(player_ref.health)


func _set_life_state_name(value: String) -> void:
	player_ref.life_state_name = value


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
