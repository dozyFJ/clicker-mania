extends Node3D

const SAVE_PATH := "user://save.json"
const LIVE_CONTENT_URL := "https://raw.githubusercontent.com/dozyFJ/clicker-mania/main/live_content.json"
const LIVE_CACHE_PATH := "user://live_content.json"
var coins_multiplier: int = 1
var xp_per_win: int = 25
var live_version: int = 0
const RELEASE_API := "https://api.github.com/repos/dozyFJ/clicker-mania/releases/tags/latest-apk"
const APK_URL := "https://github.com/dozyFJ/clicker-mania/releases/download/latest-apk/clicker-mania-debug.apk"
var coins: int = 0
var combo: int = 0
var last_tap: float = -100.0
var hero: Node3D
var camera: Camera3D
var score_label: Label
var combo_label: Label
var hint_label: Label
var animation_time: float = 0.0
var bounce: float = 0.0
var floaters: Array = []
var projectiles: Array = []
var enemy_hp: int = 100
var enemy_max_hp: int = 100
var enemy_level: int = 1
var damage: int = 5
var hp_label: Label
var spawn_serial: int = 0
var mob_name: String = ""
var mob_kind: int = 0
var model_parts: Array[MeshInstance3D] = []
var hit_flash: float = 0.0
var debris: Array = []
var random := RandomNumberGenerator.new()

func _ready() -> void:
	var splash := preload("res://splash.gd").new()
	add_child(splash)
	await get_tree().process_frame
	splash.set_progress(20, "ЗАГРУЗКА СОХРАНЕНИЯ")
	random.randomize()
	_load_game()
	_load_cached_content()
	await get_tree().process_frame
	splash.set_progress(55, "СОЗДАНИЕ МИРА")
	_setup_world()
	await get_tree().process_frame
	splash.set_progress(85, "ПОДГОТОВКА ИГРЫ")
	_setup_ui()
	_update_labels()
	await get_tree().process_frame
	splash.set_progress(100, "ГОТОВО!")
	await get_tree().create_timer(0.4).timeout
	var fade := create_tween()
	fade.tween_property(splash.get_child(0), "modulate:a", 0.0, 0.35)
	await fade.finished
	splash.queue_free()
	_check_live_content()
	_check_updates()

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c2940")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffffff")
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world.environment = env
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.05
	light.light_color = Color("#fff1dc")
	light.shadow_enabled = true
	add_child(light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-25, 140, 0)
	fill_light.light_energy = 0.45
	fill_light.light_color = Color("#a6caff")
	add_child(fill_light)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(0, 11.5, 8.0)
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	camera.current = true

	_build_arena()
	hero = Node3D.new()
	add_child(hero)
	_spawn_enemy()

func _atlas_box(pos: Vector3, size: Vector3, tile: int, tint: Color = Color.WHITE) -> void:
	var part := _add_box(self, pos, size, tint)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode diffuse_burley, cull_back; uniform sampler2D atlas_tex : source_color, filter_nearest; uniform vec4 tile_rect; uniform vec4 tint_color : source_color; void fragment() { vec2 uv = tile_rect.xy + fract(UV) * tile_rect.zw; ALBEDO = texture(atlas_tex, uv).rgb * tint_color.rgb; ROUGHNESS = 0.95; }"
	mat.shader = shader
	mat.set_shader_parameter("atlas_tex", load("res://arena_atlas.svg"))
	mat.set_shader_parameter("tile_rect", Vector4(float(tile % 4) / 4.0, float(tile / 4) / 2.0, 0.25, 0.5))
	mat.set_shader_parameter("tint_color", Vector4(tint.r, tint.g, tint.b, 1.0))
	part.material_override = mat

