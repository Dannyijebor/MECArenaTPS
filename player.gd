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
const SPRINT_MULT := 1.55
const CROUCH_MULT := 0.5
const SLIDE_MULT := 2.1
const SLIDE_TIME := 0.65
const SLIDE_COOLDOWN := 1.0
const FOV_BASE := 55.0
const FOV_SPRINT := 88.0
const FOV_SLIDE := 96.0
const ADS_FOV := 55.0
const ADS_SPEED_MULT := 0.55
const ADS_SPREAD_MULT := 0.5
const ADS_RECOIL_MULT := 0.6
const ADS_AA_MULT := 0.5
const ADS_CAM_Y := 1.55
const STAND_EYE_Y := 1.4
const CROUCH_EYE_Y := 0.9
const SLIDE_EYE_Y := 0.6
const SPRINT_THRESHOLD := 0.85
const SPRINT_HOLD_TIME := 0.2

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
var _sprinting := false
var _sprint_hold := 0.0
var _crouching := false
var _sliding := false
var _aiming := false
var _slide_timer := 0.0
var _slide_cd := 0.0
var _slide_dir := Vector3.ZERO
var _was_on_floor := true
var _shake_amt := 0.0
var _skeleton: Skeleton3D = null
var _bones: Dictionary = {}
var _anim: AnimationPlayer = null
var _use_animations: bool = false
var _carry_weight: float = 0.0
var _max_carry: float = 2400.0
var _carry_mult: float = 1.0
var _walk_phase := 0.0
var _last_step_idx: int = 0
var _model_root: Node3D = null
var hit_marker_time := 0.0
var hit_marker_headshot := false
var damage_numbers: Array = []
var _cam_base_pos := Vector3(0, 0.70, 1.55)
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
var touch_crouch := false
var touch_aim := false

func _ready() -> void:
	_setup_human_visual()
	ammo = WeaponDB.mag_size(current_weapon_id)
	_cam_base_pos = camera.position
	camera.fov = FOV_BASE
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
	_tick_movement_feel(delta)
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
		velocity.x = direction.x * _get_move_speed()
		velocity.z = direction.z * _get_move_speed()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 4.0 * delta * 10)
		velocity.z = move_toward(velocity.z, 0, SPEED * 4.0 * delta * 10)

	if touch_fire and _fire_timer <= 0.0:
		fire()

	rotation.y = _yaw

	cam_pivot.rotation.x = deg_to_rad(_pitch) - _recoil_pitch

	if _sliding and _slide_dir.length() > 0.01:
		velocity.x = _slide_dir.x * SPEED * SLIDE_MULT
		velocity.z = _slide_dir.z * SPEED * SLIDE_MULT
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
	if _aiming:
		aim_angle *= ADS_AA_MULT
	var target: Node3D = _find_auto_aim_target(origin, forward, aim_angle)
	var base_dir: Vector3 = forward
	if target != null:
		base_dir = (target.global_position + Vector3(0, 0.8, 0) - origin).normalized()

	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var pellets: int = int(wd.get("pellets", 1))
	var spread_rad: float = deg_to_rad(float(wd.get("spread_deg", 1.0)))
	if _aiming:
		spread_rad *= ADS_SPREAD_MULT
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

	var rp: float = float(wd.get("recoil_pitch", 1.0))
	if _aiming:
		rp *= ADS_RECOIL_MULT
	_recoil_pitch += deg_to_rad(rp)

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


