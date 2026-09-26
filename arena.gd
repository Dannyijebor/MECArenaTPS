extends Node3D
class_name Arena

# RESONANCE — The Vault
# Hand-crafted 80x80 sealed arena. 4 quadrant rooms + central atrium.
# Every wall is a physics box. Nothing falls through, nothing shoots through.

const SIZE := 80.0
const HALF := 40.0
const WALL_THICK := 0.8
const WALL_H := 8.0

# Palette — warm industrial
const COLOR_WALL := Color(0.16, 0.14, 0.12)
const COLOR_FLOOR := Color(0.20, 0.17, 0.14)
const COLOR_ROOF := Color(0.08, 0.07, 0.06)
const COLOR_TRIM := Color(0.55, 0.42, 0.28)
const COLOR_ACCENT := Color(1.0, 0.72, 0.35)
const COLOR_AMBIENT := Color(1.0, 0.82, 0.55)

var _parent: Node3D = null

func build(parent: Node3D) -> void:
	_parent = parent
	_build_floor()
	_build_floor_tiles()
	_build_shell()
	_build_roof()
	_build_interior()
	_build_wall_patterns()
	_build_cover()
	_build_decor()
	_build_lighting()
	_build_made_by_danny()
	print("[arena] The Vault built — ", SIZE, "x", SIZE, "m sealed")

# ================================================================
# FLOOR — solid 80x80 slab with collision
# ================================================================
func _build_floor() -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(SIZE, 0.4, SIZE)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FLOOR
	mat.roughness = 0.35
	mat.metallic = 0.30
	m.material_override = mat
	m.position = Vector3(0, -0.2, 0)
	_parent.add_child(m)
	# Collision
	_solid(Vector3(0, -0.2, 0), Vector3(SIZE, 0.4, SIZE))

# ================================================================
# SHELL — 4 outer walls, sealed
# ================================================================
func _build_shell() -> void:
	var th := WALL_THICK
	var w := SIZE
	var h := WALL_H
	# North wall (-Z)
	_wall(Vector3(0, h*0.5, -HALF + th*0.5), Vector3(w, h, th))
	# South wall (+Z)
	_wall(Vector3(0, h*0.5,  HALF - th*0.5), Vector3(w, h, th))
	# West wall (-X)
	_wall(Vector3(-HALF + th*0.5, h*0.5, 0), Vector3(th, h, w))
	# East wall (+X)
	_wall(Vector3( HALF - th*0.5, h*0.5, 0), Vector3(th, h, w))

# ================================================================
# ROOF — solid ceiling slab
# ================================================================
func _build_roof() -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(SIZE, 0.4, SIZE)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_ROOF
	mat.roughness = 0.9
	m.material_override = mat
	m.position = Vector3(0, WALL_H + 0.2, 0)
	_parent.add_child(m)
	# Collision
	_solid(Vector3(0, WALL_H + 0.2, 0), Vector3(SIZE, 0.4, SIZE))
	# Ceiling beams for depth
	for i in range(9):
		var x: float = -32.0 + i * 8.0
		_deco_box(Vector3(x, WALL_H - 0.15, 0), Vector3(0.4, 0.4, SIZE - 2.0), Color(0.06, 0.05, 0.04))
	for i in range(9):
		var z: float = -32.0 + i * 8.0
		_deco_box(Vector3(0, WALL_H - 0.15, z), Vector3(SIZE - 2.0, 0.4, 0.4), Color(0.06, 0.05, 0.04))