func _build_arena() -> void:
	# Layered ground and paved center, visible from the isometric camera.
	_atlas_box(Vector3(0, -0.37, 0), Vector3(11.5, 0.5, 11.5), 0)
	_atlas_box(Vector3(0, -0.09, 0), Vector3(5.3, 0.1, 5.3), 1)
	for i in range(-2, 3):
		_atlas_box(Vector3(float(i) * 1.02, -0.025, -2.68), Vector3(0.95, 0.06, 0.38), 2)
		_atlas_box(Vector3(float(i) * 1.02, -0.025, 2.68), Vector3(0.95, 0.06, 0.38), 2)
		_atlas_box(Vector3(-2.68, -0.025, float(i) * 1.02), Vector3(0.38, 0.06, 0.95), 2)
		_atlas_box(Vector3(2.68, -0.025, float(i) * 1.02), Vector3(0.38, 0.06, 0.95), 2)
	# Four corner towers, with battlements.
	for x in [-3.8, 3.8]:
		for z in [-3.8, 3.8]:
			_atlas_box(Vector3(x, 0.55, z), Vector3(1.0, 1.65, 1.0), 2)
			_atlas_box(Vector3(x, 1.48, z), Vector3(1.32, 0.26, 1.32), 3)
			for dx in [-0.48, 0.48]:
				for dz in [-0.48, 0.48]:
					_atlas_box(Vector3(x + dx, 1.78, z + dz), Vector3(0.25, 0.42, 0.25), 2)
	# Low boundary walls and entrances.
	for z in [-4.65, 4.65]:
		for x in [-2.5, -1.5, 1.5, 2.5]:
			_atlas_box(Vector3(x, 0.23, z), Vector3(0.96, 0.85, 0.4), 2)
	for x in [-4.65, 4.65]:
		for z in [-2.5, -1.5, 1.5, 2.5]:
			_atlas_box(Vector3(x, 0.23, z), Vector3(0.4, 0.85, 0.96), 2)
	# Trees, shrubs and crates frame the arena without blocking the enemy.
	for p in [Vector3(-4.8, 0, -2.8), Vector3(4.8, 0, 2.6), Vector3(-4.8, 0, 2.2), Vector3(4.8, 0, -2.5)]:
		_atlas_box(p + Vector3(0, 0.55, 0), Vector3(0.34, 1.65, 0.34), 6)
		_atlas_box(p + Vector3(0, 1.58, 0), Vector3(1.55, 1.35, 1.55), 4)
		_atlas_box(p + Vector3(0, 2.23, 0), Vector3(1.05, 0.55, 1.05), 7)
	for p in [Vector3(-3.2, 0, -1.5), Vector3(3.3, 0, 1.7), Vector3(-3.3, 0, 2.5), Vector3(3.2, 0, -2.1)]:
		_atlas_box(p + Vector3(0, 0.15, 0), Vector3(0.9, 0.65, 0.9), 4)
	for p in [Vector3(-3.25, 0, 0.5), Vector3(3.3, 0, -0.5)]:
		_atlas_box(p + Vector3(0, 0.28, 0), Vector3(0.75, 0.85, 0.75), 6)
		_atlas_box(p + Vector3(0, 0.74, 0), Vector3(0.82, 0.12, 0.82), 3)

func _add_box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.metallic = 0.0
	instance.material_override = mat
	parent.add_child(instance)
	return instance

