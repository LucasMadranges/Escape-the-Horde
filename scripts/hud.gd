extends CanvasLayer

const MAX_HEALTH := 100
const WEAPON_NAMES := {"pistol": "Pistolet", "shotgun": "Pompe", "rifle": "Fusil"}
const WEAPON_ICON_PATHS := {
	"pistol":  "res://assets/UI/Inventory/Objects/Icon_Pistol.png",
	"shotgun": "res://assets/UI/Inventory/Objects/Icon_Shotgun.png",
	"rifle":   "res://assets/UI/Inventory/Objects/Icon_Gun.png",
}

# Color palette
const C_BG        := Color(0.06, 0.06, 0.10, 0.82)
const C_BORDER    := Color(1.0, 1.0, 1.0, 0.08)
const C_GOLD      := Color(1.0, 0.85, 0.25)
const C_RED       := Color(1.0, 0.32, 0.28)
const C_GRAY      := Color(0.60, 0.60, 0.65)
const C_WHITE     := Color(0.95, 0.95, 1.0)
const C_HP_GREEN  := Color(0.22, 0.82, 0.38)
const C_HP_WARN   := Color(0.95, 0.65, 0.15)
const C_HP_CRIT   := Color(0.95, 0.22, 0.22)
const C_HP_DARK   := Color(0.08, 0.08, 0.12, 0.9)
const C_WAVE_ACC  := Color(1.0, 0.78, 0.10)
const C_ENEMY_ACC := Color(0.95, 0.30, 0.25)

# Refs updated each frame
var _wave_lbl:   Label
var _enemy_lbl:  Label
var _hp_fill:    ColorRect
var _hp_lbl:     Label
var _hp_bar_bg:  ColorRect
var _hp_bar_w:   float = 140.0
var _hp_bar_x:   float = 48.0
var _slot_cell:  Array = []
var _slot_icon:  Array = []
var _slot_name:  Array = []
var _wave_root:  Control
var _enemy_root: Control

# Textures
var _tex_cell:   Texture2D
var _tex_chosen: Texture2D
var _tex_hp:     Texture2D
var _tex_hpbar:  Texture2D
var _icons:      Dictionary = {}

# Dirty cache
var _prev_hp      := -1
var _prev_wave    := -1
var _prev_enemies := -1
var _prev_slots   := ["__", "__"]
var _prev_active  := -1

var _player:  Node
var _enemies: Node
var _is_game  := false


func _ready() -> void:
	layer = 12
	_load_textures()
	_build()
	_init_context()


func _load_textures() -> void:
	var map := {
		"cell":   "res://assets/UI/Inventory/Inventory-Cell.png",
		"chosen": "res://assets/UI/Inventory/Inventory-Chosen.png",
		"hp":     "res://assets/UI/HP/HP.png",
		"hpbar":  "res://assets/UI/HP/HP-Bar.png",
	}
	for k in map:
		if ResourceLoader.exists(map[k]):
			var t := load(map[k]) as Texture2D
			match k:
				"cell":   _tex_cell   = t
				"chosen": _tex_chosen = t
				"hp":     _tex_hp     = t
				"hpbar":  _tex_hpbar  = t
	for wid in WEAPON_ICON_PATHS:
		var p: String = WEAPON_ICON_PATHS[wid]
		if ResourceLoader.exists(p):
			_icons[wid] = load(p) as Texture2D


func _init_context() -> void:
	var p := get_parent()
	if p == null:
		return
	_enemies  = p.get_node_or_null("Enemies")
	_is_game  = (p.get_node_or_null("GameManager") != null) and (_enemies != null)
	_wave_root.visible  = _is_game
	_enemy_root.visible = _is_game


# ─── BUILD ────────────────────────────────────────────────────────────────────

func _build() -> void:
	_build_wave()
	_build_enemies()
	_build_hp()
	_build_slots()


# Top-center wave badge
func _build_wave() -> void:
	const W  := 148.0
	const H  := 68.0
	const AH := 3.0   # accent height

	_wave_root = _panel(W, H, 0.5, 0.0, -W * 0.5, 0.0)
	add_child(_wave_root)

	# Gold accent strip at top
	var acc := ColorRect.new()
	acc.color = C_WAVE_ACC
	acc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	acc.offset_bottom = AH
	_wave_root.add_child(acc)

	var sub := _flat_lbl("VAGUE", 11, C_GRAY)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top    = AH + 6
	sub.offset_bottom = AH + 22
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_root.add_child(sub)

	_wave_lbl = _flat_lbl("1", 34, C_GOLD)
	_wave_lbl.add_theme_constant_override("outline_size", 3)
	_wave_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wave_lbl.offset_top    = AH + 20
	_wave_lbl.offset_bottom = 0
	_wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_wave_root.add_child(_wave_lbl)


