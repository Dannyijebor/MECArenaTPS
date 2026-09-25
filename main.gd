extends Node3D
const SFX := preload("res://sfx.gd")
const SAVE_PATH := "user://sector7_best.cfg"

const WAVE_MODIFIERS := [
	{"name": "AMBIENT CALM",     "desc": "Fewer hostiles",              "color": Color(0.55, 0.90, 1.00), "count": 0.75, "speed": 1.00, "bias": 0},
	{"name": "HIGH ALERT",       "desc": "More hostiles inbound",        "color": Color(1.00, 0.65, 0.20), "count": 1.40, "speed": 0.95, "bias": 0},
	{"name": "RESONANCE STORM",  "desc": "Electrical surge — faster enemies", "color": Color(0.72, 0.30, 1.00), "count": 1.10, "speed": 1.35, "bias": 0},
	{"name": "RUSHER ASSAULT",   "desc": "Fast melee units inbound",      "color": Color(1.00, 0.35, 0.15), "count": 1.15, "speed": 1.00, "bias": 1},
	{"name": "SNIPER FOCUS",     "desc": "Long-range specialists active", "color": Color(0.95, 0.85, 0.20), "count": 1.00, "speed": 1.00, "bias": 3},
	{"name": "TANK PATROL",      "desc": "Heavy armor detected",          "color": Color(0.65, 0.30, 0.95), "count": 1.05, "speed": 0.95, "bias": 2},
]
var _active_modifier: Dictionary = {}

const FLOOR_SIZE := 40.0

# Wave system
var _wave := 0
var _score := 0
var _loot_haul := 0
var _loot_tier_counts := [0, 0, 0, 0]
var _kills := 0
var _best_score := 0
var _best_wave := 0
var _enemies_alive := 0
var _wave_cooldown := 0.0
var _between_waves := false

# UI reference
var _ui: Node = null
var _extraction_area: Area3D = null
var _extraction_light: OmniLight3D = null
var _extraction_ring: MeshInstance3D = null
var _extraction_disc: MeshInstance3D = null
var _extraction_pos := Vector3(24.0, 0.05, 24.0)
var _player_in_extraction := false
var _extraction_hold := 0.0
var _extraction_armed := false
var _extracted := false
const EXTRACT_HOLD_TIME := 2.5
const EXTRACT_MIN_WAVE := 3
var _ambient_player: AudioStreamPlayer = null
var _distant_timer: float = 0.0

func _ready() -> void:
	_build_floor()
	_build_player()
	_build_lighting()
	_build_environment()
	_build_scifi_env()
	_build_neon_bazaar()
	_build_platforms()
	_build_details()
	_build_extraction_pad()
	_build_dannys_shrine()
	_build_void_edges()
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
	e.ambient_light_energy = 0.10
	env.environment = e
	add_child(env)
	e.fog_enabled = true
	e.fog_light_color = Color(0.15, 0.04, 0.14)
	e.fog_light_energy = 0.7
	e.fog_density = 0.075
	e.fog_sky_affect = 0.75


func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.030, 0.045)
	mat.roughness = 0.15
	mat.metallic = 0.55
	mat.rim_enabled = true
	mat.rim = 0.4
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
	var bias: int = int(_active_modifier.get("bias", 0))
	var speed_mult: float = float(_active_modifier.get("speed", 1.0))
	var types: Array = []
	for i in range(count):
		var t := 0
		var r := randf()
		# Bias overrides default distribution
		if bias > 0 and randf() < 0.55:
			t = bias
		elif _wave >= 7 and r < 0.15:
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
		var e := _spawn_enemy_at(pos, enemy_script, types[i])
		if e != null and speed_mult != 1.0:
			var base_speed_v: Variant = e.get("_t_speed_mult")
			if base_speed_v != null:
				e.set("_t_speed_mult", float(base_speed_v) * speed_mult)


