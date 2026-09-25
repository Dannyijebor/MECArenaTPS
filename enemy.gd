extends CharacterBody3D
const SFX := preload("res://sfx.gd")

signal died

const SPEED := 2.2
const GRAVITY := 16.0
const MAX_HP := 3
const CONTACT_DAMAGE := 10
const CONTACT_COOLDOWN := 0.8
const CONTACT_RANGE := 1.2
const SHOOT_RANGE := 18.0
const SHOOT_MIN_DIST := 4.0
const SHOOT_COOLDOWN := 1.6
const SHOOT_DAMAGE := 6
const SHOOT_ACCURACY_DEG := 6.0
const STRAFE_SPEED := 1.6
const STRAFE_CHANGE_MIN := 1.2
const STRAFE_CHANGE_MAX := 2.6
const COVER_SEARCH_RADIUS := 9.0
const COVER_HP_THRESHOLD := 1
const COVER_HOLD_TIME := 1.8
const DAMAGE_MEMORY_TIME := 2.5
const FLANK_ARC_DEG := 35.0
const ENEMY_PREFERRED_DIST := 7.0

const WALK_FREQ := 3.2
const SWING_DEG := 34.0
const SWING_AXIS := Vector3(1, 0, 0)

# Arm aim pose (degrees, applied as bone rotations)
const AIM_ARM_PITCH := -75.0
const AIM_ELBOW_BEND := 65.0
const AIM_HAND_TWIST := 15.0

var hp: int = 3
var _player: Node3D = null
var _hit_flash := 0.0
var _dying := false
var _contact_cd := 0.0
var _shoot_cd := 0.0
enum AIState { APPROACH, COMBAT, COVER }
var _ai_state: int = AIState.APPROACH
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0
var _flank_offset: float = 0.0
var _cover_target: Vector3 = Vector3.ZERO
var _cover_timer: float = 0.0
var _recent_damage_timer: float = 0.0
var _last_hp: int = 999

# ---- Enemy types ----
var enemy_type: int = 0
var _t_speed_mult: float = 1.0
var _t_hp: int = 3
var _t_range: float = 18.0
var _t_cd: float = 1.6
var _t_dmg: int = 6
var _t_color: Color = Color(0.55, 0.16, 0.16)
var _body_root: Node3D = null
var _skeleton: Skeleton3D = null
var _bones: Dictionary = {}
var _anim: AnimationPlayer = null
var _use_animations: bool = false
var _walk_phase := 0.0
var _recoil := 0.0

static var _model_scene: PackedScene = null
static var _white_mat: StandardMaterial3D = null
static var _gun_mesh: Mesh = null
static var _gun_mat: StandardMaterial3D = null

func _ready() -> void:
	_apply_type()
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
				var xform: Transform3D = mi.transform if not mi.is_inside_tree() else mi.global_transform
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
	_add_clothing(_t_color)
	if _skeleton == null:
		return
	var wanted := ["thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_r", "hand_l", "spine_01", "spine_02", "neck", "head", "hips"]
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
	_set_bone_local("upperarm_l", 0.0, 72.0 + sway, -12.0)
	_set_bone_local("upperarm_r", 0.0, -72.0 + sway, 12.0)
	_set_bone_local("lowerarm_l", 0.0, 55.0, 0.0)
	_set_bone_local("lowerarm_r", 0.0, -55.0, 0.0)
	_set_bone_local("hand_l", 0.0, 0.0, AIM_HAND_TWIST)
	_set_bone_local("hand_r", 0.0, 0.0, -AIM_HAND_TWIST)
	# Hip counter-sway while walking
	if moving:
		var hip_yaw: float = -s * 4.5
		_set_bone_local("hips", 0.0, 0.0, hip_yaw)
	# Forward lean at speed
	var lean_pitch: float = 0.0
	if speed > SPEED * 1.2:
		lean_pitch = -8.0
	elif moving:
		lean_pitch = -3.0
	_set_bone_local("spine_01", lean_pitch)
	# Head tracking — turn toward player
	if _player != null and is_instance_valid(_player):
		var to_p: Vector3 = _player.global_position - global_position
		to_p.y = 0.0
		if to_p.length() > 0.1:
			var local_p: Vector3 = to_p.rotated(Vector3.UP, -rotation.y)
			var yaw_deg: float = rad_to_deg(atan2(-local_p.x, -local_p.z))
			yaw_deg = clampf(yaw_deg, -50.0, 50.0)
			_set_bone_local("neck", 0.0, 0.0, yaw_deg * 0.55)
			_set_bone_local("head", 0.0, 0.0, yaw_deg * 0.45)


func _spawn_muzzle_flash() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 4.0
	flash.omni_range = 3.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position + Vector3(0, 1.2, 0) - global_transform.basis.z * 0.6
	var t := get_tree().create_timer(0.06)
	t.timeout.connect(func(): if is_instance_valid(flash): flash.queue_free())

