extends CharacterBody3D

signal died

const SPEED := 2.2
const GRAVITY := 16.0
const MAX_HP := 3
const CONTACT_DAMAGE := 10
const CONTACT_COOLDOWN := 0.8
const CONTACT_RANGE := 1.2

var hp := MAX_HP
var _player: Node3D = null
var _hit_flash := 0.0
var _contact_cd := 0.0
var _body_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("enemy")
	for child in get_children():
		if child is MeshInstance3D:
			_body_mesh = child
			break
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_update_color()

func _update_color() -> void:
	if _body_mesh == null:
		return
	var mat := StandardMaterial3D.new()
	if _hit_flash > 0.0:
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	else:
		var t := float(hp) / float(MAX_HP)
		mat.albedo_color = Color(0.9, 0.2 + 0.4 * (1.0 - t), 0.15)
	_body_mesh.material_override = mat

func take_damage(amount: int) -> void:
	hp -= amount
	_hit_flash = 0.12
	_update_color()
	if hp <= 0:
		_die()

func _die() -> void:
	emit_signal("died")
	var parent := get_parent()
	if parent != null:
		var burst := CPUParticles3D.new()
		burst.emitting = true
		burst.amount = 24
		burst.lifetime = 0.7
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.direction = Vector3(0, 1, 0)
		burst.spread = 180.0
		burst.initial_velocity_min = 3.0
		burst.initial_velocity_max = 6.0
		burst.gravity = Vector3(0, -8, 0)
		burst.scale_amount_min = 0.08
		burst.scale_amount_max = 0.18
		burst.color = Color(1.0, 0.3, 0.3)
		parent.add_child(burst)
		burst.global_position = global_position + Vector3(0, 0.8, 0)
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())
	queue_free()

func _physics_process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			_update_color()
	if _contact_cd > 0.0:
		_contact_cd -= delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()

		# Contact damage
		if dist < CONTACT_RANGE and _contact_cd <= 0.0 and _player.has_method("take_damage"):
			_player.call("take_damage", CONTACT_DAMAGE)
			_contact_cd = CONTACT_COOLDOWN

		if dist > 0.6:
			var dir := to_player.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			var target_yaw := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 0.15)
		else:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
