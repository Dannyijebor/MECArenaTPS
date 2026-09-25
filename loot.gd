extends Area3D
class_name LootPickup
const SFX := preload("res://sfx.gd")

# Tier roll: 60% no drop, 25% common, 11% rare, 3% epic, 1% Danny
const TIERS := [
	{"name": "COMMON",  "color": Color(0.75, 0.78, 0.82), "value": 15,
		"emission": 1.2, "scale": 0.30},
	{"name": "RARE",    "color": Color(0.25, 0.65, 1.00), "value": 45,
		"emission": 2.2, "scale": 0.34},
	{"name": "EPIC",    "color": Color(0.72, 0.30, 1.00), "value": 120,
		"emission": 3.0, "scale": 0.38},
	{"name": "DANNY",   "color": Color(1.00, 0.78, 0.15), "value": 400,
		"emission": 4.5, "scale": 0.45},
]

var tier: int = 0
var value: int = 15
var _player: Node3D = null
var _picked: bool = false
var _t: float = 0.0
var _base_y: float = 0.0

func setup(t: int) -> void:
	tier = clampi(t, 0, TIERS.size() - 1)
	value = int(TIERS[tier].value)

func _ready() -> void:
	add_to_group("loot")
	_base_y = global_position.y
	_player = get_tree().get_first_node_in_group("player")
	_build_visual()

func _build_visual() -> void:
	var info: Dictionary = TIERS[tier]
	var col: Color = info.color
	var sc: float = info.scale
	# Core — emissive cube
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(sc, sc, sc)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = info.emission
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 0.2
	mat.metallic = 0.4
	mesh.material_override = mat
	add_child(mesh)
	# Outer ring — rotating frame
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = sc * 1.2
	tor.outer_radius = sc * 1.5
	ring.mesh = tor
	ring.material_override = mat
	ring.name = "Ring"
	add_child(ring)
	# Glow light
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = info.emission * 0.5
	light.omni_range = 4.0 + tier * 1.5
	add_child(light)
	# Danny-tier gets a pillar of light
	if tier == 3:
		var pillar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = sc * 0.6
		cyl.bottom_radius = sc * 0.6
		cyl.height = 12.0
		pillar.mesh = cyl
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(col.r, col.g, col.b, 0.25)
		pmat.emission_enabled = true
		pmat.emission = col
		pmat.emission_energy_multiplier = 2.5
		pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pillar.material_override = pmat
		pillar.position = Vector3(0, 6.0, 0)
		add_child(pillar)
	# Collision — 1.6m pickup radius
	var shape_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	shape_col.shape = sphere
	add_child(shape_col)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _picked:
		return
	_t += delta
	# Bob
	var pos: Vector3 = global_position
	pos.y = _base_y + 0.35 + sin(_t * 2.4) * 0.15
	global_position = pos
	# Rotate — core spins, ring counter-spins
	rotate_y(delta * 1.6)
	var ring: Node = get_node_or_null("Ring")
	if ring != null and ring is Node3D:
		(ring as Node3D).rotate_y(-delta * 2.4)

func _on_body_entered(body: Node3D) -> void:
	if _picked:
		return
	if not body.is_in_group("player"):
		return
	_picked = true
	# Reward
	var tree := get_tree()
	var main: Node = tree.current_scene
	if main != null and main.has_method("add_loot"):
		main.call("add_loot", value, tier)
	# Sound
	var sfx = load("res://sfx.gd")
	if sfx != null:
		var pitch := 1.0 + float(tier) * 0.25
		sfx.play("hit", -4.0, pitch)
	# Visual burst
	_spawn_burst()
	queue_free()

func _spawn_burst() -> void:
	var col: Color = TIERS[tier].color
	var p := CPUParticles3D.new()
	p.emitting = true
	p.amount = 20 + tier * 8
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -5, 0)
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.10
	var pm := StandardMaterial3D.new()
	pm.albedo_color = col
	pm.emission_enabled = true
	pm.emission = col
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