func _tick_movement_feel(delta: float) -> void:
	_aiming = touch_aim and not _sliding
	_tick_player_walk(delta)
	if hit_marker_time > 0.0:
		hit_marker_time -= delta
	for dn in damage_numbers:
		dn["life"] -= delta
	damage_numbers = damage_numbers.filter(func(d): return d["life"] > 0.0)
	var stick_len: float = touch_move.length()

	if stick_len > SPRINT_THRESHOLD:
		_sprint_hold += delta
		if _sprint_hold >= SPRINT_HOLD_TIME:
			_sprinting = true
	else:
		_sprint_hold = 0.0
		_sprinting = false

	if _slide_cd > 0.0:
		_slide_cd -= delta

	_crouching = touch_crouch and not _sliding

	if touch_crouch and _sprinting and not _sliding and _slide_cd <= 0.0 and is_on_floor():
		var dir2 := Vector3(touch_move.x, 0, touch_move.y)
		if dir2.length() > 0.2:
			dir2 = dir2.rotated(Vector3.UP, rotation.y).normalized()
			_sliding = true
			_slide_timer = SLIDE_TIME
			_slide_cd = SLIDE_COOLDOWN + SLIDE_TIME
			_slide_dir = dir2
			SFX.play("reload", -8.0, 1.9)

	if _sliding:
		_slide_timer -= delta
		if _slide_timer <= 0.0:
			_sliding = false

	var target_y := STAND_EYE_Y
	if _aiming:
		target_y = ADS_CAM_Y
	if _sliding:
		target_y = SLIDE_EYE_Y
	elif _crouching:
		target_y = CROUCH_EYE_Y
	cam_pivot.position.y = lerp(cam_pivot.position.y, target_y, delta * 12.0)

	var target_fov := FOV_BASE
	if _aiming and not _sliding:
		target_fov = ADS_FOV
	elif _sliding:
		target_fov = FOV_SLIDE
	elif _sprinting and stick_len > 0.5:
		target_fov = FOV_SPRINT
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var fall_speed: float = abs(velocity.y)
		if fall_speed > 3.0:
			_shake_amt = clampf(fall_speed / 30.0, 0.05, 0.35)
			SFX.play("hurt", -12.0, 0.7)
	_was_on_floor = on_floor

	# Head bob — camera rises/falls per step
	var bob_y := 0.0
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 0.5 and not _sliding:
		bob_y = sin(_walk_phase * 2.0) * 0.022
	elif horiz_speed < 0.3:
		bob_y = sin(Time.get_ticks_msec() * 0.001 * 1.9) * 0.006
	if _shake_amt > 0.001:
		var ox := randf_range(-1.0, 1.0) * _shake_amt
		var oy := randf_range(-1.0, 1.0) * _shake_amt
		var oz := randf_range(-1.0, 1.0) * _shake_amt
		camera.position = _cam_base_pos + Vector3(ox, oy + bob_y, oz)
		_shake_amt = move_toward(_shake_amt, 0.0, delta * 2.5)
	else:
		camera.position = _cam_base_pos + Vector3(0, bob_y, 0)


func _get_move_speed() -> float:
	if _aiming:
		return SPEED * ADS_SPEED_MULT * _carry_mult
	if _sliding:
		return SPEED * SLIDE_MULT * _carry_mult
	if _crouching:
		return SPEED * CROUCH_MULT * _carry_mult
	if _sprinting:
		return SPEED * SPRINT_MULT * _carry_mult
	return SPEED * _carry_mult


func report_hit(dmg: int, is_headshot: bool, world_pos: Vector3) -> void:
	hit_marker_time = 0.14
	hit_marker_headshot = is_headshot
	damage_numbers.append({
		"value": dmg,
		"pos": world_pos + Vector3(0, 0.3, 0),
		"life": 0.85,
		"max_life": 0.85,
		"headshot": is_headshot,
	})
	if damage_numbers.size() > 12:
		damage_numbers.pop_front()
	if is_headshot:
		SFX.play("hit", -1.0, 1.35)
	else:
		SFX.play("hit", -4.0, randf_range(0.95, 1.08))



func _setup_human_visual() -> void:
	# Hide the procedural capsule
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false

	# Load the SWAT GLB — real Mixamo-rigged tactical character
	var scene: PackedScene = load("res://models/avatars/swat.glb")
	if scene == null:
		print("[player] swat.glb not found")
		return
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	inst.position = Vector3(0, 0, 0)
	inst.rotation.y = PI

	# Find AnimationPlayer
	_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		_skeleton = _find_skeleton(inst)
	if _anim != null and _skeleton != null:
		var rig_script: Script = load("res://anim_rig.gd")
		if rig_script != null:
			var ok: bool = rig_script.attach(_anim, _skeleton)
			print("[player] rig attach: ", ok)
			if ok:
				_anim.play("mixamo/idle")
	_attach_gun_to_hand(inst)

	# Disable procedural animation — bones are Mixamo, code expects Quaternius names
	_use_animations = true

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null

