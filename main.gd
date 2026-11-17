extends Node3D

const SAVE_PATH := "user://save.json"
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
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.randomize()
	_load_game()
	_setup_world()
	_setup_ui()
	_update_labels()

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#18253b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffffff")
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.7
	add_child(light)

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.5, 8.5)
	add_child(camera)
	camera.look_at(Vector3(0, 1.15, 0))
	camera.current = true

	_add_box(self, Vector3(0, -0.3, 0), Vector3(10, 0.5, 10), Color("#30455c"))
	_add_box(self, Vector3(0, -0.04, 0), Vector3(3.8, 0.12, 3.0), Color("#546f88"))
	hero = Node3D.new()
	add_child(hero)
	_make_old_man()

func _add_box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	instance.material_override = mat
	parent.add_child(instance)
	return instance

func _make_old_man() -> void:
	var pants := Color("#3a425f")
	var jacket := Color("#3a88ad")
	var skin := Color("#e4b08c")
	var hair := Color("#f2f1e8")
	_add_box(hero, Vector3(-0.36, 0.42, 0), Vector3(0.55, 0.85, 0.58), pants)
	_add_box(hero, Vector3(0.36, 0.42, 0), Vector3(0.55, 0.85, 0.58), pants)
	_add_box(hero, Vector3(0, 1.35, 0), Vector3(1.35, 1.25, 0.75), jacket)
	_add_box(hero, Vector3(-0.94, 1.34, 0), Vector3(0.46, 1.15, 0.65), jacket)
	_add_box(hero, Vector3(0.94, 1.34, 0), Vector3(0.46, 1.15, 0.65), jacket)
	_add_box(hero, Vector3(0, 2.35, 0), Vector3(1.13, 1.05, 0.9), skin)
	_add_box(hero, Vector3(0, 2.94, 0), Vector3(1.24, 0.25, 1.0), hair)
	_add_box(hero, Vector3(-0.46, 2.6, 0), Vector3(0.17, 0.65, 0.95), hair)
	_add_box(hero, Vector3(0.46, 2.6, 0), Vector3(0.17, 0.65, 0.95), hair)
	_add_box(hero, Vector3(-0.24, 2.46, 0.48), Vector3(0.12, 0.12, 0.08), Color("#1b2435"))
	_add_box(hero, Vector3(0.24, 2.46, 0.48), Vector3(0.12, 0.12, 0.08), Color("#1b2435"))
	_add_box(hero, Vector3(0, 2.18, 0.53), Vector3(0.22, 0.2, 0.17), skin)
	_add_box(hero, Vector3(0, 1.96, 0.49), Vector3(0.65, 0.18, 0.12), hair)
	var collider := StaticBody3D.new()
	hero.add_child(collider)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 3.2, 1.4)
	shape.shape = box
	shape.position = Vector3(0, 1.55, 0)
	collider.add_child(shape)

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

	hint_label = Label.new()
	hint_label.anchor_top = 0.85
	hint_label.anchor_bottom = 0.95
	hint_label.anchor_right = 1.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.text = "ТАПАЙ ПО СТАРИКУ!"
	hint_label.add_theme_font_size_override("font_size", 28)
	root.add_child(hint_label)

func _unhandled_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not event.pressed:
			return
		pos = event.position
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = event.position
	else:
		return
	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hero.is_ancestor_of(hit.collider):
		_tap(pos)

func _tap(pos: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	combo = combo + 1 if now - last_tap < 0.8 else 1
	last_tap = now
	var multiplier := mini(10, 1 + combo / 5)
	coins += multiplier
	bounce = 0.22
	_update_labels()
	_float_text(pos, "+" + str(multiplier))
	_save_game()

func _float_text(pos: Vector2, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color("#ffe66d"))
	label.position = pos
	get_tree().root.add_child(label)
	floaters.append({"node": label, "age": 0.0})

func _process(delta: float) -> void:
	animation_time += delta
	bounce = maxf(0.0, bounce - delta * 1.7)
	hero.position.y = sin(animation_time * 1.8) * 0.05 + bounce
	hero.rotation.y = sin(animation_time * 0.7) * 0.08
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

func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"coins": coins}))

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		coins = maxi(0, int(parsed.get("coins", 0)))
