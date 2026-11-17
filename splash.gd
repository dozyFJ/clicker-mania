extends CanvasLayer

var bar: ProgressBar
var status: Label

func _ready() -> void:
	layer = 100
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("#101a30")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := VBoxContainer.new()
	center.anchor_left = 0.07
	center.anchor_right = 0.93
	center.anchor_top = 0.30
	center.anchor_bottom = 0.73
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 22)
	root.add_child(center)
	var symbol := Label.new()
	symbol.text = "◆"
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.add_theme_font_size_override("font_size", 110)
	symbol.add_theme_color_override("font_color", Color("#55dcff"))
	center.add_child(symbol)
	var logo := Label.new()
	logo.text = "CLICKER MANIA"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 52)
	logo.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(logo)
	var tagline := Label.new()
	tagline.text = "ВОКСЕЛЬНЫЙ МИР"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 23)
	tagline.add_theme_color_override("font_color", Color("#91a7c7"))
	center.add_child(tagline)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#55dcff")
	fill.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#283851")
	track.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("background", track)
	center.add_child(bar)
	status = Label.new()
	status.text = "ЗАПУСК... 0%"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color("#c9d8ef"))
	center.add_child(status)

func set_progress(value: float, label: String) -> void:
	bar.value = value
	status.text = label + "  " + str(int(value)) + "%"
