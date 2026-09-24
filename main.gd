extends Node3D
const SFX := preload("res://sfx.gd")

const FLOOR_SIZE := 40.0

# Wave system
var _wave := 0
var _kills := 0
var _enemies_alive := 0
var _wave_cooldown := 0.0
var _between_waves := false

# UI reference
var _ui: Node = null
var _ambient_player: AudioStreamPlayer = null
var _distant_timer: float = 0.0

func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_player()
	_build_lighting()
	_build_environment_obstacles()
	_build_arena_walls()
	_build_platforms()
	_build_grid_marks()
	_build_details()
	_build_touch_controls()
	_build_ambient()
	# Wait a frame so UI is in the tree, then cache it
	await get_tree().process_frame
	_ui = get_node_or_null("TouchControlsLayer/TouchControls")
	_start_wave(1)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.13
	env.environment = e
	add_child(env)
	e.fog_enabled = true
	e.fog_light_color = Color(0.06, 0.07, 0.11)
	e.fog_light_energy = 0.7
	e.fog_density = 0.055
	e.fog_sky_affect = 0.3


func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.17, 0.22)
	floor_mesh.material_override = mat
	add_child(floor_mesh)

	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(FLOOR_SIZE, 0.2, FLOOR_SIZE)
	floor_col.shape = shape
	floor_col.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_col)
	add_child(floor_body)

func _build_player() -> void:
	var player_script = load("res://player.gd")
	var player := CharacterBody3D.new()
	player.set_script(player_script)
	player.position = Vector3(0, 1.0, 0)
	player.name = "Player"
	player.add_to_group("player")

	var body_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	body_mesh.mesh = capsule
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.7, 1.0)
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0, 0.8, 0)
	player.add_child(body_mesh)

	var col := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.6
	col.shape = capsule_shape
	col.position = Vector3(0, 0.8, 0)
	player.add_child(col)

	var cam_pivot := Node3D.new()
	cam_pivot.name = "CamPivot"
	cam_pivot.position = Vector3(0, 1.4, 0)
	player.add_child(cam_pivot)

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 0.6, 4.0)
	camera.rotation_degrees = Vector3(-8, 0, 0)
	camera.current = true
	cam_pivot.add_child(camera)

	add_child(player)
	# Connect respawn on death
	player.connect("died", Callable(self, "_on_player_died"))

func _build_lighting() -> void:
	# Dim moonlight bleeding through the roof
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-75, -30, 0)
	sun.light_energy = 0.18
	sun.light_color = Color(0.55, 0.65, 0.85)
	add_child(sun)

	# Interior fixture lights — hot center, cool corners
	var fixtures := [
		{"pos": Vector3(0, 3.4, 0),     "col": Color(1.0, 0.78, 0.45), "e": 3.2, "r": 16.0},
		{"pos": Vector3(-12, 3.4, -12), "col": Color(0.45, 0.65, 1.0), "e": 2.4, "r": 12.0},
		{"pos": Vector3( 12, 3.4, -12), "col": Color(0.45, 0.65, 1.0), "e": 2.4, "r": 12.0},
		{"pos": Vector3(-12, 3.4,  12), "col": Color(0.45, 0.65, 1.0), "e": 2.4, "r": 12.0},
		{"pos": Vector3( 12, 3.4,  12), "col": Color(0.45, 0.65, 1.0), "e": 2.4, "r": 12.0},
	]
	for fx in fixtures:
		var light := OmniLight3D.new()
		light.light_color = fx.col
		light.light_energy = fx.e
		light.omni_range = fx.r
		light.position = fx.pos
		add_child(light)
		# visible bulb
		var bulb := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.10
		sph.height = 0.20
		bulb.mesh = sph
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = fx.col
		bmat.emission_enabled = true
		bmat.emission = fx.col
		bmat.emission_energy_multiplier = 4.0
		bulb.material_override = bmat
		bulb.position = fx.pos
		add_child(bulb)

func _build_touch_controls() -> void:
	var controls_script = load("res://touch_controls.gd")
	var canvas := CanvasLayer.new()
	canvas.name = "TouchControlsLayer"
	var controls := Control.new()
	controls.name = "TouchControls"
	controls.set_script(controls_script)
	canvas.add_child(controls)
	add_child(canvas)

