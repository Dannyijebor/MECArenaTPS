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

const MAX_HP := 150
const REGEN_DELAY := 3.5
const REGEN_RATE := 14.0
const IFrames_TIME := 1.4
const SPRINT_MULT := 1.55
const CROUCH_MULT := 0.5
const SLIDE_MULT := 2.1
const SLIDE_TIME := 0.65
const SLIDE_COOLDOWN := 1.0
const FOV_BASE := 50.0
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
var _gun_node: Node3D = null
var _weapon_drawn: bool = false
var _draw_timer: float = 0.0
var _holster_timer: float = 0.0
var _holster_wait: float = 0.0
const HOLSTER_DELAY := 3.0
var _gun_muzzle: Node3D = null
var _use_animations: bool = false
var _speed_mult: float = 1.0
var _dmg_mult: float = 1.0
var _regen_delay_mult: float = 1.0
var _regen_rate_mult: float = 1.0
var _heal_bonus: int = 0
var _char_id: String = "SWAT"
var _ability_active: bool = false
var _ability_timer: float = 0.0
var _ability_cd: float = 0.0
const ABILITY_DURATION := 5.0
const ABILITY_COOLDOWN := 7.0
var _carry_weight: float = 0.0
var _max_carry: float = 2400.0
var _carry_mult: float = 1.0
var _walk_phase := 0.0
var _last_step_idx: int = 0
var _model_root: Node3D = null
var hit_marker_time := 0.0
var hit_marker_headshot := false
var damage_numbers: Array = []
var _cam_base_pos := Vector3(0, 0.78, 1.10)
var current_weapon_id: String = WeaponDB.RIFLE
var ammo: int = 0
var _reload_timer: float = 0.0
var _reloading: bool = false
var _recoil_pitch: float = 0.0
var _dying: bool = false
var _death_timer: float = 0.0
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
	tick_ability(delta)
	_tick_weapon_state(delta)
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
		var jv: float = JUMP_VELOCITY
		if _ability_active and _char_id == "AJ":
			jv *= 1.6
		velocity.y = jv
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
	if _ability_active and _char_id == "CH39":
		return  # IRONHIDE: immune to damage
	SFX.play("hurt", -2.0)
	_regen_wait = REGEN_DELAY * _regen_delay_mult
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
	if _dying:
		return
	_dying = true
	_death_timer = 0.0
	# Stop all input, animations on the death clip
	touch_move = Vector2.ZERO
	touch_look = Vector2.ZERO
	touch_fire = false
	touch_jump = false
	touch_crouch = false
	touch_aim = false
	velocity = Vector3.ZERO
	# Play the death animation
	if _anim != null and _anim.has_animation("mixamo/death"):
		_anim.play("mixamo/death", 0.15)
		_anim.speed_scale = 0.85
		print("[player] death animation playing")
	# Slow motion effect — time scale down briefly
	Engine.time_scale = 0.55
	SFX.play("hurt", -1.0, 0.7)
	# Cinematic camera pitch — look down at the corpse
	emit_signal("died")


func is_dying() -> bool:
	return _dying

func respawn() -> void:
	hp = MAX_HP
	_iframes = 1.2
	global_position = Vector3(0, 1.0, 0)
	velocity = Vector3.ZERO
	# Clear death state
	_dying = false
	_death_timer = 0.0
	Engine.time_scale = 1.0
	# Reset camera to normal
	camera.position = _cam_base_pos
	# Return to rifle ready idle
	if _anim != null and _anim.has_animation("mixamo/rifle_idle"):
		_anim.play("mixamo/rifle_idle", 0.2)
		_anim.speed_scale = 1.0
	emit_signal("hp_changed", hp)
	_restore_body_color()