func _cache_bones() -> void:
	var wanted := ["thigh_l", "thigh_r", "calf_l", "calf_r",
		"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
		"hand_l", "hand_r", "spine_01", "spine_02", "hips", "neck", "head"]
	for name in wanted:
		var i := _skeleton.find_bone(name)
		if i >= 0:
			_bones[name] = i

func _autoscale(root: Node3D) -> void:
	var aabb := _compute_aabb(root)
	if aabb.size.y < 0.01:
		return
	var scale_factor: float = 1.75 / aabb.size.y
	root.scale = Vector3(scale_factor, scale_factor, scale_factor)
	# sink model so feet touch ground — model pos is offset later

func _compute_aabb(n: Node) -> AABB:
	var total := AABB()
	var first := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var m := c as MeshInstance3D
			var a := m.get_aabb()
			var t := m.transform
			var world_a := t * a
			if first:
				total = world_a; first = false
			else:
				total = total.merge(world_a)
		total = total.merge(_compute_aabb(c)) if not first else total
	return total

func _set_bone_local(bone: String, pitch: float, roll: float = 0.0, yaw: float = 0.0) -> void:
	if not _bones.has(bone):
		return
	var idx: int = _bones[bone]
	var rest: Basis = _skeleton.get_bone_rest(idx).basis
	var extra := Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Basis(Vector3.FORWARD, deg_to_rad(roll)) * Basis(Vector3.UP, deg_to_rad(yaw))
	_skeleton.set_bone_pose_rotation(idx, (rest * extra).get_rotation_quaternion())

func _apply_aim_once() -> void:
	_set_bone_local("upperarm_l", 0.0, 72.0, -12.0)
	_set_bone_local("upperarm_r", 0.0, -72.0, 12.0)
	_set_bone_local("lowerarm_l", 0.0, 55.0, 0.0)
	_set_bone_local("lowerarm_r", 0.0, -55.0, 0.0)
	_set_bone_local("hand_l", 0.0, 0.0, 15.0)
	_set_bone_local("hand_r", 0.0, 0.0, -15.0)

func _tick_player_walk(delta: float) -> void:
	# Procedural bone-writing disabled — Mixamo animations drive the skeleton
	if _use_animations and _anim != null:
		_tick_animation_state()
	# Footsteps still fire off walk phase
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed > 0.4 and is_on_floor():
		# Advance phase by TIME, not frame — gives ~2 steps/sec at walk, ~4 at sprint
		_walk_phase += (speed / 5.5) * 4.0 * delta
		var step_idx: int = int(_walk_phase)
		if step_idx != _last_step_idx:
			_last_step_idx = step_idx
			SFX.play("footstep", -3.0, randf_range(0.92, 1.08))

func _add_clothing(color: Color) -> void:
	# Shirt
	_attach_box("spine_02", Vector3(0.38, 0.42, 0.24), Vector3(0, 0.12, 0), color)
	# Belt / pants top
	_attach_box("hips", Vector3(0.36, 0.22, 0.26), Vector3(0, 0.0, 0), color.darkened(0.35))
	# Thighs
	_attach_box("thigh_l", Vector3(0.16, 0.35, 0.16), Vector3(0, -0.15, 0), color.darkened(0.35))
	_attach_box("thigh_r", Vector3(0.16, 0.35, 0.16), Vector3(0, -0.15, 0), color.darkened(0.35))
	# Sleeves
	_attach_box("upperarm_l", Vector3(0.14, 0.20, 0.14), Vector3(0, -0.10, 0), color)
	_attach_box("upperarm_r", Vector3(0.14, 0.20, 0.14), Vector3(0, -0.10, 0), color)
	# Boots
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