func _build_environment_obstacles() -> void:
	# Cover walls: {x, z, width, depth, height}
	var walls := [
		{"x": -12, "z": -12, "w": 1.0, "d": 6.0, "h": 2.5},
		{"x": 12, "z": -12, "w": 1.0, "d": 6.0, "h": 2.5},
		{"x": -12, "z": 12, "w": 1.0, "d": 6.0, "h": 2.5},
		{"x": 12, "z": 12, "w": 1.0, "d": 6.0, "h": 2.5},
		{"x": 0, "z": -18, "w": 8.0, "d": 1.0, "h": 2.2},
		{"x": 0, "z": 18, "w": 8.0, "d": 1.0, "h": 2.2},
	]
	for wall in walls:
		_build_wall(wall.x, wall.z, wall.w, wall.d, wall.h)

	# Low cover boxes (crouch-height, h=1.0)
	var cover := [
		{"x": -6, "z": -6, "w": 2.0, "d": 2.0, "h": 1.0},
		{"x": 6, "z": -6, "w": 2.0, "d": 2.0, "h": 1.0},
		{"x": -6, "z": 6, "w": 2.0, "d": 2.0, "h": 1.0},
		{"x": 6, "z": 6, "w": 2.0, "d": 2.0, "h": 1.0},
		{"x": 0, "z": 0, "w": 1.6, "d": 1.6, "h": 1.2},
	]
	for c in cover:
		_build_wall(c.x, c.z, c.w, c.d, c.h, true)

func _build_wall(x: float, z: float, w: float, d: float, h: float, is_cover: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	if is_cover:
		mat.albedo_color = Color(0.22, 0.24, 0.30)
		mat.roughness = 0.85
	else:
		mat.albedo_color = Color(0.18, 0.20, 0.26)
		mat.roughness = 0.75
		mat.metallic = 0.3
	mesh.material_override = mat
	mesh.position = Vector3(x, h / 2.0, z)
	add_child(mesh)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, d)
	col.shape = shape
	body.add_child(col)
	body.add_to_group("cover")
	body.position = Vector3(x, h / 2.0, z)
	add_child(body)

func _spawn_wave_enemies(count: int) -> void:
	var enemy_script = load("res://enemy.gd")
	var corners := [
		Vector3(-15.0, 1.0, -15.0),
		Vector3( 15.0, 1.0, -15.0),
		Vector3(-15.0, 1.0,  15.0),
		Vector3( 15.0, 1.0,  15.0),
	]
	# Compose type mix by wave
	var types: Array = []
	for i in range(count):
		var t := 0
		var r := randf()
		if _wave >= 7 and r < 0.15:
			t = 3
		elif _wave >= 5 and r < 0.40:
			t = 2
		elif _wave >= 3 and r < 0.65:
			t = 1
		types.append(t)
	for i in range(count):
		var base: Vector3 = corners[i % corners.size()]
		var jitter := Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
		var pos: Vector3 = base + jitter
		_spawn_enemy_at(pos, enemy_script, types[i])

func _spawn_enemy_at(pos: Vector3, enemy_script: Script, type_idx: int = 0) -> void:
	# Darkness puff
	_spawn_spawn_puff(pos)
	# Low rumble
	SFX.play("enemy_shoot", -10.0, 0.45)

	var e := CharacterBody3D.new()
	e.set_script(enemy_script)
	e.enemy_type = type_idx
	e.position = pos
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)
	e.add_child(col)
	add_child(e)
	e.connect("died", Callable(self, "_on_enemy_died"))
	# Scale-in from shadow
	e.scale = Vector3(0.1, 0.1, 0.1)
	var tw := create_tween()
	tw.tween_property(e, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_enemies_alive += 1

func _spawn_spawn_puff(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.amount = 40
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.15, 0.02, 0.04)
	pm.emission_enabled = true
	pm.emission = Color(0.55, 0.08, 0.12)
	pm.emission_energy_multiplier = 2.0
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material = pm
	p.mesh = sph
	add_child(p)
	p.global_position = pos
	var t := get_tree().create_timer(1.4)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

func _start_wave(n: int) -> void:
	SFX.play("wave_start", -4.0)
	_wave = n
	_between_waves = false
	var count := 3 + (n - 1) * 2
	_spawn_wave_enemies(count)
	_spawn_medkits(1 + int((n - 1) / 2))

func _on_enemy_died() -> void:
	_kills += 1
	_enemies_alive -= 1
	if _enemies_alive <= 0 and not _between_waves:
		_between_waves = true
		_wave_cooldown = 2.5
	SFX.play("wave_clear", -4.0)

func _on_player_died() -> void:
	# Freeze input briefly, then respawn
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func(): _respawn_player())

func _respawn_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("respawn"):
		player.call("respawn")

