extends Node3D
const PlayerScript = preload("res://scripts/player.gd")
var player: CharacterBody3D
var message_label: Label
func _ready() -> void:
	_build_atmosphere()
	_build_landscape()
	_build_town()
	_build_dinosaur_herd()
	_build_player()
	_build_hud()
func _material(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	n.scale = scale
	n.rotation = rot
	parent.add_child(n)
	return n
func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, _material(color), pos, Vector3.ONE, rot)
func _sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 10
	return _mesh(parent, mesh, _material(color), pos, size)
func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, sides := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(parent, mesh, _material(color), pos)
func _build_atmosphere() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.28, 0.48)
	sky_mat.sky_horizon_color = Color(0.91, 0.57, 0.31)
	sky_mat.ground_bottom_color = Color(0.19, 0.12, 0.09)
	sky_mat.ground_horizon_color = Color(0.78, 0.47, 0.28)
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.63, 0.52)
	e.ambient_light_energy = 0.72
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.35
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -28, 0)
	sun.light_color = Color(1.0, 0.77, 0.54)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)
func _build_landscape() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(520, 520)
	ground.subdivide_width = 80
	ground.subdivide_depth = 80
	_mesh(self, ground, _material(Color(0.48, 0.29, 0.16)), Vector3.ZERO)
	for i in range(22):
		var angle := TAU * float(i) / 22.0
		var radius := randf_range(125.0, 190.0)
		var p := Vector3(cos(angle) * radius, randf_range(13.0, 25.0), sin(angle) * radius)
		_sphere(self, p, Vector3(randf_range(22, 42), randf_range(22, 42), randf_range(22, 42)), Color(0.43, 0.22, 0.15))
		_box(self, p + Vector3(0, 13, 0), Vector3(randf_range(18, 35), 5, randf_range(18, 35)), Color(0.58, 0.31, 0.2))
	for i in range(95):
		var p := Vector3(randf_range(-110, 110), 0.8, randf_range(-110, 110))
		if Vector2(p.x, p.z).length() > 23:
			_sphere(self, p, Vector3(randf_range(1, 3.5), randf_range(0.7, 2.0), randf_range(1, 3)), Color(0.45, 0.27, 0.18))
	for i in range(125):
		var p := Vector3(randf_range(-115, 115), 0, randf_range(-115, 115))
		if Vector2(p.x, p.z).length() > 20:
			var h := randf_range(1.3, 3.8)
			_cylinder(self, p + Vector3(0, h * 0.5, 0), 0.22, h, Color(0.18, 0.31, 0.19), 7)
			if i % 3 == 0:
				_cylinder(self, p + Vector3(0.42, h * 0.55, 0), 0.13, h * 0.38, Color(0.18, 0.31, 0.19), 7).rotation.z = -0.8
func _build_town() -> void:
	_box(self, Vector3(0, 0.025, 0), Vector3(19, 0.05, 110), Color(0.58, 0.36, 0.22))
	_build_building(Vector3(-12, 0, -12), "SALOON", Color(0.43, 0.18, 0.12), true)
	_build_building(Vector3(12, 0, -8), "GENERAL STORE", Color(0.55, 0.38, 0.22), false)
	_build_building(Vector3(-13, 0, 12), "SHERIFF", Color(0.36, 0.27, 0.19), false)
	_build_building(Vector3(13, 0, 16), "STABLES", Color(0.48, 0.31, 0.18), true)
	_build_building(Vector3(-30, 0, -3), "HOTEL", Color(0.5, 0.25, 0.17), false)
	_build_building(Vector3(31, 0, 7), "RAIL OFFICE", Color(0.42, 0.28, 0.2), false)
	for z in range(-45, 51, 15):
		_cylinder(self, Vector3(23, 4.2, z), 0.13, 8.4, Color(0.24, 0.15, 0.1), 7)
		_box(self, Vector3(23, 7.5, z), Vector3(2.4, 0.16, 0.18), Color(0.24, 0.15, 0.1))
	_cylinder(self, Vector3(39, 8, -22), 2.6, 6, Color(0.28, 0.22, 0.17), 12)
	_cylinder(self, Vector3(39, 12, -22), 3.1, 2.5, Color(0.35, 0.24, 0.17), 12)
	for x in [47.0, 50.0]:
		_box(self, Vector3(x, 0.16, -20), Vector3(0.18, 0.22, 125), Color(0.22, 0.22, 0.2))
	for z in range(-80, 41, 3):
		_box(self, Vector3(48.5, 0.08, z), Vector3(4.5, 0.15, 0.65), Color(0.25, 0.16, 0.1))
	_box(self, Vector3(49, 1.7, -30), Vector3(4.4, 2.4, 13), Color(0.12, 0.14, 0.15))
	_cylinder(self, Vector3(49, 3.6, -33), 1.05, 4.3, Color(0.09, 0.1, 0.11), 16)
	_cylinder(self, Vector3(49, 5.8, -33), 0.42, 1.2, Color(0.15, 0.15, 0.14), 12)
	for z in [-34, -28]:
		for x in [46.8, 51.2]:
			_cylinder(self, Vector3(x, 0.9, z), 0.9, 0.38, Color(0.07, 0.07, 0.07), 16).rotation.x = PI / 2
