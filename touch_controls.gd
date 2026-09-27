extends Control

# ============================================================
# UI THEME - modern mobile shooter style
# ============================================================
const UI_DARK := Color(0.05, 0.07, 0.11, 0.88)
const UI_BORDER := Color(0.60, 0.88, 1.0, 0.55)
const UI_TEXT := Color(0.94, 0.97, 1.0)
const UI_TEXT_DIM := Color(0.65, 0.75, 0.88)
const UI_ACCENT := Color(0.35, 0.88, 1.0)
const UI_DANGER := Color(1.0, 0.35, 0.35)

const BTN_FIRE := Color(0.92, 0.28, 0.28)
const BTN_JUMP := Color(0.28, 0.78, 0.42)
const BTN_RELOAD := Color(0.90, 0.64, 0.20)
const BTN_SWAP := Color(0.32, 0.55, 0.90)
const BTN_AIM := Color(0.82, 0.85, 0.92)
const BTN_CROUCH := Color(0.62, 0.35, 0.88)
const BTN_MIC := Color(0.28, 0.78, 0.55)

# ============================================================
# LAYOUT CONSTANTS
# ============================================================
const JOYSTICK_RADIUS := 100.0
const JOYSTICK_KNOB_RADIUS := 44.0
const BUTTON_RADIUS := 56.0

# ============================================================
# STATE
# ============================================================
var _player: CharacterBody3D = null

var _move_touch_id := -1
var _move_center := Vector2.ZERO
var _move_knob_pos := Vector2.ZERO

var _look_touch_id := -1
var _look_last_pos := Vector2.ZERO

var _fire_touch_id := -1
var _jump_touch_id := -1
var _reload_touch_id := -1
var _switch_touch_id := -1
var _crouch_touch_id := -1
var _ads_touch_id := -1
var _mic_touch_id := -1

var _wave: int = 1
var _lives: int = 3
var _kills: int = 0
var _score: int = 0
var _best_score: int = 0
var _best_wave: int = 0
var _loot_haul: int = 0
var _carry_ratio: float = 0.0
var extraction_progress: float = 0.0
var extraction_armed: bool = false

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport().get_visible_rect().size)
	mouse_filter = Control.MOUSE_FILTER_PASS
	get_viewport().size_changed.connect(_on_viewport_resized)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _on_viewport_resized() -> void:
	set_deferred("size", get_viewport().get_visible_rect().size)

func _process(delta: float) -> void:
	queue_redraw()


func set_lives(n: int) -> void:
	_lives = n
	queue_redraw()


func set_state(wave: int, kills: int, score: int = 0, best_score: int = 0, best_wave: int = 0, loot_haul: int = 0) -> void:
	_wave = wave
	_kills = kills
	_score = score
	_best_score = best_score
	_best_wave = best_wave
	_loot_haul = loot_haul

# ============================================================
# BUTTON POSITIONS
# ============================================================
func _joystick_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(JOYSTICK_RADIUS + 60, vp.y - JOYSTICK_RADIUS - 60)

func _fire_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS * 3 - 90, vp.y - BUTTON_RADIUS - 60)

func _jump_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS - 60, vp.y - BUTTON_RADIUS - 60)

func _reload_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS - 60, vp.y - BUTTON_RADIUS * 3 - 90)

func _switch_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS * 3 - 90, vp.y - BUTTON_RADIUS * 3 - 90)

func _crouch_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(JOYSTICK_RADIUS * 2.0 + 120.0, vp.y - JOYSTICK_RADIUS - 60.0)

func _ads_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS * 5.0 - 130.0, vp.y - BUTTON_RADIUS - 60.0)

func _mic_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x * 0.5, 110.0)

