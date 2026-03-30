extends RefCounted

const REALTIME_CONFIG_SCRIPT := preload("res://scripts/network/realtime/realtime_config.gd")


static func dispatch(client: Node, event_name: String, data: Variant) -> void:
	match event_name:
		REALTIME_CONFIG_SCRIPT.EVENT_CONNECTED:
			client._on_connected_event(data)
		REALTIME_CONFIG_SCRIPT.EVENT_PLAYED:
			client._on_played_event(data)
		REALTIME_CONFIG_SCRIPT.EVENT_JOINED:
			client._on_joined_event(data)
		REALTIME_CONFIG_SCRIPT.EVENT_STATE:
			client._on_state_event(data)
		REALTIME_CONFIG_SCRIPT.EVENT_ERROR:
			client.emit_signal("realtime_error", str(data.get("message", "unknown")))
		"game:player_sync":
			client._on_player_sync_event(data)
		"game:zombie_spawn":
			client._on_zombie_spawn_event(data)
		"game:zombie_sync":
			client._on_zombie_sync_event(data)
		"game:zombie_kill":
			client._on_zombie_kill_event(data)
		"game:player_damage":
			client._on_player_damage_event(data)
		"game:player_downed":
			client._on_player_downed_event(data)
		"game:player_revive_started":
			client._on_player_revive_started_event(data)
		"game:player_revive_canceled":
			client._on_player_revive_canceled_event(data)
		"game:player_revived":
			client._on_player_revived_event(data)
		"game:player_dead":
			client._on_player_dead_event(data)
		_:
			pass