# Adapted from WolfCraft's MobKind and blocky player models.
# Mob order: Ghoul, Crawler, Boar, Sheep, then six player skins.
func _spawn_enemy() -> void:
	for child in hero.get_children():
		child.queue_free()
	model_parts.clear()
	hero.scale = Vector3.ONE
	mob_kind = (enemy_level - 1) % 10
	var skin := Color("#ddb08c")
	var hair := Color("#342216")
	var jacket := Color("#1b8890")
	var pants := Color("#30354d")
	var eyes := Color("#ffdf4a")
	if mob_kind == 0:
		mob_name = "УПЫРЬ"
		skin = Color("#81a38a")
		hair = Color("#304535")
		jacket = Color("#66566e")
		pants = Color("#363f4c")
		eyes = Color("#ff4343")
	elif mob_kind == 1:
		mob_name = "ПОЛЗУН"
		skin = Color("#708b67")
		hair = Color("#273b31")
		jacket = Color("#475b44")
		pants = Color("#283c35")
		eyes = Color("#ff5757")
	elif mob_kind == 2:
		mob_name = "КАБАН"
		skin = Color("#8e634b")
		hair = Color("#50382d")
		eyes = Color("#18141b")
	elif mob_kind == 3:
		mob_name = "ОВЦА"
		skin = Color("#dfd5bd")
		hair = Color("#f5efe2")
		eyes = Color("#24232a")
	else:
		var skins := [
			[Color("#ddb08c"), Color("#342216"), Color("#1b8890"), Color("#30354d")],
			[Color("#ddb08c"), Color("#21120f"), Color("#bd2626"), Color("#34343d")],
			[Color("#c99a75"), Color("#59371a"), Color("#349b43"), Color("#443c29")],
			[Color("#eac2a3"), Color("#8c40ad"), Color("#8448bf"), Color("#272342")],
			[Color("#b48061"), Color("#d85a17"), Color("#f2a12d"), Color("#3a3947")],
			[Color("#8c6147"), Color("#17171d"), Color("#292936"), Color("#191a20")]
		]
		var palette: Array = skins[mob_kind - 4]
		skin = palette[0]
		hair = palette[1]
		jacket = palette[2]
		pants = palette[3]
		mob_name = "ЧЕЛОВЕК " + str(mob_kind - 3)
	if mob_kind == 2 or mob_kind == 3:
		# Four-legged voxel animals, modeled as boxes rather than sprites.
		_part(Vector3(0, 1.25, 0), Vector3(1.7, 1.05, 1.05), hair)
		_part(Vector3(0, 1.35, 0.78), Vector3(0.95, 0.95, 0.9), skin)
		for x in [-0.58, 0.58]:
			for z in [-0.33, 0.42]:
				_part(Vector3(x, 0.45, z), Vector3(0.38, 0.9, 0.38), skin)
		for x in [-0.27, 0.27]:
			_part(Vector3(x, 1.53, 1.28), Vector3(0.14, 0.14, 0.12), eyes)
		if mob_kind == 2:
			_part(Vector3(0, 1.1, 1.31), Vector3(0.52, 0.38, 0.24), Color("#b7826a"))
			_part(Vector3(-0.3, 1.95, 0.75), Vector3(0.3, 0.48, 0.3), skin)
			_part(Vector3(0.3, 1.95, 0.75), Vector3(0.3, 0.48, 0.3), skin)
		else:
			_part(Vector3(0, 1.92, 0), Vector3(1.65, 0.35, 1.0), hair)
	else:
		for x in [-0.36, 0.36]:
			_part(Vector3(x, 0.48, 0), Vector3(0.54, 0.95, 0.58), pants)
			_part(Vector3(x, 0.12, 0.17), Vector3(0.56, 0.22, 0.78), Color("#202635"))
		_part(Vector3(0, 1.42, 0), Vector3(1.3, 1.2, 0.72), jacket)
		_part(Vector3(0, 1.42, 0.38), Vector3(0.22, 0.86, 0.045), jacket.lightened(0.22))
		_part(Vector3(0, 1.93, 0), Vector3(0.34, 0.2, 0.3), skin)
		for x in [-0.92, 0.92]:
			_part(Vector3(x, 1.4, 0), Vector3(0.45, 0.8, 0.6), jacket)
			_part(Vector3(x, 0.92, 0), Vector3(0.43, 0.35, 0.55), skin)
		_part(Vector3(0, 2.36, 0), Vector3(1.1, 1.02, 0.88), skin)
		_part(Vector3(0, 2.93, 0), Vector3(1.19, 0.24, 0.95), hair)
		_part(Vector3(-0.52, 2.65, 0), Vector3(0.13, 0.52, 0.89), hair)
		_part(Vector3(0.52, 2.65, 0), Vector3(0.13, 0.52, 0.89), hair)
		_part(Vector3(0, 2.83, 0.47), Vector3(0.9, 0.18, 0.12), hair)
		for x in [-0.25, 0.25]:
			_part(Vector3(x, 2.46, 0.48), Vector3(0.13, 0.13, 0.08), eyes)
		_part(Vector3(0, 2.12, 0.48), Vector3(0.3, 0.09, 0.1), Color("#6b3537"))
		if mob_kind == 1:
			hero.scale = Vector3(1.0, 0.73, 1.1)
		else:
			hero.scale = Vector3.ONE