func _spawn_enemy_at(pos: Vector3, enemy_script: Script, type_idx: int = 0) -> Node3D:
	_spawn_spawn_puff(pos)
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
	e.scale = Vector3(0.1, 0.1, 0.1)
	var tw := create_tween()
	tw.tween_property(e, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_enemies_alive += 1
	return e


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
	if n > _best_wave:
		_best_wave = n
	_between_waves = false
	# Pick modifier (wave 1 always CALM)
	if n == 1:
		_active_modifier = WAVE_MODIFIERS[0]
	else:
		_active_modifier = WAVE_MODIFIERS[randi() % WAVE_MODIFIERS.size()]
	# Announce
	_show_wave_banner(n, _active_modifier)
	# Compute enemy count
	var base_count := 3 + (n - 1) * 2
	var count: int = max(2, int(round(float(base_count) * float(_active_modifier.get("count", 1.0)))))
	_spawn_wave_enemies(count)
	_maybe_spawn_ghost(n)


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
	_tick_extraction(delta)
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


func _build_extraction_pad() -> void:
	# Green glowing cylinder + rotating ring at arena corner
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.0
	cyl.height = 0.10
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.30, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.30, 0.15)
	mat.emission_energy_multiplier = 0.5
	disc.material_override = mat
	disc.position = _extraction_pos + Vector3(0, 0.05, 0)
	add_child(disc)
	_extraction_disc = disc

	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 2.6
	tor.outer_radius = 2.9
	ring.mesh = tor
	ring.material_override = mat
	ring.position = _extraction_pos + Vector3(0, 0.40, 0)
	add_child(ring)
	_extraction_ring = ring

	var light := OmniLight3D.new()
	light.light_color = Color(0.20, 1.0, 0.40)
	light.light_energy = 0.8
	light.omni_range = 12.0
	light.position = _extraction_pos + Vector3(0, 1.5, 0)
	add_child(light)
	_extraction_light = light

	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 3.0
	col.shape = shape
	area.add_child(col)
	area.position = _extraction_pos + Vector3(0, 1.5, 0)
	add_child(area)
	area.body_entered.connect(_on_extraction_enter)
	area.body_exited.connect(_on_extraction_exit)
	_extraction_area = area


func _on_extraction_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_extraction = true


func _on_extraction_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_extraction = false
		_extraction_hold = 0.0


func _tick_extraction(delta: float) -> void:
	if _extracted:
		return
	# Arm the pad once wave threshold is reached
	if not _extraction_armed and _wave >= EXTRACT_MIN_WAVE:
		_extraction_armed = true
		if _extraction_disc != null:
			var m := _extraction_disc.material_override as StandardMaterial3D
			if m != null:
				m.albedo_color = Color(0.15, 0.90, 0.35)
				m.emission = Color(0.20, 1.0, 0.45)
				m.emission_energy_multiplier = 3.5
		if _extraction_light != null:
			_extraction_light.light_energy = 4.0
	# Animate ring
	if _extraction_ring != null:
		_extraction_ring.rotate_y(delta * 1.4)
		var s := 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.05
		_extraction_ring.scale = Vector3(s, 1.0, s)
	# Pulse light
	if _extraction_light != null and _extraction_armed:
		_extraction_light.light_energy = 3.0 + sin(Time.get_ticks_msec() * 0.005) * 1.5
	# Hold-to-extract
	if _extraction_armed and _player_in_extraction:
		_extraction_hold += delta
		if _extraction_hold >= EXTRACT_HOLD_TIME:
			_on_extraction_complete()
	else:
		_extraction_hold = max(0.0, _extraction_hold - delta * 2.0)


func _on_extraction_complete() -> void:
	if _extracted:
		return
	_extracted = true
	SFX.play("wave_clear", 0.0)
	# Haul bonus — the whole point of carrying weight
	var bonus: int = int(round(float(_loot_haul) * 0.5))
	_score += bonus
	_save_best()
	_show_extraction_banner(bonus)
	var t := get_tree().create_timer(4.5)
	t.timeout.connect(func() -> void:
		get_tree().reload_current_scene()
	)