func take_damage(amount: int, hit_pos: Vector3 = Vector3.ZERO) -> void:
	SFX.play("hit", -4.0, randf_range(0.95, 1.08))
	_recent_damage_timer = DAMAGE_MEMORY_TIME
	hp -= amount
	var _is_hs := false
	if hit_pos != Vector3.ZERO:
		var head_y: float = global_position.y + 1.5
		_is_hs = hit_pos.y > head_y
	var _report_dmg := amount * 2 if _is_hs else amount
	if _is_hs:
		hp -= amount
	if _player != null and _player.has_method("report_hit"):
		_player.call("report_hit", _report_dmg, _is_hs, hit_pos)
	_apply_stagger(hit_pos, _is_hs)
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
	_tick_combat(delta)
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

	_tick_ai(delta)
	move_and_slide()


func _has_los_to_player() -> bool:
	if _player == null:
		return false
	var from := global_position + Vector3(0, 1.4, 0)
	var to := _player.global_position + Vector3(0, 1.0, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [self.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var c = hit.collider
	return c == _player or (c is Node and c.is_in_group("player"))

func _try_shoot_player() -> void:
	SFX.play("enemy_shoot", -6.0, randf_range(0.9, 1.1))
	if _player == null:
		return
	var from := global_position + Vector3(0, 1.4, 0)
	var to := _player.global_position + Vector3(0, 1.0, 0)
	var dir := (to - from).normalized()
	var spread := deg_to_rad(SHOOT_ACCURACY_DEG)
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	dir = dir.rotated(Vector3.RIGHT, randf_range(-spread, spread))
	var ray_end := from + dir * SHOOT_RANGE * 1.5
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, ray_end)
	q.exclude = [self.get_rid()]
	var hit := space.intersect_ray(q)
	var impact: Vector3 = hit.position if not hit.is_empty() else ray_end
	_spawn_muzzle_flash()
	_spawn_tracer(from, impact)
	if hit.is_empty():
		return
	var c = hit.collider
	if c == _player or (c is Node and c.is_in_group("player")):
		if c.has_method("take_damage"):
			c.call("take_damage", _t_dmg)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.1:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, dist)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.4)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	var t := get_tree().create_timer(0.07)
	t.timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)

func _tick_combat(delta: float) -> void:
	if _t_range <= 0.0:
		return
	if _player == null or hp <= 0:
		return
	_shoot_cd -= delta
	if _shoot_cd > 0.0:
		return
	var d := global_position.distance_to(_player.global_position)
	if d < SHOOT_MIN_DIST or d > _t_range:
		return
	if not _has_los_to_player():
		return
	_shoot_cd = _t_cd
	_try_shoot_player()


func _tick_ai(delta: float) -> void:
	if _player == null or hp <= 0:
		return

	if hp < _last_hp:
		_recent_damage_timer = DAMAGE_MEMORY_TIME
	_last_hp = hp
	if _recent_damage_timer > 0.0:
		_recent_damage_timer -= delta

	if _flank_offset == 0.0:
		_flank_offset = deg_to_rad(randf_range(-FLANK_ARC_DEG, FLANK_ARC_DEG))

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized() if dist > 0.01 else Vector3.FORWARD

	# State selection
	if _recent_damage_timer > 0.0 or hp <= COVER_HP_THRESHOLD:
		_ai_state = AIState.COVER
	elif dist < SHOOT_RANGE and _has_los_to_player():
		_ai_state = AIState.COMBAT
	else:
		_ai_state = AIState.APPROACH

	var move_dir := Vector3.ZERO
	match _ai_state:
		AIState.APPROACH:
			var flank_dir: Vector3 = dir.rotated(Vector3.UP, _flank_offset)
			move_dir = flank_dir
			if dist < ENEMY_PREFERRED_DIST:
				move_dir = -dir
		AIState.COMBAT:
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_dir *= -1.0
				_strafe_timer = randf_range(STRAFE_CHANGE_MIN, STRAFE_CHANGE_MAX)
			var perp: Vector3 = dir.rotated(Vector3.UP, PI * 0.5) * _strafe_dir
			var dist_corr := 0.0
			if dist < ENEMY_PREFERRED_DIST - 2.0:
				dist_corr = -0.6
			elif dist > ENEMY_PREFERRED_DIST + 2.0:
				dist_corr = 0.6
			var combined: Vector3 = perp + dir * dist_corr
			move_dir = combined.normalized() if combined.length() > 0.01 else Vector3.ZERO
		AIState.COVER:
			_cover_timer -= delta
			if _cover_timer <= 0.0 or _cover_target == Vector3.ZERO:
				_cover_target = _find_cover_point()
				_cover_timer = COVER_HOLD_TIME
			if _cover_target == Vector3.INF or _cover_target == Vector3.ZERO:
				move_dir = -dir
			else:
				var to_cover: Vector3 = _cover_target - global_position
				to_cover.y = 0.0
				move_dir = Vector3.ZERO if to_cover.length() < 0.6 else to_cover.normalized()

	var speed: float = (SPEED * _t_speed_mult) if _ai_state == AIState.APPROACH else (STRAFE_SPEED * _t_speed_mult)
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

