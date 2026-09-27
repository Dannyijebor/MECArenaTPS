extends CanvasLayer
class_name LoadingScreen

signal finished

var _progress: float = 0.0
var _total_time: float = 2.6
var _bar: ColorRect = null
var _label: Label = null
var _bg_rect: TextureRect = null
var _bar_width: float = 500.0

func _ready() -> void:
	layer = 210
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	# Nebula background image (cover, stretched to fill)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex: Texture2D = load("res://assets/load_bg.png")
	if tex != null:
		bg.texture = tex
	else:
		print("[loading] load_bg.png not found — using fallback color")
		var fallback := ColorRect.new()
		fallback.color = Color(0.02, 0.015, 0.03)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fallback)
	add_child(bg)
	_bg_rect = bg
	# Dark overlay so text is readable over the image
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.01, 0.05, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	# Top vignette
	var vignette_top := ColorRect.new()
	vignette_top.color = Color(0, 0, 0, 0.55)
	vignette_top.anchor_right = 1.0
	vignette_top.anchor_bottom = 0.25
	add_child(vignette_top)
	# Bottom vignette
	var vignette_bottom := ColorRect.new()
	vignette_bottom.color = Color(0, 0, 0, 0.65)
	vignette_bottom.anchor_left = 0.0
	vignette_bottom.anchor_right = 1.0
	vignette_bottom.anchor_top = 0.75
	vignette_bottom.anchor_bottom = 1.0
	add_child(vignette_bottom)
	# Title
	var title := Label.new()
	title.text = "RESONANCE"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.12))
	title.add_theme_constant_override("outline_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.offset_left = 0.0
	title.offset_right = 0.0
	title.offset_top = 200.0
	title.offset_bottom = 280.0
	title.name = "Title"
	add_child(title)
	# Subtitle
	var sub := Label.new()
	sub.text = "THE DANYA PROTOCOL"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.80, 0.92, 1.0))
	sub.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.12))
	sub.add_theme_constant_override("outline_size", 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.anchor_top = 0.0
	sub.anchor_bottom = 0.0
	sub.offset_left = 0.0
	sub.offset_right = 0.0
	sub.offset_top = 285.0
	sub.offset_bottom = 315.0
	add_child(sub)
	# Bar background
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bar_bg.custom_minimum_size = Vector2(_bar_width, 14)
	bar_bg.anchor_left = 0.5
	bar_bg.anchor_right = 0.5
	bar_bg.anchor_top = 0.5
	bar_bg.anchor_bottom = 0.5
	bar_bg.offset_left = -_bar_width * 0.5
	bar_bg.offset_right = _bar_width * 0.5
	bar_bg.offset_top = -7.0
	bar_bg.offset_bottom = 7.0
	add_child(bar_bg)
	# Bar fill
	_bar = ColorRect.new()
	_bar.color = Color(0.35, 0.90, 1.0)
	_bar.custom_minimum_size = Vector2(_bar_width, 10)
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 0.5
	_bar.anchor_bottom = 0.5
	_bar.offset_left = -_bar_width * 0.5 + 2.0
	_bar.offset_right = _bar_width * 0.5 - 2.0
	_bar.offset_top = -5.0
	_bar.offset_bottom = 5.0
	_bar.scale.x = 0.0
	add_child(_bar)
	# Loading label
	_label = Label.new()
	_label.text = "LOADING SECTOR 7... 0%"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.12))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = 0.0
	_label.offset_right = 0.0
	_label.offset_top = 400.0
	_label.offset_bottom = 428.0
	add_child(_label)
	# Bottom tag
	var tag := Label.new()
	tag.text = "MADE BY DANNY"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 0.9))
	tag.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.12))
	tag.add_theme_constant_override("outline_size", 4)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.anchor_left = 0.0
	tag.anchor_right = 1.0
	tag.anchor_top = 1.0
	tag.anchor_bottom = 1.0
	tag.offset_left = 0.0
	tag.offset_right = 0.0
	tag.offset_top = -60.0
	tag.offset_bottom = -30.0
	add_child(tag)

func _process(delta: float) -> void:
	if _progress >= 1.0:
		return
	_progress = min(_progress + delta / _total_time, 1.0)
	if _bar != null:
		_bar.scale.x = _progress
	if _label != null:
		_label.text = "LOADING SECTOR 7... " + str(int(_progress * 100.0)) + "%"
	if _progress >= 1.0:
		var t := get_tree().create_timer(0.4)
		t.timeout.connect(func() -> void:
			finished.emit()
		)