func _show_extraction_banner(haul_bonus: int = 0) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var label := Label.new()
	label.text = "EXTRACTION SUCCESSFUL"
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(0.30, 1.0, 0.55))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.03))
	label.add_theme_constant_override("outline_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(label)
	var sub := Label.new()
	sub.text = "SCORE " + str(_score) + "  •  WAVE " + str(_wave) + "  •  HAUL BONUS +" + str(haul_bonus) + "  (x0.5)"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 1.0, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 300.0
	sub.offset_bottom = 340.0
	layer.add_child(sub)


func _save_best() -> void:
	var cfg := ConfigFile.new()
	if _score > _best_score:
		_best_score = _score
	cfg.set_value("progress", "best_score", _best_score)
	cfg.set_value("progress", "best_wave", _best_wave)
	cfg.save(SAVE_PATH)


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best_score = int(cfg.get_value("progress", "best_score", 0))
		_best_wave = int(cfg.get_value("progress", "best_wave", 0))


func _build_neon_bazaar() -> void:
	_build_bazaar_lights()
	_build_neon_signs()
	_build_hand_of_danny()


func _build_bazaar_lights() -> void:
	# Magenta + cyan cross-lights — the signature neon-grunge palette
	var magenta := OmniLight3D.new()
	magenta.light_color = Color(1.0, 0.15, 0.65)
	magenta.light_energy = 4.5
	magenta.omni_range = 42.0
	magenta.position = Vector3(-14, 8, -14)
	add_child(magenta)

	var cyan := OmniLight3D.new()
	cyan.light_color = Color(0.10, 0.85, 1.0)
	cyan.light_energy = 4.5
	cyan.omni_range = 42.0
	cyan.position = Vector3(14, 8, 14)
	add_child(cyan)

	# Soft magenta rim on the ceiling
	var top := OmniLight3D.new()
	top.light_color = Color(0.9, 0.25, 0.7)
	top.light_energy = 1.6
	top.omni_range = 30.0
	top.position = Vector3(0, 11.0, 0)
	add_child(top)


func _build_neon_signs() -> void:
	# 8 storefront signs around the walls
	var palette := [
		Color(1.0, 0.15, 0.65),   # magenta
		Color(0.10, 0.85, 1.0),   # cyan
		Color(1.0, 0.85, 0.15),   # sodium yellow
	]
	var half := FLOOR_SIZE * 0.5 - 1.0
	var placements := [
		{"pos": Vector3(-8.0, 4.0, -half + 0.4), "size": Vector3(4.0, 1.2, 0.10), "rot": Vector3.ZERO},
		{"pos": Vector3( 8.0, 5.0, -half + 0.4), "size": Vector3(3.0, 2.0, 0.10), "rot": Vector3.ZERO},
		{"pos": Vector3(-8.0, 6.0,  half - 0.4), "size": Vector3(3.5, 1.5, 0.10), "rot": Vector3(0, PI, 0)},
		{"pos": Vector3( 8.0, 3.5,  half - 0.4), "size": Vector3(4.5, 0.9, 0.10), "rot": Vector3(0, PI, 0)},
		{"pos": Vector3(-half + 0.4, 5.0, -8.0), "size": Vector3(0.10, 1.8, 3.5), "rot": Vector3.ZERO},
		{"pos": Vector3(-half + 0.4, 3.5,  8.0), "size": Vector3(0.10, 1.0, 4.0), "rot": Vector3.ZERO},
		{"pos": Vector3( half - 0.4, 6.0, -8.0), "size": Vector3(0.10, 2.2, 3.0), "rot": Vector3.ZERO},
		{"pos": Vector3( half - 0.4, 4.5,  8.0), "size": Vector3(0.10, 1.4, 3.8), "rot": Vector3.ZERO},
	]
	for i in range(placements.size()):
		var pl: Dictionary = placements[i]
		var col: Color = palette[i % palette.size()]
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = pl.size
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 2.6
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = mat
		mesh.position = pl.pos
		mesh.rotation_degrees = pl.rot
		add_child(mesh)
		# Soft local light for sign bleed
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.6
		l.omni_range = 8.0
		l.position = pl.pos + Vector3(0, -1.5, 0)
		add_child(l)


func _build_hand_of_danny() -> void:
	# Composite monument — chrome hand gripping a wrench, at the north wall
	var base_pos := Vector3(0, 0, -FLOOR_SIZE * 0.5 + 4.0)
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.85, 0.88, 0.92)
	chrome.metallic = 0.95
	chrome.roughness = 0.15

	# Forearm / wrist
	_add_hand_part(base_pos + Vector3(0, 2.0, 0), Vector3(3.6, 1.8, 3.6), chrome)
	# Palm
	_add_hand_part(base_pos + Vector3(0, 4.6, 0), Vector3(5.5, 2.4, 2.6), chrome)
	# Fingers (5, splayed)
	var finger_x := [-2.2, -1.1, 0.0, 1.1, 2.2]
	var finger_h := [3.6, 4.0, 4.2, 3.9, 3.2]
	for i in range(5):
		_add_hand_part(
			base_pos + Vector3(finger_x[i], 6.4 + finger_h[i] * 0.5, 0),
			Vector3(0.55, finger_h[i], 1.0),
			chrome)
	# Thumb, angled out from palm
	_add_hand_part(base_pos + Vector3(3.0, 4.6, 0.2), Vector3(1.8, 0.7, 0.7), chrome)

	# The wrench — shaft + C-shaped head
	_add_hand_part(base_pos + Vector3(0, 5.4, 2.6), Vector3(0.55, 0.55, 5.0), chrome)
	_add_hand_part(base_pos + Vector3(0, 5.4, 5.5), Vector3(1.8, 0.55, 0.55), chrome)
	_add_hand_part(base_pos + Vector3(-0.7, 6.2, 5.7), Vector3(0.5, 1.4, 0.5), chrome)
	_add_hand_part(base_pos + Vector3( 0.7, 6.2, 5.7), Vector3(0.5, 1.4, 0.5), chrome)

	# Pedestal light under the hand
	var danny_light := OmniLight3D.new()
	danny_light.light_color = Color(0.15, 0.95, 1.0)
	danny_light.light_energy = 6.0
	danny_light.omni_range = 22.0
	danny_light.position = base_pos + Vector3(0, 5.0, 3.0)
	add_child(danny_light)

	# "MADE BY DANNY" glowing across the palm
	var tm := TextMesh.new()
	tm.text = "MADE BY DANNY"
	tm.font_size = 128
	tm.pixel_size = 0.024
	tm.depth = 0.15
	tm.curve_step = 0.5
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var text_mat := StandardMaterial3D.new()
	text_mat.albedo_color = Color(0.55, 0.98, 1.0)
	text_mat.emission_enabled = true
	text_mat.emission = Color(0.35, 0.92, 1.0)
	text_mat.emission_energy_multiplier = 4.5
	text_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = text_mat
	mi.position = base_pos + Vector3(0, 4.6, 1.45)
	add_child(mi)