func _part(pos: Vector3, size: Vector3, color: Color) -> void:
	var part := _add_box(hero, pos, size, color)
	model_parts.append(part)

func _burst_enemy() -> void:
	var palette := [Color("#e7b977"), Color("#88a7d8"), Color("#dbe7ee")]
	for i in range(16):
		var cube := _add_box(self, hero.position + Vector3(random.randf_range(-0.7, 0.7), random.randf_range(0.5, 2.8), random.randf_range(-0.5, 0.5)), Vector3.ONE * random.randf_range(0.09, 0.22), palette[i % palette.size()])
		debris.append({"node": cube, "vel": Vector3(random.randf_range(-3.0, 3.0), random.randf_range(2.0, 5.0), random.randf_range(-2.0, 2.0)), "life": 0.9})

func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	score_label = Label.new()
	score_label.anchor_right = 1.0
	score_label.offset_top = 55
	score_label.offset_bottom = 130
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 48)
	root.add_child(score_label)

	combo_label = Label.new()
	combo_label.anchor_right = 1.0
	combo_label.offset_top = 150
	combo_label.offset_bottom = 215
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 36)
	root.add_child(combo_label)

	hp_label = Label.new()
	hp_label.anchor_right = 1.0
	hp_label.offset_top = 235
	hp_label.offset_bottom = 305
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 31)
	root.add_child(hp_label)

	hint_label = Label.new()
	hint_label.anchor_top = 0.75
	hint_label.anchor_bottom = 0.82
	hint_label.anchor_right = 1.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.text = "ТАПАЙ: КУРСОР АТАКУЕТ!"
	hint_label.add_theme_font_size_override("font_size", 28)
	root.add_child(hint_label)
	_build_bottom_menu(root)


var player_xp: int = 0
var player_level: int = 1
var menu_panel: PanelContainer
var menu_info: Label
var level_progress: ProgressBar
var level_text: Label

