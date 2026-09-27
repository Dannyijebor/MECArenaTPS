extends CanvasLayer
class_name Lobby

signal play_pressed
signal quit_pressed

# ============================================================
# SERIOUS MILITARY UI — single accent color
# ============================================================
const ACCENT := Color(0.20, 0.75, 0.95)
const ACCENT_DIM := Color(0.20, 0.75, 0.95, 0.35)
const ACCENT_GLOW := Color(0.35, 0.85, 1.0, 0.55)
const BG_DARK := Color(0.03, 0.04, 0.06)
const BG_OVERLAY := Color(0.03, 0.04, 0.06, 0.72)
const TEXT_PRIMARY := Color(0.95, 0.97, 1.0)
const TEXT_DIM := Color(0.68, 0.74, 0.84)
const TEXT_FAINT := Color(0.42, 0.48, 0.58)
const BORDER := Color(0.20, 0.75, 0.95, 0.45)

# ============================================================
# STATE
# ============================================================
var _pages: Dictionary = {}
var _current_page: String = "main"
var _selected_mode: String = "SOLO"
var _selected_char: String = "SWAT"
var _char_index: int = 0

var _preview_container: SubViewportContainer = null
var _preview_viewport: SubViewport = null
var _preview_pivot: Node3D = null
var _preview_model: Node3D = null
var _preview_anim: AnimationPlayer = null
var _preview_ready: bool = false

var _char_name_label: Label = null
var _char_ability_label: Label = null
var _char_blurb_label: Label = null
var _dot_labels: Array = []

var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
const DRAG_THRESHOLD := 40.0

const CHAR_ORDER := ["SWAT", "AJ", "CH39", "MARIA", "HEAVY"]
const MODES := [
	{"id": "SOLO",   "label": "SOLO",          "desc": "Survive endless waves", "icon": "solo"},
	{"id": "1V1",    "label": "1 v 1",         "desc": "Duel another player", "icon": "1v1"},
	{"id": "SQUAD",  "label": "SQUAD",         "desc": "4 vs 4 team battle", "icon": "squad"},
	{"id": "BR",     "label": "BATTLE ROYALE", "desc": "Last one standing", "icon": "br"},
]

# ============================================================
# INIT
# ============================================================
func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_go_to_page("main")
	print("[lobby] ready")

func _build() -> void:
	_build_background()
	_build_pages()
	_build_preview()

# ============================================================
# BACKGROUND
# ============================================================
func _build_background() -> void:
	# Nebula texture if available
	var tex: Texture2D = load("res://assets/load_bg.png")
	if tex != null:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bg)
	else:
		var fb := ColorRect.new()
		fb.color = BG_DARK
		fb.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fb)
	# Dark overlay so text reads
	var ov := ColorRect.new()
	ov.color = BG_OVERLAY
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	# Top + bottom vignette bands
	var band_top := ColorRect.new()
	band_top.color = Color(0, 0, 0, 0.60)
	band_top.anchor_right = 1.0
	band_top.anchor_bottom = 0.14
	add_child(band_top)
	var band_bot := ColorRect.new()
	band_bot.color = Color(0, 0, 0, 0.65)
	band_bot.anchor_left = 0.0
	band_bot.anchor_right = 1.0
	band_bot.anchor_top = 0.86
	band_bot.anchor_bottom = 1.0
	add_child(band_bot)

# ============================================================
# PAGES
# ============================================================
func _build_pages() -> void:
	_pages["main"] = _make_main_page()
	_pages["mode"] = _make_mode_page()
	_pages["char"] = _make_char_page()
	for p in _pages.values():
		add_child(p)
		p.visible = false

func _go_to_page(name: String) -> void:
	if not _pages.has(name):
		return
	for k in _pages.keys():
		_pages[k].visible = (k == name)
	_current_page = name
	# Show character preview ONLY on character page
	if _preview_container != null:
		_preview_container.visible = (name == "char")
	if name == "char":
		_refresh_character_preview()

