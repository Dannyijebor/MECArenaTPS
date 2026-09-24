extends CharacterBody3D

signal died

const SPEED := 2.2
const GRAVITY := 16.0
const MAX_HP := 3
const CONTACT_DAMAGE := 10
const CONTACT_COOLDOWN := 0.8
const CONTACT_RANGE := 1.2
const MODEL_SCALE := 1.0

static var _model_scene: PackedScene = null
static var _white_mat: StandardMaterial3D = null

var hp := MAX_HP
var _player: Node3D = null
var _hit_flash := 0.0
var _contact_cd := 0.0
var _body_root: Node3D = null

func _ready() -> void:
	add_to_group("enemy")
	_build_visual()
	_player = get_tree().get_first_node_in_group("player") as Node3D

func _build_visual() -> void:
	if _model_scene == null:
		var loaded: Resource = load("res://models/base_characters/Superhero_Male_FullBody.gltf")
		if loaded is PackedScene:
			_model_scene = loaded as PackedScene
	if _model_scene != null:
		var inst := _model_scene.instantiate()
		if inst is Node3D:
			_body_root = inst as Node3D
			_body_root.scale = Vector3(MODEL_SCALE, MODEL_SCALE, MODEL_SCALE)
			add_child(_body_root)
			return
	# Fallback capsule if model fails to load
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.15)
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.8, 0)
	add_child(mesh)

func _flash_materials(enable: bool) -> void:
	if _body_root == null:
		return
	if _white_mat == null:
		_white_mat = StandardMaterial3D.new()
		_white_mat.albedo_color = Color(1.0, 1.0, 1.0)
		_white_mat.emission_enabled = true
		_white_mat.emission = Color(1.0, 0.9, 0.9)
		_white_mat.emission_energy_multiplier = 2.0
	for node in _body_root.get_children():
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			mi.material_override = _white_mat if enable else null

func take_damage(amount: int) -> void:
	hp -= amount
	_hit_flash = 0.12
	_flash_materials(true)
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
			_flash_materials(false)
	if _contact_cd > 0.0:
		_contact_cd -= delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()

		if dist < CONTACT_RANGE and _contact_cd <= 0.0 and _player.has_method("take_damage"):
			_player.call("take_damage", CONTACT_DAMAGE)
			_contact_cd = CONTACT_COOLDOWN

		if dist > 0.6:
			var dir := to_player.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			# Face the player — add PI if model faces backwards
			var target_yaw := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 0.15)
		else:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
