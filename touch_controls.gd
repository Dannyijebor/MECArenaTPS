extends CanvasLayer

# ─────────────────────────────────────────────
# Touch controls — landscape layout
#
#   Bottom-left:  MOVE joystick
#   Right 60%:    LOOK drag (no visual)
#   Bottom-right: JUMP + FIRE buttons
# ─────────────────────────────────────────────

const JOYSTICK_CENTER := Vector2(180, -160)
const JOYSTICK_RADIUS := 100.0
const JOYSTICK_KNOB_RADIUS := 44.0

const JUMP_BTN_OFFSET := Vector2(-140, -140)
const FIRE_BTN_OFFSET := Vector2(-260, -140)
const BUTTON_RADIUS := 56.0

var _player: CharacterBody3D = null

# Move joystick state
var _move_touch_id := -1
var _move_center := Vector2.ZERO
var _move_knob_pos := Vector2.ZERO

# Look drag state
var _look_touch_id := -1
var _look_last_pos := Vector2.ZERO

# Buttons
var _jump_pressed := false
var _fire_pressed := false

# Colors
const C_BASE := Color(0.22, 0.74, 0.97, 0.28)
const C_BORDER := Color(0.22, 0.74, 0.97, 0.75)
const C_KNOB := Color(0.22, 0.74, 0.97, 0.85)
const C_JUMP := Color(0.22, 0.85, 0.42, 0.55)
const C_JUMP_BORDER := Color(0.22, 0.85, 0.42, 0.9)
const C_FIRE := Color(0.97, 0.45, 0.45, 0.55)
const C_FIRE_BORDER := Color(0.97, 0.45, 0.45, 0.9)

func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = _find_player_by_name(get_tree().root)

func _find_player_by_name(node: Node) -> CharacterBody3D:
	for child in node.get_children():
		if child.name == "Player" and child is CharacterBody3D:
			return child
		var found = _find_player_by_name(child)
		if found != null:
			return found
	return null

func _joystick_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return vp + JOYSTICK_CENTER

func _jump_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return vp + JUMP_BTN_OFFSET

func _fire_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return vp + FIRE_BTN_OFFSET

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos := event.position
	if event.pressed:
		# Jump button?
		if pos.distance_to(_jump_center()) < BUTTON_RADIUS + 12:
			_jump_pressed = true
			if _player:
				_player.touch_jump = true
			return

		# Fire button?
		if pos.distance_to(_fire_center()) < BUTTON_RADIUS + 12:
			_fire_pressed = true
			return

		# Move joystick zone? (bottom-left 40% of screen)
		var vp := get_viewport().get_visible_rect().size
		if pos.x < vp.x * 0.4 and pos.y > vp.y * 0.5:
			_move_touch_id = event.index
			_move_center = pos
			_move_knob_pos = pos
			return

		# Otherwise → look drag
		if _look_touch_id == -1:
			_look_touch_id = event.index
			_look_last_pos = pos
	else:
		# Release
		if event.index == _move_touch_id:
			_move_touch_id = -1
			if _player:
				_player.touch_move = Vector2.ZERO
		if event.index == _look_touch_id:
			_look_touch_id = -1
		_jump_pressed = false
		_fire_pressed = false

func _handle_drag(event: InputEventScreenDrag) -> void:
	var pos := event.position
	if event.index == _move_touch_id:
		var offset := pos - _move_center
		if offset.length() > JOYSTICK_RADIUS:
			offset = offset.normalized() * JOYSTICK_RADIUS
		_move_knob_pos = _move_center + offset
		if _player:
			# Godot uses -Z as forward; joystick up = -Y in screen = forward
			_player.touch_move = Vector2(offset.x / JOYSTICK_RADIUS, offset.y / JOYSTICK_RADIUS)
	elif event.index == _look_touch_id:
		var delta_look := pos - _look_last_pos
		_look_last_pos = pos
		if _player:
			_player.touch_look += delta_look

func _draw() -> void:
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

	# Fire button
	var fire := _fire_center()
	draw_circle(fire, BUTTON_RADIUS, C_FIRE)
	draw_arc(fire, BUTTON_RADIUS, 0, TAU, 64, C_FIRE_BORDER, 3.0, true)

func _process(_delta: float) -> void:
	queue_redraw()