func set_carry_weight(amount: float) -> void:
	_carry_weight = max(0.0, amount)
	var ratio: float = clampf(_carry_weight / _max_carry, 0.0, 1.0)
	# Up to -45% movement speed at full carry
	_carry_mult = 1.0 - ratio * 0.45


func get_carry_ratio() -> float:
	return clampf(_carry_weight / _max_carry, 0.0, 1.0)


func get_carry_weight() -> float:
	return _carry_weight


func _tick_animation_state() -> void:
	if _anim == null:
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var target := "mixamo/idle"
	var speed_mult := 1.0
	if _aiming and speed < 0.5:
		target = "mixamo/rifle_idle"
	elif _crouching or _sliding:
		if speed > 0.4:
			target = "mixamo/crouch_walk"
			speed_mult = 0.9 + (speed / 4.0) * 0.4
		else:
			target = "mixamo/idle"
	elif speed > 0.4:
		var fwd: Vector3 = -global_transform.basis.z
		var to_vel: Vector3 = Vector3(velocity.x, 0, velocity.z)
		var forward_dot: float = fwd.dot(to_vel)
		if forward_dot < 0.0:
			target = "mixamo/walk_back"
			speed_mult = 0.9 + (speed / 5.5) * 0.3
		elif speed > 4.5:
			target = "mixamo/run"
			speed_mult = 1.0 + (speed / 8.0) * 0.25
		else:
			target = "mixamo/walk"
			speed_mult = 0.85 + (speed / 5.5) * 0.45
	if not _anim.has_animation(target):
		if _anim.has_animation("mixamo/idle"):
			target = "mixamo/idle"
		else:
			return
	_anim.speed_scale = speed_mult
	if _anim.current_animation != target:
		_anim.play(target, 0.22)


func _attach_gun_to_hand(model: Node3D) -> void:
	# SWAT ships TWO skeletons — face (7 bones) + body (51 bones). We want the body.
	var skel: Skeleton3D = null
	var best_bone_count: int = 0
	var stack: Array = [model]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			var s := n as Skeleton3D
			if s.get_bone_count() > best_bone_count:
				best_bone_count = s.get_bone_count()
				skel = s
		for c in n.get_children():
			stack.append(c)
	if skel == null:
		return
	print("[player] using skeleton with ", best_bone_count, " bones")
	var hand_idx: int = -1
	# Search every bone in the skeleton for a name matching "RightHand" exactly
	for i in range(skel.get_bone_count()):
		var bn: String = skel.get_bone_name(i)
		var lower: String = bn.to_lower()
		if lower.ends_with("righthand") or lower.ends_with("hand_r") or lower.ends_with("hand.r") or lower.ends_with("hand_r_end") or lower.ends_with("r_hand"):
			hand_idx = i
			print("[player] gun hand bone found: ", bn, " (idx ", i, ")")
			break
	if hand_idx < 0:
		# Fallback: search for anything with "hand" and "r" in name
		for i in range(skel.get_bone_count()):
			var bn2: String = skel.get_bone_name(i).to_lower()
			if "hand" in bn2 and ("r" in bn2 or "right" in bn2):
				hand_idx = i
				print("[player] gun hand bone (fuzzy): ", skel.get_bone_name(i))
				break
	if hand_idx < 0:
		hand_idx = skel.get_bone_count() - 1
		print("[player] gun hand fallback: ", skel.get_bone_name(hand_idx))
	var att := BoneAttachment3D.new()
	att.bone_idx = hand_idx
	att.bone_name = skel.get_bone_name(hand_idx)
	skel.add_child(att)
	var gun_script: Script = load("res://gun.gd")
	if gun_script == null:
		return
	var gun: Node3D = gun_script.build(att)
	# Orient for Mixamo hand — rotate so barrel points forward
	gun.rotation_degrees = Vector3(0, 90, 90)
	gun.position = Vector3(0.0, 0.04, 0.02)
	gun.scale = Vector3(0.9, 0.9, 0.9)