# ============================================================
# PAGE — MAIN MENU
# ============================================================
func _make_main_page() -> Control:
	var p := Control.new()
	p.name = "Page_Main"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Title block
	var title := _make_title("RESONANCE", 96, ACCENT)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.18
	title.anchor_bottom = 0.18
	title.offset_top = 0.0
	title.offset_bottom = 110.0
	p.add_child(title)
	var sub := _make_label("THE DANYA PROTOCOL", 22, TEXT_DIM)
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.anchor_top = 0.36
	sub.anchor_bottom = 0.36
	sub.offset_bottom = 30.0
	p.add_child(sub)
	var line := ColorRect.new()
	line.color = ACCENT_DIM
	line.anchor_left = 0.35
	line.anchor_right = 0.65
	line.anchor_top = 0.40
	line.anchor_bottom = 0.40
	line.offset_bottom = 2.0
	p.add_child(line)
	var sector := _make_label("SECTOR 7 - THE VAULT", 14, ACCENT)
	sector.anchor_left = 0.0
	sector.anchor_right = 1.0
	sector.anchor_top = 0.42
	sector.anchor_bottom = 0.42
	sector.offset_bottom = 24.0
	p.add_child(sector)
	# PLAY button (huge)
	var play_btn := _make_button("PLAY", 32, Vector2(340, 78))
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.55
	play_btn.anchor_bottom = 0.55
	play_btn.offset_left = -170.0
	play_btn.offset_right = 170.0
	play_btn.offset_top = 0.0
	play_btn.offset_bottom = 78.0
	play_btn.name = "Btn_Play"
	play_btn.pressed.connect(func() -> void: _go_to_page("mode"))
	p.add_child(play_btn)
	# QUIT button (smaller, below)
	var quit_btn := _make_button("QUIT", 20, Vector2(340, 52))
	quit_btn.anchor_left = 0.5
	quit_btn.anchor_right = 0.5
	quit_btn.anchor_top = 0.55
	quit_btn.anchor_bottom = 0.55
	quit_btn.offset_left = -170.0
	quit_btn.offset_right = 170.0
	quit_btn.offset_top = 100.0
	quit_btn.offset_bottom = 152.0
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit(); get_tree().quit())
	p.add_child(quit_btn)
	# Footer
	var foot := _make_label("MADE BY DANNY", 12, TEXT_FAINT)
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_top = -40.0
	foot.offset_bottom = -20.0
	p.add_child(foot)
	return p

# ============================================================
# PAGE — MODE SELECT
# ============================================================
func _make_mode_page() -> Control:
	var p := Control.new()
	p.name = "Page_Mode"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _make_title("SELECT MODE", 44, TEXT_PRIMARY)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.10
	title.anchor_bottom = 0.10
	title.offset_bottom = 60.0
	p.add_child(title)
	var subtitle := _make_label("CHOOSE YOUR ENGAGEMENT TYPE", 13, TEXT_FAINT)
	subtitle.anchor_left = 0.0
	subtitle.anchor_right = 1.0
	subtitle.anchor_top = 0.16
	subtitle.anchor_bottom = 0.16
	subtitle.offset_bottom = 22.0
	p.add_child(subtitle)
	# 4 mode cards horizontally
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.anchor_top = 0.5
	container.anchor_bottom = 0.5
	container.offset_left = -500.0
	container.offset_right = 500.0
	container.offset_top = -130.0
	container.offset_bottom = 130.0
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(container)
	for m in MODES:
		var card := _make_mode_card(m)
		container.add_child(card)
	# Back
	var back := _make_button("< BACK", 18, Vector2(160, 48))
	back.anchor_left = 0.0
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 40.0
	back.offset_right = 200.0
	back.offset_top = -100.0
	back.offset_bottom = -52.0
	back.pressed.connect(func() -> void: _go_to_page("main"))
	p.add_child(back)
	# Next
	var nxt := _make_button("NEXT >", 18, Vector2(200, 48))
	nxt.anchor_left = 1.0
	nxt.anchor_right = 1.0
	nxt.anchor_top = 1.0
	nxt.anchor_bottom = 1.0
	nxt.offset_left = -240.0
	nxt.offset_right = -40.0
	nxt.offset_top = -100.0
	nxt.offset_bottom = -52.0
	nxt.pressed.connect(func() -> void: _go_to_page("char"))
	p.add_child(nxt)
	return p

