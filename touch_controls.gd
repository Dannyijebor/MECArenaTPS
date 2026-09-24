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

const C_BASE := Color(0.22, 0.74, 0.97, 0.28)
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

func _process(_delta: float) -> void:
	queue_redraw()
