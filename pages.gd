extends Control

var game: Node3D
var page: PanelContainer
var heading: Label
var body: VBoxContainer
var egg_button: Button
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
	var top := HBoxContainer.new()
	top.anchor_left = 0.05
	top.anchor_right = 0.95
	top.anchor_top = 0.012
	top.anchor_bottom = 0.09
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	for entry in [["⌂", 0], ["🥚 ЯЙЦА", 1], ["🐾 ПЕТЫ", 2]]:
		var btn := Button.new()
		btn.text = str(entry[0])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_stylebox_override("normal", _style(Color("#274a7b"), Color("#ffda79"), 26))
		btn.add_theme_stylebox_override("pressed", _style(Color("#156aa3"), Color("#ffffff"), 26))
		btn.pressed.connect(show_page.bind(int(entry[1])))
		top.add_child(btn)
	page = PanelContainer.new()
	page.anchor_left = 0.055
	page.anchor_right = 0.945
	page.anchor_top = 0.16
	page.anchor_bottom = 0.85
	page.add_theme_stylebox_override("panel", _style(Color("#192744"), Color("#e3bf70"), 32))
	add_child(page)
	body = VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 22)
	page.add_child(body)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 39)
	heading.add_theme_color_override("font_color", Color("#ffe49d"))
	body.add_child(heading)
	feedback = Label.new()
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 25)
	feedback.add_theme_color_override("font_color", Color.WHITE)
	body.add_child(feedback)
	var egg_view := CenterContainer.new()
	egg_view.custom_minimum_size = Vector2(0, 280)
	body.add_child(egg_view)
	egg_button = Button.new()
	egg_button.text = "🥚"
	egg_button.custom_minimum_size = Vector2(260, 260)
	egg_button.add_theme_font_size_override("font_size", 110)
	egg_button.add_theme_stylebox_override("normal", _style(Color("#4b7bc1"), Color("#c5edff"), 90))
	egg_button.pressed.connect(_buy_egg)
	egg_view.add_child(egg_button)
	var action := Button.new()
	action.name = "Action"
	action.text = "КУПИТЬ ЯЙЦО"
	action.custom_minimum_size = Vector2(0, 85)
	action.add_theme_font_size_override("font_size", 29)
	action.add_theme_stylebox_override("normal", _style(Color("#3aaf69"), Color("#d7ff9b"), 24))
	action.pressed.connect(_buy_egg)
	body.add_child(action)
	_load_inventory()
	show_page(0)

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
	page.visible = not home
	game.score_label.visible = home
	game.combo_label.visible = home
	game.hp_label.visible = home
	game.hint_label.visible = home
	game.menu_panel.visible = home
	mouse_filter = Control.MOUSE_FILTER_IGNORE if home else Control.MOUSE_FILTER_STOP
	if home:
		return
	egg_button.visible = tab == 1
	body.get_node("Action").visible = tab == 1
	if tab == 1:
		heading.text = "КАПСУЛЫ ПИТОМЦЕВ"
		feedback.text = "100 МОНЕТ • НАЖМИ НА ЯЙЦО"
	else:
		heading.text = "МОИ ПИТОМЦЫ"
		feedback.text = "ПОЛУЧЕНО: " + str(inventory.size())
		var labels := ""
		for pet in inventory:
			labels += "🐾 " + str(pet) + "    "
		if inventory.is_empty():
			labels = "ПОКА НЕТ ПИТОМЦЕВ"
		feedback.text += "\n" + labels

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
	egg_button.text = "🐾"
	egg_button.modulate = pet_colors[index]
	feedback.text = "ВЫЛУПИЛСЯ: " + current_pet
	var dialog := AcceptDialog.new()
	dialog.title = "НОВЫЙ ПИТОМЕЦ!"
	dialog.dialog_text = current_pet + "\nДобавить в инвентарь?"
	dialog.ok_button_text = "ПРИНЯТЬ"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		inventory.append(current_pet)
		_save_inventory()
		egg_button.text = "🥚"
		egg_button.modulate = Color.WHITE
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
