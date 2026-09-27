extends Area3D
class_name Hazard

enum Kind { FIRE, ELECTRIC, SPIKE }

var kind: int = 0
var _t: float = 0.0
var _player: Node3D = null
var _player_in: bool = false
var _cooldown: float = 0.0
var _base_mesh: MeshInstance3D = null
var _base_light: OmniLight3D = null
var _base_energy: float = 2.5
var _arc_mesh: MeshInstance3D = null
var _spikes: Array = []
var _spark_particles: CPUParticles3D = null
var _fire_particles: CPUParticles3D = null
var _smoke_particles: CPUParticles3D = null

const RADIUS := 1.4

func setup(k: int) -> void:
	kind = k

func _ready() -> void:
	add_to_group("hazard")
	_player = get_tree().get_first_node_in_group("player")
	_build_base()
	match kind:
		Kind.FIRE:
			_build_fire()
		Kind.ELECTRIC:
			_build_electric()
		Kind.SPIKE:
			_build_spike()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

# ============================================================
# BASE — charred/damaged floor disc
# ============================================================
func _build_base() -> void:
	var col: Color
	match kind:
		Kind.FIRE:
			col = Color(0.12, 0.06, 0.03)
		Kind.ELECTRIC:
			col = Color(0.05, 0.08, 0.12)
		Kind.SPIKE:
			col = Color(0.08, 0.07, 0.06)
	_base_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS
	cyl.height = 0.08
	_base_mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mat.metallic = 0.05
	_base_mesh.material_override = mat
	_base_mesh.position = Vector3(0, 0.04, 0)
	add_child(_base_mesh)
	# Rim ring
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.06
	torus.outer_radius = RADIUS
	rim.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col.darkened(0.3)
	rmat.roughness = 0.7
	rim.material_override = rmat
	rim.position = Vector3(0, 0.06, 0)
	add_child(rim)
	# Collision
	var col_shape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = 1.6
	col_shape.shape = shape
	col_shape.position = Vector3(0, 0.8, 0)
	add_child(col_shape)

# ============================================================
# FIRE — rising flames + smoke + flickering light
# ============================================================
func _build_fire() -> void:
	# Emissive orange base — hot coals
	var coal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS - 0.15
	cyl.bottom_radius = RADIUS - 0.10
	cyl.height = 0.05
	coal.mesh = cyl
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.35, 0.05)
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.40, 0.08)
	cmat.emission_energy_multiplier = 5.0
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coal.material_override = cmat
	coal.position = Vector3(0, 0.09, 0)
	add_child(coal)
	# Six layered billboard flames using the fire shader
	var fire_shader: Shader = load("res://fire.gdshader")
	if fire_shader == null:
		print("[hazard] fire.gdshader not found")
		return
	var flame_positions: Array = []
	for i in range(6):
		var ang: float = (float(i) / 6.0) * TAU + randf() * 0.4
		var rad: float = randf_range(0.15, RADIUS - 0.55)
		flame_positions.append(Vector3(cos(ang) * rad, 0.0, sin(ang) * rad))
	# Center flame is the tallest
	flame_positions.insert(0, Vector3.ZERO)
	for idx in range(flame_positions.size()):
		var pos: Vector3 = flame_positions[idx]
		var is_center: bool = (idx == 0)
		var quad := MeshInstance3D.new()
		var plane := QuadMesh.new()
		var h: float = randf_range(1.2, 1.9) if is_center else randf_range(0.7, 1.3)
		var w: float = h * 0.85
		plane.size = Vector2(w, h)
		quad.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = fire_shader
		mat.set_shader_parameter("flame_height", h)
		mat.set_shader_parameter("flame_width", w)
		mat.set_shader_parameter("intensity", 1.6 if is_center else 1.1)
		var t_offset: float = randf() * 10.0
		mat.set_shader_parameter("time_scale", randf_range(0.9, 1.3))
		quad.material_override = mat
		# Position — raise flame so bottom starts at base
		quad.position = pos + Vector3(0, h * 0.5, 0)
		# Billboard toward camera — rotate every frame in _process
		quad.name = "Flame_" + str(idx)
		add_child(quad)
	# Tall flickering fire light
	_base_light = OmniLight3D.new()
	_base_light.light_color = Color(1.0, 0.55, 0.20)
	_base_light.light_energy = 5.0
	_base_light.omni_range = 7.0
	_base_light.position = Vector3(0, 1.2, 0)
	add_child(_base_light)
	# Rising ember particles
	_fire_particles = CPUParticles3D.new()
	_fire_particles.emitting = true
	_fire_particles.amount = 18
	_fire_particles.lifetime = 1.6
	_fire_particles.direction = Vector3.UP
	_fire_particles.spread = 22.0
	_fire_particles.initial_velocity_min = 1.4
	_fire_particles.initial_velocity_max = 2.8
	_fire_particles.gravity = Vector3(0, 1.0, 0)
	_fire_particles.scale_amount_min = 0.04
	_fire_particles.scale_amount_max = 0.10
	_fire_particles.color = Color(1.0, 0.60, 0.15, 1.0)
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.03
	ember_mesh.height = 0.06
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(1.0, 0.55, 0.15)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.45, 0.10)
	ember_mat.emission_energy_multiplier = 6.0
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mesh.material = ember_mat
	_fire_particles.mesh = ember_mesh
	_fire_particles.position = Vector3(0, 0.3, 0)
	add_child(_fire_particles)


