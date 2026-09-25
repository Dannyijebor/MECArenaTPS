extends Node
class_name SciFiEnv

# Sector-7 Neon Bazaar builder — Modular SciFi MegaKit
# Real piece sizes verified: 4m long × 2.2m tall × 0.2m thick

const WALL_LEN := 4.0
const WALL_H := 2.2
const WALL_THICK := 0.2
const WALL_ROWS := 2

var floor_size: float = 40.0
var half: float = 20.0
var wall_h: float = 4.4

func build(parent: Node3D, size: float) -> void:
	floor_size = size
	half = size * 0.5 - 0.15
	wall_h = WALL_H * float(WALL_ROWS)
	_build_walls(parent)
	_build_corners(parent)
	_build_ceiling(parent)
	_build_floor_trim(parent)
	_build_columns(parent)
	_build_props(parent)
	_build_pipes(parent)
	_build_ceiling_lights(parent)
	_build_hazard_stripes(parent)

# ----------------------------------------------------------------
# WALLS — 4 sides, 2 rows stacked, correct dimensions
# ----------------------------------------------------------------
func _build_walls(parent: Node3D) -> void:
	var n_per_side: int = int(floor_size / WALL_LEN)
	var row_ys: Array = []
	for r in range(WALL_ROWS):
		row_ys.append(WALL_H * 0.5 + r * WALL_H)
	# North (-Z) — piece length runs along X, so rotate 90°
	for y in row_ys:
		for i in range(n_per_side):
			var x: float = -floor_size * 0.5 + WALL_LEN * 0.5 + i * WALL_LEN
			_place(parent, "Walls/WallBand_Straight.gltf",
				Vector3(x, y, -half), PI * 0.5,
				Vector3(WALL_LEN, WALL_H, 0.5))
	# South (+Z)
	for y in row_ys:
		for i in range(n_per_side):
			var x: float = -floor_size * 0.5 + WALL_LEN * 0.5 + i * WALL_LEN
			_place(parent, "Walls/WallBand_Straight.gltf",
				Vector3(x, y, half), PI * 0.5,
				Vector3(WALL_LEN, WALL_H, 0.5))
	# West (-X) — length runs along Z, no rotation
	for y in row_ys:
		for i in range(n_per_side):
			var z: float = -floor_size * 0.5 + WALL_LEN * 0.5 + i * WALL_LEN
			_place(parent, "Walls/WallBand_Straight.gltf",
				Vector3(-half, y, z), 0.0,
				Vector3(0.5, WALL_H, WALL_LEN))
	# East (+X)
	for y in row_ys:
		for i in range(n_per_side):
			var z: float = -floor_size * 0.5 + WALL_LEN * 0.5 + i * WALL_LEN
			_place(parent, "Walls/WallBand_Straight.gltf",
				Vector3(half, y, z), 0.0,
				Vector3(0.5, WALL_H, WALL_LEN))

# ----------------------------------------------------------------
# CORNERS — 4 vertical stack joints
# ----------------------------------------------------------------
func _build_corners(parent: Node3D) -> void:
	var corner_scn := "Walls/WallBand_Corner_Round_Inner.gltf"
	var positions := [
		Vector3(-half, WALL_H * 0.5, -half),
		Vector3( half, WALL_H * 0.5, -half),
		Vector3( half, WALL_H * 0.5,  half),
		Vector3(-half, WALL_H * 0.5,  half),
	]
	var rots := [0.0, -PI * 0.5, PI, PI * 0.5]
	for i in range(4):
		_place(parent, corner_scn, positions[i], rots[i])

# ----------------------------------------------------------------
# CEILING — trim pieces along all 4 top edges + center panel
# ----------------------------------------------------------------
func _build_ceiling(parent: Node3D) -> void:
	var n_per_side: int = int(floor_size / WALL_LEN)
	var y := wall_h + 0.05
	# North + South trim
	for i in range(n_per_side):
		var x: float = -floor_size * 0.5 + WALL_LEN * 0.5 + i * WALL_LEN
		_place(parent, "Walls/TopSimple_Straight.gltf", Vector3(x, y, -half), PI * 0.5)
		_place(parent, "Walls/TopSimple_Straight.gltf", Vector3(x, y, half), PI * 0.5)
	# West + East trim
	for i in range(n_per_side):
		var z: float = -floor_size * 0.5 + WALL_LEN * 0.5 + i * WALL_LEN
		_place(parent, "Walls/TopSimple_Straight.gltf", Vector3(-half, y, z), 0.0)
		_place(parent, "Walls/TopSimple_Straight.gltf", Vector3(half, y, z), 0.0)
	# Center cross — 3x3 grid of TopCables_Hanging for industrial feel
	for x in [-10.0, 0.0, 10.0]:
		for z in [-10.0, 0.0, 10.0]:
			if x == 0.0 and z == 0.0:
				continue
			_place(parent, "Walls/TopCables_Straight_Hanging.gltf", Vector3(x, wall_h - 0.3, z), 0.0)