func _build_building(pos: Vector3, sign_text: String, wall: Color, porch: bool) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_box(root, Vector3(0, 2.1, 0), Vector3(10, 4.2, 7), wall)
	_box(root, Vector3(0, 4.45, 0), Vector3(11, 0.45, 8), Color(0.19, 0.12, 0.1))
	var roof := PrismMesh.new()
	roof.size = Vector3(11, 2.7, 8)
	_mesh(root, roof, _material(Color(0.24, 0.14, 0.11)), Vector3(0, 5.9, 0))
	_box(root, Vector3(0, 2.0, 3.57), Vector3(1.45, 2.8, 0.16), Color(0.16, 0.1, 0.07))
	for x in [-3.3, 3.3]:
		_box(root, Vector3(x, 2.1, 3.66), Vector3(1.25, 1.7, 0.18), Color(0.16, 0.29, 0.34))
		_box(root, Vector3(x, 2.1, 3.78), Vector3(1.4, 0.12, 0.12), Color(0.24, 0.15, 0.1))
	if porch:
		_box(root, Vector3(0, 1.7, 5.0), Vector3(11, 0.25, 3), Color(0.3, 0.2, 0.13))
		for x in [-4.7, 0, 4.7]:
			_cylinder(root, Vector3(x, 1.5, 6.2), 0.12, 3, Color(0.25, 0.16, 0.1), 8)
	var sign := Label3D.new()
	sign.text = sign_text
	sign.font_size = 42
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 4.0, 4.08)
	sign.rotation_degrees.y = 180
	sign.modulate = Color(1.0, 0.79, 0.48)
	root.add_child(sign)
func _build_dinosaur_herd() -> void:
	_make_triceratops(Vector3(-31, 0, -52), 1.0, 0.0)
	_make_triceratops(Vector3(-39, 0, -59), 0.78, 0.45)
	_make_triceratops(Vector3(-23, 0, -62), 0.66, -0.3)
	var rex := Node3D.new()
	rex.position = Vector3(70, 0, -112)
	rex.scale = Vector3(2.3, 2.3, 2.3)
	add_child(rex)
	_sphere(rex, Vector3(0, 2.5, 0), Vector3(1.4, 1.6, 2.6), Color(0.25, 0.19, 0.14))
	_sphere(rex, Vector3(0, 3.5, -1.8), Vector3(1.0, 0.9, 1.0), Color(0.25, 0.19, 0.14))
	for x in [-0.55, 0.55]:
		_cylinder(rex, Vector3(x, 0.9, 0.6), 0.22, 1.8, Color(0.22, 0.17, 0.13), 8)
func _make_triceratops(pos: Vector3, size: float, yaw: float) -> void:
	var d := Node3D.new()
	d.position = pos
	d.rotation.y = yaw
	d.scale = Vector3.ONE * size
	add_child(d)
	var hide := Color(0.43, 0.39, 0.25)
	var dark := Color(0.29, 0.27, 0.18)
	_sphere(d, Vector3(0, 1.55, 0), Vector3(1.35, 1.05, 2.1), hide)
	_sphere(d, Vector3(0, 1.45, -1.45), Vector3(1.0, 0.82, 0.95), hide)
	_sphere(d, Vector3(0, 1.55, -2.05), Vector3(1.12, 0.88, 0.4), dark)
	_sphere(d, Vector3(0, 2.1, -1.7), Vector3(1.25, 1.0, 0.22), Color(0.5, 0.43, 0.27))
	for x in [-0.48, 0.48]:
		var horn := _cylinder(d, Vector3(x, 2.45, -2.15), 0.06, 0.85, Color(0.82, 0.72, 0.51), 7)
		horn.rotation.x = -0.55
	var nose := _cylinder(d, Vector3(0, 2.1, -2.48), 0.07, 0.55, Color(0.85, 0.77, 0.59), 7)
	nose.rotation.x = -0.6
	for x in [-0.82, 0.82]:
		for z in [-0.72, 0.8]:
			_cylinder(d, Vector3(x, 0.58, z), 0.24, 1.1, dark, 9)
func _build_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.position = Vector3(0, 0.2, 38)
	add_child(player)
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 24)
	cross.add_theme_color_override("font_color", Color(1, 0.87, 0.65, 0.85))
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-7, -14)
	layer.add_child(cross)
	var title := Label.new()
	title.text = "D U S T   &   D I N O S A U R S     /     RED ROCK, ARIZONA — 1897"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.83, 0.62))
	title.position = Vector2(28, 22)
	layer.add_child(title)
	var help := Label.new()
	help.text = "WASD MOVE    SHIFT SPRINT    SPACE JUMP    E INTERACT    ESC RELEASE MOUSE"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.94, 0.86, 0.75, 0.8))
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(28, -38)
	layer.add_child(help)
	message_label = Label.new()
	message_label.text = "RED ROCK — THE FRONTIER NEVER SLEEPS"
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color(1, 0.78, 0.48))
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.position = Vector2(-220, -90)
	layer.add_child(message_label)
func _process(_delta: float) -> void:
	if is_instance_valid(player) and Input.is_action_just_pressed("interact"):
		message_label.text = "THE OLD WEST IS FULL OF SECRETS. KEEP YOUR EYES OPEN."
