extends Control

# Touch controls — landscape layout.
# Left side:  MOVE joystick
# Right side: LOOK drag
# Bottom-right: FIRE + JUMP buttons
# Crosshair drawn in center.

const JOYSTICK_RADIUS := 100.0
const JOYSTICK_KNOB_RADIUS := 44.0
const BUTTON_RADIUS := 56.0

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

const C_BASE := Color(0.22, 0.74, 0.97, 0.28)

var _wave: int = 1
var extraction_progress: float = 0.0
var extraction_armed: bool = false
var _kills: int = 0

func set_state(wave: int, kills: int) -> void:
	_wave = wave
	_kills = kills
const C_BORDER := Color(0.22, 0.74, 0.97, 0.75)
const C_KNOB := Color(0.22, 0.74, 0.97, 0.85)
const C_JUMP := Color(0.22, 0.85, 0.42, 0.55)
const C_JUMP_BORDER := Color(0.22, 0.85, 0.42, 0.9)
const C_FIRE := Color(0.97, 0.45, 0.45, 0.55)
const C_FIRE_BORDER := Color(0.97, 0.45, 0.45, 0.9)
const C_FIRE_PRESSED := Color(1.0, 0.3, 0.3, 0.95)
const C_CROSSHAIR := Color(1, 0.9, 0.3, 0.85)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", get_viewport().get_visible_rect().size)
	mouse_filter = Control.MOUSE_FILTER_PASS
	get_viewport().size_changed.connect(_on_viewport_resized)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _on_viewport_resized() -> void:
	set_deferred("size", get_viewport().get_visible_rect().size)

func _joystick_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(JOYSTICK_RADIUS + 60, vp.y - JOYSTICK_RADIUS - 60)

func _jump_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS - 60, vp.y - BUTTON_RADIUS - 60)

func _fire_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS * 3 - 90, vp.y - BUTTON_RADIUS - 60)

func _reload_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS - 60, vp.y - BUTTON_RADIUS * 3 - 90)

func _crouch_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(JOYSTICK_RADIUS * 2.0 + 120.0, vp.y - JOYSTICK_RADIUS - 60.0)

func _ads_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS * 5.0 - 130.0, vp.y - BUTTON_RADIUS - 60.0)

func _switch_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - BUTTON_RADIUS * 3 - 90, vp.y - BUTTON_RADIUS * 3 - 90)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and _player:
			_player.switch_weapon()
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

		if pos.distance_to(_fire_center()) < BUTTON_RADIUS + 14:
			_fire_touch_id = event.index
			if _player:
				_player.touch_fire = true
			return

		var vp := get_viewport().get_visible_rect().size
		if pos.x < vp.x * 0.4 and pos.y > vp.y * 0.4:
			_move_touch_id = event.index
			_move_center = pos
			_move_knob_pos = pos
			return

		if _look_touch_id == -1:
			_look_touch_id = event.index
			_look_last_pos = pos
	else:
		if event.index == _move_touch_id:
			_move_touch_id = -1
			if _player:
				_player.touch_move = Vector2.ZERO
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
	elif event.index == _look_touch_id:
		var delta_look := pos - _look_last_pos
		_look_last_pos = pos
		if _player:
			_player.touch_look += delta_look

