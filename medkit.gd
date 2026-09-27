extends Area3D
class_name MedKit
const SFX := preload("res://sfx.gd")

const HEAL_AMOUNT := 40
const LIFETIME := 25.0
const ROT_SPEED := 1.8
const BOB_AMP := 0.18

var _t: float = 0.0
var _used := false
var _base_y: float = 0.0

func _ready() -> void:
	add_to_group("medkit")
	_base_y = global_position.y
	_build_visual()
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	# White cross on red background — universal medkit look
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.55, 0.55)
	base.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.18, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.25)
	mat.emission_energy_multiplier = 1.8
	base.material_override = mat
	add_child(base)
	# White cross pieces on top face
	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = Color(1.0, 1.0, 1.0)
	cross_mat.emission_enabled = true
	cross_mat.emission = Color(1.0, 1.0, 1.0)
	cross_mat.emission_energy_multiplier = 2.5
	var cross_h := MeshInstance3D.new()
	var chb := BoxMesh.new()
	chb.size = Vector3(0.30, 0.04, 0.10)
	cross_h.mesh = chb
	cross_h.material_override = cross_mat
	cross_h.position = Vector3(0, 0.28, 0)
	add_child(cross_h)
	var cross_v := MeshInstance3D.new()
	var cvb := BoxMesh.new()
	cvb.size = Vector3(0.10, 0.04, 0.30)
	cross_v.mesh = cvb
	cross_v.material_override = cross_mat
	cross_v.position = Vector3(0, 0.28, 0)
	add_child(cross_v)
	# Green glow light
	var light := OmniLight3D.new()
	light.light_color = Color(0.30, 1.0, 0.45)
	light.light_energy = 2.2
	light.omni_range = 4.0
	add_child(light)
	# Collision — 1.8m pickup radius
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.8
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	if _used:
		return
	_t += delta
	rotate_y(ROT_SPEED * delta)
	var pos: Vector3 = global_position
	pos.y = _base_y + sin(_t * 2.2) * BOB_AMP
	global_position = pos
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
	SFX.play("wave_clear", -4.0, 1.5)
	_spawn_burst()
	queue_free()

func _spawn_burst() -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.amount = 30
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -3, 0)
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.30, 1.0, 0.45)
	pm.emission_enabled = true
	pm.emission = Color(0.35, 1.0, 0.5)
	pm.emission_energy_multiplier = 3.5
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material = pm
	p.mesh = sph
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	var t := get_tree().create_timer(1.4)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