func _process(delta: float) -> void:
	if _distant_timer > 0.0:
		_distant_timer -= delta
		if _distant_timer <= 0.0:
			SFX.play("distant_gunfire", -18.0, randf_range(0.85, 1.1))
			_distant_timer = randf_range(5.0, 12.0)
	if _between_waves and _wave_cooldown > 0.0:
		_wave_cooldown -= delta
		if _wave_cooldown <= 0.0:
			_start_wave(_wave + 1)
	# Push state to UI
	if _ui != null and _ui.has_method("set_state"):
		_ui.call("set_state", _wave, _kills)


func _spawn_medkits(count: int) -> void:
	var script := load("res://medkit.gd")
	for i in range(count):
		var angle := randf() * TAU
		var radius := 5.0 + randf() * 7.0
		var pos := Vector3(cos(angle) * radius, 0.6, sin(angle) * radius)
		var mk := Area3D.new()
		mk.set_script(script)
		mk.position = pos
		add_child(mk)


func _build_arena_walls() -> void:
	# Outer shell — 4 walls, 4m tall
	var half := FLOOR_SIZE * 0.5 - 0.5
	var wall_h := 4.0
	_place_wall_block(0.0, -half, FLOOR_SIZE, 0.5, wall_h)
	_place_wall_block(0.0,  half, FLOOR_SIZE, 0.5, wall_h)
	_place_wall_block(-half, 0.0, 0.5, FLOOR_SIZE, wall_h)
	_place_wall_block( half, 0.0, 0.5, FLOOR_SIZE, wall_h)

	# Roof — closes the ceiling
	var roof := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(FLOOR_SIZE, 0.4, FLOOR_SIZE)
	roof.mesh = rbox
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.06, 0.07, 0.11)
	rmat.roughness = 0.95
	roof.material_override = rmat
	roof.position = Vector3(0, wall_h + 0.2, 0)
	add_child(roof)
	var rbody := StaticBody3D.new()
	var rcol := CollisionShape3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = Vector3(FLOOR_SIZE, 0.4, FLOOR_SIZE)
	rcol.shape = rshape
	rbody.add_child(rcol)
	rbody.position = Vector3(0, wall_h + 0.2, 0)
	add_child(rbody)

	# Interior cross-walls dividing into 4 rooms, with 6m center doorways + 3m side doors
	# Horizontal divider (along X, at z=0)
	_place_wall_block(-12.0, 0.0, 16.0, 0.4, 3.2)   # left of center gap
	_place_wall_block( 12.0, 0.0, 16.0, 0.4, 3.2)   # right of center gap
	# Vertical divider (along Z, at x=0)
	_place_wall_block(0.0, -12.0, 0.4, 16.0, 3.2)
	_place_wall_block(0.0,  12.0, 0.4, 16.0, 3.2)

	# Interior doorways in the outside walls — 4 openings (N/S/E/W midpoints)
	# By NOT blocking those areas (outer walls are continuous, so carve not needed — enemies spawn INSIDE)

	# Center pillars for cover in the hub room
	_place_pillar(-3.0, -3.0, 0.8, 3.4)
	_place_pillar( 3.0, -3.0, 0.8, 3.4)
	_place_pillar(-3.0,  3.0, 0.8, 3.4)
	_place_pillar( 3.0,  3.0, 0.8, 3.4)

func _place_wall_block(x: float, z: float, w: float, d: float, h: float) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.15, 0.20)
	mat.roughness = 0.88
	mat.metallic = 0.15
	mesh.material_override = mat
	mesh.position = Vector3(x, h * 0.5, z)
	add_child(mesh)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, d)
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(x, h * 0.5, z)
	body.add_to_group("cover")
	add_child(body)

func _place_pillar(x: float, z: float, w: float, h: float) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, w)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.19, 0.26)
	mat.roughness = 0.7
	mat.metallic = 0.3
	mesh.material_override = mat
	mesh.position = Vector3(x, h * 0.5, z)
	add_child(mesh)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, w)
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(x, h * 0.5, z)
	body.add_to_group("cover")
	add_child(body)

func _build_platforms() -> void:
	# Two raised platforms with ramps — gives verticality
	_build_platform(-10.0, -10.0, 4.0, 2.0)
	_build_platform( 10.0,  10.0, 4.0, 2.0)

