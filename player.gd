extends CharacterBody3D

const SPEED := 5.5
const JUMP_VELOCITY := 6.5
const GRAVITY := 16.0

@onready var cam_pivot: Node3D = $CamPivot

var _yaw := 0.0
var _pitch := -8.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch -= event.relative.y * 0.003
		_pitch = clamp(_pitch, -60.0, 20.0)
		rotation.y = _yaw
		cam_pivot.rotation.x = deg_to_rad(_pitch)

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction := Vector3(input_dir.x, 0, input_dir.y)
	direction = direction.rotated(Vector3.UP, rotation.y)

	if direction.length() > 0.01:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 4.0 * delta * 10)
		velocity.z = move_toward(velocity.z, 0, SPEED * 4.0 * delta * 10)

	move_and_slide()