# ============================================================
# INPUT
# ============================================================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos := event.position
	if event.pressed:
		if pos.distance_to(_jump_center()) < BUTTON_RADIUS + 14:
			_jump_touch_id = event.index
			if _player:
				_player.touch_jump = true
			return
		if pos.distance_to(_fire_center()) < BUTTON_RADIUS + 14:
			_fire_touch_id = event.index
			if _player:
				_player.touch_fire = true
			return
		if pos.distance_to(_reload_center()) < BUTTON_RADIUS + 14:
			_reload_touch_id = event.index
			if _player:
				_player.call("_start_reload")
			return
		if pos.distance_to(_switch_center()) < BUTTON_RADIUS + 14:
			_switch_touch_id = event.index
			if _player:
				_player.call("switch_weapon")
			return
		if pos.distance_to(_crouch_center()) < BUTTON_RADIUS + 14:
			_crouch_touch_id = event.index
			if _player:
				_player.touch_crouch = true
			return
		if pos.distance_to(_ads_center()) < BUTTON_RADIUS + 14:
			_ads_touch_id = event.index
			if _player:
				_player.touch_aim = true
			return
		if pos.distance_to(_mic_center()) < BUTTON_RADIUS + 14:
			_mic_touch_id = event.index
			if Voice != null:
				Voice.set_transmitting(true)
			return
		var vp := get_viewport().get_visible_rect().size
		if pos.x < vp.x * 0.4 and pos.y > vp.y * 0.4:
			_move_touch_id = event.index
			_move_center = pos
			_move_knob_pos = pos
			queue_redraw()
			return
		if _look_touch_id == -1:
			_look_touch_id = event.index
			_look_last_pos = pos
	else:
		if event.index == _move_touch_id:
			_move_touch_id = -1
			_move_knob_pos = _move_center
			if _player:
				_player.touch_move = Vector2.ZERO
			queue_redraw()
		if event.index == _look_touch_id:
			_look_touch_id = -1
		if event.index == _jump_touch_id:
			_jump_touch_id = -1
		if event.index == _reload_touch_id:
			_reload_touch_id = -1
		if event.index == _switch_touch_id:
			_switch_touch_id = -1
		if event.index == _crouch_touch_id:
			_crouch_touch_id = -1
			if _player:
				_player.touch_crouch = false
		if event.index == _ads_touch_id:
			_ads_touch_id = -1
			if _player:
				_player.touch_aim = false
		if event.index == _mic_touch_id:
			_mic_touch_id = -1
			if Voice != null:
				Voice.set_transmitting(false)
		if event.index == _fire_touch_id:
			_fire_touch_id = -1
			if _player:
				_player.touch_fire = false

func _handle_drag(event: InputEventScreenDrag) -> void:
	var pos := event.position
	if event.index == _move_touch_id:
		var offset := pos - _move_center
		if offset.length() > JOYSTICK_RADIUS:
			offset = offset.normalized() * JOYSTICK_RADIUS
		_move_knob_pos = _move_center + offset
		if _player:
			_player.touch_move = Vector2(offset.x / JOYSTICK_RADIUS, offset.y / JOYSTICK_RADIUS)
		queue_redraw()
	elif event.index == _look_touch_id:
		var delta_look := pos - _look_last_pos
		_look_last_pos = pos
		if _player:
			_player.touch_look += delta_look

# ============================================================
# UI DRAWING
# ============================================================
func _ui_button(center: Vector2, radius: float, base: Color, icon: String, pressed: bool) -> void:
	var r := radius * (1.08 if pressed else 1.0)
	if pressed:
		# Outer glow ring when pressed
		draw_arc(center, r + 6, 0, TAU, 64, Color(base.r, base.g, base.b, 0.55), 5.0, true)
	draw_circle(center + Vector2(0, 5), r + 2, Color(0, 0, 0, 0.42))
	draw_circle(center, r, UI_DARK)
	var fill_col: Color = base
	fill_col.a = 0.95 if pressed else 0.62
	draw_circle(center, r - 3, fill_col)
	var hi: Color = Color(1, 1, 1, 0.22 if pressed else 0.10)
	draw_circle(center + Vector2(0, -r * 0.24), r * 0.50, hi)
	var border: Color = Color(1, 1, 1, 0.95) if pressed else UI_BORDER
	draw_arc(center, r - 1, 0, TAU, 64, border, 3.0, true)
	var icon_col: Color = Color(1, 1, 1, 0.98 if pressed else 0.90)
	_ui_icon(center, r * 0.42, icon, icon_col)

