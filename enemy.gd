extends CharacterBody3D

signal died

const SPEED := 2.2
const GRAVITY := 16.0
const MAX_HP := 3
const CONTACT_DAMAGE := 10
const CONTACT_COOLDOWN := 0.8
const CONTACT_RANGE := 1.2

const WALK_FREQ := 3.2
const SWING_DEG := 34.0
const SWING_AXIS := Vector3(1, 0, 0)

# Arm aim pose (degrees, applied as bone rotations)
const AIM_ARM_PITCH := -75.0
const AIM_ELBOW_BEND := 65.0
const AIM_HAND_TWIST := 15.0

var hp := MAX_HP
var _player: Node3D = null
var _hit_flash := 0.0
var _contact_cd := 0.0
var _body_root: Node3D = null
var _skeleton: Skeleton3D = null
var _bones: Dictionary = {}
var _walk_phase := 0.0
var _recoil := 0.0

static var _model_scene: PackedScene = null
static var _white_mat: StandardMaterial3D = null
static var _gun_mesh: Mesh = null
static var _gun_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("enemy")
	_build_visual()
	_find_skeleton()
	_attach_gun()
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
			s = clamp(s, 0.01, 100.0)
			_body_root.scale = Vector3(s, s, s)
			_body_root.position.y = -aabb.position.y * s
			add_child(_body_root)
			return
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
	var stack: Array = [node]
	while stack.size() > 0:
		var current = stack.pop_back()
		if current is MeshInstance3D:
			var mi := current as MeshInstance3D
			var m: Mesh = mi.mesh
			if m != null:
				var mesh_aabb: AABB = m.get_aabb()
				var xform: Transform3D = mi.global_transform
				var min_p: Vector3 = mesh_aabb.position
				var max_p: Vector3 = mesh_aabb.position + mesh_aabb.size
				for xi in range(2):
					for yi in range(2):
						for zi in range(2):
							var corner: Vector3 = Vector3(min_p.x if xi == 0 else max_p.x, min_p.y if yi == 0 else max_p.y, min_p.z if zi == 0 else max_p.z)
							var world: Vector3 = xform * corner
							if first:
								result = AABB(world, Vector3.ZERO)
								first = false
							else:
								result = result.expand(world)
		for child in current.get_children():
			stack.push_back(child)
	return result

func _find_skeleton() -> void:
	if _body_root == null:
		return
	_skeleton = _find_skeleton_recursive(_body_root)
	if _skeleton == null:
		return
	var wanted := ["thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_r", "hand_l", "spine_01", "spine_02"]
	for i in range(_skeleton.get_bone_count()):
		var n: String = _skeleton.get_bone_name(i)
		for short in wanted:
			if n == short or n.ends_with("/" + short) or n.ends_with(":" + short):
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

func _attach_gun() -> void:
	if _skeleton == null or not _bones.has("hand_r"):
		return
	if _gun_mesh == null:
		_build_gun_mesh()
	var attach := BoneAttachment3D.new()
	attach.bone_name = _skeleton.get_bone_name(_bones["hand_r"])
	_skeleton.add_child(attach)
	var gun := MeshInstance3D.new()
	gun.mesh = _gun_mesh
	gun.material_override = _gun_mat
	# Position in hand-bone local space: in front, slightly up
	gun.position = Vector3(0.05, 0.0, 0.02)
	gun.rotation_degrees = Vector3(0, 0, 0)
	attach.add_child(gun)