func _draw() -> void:
	# Crosshair in center
	var vp := get_viewport().get_visible_rect().size
	var c := vp * 0.5

	# ── HP bar (top-left)
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
	var bar_w := 220.0
	var bar_h := 22.0
	var bar_pos := Vector2(30, 30)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(bar_pos + Vector2(2, 2), Vector2((bar_w - 4) * hp_ratio, bar_h - 4)), Color(0.94, 0.27, 0.27, 1.0))

	# ── KILLS + WAVE (top-right)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(vp.x - 230, 52), "KILLS " + str(_kills), HORIZONTAL_ALIGNMENT_RIGHT, 200, 24, Color.WHITE)
	draw_string(font, Vector2(vp.x - 230, 82), "WAVE " + str(_wave), HORIZONTAL_ALIGNMENT_RIGHT, 200, 20, Color(0.3, 0.9, 1.0))

	# ── Death overlay
	var hp_check: float = 1.0
	if _player != null and is_instance_valid(_player):
		var hv: Variant = _player.get("hp")
		if hv != null:
			hp_check = float(hv)
	if hp_check <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.55))
		draw_string(font, Vector2(0, vp.y * 0.5 - 20), "YOU DIED", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 48, Color(1.0, 0.3, 0.3))
		draw_string(font, Vector2(0, vp.y * 0.5 + 40), "Respawning...", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 24, Color(1.0, 1.0, 1.0, 0.8))

	draw_circle(c, 4.0, C_CROSSHAIR)
	draw_line(c + Vector2(-14, 0), c + Vector2(-4, 0), C_CROSSHAIR, 2.0)
	draw_line(c + Vector2(4, 0), c + Vector2(14, 0), C_CROSSHAIR, 2.0)
	draw_line(c + Vector2(0, -14), c + Vector2(0, -4), C_CROSSHAIR, 2.0)
	draw_line(c + Vector2(0, 4), c + Vector2(0, 14), C_CROSSHAIR, 2.0)

	# Move joystick
	var base := _move_center if _move_touch_id != -1 else _joystick_center()
	draw_circle(base, JOYSTICK_RADIUS, C_BASE)
	draw_arc(base, JOYSTICK_RADIUS, 0, TAU, 64, C_BORDER, 3.0, true)
	var knob := _move_knob_pos if _move_touch_id != -1 else base
	draw_circle(knob, JOYSTICK_KNOB_RADIUS, C_KNOB)

	# Jump button
	var jump := _jump_center()
	draw_circle(jump, BUTTON_RADIUS, C_JUMP)
	draw_arc(jump, BUTTON_RADIUS, 0, TAU, 64, C_JUMP_BORDER, 3.0, true)

	# Fire button — brightens while held
	var fire := _fire_center()
	var fire_color := C_FIRE_PRESSED if _fire_touch_id != -1 else C_FIRE
	draw_circle(fire, BUTTON_RADIUS, fire_color)
	draw_arc(fire, BUTTON_RADIUS, 0, TAU, 64, C_FIRE_BORDER, 3.0, true)

	_draw_weapon_hud(vp)

	_draw_crouch_button(vp)

	_draw_hitmarker_and_numbers()

	_draw_ads_button(vp)

	_draw_extraction_hud()

	_draw_carry_bar(vp)

func _process(_delta: float) -> void:
	queue_redraw()


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
		"SMG":     mag_size = 40
		"SHOTGUN": mag_size = 6
		_:         mag_size = 30

	var ammo_color := Color(1, 1, 1, 0.95)
	if cur_ammo <= mag_size / 3:
		ammo_color = Color(1.0, 0.45, 0.4, 0.95)
	draw_string(font, Vector2(vp.x - 240, 120), wd_name, HORIZONTAL_ALIGNMENT_RIGHT, 200, 18, Color(0.7, 0.9, 1.0, 0.9))
	draw_string(font, Vector2(vp.x - 240, 154), str(cur_ammo) + " / " + str(mag_size), HORIZONTAL_ALIGNMENT_RIGHT, 200, 26, ammo_color)

	# Reload button
	var rp := _reload_center()
	var r_fill := Color(1.0, 0.7, 0.2, 0.55)
	if _reload_touch_id != -1:
		r_fill = Color(1.0, 0.7, 0.2, 0.95)
	draw_circle(rp, BUTTON_RADIUS, r_fill)
	draw_arc(rp, BUTTON_RADIUS, 0.0, TAU, 48, Color(1.0, 0.8, 0.3, 0.9), 3.0)
	draw_string(font, rp + Vector2(-30, 8), "RELOAD", HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color.WHITE)

	# Switch button
	var sp := _switch_center()
	var s_fill := Color(0.5, 0.6, 1.0, 0.55)
	if _switch_touch_id != -1:
		s_fill = Color(0.5, 0.6, 1.0, 0.95)
	draw_circle(sp, BUTTON_RADIUS, s_fill)
	draw_arc(sp, BUTTON_RADIUS, 0.0, TAU, 48, Color(0.7, 0.8, 1.0, 0.9), 3.0)
	draw_string(font, sp + Vector2(-22, 8), "SWAP", HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color.WHITE)