func _rounded_style(bg: Color, border: Color, radius: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func _ui_atlas_style(tile: int, margin: float = 34.0) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://ui_atlas.svg")
	atlas.region = Rect2((tile % 3) * 256, int(tile / 3) * 256, 256, 256)
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.draw_center = true
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _build_bottom_menu(root: Control) -> void:
	menu_panel = PanelContainer.new()
	menu_panel.anchor_left = 0.035
	menu_panel.anchor_right = 0.965
	menu_panel.anchor_top = 1.0
	menu_panel.anchor_bottom = 1.0
	menu_panel.offset_top = -176
	menu_panel.offset_bottom = -16
	menu_panel.add_theme_stylebox_override("panel", _ui_atlas_style(0, 28))
	root.add_child(menu_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	menu_panel.add_child(row)
	var xp_column := VBoxContainer.new()
	xp_column.custom_minimum_size = Vector2(145, 95)
	xp_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_column.alignment = BoxContainer.ALIGNMENT_CENTER
	xp_column.add_theme_constant_override("separation", 8)
	row.add_child(xp_column)
	level_text = Label.new()
	level_text.text = "УРОВЕНЬ 1"
	level_text.add_theme_font_size_override("font_size", 19)
	xp_column.add_child(level_text)
	level_progress = ProgressBar.new()
	level_progress.custom_minimum_size = Vector2(145, 22)
	level_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_progress.max_value = 100
	level_progress.show_percentage = false
	level_progress.add_theme_stylebox_override("fill", _ui_atlas_style(4, 18))
	level_progress.add_theme_stylebox_override("background", _ui_atlas_style(3, 18))
	xp_column.add_child(level_progress)
	var click_button := Button.new()
	click_button.text = "КЛИК"
	click_button.custom_minimum_size = Vector2(125, 125)
	click_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	click_button.add_theme_font_size_override("font_size", 25)
	click_button.add_theme_color_override("font_color", Color.WHITE)
	click_button.add_theme_stylebox_override("normal", _ui_atlas_style(1, 30))
	click_button.add_theme_stylebox_override("hover", _ui_atlas_style(1, 30))
	click_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	click_button.add_theme_stylebox_override("pressed", _ui_atlas_style(5, 30))
	click_button.pressed.connect(func() -> void: _tap(get_viewport().get_visible_rect().size * 0.5))
	row.add_child(click_button)
	var pets_button := Button.new()
	pets_button.text = "ПИТОМЦЫ"
	pets_button.custom_minimum_size = Vector2(165, 78)
	pets_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pets_button.add_theme_font_size_override("font_size", 19)
	pets_button.add_theme_color_override("font_color", Color.WHITE)
	pets_button.add_theme_stylebox_override("normal", _ui_atlas_style(2, 58))
	pets_button.add_theme_stylebox_override("hover", _ui_atlas_style(2, 58))
	pets_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pets_button.add_theme_stylebox_override("pressed", _ui_atlas_style(0, 58))
	pets_button.pressed.connect(_open_menu.bind(1))
	row.add_child(pets_button)
	menu_info = Label.new()
	menu_info.visible = false
	root.add_child(menu_info)
	_update_player_level()

func _open_menu(tab: int) -> void:
	match tab:
		0:
			menu_info.text = "⚡ ТАПАЙ ПО АРЕНЕ И ПОБЕЖДАЙ!"
		1:
			menu_info.text = "🐾 ПЕТЫ — СКОРО"
		2:
			menu_info.text = "🃏 КАРТЫ — СКОРО"
		3:
			menu_info.text = "🎒 ИНВЕНТАРЬ — СКОРО"

func _update_player_level() -> void:
	if level_progress == null:
		return
	player_level = 1 + int(player_xp / 100)
	level_text.text = "⭐ УРОВЕНЬ " + str(player_level)
	level_progress.value = player_xp % 100

func _unhandled_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not event.pressed:
			return
		pos = event.position
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		# Android generates a mouse event from a touch; avoid double attacks.
		if OS.has_feature("mobile"):
			return
		pos = event.position
	else:
		return
	_tap(pos)

func _tap(pos: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	combo = combo + 1 if now - last_tap < 0.8 else 1
	last_tap = now
	var multiplier := mini(10, 1 + combo / 5)
	spawn_serial += 1
	# Cursor projectile is rendered as a small 3D voxel pointer.
	var pointer := Node3D.new()
	add_child(pointer)
	var start_x := clampf((pos.x / get_viewport().get_visible_rect().size.x - 0.5) * 5.0, -2.5, 2.5)
	var start_y := clampf((1.0 - pos.y / get_viewport().get_visible_rect().size.y) * 3.0, 0.5, 3.5)
	pointer.position = Vector3(start_x, start_y, 4.0)
	var white := Color("#fff7dc")
	_add_box(pointer, Vector3(0, 0, 0), Vector3(0.18, 0.42, 0.12), white)
	_add_box(pointer, Vector3(0.16, -0.18, 0), Vector3(0.32, 0.14, 0.12), white)
	_add_box(pointer, Vector3(0.28, -0.32, 0), Vector3(0.12, 0.2, 0.12), Color("#ffcb4a"))
	projectiles.append({"node": pointer, "age": 0.0, "damage": damage * multiplier, "screen": pos})
	_update_labels()

func _hit_enemy(amount: int, pos: Vector2) -> void:
	enemy_hp -= amount
	bounce = 0.24
	hit_flash = 0.16
	_float_text(pos, "-" + str(amount) + " HP")
	if enemy_hp <= 0:
		coins += 10 * enemy_level * coins_multiplier
		player_xp += xp_per_win
		_update_player_level()
		_float_text(Vector2(get_viewport().get_visible_rect().size.x * 0.5, 350), "+ " + str(10 * enemy_level) + " coins")
		enemy_level += 1
		enemy_max_hp = 100 + (enemy_level - 1) * 45
		enemy_hp = enemy_max_hp
		_burst_enemy()
		_spawn_enemy()
		_save_game()
	_update_labels()

func _float_text(pos: Vector2, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color("#ffe66d"))
	label.position = pos
	get_tree().root.add_child(label)
	floaters.append({"node": label, "age": 0.0})

func _process(delta: float) -> void:
	if update_request != null and update_progress != null:
		var total := update_request.get_body_size()
		if total > 0:
			update_progress.value = clampf(100.0 * float(update_request.get_downloaded_bytes()) / float(total), 0.0, 99.0)
	for projectile in projectiles.duplicate():
		projectile["age"] += delta
		var progress: float = minf(1.0, projectile["age"] / 0.23)
		projectile["node"].position = projectile["node"].position.lerp(Vector3(0, 1.65, 0.75), minf(1.0, delta * 18.0))
		projectile["node"].rotation.z += delta * 9.0
		if progress >= 1.0:
			_hit_enemy(projectile["damage"], projectile["screen"])
			projectile["node"].queue_free()
			projectiles.erase(projectile)
	for particle in debris.duplicate():
		particle["life"] -= delta
		var velocity: Vector3 = particle["vel"]
		velocity.y -= 13.0 * delta
		particle["vel"] = velocity
		particle["node"].position += velocity * delta
		if particle["life"] <= 0.0:
			particle["node"].queue_free()
			debris.erase(particle)
	hit_flash = maxf(0.0, hit_flash - delta)
	for part in model_parts:
		if is_instance_valid(part):
			part.transparency = 0.35 if hit_flash > 0.0 else 0.0
	animation_time += delta
	bounce = maxf(0.0, bounce - delta * 1.7)
	hero.position.y = sin(animation_time * 1.8) * 0.05 + bounce
	hero.rotation.y = sin(animation_time * 0.7) * 0.035
	hero.rotation.z = 0.0
	if combo > 0 and Time.get_ticks_msec() / 1000.0 - last_tap > 1.2:
		combo = 0
		_update_labels()
	for item in floaters.duplicate():
		item.age += delta
		item.node.position.y -= delta * 110.0
		item.node.modulate.a = 1.0 - item.age / 0.75
		if item.age >= 0.75:
			item.node.queue_free()
			floaters.erase(item)

func _update_labels() -> void:
	score_label.text = "🪙 " + str(coins)
	var multiplier := mini(10, 1 + combo / 5)
	combo_label.text = "КОМБО x" + str(multiplier) + "  (" + str(combo) + ")"
	if hp_label:
		hp_label.text = mob_name + " Lv." + str(enemy_level) + " | HP " + str(enemy_hp) + "/" + str(enemy_max_hp) + " | DMG " + str(damage * multiplier)

func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"coins": coins, "enemy_level": enemy_level, "enemy_hp": enemy_hp, "player_xp": player_xp}))

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		coins = maxi(0, int(parsed.get("coins", 0)))
		player_xp = maxi(0, int(parsed.get("player_xp", 0)))
		enemy_level = maxi(1, int(parsed.get("enemy_level", 1)))
		enemy_max_hp = 100 + (enemy_level - 1) * 45
		enemy_hp = clampi(int(parsed.get("enemy_hp", enemy_max_hp)), 1, enemy_max_hp)