func _make_mode_card(m: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 260)
	card.text = ""
	card.name = "Card_" + String(m.id)
	card.toggle_mode = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.85)
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	sbh.border_color = ACCENT
	sbh.set_border_width_all(3)
	card.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.10, 0.22, 0.32, 0.95)
	sbp.border_color = ACCENT
	card.add_theme_stylebox_override("pressed", sbp)
	# Content
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_top = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12.0
	vbox.offset_right = -12.0
	vbox.offset_top = 20.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	var lbl := _make_label(String(m.label), 24, TEXT_PRIMARY)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)
	var sep := ColorRect.new()
	sep.color = ACCENT_DIM
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)
	var desc := _make_label(String(m.desc), 13, TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(180, 0)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc)
	card.pressed.connect(_on_mode_chosen.bind(String(m.id)))
	return card

func _on_mode_chosen(id: String) -> void:
	_selected_mode = id
	if NetworkManager != null:
		NetworkManager.game_mode = id
	print("[lobby] mode: ", id)
	_highlight_mode_card(id)

func _highlight_mode_card(id: String) -> void:
	var page: Node = _pages.get("mode")
	if page == null:
		return
	for m in MODES:
		var card: Node = page.find_child("Card_" + String(m.id), true, false)
		if card == null or not (card is Button):
			continue
		var sb: StyleBoxFlat = (card as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if sb == null:
			continue
		if String(m.id) == id:
			sb.bg_color = Color(0.10, 0.22, 0.32, 0.95)
			sb.border_color = ACCENT
		else:
			sb.bg_color = Color(0.05, 0.07, 0.10, 0.85)
			sb.border_color = BORDER

# ============================================================
# PAGE — CHARACTER SELECT
# ============================================================
func _make_char_page() -> Control:
	var p := Control.new()
	p.name = "Page_Char"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _make_title("SELECT OPERATIVE", 44, TEXT_PRIMARY)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.06
	title.anchor_bottom = 0.06
	title.offset_bottom = 60.0
	p.add_child(title)
	var subtitle := _make_label("EACH OPERATIVE HAS A UNIQUE ABILITY", 13, TEXT_FAINT)
	subtitle.anchor_left = 0.0
	subtitle.anchor_right = 1.0
	subtitle.anchor_top = 0.12
	subtitle.anchor_bottom = 0.12
	subtitle.offset_bottom = 22.0
	p.add_child(subtitle)
	# Left arrow
	var larr := _make_button("<", 42, Vector2(70, 90))
	larr.anchor_left = 0.0
	larr.anchor_top = 0.5
	larr.anchor_bottom = 0.5
	larr.offset_left = 40.0
	larr.offset_right = 110.0
	larr.offset_top = -45.0
	larr.offset_bottom = 45.0
	larr.pressed.connect(_on_prev_char)
	p.add_child(larr)
	# Right arrow
	var rarr := _make_button(">", 42, Vector2(70, 90))
	rarr.anchor_left = 1.0
	rarr.anchor_right = 1.0
	rarr.anchor_top = 0.5
	rarr.anchor_bottom = 0.5
	rarr.offset_left = -110.0
	rarr.offset_right = -40.0
	rarr.offset_top = -45.0
	rarr.offset_bottom = 45.0
	rarr.pressed.connect(_on_next_char)
	p.add_child(rarr)
	# Character name
	var nm := _make_title("VECTOR", 42, ACCENT)
	nm.anchor_left = 0.0
	nm.anchor_right = 1.0
	nm.anchor_top = 0.72
	nm.anchor_bottom = 0.72
	nm.offset_bottom = 48.0
	p.add_child(nm)
	_char_name_label = nm
	# Ability tag
	var ab := _make_label("FOCUS", 18, TEXT_PRIMARY)
	ab.anchor_left = 0.0
	ab.anchor_right = 1.0
	ab.anchor_top = 0.79
	ab.anchor_bottom = 0.79
	ab.offset_bottom = 26.0
	p.add_child(ab)
	_char_ability_label = ab
	# Blurb
	var bl := _make_label("Infinite ammo + faster fire", 14, TEXT_DIM)
	bl.anchor_left = 0.0
	bl.anchor_right = 1.0
	bl.anchor_top = 0.83
	bl.anchor_bottom = 0.83
	bl.offset_bottom = 22.0
	p.add_child(bl)
	_char_blurb_label = bl
	# Dot indicators
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 10)
	dots.anchor_left = 0.5
	dots.anchor_right = 0.5
	dots.anchor_top = 0.88
	dots.anchor_bottom = 0.88
	dots.offset_left = -80.0
	dots.offset_right = 80.0
	dots.offset_bottom = 14.0
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(dots)
	_dot_labels.clear()
	for i in range(CHAR_ORDER.size()):
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(22, 4)
		d.color = ACCENT_DIM
		dots.add_child(d)
		_dot_labels.append(d)
	# Back
	var back := _make_button("< BACK", 18, Vector2(160, 48))
	back.anchor_left = 0.0
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 40.0
	back.offset_right = 200.0
	back.offset_top = -100.0
	back.offset_bottom = -52.0
	back.pressed.connect(func() -> void: _go_to_page("mode"))
	p.add_child(back)
	# START
	var start := _make_button("DEPLOY >", 20, Vector2(240, 56))
	start.anchor_left = 1.0
	start.anchor_right = 1.0
	start.anchor_top = 1.0
	start.anchor_bottom = 1.0
	start.offset_left = -280.0
	start.offset_right = -40.0
	start.offset_top = -108.0
	start.offset_bottom = -52.0
	start.pressed.connect(_on_start)
	p.add_child(start)
	return p

