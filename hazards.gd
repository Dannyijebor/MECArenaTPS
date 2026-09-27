extends Area3D
class_name Hazard

enum Kind { FIRE, ELECTRIC, SPIKE }

var kind: int = 0
var _t: float = 0.0
var _player: Node3D = null
var _player_in: bool = false
var _cooldown: float = 0.0
var _mesh: MeshInstance3D = null
var _light: OmniLight3D = null
var _base_energy: float = 2.5

func setup(k: int) -> void:
	kind = k

func _ready() -> void:
	add_to_group("hazard")
	_player = get_tree().get_first_node_in_group("player")
	_build_visual()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _build_visual() -> void:
	var col: Color
	var radius: float = 1.4
	match kind:
		Kind.FIRE:
			col = Color(1.0, 0.45, 0.15)
		Kind.ELECTRIC:
			col = Color(0.30, 0.75, 1.0)
		Kind.SPIKE:
			col = Color(0.85, 0.15, 0.20)
	# Disc
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.06
	_mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = _base_energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 0.05, 0)
	add_child(_mesh)
	# Light
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 2.4
	_light.omni_range = 5.0
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)
	# Collision
	var col_shape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.6
	col_shape.shape = shape
	col_shape.position = Vector3(0, 0.8, 0)
	add_child(col_shape)

func _process(delta: float) -> void:
	_t += delta
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
	var e: float = _base_energy * (0.6 + pulse * 0.6)
	if _mesh != null:
		var mat := _mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = e
	if _light != null:
		_light.light_energy = 2.0 + pulse * 1.6
	if _cooldown > 0.0:
		_cooldown -= delta
	if _player_in and _cooldown <= 0.0 and _player != null:
		_damage_player()

func _damage_player() -> void:
	if _player == null or not _player.has_method("take_damage"):
		return
	match kind:
		Kind.FIRE:
			_player.call("take_damage", 6)
			_cooldown = 0.7
		Kind.ELECTRIC:
			_player.call("take_damage", 10)
			_cooldown = 1.2
		Kind.SPIKE:
			_player.call("take_damage", 15)
			_cooldown = 1.5

func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in = true

func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in = false