func fire() -> void:
	if _dying:
		return
	if _reloading or _switch_cd > 0.0:
		return
	var wd: Dictionary = WeaponDB.get_data(current_weapon_id)
	if ammo <= 0:
		SFX.play("empty", -4.0)
		_start_reload()
		return
	var cd_val: float = float(wd.get("cooldown", 0.14))
	if _ability_active and _char_id == "SWAT":
		# FOCUS: infinite ammo + 40% faster fire
		cd_val *= 0.6
	else:
		ammo -= 1
	_fire_timer = cd_val
	SFX.play("shoot", 0.0, randf_range(0.96, 1.04))

	# Aim direction still from camera (that's the crosshair)
	var cam_origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var aim_angle: float = float(wd.get("auto_aim_angle", 12.0))
	if _aiming:
		aim_angle *= ADS_AA_MULT
	var target: Node3D = _find_auto_aim_target(cam_origin, forward, aim_angle)
	var base_dir: Vector3 = forward
	if target != null:
		base_dir = (target.global_position + Vector3(0, 0.8, 0) - cam_origin).normalized()

	# Spawn position — from the gun muzzle when available, else fall back to camera
	var muzzle_pos: Vector3 = cam_origin + forward * 0.4
	if _gun_muzzle != null and is_instance_valid(_gun_muzzle):
		muzzle_pos = _gun_muzzle.global_position
	# Recompute direction so bullet goes from muzzle to the aim point
	var aim_point: Vector3 = cam_origin + forward * 60.0
	if target != null:
		aim_point = target.global_position + Vector3(0, 0.8, 0)
	var spawn_dir: Vector3 = (aim_point - muzzle_pos).normalized()

	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var pellets: int = int(wd.get("pellets", 1))
	var spread_rad: float = deg_to_rad(float(wd.get("spread_deg", 1.0)))
	if _aiming:
		spread_rad *= ADS_SPREAD_MULT
	var damage: int = int(wd.get("damage", 5))
	damage = int(float(damage) * _dmg_mult)
	if _ability_active and _char_id == "HEAVY":
		damage *= 3
	var bullet_script: Script = load("res://bullet.gd")

	for i in range(pellets):
		var dir: Vector3 = spawn_dir
		if spread_rad > 0.0:
			dir = dir.rotated(Vector3.UP, randf_range(-spread_rad, spread_rad))
			dir = dir.rotated(Vector3.RIGHT, randf_range(-spread_rad, spread_rad))
		var bullet := Area3D.new()
		bullet.set_script(bullet_script)
		scene.add_child(bullet)
		bullet.global_position = muzzle_pos
		if bullet.has_method("setup"):
			bullet.call("setup", dir, damage)

	# Muzzle flash at the actual gun muzzle
	_spawn_muzzle_flash(muzzle_pos, spawn_dir, cam_origin)

	_recoil_pitch += deg_to_rad(float(wd.get("recoil_pitch", 1.0)))
	if ammo <= 0:
		_start_reload()


func _spawn_muzzle_flash(pos: Vector3, dir: Vector3, cam_pos: Vector3) -> void:
	# Only show flash if the muzzle is visible from the camera's view
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 5.0
	light.omni_range = 5.0
	tree_set_scene_light(light, pos)
	# Sprite flash — small star burst
	var sprite := Sprite3D.new()
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Radial star
	for r in range(16, 0, -1):
		var a: float = clampf(1.0 - (float(r) / 16.0), 0.0, 1.0)
		var c := Color(1.0, 0.85, 0.5, a * 0.9)
		for angle_i in range(8):
			var ang: float = float(angle_i) * TAU / 8.0
			var x: int = int(16 + cos(ang) * r)
			var y: int = int(16 + sin(ang) * r)
			if x >= 0 and x < 32 and y >= 0 and y < 32:
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.pixel_size = 0.006
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.position = pos
	sprite.modulate = Color(1.0, 0.9, 0.6, 1.0)
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(sprite)
	# Freeze flash to fade quickly
	var t := get_tree().create_timer(0.06)
	t.timeout.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.queue_free()
		if is_instance_valid(light):
			light.queue_free()
	)