func _build_gun_mesh() -> void:
	# Simple rifle: long thin body + magazine + muzzle
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Body: rectangle from (0,0,0) to (0.08, 0.08, 0.5)
	st.add_vertex(Vector3(0.0, 0.0, 0.0)); st.add_vertex(Vector3(0.08, 0.0, 0.0)); st.add_vertex(Vector3(0.08, 0.08, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, 0.0)); st.add_vertex(Vector3(0.08, 0.08, 0.0)); st.add_vertex(Vector3(0.0, 0.08, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, 0.5)); st.add_vertex(Vector3(0.08, 0.0, 0.5)); st.add_vertex(Vector3(0.08, 0.0, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, 0.5)); st.add_vertex(Vector3(0.08, 0.0, 0.0)); st.add_vertex(Vector3(0.0, 0.0, 0.0))
	st.add_vertex(Vector3(0.0, 0.08, 0.5)); st.add_vertex(Vector3(0.08, 0.08, 0.5)); st.add_vertex(Vector3(0.08, 0.0, 0.5))
	st.add_vertex(Vector3(0.0, 0.08, 0.5)); st.add_vertex(Vector3(0.08, 0.0, 0.5)); st.add_vertex(Vector3(0.0, 0.0, 0.5))
	st.generate_normals()
	_gun_mesh = st.commit()
	_gun_mat = StandardMaterial3D.new()
	_gun_mat.albedo_color = Color(0.12, 0.13, 0.15)
	_gun_mat.roughness = 0.55
	_gun_mat.metallic = 0.8

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

func _set_bone_local(bone_short: String, pitch_deg: float, roll_deg: float = 0.0, yaw_deg: float = 0.0) -> void:
	if not _bones.has(bone_short):
		return
	var idx: int = _bones[bone_short]
	var rest: Basis = _skeleton.get_bone_rest(idx).basis
	var extra := Basis(Vector3.RIGHT, deg_to_rad(pitch_deg)) * Basis(Vector3.FORWARD, deg_to_rad(roll_deg)) * Basis(Vector3.UP, deg_to_rad(yaw_deg))
	_skeleton.set_bone_pose_rotation(idx, (rest * extra).get_rotation_quaternion())

func _apply_pose(speed: float) -> void:
	if _skeleton == null or _bones.is_empty():
		return
	# Legs walk
	var moving := speed > 0.3
	if moving:
		_walk_phase += WALK_FREQ * (speed / SPEED)
	var swing: float = deg_to_rad(SWING_DEG) if moving else 0.0
	var s: float = sin(_walk_phase)
	var c: float = cos(_walk_phase)
	_set_bone_local("thigh_l", s * SWING_DEG)
	_set_bone_local("thigh_r", -s * SWING_DEG)
	_set_bone_local("calf_l", -max(0.0, c) * SWING_DEG * 0.7)
	_set_bone_local("calf_r", -max(0.0, -c) * SWING_DEG * 0.7)
	# Arms: static aim pose + tiny sway
	var sway := sin(_walk_phase * 0.5) * 3.0
	_set_bone_local("upperarm_l", AIM_ARM_PITCH - 10.0 + sway, 0.0, -25.0)
	_set_bone_local("upperarm_r", AIM_ARM_PITCH + sway, 0.0, 25.0)
	_set_bone_local("lowerarm_l", AIM_ELBOW_BEND - 15.0, 0.0, 0.0)
	_set_bone_local("lowerarm_r", AIM_ELBOW_BEND, 0.0, 0.0)
	_set_bone_local("hand_l", 0.0, 0.0, AIM_HAND_TWIST)
	_set_bone_local("hand_r", 0.0, 0.0, -AIM_HAND_TWIST)

func _spawn_muzzle_flash() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 4.0
	flash.omni_range = 3.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position + Vector3(0, 1.2, 0) - global_transform.basis.z * 0.6
	var t := get_tree().create_timer(0.06)
	t.timeout.connect(func(): if is_instance_valid(flash): flash.queue_free())

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
	if _recoil > 0.0:
		_recoil -= delta * 4.0
	var recoil_offset: float = -_recoil * 0.15

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()

		if dist < CONTACT_RANGE and _contact_cd <= 0.0 and _player.has_method("take_damage"):
			_player.call("take_damage", CONTACT_DAMAGE)
			_contact_cd = CONTACT_COOLDOWN
			_recoil = 1.0
			_spawn_muzzle_flash()

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
	_apply_pose(speed)
	if _body_root != null:
		_body_root.position.z = recoil_offset

	move_and_slide()
