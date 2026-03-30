extends RefCounted

const WS_URL := "ws://127.0.0.1:3000/ws/game"
const GAMES_API_URL := "http://127.0.0.1:3000/api/games"
const SESSIONS_API_URL := "http://127.0.0.1:3000/api/sessions"

const EVENT_CONNECTED := "game:connected"
const EVENT_PLAYED := "game:played"
const EVENT_JOINED := "game:joined"
const EVENT_LAUNCHED := "game:launched"
const EVENT_STATE := "game:state"
const EVENT_ERROR := "game:error"

const SIGNALS_BY_EVENT := {
	"game:player_sync": "player_sync_received",
	"game:zombie_spawn": "zombie_spawn_received",
	"game:zombie_sync": "zombie_sync_received",
	"game:zombie_kill": "zombie_kill_received",
	"game:player_damage": "player_damage_received",
	"game:player_downed": "player_downed_received",
	"game:player_revive_started": "player_revive_started_received",
	"game:player_revive_canceled": "player_revive_canceled_received",
	"game:player_revived": "player_revived_received",
	"game:player_dead": "player_dead_received",
}