func tree_set_scene_light(l: OmniLight3D, pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(l)
	l.global_position = pos

func _start_reload() -> void:
	if _ability_active and _char_id == "SWAT":
		return
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
		if _ability_active and _char_id == "MARIA":
			_regen_wait = 0.0
		else:
			_regen_wait -= delta * _regen_rate_mult
			return
	var rate: float = REGEN_RATE
	if _ability_active and _char_id == "MARIA":
		rate *= 4.0
	_regen_accum += rate * delta
	if _regen_accum < 1.0:
		return
	var gain: int = int(_regen_accum)
	_regen_accum -= float(gain)
	var before: int = hp
	hp = min(hp + gain, MAX_HP)
	if hp != before:
		hp_changed.emit(hp)


func heal(amount: int) -> void:
	amount += _heal_bonus
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
	var cam_target := _cam_base_pos + Vector3(0, bob_y, 0)
	if _shake_amt > 0.001:
		cam_target += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amt
		_shake_amt = move_toward(_shake_amt, 0.0, delta * 2.5)
	# Wall clip — pull camera in when a wall is between pivot and camera
	if camera != null and cam_pivot != null:
		var pivot_world: Vector3 = cam_pivot.global_position
		var want_world: Vector3 = cam_pivot.to_global(cam_target)
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(pivot_world, want_world)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var hit_dist: float = pivot_world.distance_to(hit.position)
			var want_dist: float = pivot_world.distance_to(want_world)
			var ratio: float = clampf((hit_dist - 0.35) / max(want_dist, 0.01), 0.12, 1.0)
			cam_target.z = _cam_base_pos.z * ratio
	camera.position = camera.position.lerp(cam_target, delta * 15.0)


func _get_move_speed() -> float:
	var base := SPEED * _speed_mult * _carry_mult
	if _ability_active and _char_id == "AJ":
		base *= 1.9
	if _aiming:
		return base * ADS_SPEED_MULT
	if _sliding:
		return base * SLIDE_MULT
	if _crouching:
		return base * CROUCH_MULT
	if _sprinting:
		return base * SPRINT_MULT
	return base


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
	# Load the selected character model
	var char_data: Dictionary = CharacterDB.get_data(_char_id)
	var model_path: String = String(char_data.get("path", "res://models/avatars/swat.glb"))
	# Fall back to SWAT if the selected model fails to load
	var scene: PackedScene = load(model_path)
	if scene == null:
		print("[player] failed to load ", model_path, " - falling back to SWAT")
		scene = load("res://models/avatars/swat.glb")
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
			SFX.play("footstep", -1.0, randf_range(0.92, 1.08))

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
	if _dying:
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var target := "mixamo/idle"
	var speed_mult := 1.0
	var airborne: bool = not is_on_floor()
	# 1. Holster animation playing
	if _holster_timer > 0.0 and _anim.has_animation("mixamo/holster"):
		target = "mixamo/holster"
		_anim.speed_scale = 1.0
		if _anim.current_animation != target:
			_anim.play(target, 0.12)
		return
	# 2. Holstered — unarmed
	if not _weapon_drawn:
		if speed > 0.4:
			target = "mixamo/walk"
			speed_mult = 0.85 + (speed / 5.5) * 0.45
		else:
			target = "mixamo/idle"
		_anim.speed_scale = speed_mult
		if _anim.current_animation != target and _anim.has_animation(target):
			_anim.play(target, 0.22)
		return
	# 3. Draw animation playing
	if _draw_timer > 0.0 and _anim.has_animation("mixamo/draw"):
		target = "mixamo/draw"
		_anim.speed_scale = 1.2
		if _anim.current_animation != target:
			_anim.play(target, 0.10)
		return
	# 4. AIRBORNE — directional jump animations
	if airborne:
		var fwd_j: Vector3 = -global_transform.basis.z
		var right_j: Vector3 = global_transform.basis.x
		var v_j: Vector3 = Vector3(velocity.x, 0, velocity.z)
		var spd_j: float = v_j.length()
		if spd_j < 0.5:
			target = "mixamo/pistol_jump"
		else:
			var vn: Vector3 = v_j.normalized()
			var f_dot: float = fwd_j.dot(vn)
			var r_dot: float = right_j.dot(vn)
			if f_dot > 0.5:
				target = "mixamo/jump_forward"
			elif f_dot < -0.5:
				target = "mixamo/jump_back"
			elif abs(r_dot) > 0.5:
				target = "mixamo/jump_strafe"
			else:
				target = "mixamo/jump_forward"
		_anim.speed_scale = 1.0
		if _anim.current_animation != target and _anim.has_animation(target):
			_anim.play(target, 0.10)
		return
	# 5. RELOADING — full reload cycle
	if _reloading and _anim.has_animation("mixamo/reload"):
		target = "mixamo/reload"
		_anim.speed_scale = 1.0
		if _anim.current_animation != target:
			_anim.play(target, 0.15)
		return
	# 6. CROUCHING — directional crouch animations
	if _crouching or _sliding:
		if speed < 0.4:
			target = "mixamo/crouch_idle"
		else:
			var fwd_c: Vector3 = -global_transform.basis.z
			var right_c: Vector3 = global_transform.basis.x
			var v_c: Vector3 = Vector3(velocity.x, 0, velocity.z).normalized()
			var f_dot_c: float = fwd_c.dot(v_c)
			var r_dot_c: float = right_c.dot(v_c)
			if f_dot_c > 0.5:
				target = "mixamo/crouch_walk"
			elif f_dot_c < -0.5:
				target = "mixamo/crouch_back"
			elif r_dot_c > 0.5:
				target = "mixamo/crouch_right"
			elif r_dot_c < -0.5:
				target = "mixamo/crouch_left"
			else:
				target = "mixamo/crouch_walk"
			speed_mult = 0.9 + (speed / 4.0) * 0.4
		_anim.speed_scale = speed_mult
		if _anim.current_animation != target and _anim.has_animation(target):
			_anim.play(target, 0.18)
		return
	# 7. WEAPON DRAWN, UPRIGHT — combat states
	var fire_window: float = float(WeaponDB.get_data(current_weapon_id).get("cooldown", 0.14)) - 0.08
	if _fire_timer > fire_window and _anim.has_animation("mixamo/fire"):
		target = "mixamo/fire"
	elif _aiming and speed < 0.5 and _anim.has_animation("mixamo/aim"):
		target = "mixamo/aim"
	elif speed > 4.5:
		target = "mixamo/run"
		speed_mult = 1.05
	elif speed > 0.4:
		var fwd2: Vector3 = -global_transform.basis.z
		var to_vel: Vector3 = Vector3(velocity.x, 0, velocity.z)
		if fwd2.dot(to_vel) < 0.0:
			target = "mixamo/walk_back"
		else:
			target = "mixamo/walk"
		speed_mult = 0.9 + (speed / 5.5) * 0.4
	else:
		target = "mixamo/rifle_idle"
	# Fallback
	if not _anim.has_animation(target):
		if _anim.has_animation("mixamo/rifle_idle"):
			target = "mixamo/rifle_idle"
		elif _anim.has_animation("mixamo/idle"):
			target = "mixamo/idle"
		else:
			return
	_anim.speed_scale = speed_mult
	if _anim.current_animation != target:
		_anim.play(target, 0.15)


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
	# Pick model based on current weapon
	var model_path := "res://models/weapons/Guns/MGP7/MGP7_Rigged.glb"
	match current_weapon_id:
		WeaponDB.SMG:
			model_path = "res://models/weapons/Guns/ZC57/ZC57_Rigged.glb"
		WeaponDB.SHOTGUN:
			model_path = "res://models/weapons/Guns/ZC57/ZC57_Rigged.glb"
	var gun: Node3D = gun_script.build_from_glb(att, model_path)
	# Orient for Mixamo hand — barrel forward
	gun.rotation_degrees = Vector3(90, 0, 0)
	gun.position = Vector3(0.0, 0.06, 0.0)
	gun.scale = Vector3(1.2, 1.2, 1.2)
	_gun_node = gun
	gun.visible = false
	# Add a muzzle marker at the barrel tip for accurate spawn position
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.015, -0.68)
	gun.add_child(muzzle)
	_gun_muzzle = muzzle


