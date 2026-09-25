extends Area3D
class_name LootChest
const SFX := preload("res://sfx.gd")

# Danny's Shrine chest. One-time legendary reward. Safe zone inside.

const HEAL_AMOUNT := 40
var _opened := false
var _t := 0.0

func _ready() -> void:
	add_to_group("loot_chest")
	_build_visual()
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	# Chest body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.7, 0.8)
	body.mesh = bm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.08, 0.05)
	dark.metallic = 0.7
	dark.roughness = 0.4
	body.material_override = dark
	body.position = Vector3(0, 0.35, 0)
	add_child(body)
	# Gold trim — 4 edges
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.80, 0.25)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.78, 0.20)
	gold.emission_energy_multiplier = 2.5
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.metallic = 0.95
	var edges := [
		{"p": Vector3(0, 0.72, 0), "s": Vector3(1.22, 0.04, 0.82)},
		{"p": Vector3(0, 0.02, 0), "s": Vector3(1.22, 0.04, 0.82)},
	]
	for e in edges:
		var trim := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = e.s
		trim.mesh = tm
		trim.material_override = gold
		trim.position = e.p
		add_child(trim)
	# Glow light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.80, 0.30)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position = Vector3(0, 1.0, 0)
	add_child(light)
	# Collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.5, 1.5)
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	if _opened:
		return
	_t += delta
	# Gentle hover when near player (subtle bob)
	var y := 0.35 + sin(_t * 1.4) * 0.04
	for c in get_children():
		if c is MeshInstance3D:
			var p: Vector3 = (c as MeshInstance3D).position
			p.y = (c as MeshInstance3D).position.y + sin(_t * 1.4) * 0.0015
			(c as MeshInstance3D).position = p

func _on_body_entered(body: Node3D) -> void:
	if _opened:
		return
	if not body.is_in_group("player"):
		return
	_opened = true
	SFX.play("wave_clear", 0.0, 0.8)
	# Heal player
	if body.has_method("heal"):
		body.call("heal", HEAL_AMOUNT)
	# Spawn 2 Danny-tier loots
	var loot_script: Script = load("res://loot.gd")
	if loot_script != null:
		for i in range(2):
			var l := Area3D.new()
			l.set_script(loot_script)
			l.call("setup", 3)
			l.position = global_position + Vector3(0, 0.8, 0) + Vector3(cos(i * PI), 0, sin(i * PI)) * 1.2
			get_tree().current_scene.add_child(l)
	# Fade chest
	var tw := create_tween()
	tw.set_parallel(true)
	for c in get_children():
		if c is MeshInstance3D:
			var mat := (c as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tw.chain().tween_callback(queue_free)