func _build_electric() -> void:
	# Emissive blue base
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS - 0.15
	cyl.bottom_radius = RADIUS - 0.10
	cyl.height = 0.06
	pad.mesh = cyl
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.20, 0.75, 1.0)
	pmat.emission_enabled = true
	pmat.emission = Color(0.30, 0.85, 1.0)
	pmat.emission_energy_multiplier = 3.0
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = pmat
	pad.position = Vector3(0, 0.10, 0)
	add_child(pad)
	# Lightning arc — chunky zigzag mesh that pulses
	_arc_mesh = MeshInstance3D.new()
	var arc := ImmediateMesh.new()
	_arc_mesh.mesh = arc
	var amat := StandardMaterial3D.new()
	am_mat_setup(amat)
	_arc_mesh.material_override = amat
	_arc_mesh.name = "Arc"
	add_child(_arc_mesh)
	# Spark particles — shooting outward
	_spark_particles = CPUParticles3D.new()
	_spark_particles.emitting = true
	_spark_particles.amount = 26
	_spark_particles.lifetime = 0.55
	_spark_particles.direction = Vector3.UP
	_spark_particles.spread = 180.0
	_spark_particles.initial_velocity_min = 2.0
	_spark_particles.initial_velocity_max = 4.5
	_spark_particles.gravity = Vector3(0, -3.0, 0)
	_spark_particles.scale_amount_min = 0.03
	_spark_particles.scale_amount_max = 0.09
	_spark_particles.color = Color(0.45, 0.90, 1.0, 1.0)
	var sp_mesh := SphereMesh.new()
	sp_mesh.radius = 0.05
	sp_mesh.height = 0.10
	var sp_mat := StandardMaterial3D.new()
	sp_mat.albedo_color = Color(0.55, 0.95, 1.0)
	sp_mat.emission_enabled = true
	sp_mat.emission = Color(0.45, 0.90, 1.0)
	sp_mat.emission_energy_multiplier = 5.0
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mesh.material = sp_mat
	_spark_particles.mesh = sp_mesh
	_spark_particles.position = Vector3(0, 0.4, 0)
	add_child(_spark_particles)
	# Blue pulse light
	_base_light = OmniLight3D.new()
	_base_light.light_color = Color(0.35, 0.80, 1.0)
	_base_light.light_energy = 5.0
	_base_light.omni_range = 6.5
	_base_light.position = Vector3(0, 0.8, 0)
	add_child(_base_light)