func _tick_weapon_state(delta: float) -> void:
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var should_draw := _aiming or touch_fire or speed > 3.0
	if should_draw and not _weapon_drawn:
		_weapon_drawn = true
		_draw_timer = 0.6
		_holster_wait = 0.0
		if _gun_node != null:
			_gun_node.visible = true
	if _weapon_drawn and not should_draw:
		_holster_wait += delta
		if _holster_wait >= HOLSTER_DELAY:
			_weapon_drawn = false
			_holster_wait = 0.0
			_holster_timer = 0.6
			if _gun_node != null:
				_gun_node.visible = false
	if _draw_timer > 0.0:
		_draw_timer -= delta
	if _holster_timer > 0.0:
		_holster_timer -= delta


func is_weapon_drawn() -> bool:
	return _weapon_drawn


func _apply_character_stats() -> void:
	var d: Dictionary = CharacterDB.get_data(_char_id)
	_speed_mult = float(d.get("speed_mult", 1.0))
	_dmg_mult = float(d.get("dmg_mult", 1.0))
	_regen_delay_mult = float(d.get("regen_delay_mult", 1.0))
	_regen_rate_mult = float(d.get("regen_rate_mult", 1.0))
	_heal_bonus = int(d.get("heal_bonus", 0))
	# Apply HP multiplier
	var hp_mult: float = float(d.get("hp_mult", 1.0))
	max_hp = int(float(MAX_HP) * hp_mult)
	hp = max_hp
	if hp_changed:
		hp_changed.emit(hp)
	print("[player] char: ", _char_id, "  hp=", max_hp, "  spd=", _speed_mult, "  dmg=", _dmg_mult)