# ================================================================
# INTERIOR — 4 quadrant rooms + central atrium + corridors
# ================================================================
func _build_interior() -> void:
	# Room boundaries (each quadrant room is 28x28, atrium is 24x24)
	var room_ext := 14.0     # half-width of an interior room
	var atrium_ext := 12.0   # half-width of the central atrium
	var corridor_w := 4.0    # width of connecting corridors
	var h := WALL_H
	var th := 0.4            # interior wall thickness
	# === North wall of south rooms and south wall of north rooms ===
	# These run along X at z = +/- (room_ext + corridor_w/2)
	var room_z := room_ext + corridor_w * 0.5
	var room_seg := room_ext       # length of each wall segment
	# Horizontal dividers (along X)
	for z_sign in [-1.0, 1.0]:
		var z: float = z_sign * room_z
		# Left segment (west side, from outer wall to corridor)
		var x_left: float = -HALF + WALL_THICK + room_seg * 0.5
		_wall(Vector3(x_left, h*0.5, z), Vector3(room_seg, h, th))
		# Right segment (east side)
		var x_right: float = HALF - WALL_THICK - room_seg * 0.5
		_wall(Vector3(x_right, h*0.5, z), Vector3(room_seg, h, th))
	# Vertical dividers (along Z)
	for x_sign in [-1.0, 1.0]:
		var x: float = x_sign * room_z
		var z_top: float = -HALF + WALL_THICK + room_seg * 0.5
		_wall(Vector3(x, h*0.5, z_top), Vector3(th, h, room_seg))
		var z_bot: float = HALF - WALL_THICK - room_seg * 0.5
		_wall(Vector3(x, h*0.5, z_bot), Vector3(th, h, room_seg))
	# === Atrium walls — 4 dividers facing the central space ===
	# Each has a 4m doorway in the middle
	var a_ext := atrium_ext
	var door_half := 2.0
	# Wall segments facing atrium, split around doorway
	# North side (top of atrium)
	for side in [-1.0, 1.0]:
		var seg_len: float = a_ext - door_half
		var x_seg: float = side * (door_half + seg_len * 0.5)
		_wall(Vector3(x_seg, h*0.5, -a_ext), Vector3(seg_len, h, th))
	# South side
	for side in [-1.0, 1.0]:
		var seg_len: float = a_ext - door_half
		var x_seg: float = side * (door_half + seg_len * 0.5)
		_wall(Vector3(x_seg, h*0.5, a_ext), Vector3(seg_len, h, th))
	# West side
	for side in [-1.0, 1.0]:
		var seg_len: float = a_ext - door_half
		var z_seg: float = side * (door_half + seg_len * 0.5)
		_wall(Vector3(-a_ext, h*0.5, z_seg), Vector3(th, h, seg_len))
	# East side
	for side in [-1.0, 1.0]:
		var seg_len: float = a_ext - door_half
		var z_seg: float = side * (door_half + seg_len * 0.5)
		_wall(Vector3(a_ext, h*0.5, z_seg), Vector3(th, h, seg_len))

# ================================================================
# COVER — crates, pillars, barrels, dividers
# ================================================================
func _build_cover() -> void:
	# === Atrium: 4 central pillars + 4 corner crates ===
	var pillars := [
		Vector3(-6, 0, -6), Vector3(6, 0, -6),
		Vector3(-6, 0,  6), Vector3(6, 0,  6),
	]
	for p in pillars:
		_pillar(p, 1.2, WALL_H)
	var crates_atrium := [
		Vector3(-10, 0, -3), Vector3(-10, 0,  3),
		Vector3( 10, 0, -3), Vector3( 10, 0,  3),
		Vector3(-3, 0, -10), Vector3( 3, 0, -10),
		Vector3(-3, 0,  10), Vector3( 3, 0,  10),
	]
	for c in crates_atrium:
		_crate(c, 1.2)
	# === NW room (Armory) — bunks + lockers ===
	var nw_center := Vector3(-26, 0, -26)
	_room_cover(nw_center, 10.0)
	# === NE room (Control) — desks + terminals ===
	var ne_center := Vector3( 26, 0, -26)
	_room_cover(ne_center, 10.0)
	# === SW room (Storage) — big stacks of crates ===
	var sw_center := Vector3(-26, 0,  26)
	_room_cover(sw_center, 10.0)
	# === SE room (Barracks) — pillars + beds ===
	var se_center := Vector3( 26, 0,  26)
	_room_cover(se_center, 10.0)

func _room_cover(center: Vector3, spread: float) -> void:
	# Grid of cover pieces
	var offsets := [
		Vector3(-4, 0, -4), Vector3( 4, 0, -4),
		Vector3(-4, 0,  4), Vector3( 4, 0,  4),
		Vector3( 0, 0,  0),
	]
	for off in offsets:
		_crate(center + off, 1.2)
	# Two large pillars at diagonals
	_pillar(center + Vector3(-spread, 0, 0), 1.0, WALL_H)
	_pillar(center + Vector3( spread, 0, 0), 1.0, WALL_H)
	_pillar(center + Vector3(0, 0, -spread), 1.0, WALL_H)
	_pillar(center + Vector3(0, 0,  spread), 1.0, WALL_H)

