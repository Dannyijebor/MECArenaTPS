extends CharacterBody3D
const WeaponDB := preload("res://weapon.gd")
const SFX := preload("res://sfx.gd")

signal died
signal hp_changed(new_hp: int)

const SPEED := 5.5
const JUMP_VELOCITY := 6.5
const GRAVITY := 16.0
const LOOK_SENSITIVITY := 0.05
const PITCH_MIN := -60.0
const PITCH_MAX := 20.0

const FIRE_COOLDOWN := 0.14
const AUTO_AIM_ANGLE := 12.0
const AUTO_AIM_RANGE := 40.0

const MAX_HP := 100
const REGEN_DELAY := 5.0
const REGEN_RATE := 8.0
const IFrames_TIME := 0.9

@onready var cam_pivot: Node3D = $CamPivot
@onready var camera: Camera3D = $CamPivot/Camera

var hp := MAX_HP
var _regen_wait := 0.0
var _regen_accum := 0.0
var max_hp := MAX_HP
var _iframes := 0.0
var _yaw := 0.0
var _pitch := -8.0
var _fire_timer := 0.0
var current_weapon_id: String = WeaponDB.RIFLE
var ammo: int = 0
var _reload_timer: float = 0.0
var _reloading: bool = false
var _recoil_pitch: float = 0.0
var _switch_cd: float = 0.0

var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_jump := false
var touch_fire := false

func _ready() -> void:
	ammo = WeaponDB.mag_size(current_weapon_id)
	rotation.y = _yaw

func _physics_process(delta: float) -> void:
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			ammo = WeaponDB.mag_size(current_weapon_id)
	if _switch_cd > 0.0:
		_switch_cd -= delta
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, deg_to_rad(28.0) * delta)
	_tick_regen(delta)
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

	rotation.y = _yaw

	cam_pivot.rotation.x = deg_to_rad(_pitch) - _recoil_pitch

	move_and_slide()

func take_damage(amount: int) -> void:
	SFX.play("hurt", -2.0)
	_regen_wait = REGEN_DELAY
	_regen_accum = 0.0
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
	if _reloading or _switch_cd > 0.0:
		return
	var wd: Dictionary = WeaponDB.get_data(current_weapon_id)
	if ammo <= 0:
		SFX.play("empty", -4.0)
		_start_reload()
		return
	ammo -= 1
	_fire_timer = float(wd.get("cooldown", 0.14))
	SFX.play("shoot", 0.0, randf_range(0.96, 1.04))

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var aim_angle: float = float(wd.get("auto_aim_angle", 12.0))
	var target: Node3D = _find_auto_aim_target(origin, forward, aim_angle)
	var base_dir: Vector3 = forward
	if target != null:
		base_dir = (target.global_position + Vector3(0, 0.8, 0) - origin).normalized()

	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var pellets: int = int(wd.get("pellets", 1))
	var spread_rad: float = deg_to_rad(float(wd.get("spread_deg", 1.0)))
	var damage: int = int(wd.get("damage", 5))
	var bullet_script: Script = load("res://bullet.gd")

	for i in range(pellets):
		var dir: Vector3 = base_dir
		if spread_rad > 0.0:
			dir = dir.rotated(Vector3.UP, randf_range(-spread_rad, spread_rad))
			dir = dir.rotated(Vector3.RIGHT, randf_range(-spread_rad, spread_rad))
		var bullet := Area3D.new()
		bullet.set_script(bullet_script)
		scene.add_child(bullet)
		bullet.global_position = origin + dir * 0.6
		if bullet.has_method("setup"):
			bullet.call("setup", dir, damage)

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.5)
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	scene.add_child(flash)
	flash.global_position = origin + base_dir * 0.5
	var t := get_tree().create_timer(0.06)
	t.timeout.connect(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
	)

	_recoil_pitch += deg_to_rad(float(wd.get("recoil_pitch", 1.0)))

	if ammo <= 0:
		_start_reload()

func _start_reload() -> void:
	if _reloading:
		return
	var wd: Dictionary = WeaponDB.get_data(current_weapon_id)
	if ammo >= int(wd.get("mag", 30)):
		return
	_reloading = true
	_reload_timer = float(wd.get("reload_time", 1.8))
	SFX.play("reload", -3.0)

func switch_weapon() -> void:
	if _reloading or _switch_cd > 0.0:
		return
	current_weapon_id = WeaponDB.next_id(current_weapon_id)
	ammo = WeaponDB.mag_size(current_weapon_id)
	_switch_cd = 0.35
	_fire_timer = 0.35
	SFX.play("reload", -1.0, 1.4)

func _find_auto_aim_target(origin: Vector3, forward: Vector3, angle_deg: float = AUTO_AIM_ANGLE) -> Node3D:
	var best: Node3D = null
	var best_angle: float = deg_to_rad(angle_deg)
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


func _tick_regen(delta: float) -> void:
	if hp <= 0 or hp >= MAX_HP:
		_regen_wait = 0.0
		_regen_accum = 0.0
		return
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	_regen_accum += REGEN_RATE * delta
	if _regen_accum < 1.0:
		return
	var gain: int = int(_regen_accum)
	_regen_accum -= float(gain)
	var before: int = hp
	hp = min(hp + gain, MAX_HP)
	if hp != before:
		hp_changed.emit(hp)


func heal(amount: int) -> void:
	if hp <= 0:
		return
	var before: int = hp
	hp = min(hp + amount, MAX_HP)
	if hp != before:
		hp_changed.emit(hp)