func _check_updates() -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if response_code == 200:
			var release = JSON.parse_string(body.get_string_from_utf8())
			if release is Dictionary:
				var published_sha := str(release.get("body", ""))
				var installed_sha := ""
				if FileAccess.file_exists("res://build_sha.txt"):
					installed_sha = FileAccess.get_file_as_string("res://build_sha.txt").strip_edges()
				if installed_sha != "" and not published_sha.contains(installed_sha):
					_show_update_dialog()
		request.queue_free()
	)
	request.request(RELEASE_API, ["User-Agent: ClickerMania"])

func _show_update_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "ОБНОВЛЕНИЕ CLICKER MANIA"
	dialog.dialog_text = "Доступна новая версия игры! Скачать APK?"
	dialog.ok_button_text = "СКАЧАТЬ"
	dialog.cancel_button_text = "ПОЗЖЕ"
	add_child(dialog)
	dialog.confirmed.connect(_download_update)
	dialog.popup_centered()

var update_request: HTTPRequest
var update_dialog: AcceptDialog
var update_progress: ProgressBar

func _download_update() -> void:
	if update_request != null:
		return
	update_dialog = AcceptDialog.new()
	update_dialog.title = "ЗАГРУЗКА ОБНОВЛЕНИЯ"
	update_dialog.dialog_text = "Скачиваем новую версию APK..."
	update_dialog.ok_button_text = "В ФОНЕ"
	add_child(update_dialog)
	update_progress = ProgressBar.new()
	update_progress.custom_minimum_size = Vector2(400, 28)
	update_progress.max_value = 100
	update_progress.show_percentage = true
	update_dialog.add_child(update_progress)
	update_dialog.popup_centered(Vector2i(540, 220))
	update_request = HTTPRequest.new()
	update_request.download_file = "user://clicker-mania-update.apk"
	add_child(update_request)
	update_request.request_completed.connect(_on_update_downloaded)
	var err := update_request.request(APK_URL, ["User-Agent: ClickerMania"])
	if err != OK:
		_finish_update_download(false)