func _build_platform(x: float, z: float, w: float, h: float) -> void:
	# Platform top
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, w)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.26, 0.32)
	mat.metallic = 0.4
	mat.roughness = 0.7
	mesh.material_override = mat
	mesh.position = Vector3(x, h * 0.5, z)
	add_child(mesh)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, w)
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(x, h * 0.5, z)
	body.add_to_group("cover")
	add_child(body)
	# Ramp toward center
	var ramp := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(2.0, 0.3, 3.2)
	ramp.mesh = rbox
	ramp.material_override = mat
	var dir_x := 1.0 if x < 0 else -1.0
	var dir_z := 1.0 if z < 0 else -1.0
	ramp.position = Vector3(x + dir_x * (w * 0.5 + 1.2), h * 0.5 - 0.4, z + dir_z * (w * 0.5 + 1.2))
	ramp.rotation = Vector3(0, atan2(dir_x, dir_z), 0)
	ramp.rotation.x = -0.5 * dir_z
	add_child(ramp)
	var rbody := StaticBody3D.new()
	var rcol := CollisionShape3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = Vector3(2.0, 0.3, 3.2)
	rcol.shape = rshape
	rbody.add_child(rcol)
	rbody.position = ramp.position
	rbody.rotation = ramp.rotation
	add_child(rbody)

func _build_grid_marks() -> void:
	pass


func _build_details() -> void:
	_build_wall_accents()
	_build_neon_floor_strips()
	_build_ceiling_beams()
	_build_crates()
	_build_corner_lights()
	_build_danny_sign()

func _add_emissive_box(pos: Vector3, size: Vector3, col: Color, energy: float = 2.0) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)

func _add_solid_box(pos: Vector3, size: Vector3, col: Color, rough: float = 0.9, metallic: float = 0.1) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metallic
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)
	return mesh

func _build_wall_accents() -> void:
	var accent := Color(0.15, 0.55, 0.75)
	var half := FLOOR_SIZE * 0.5 - 0.5
	var bands := [
		{"pos": Vector3(0, 2.0, -half + 0.26), "size": Vector3(FLOOR_SIZE - 1.0, 0.06, 0.06)},
		{"pos": Vector3(0, 2.0,  half - 0.26), "size": Vector3(FLOOR_SIZE - 1.0, 0.06, 0.06)},
		{"pos": Vector3(-half + 0.26, 2.0, 0), "size": Vector3(0.06, 0.06, FLOOR_SIZE - 1.0)},
		{"pos": Vector3( half - 0.26, 2.0, 0), "size": Vector3(0.06, 0.06, FLOOR_SIZE - 1.0)},
	]
	for b in bands:
		_add_emissive_box(b.pos, b.size, accent, 1.6)

func _build_neon_floor_strips() -> void:
	var neon := Color(0.20, 0.85, 1.0)
	var half := FLOOR_SIZE * 0.5 - 0.65
	var strips := [
		{"pos": Vector3(0, 0.05, -half), "size": Vector3(FLOOR_SIZE - 1.3, 0.05, 0.10)},
		{"pos": Vector3(0, 0.05,  half), "size": Vector3(FLOOR_SIZE - 1.3, 0.05, 0.10)},
		{"pos": Vector3(-half, 0.05, 0), "size": Vector3(0.10, 0.05, FLOOR_SIZE - 1.3)},
		{"pos": Vector3( half, 0.05, 0), "size": Vector3(0.10, 0.05, FLOOR_SIZE - 1.3)},
	]
	for s in strips:
		_add_emissive_box(s.pos, s.size, neon, 2.5)
		var l := OmniLight3D.new()
		l.light_color = neon
		l.light_energy = 0.8
		l.omni_range = 6.0
		l.position = s.pos + Vector3(0, 0.5, 0)
		add_child(l)

func _build_ceiling_beams() -> void:
	var beam := Color(0.10, 0.11, 0.15)
	var y := 3.75
	for z_off in [-13.0, -6.5, 0.0, 6.5, 13.0]:
		_add_solid_box(Vector3(0, y, z_off), Vector3(FLOOR_SIZE - 1.0, 0.25, 0.35), beam, 0.9, 0.2)
	for x_off in [-13.0, 0.0, 13.0]:
		_add_solid_box(Vector3(x_off, y, 0), Vector3(0.35, 0.25, FLOOR_SIZE - 1.0), beam, 0.9, 0.2)

