extends Node3D

const FLOOR_SIZE := 40.0

func _ready() -> void:
	print("=== _ready() started ===")
	_build_environment()
	print("  environment built")
	_build_floor()
	print("  floor built")
	_build_player()
	print("  player built")
	_build_lighting()
	print("  lighting built")
	print("=== finished, children=", get_child_count(), "===")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
		for sub in child.get_children():
			print("      - ", sub.name, " (", sub.get_class(), ")")

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
	print("    _build_player: about to add player to scene, player=", player)
	add_child(player)
	print("    _build_player: player added, parent children=", get_child_count())

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)
