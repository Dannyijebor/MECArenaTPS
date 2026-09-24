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

func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_player()
	_build_lighting()
	_build_environment_obstacles()
	_build_touch_controls()
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
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)

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
	for i in range(count):
		var angle := (float(i) / float(count)) * TAU + randf() * 0.4
		var radius := 14.0 + randf() * 4.0
		var pos := Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)
		_spawn_enemy_at(pos, enemy_script)

func _spawn_enemy_at(pos: Vector3, enemy_script: Script) -> void:
	var e := CharacterBody3D.new()
	e.set_script(enemy_script)
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
	_enemies_alive += 1

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

func _on_player_died() -> void:
	# Freeze input briefly, then respawn
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func(): _respawn_player())

func _respawn_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("respawn"):
		player.call("respawn")

func _process(delta: float) -> void:
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
