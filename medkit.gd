extends Area3D

const HEAL_AMOUNT := 40
const LIFETIME := 20.0
const ROT_SPEED := 2.0
const BOB_AMP := 0.15
const BOB_FREQ := 2.0

var _t := 0.0
var _base_y := 0.0
var _used := false

func _ready() -> void:
	add_to_group("medkit")
	_base_y = global_position.y
	body_entered.connect(_on_body_entered)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.5)
	mat.emission_energy_multiplier = 2.5
	mesh.material_override = mat
	add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.9, 0.9)
	col.shape = shape
	add_child(col)

	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.5)
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)

func _process(delta: float) -> void:
	if _used:
		return
	_t += delta
	rotate_y(ROT_SPEED * delta)
	var gp := global_position
	gp.y = _base_y + sin(_t * BOB_FREQ) * BOB_AMP
	global_position = gp
	if _t >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if _used:
		return
	if not body.is_in_group("player"):
		return
	_used = true
	if body.has_method("heal"):
		body.call("heal", HEAL_AMOUNT)
	_spawn_burst()
	queue_free()

func _spawn_burst() -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.amount = 24
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -4, 0)
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.3, 1.0, 0.5)
	pm.emission_enabled = true
	pm.emission = Color(0.3, 1.0, 0.5)
	pm.emission_energy_multiplier = 3.0
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material = pm
	p.mesh = sph
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