func _find_cover_point() -> Vector3:
	var covers = get_tree().get_nodes_in_group("cover")
	if covers.is_empty() or _player == null:
		return Vector3.INF
	var player_pos: Vector3 = _player.global_position
	var best: Vector3 = Vector3.INF
	var best_score := -1.0e20
	for node in covers:
		if not (node is Node3D):
			continue
		var cover_pos: Vector3 = (node as Node3D).global_position
		var d_self: float = global_position.distance_to(cover_pos)
		if d_self > COVER_SEARCH_RADIUS:
			continue
		var away: Vector3 = (cover_pos - player_pos)
		away.y = 0.0
		if away.length() < 0.01:
			continue
		var hide: Vector3 = cover_pos + away.normalized() * 1.6
		hide.y = global_position.y
		var score: float = -global_position.distance_to(hide) - d_self * 0.2
		if score > best_score:
			best_score = score
			best = hide
	return best


func _apply_stagger(hit_pos: Vector3, is_headshot: bool) -> void:
	if is_headshot:
		_hit_flash = 0.2
		hp -= 0
	var push: float = 8.0 if is_headshot else 4.0
	var dir: Vector3 = (global_position - hit_pos)
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x += dir.x * push
		velocity.z += dir.z * push


func _die_ragdoll() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector3.ZERO
	# turn off collision + AI
	set_physics_process(false)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	# muzzle/sfx
	SFX.play("hit", -6.0, 0.7)
	# try get body root, ragdoll-rotate it
	var br: Node3D = _body_root
	if br != null:
		var fall_dir := 1.0 if randf() > 0.5 else -1.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(br, "rotation:z", br.rotation.z + deg_to_rad(88.0) * fall_dir, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(br, "position:y", br.position.y - 0.1, 0.6)
	# emit death for wave logic
	emit_signal("died")
	# fade + free
	var t2 := get_tree().create_timer(1.2)
	t2.timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)



func _add_clothing(color: Color) -> void:
	_attach_box("spine_02", Vector3(0.38, 0.42, 0.24), Vector3(0, 0.12, 0), color)
	_attach_box("hips", Vector3(0.36, 0.22, 0.26), Vector3(0, 0.0, 0), color.darkened(0.35))
	_attach_box("thigh_l", Vector3(0.16, 0.35, 0.16), Vector3(0, -0.15, 0), color.darkened(0.35))
	_attach_box("thigh_r", Vector3(0.16, 0.35, 0.16), Vector3(0, -0.15, 0), color.darkened(0.35))
	_attach_box("upperarm_l", Vector3(0.14, 0.20, 0.14), Vector3(0, -0.10, 0), color)
	_attach_box("upperarm_r", Vector3(0.14, 0.20, 0.14), Vector3(0, -0.10, 0), color)
	_attach_box("calf_l", Vector3(0.13, 0.22, 0.13), Vector3(0, -0.20, 0), Color(0.08, 0.08, 0.10))
	_attach_box("calf_r", Vector3(0.13, 0.22, 0.13), Vector3(0, -0.20, 0), Color(0.08, 0.08, 0.10))

func _attach_box(bone: String, size: Vector3, offset: Vector3, color: Color) -> void:
	if _skeleton == null:
		return
	var i := _skeleton.find_bone(bone)
	if i < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = i
	att.bone_name = bone
	_skeleton.add_child(att)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.05
	mesh.material_override = mat
	att.add_child(mesh)


func _apply_type() -> void:
	match enemy_type:
		0:  # GRUNT — baseline
			_t_speed_mult = 1.0
			_t_hp = 3
			_t_range = 18.0
			_t_cd = 1.6
			_t_dmg = 6
			_t_color = Color(0.55, 0.16, 0.16)
		1:  # RUSHER — fast, no gun, melee
			_t_speed_mult = 1.85
			_t_hp = 2
			_t_range = 0.0
			_t_cd = 0.0
			_t_dmg = 0
			_t_color = Color(0.90, 0.42, 0.10)
		2:  # TANK — slow, tough, hits hard
			_t_speed_mult = 0.62
			_t_hp = 10
			_t_range = 14.0
			_t_cd = 2.4
			_t_dmg = 12
			_t_color = Color(0.42, 0.14, 0.62)
		3:  # SNIPER — long range, one hard shot
			_t_speed_mult = 0.85
			_t_hp = 2
			_t_range = 32.0
			_t_cd = 3.2
			_t_dmg = 18
			_t_color = Color(0.92, 0.72, 0.15)
	hp = _t_hp
