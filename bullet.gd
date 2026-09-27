extends Area3D
class_name Bullet

const SPEED := 85.0
const LIFETIME := 1.6
const DEFAULT_DAMAGE := 5

var direction := Vector3.FORWARD
var _damage: int = DEFAULT_DAMAGE
var _age := 0.0

func setup(dir: Vector3, dmg: int = DEFAULT_DAMAGE) -> void:
	direction = dir.normalized()
	_damage = dmg

func _ready() -> void:
	add_to_group("bullet")
	_build_visual()
	_build_collision()

func _build_visual() -> void:
	# Elongated tracer — a bright streak along the bullet's travel axis
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.035, 0.035, 1.20)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.80, 0.35)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.95
	mesh.material_override = mat
	add_child(mesh)
	# Bright hot core — small brighter sphere at the leading tip
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	core.mesh = sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 1.0, 0.85)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.95, 0.6)
	core_mat.emission_energy_multiplier = 6.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = core_mat
	core.position = Vector3(0, 0, -0.55)
	add_child(core)
	# Small point light so nearby surfaces glow as the bullet flies past
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.0
	light.omni_range = 2.5
	add_child(light)
	# Orient along travel direction
	look_at(global_position + direction, Vector3.UP)

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	var from: Vector3 = global_position
	var to: Vector3 = from + direction * SPEED * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	# Exclude the player who fired
	var exclude: Array = []
	for n in get_tree().get_nodes_in_group("player"):
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_handle_hit(hit.collider, hit.position)
		return
	global_position = to
	_age += delta
	if _age >= LIFETIME:
		queue_free()

func _handle_hit(body: Node, pos: Vector3) -> void:
	if body != null and body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(_damage, pos)
	_spawn_impact(pos)
	queue_free()

func _spawn_impact(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = -direction
	p.spread = 55.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -8, 0)
	var sph := SphereMesh.new()
	sph.radius = 0.035
	sph.height = 0.07
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1.0, 0.85, 0.45)
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.75, 0.3)
	pm.emission_energy_multiplier = 4.0
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material = pm
	p.mesh = sph
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