func _on_update_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_finish_update_download(result == HTTPRequest.RESULT_SUCCESS and code == 200)

func _finish_update_download(success: bool) -> void:
	if update_request != null:
		update_request.queue_free()
		update_request = null
	if update_dialog == null:
		return
	if success:
		update_progress.value = 100
		update_dialog.dialog_text = "APK загружен. Для установки Android потребуется подтверждение. Откройте страницу загрузки и установите обновление, затем перезапустите игру."
		update_dialog.ok_button_text = "ОТКРЫТЬ УСТАНОВКУ"
		update_dialog.confirmed.connect(func() -> void: OS.shell_open(APK_URL), CONNECT_ONE_SHOT)
	else:
		update_dialog.dialog_text = "Не удалось скачать обновление. Проверьте интернет и повторите попытку."
		update_dialog.ok_button_text = "ЗАКРЫТЬ"


func _load_cached_content() -> void:
	if FileAccess.file_exists(LIVE_CACHE_PATH):
		var cached = JSON.parse_string(FileAccess.get_file_as_string(LIVE_CACHE_PATH))
		if cached is Dictionary:
			_apply_live_content(cached)

func _check_live_content() -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 12.0
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload is Dictionary and int(payload.get("content_version", 0)) >= live_version:
				_apply_live_content(payload)
				var cache := FileAccess.open(LIVE_CACHE_PATH, FileAccess.WRITE)
				if cache:
					cache.store_string(JSON.stringify(payload))
		request.queue_free()
	)
	var err := request.request(LIVE_CONTENT_URL, ["User-Agent: ClickerMania"])
	if err != OK:
		request.queue_free()

func _apply_live_content(payload: Dictionary) -> void:
	live_version = maxi(live_version, int(payload.get("content_version", 0)))
	damage = clampi(int(payload.get("damage", damage)), 1, 100000)
	coins_multiplier = clampi(int(payload.get("coins_multiplier", coins_multiplier)), 1, 1000)
	xp_per_win = clampi(int(payload.get("xp_per_win", xp_per_win)), 1, 10000)
	if score_label != null:
		_update_labels()