func _ui_icon(center: Vector2, size: float, icon: String, col: Color) -> void:
	var s := size
	match icon:
		"fire":
			draw_line(center + Vector2(-s * 0.70, s * 0.30), center + Vector2(0, -s * 0.50), col, 4.0, true)
			draw_line(center + Vector2( s * 0.70, s * 0.30), center + Vector2(0, -s * 0.50), col, 4.0, true)
			draw_line(center + Vector2(-s * 0.60, s * 0.65), center + Vector2(s * 0.60, s * 0.65), col, 4.0, true)
		"jump":
			draw_line(center + Vector2(0, s * 0.55), center + Vector2(0, -s * 0.50), col, 4.0, true)
			draw_line(center + Vector2(-s * 0.55, s * 0.05), center + Vector2(0, -s * 0.50), col, 4.0, true)
			draw_line(center + Vector2( s * 0.55, s * 0.05), center + Vector2(0, -s * 0.50), col, 4.0, true)
		"reload":
			draw_arc(center, s * 0.62, -PI * 0.35, PI * 1.30, 40, col, 3.6, true)
			var tip_x: float = center.x + cos(PI * 1.30) * s * 0.62
			var tip_y: float = center.y + sin(PI * 1.30) * s * 0.62
			draw_line(Vector2(tip_x, tip_y), Vector2(tip_x - s * 0.22, tip_y + s * 0.02), col, 3.6, true)
			draw_line(Vector2(tip_x, tip_y), Vector2(tip_x - s * 0.02, tip_y - s * 0.24), col, 3.6, true)
		"swap":
			draw_line(center + Vector2(-s * 0.35, -s * 0.45), center + Vector2(-s * 0.35, s * 0.50), col, 3.5, true)
			draw_line(center + Vector2(-s * 0.62, -s * 0.15), center + Vector2(-s * 0.35, -s * 0.45), col, 3.5, true)
			draw_line(center + Vector2(-s * 0.08, -s * 0.15), center + Vector2(-s * 0.35, -s * 0.45), col, 3.5, true)
			draw_line(center + Vector2( s * 0.35, s * 0.45), center + Vector2( s * 0.35, -s * 0.50), col, 3.5, true)
			draw_line(center + Vector2( s * 0.08, s * 0.15), center + Vector2( s * 0.35, s * 0.45), col, 3.5, true)
			draw_line(center + Vector2( s * 0.62, s * 0.15), center + Vector2( s * 0.35, s * 0.45), col, 3.5, true)
		"aim":
			draw_line(center + Vector2(-s * 0.80, 0), center + Vector2(-s * 0.28, 0), col, 3.0, true)
			draw_line(center + Vector2( s * 0.28, 0), center + Vector2( s * 0.80, 0), col, 3.0, true)
			draw_line(center + Vector2(0, -s * 0.80), center + Vector2(0, -s * 0.28), col, 3.0, true)
			draw_line(center + Vector2(0,  s * 0.28), center + Vector2(0,  s * 0.80), col, 3.0, true)
			draw_circle(center, 3.0, col)
		"crouch":
			draw_line(center + Vector2(0, -s * 0.55), center + Vector2(0, s * 0.50), col, 4.0, true)
			draw_line(center + Vector2(-s * 0.55, s * 0.05), center + Vector2(0, s * 0.50), col, 4.0, true)
			draw_line(center + Vector2( s * 0.55, s * 0.05), center + Vector2(0, s * 0.50), col, 4.0, true)
		"mic":
			var w := s * 0.34
			var h := s * 0.50
			draw_circle(center + Vector2(0, -h * 0.55), w, col)
			draw_rect(Rect2(center + Vector2(-w, -h * 0.55), Vector2(w * 2, h * 1.10)), col)
			draw_circle(center + Vector2(0, h * 0.55), w, col)
			draw_line(center + Vector2(0, h * 0.85), center + Vector2(0, h * 1.25), col, 3.0, true)
			draw_line(center + Vector2(-w * 0.9, h * 1.25), center + Vector2(w * 0.9, h * 1.25), col, 3.0, true)

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	_draw_joystick(vp)
	_draw_buttons(vp)
	_draw_weapon_hud(vp)
	_draw_hitmarker_and_numbers()
	_draw_extraction_hud()
	_draw_carry_bar(vp)
	_draw_hp_and_stats(vp)
	_draw_death_overlay(vp)