func _add_hand_part(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)
	# Match collision so player can't walk through the monument
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	add_child(body)


func _build_scifi_env() -> void:
	var env_script: Script = load("res://scifi_env.gd")
	if env_script == null:
		print("[scifi] env script missing")
		return
	var env: Node = Node.new()
	env.set_script(env_script)
	add_child(env)
	env.call("build", self, FLOOR_SIZE)
	print("[scifi] environment built")




func _spawn_loot_drop(pos: Vector3) -> void:
	var roll := randf()
	var tier := -1
	if roll < 0.60:
		return
	elif roll < 0.85:
		tier = 0
	elif roll < 0.96:
		tier = 1
	elif roll < 0.99:
		tier = 2
	else:
		tier = 3
	var loot_script: Script = load("res://loot.gd")
	if loot_script == null:
		return
	var loot := Area3D.new()
	loot.set_script(loot_script)
	loot.call("setup", tier)
	loot.position = pos + Vector3(randf_range(-0.6, 0.6), 0.5, randf_range(-0.6, 0.6))
	add_child(loot)


func add_loot(value: int, tier: int) -> void:
	_loot_haul += value
	if tier >= 0 and tier < _loot_tier_counts.size():
		_loot_tier_counts[tier] += 1
	# Push carry weight to player — slows them, ups tension
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_carry_weight"):
		player.call("set_carry_weight", float(_loot_haul))
	print("[loot] +", value, " tier ", tier, " total ", _loot_haul)


func _show_wave_banner(n: int, modifier: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.name = "WaveBanner"
	layer.layer = 90
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var title := Label.new()
	title.text = "WAVE " + str(n)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.60, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.10))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 140.0
	title.offset_bottom = 220.0
	holder.add_child(title)
	var sub := Label.new()
	sub.text = String(modifier.get("name", ""))
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", modifier.get("color", Color.WHITE))
	sub.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.10))
	sub.add_theme_constant_override("outline_size", 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 220.0
	sub.offset_bottom = 270.0
	holder.add_child(sub)
	var desc := Label.new()
	desc.text = String(modifier.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	desc.offset_top = 275.0
	desc.offset_bottom = 305.0
	holder.add_child(desc)
	title.modulate.a = 0.0
	sub.modulate.a = 0.0
	desc.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.45)
	tw.parallel().tween_property(desc, "modulate:a", 0.9, 0.55)
	tw.tween_interval(2.0)
	tw.tween_property(title, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(desc, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)


func _maybe_spawn_ghost(wave_num: int) -> void:
	if wave_num < 3 or wave_num % 3 != 0:
		return
	# Pick a target — random open position in the arena
	var tx := randf_range(-14.0, 14.0)
	var tz := randf_range(-14.0, 14.0)
	var target := Vector3(tx, 0.9, tz)
	# Spawn edge opposite target
	var spawn_x: float = -14.0 if tx > 0 else 14.0
	var spawn_z: float = -14.0 if tz > 0 else 14.0
	var spawn := Vector3(spawn_x, 0.9, spawn_z)
	var ghost_script: Script = load("res://dannys_ghost.gd")
	if ghost_script == null:
		print("[ghost] script missing")
		return
	var ghost := Node3D.new()
	ghost.set_script(ghost_script)
	ghost.call("setup", target)
	ghost.position = spawn
	add_child(ghost)
	print("[ghost] Danny appeared at wave ", wave_num, " heading to ", target)


func spawn_danny_loot(pos: Vector3) -> void:
	# Guaranteed Danny-tier drop + 2 rares
	var loot_script: Script = load("res://loot.gd")
	if loot_script == null:
		return
	var danny_loot := Area3D.new()
	danny_loot.set_script(loot_script)
	danny_loot.call("setup", 3)
	danny_loot.position = pos + Vector3(0, 0.5, 0)
	add_child(danny_loot)
	for i in range(2):
		var r := Area3D.new()
		r.set_script(loot_script)
		r.call("setup", 2)
		r.position = pos + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5))
		add_child(r)
	print("[ghost] Danny loot spawned at ", pos)


