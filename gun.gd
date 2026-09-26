extends Node3D
class_name Gun

# Procedural tactical carbine. Attaches to a hand bone.

static func build(parent: Node3D) -> Node3D:
	var gun := Node3D.new()
	gun.name = "Rifle"
	# Materials
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	dark.roughness = 0.55
	dark.metallic = 0.65
	var mid := StandardMaterial3D.new()
	mid.albedo_color = Color(0.14, 0.13, 0.12)
	mid.roughness = 0.75
	mid.metallic = 0.45
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.55, 0.30, 0.10)
	accent.roughness = 0.85
	# Receiver (main body)
	_add_box(gun, Vector3(0, 0, -0.05), Vector3(0.055, 0.075, 0.28), dark)
	# Barrel
	_add_cyl(gun, Vector3(0, 0.015, -0.32), 0.018, 0.30, dark)
	# Muzzle brake
	_add_box(gun, Vector3(0, 0.015, -0.48), Vector3(0.035, 0.035, 0.06), mid)
	# Handguard / rail
	_add_box(gun, Vector3(0, -0.01, -0.22), Vector3(0.045, 0.05, 0.16), mid)
	# Magazine
	var mag := Node3D.new()
	var mag_box := MeshInstance3D.new()
	var mbm := BoxMesh.new()
	mbm.size = Vector3(0.045, 0.16, 0.07)
	mag_box.mesh = mbm
	mag_box.material_override = mid
	mag.add_child(mag_box)
	mag.rotation.x = -0.22
	mag.position = Vector3(0, -0.14, 0.02)
	gun.add_child(mag)
	# Grip
	var grip := Node3D.new()
	var gm := MeshInstance3D.new()
	var gm2 := BoxMesh.new()
	gm2.size = Vector3(0.04, 0.12, 0.055)
	gm.mesh = gm2
	gm.material_override = accent
	grip.add_child(gm)
	grip.rotation.x = 0.28
	grip.position = Vector3(0, -0.11, 0.10)
	gun.add_child(grip)
	# Stock
	_add_box(gun, Vector3(0, 0.005, 0.24), Vector3(0.05, 0.07, 0.14), mid)
	_add_box(gun, Vector3(0, -0.01, 0.33), Vector3(0.045, 0.09, 0.04), accent)
	# Optic / reflex sight
	_add_box(gun, Vector3(0, 0.065, -0.08), Vector3(0.05, 0.04, 0.08), dark)
	var scope_glass := StandardMaterial3D.new()
	scope_glass.albedo_color = Color(0.15, 0.55, 0.75)
	scope_glass.emission_enabled = true
	scope_glass.emission = Color(0.35, 0.75, 1.0)
	scope_glass.emission_energy_multiplier = 1.6
	_add_box(gun, Vector3(0, 0.087, -0.08), Vector3(0.035, 0.012, 0.05), scope_glass)
	# Foregrip
	_add_box(gun, Vector3(0, -0.09, -0.20), Vector3(0.032, 0.10, 0.045), mid)
	parent.add_child(gun)
	return gun

static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	parent.add_child(m)

static func _add_cyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	m.mesh = c
	m.position = pos
	m.rotation.x = PI * 0.5
	m.material_override = mat
	parent.add_child(m)