func _draw_joystick(vp: Vector2) -> void:
	var jc := _joystick_center()
	var active: bool = _move_touch_id != -1
	# Base ring
	var base_col := Color(0.10, 0.14, 0.20, 0.55)
	if active:
		base_col = Color(0.12, 0.18, 0.26, 0.65)
	draw_circle(jc, JOYSTICK_RADIUS, base_col)
	var ring_col := Color(0.55, 0.88, 1.0, 0.75)
	if active:
		ring_col = Color(0.65, 0.95, 1.0, 1.0)
	draw_arc(jc, JOYSTICK_RADIUS, 0, TAU, 64, ring_col, 4.0, true)
	# Knob follows finger
	var kp: Vector2 = jc
	if active:
		kp = _move_knob_pos
	# Direction indicator — a small line from center to knob when active
	if active:
		var dir := (kp - jc)
		if dir.length() > 4.0:
			draw_line(jc, kp, Color(0.55, 0.88, 1.0, 0.55), 3.0, true)
	# Knob body — bigger + brighter when active
	var knob_r := JOYSTICK_KNOB_RADIUS
	var knob_col := Color(0.32, 0.78, 1.0, 0.85)
	if active:
		knob_r = JOYSTICK_KNOB_RADIUS * 1.15
		knob_col = Color(0.55, 0.92, 1.0, 1.0)
		# Glow ring around knob
		draw_arc(kp, knob_r + 4, 0, TAU, 48, Color(0.55, 0.92, 1.0, 0.55), 4.0, true)
	draw_circle(kp, knob_r, knob_col)
	draw_arc(kp, knob_r, 0, TAU, 48, Color(1, 1, 1, 0.95), 3.0, true)
	# Small inner highlight
	draw_circle(kp + Vector2(0, -knob_r * 0.30), knob_r * 0.45, Color(1, 1, 1, 0.28))

func _draw_buttons(vp: Vector2) -> void:
	var fp := _fire_center()
	_ui_button(fp, BUTTON_RADIUS + 4, BTN_FIRE, "fire", _fire_touch_id != -1)
	var jp := _jump_center()
	_ui_button(jp, BUTTON_RADIUS + 4, BTN_JUMP, "jump", _jump_touch_id != -1)
	var rp := _reload_center()
	_ui_button(rp, BUTTON_RADIUS + 4, BTN_RELOAD, "reload", _reload_touch_id != -1)
	var sp := _switch_center()
	_ui_button(sp, BUTTON_RADIUS + 4, BTN_SWAP, "swap", _switch_touch_id != -1)
	var cp := _crouch_center()
	_ui_button(cp, 52.0, BTN_CROUCH, "crouch", _crouch_touch_id != -1)
	var ap := _ads_center()
	var aiming: bool = false
	if _player != null and is_instance_valid(_player):
		var a: Variant = _player.get("_aiming")
		if a != null:
			aiming = bool(a)
	_ui_button(ap, BUTTON_RADIUS + 4, BTN_AIM, "aim", _ads_touch_id != -1 or aiming)
	var mp := _mic_center()
	_ui_button(mp, BUTTON_RADIUS * 0.9, BTN_MIC, "mic", _mic_touch_id != -1)
	var font := ThemeDB.fallback_font
	draw_string(font, mp + Vector2(-54, -BUTTON_RADIUS * 0.9 - 12), "HOLD TO TALK", HORIZONTAL_ALIGNMENT_LEFT, 200, 13, UI_TEXT_DIM)