func _on_prev_char() -> void:
	_char_index = (_char_index - 1 + CHAR_ORDER.size()) % CHAR_ORDER.size()
	_selected_char = CHAR_ORDER[_char_index]
	_refresh_character_preview()

func _on_next_char() -> void:
	_char_index = (_char_index + 1) % CHAR_ORDER.size()
	_selected_char = CHAR_ORDER[_char_index]
	_refresh_character_preview()

func _on_start() -> void:
	if NetworkManager != null:
		NetworkManager.selected_character = _selected_char
		NetworkManager.game_mode = _selected_mode
	print("[lobby] START  char=", _selected_char, "  mode=", _selected_mode)
	play_pressed.emit()

# ============================================================
# CHARACTER PREVIEW (SubViewport)
# ============================================================
func _build_preview() -> void:
	_preview_container = SubViewportContainer.new()
	_preview_container.custom_minimum_size = Vector2(360, 520)
	_preview_container.anchor_left = 0.5
	_preview_container.anchor_right = 0.5
	_preview_container.anchor_top = 0.5
	_preview_container.anchor_bottom = 0.5
	_preview_container.offset_left = -180.0
	_preview_container.offset_right = 180.0
	_preview_container.offset_top = -260.0
	_preview_container.offset_bottom = 260.0
	_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_container.stretch = true
	add_child(_preview_container)
	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(360, 520)
	_preview_viewport.transparent_bg = true
	_preview_viewport.own_world_3d = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_preview_viewport)
	# Camera
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 3.0)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 40.0
	cam.current = true
	_preview_viewport.add_child(cam)
	# Light
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-35, 45, 0)
	dl.light_energy = 1.3
	dl.light_color = Color(0.95, 0.97, 1.0)
	_preview_viewport.add_child(dl)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -140, 0)
	rim.light_energy = 0.9
	rim.light_color = ACCENT
	_preview_viewport.add_child(rim)
	# Environment (so materials look right)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.45, 0.55)
	env.ambient_light_energy = 0.7
	we.environment = env
	_preview_viewport.add_child(we)
	# Pivot rotates the character
	_preview_pivot = Node3D.new()
	_preview_viewport.add_child(_preview_pivot)
	_preview_ready = true