func _draw_crouch_button(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var cp := _crouch_center()
	var fill := Color(0.6, 0.3, 1.0, 0.5)
	if _crouch_touch_id != -1:
		fill = Color(0.7, 0.4, 1.0, 0.95)
	draw_circle(cp, 50.0, fill)
	draw_arc(cp, 50.0, 0.0, TAU, 48, Color(0.75, 0.55, 1.0, 0.9), 3.0)
	draw_string(font, cp + Vector2(-26, 8), "CRCH", HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color.WHITE)


func _draw_hitmarker_and_numbers() -> void:
	var font := ThemeDB.fallback_font
	if _player == null or not is_instance_valid(_player):
		return
	var vp := get_viewport().get_visible_rect().size
	var center := vp * 0.5

	# Hitmarker
	var hmt: Variant = _player.get("hit_marker_time")
	if hmt != null and float(hmt) > 0.0:
		var hs_v: Variant = _player.get("hit_marker_headshot")
		var hs: bool = hs_v != null and bool(hs_v)
		var col: Color = Color(1.0, 0.85, 0.2, 0.95) if hs else Color(1, 1, 1, 0.9)
		var r1 := 8.0
		var r2 := 20.0
		var thick := 2.5
		# four ticks forming an X
		draw_line(center + Vector2(-r2, -r2), center + Vector2(-r1, -r1), col, thick)
		draw_line(center + Vector2(r2, -r2),  center + Vector2(r1, -r1),  col, thick)
		draw_line(center + Vector2(-r2, r2),  center + Vector2(-r1, r1),  col, thick)
		draw_line(center + Vector2(r2, r2),   center + Vector2(r1, r1),   col, thick)

	# Damage numbers
	var dn_list: Variant = _player.get("damage_numbers")
	if dn_list == null:
		return
	var cam: Camera3D = _player.get("camera") if _player.get("camera") != null else null
	if cam == null:
		return
	for dn in dn_list:
		if not (dn is Dictionary):
			continue
		var life: float = float(dn.get("life", 0.0))
		var max_life: float = float(dn.get("max_life", 0.85))
		var t: float = 1.0 - (life / max_life)
		var world_pos: Vector3 = dn.get("pos", Vector3.ZERO) + Vector3(0, t * 0.9, 0)
		var screen: Vector2 = cam.unproject_position(world_pos)
		if screen.x < -100 or screen.x > vp.x + 100:
			continue
		var alpha: float = clamp(1.0 - t * 1.1, 0.0, 1.0)
		var hs: bool = dn.get("headshot", false)
		var val: int = int(dn.get("value", 0))
		var col: Color = Color(1.0, 0.85, 0.2, alpha) if hs else Color(1, 1, 1, alpha)
		var size: int = 22 if hs else 18
		var txt: String = str(val)
		if hs:
			txt = "HS " + str(val)
		draw_string(font, screen + Vector2(-14, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, 100, size, col)


func _draw_ads_button(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var ap := _ads_center()
	var aiming: bool = false
	if _player != null and is_instance_valid(_player):
		var a: Variant = _player.get("_aiming")
		if a != null:
			aiming = bool(a)
	var fill := Color(0.9, 0.9, 0.95, 0.5)
	var border := Color(0.95, 0.95, 1.0, 0.9)
	if aiming or _ads_touch_id != -1:
		fill = Color(0.95, 0.95, 1.0, 0.95)
		border = Color(1.0, 0.55, 0.35, 1.0)
	draw_circle(ap, BUTTON_RADIUS, fill)
	draw_arc(ap, BUTTON_RADIUS, 0.0, TAU, 48, border, 3.0)
	# Crosshair icon inside
	var ic: Color = Color(0.1, 0.1, 0.15, 0.95)
	if aiming:
		ic = Color(0.55, 0.15, 0.05, 0.95)
	draw_line(ap + Vector2(-14, 0), ap + Vector2(-5, 0), ic, 2.0)
	draw_line(ap + Vector2(5, 0), ap + Vector2(14, 0), ic, 2.0)
	draw_line(ap + Vector2(0, -14), ap + Vector2(0, -5), ic, 2.0)
	draw_line(ap + Vector2(0, 5), ap + Vector2(0, 14), ic, 2.0)
	draw_string(font, ap + Vector2(-16, BUTTON_RADIUS + 18), "AIM", HORIZONTAL_ALIGNMENT_LEFT, 100, 14, Color.WHITE)


func _draw_extraction_hud() -> void:
	var font := ThemeDB.fallback_font
	var vp := get_viewport().get_visible_rect().size
	# Bottom-center prompt
	var y := vp.y - 200.0
	if extraction_armed and extraction_progress <= 0.0:
		var msg := "EXTRACTION ARMED — RETURN TO GREEN PAD"
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
	# Position: right side under HUD, small bar
	var bar_w := 200.0
	var bar_h := 12.0
	var bx := vp.x - bar_w - 30.0
	var by := 190.0
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