func am_mat_setup(m: StandardMaterial3D) -> void:
	m.albedo_color = Color(0.70, 0.95, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.60, 0.92, 1.0)
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# ============================================================
# SPIKE — protruding metal spikes
# ============================================================
func _build_spike() -> void:
	# Danger ring on the floor
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = RADIUS - 0.20
	tor.outer_radius = RADIUS - 0.05
	ring.mesh = tor
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.65, 0.10, 0.10)
	rmat.emission_enabled = true
	rmat.emission = Color(0.85, 0.12, 0.12)
	rmat.emission_energy_multiplier = 2.5
	ring.material_override = rmat
	ring.position = Vector3(0, 0.09, 0)
	add_child(ring)
	# Metal spikes — 7 cones protruding upward, tips gleaming
	var spike_count := 7
	for i in range(spike_count):
		var angle: float = (float(i) / float(spike_count)) * TAU + randf() * 0.4
		var rad: float = randf_range(0.35, RADIUS - 0.35)
		var px: float = cos(angle) * rad
		var pz: float = sin(angle) * rad
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.10
		var h: float = randf_range(0.35, 0.65)
		cone.height = h
		cone.radial_segments = 6
		spike.mesh = cone
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.55, 0.58, 0.62)
		smat.metallic = 0.95
		smat.roughness = 0.18
		spike.material_override = smat
		spike.position = Vector3(px, h * 0.5 + 0.08, pz)
		add_child(spike)
		_spikes.append(spike)
	# Tip glow — red emissive dots on spike tips
		var tip := MeshInstance3D.new()
		var tip_mesh := SphereMesh.new()
		tip_mesh.radius = 0.025
		tip_mesh.height = 0.05
		tip.mesh = tip_mesh
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(1.0, 0.15, 0.15)
		tmat.emission_enabled = true
		tmat.emission = Color(1.0, 0.20, 0.20)
		tmat.emission_energy_multiplier = 4.0
		tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tip.material_override = tmat
		tip.position = Vector3(px, h + 0.08, pz)
		add_child(tip)
	# Dim red light
	_base_light = OmniLight3D.new()
	_base_light.light_color = Color(1.0, 0.20, 0.20)
	_base_light.light_energy = 2.5
	_base_light.omni_range = 5.0
	_base_light.position = Vector3(0, 0.5, 0)
	add_child(_base_light)

# ============================================================
# TICK
# ============================================================
func _process(delta: float) -> void:
	if kind == Kind.FIRE:
		_update_fire_billboards()
	_t += delta
	# Pulsing light per hazard type
	if _base_light != null:
		match kind:
			Kind.FIRE:
				var fp: float = 0.5 + 0.5 * sin(_t * 9.0) + randf_range(-0.15, 0.15)
				_base_light.light_energy = 4.5 + fp * 2.5
			Kind.ELECTRIC:
				var ep: float = 0.5 + 0.5 * sin(_t * 12.0)
				_base_light.light_energy = 3.5 + ep * 4.0
			Kind.SPIKE:
				var sp: float = 0.5 + 0.5 * sin(_t * 3.0)
				_base_light.light_energy = 2.0 + sp * 1.5
	# Electric: regenerate lightning arc every ~0.1s
	if kind == Kind.ELECTRIC and _arc_mesh != null:
		if randf() < 0.35:
			_regenerate_arc()
	# Spike: slight bobbing of spikes (menacing)
	if kind == Kind.SPIKE:
		for i in range(_spikes.size()):
			var sp_node: Node3D = _spikes[i]
			if is_instance_valid(sp_node):
				var base_y: float = 0.08 + 0.45
				sp_node.position.y = base_y + sin(_t * 4.0 + float(i) * 0.9) * 0.03
	# Damage tick
	if _cooldown > 0.0:
		_cooldown -= delta
	if _player_in and _cooldown <= 0.0 and _player != null:
		_damage_player()

func _regenerate_arc() -> void:
	if _arc_mesh == null or not (_arc_mesh.mesh is ImmediateMesh):
		return
	var arc := _arc_mesh.mesh as ImmediateMesh
	arc.clear_surfaces()
	arc.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var start := Vector3(randf_range(-0.6, 0.6), 0.15, randf_range(-0.6, 0.6))
	arc.surface_add_vertex(start)
	var steps := 5
	var end := Vector3(randf_range(-0.9, 0.9), randf_range(0.6, 1.5), randf_range(-0.9, 0.9))
	for i in range(1, steps):
		var u: float = float(i) / float(steps)
		var mid: Vector3 = start.lerp(end, u)
		mid += Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
		arc.surface_add_vertex(mid)
	arc.surface_add_vertex(end)
	arc.surface_end()

func _damage_player() -> void:
	if _player == null or not _player.has_method("take_damage"):
		return
	match kind:
		Kind.FIRE:
			_player.call("take_damage", 4)
			_cooldown = 0.7
		Kind.ELECTRIC:
			_player.call("take_damage", 6)
			_cooldown = 1.2
		Kind.SPIKE:
			_player.call("take_damage", 9)
			_cooldown = 1.5

func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in = true

func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in = false


func _update_fire_billboards() -> void:
	var cam: Camera3D = null
	var vp := get_viewport()
	if vp != null:
		cam = vp.get_camera_3d()
	if cam == null:
		return
	var cam_pos: Vector3 = cam.global_position
	for c in get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Flame_"):
			var mi := c as MeshInstance3D
			var to_cam: Vector3 = cam_pos - mi.global_position
			to_cam.y = 0.0
			if to_cam.length() > 0.1:
				mi.look_at(mi.global_position + to_cam.normalized(), Vector3.UP)