func _refresh_character_preview() -> void:
	if not _preview_ready:
		return
	# Clear old model
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
		_preview_model = null
	_preview_anim = null
	# Load new model
	var d: Dictionary = CharacterDB.get_data(_selected_char)
	var path: String = String(d.get("path", ""))
	if path == "":
		return
	var scn: PackedScene = load(path)
	if scn == null:
		print("[lobby] failed to load ", path)
		return
	var inst: Node3D = scn.instantiate()
	_preview_pivot.add_child(inst)
	_preview_model = inst
	# Auto-scale to 1.85m target height
	_autoscale_preview(inst)
	# Attach idle animation
	var skel: Skeleton3D = _find_biggest_skeleton(inst)
	if skel != null:
		var ap := AnimationPlayer.new()
		inst.add_child(ap)
		var rig: Script = load("res://anim_rig.gd")
		if rig != null:
			var ok: bool = rig.attach(ap, skel)
			if ok:
				_preview_anim = ap
				if ap.has_animation("mixamo/rifle_idle"):
					ap.play("mixamo/rifle_idle")
				elif ap.has_animation("mixamo/idle"):
					ap.play("mixamo/idle")
	# Update labels
	_update_char_labels(d)

func _autoscale_preview(root: Node3D) -> void:
	var aabb := _compute_aabb_recursive(root)
	if aabb.size.y < 0.01:
		return
	var target_h := 1.85
	var s: float = target_h / aabb.size.y
	root.scale = Vector3(s, s, s)
	root.position.y = -aabb.position.y * s

func _compute_aabb_recursive(n: Node) -> AABB:
	var total := AABB()
	var first := true
	var stack: Array = [n]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var local := mi.get_aabb()
			var world := mi.transform * local
			if first:
				total = world
				first = false
			else:
				total = total.merge(world)
		for c in node.get_children():
			stack.append(c)
	return total

func _find_biggest_skeleton(root: Node) -> Skeleton3D:
	var best: Skeleton3D = null
	var best_count: int = 0
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			var s := n as Skeleton3D
			if s.get_bone_count() > best_count:
				best_count = s.get_bone_count()
				best = s
		for c in n.get_children():
			stack.append(c)
	return best

func _update_char_labels(d: Dictionary) -> void:
	if _char_name_label != null:
		_char_name_label.text = String(d.get("label", "?"))
	if _char_ability_label != null:
		_char_ability_label.text = String(d.get("ability", ""))
	if _char_blurb_label != null:
		_char_blurb_label.text = String(d.get("ability_desc", d.get("blurb", "")))
	for i in range(_dot_labels.size()):
		var dot: ColorRect = _dot_labels[i]
		if i == _char_index:
			dot.color = ACCENT
		else:
			dot.color = ACCENT_DIM

# ============================================================
# UI BUILDERS
# ============================================================
func _make_title(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_button(text: String, size: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.11, 0.78)
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.08, 0.14, 0.20, 0.95)
	sbh.border_color = ACCENT
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.14, 0.30, 0.42, 1.0)
	sbp.border_color = ACCENT
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_color_override("font_color", TEXT_PRIMARY)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	return b

# ============================================================
# DRAG SWIPE (character page)
# ============================================================
func _input(event: InputEvent) -> void:
	if _current_page != "char":
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_drag_start = t.position
			_dragging = true
		else:
			if _dragging:
				var dx := t.position.x - _drag_start.x
				if abs(dx) > DRAG_THRESHOLD:
					if dx < 0:
						_on_next_char()
					else:
						_on_prev_char()
			_dragging = false

# ============================================================
# TICK
# ============================================================
func _process(delta: float) -> void:
	if _preview_pivot != null and _preview_model != null:
		_preview_pivot.rotate_y(delta * 0.6)