func _refresh_character() -> void:
	if NetworkManager != null:
		_char_id = NetworkManager.selected_character
	print("[player] refreshing to character: ", _char_id)
	# Collect all model roots to remove
	var to_remove: Array = []
	for c in get_children():
		if c == cam_pivot:
			continue
		if c is CollisionShape3D:
			continue
		if c is MeshInstance3D:
			to_remove.append(c)
			continue
		if c is Node3D:
			# Anything with Skeleton3D or AnimationPlayer is a model root
			if c.find_child("Skeleton3D", true, false) != null:
				to_remove.append(c)
			elif c.find_child("AnimationPlayer", true, false) != null:
				to_remove.append(c)
	for c in to_remove:
		remove_child(c)
		c.queue_free()
	# Reset animation refs
	_anim = null
	_skeleton = null
	_bones.clear()
	_use_animations = false
	# Load new character model
	_setup_human_visual()
	# Reapply stats and reset HP
	_apply_character_stats()
	hp = max_hp
	if hp_changed:
		hp_changed.emit(hp)


func activate_ability() -> void:
	if _ability_active or _ability_cd > 0.0:
		return
	if hp <= 0:
		return
	_ability_active = true
	_ability_timer = ABILITY_DURATION
	print("[ability] activated: ", _char_id)
	# Instant effects (some abilities fire once on activation)
	match _char_id:
		"MARIA":
			# Instant full heal
			var before: int = hp
			hp = max_hp
			if hp != before and hp_changed:
				hp_changed.emit(hp)
			SFX.play("wave_clear", -4.0, 1.4)
		_:
			SFX.play("reload", -2.0, 1.3)


func tick_ability(delta: float) -> void:
	if _ability_active:
		_ability_timer -= delta
		if _ability_timer <= 0.0:
			_ability_active = false
			_ability_timer = 0.0
			_ability_cd = ABILITY_COOLDOWN
			print("[ability] expired, cooldown started")
	elif _ability_cd > 0.0:
		_ability_cd -= delta
		if _ability_cd <= 0.0:
			_ability_cd = 0.0


func get_ability_state() -> Dictionary:
	return {
		"active": _ability_active,
		"remaining": _ability_timer,
		"cooldown": _ability_cd,
		"duration": ABILITY_DURATION,
		"cd_max": ABILITY_COOLDOWN,
		"id": _char_id,
	}
