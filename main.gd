extends Node3D

# ─────────────────────────────────────────────
# Main game scene.
# Builds the environment, the player, the enemies,
# the HUD, and the touch controls.
# Acts as the game_manager for score/hp events.
# ─────────────────────────────────────────────

const FLOOR_SIZE := 40.0
const ENEMY_COUNT := 5

var _hud_kills: Label = null
var _hud_hp: Label = null
var _kills := 0
var _player: CharacterBody3D = null

func _ready() -> void:
	add_to_group("game_manager")
	_build_environment()
	_build_floor()
	_build_player()
	_build_lighting()
	_build_enemies()
	_build_hud()
	_build_touch_controls()

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
	_player = player

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)

func _build_enemies() -> void:
	var enemy_script = load("res://enemy.gd")
	for i in range(ENEMY_COUNT):
		var enemy := CharacterBody3D.new()
		enemy.set_script(enemy_script)
		var angle := (float(i) / ENEMY_COUNT) * TAU
		var radius := 10.0 + randf() * 5.0
		enemy.position = Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)

		var mesh := MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.4
		capsule.height = 1.6
		mesh.mesh = capsule
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.2, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.05, 0.05)
		mat.emission_energy_multiplier = 0.6
		mesh.material_override = mat
		mesh.position = Vector3(0, 0.8, 0)
		enemy.add_child(mesh)

		var col := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.6
		col.shape = shape
		col.position = Vector3(0, 0.8, 0)
		enemy.add_child(col)

		add_child(enemy)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUDLayer"

	_hud_kills = Label.new()
	_hud_kills.text = "KILLS: 0"
	_hud_kills.add_theme_font_size_override("font_size", 28)
	_hud_kills.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_hud_kills.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud_kills.add_theme_constant_override("outline_size", 6)
	_hud_kills.position = Vector2(30, 20)
	canvas.add_child(_hud_kills)

	_hud_hp = Label.new()
	_hud_hp.text = "HP: 100"
	_hud_hp.add_theme_font_size_override("font_size", 22)
	_hud_hp.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_hud_hp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud_hp.add_theme_constant_override("outline_size", 6)
	_hud_hp.position = Vector2(30, 60)
	canvas.add_child(_hud_hp)

	add_child(canvas)

func _build_touch_controls() -> void:
	var controls_script = load("res://touch_controls.gd")
	var canvas := CanvasLayer.new()
	canvas.name = "TouchControlsLayer"
	var controls := Control.new()
	controls.name = "TouchControls"
	controls.set_script(controls_script)
	canvas.add_child(controls)
	add_child(canvas)

# ─────────────────────────────────────────────
# Game manager callbacks (called via group)
# ─────────────────────────────────────────────

func on_enemy_killed(_pos: Vector3) -> void:
	_kills += 1
	if _hud_kills:
		_hud_kills.text = "KILLS: " + str(_kills)
	# Respawn a new enemy after a short delay so the arena stays active
	get_tree().create_timer(2.0).timeout.connect(_spawn_one_enemy)

func _spawn_one_enemy() -> void:
	var enemy_script = load("res://enemy.gd")
	var enemy := CharacterBody3D.new()
	enemy.set_script(enemy_script)
	var angle := randf() * TAU
	var radius := 14.0 + randf() * 4.0
	enemy.position = Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)

	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.05, 0.05)
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.8, 0)
	enemy.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)
	enemy.add_child(col)

	add_child(enemy)

func on_player_died() -> void:
	if _hud_hp:
		_hud_hp.text = "HP: 0 — YOU DIED"
		_hud_hp.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
