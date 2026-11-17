extends Control

var game: Node3D
var page: PanelContainer
var capsule_hud: Control
var heading: Label
var body: VBoxContainer
var egg_button: Button
var egg_image: TextureRect
var egg_atlas: AtlasTexture
var feedback: Label
var egg_price := 100
var inventory: Array = []
var hatching := false
var current_pet := ""
var pet_names := ["ЛИСЁНОК", "КОТЁНОК", "ДРАКОНЧИК", "ЗАЙЧИК", "ВОЛЧОНОК"]
var pet_colors := [Color("#ffad51"), Color("#a8d9ff"), Color("#ae87ff"), Color("#ffb4db"), Color("#9ce3b5")]

func setup(main_game: Node3D) -> void:
	game = main_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dock_back := PanelContainer.new()
	dock_back.anchor_left = 0.015
	dock_back.anchor_right = 0.985
	dock_back.anchor_top = 1.0
	dock_back.anchor_bottom = 1.0
	dock_back.offset_top = -112
	dock_back.offset_bottom = -8
	dock_back.add_theme_stylebox_override("panel", _cartoon_style(0, 28))
	add_child(dock_back)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 7)
	dock_back.add_child(tabs)
	for entry in [["ИГРА", 0], ["КАПСУЛЫ", 1], ["УЛУЧШ.", 2], ["НАСТР.", 3]]:
		var btn := Button.new()
		btn.text = str(entry[0])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 78
		btn.add_theme_font_size_override("font_size", 19)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal", _cartoon_style(1 if int(entry[1]) == 0 else 2, 25))
		btn.add_theme_stylebox_override("pressed", _cartoon_style(5, 25))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(show_page.bind(int(entry[1])))
		tabs.add_child(btn)
	page = PanelContainer.new()
	page.anchor_left = 0.025
	page.anchor_right = 0.975
	page.anchor_top = 0.08
	page.anchor_bottom = 1.0
	page.offset_bottom = -128
	page.add_theme_stylebox_override("panel", _cartoon_style(0))
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(page)
	move_child(page, 0)
	body = VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_theme_constant_override("separation", 24)
	page.add_child(body)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.custom_minimum_size.y = 100
	heading.add_theme_color_override("font_color", Color("#ffe49d"))
	body.add_child(heading)
	feedback = Label.new()
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 22)
	feedback.custom_minimum_size.y = 75
	feedback.add_theme_color_override("font_color", Color.WHITE)
	body.add_child(feedback)
	var egg_view := CenterContainer.new()
	egg_view.custom_minimum_size = Vector2(0, 370)
	body.add_child(egg_view)
	egg_button = Button.new()
	egg_button.text = ""
	egg_button.custom_minimum_size = Vector2(290, 340)
	egg_button.add_theme_font_size_override("font_size", 110)
	egg_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	egg_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	egg_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	egg_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	egg_button.pressed.connect(_buy_egg)
	egg_view.add_child(egg_button)
	egg_image = TextureRect.new()
	egg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	egg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	egg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	egg_atlas = AtlasTexture.new()
	egg_atlas.atlas = load("res://egg_pet_atlas.svg")
	egg_atlas.region = Rect2(0, 0, 256, 256)
	egg_image.texture = egg_atlas
	egg_button.add_child(egg_image)
	var action := Button.new()
	action.name = "Action"
	action.text = "КУПИТЬ ЯЙЦО"
	action.custom_minimum_size = Vector2(0, 95)
	action.add_theme_font_size_override("font_size", 29)
	action.add_theme_stylebox_override("normal", _cartoon_style(4, 25))
	action.pressed.connect(_buy_egg)
	body.add_child(action)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	capsule_hud = Control.new()
	capsule_hud.anchor_left = 0.05
	capsule_hud.anchor_right = 0.95
	capsule_hud.anchor_top = 0.68
	capsule_hud.anchor_bottom = 1.0
	capsule_hud.offset_bottom = -128
	add_child(capsule_hud)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 9)
	capsule_hud.add_child(grid)
	for i in range(3):
		var tile := Button.new()
		tile.text = ["МАГИЯ\\n100 МОНЕТ", "ЛЁД\\n100 МОНЕТ", "ОГОНЬ\\n100 МОНЕТ"][i].replace("\\n", "\n")
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.add_theme_font_size_override("font_size", 21)
		tile.add_theme_stylebox_override("normal", _cartoon_style(2 if i == 0 else 1, 24))
		tile.add_theme_stylebox_override("pressed", _cartoon_style(5, 24))
		tile.pressed.connect(_buy_egg)
		grid.add_child(tile)
	_load_inventory()
	show_page(0)