# ----------------------------------------------------------------
# FLOOR TRIM — dark metal plates around perimeter
# ----------------------------------------------------------------
func _build_floor_trim(parent: Node3D) -> void:
	var y := 0.02
	var edge := floor_size * 0.5 - 2.0
	var positions := []
	for i in range(-3, 4):
		positions.append(Vector3(i * 5.0, y, -edge))
		positions.append(Vector3(i * 5.0, y,  edge))
		positions.append(Vector3(-edge, y, i * 5.0))
		positions.append(Vector3( edge, y, i * 5.0))
	for p in positions:
		_place(parent, "Platforms/Platform_DarkPlates.gltf", p, 0.0)

# ----------------------------------------------------------------
# COLUMNS — 4 structural + 4 pipe columns
# ----------------------------------------------------------------
func _build_columns(parent: Node3D) -> void:
	# 4 large structural columns — heavy cover
	var struct_positions := [
		Vector3(-10, 0, -10),
		Vector3( 10, 0, -10),
		Vector3(-10, 0,  10),
		Vector3( 10, 0,  10),
	]
	for p in struct_positions:
		_place(parent, "Columns/Column_Large_Straight.gltf", p, 0.0,
			Vector3(1.2, 6.0, 1.2))
	# 4 support columns against the walls
	var sup_positions := [
		Vector3(-half + 0.6, 0, -8),
		Vector3( half - 0.6, 0, -8),
		Vector3(-half + 0.6, 0,  8),
		Vector3( half - 0.6, 0,  8),
	]
	for p in sup_positions:
		_place(parent, "Columns/Column_MetalSupport.gltf", p, 0.0,
			Vector3(0.6, 5.0, 0.6))
	# 2 pipe columns mid-arena
	_place(parent, "Columns/Column_Pipes.gltf", Vector3(0, 0, -14), 0.0,
		Vector3(0.8, 5.0, 0.8))
	_place(parent, "Columns/Column_Pipes.gltf", Vector3(0, 0, 14), 0.0,
		Vector3(0.8, 5.0, 0.8))

# ----------------------------------------------------------------
# PROPS — crates, barrels, computers, vents, chest
# ----------------------------------------------------------------
func _build_props(parent: Node3D) -> void:
	# Crates as cover — 8 total, mixed sizes
	var crate_spots := [
		Vector3(-4, 0, -3), Vector3( 4, 0, -3),
		Vector3(-4, 0,  3), Vector3( 4, 0,  3),
		Vector3(-15, 0, -6), Vector3(15, 0, -6),
		Vector3(-15, 0,  6), Vector3(15, 0,  6),
	]
	for i in range(crate_spots.size()):
		var s: String = "Props/Prop_Crate3.gltf" if i % 2 == 0 else "Props/Prop_Crate4.gltf"
		_place(parent, s, crate_spots[i], 0.0,
			Vector3(1.2, 1.2, 1.2))
	# Barrels — 4, near walls
	var barrel_spots := [
		Vector3(-14, 0, 0), Vector3(14, 0, 0),
		Vector3(0, 0, -17), Vector3(0, 0, 17),
	]
	for p in barrel_spots:
		_place(parent, "Props/Prop_Barrel_Large.gltf", p, 0.0,
			Vector3(1.0, 1.6, 1.0))
	# Computer terminals — 3, north + west + east walls
	_place(parent, "Props/Prop_Computer.gltf", Vector3(-6, 0, -half + 1.4), 0.0,
		Vector3(0.8, 1.2, 0.8))
	_place(parent, "Props/Prop_Computer.gltf", Vector3( 6, 0, -half + 1.4), 0.0,
		Vector3(0.8, 1.2, 0.8))
	_place(parent, "Props/Prop_Computer.gltf", Vector3(-half + 1.4, 0, 0), PI * 0.5,
		Vector3(0.8, 1.2, 0.8))
	# Chest — loot location
	_place(parent, "Props/Prop_Chest.gltf", Vector3(0, 0, 0), 0.0,
		Vector3(1.0, 0.8, 0.6))
	# Access point — schematic
	_place(parent, "Props/Prop_AccessPoint.gltf", Vector3(half - 1.4, 0, -8), -PI * 0.5,
		Vector3(0.6, 1.4, 0.6))
	# Vents — decorative on walls, 4 total
	_place(parent, "Props/Prop_Vent_Big.gltf", Vector3(-8, 3.0, -half + 0.4), 0.0)
	_place(parent, "Props/Prop_Vent_Big.gltf", Vector3( 8, 3.0, -half + 0.4), 0.0)
	_place(parent, "Props/Prop_Vent_Big.gltf", Vector3( 8, 3.0,  half - 0.4), PI)
	_place(parent, "Props/Prop_Vent_Big.gltf", Vector3(-8, 3.0,  half - 0.4), PI)
	# Item holder — loot spawn
	_place(parent, "Props/Prop_ItemHolder.gltf", Vector3(-half + 1.5, 0, -10), PI * 0.5,
		Vector3(0.5, 1.0, 0.5))

