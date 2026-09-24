extends Area3D

const SPEED := 45.0
const LIFETIME := 2.0
const DAMAGE := 5
var _damage: int = DAMAGE

var direction := Vector3.FORWARD
var _age := 0.0

func setup(dir: Vector3, dmg: int = DAMAGE) -> void:
	direction = dir.normalized()
	_damage = dmg

func _ready() -> void:
	add_to_group("bullet")
	# Connect collision
	body_entered.connect(_on_body_entered)
	# Visual
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.3)
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	add_child(mesh)
	# Glow trail
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.5)
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)
	# Collision shape
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(_damage, global_position)
		queue_free()