# Top-right enemy counter
func _build_enemies() -> void:
	const W  := 148.0
	const H  := 68.0
	const AH := 3.0
	const M  := 12.0

	_enemy_root = _panel(W, H, 1.0, 0.0, -W - M, 0.0)
	add_child(_enemy_root)

	var acc := ColorRect.new()
	acc.color = C_ENEMY_ACC
	acc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	acc.offset_bottom = AH
	_enemy_root.add_child(acc)

	var sub := _flat_lbl("ENNEMIS", 11, C_GRAY)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top    = AH + 6
	sub.offset_bottom = AH + 22
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_root.add_child(sub)

	_enemy_lbl = _flat_lbl("0", 34, C_RED)
	_enemy_lbl.add_theme_constant_override("outline_size", 3)
	_enemy_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_lbl.offset_top    = AH + 20
	_enemy_lbl.offset_bottom = 0
	_enemy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_enemy_root.add_child(_enemy_lbl)


# Bottom-right HP bar — single row, all anchors=0 (absolute from panel top-left)
func _build_hp() -> void:
	const PANEL_W := 260.0
	const PANEL_H := 44.0
	const M       := 12.0
	const PAD     := 10.0
	const HEART_W := 28.0    # ♥ label column
	const NUM_W   := 62.0    # "100/100" column
	const GAP     := 6.0
	const BAR_H   := 12.0
	const BAR_X   := PAD + HEART_W + GAP          # 44
	const BAR_W   := PANEL_W - BAR_X - GAP - NUM_W - PAD  # 260-44-6-62-10 = 138
	const BAR_Y   := (PANEL_H - BAR_H) * 0.5

	var root := _panel(PANEL_W, PANEL_H, 1.0, 1.0, -PANEL_W - M, -PANEL_H - M)
	add_child(root)

	# ♥ label — much more reliable than texture with unknown aspect ratio
	var heart := _flat_lbl("♥", 20, Color(0.95, 0.25, 0.3))
	heart.anchor_left = 0.0; heart.anchor_right  = 0.0
	heart.anchor_top  = 0.0; heart.anchor_bottom = 0.0
	heart.offset_left   = PAD
	heart.offset_right  = PAD + HEART_W
	heart.offset_top    = 0.0
	heart.offset_bottom = PANEL_H
	heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	root.add_child(heart)

	# Bar track (dark bg)
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = C_HP_DARK
	_hp_bar_bg.anchor_left = 0.0; _hp_bar_bg.anchor_right  = 0.0
	_hp_bar_bg.anchor_top  = 0.0; _hp_bar_bg.anchor_bottom = 0.0
	_hp_bar_bg.offset_left   = BAR_X
	_hp_bar_bg.offset_right  = BAR_X + BAR_W
	_hp_bar_bg.offset_top    = BAR_Y
	_hp_bar_bg.offset_bottom = BAR_Y + BAR_H
	root.add_child(_hp_bar_bg)

	# Bar fill — offset_right shrinks in _tick_hp
	_hp_fill = ColorRect.new()
	_hp_fill.color = C_HP_GREEN
	_hp_fill.anchor_left = 0.0; _hp_fill.anchor_right  = 0.0
	_hp_fill.anchor_top  = 0.0; _hp_fill.anchor_bottom = 0.0
	_hp_fill.offset_left   = BAR_X
	_hp_fill.offset_right  = BAR_X + BAR_W
	_hp_fill.offset_top    = BAR_Y
	_hp_fill.offset_bottom = BAR_Y + BAR_H
	root.add_child(_hp_fill)

	# "100/100" numeric label
	_hp_lbl = _flat_lbl("100/100", 11, C_WHITE)
	_hp_lbl.anchor_left = 0.0; _hp_lbl.anchor_right  = 0.0
	_hp_lbl.anchor_top  = 0.0; _hp_lbl.anchor_bottom = 0.0
	_hp_lbl.offset_left   = BAR_X + BAR_W + GAP
	_hp_lbl.offset_right  = PANEL_W - PAD
	_hp_lbl.offset_top    = 0.0
	_hp_lbl.offset_bottom = PANEL_H
	_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_hp_lbl)

	_hp_bar_w = BAR_W
	_hp_bar_x = BAR_X


