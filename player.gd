extends CharacterBody3D

signal died
signal hp_changed(new_hp: int)

const SPEED := 5.5
const JUMP_VELOCITY := 6.5
const GRAVITY := 16.0
const LOOK_SENSITIVITY := 0.15
const PITCH_MIN := -60.0
const PITCH_MAX := 20.0

const FIRE_COOLDOWN := 0.14
const AUTO_AIM_ANGLE := 12.0
const AUTO_AIM_RANGE := 40.0

const MAX_HP := 100
const IFrames_TIME := 0.9

@onready var cam_pivot: Node3D = $CamPivot
@onready var camera: Camera3D = $CamPivot/Camera

var hp := MAX_HP
var max_hp := MAX_HP
var _iframes := 0.0
var _yaw := 0.0
var _pitch := -8.0
var _fire_timer := 0.0

var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_jump := false
var touch_fire := false

func _ready() -> void:
	rotation.y = _yaw
	cam_pivot.rotation.x = deg_to_rad(_pitch)

func _physics_process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
	if _iframes > 0.0:
		_iframes -= delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if touch_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
	touch_jump = false

	if touch_look.length_squared() > 0.0001:
		_yaw -= touch_look.x * LOOK_SENSITIVITY
		_pitch -= touch_look.y * LOOK_SENSITIVITY
		_pitch = clamp(_pitch, PITCH_MIN, PITCH_MAX)
		rotation.y = _yaw
		cam_pivot.rotation.x = deg_to_rad(_pitch)
	touch_look = Vector2.ZERO

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

	if touch_fire and _fire_timer <= 0.0:
		fire()

	move_and_slide()

func take_damage(amount: int) -> void:
	if _iframes > 0.0:
		return
	if hp <= 0:
		return
	hp -= amount
	_iframes = IFrames_TIME
	emit_signal("hp_changed", hp)
	# Hit flash — briefly tint the body white
	var body := _find_body_mesh()
	if body != null:
		var mat := body.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(1.0, 1.0, 1.0)
			var t := get_tree().create_timer(0.12)
			t.timeout.connect(func(): _restore_body_color())
	if hp <= 0:
		die()

func _find_body_mesh() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null

func _restore_body_color() -> void:
	var body := _find_body_mesh()
	if body == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 1.0)
	body.material_override = mat

func die() -> void:
	emit_signal("died")

func respawn() -> void:
	hp = MAX_HP
	_iframes = 1.2
	global_position = Vector3(0, 1.0, 0)
	velocity = Vector3.ZERO
	emit_signal("hp_changed", hp)
	_restore_body_color()

func fire() -> void:
	_fire_timer = FIRE_COOLDOWN
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z.normalized()

	var target := _find_auto_aim_target(origin, forward)
	var shoot_dir := forward
	if target != null:
		shoot_dir = (target.global_position + Vector3(0, 0.8, 0) - origin).normalized()

	var bullet_script = load("res://bullet.gd")
	var bullet := Area3D.new()
	bullet.set_script(bullet_script)
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(bullet)
	bullet.global_position = origin + shoot_dir * 0.6
	if bullet.has_method("setup"):
		bullet.call("setup", shoot_dir)

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.5)
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	scene.add_child(flash)
	flash.global_position = origin + shoot_dir * 0.5
	var t := get_tree().create_timer(0.06)
	t.timeout.connect(func(): if is_instance_valid(flash): flash.queue_free())

func _find_auto_aim_target(origin: Vector3, forward: Vector3) -> Node3D:
	var best: Node3D = null
	var best_angle: float = deg_to_rad(AUTO_AIM_ANGLE)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy: Vector3 = (enemy.global_position + Vector3(0, 0.8, 0)) - origin
		var dist: float = to_enemy.length()
		if dist > AUTO_AIM_RANGE:
			continue
		var angle: float = forward.angle_to(to_enemy.normalized())
		if angle < best_angle:
			best_angle = angle
			best = enemy
	return best