# ----------------------------------------------------------------
# PIPES — vertical pipe run along back wall
# ----------------------------------------------------------------
func _build_pipes(parent: Node3D) -> void:
	var y := 3.5
	for i in range(5):
		var x: float = -floor_size * 0.5 + 4.0 + i * 8.0
		_place(parent, "Props/Prop_PipeHolder.gltf", Vector3(x, y, -half + 0.3), 0.0)
	for i in range(5):
		var x: float = -floor_size * 0.5 + 4.0 + i * 8.0
		_place(parent, "Props/Prop_PipeHolder.gltf", Vector3(x, y, half - 0.3), PI)

# ----------------------------------------------------------------
# CEILING LIGHTS — 6 OmniLights strung across the room
# ----------------------------------------------------------------
func _build_ceiling_lights(parent: Node3D) -> void:
	var positions := [
		Vector3(-10, wall_h - 0.5, -10),
		Vector3( 10, wall_h - 0.5, -10),
		Vector3(-10, wall_h - 0.5,  10),
		Vector3( 10, wall_h - 0.5,  10),
		Vector3(  0, wall_h - 0.5,   0),
	]
	for p in positions:
		var light := OmniLight3D.new()
		light.light_color = Color(0.85, 0.80, 1.0)
		light.light_energy = 1.8
		light.omni_range = 14.0
		light.position = p
		parent.add_child(light)
		_place(parent, "Props/Prop_Light_Wide.gltf", p + Vector3(0, -0.15, 0), 0.0)

# ----------------------------------------------------------------
# HAZARD STRIPES — glowing trim along the wall base
# ----------------------------------------------------------------
func _build_hazard_stripes(parent: Node3D) -> void:
	var stripe_col := Color(1.0, 0.55, 0.15)
	var y := 0.08
	var length := floor_size - 1.0
	var sides := [
		{"pos": Vector3(0, y, -half + 0.2), "size": Vector3(length, 0.06, 0.08), "rot": 0.0},
		{"pos": Vector3(0, y,  half - 0.2), "size": Vector3(length, 0.06, 0.08), "rot": 0.0},
		{"pos": Vector3(-half + 0.2, y, 0), "size": Vector3(0.08, 0.06, length), "rot": 0.0},
		{"pos": Vector3( half - 0.2, y, 0), "size": Vector3(0.08, 0.06, length), "rot": 0.0},
	]
	for s in sides:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s.size
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = stripe_col
		mat.emission_enabled = true
		mat.emission = stripe_col
		mat.emission_energy_multiplier = 2.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = mat
		mesh.position = s.pos
		parent.add_child(mesh)

# ----------------------------------------------------------------
# PLACEMENT HELPER
# ----------------------------------------------------------------
func _place(parent: Node3D, path: String, pos: Vector3,
		rot_y: float = 0.0, body_size: Vector3 = Vector3.ZERO) -> Node3D:
	var scn: PackedScene = load("res://models/env/scifi/glTF/" + path)
	if scn == null:
		return null
	var inst: Node3D = scn.instantiate()
	parent.add_child(inst)
	inst.position = pos
	if rot_y != 0.0:
		inst.rotation.y = rot_y
	if body_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = body_size
		col.shape = shape
		body.add_child(col)
		body.position = pos
		body.rotation.y = rot_y
		body.add_to_group("cover")
		parent.add_child(body)
	return inst
