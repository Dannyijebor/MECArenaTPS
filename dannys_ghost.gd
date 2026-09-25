extends Node3D
class_name DannysGhost
const SFX := preload("res://sfx.gd")

# Flickering hologram guide. Walks from spawn to a target, drops
# legendary loot if the player gets within range before it fades.

const WALK_SPEED := 2.2
const LIFETIME := 22.0
const FOLLOW_RANGE := 4.5
const FADE_TIME := 1.6
const GLITCH_INTERVAL := 0.18

var target_pos: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _done: bool = false
var _bob: float = 0.0
var _glitch_accum: float = 0.0
var _base_y: float = 0.0
var _body: MeshInstance3D = null
var _light: OmniLight3D = null
var _player: Node3D = null

func setup(target: Vector3) -> void:
	target_pos = target

func _ready() -> void:
	add_to_group("dannys_ghost")
	_base_y = global_position.y
	_player = get_tree().get_first_node_in_group("player")
	_build_hologram()
	SFX.play("distant_gunfire", -10.0, 1.6)

func _build_hologram() -> void:
	# Core capsule — Danny silhouette
	var mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	mesh.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.90, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.30, 0.90, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.rim_enabled = true
	mat.rim = 1.0
	mesh.material_override = mat
	mesh.name = "Body"
	add_child(mesh)
	_body = mesh
	# Head
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	head.mesh = sphere
	head.material_override = mat
	head.position = Vector3(0, 1.15, 0)
	add_child(head)
	# Ambient glow
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.92, 1.0)
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.position = Vector3(0, 1.0, 0)
	add_child(light)
	_light = light
	# Ground trail dots
	for i in range(6):
		var dot := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.08
		disc.bottom_radius = 0.08
		disc.height = 0.02
		dot.mesh = disc
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.20, 0.95, 1.0, 0.9)
		dmat.emission_enabled = true
		dmat.emission = Color(0.30, 0.95, 1.0)
		dmat.emission_energy_multiplier = 4.0
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot.material_override = dmat
		dot.position = Vector3(0, 0.03, 0.5 + i * 0.4)
		add_child(dot)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_bob += delta * 2.4
	# Walk toward target
	var to_target: Vector3 = target_pos - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	if dist > 0.5:
		var step: Vector3 = to_target.normalized() * WALK_SPEED * delta
		var new_pos: Vector3 = global_position + step
		new_pos.y = _base_y + sin(_bob) * 0.05
		global_position = new_pos
		# Face movement direction
		var look_at_pos: Vector3 = global_position + to_target.normalized()
		look_at(look_at_pos, Vector3.UP)
	# Flicker / glitch
	_glitch_accum += delta
	if _glitch_accum > GLITCH_INTERVAL:
		_glitch_accum = 0.0
		_flicker()
	# Check player follow
	if _player != null and is_instance_valid(_player):
		var d: float = _player.global_position.distance_to(global_position)
		if d < FOLLOW_RANGE:
			_reward()
			return
	# Lifetime countdown
	if _t >= LIFETIME - FADE_TIME:
		_fade_out()

func _flicker() -> void:
	if _body != null:
		var alpha: float = randf_range(0.25, 0.75)
		var mat := _body.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = alpha
	if _light != null:
		_light.light_energy = randf_range(1.5, 4.5)

func _fade_out() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.set_parallel(true)
	if _body != null:
		var mat := _body.material_override as StandardMaterial3D
		if mat != null:
			tw.tween_property(mat, "albedo_color:a", 0.0, FADE_TIME)
			tw.tween_property(mat, "emission_energy_multiplier", 0.0, FADE_TIME)
	if _light != null:
		tw.tween_property(_light, "light_energy", 0.0, FADE_TIME)
	tw.chain().tween_callback(queue_free)

func _reward() -> void:
	if _done:
		return
	_done = true
	SFX.play("wave_clear", 0.0, 1.4)
	# Spawn legendary loot at target
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("spawn_danny_loot"):
		main.call("spawn_danny_loot", target_pos)
	# Vanish burst
	var p := CPUParticles3D.new()
	p.emitting = true
	p.amount = 60
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -2, 0)
	var sph := SphereMesh.new()
	sph.radius = 0.08
	sph.height = 0.16
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.30, 0.95, 1.0)
	pm.emission_enabled = true
	pm.emission = Color(0.30, 0.95, 1.0)
	pm.emission_energy_multiplier = 4.0
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material = pm
	p.mesh = sph
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	var t := get_tree().create_timer(1.6)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
		if is_instance_valid(self):
			queue_free()
	)