# Bottom-left weapon slots
func _build_slots() -> void:
	const W   := 82.0
	const H   := 96.0
	const GAP := 8.0
	const M   := 12.0

	for i in 2:
		var lx := M + i * (W + GAP)
		var rx := lx + W

		var cell := TextureRect.new()
		cell.texture = _tex_cell
		cell.stretch_mode = TextureRect.STRETCH_SCALE
		_anchor(cell, lx, rx, -H - M, -M, 0.0, 0.0, 1.0, 1.0)
		add_child(cell)
		_slot_cell.append(cell)

		var key := _flat_lbl("[%d]" % (i + 1), 11, Color(0.82, 0.74, 0.46))
		_anchor(key, lx + 4, rx - 4, -H - M + 4, -H - M + 18, 0.0, 0.0, 1.0, 1.0)
		add_child(key)

		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_anchor(icon, lx + 6, rx - 6, -H - M + 18, -M - 24, 0.0, 0.0, 1.0, 1.0)
		add_child(icon)
		_slot_icon.append(icon)

		var name_lbl := _flat_lbl("—", 10, Color(0.6, 0.6, 0.6))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_anchor(name_lbl, lx + 2, rx - 2, -M - 22, -M - 4, 0.0, 0.0, 1.0, 1.0)
		add_child(name_lbl)
		_slot_name.append(name_lbl)


# ─── UPDATE ───────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	_tick_hp()
	if _is_game:
		_tick_wave()
		_tick_enemies()
	_tick_weapons()


func _tick_hp() -> void:
	if not is_instance_valid(_player):
		return
	var hp := int(_player.get("health"))
	if hp == _prev_hp:
		return
	_prev_hp = hp
	var pct := clampf(float(hp) / MAX_HEALTH, 0.0, 1.0)

	# offset_right is absolute from panel left (anchor_right = 0) — no mixed-anchor issue
	_hp_fill.offset_right = _hp_bar_x + _hp_bar_w * pct

	_hp_fill.color = C_HP_CRIT if pct <= 0.25 else (C_HP_WARN if pct <= 0.5 else C_HP_GREEN)
	_hp_lbl.text = "%d/%d" % [hp, MAX_HEALTH]
	_hp_lbl.add_theme_color_override("font_color", C_HP_CRIT if pct <= 0.25 else C_WHITE)


func _tick_wave() -> void:
	var p := get_parent()
	if p == null:
		return
	var gm := p.get_node_or_null("GameManager")
	if gm == null:
		return
	var w := int(gm.get("wave"))
	if w == _prev_wave:
		return
	_prev_wave = w
	_wave_lbl.text = str(w)


func _tick_enemies() -> void:
	if not is_instance_valid(_enemies):
		return
	var c := _enemies.get_child_count()
	if c == _prev_enemies:
		return
	_prev_enemies = c
	_enemy_lbl.text = str(c)


func _tick_weapons() -> void:
	var active := GameData.active_slot
	var dirty  := (active != _prev_active)
	for i in 2:
		if GameData.weapon_slots[i] != _prev_slots[i]:
			dirty = true
	if not dirty:
		return
	_prev_active = active
	for i in 2:
		_prev_slots[i] = GameData.weapon_slots[i]
	for i in 2:
		var w: String = GameData.weapon_slots[i]
		var on := (i == active)
		_slot_cell[i].texture = (_tex_chosen if on else _tex_cell) as Texture2D
		_slot_icon[i].texture = _icons.get(w, null) as Texture2D
		if w != "":
			_slot_name[i].text = WEAPON_NAMES.get(w, w)
			_slot_name[i].add_theme_color_override("font_color",
				C_GOLD if on else Color(0.6, 0.6, 0.6))
		else:
			_slot_name[i].text = "—"
			_slot_name[i].add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))


# ─── HELPERS ──────────────────────────────────────────────────────────────────

# Creates a styled panel Control anchored to a viewport corner
# anchor_x / anchor_y = 0.0 or 1.0 for corner
# ox / oy = pixel offset from anchor point
func _panel(w: float, h: float, ax: float, ay: float, ox: float, oy: float) -> Control:
	var root := Control.new()
	root.anchor_left   = ax;  root.anchor_right  = ax
	root.anchor_top    = ay;  root.anchor_bottom = ay
	root.offset_left   = ox;      root.offset_right  = ox + w
	root.offset_top    = oy;      root.offset_bottom = oy + h

	# Subtle border (slightly lighter bg behind)
	var border := ColorRect.new()
	border.color = C_BORDER
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.offset_left = -1; border.offset_right  = 1
	border.offset_top  = -1; border.offset_bottom = 1
	root.add_child(border)

	# Main dark background
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	return root


func _flat_lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	return l


func _anchor(c: Control,
		ol: float, or_: float, ot: float, ob: float,
		al: float, ar: float, at: float, ab: float) -> void:
	c.anchor_left   = al;  c.anchor_right  = ar
	c.anchor_top    = at;  c.anchor_bottom = ab
	c.offset_left   = ol;  c.offset_right  = or_
	c.offset_top    = ot;  c.offset_bottom = ob