func _cartoon_style(tile: int, margin: float = 30.0) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://ui_atlas.svg")
	atlas.region = Rect2((tile % 3) * 256, int(tile / 3) * 256, 256, 256)
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(5)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func show_page(tab: int) -> void:
	var home := tab == 0
	page.visible = tab == 2 or tab == 3
	capsule_hud.visible = tab == 1
	game.set_capsule_scene(tab == 1)
	game.score_label.visible = home
	game.combo_label.visible = home
	game.hp_label.visible = home
	game.hint_label.visible = home
	game.menu_panel.visible = home
	mouse_filter = Control.MOUSE_FILTER_IGNORE if home else Control.MOUSE_FILTER_PASS
	if home:
		return
	egg_button.visible = false
	body.get_node("Action").visible = false
	if tab == 1:
		heading.text = "КАПСУЛЫ ПИТОМЦЕВ"
		feedback.text = "100 МОНЕТ • НАЖМИ НА ЯЙЦО"
	elif tab == 2:
		heading.text = "УЛУЧШЕНИЯ"
		feedback.text = "УРОН: " + str(game.damage) + "\nМОHЕТЫ: " + str(game.coins) + "\nПИТОМЦЫ: " + str(inventory.size())
	else:
		heading.text = "НАСТРОЙКИ"
		feedback.text = "CLICKER MANIA\nЗВУК И ГРАФИКА\nСКОРО"

func _buy_egg() -> void:
	if hatching:
		return
	if game.coins < egg_price:
		feedback.text = "НЕДОСТАТОЧНО МОНЕТ!"
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "КАПСУЛА ПИТОМЦА"
	dialog.dialog_text = "Купить яйцо за 100 монет?"
	dialog.ok_button_text = "ДА, КУПИТЬ"
	dialog.cancel_button_text = "НЕТ"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if game.coins >= egg_price:
			game.coins -= egg_price
			game._update_labels()
			game._save_game()
			_hatch()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()

func _hatch() -> void:
	hatching = true
	feedback.text = "ЯЙЦО ТРЯСЁТСЯ..."
	egg_button.disabled = true
	for i in range(8):
		var tween := create_tween()
		tween.tween_property(egg_button, "rotation", 0.16 if i % 2 == 0 else -0.16, 0.09)
		await tween.finished
	egg_button.rotation = 0.0
	var index := randi_range(0, pet_names.size() - 1)
	current_pet = pet_names[index]
	egg_atlas.region = Rect2(256, 0, 256, 256)
	egg_image.modulate = pet_colors[index]
	feedback.text = "ВЫЛУПИЛСЯ: " + current_pet
	var dialog := AcceptDialog.new()
	dialog.title = "НОВЫЙ ПИТОМЕЦ!"
	dialog.dialog_text = current_pet + "\nДобавить в инвентарь?"
	dialog.ok_button_text = "ПРИНЯТЬ"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		inventory.append(current_pet)
		_save_inventory()
		egg_atlas.region = Rect2(0, 0, 256, 256)
		egg_image.modulate = Color.WHITE
		egg_button.disabled = false
		hatching = false
		feedback.text = "ПИТОМЕЦ В ИНВЕНТАРЕ!"
		dialog.queue_free()
	)
	dialog.popup_centered()

func _save_inventory() -> void:
	var file := FileAccess.open("user://pets.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(inventory))

func _load_inventory() -> void:
	if FileAccess.file_exists("user://pets.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://pets.json"))
		if data is Array:
			inventory = data
