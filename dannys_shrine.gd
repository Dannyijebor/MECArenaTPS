extends Node3D
class_name DannysShrine
const SFX := preload("res://sfx.gd")

# Small clean-white shrine room. Landmark + safe zone + loot cache.

const ROOM_W := 6.0
const ROOM_H := 3.2
const ROOM_D := 6.0
const SAFE_RADIUS := 8.0

var _floor_origin: Vector3 = Vector3.ZERO
var _cyan_light: OmniLight3D = null
var _terminal_glow: MeshInstance3D = null
var _chest_opened: bool = false

func setup(origin: Vector3) -> void:
	_floor_origin = origin

func _ready() -> void:
	add_to_group("shrine")
	add_to_group("danny_zone")
	_build_room()
	_build_floor_etching()
	_build_terminal()
	_build_loot_chest()
	_build_aura()

func _build_room() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.88, 0.90, 0.94)
	white.roughness = 0.35
	white.metallic = 0.05
	# Floor
	_add_box(Vector3(0, 0.02, 0), Vector3(ROOM_W, 0.05, ROOM_D), white)
	# Ceiling
	_add_box(Vector3(0, ROOM_H, 0), Vector3(ROOM_W, 0.15, ROOM_D), white)
	# 4 walls (with doorway gap on south side facing arena)
	# North
	_add_box(Vector3(0, ROOM_H * 0.5, -ROOM_D * 0.5), Vector3(ROOM_W, ROOM_H, 0.20), white)
	# East
	_add_box(Vector3(ROOM_W * 0.5, ROOM_H * 0.5, 0), Vector3(0.20, ROOM_H, ROOM_D), white)
	# West
	_add_box(Vector3(-ROOM_W * 0.5, ROOM_H * 0.5, 0), Vector3(0.20, ROOM_H, ROOM_D), white)
	# South — split for doorway
	_add_box(Vector3(-2.0, ROOM_H * 0.5, ROOM_D * 0.5), Vector3(2.0, ROOM_H, 0.20), white)
	_add_box(Vector3( 2.0, ROOM_H * 0.5, ROOM_D * 0.5), Vector3(2.0, ROOM_H, 0.20), white)
	# Collision bodies
	_add_wall_body(Vector3(0, ROOM_H * 0.5, -ROOM_D * 0.5), Vector3(ROOM_W, ROOM_H, 0.20))
	_add_wall_body(Vector3(ROOM_W * 0.5, ROOM_H * 0.5, 0), Vector3(0.20, ROOM_H, ROOM_D))
	_add_wall_body(Vector3(-ROOM_W * 0.5, ROOM_H * 0.5, 0), Vector3(0.20, ROOM_H, ROOM_D))
	_add_wall_body(Vector3(-2.0, ROOM_H * 0.5, ROOM_D * 0.5), Vector3(2.0, ROOM_H, 0.20))
	_add_wall_body(Vector3( 2.0, ROOM_H * 0.5, ROOM_D * 0.5), Vector3(2.0, ROOM_H, 0.20))

func _build_floor_etching() -> void:
	# Gold "MADE BY DANNY" text etched in the floor
	var tm := TextMesh.new()
	tm.text = "MADE BY DANNY"
	tm.font_size = 128
	tm.pixel_size = 0.008
	tm.depth = 0.03
	tm.curve_step = 0.5
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.30)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.78, 0.25)
	gold.emission_energy_multiplier = 2.5
	gold.metallic = 0.9
	gold.roughness = 0.25
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = gold
	mi.position = Vector3(0, 0.06, 0)
	mi.rotation.x = -PI * 0.5
	add_child(mi)

func _build_terminal() -> void:
	# Small terminal at the north wall — glowing screen
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 1.2, 0.3)
	body.mesh = box
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.15, 0.16, 0.20)
	grey.roughness = 0.5
	grey.metallic = 0.6
	body.material_override = grey
	body.position = Vector3(0, 0.6, -ROOM_D * 0.5 + 0.3)
	add_child(body)
	var screen := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(0.7, 0.5, 0.05)
	screen.mesh = sbox
	var cyan := StandardMaterial3D.new()
	cyan.albedo_color = Color(0.20, 0.95, 1.0)
	cyan.emission_enabled = true
	cyan.emission = Color(0.20, 0.95, 1.0)
	cyan.emission_energy_multiplier = 3.5
	cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.material_override = cyan
	screen.position = Vector3(0, 0.85, -ROOM_D * 0.5 + 0.12)
	add_child(screen)
	_terminal_glow = screen
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 0.95, 1.0)
	light.light_energy = 2.5
	light.omni_range = 6.0
	light.position = Vector3(0, 1.2, -ROOM_D * 0.5 + 0.6)
	add_child(light)
	_cyan_light = light

func _build_loot_chest() -> void:
	# Danny-tier chest at the shrine center
	var chest_script: Script = load("res://loot_chest.gd")
	if chest_script == null:
		return
	var chest := Area3D.new()
	chest.set_script(chest_script)
	chest.position = Vector3(0, 0.6, 0)
	add_child(chest)

func _build_aura() -> void:
	# 3 gold lantern fixtures + soft ceiling glow
	for offset in [Vector3(-2.0, 0.5, -2.0), Vector3(2.0, 0.5, -2.0), Vector3(-2.0, 0.5, 2.0), Vector3(2.0, 0.5, 2.0)]:
		var lantern := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.12
		sph.height = 0.24
		lantern.mesh = sph
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 0.85, 0.35)
		lmat.emission_enabled = true
		lmat.emission = Color(1.0, 0.82, 0.30)
		lmat.emission_energy_multiplier = 3.0
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lantern.material_override = lmat
		lantern.position = offset + Vector3(0, 2.5, 0)
		add_child(lantern)
		var lg := OmniLight3D.new()
		lg.light_color = Color(1.0, 0.82, 0.35)
		lg.light_energy = 1.5
		lg.omni_range = 4.0
		lg.position = offset + Vector3(0, 2.4, 0)
		add_child(lg)

func _add_box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _add_wall_body(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	body.add_to_group("cover")
	add_child(body)