func _draw_hp_and_stats(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var hp: float = 0.0
	var max_hp: float = 100.0
	if _player != null and is_instance_valid(_player):
		var hp_v: Variant = _player.get("hp")
		if hp_v != null:
			hp = float(hp_v)
		var max_v: Variant = _player.get("max_hp")
		if max_v != null:
			max_hp = float(max_v)
	var hp_ratio: float = clamp(hp / max_hp, 0.0, 1.0)
	var bar_w := 240.0
	var bar_h := 22.0
	var bar_pos := Vector2(30, 30)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.55))
	var fill_col := Color(0.94, 0.27, 0.27)
	if hp_ratio < 0.35:
		fill_col = Color(1.0, 0.20, 0.20)
	draw_rect(Rect2(bar_pos + Vector2(2, 2), Vector2((bar_w - 4) * hp_ratio, bar_h - 4)), fill_col)
	draw_string(font, Vector2(vp.x - 260, 52), "SCORE " + str(_score), HORIZONTAL_ALIGNMENT_RIGHT, 240, 26, Color(0.55, 0.95, 1.0))
	draw_string(font, Vector2(vp.x - 260, 82), "KILLS " + str(_kills), HORIZONTAL_ALIGNMENT_RIGHT, 240, 20, Color.WHITE)
	draw_string(font, Vector2(vp.x - 260, 108), "WAVE " + str(_wave) + "  - ENDLESS", HORIZONTAL_ALIGNMENT_RIGHT, 240, 20, Color(0.3, 0.9, 1.0))
	# Wave speed indicator
	var wave_speed_pct: int = int(min(300.0, (_wave - 1) * 10.0))
	if wave_speed_pct > 0:
		draw_string(font, Vector2(vp.x - 260, 128), "ENEMY SPEED +" + str(wave_speed_pct) + "%", HORIZONTAL_ALIGNMENT_RIGHT, 240, 13, Color(1.0, 0.65, 0.35))
	draw_string(font, Vector2(vp.x - 260, 134), "BEST " + str(_best_score) + " W" + str(_best_wave), HORIZONTAL_ALIGNMENT_RIGHT, 240, 15, Color(0.65, 0.75, 0.85, 0.85))
	draw_string(font, Vector2(vp.x - 260, 158), "LOOT " + str(_loot_haul), HORIZONTAL_ALIGNMENT_RIGHT, 240, 15, Color(1.0, 0.82, 0.30, 0.95))
	var lives_col := Color(1.0, 0.35, 0.35)
	if _lives > 1:
		lives_col = Color(0.55, 0.95, 1.0)
	draw_string(font, Vector2(vp.x - 260, 182), "LIVES " + str(_lives) + " / 3", HORIZONTAL_ALIGNMENT_RIGHT, 240, 17, lives_col)
	draw_string(font, Vector2(bar_pos.x, bar_pos.y - 6), "HP " + str(int(hp)) + "/" + str(int(max_hp)), HORIZONTAL_ALIGNMENT_LEFT, 200, 14, Color(0.9, 0.9, 0.9))

