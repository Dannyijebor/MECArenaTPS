extends CharacterBody3D

const SPEED := 5.5
const JUMP_VELOCITY := 6.5
const GRAVITY := 16.0
const LOOK_SENSITIVITY := 0.004
const PITCH_MIN := -60.0
const PITCH_MAX := 20.0

@onready var cam_pivot: Node3D = $CamPivot

var _yaw := 0.0
var _pitch := -8.0

# External input, set by touch_controls.gd
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_jump := false

func _ready() -> void:
	rotation.y = _yaw
	cam_pivot.rotation.x = deg_to_rad(_pitch)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump (edge-triggered via the touch button)
	if touch_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
	touch_jump = false

	# Camera look from right-side drag
	if touch_look.length_squared() > 0.0001:
		_yaw -= touch_look.x * LOOK_SENSITIVITY
		_pitch -= touch_look.y * LOOK_SENSITIVITY
		_pitch = clamp(_pitch, PITCH_MIN, PITCH_MAX)
		rotation.y = _yaw
		cam_pivot.rotation.x = deg_to_rad(_pitch)
	touch_look = Vector2.ZERO

	# Movement from left joystick
	var direction := Vector3(touch_move.x, 0, touch_move.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	direction = direction.rotated(Vector3.UP, rotation.y)

	if direction.length() > 0.01:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 4.0 * delta * 10)
		velocity.z = move_toward(velocity.z, 0, SPEED * 4.0 * delta * 10)

	move_and_slide()
