extends CharacterBody3D

signal died

const SPEED := 2.2
const GRAVITY := 16.0
const MAX_HP := 3
const CONTACT_DAMAGE := 10
const CONTACT_COOLDOWN := 0.8
const CONTACT_RANGE := 1.2

# Procedural walk
const WALK_FREQ := 7.0
const SWING_DEG := 38.0
const ARM_SWING_SCALE := 0.55
const SWING_AXIS := Vector3(1, 0, 0)

var hp := MAX_HP
var _player: Node3D = null
var _hit_flash := 0.0
var _contact_cd := 0.0
var _body_root: Node3D = null
var _skeleton: Skeleton3D = null
var _bones: Dictionary = {}
var _walk_phase := 0.0
var _swing_axis := SWING_AXIS

static var _model_scene: PackedScene = null
static var _white_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("enemy")
	_build_visual()
	_find_skeleton()
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
			var aabb: AABB = _compute_aabb(_body_root)
			var target_height: float = 1.8
			var raw_height: float = max(aabb.size.y, 0.001)
			var s: float = target_height / raw_height
			_body_root.scale = Vector3(s, s, s)
			_body_root.position.y = -aabb.position.y * s
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

func _compute_aabb(node: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var local_aabb: AABB = mi.get_aabb()
			if first:
				result = local_aabb
				first = false
			else:
				result = result.merge(local_aabb)
	return result

func _find_skeleton() -> void:
	if _body_root == null:
		return
	_skeleton = _find_skeleton_recursive(_body_root)
	if _skeleton == null:
		return
	var wanted := ["thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "foot_l", "foot_r", "head", "pelvis", "spine_01", "spine_02"]
	for i in range(_skeleton.get_bone_count()):
		var n: String = _skeleton.get_bone_name(i)
		for short in wanted:
			if n == short or n.ends_with("/" + short) or n.ends_with(":" + short) or n.ends_with("_" + short):
				_bones[short] = i
				break

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton_recursive(child)
		if found != null:
			return found
	return null

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

func _set_bone_swing(bone_short: String, angle: float) -> void:
	if not _bones.has(bone_short):
		return
	var idx: int = _bones[bone_short]
	var rest: Basis = _skeleton.get_bone_rest(idx).basis
	var extra := Basis(_swing_axis, angle)
	_skeleton.set_bone_pose_rotation(idx, (rest * extra).get_rotation_quaternion())

func _apply_walk_pose(speed: float) -> void:
	if _skeleton == null or _bones.is_empty():
		return
	var moving := speed > 0.3
	if moving:
		_walk_phase += WALK_FREQ * (speed / SPEED)
	var swing: float = deg_to_rad(SWING_DEG) if moving else 0.0
	var s: float = sin(_walk_phase)
	var c: float = cos(_walk_phase)

	_set_bone_swing("thigh_l", s * swing)
	_set_bone_swing("thigh_r", -s * swing)
	_set_bone_swing("calf_l", -max(0.0, c) * swing * 0.7)
	_set_bone_swing("calf_r", -max(0.0, -c) * swing * 0.7)
	_set_bone_swing("upperarm_l", -s * swing * ARM_SWING_SCALE)
	_set_bone_swing("upperarm_r", s * swing * ARM_SWING_SCALE)
	_set_bone_swing("lowerarm_l", -max(0.0, s) * swing * 0.35)
	_set_bone_swing("lowerarm_r", -max(0.0, -s) * swing * 0.35)

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
			var target_yaw := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 0.15)
		else:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0

	var speed := Vector2(velocity.x, velocity.z).length()
	_apply_walk_pose(speed)

	move_and_slide()