func _draw_death_overlay(vp: Vector2) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var dying_v: Variant = _player.get("_dying")
	if dying_v == null or not bool(dying_v):
		return
	var font := ThemeDB.fallback_font
	# Dark red vignette over the whole screen
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.12, 0.01, 0.02, 0.62))
	# Big centered YOU DIED
	var title_y: float = vp.y * 0.40
	draw_string(font, Vector2(0, title_y), "YOU DIED", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 96, Color(1.0, 0.22, 0.22))
	# Subtitle
	var sub_y: float = vp.y * 0.53
	draw_string(font, Vector2(0, sub_y), "Respawning...", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 30, Color(0.88, 0.88, 0.92))
	# Thin red line under the title
	var line_w := 320.0
	var line_x := (vp.x - line_w) * 0.5
	draw_line(Vector2(line_x, title_y + 20), Vector2(line_x + line_w, title_y + 20), Color(1.0, 0.25, 0.25, 0.75), 2.0)


func _draw_weapon_hud(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var wd_name := "RIFLE"
	var cur_ammo := 30
	var mag_size := 30
	if _player != null and is_instance_valid(_player):
		var wid: Variant = _player.get("current_weapon_id")
		if wid != null:
			wd_name = String(wid).to_upper()
		var a: Variant = _player.get("ammo")
		if a != null:
			cur_ammo = int(a)
	match wd_name:
		"SMG":
			mag_size = 40
		"SHOTGUN":
			mag_size = 6
		_:
			mag_size = 30
	var ammo_color := Color(1, 1, 1, 0.95)
	if cur_ammo <= mag_size / 3:
		ammo_color = Color(1.0, 0.45, 0.4, 0.95)
	draw_string(font, Vector2(vp.x - 240, 200), wd_name, HORIZONTAL_ALIGNMENT_RIGHT, 200, 18, Color(0.7, 0.9, 1.0, 0.9))
	draw_string(font, Vector2(vp.x - 240, 234), str(cur_ammo) + " / " + str(mag_size), HORIZONTAL_ALIGNMENT_RIGHT, 200, 26, ammo_color)

func _draw_hitmarker_and_numbers() -> void:
	pass

func _draw_extraction_hud() -> void:
	var font := ThemeDB.fallback_font
	var vp := get_viewport().get_visible_rect().size
	var y := vp.y - 200.0
	if extraction_armed and extraction_progress <= 0.0:
		var msg := "EXTRACTION ARMED - RETURN TO GREEN PAD"
		draw_string(font, Vector2(0, y), msg, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color(0.30, 1.0, 0.55, 0.85))
	if extraction_progress > 0.0:
		var bar_w := 380.0
		var bar_h := 18.0
		var bx := (vp.x - bar_w) * 0.5
		var by := y - 20.0
		draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(bx + 2, by + 2, (bar_w - 4) * extraction_progress, bar_h - 4), Color(0.30, 1.0, 0.55, 0.95))
		draw_string(font, Vector2(0, y + 20), "EXTRACTING...", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 22, Color(0.30, 1.0, 0.55))

func _draw_carry_bar(vp: Vector2) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var ratio_v: Variant = _player.get("_carry_weight")
	if ratio_v == null:
		return
	var weight: float = float(ratio_v)
	if weight <= 0.0:
		return
	var max_v: Variant = _player.get("_max_carry")
	var max_w: float = float(max_v) if max_v != null else 2400.0
	var ratio: float = clampf(weight / max_w, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var bar_w := 200.0
	var bar_h := 12.0
	var bx := vp.x - bar_w - 30.0
	var by := 200.0
	draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0, 0, 0, 0.65))
	var col := Color(0.30, 0.95, 1.0)
	if ratio > 0.6:
		col = Color(1.0, 0.75, 0.20)
	if ratio > 0.85:
		col = Color(1.0, 0.35, 0.20)
	draw_rect(Rect2(bx + 2, by + 2, (bar_w - 4) * ratio, bar_h - 4), col)
	var label := "CARRY " + str(int(weight))
	if ratio > 0.85:
		label += "  HEAVY"
	elif ratio > 0.6:
		label += "  LOADED"
	draw_string(font, Vector2(bx, by - 6), label, HORIZONTAL_ALIGNMENT_RIGHT, bar_w, 14, col)