# ================================================================
# DECOR — hazard stripes, wall details, signs
# ================================================================
func _build_decor() -> void:
	# Hazard stripes at atrium doorway thresholds
	var door_positions := [
		Vector3(0, 0.05, -12.0), Vector3(0, 0.05, 12.0),
		Vector3(-12.0, 0.05, 0), Vector3(12.0, 0.05, 0),
	]
	for p in door_positions:
		_hazard_strip(p)
	# Wall trim bands along the outer shell at 1m and 5m heights
	var trim_ys := [1.2, 5.5]
	for y in trim_ys:
		# Along north/south
		_deco_box(Vector3(0, y, -HALF + WALL_THICK + 0.02), Vector3(SIZE - 2.0, 0.10, 0.06), COLOR_TRIM)
		_deco_box(Vector3(0, y,  HALF - WALL_THICK - 0.02), Vector3(SIZE - 2.0, 0.10, 0.06), COLOR_TRIM)
		# Along east/west
		_deco_box(Vector3(-HALF + WALL_THICK + 0.02, y, 0), Vector3(0.06, 0.10, SIZE - 2.0), COLOR_TRIM)
		_deco_box(Vector3( HALF - WALL_THICK - 0.02, y, 0), Vector3(0.06, 0.10, SIZE - 2.0), COLOR_TRIM)
	# Vents high on outer walls
	for i in range(6):
		var x: float = -30.0 + i * 12.0
		_deco_box(Vector3(x, 6.5, -HALF + WALL_THICK + 0.3), Vector3(1.2, 0.8, 0.6), Color(0.10, 0.09, 0.08))
		_deco_box(Vector3(x, 6.5,  HALF - WALL_THICK - 0.3), Vector3(1.2, 0.8, 0.6), Color(0.10, 0.09, 0.08))