func _build_crates() -> void:
	var crate := Color(0.28, 0.22, 0.16)
	var top := Color(0.38, 0.30, 0.20)
	var positions := [
		Vector3(-7.0, 0.5, -3.0),
		Vector3(5.0, 0.5, 6.0),
		Vector3(-5.0, 0.5, 12.0),
		Vector3(13.0, 0.5, -6.0),
		Vector3(-14.0, 0.5, 8.0),
		Vector3(2.0, 0.5, -14.0),
	]
	for i in range(positions.size()):
		var sz := 1.0 + float(i % 3) * 0.15
		var pos: Vector3 = positions[i]
		_add_solid_box(pos, Vector3(sz, sz, sz), crate, 0.85, 0.05)
		_add_solid_box(pos + Vector3(0, sz * 0.5 + 0.02, 0), Vector3(sz + 0.05, 0.04, sz + 0.05), top, 0.85, 0.05)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(sz, sz, sz)
		col.shape = shape
		body.add_child(col)
		body.position = pos
		body.add_to_group("cover")
		add_child(body)

func _build_corner_lights() -> void:
	var col := Color(0.35, 0.75, 1.0)
	var half := FLOOR_SIZE * 0.5 - 1.5
	var corners := [
		Vector3(-half, 0, -half),
		Vector3( half, 0, -half),
		Vector3(-half, 0,  half),
		Vector3( half, 0,  half),
	]
	for c in corners:
		_add_emissive_box(c + Vector3(0, 1.8, 0), Vector3(0.10, 3.4, 0.10), col, 3.0)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 2.2
		l.omni_range = 8.0
		l.position = c + Vector3(0, 3.4, 0)
		add_child(l)

func _build_danny_sign() -> void:
	var half_z := FLOOR_SIZE * 0.5 - 0.55
	var plate_size := Vector3(6.0, 1.4, 0.15)
	# North wall plaque
	_add_solid_box(Vector3(0, 2.6, -half_z), plate_size, Color(0.06, 0.07, 0.10), 0.6, 0.4)
	_add_emissive_box(Vector3(0, 1.92, -half_z + 0.05), Vector3(6.0, 0.05, 0.08), Color(0.25, 0.85, 1.0), 2.5)
	var s1 := Label3D.new()
	s1.text = "MADE BY DANNY"
	s1.font = ThemeDB.fallback_font
	s1.font_size = 96
	s1.pixel_size = 0.0075
	s1.modulate = Color(0.45, 0.92, 1.0)
	s1.outline_modulate = Color(0.05, 0.15, 0.25)
	s1.outline_size = 12
	s1.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s1.position = Vector3(0, 2.65, -half_z + 0.10)
	add_child(s1)
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.55, 0.9, 1.0)
	spot.light_energy = 3.0
	spot.spot_range = 12.0
	spot.spot_angle = 38.0
	spot.position = Vector3(0, 3.4, -half_z + 2.5)
	spot.rotation_degrees = Vector3(-38, 0, 0)
	add_child(spot)
	# South wall plaque
	_add_solid_box(Vector3(0, 2.6, half_z), plate_size, Color(0.06, 0.07, 0.10), 0.6, 0.4)
	_add_emissive_box(Vector3(0, 1.92, half_z - 0.05), Vector3(6.0, 0.05, 0.08), Color(0.25, 0.85, 1.0), 2.5)
	var s2 := Label3D.new()
	s2.text = "MADE BY DANNY"
	s2.font = ThemeDB.fallback_font
	s2.font_size = 96
	s2.pixel_size = 0.0075
	s2.modulate = Color(0.45, 0.92, 1.0)
	s2.outline_modulate = Color(0.05, 0.15, 0.25)
	s2.outline_size = 12
	s2.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s2.rotation_degrees = Vector3(0, 180, 0)
	s2.position = Vector3(0, 2.65, half_z - 0.10)
	add_child(s2)
	var spot2 := SpotLight3D.new()
	spot2.light_color = Color(0.55, 0.9, 1.0)
	spot2.light_energy = 3.0
	spot2.spot_range = 12.0
	spot2.spot_angle = 38.0
	spot2.position = Vector3(0, 3.4, half_z - 2.5)
	spot2.rotation_degrees = Vector3(-38, 180, 0)
	add_child(spot2)


func _build_ambient() -> void:
	_ambient_player = AudioStreamPlayer.new()
	var stream: AudioStream = load("res://sounds/ambient_hum.wav")
	if stream == null:
		return
	_ambient_player.stream = stream
	_ambient_player.volume_db = -22.0
	_ambient_player.finished.connect(func() -> void:
		if is_instance_valid(_ambient_player):
			_ambient_player.play()
	)
	add_child(_ambient_player)
	_ambient_player.play()
	_distant_timer = randf_range(4.0, 9.0)