func _build_dannys_shrine() -> void:
	var shrine_script: Script = load("res://dannys_shrine.gd")
	if shrine_script == null:
		print("[shrine] script missing")
		return
	var shrine := Node3D.new()
	shrine.set_script(shrine_script)
	shrine.call("setup", Vector3(-15.0, 0, -15.0))
	shrine.position = Vector3(-15.0, 0, -15.0)
	add_child(shrine)
	print("[shrine] Danny's Shrine built at NW corner")


func is_in_shrine_safe_zone(pos: Vector3) -> bool:
	for s in get_tree().get_nodes_in_group("shrine"):
		if s is Node3D:
			if pos.distance_to((s as Node3D).global_position) < 8.0:
				return true
	return false


func _build_void_edges() -> void:
	# Replace the arena's outer void look — dark starfield below, red warning rail above
	var half := FLOOR_SIZE * 0.5
	# 1. Starfield ambient — distant points visible above the wall line
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.mesh = SphereMesh.new()
	(stars.mesh as SphereMesh).radius = 0.04
	(stars.mesh as SphereMesh).height = 0.08
	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(0.85, 0.92, 1.0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.75, 0.85, 1.0)
	star_mat.emission_energy_multiplier = 3.0
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(stars.mesh as SphereMesh).material = star_mat
	stars.instance_count = 120
	for i in range(120):
		var t := Transform3D()
		var r := randf_range(half + 6.0, half + 40.0)
		var ang := randf() * TAU
		var y := randf_range(6.0, 25.0)
		t.origin = Vector3(cos(ang) * r, y, sin(ang) * r)
		stars.set_instance_transform(i, t)
	var stars_node := MultiMeshInstance3D.new()
	stars_node.multimesh = stars
	add_child(stars_node)
	# 2. Red warning rail bands along the top of each wall — "drop is here"
	var red := Color(1.0, 0.20, 0.20)
	var rail_y := 4.4 + 0.1
	var rails := [
		{"pos": Vector3(0, rail_y, -half + 0.15), "size": Vector3(FLOOR_SIZE, 0.08, 0.10)},
		{"pos": Vector3(0, rail_y,  half - 0.15), "size": Vector3(FLOOR_SIZE, 0.08, 0.10)},
		{"pos": Vector3(-half + 0.15, rail_y, 0), "size": Vector3(0.10, 0.08, FLOOR_SIZE)},
		{"pos": Vector3( half - 0.15, rail_y, 0), "size": Vector3(0.10, 0.08, FLOOR_SIZE)},
	]
	for r in rails:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = r.size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = red
		m.emission_enabled = true
		m.emission = red
		m.emission_energy_multiplier = 3.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.position = r.pos
		add_child(mi)
	# 3. Red beacon pulses at each corner — 4 warning lights
	var corners := [
		Vector3(-half + 0.3, rail_y + 0.3, -half + 0.3),
		Vector3( half - 0.3, rail_y + 0.3, -half + 0.3),
		Vector3(-half + 0.3, rail_y + 0.3,  half - 0.3),
		Vector3( half - 0.3, rail_y + 0.3,  half - 0.3),
	]
	for c in corners:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.15, 0.15)
		l.light_energy = 2.0
		l.omni_range = 8.0
		l.position = c
		add_child(l)
		# Beacon bulb
		var bulb := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.12
		sph.height = 0.24
		bulb.mesh = sph
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(1.0, 0.20, 0.20)
		bmat.emission_enabled = true
		bmat.emission = Color(1.0, 0.15, 0.15)
		bmat.emission_energy_multiplier = 4.0
		bulb.material_override = bmat
		bulb.position = c
		add_child(bulb)