func _hazard_strip(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(6.0, 0.10, 1.0)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_ACCENT
	mat.emission_enabled = true
	mat.emission = COLOR_ACCENT
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	_parent.add_child(m)

# ================================================================
# LIGHTING — 8 ceiling lights, warm amber
# ================================================================
func _build_lighting() -> void:
	var positions := [
		Vector3(-20, WALL_H - 1.0, -20),
		Vector3( 20, WALL_H - 1.0, -20),
		Vector3(-20, WALL_H - 1.0,  20),
		Vector3( 20, WALL_H - 1.0,  20),
		Vector3(  0, WALL_H - 1.0,   0),
		Vector3(-10, WALL_H - 1.0,   0),
		Vector3( 10, WALL_H - 1.0,   0),
		Vector3(  0, WALL_H - 1.0,  10),
	]
	for p in positions:
		var l := OmniLight3D.new()
		l.light_color = COLOR_AMBIENT
		l.light_energy = 2.4
		l.omni_range = 18.0
		l.position = p
		_parent.add_child(l)
		# Visible light fixture
		_deco_box(p + Vector3(0, 0.15, 0), Vector3(1.2, 0.2, 1.2), Color(0.30, 0.25, 0.18))
		_emissive_box(p, Vector3(1.0, 0.08, 1.0), COLOR_AMBIENT, 3.0)

# ================================================================
# HELPERS
# ================================================================


# ================================================================
# FLOOR TILES — grid pattern overlay on the floor
# ================================================================
func _build_floor_tiles() -> void:
	var tile_size := 4.0
	var n: int = int(SIZE / tile_size)
	var tile_color_a := Color(0.24, 0.20, 0.16)
	var tile_color_b := Color(0.19, 0.16, 0.13)
	var gap_color := Color(0.08, 0.06, 0.05)
	for ix in range(n):
		for iz in range(n):
			var x: float = -HALF + tile_size * 0.5 + ix * tile_size
			var z: float = -HALF + tile_size * 0.5 + iz * tile_size
			var alt := (ix + iz) % 2 == 0
			var col: Color = tile_color_a if alt else tile_color_b
			_deco_box(Vector3(x, 0.015, z), Vector3(tile_size - 0.08, 0.03, tile_size - 0.08), col)
			# Thin seam
			_deco_box(Vector3(x, 0.005, z - tile_size * 0.5 + 0.04), Vector3(tile_size, 0.008, 0.04), gap_color)
			_deco_box(Vector3(x - tile_size * 0.5 + 0.04, 0.005, z), Vector3(0.04, 0.008, tile_size), gap_color)

# ================================================================
# WALL PATTERNS — recessed panels + vertical seams on interior walls
# ================================================================
func _build_wall_patterns() -> void:
	var panel_color := Color(0.20, 0.17, 0.14)
	var panel_dark := Color(0.10, 0.085, 0.07)
	var seam_color := Color(0.06, 0.05, 0.04)
	# Panels along outer shell walls
	var step := 4.0
	var half_inner := HALF - WALL_THICK
	# North + South wall panels
	for i in range(int(SIZE / step)):
		var x: float = -HALF + step * 0.5 + i * step
		# North
		_deco_box(Vector3(x, 2.0, -half_inner + 0.06), Vector3(step - 0.4, 3.2, 0.08), panel_color)
		_deco_box(Vector3(x, 5.6, -half_inner + 0.06), Vector3(step - 0.4, 1.4, 0.08), panel_dark)
		_deco_box(Vector3(x + step * 0.5, 4.0, -half_inner + 0.06), Vector3(0.06, 6.0, 0.10), seam_color)
		# South
		_deco_box(Vector3(x, 2.0, half_inner - 0.06), Vector3(step - 0.4, 3.2, 0.08), panel_color)
		_deco_box(Vector3(x, 5.6, half_inner - 0.06), Vector3(step - 0.4, 1.4, 0.08), panel_dark)
		_deco_box(Vector3(x + step * 0.5, 4.0, half_inner - 0.06), Vector3(0.06, 6.0, 0.10), seam_color)
	# East + West wall panels
	for i in range(int(SIZE / step)):
		var z: float = -HALF + step * 0.5 + i * step
		# West
		_deco_box(Vector3(-half_inner + 0.06, 2.0, z), Vector3(0.08, 3.2, step - 0.4), panel_color)
		_deco_box(Vector3(-half_inner + 0.06, 5.6, z), Vector3(0.08, 1.4, step - 0.4), panel_dark)
		_deco_box(Vector3(-half_inner + 0.06, 4.0, z + step * 0.5), Vector3(0.10, 6.0, 0.06), seam_color)
		# East
		_deco_box(Vector3(half_inner - 0.06, 2.0, z), Vector3(0.08, 3.2, step - 0.4), panel_color)
		_deco_box(Vector3(half_inner - 0.06, 5.6, z), Vector3(0.08, 1.4, step - 0.4), panel_dark)
		_deco_box(Vector3(half_inner - 0.06, 4.0, z + step * 0.5), Vector3(0.10, 6.0, 0.06), seam_color)

# ================================================================
# MADE BY DANNY — big glowing sign on the north wall
# ================================================================
func _build_made_by_danny() -> void:
	var tm := TextMesh.new()
	tm.text = "MADE BY DANNY"
	tm.font_size = 128
	tm.pixel_size = 0.042
	tm.depth = 0.20
	tm.curve_step = 0.5
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.90, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.metallic = 0.6
	mat.roughness = 0.25
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	var wall_z := -HALF + WALL_THICK + 0.20
	mi.position = Vector3(0, 4.5, wall_z)
	_parent.add_child(mi)
	# Accent bars above + below the sign
	_deco_box(Vector3(0, 5.9, wall_z), Vector3(14.0, 0.10, 0.14), Color(0.35, 0.90, 1.0))
	_deco_box(Vector3(0, 3.1, wall_z), Vector3(14.0, 0.10, 0.14), Color(0.35, 0.90, 1.0))
	# Spotlight over the sign
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.55, 0.92, 1.0)
	spot.light_energy = 4.0
	spot.spot_range = 16.0
	spot.spot_angle = 42.0
	spot.position = Vector3(0, 7.4, wall_z + 4.0)
	spot.rotation_degrees = Vector3(-40, 0, 0)
	_parent.add_child(spot)
	print("[arena] MADE BY DANNY sign installed on north wall")


func _wall(pos: Vector3, size: Vector3) -> void:
	_deco_box(pos, size, COLOR_WALL)
	_solid(pos, size)

func _solid(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	body.add_to_group("cover")
	_parent.add_child(body)

func _deco_box(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	mat.metallic = 0.25
	m.material_override = mat
	m.position = pos
	_parent.add_child(m)
	return m

func _emissive_box(pos: Vector3, size: Vector3, col: Color, energy: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	_parent.add_child(m)

func _crate(pos: Vector3, size: float) -> void:
	var full := pos + Vector3(0, size * 0.5, 0)
	_deco_box(full, Vector3(size, size, size), Color(0.42, 0.30, 0.18))
	_deco_box(full + Vector3(0, size * 0.5 + 0.02, 0), Vector3(size + 0.04, 0.06, size + 0.04), Color(0.55, 0.40, 0.22))
	_solid(full, Vector3(size, size, size))

func _pillar(pos: Vector3, radius: float, height: float) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.18)
	mat.roughness = 0.6
	mat.metallic = 0.4
	m.material_override = mat
	m.position = pos + Vector3(0, height * 0.5, 0)
	_parent.add_child(m)
	# Collision (square approximation of cylinder)
	_solid(pos + Vector3(0, height * 0.5, 0), Vector3(radius * 2.0, height, radius * 2.0))
