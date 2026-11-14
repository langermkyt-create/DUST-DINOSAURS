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
func _terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 world_position;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise2(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dune_shape = fbm(world_position.xz * 0.018);
	float wind_ripple = sin(dot(world_position.xz, vec2(0.72, 0.69)) * 1.35
		+ fbm(world_position.xz * 0.045) * 5.0);
	VERTEX.y += (dune_shape - 0.5) * 1.15 + wind_ripple * 0.035;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float broad = fbm(world_position.xz * 0.026);
	float grain = noise2(world_position.xz * 1.35);
	float flecks = noise2(world_position.xz * 8.5);
	float fine_grain = noise2(world_position.xz * 31.0);
	float wind_streak = sin(dot(world_position.xz, vec2(0.72, 0.69)) * 2.2
		+ noise2(world_position.xz * 0.12) * 3.0) * 0.5 + 0.5;
	vec3 dust = vec3(0.17, 0.095, 0.055);
	vec3 ochre = vec3(0.36, 0.205, 0.115);
	vec3 pale = vec3(0.52, 0.355, 0.22);
	vec3 ground = mix(dust, ochre, smoothstep(0.2, 0.8, broad));
	ground = mix(ground, pale, smoothstep(0.66, 0.92, grain) * 0.19);
	ground *= 0.91 + flecks * 0.14 + fine_grain * 0.045;
	ground *= 0.97 + wind_streak * 0.035;
	ALBEDO = ground;
	ROUGHNESS = 0.94 + fine_grain * 0.05;
	SPECULAR = 0.08;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

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
func _box(parent: Node3D, pos: Vector3, size: Vector3, surface: Variant, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material: Material
	if surface is Material:
		material = surface
	else:
		material = _material(surface as Color)
	return _mesh(parent, mesh, material, pos, Vector3.ONE, rot)
func _sphere(parent: Node3D, pos: Vector3, size: Vector3, surface: Variant) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 32
	mesh.rings = 20
	var material: Material
	if surface is Material:
		material = surface
	else:
		material = _material(surface as Color)
	return _mesh(parent, mesh, material, pos, size)
func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, sides := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	mesh.radial_segments = maxi(sides, 16)
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
	e.glow_intensity = 0.12
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.7
	e.sdfgi_enabled = true
	e.sdfgi_use_occlusion = true
	e.sdfgi_bounce_feedback = 0.72
	e.ssil_enabled = true
	e.ssil_intensity = 0.65
	e.fog_enabled = true
	e.fog_light_color = Color(0.78, 0.57, 0.39)
	e.fog_density = 0.0025
	e.fog_sun_scatter = 0.32
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.018
	e.volumetric_fog_albedo = Color(0.78, 0.61, 0.43)
	e.volumetric_fog_length = 220.0
	e.volumetric_fog_detail_spread = 2.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -28, 0)
	sun.light_color = Color(1.0, 0.77, 0.54)
	sun.light_energy = 1.65
	sun.light_angular_distance = 0.7
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 240.0
	add_child(sun)
func _build_landscape() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(520, 520)
	ground.subdivide_width = 220
	ground.subdivide_depth = 220
	var terrain := StaticBody3D.new()
	add_child(terrain)
	var ground_shape := CollisionShape3D.new()
	var ground_collision := BoxShape3D.new()
	ground_collision.size = Vector3(520, 1.0, 520)
	ground_shape.shape = ground_collision
	ground_shape.position.y = -0.5
	terrain.add_child(ground_shape)
	_mesh(self, ground, _terrain_material(), Vector3.ZERO)
	for i in range(34):
		var angle := TAU * float(i) / 34.0
		var radius := randf_range(125.0, 190.0)
		var p := Vector3(cos(angle) * radius, randf_range(13.0, 25.0), sin(angle) * radius)
		_rock_formation(p, randf_range(0.8, 1.5))
	_scatter_boulders()
	for i in range(260):
		var p := Vector3(randf_range(-115, 115), 0, randf_range(-115, 115))
		if Vector2(p.x, p.z).length() > 20:
			var h := randf_range(1.3, 3.8)
			_cylinder(self, p + Vector3(0, h * 0.5, 0), 0.22, h, Color(0.18, 0.31, 0.19), 7)
			if i % 3 == 0:
				var arm := _cylinder(self, p + Vector3(0.42, h * 0.55, 0), 0.13, h * 0.38, Color(0.18, 0.31, 0.19), 7)
				arm.rotation.z = -0.8

func _rock_formation(pos: Vector3, factor: float) -> void:
	# Build one continuous, faceted sandstone outcrop instead of a pile of cubes and spheres.
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(Vector2i(roundi(pos.x * 10.0), roundi(pos.z * 10.0))))
	var heights := [0.0, 2.2, 4.8, 7.1, 8.6]
	var radii := [8.8, 8.1, 6.9, 5.5, 3.8]
	var rings := []
	for layer in range(heights.size()):
		var ring := PackedVector3Array()
		for segment in range(12):
			var angle: float = TAU * float(segment) / 12.0 + rng.randf_range(-0.055, 0.055)
			var radius: float = float(radii[layer]) * rng.randf_range(0.88, 1.12)
			var layer_height: float = float(heights[layer])
			ring.append(Vector3(cos(angle) * radius, layer_height + rng.randf_range(-0.22, 0.22), sin(angle) * radius))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strata := [
		Color(0.31, 0.145, 0.105),
		Color(0.43, 0.205, 0.145),
		Color(0.36, 0.17, 0.125),
		Color(0.49, 0.255, 0.18)
	]
	for layer in range(heights.size() - 1):
		for segment in range(12):
			var next_segment := (segment + 1) % 12
			var lower_a: Vector3 = rings[layer][segment]
			var lower_b: Vector3 = rings[layer][next_segment]
			var upper_a: Vector3 = rings[layer + 1][segment]
			var upper_b: Vector3 = rings[layer + 1][next_segment]
			var shade: Color = strata[layer % strata.size()] * rng.randf_range(0.88, 1.12)
			surface.set_color(shade)
			surface.add_vertex(lower_a)
			surface.add_vertex(upper_a)
			surface.add_vertex(lower_b)
			surface.add_vertex(lower_b)
			surface.add_vertex(upper_a)
			surface.add_vertex(upper_b)
	# Close the crown and buried base so the outcrop has a solid silhouette.
	var crown: Vector3 = rings[heights.size() - 1][0]
	for segment in range(1, 11):
		surface.set_color(Color(0.52, 0.29, 0.21))
		surface.add_vertex(crown)
		surface.add_vertex(rings[4][segment + 1])
		surface.add_vertex(rings[4][segment])
	surface.generate_normals()
	var rock_mesh := surface.commit()
	var rock_material := StandardMaterial3D.new()
	rock_material.vertex_color_use_as_albedo = true
	rock_material.roughness = 0.96
	var rock_body := StaticBody3D.new()
	rock_body.position = pos
	rock_body.scale = Vector3.ONE * factor
	add_child(rock_body)
	var rock_instance := MeshInstance3D.new()
	rock_instance.mesh = rock_mesh
	rock_instance.material_override = rock_material
	rock_body.add_child(rock_instance)
	var rock_collision := CollisionShape3D.new()
	rock_collision.shape = rock_mesh.create_trimesh_shape()
	rock_body.add_child(rock_collision)

func _make_rock_mesh(seed_value: int, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var vertices := PackedVector3Array([
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)
	])
	var faces := PackedInt32Array([
		0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11,
		1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8,
		3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9,
		4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1
	])
	for i in range(vertices.size()):
		vertices[i] = vertices[i].normalized()
	for subdivision in range(2):
		var refined := PackedInt32Array()
		var midpoint_cache: Dictionary = {}
		for face_index in range(0, faces.size(), 3):
			var a: int = faces[face_index]
			var b: int = faces[face_index + 1]
			var c: int = faces[face_index + 2]
			var key_ab := mini(a, b) * 10000 + maxi(a, b)
			var key_bc := mini(b, c) * 10000 + maxi(b, c)
			var key_ca := mini(c, a) * 10000 + maxi(c, a)
			var ab: int
			var bc: int
			var ca: int
			if midpoint_cache.has(key_ab):
				ab = midpoint_cache[key_ab]
			else:
				vertices.append((vertices[a] + vertices[b]).normalized())
				ab = vertices.size() - 1
				midpoint_cache[key_ab] = ab
			if midpoint_cache.has(key_bc):
				bc = midpoint_cache[key_bc]
			else:
				vertices.append((vertices[b] + vertices[c]).normalized())
				bc = vertices.size() - 1
				midpoint_cache[key_bc] = bc
			if midpoint_cache.has(key_ca):
				ca = midpoint_cache[key_ca]
			else:
				vertices.append((vertices[c] + vertices[a]).normalized())
				ca = vertices.size() - 1
				midpoint_cache[key_ca] = ca
			refined.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		faces = refined
	var proportions := [
		Vector3(1.0, 0.62, 0.86),
		Vector3(0.92, 0.38, 1.0),
		Vector3(0.78, 0.72, 0.88)
	]
	var shape: Vector3 = proportions[variant]
	for i in range(vertices.size()):
		var direction: Vector3 = vertices[i].normalized()
		var fracture := sin(direction.x * 13.0 + direction.z * 8.0) * 0.045
		var weathering := rng.randf_range(-0.12, 0.12)
		vertices[i] = Vector3(direction.x * shape.x, direction.y * shape.y, direction.z * shape.z) * (1.0 + fracture + weathering)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face_index in range(0, faces.size(), 3):
		for corner in range(3):
			var p: Vector3 = vertices[faces[face_index + corner]]
			var elevation := clampf((p.y / shape.y + 1.0) * 0.5, 0.0, 1.0)
			var mottling := rng.randf_range(-0.055, 0.055)
			var band := clampf(elevation * 0.58 + mottling + 0.12, 0.0, 1.0)
			var color := Color(0.22, 0.115, 0.078).lerp(Color(0.58, 0.36, 0.235), band)
			surface.set_color(color)
			surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()

func _scatter_boulders() -> void:
	for variant in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261114 + variant * 7919
		var rock_mesh := _make_rock_mesh(8401 + variant * 101, variant)
		var rock_material := StandardMaterial3D.new()
		rock_material.vertex_color_use_as_albedo = true
		rock_material.roughness = 0.97
		rock_material.metallic = 0.0
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = rock_mesh
		multimesh.instance_count = 140
		multimesh.custom_aabb = AABB(Vector3(-125, -2, -125), Vector3(250, 35, 250))
		var rocks := MultiMeshInstance3D.new()
		rocks.multimesh = multimesh
		rocks.material_override = rock_material
		rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(rocks)
		for i in range(140):
			var x := 0.0
			var z := 0.0
			for attempt in range(80):
				x = rng.randf_range(-115.0, 115.0)
				z = rng.randf_range(-115.0, 115.0)
				if Vector2(x, z).length() > 29.0:
					break
			var size_factor := rng.randf_range(0.72, 1.45)
			if i < 12:
				size_factor = rng.randf_range(1.35, 1.72)
			var scale := Vector3(
				size_factor * rng.randf_range(0.82, 1.18),
				size_factor * rng.randf_range(0.42, 0.72),
				size_factor * rng.randf_range(0.78, 1.2)
			)
			var yaw := rng.randf_range(0.0, TAU)
			var position := Vector3(x, scale.y * 0.42, z)
			var basis := Basis(Vector3.UP, yaw).scaled(scale)
			multimesh.set_instance_transform(i, Transform3D(basis, position))
			if i < 12:
				var body := StaticBody3D.new()
				body.position = position
				body.rotation.y = yaw
				add_child(body)
				var collision := CollisionShape3D.new()
				var collision_shape := BoxShape3D.new()
				collision_shape.size = Vector3(1.55, 0.9, 1.55)
				collision.shape = collision_shape
				collision.scale = scale
				body.add_child(collision)

func _add_building_details(root: Node3D, wall: Color, porch: bool) -> void:
	var wood := _weathered_wood_material(wall.darkened(0.22))
	var trim := _weathered_wood_material(Color(0.19, 0.105, 0.065))
	var glass := _material(Color(0.12, 0.22, 0.25), 0.22, 0.12)
	var porch_wood := _weathered_wood_material(Color(0.3, 0.2, 0.13))
	for y in [0.55, 1.0, 1.45, 1.9, 2.35, 2.8, 3.25]:
		_box(root, Vector3(0, y, 3.57), Vector3(9.8, 0.055, 0.035), wood)
	for x in [-4.82, 4.82]:
		_box(root, Vector3(x, 2.1, 3.62), Vector3(0.16, 4.0, 0.12), trim)
	for x in [-3.3, 3.3]:
		_box(root, Vector3(x, 2.1, 3.91), Vector3(1.52, 1.95, 0.12), trim)
		_box(root, Vector3(x, 2.1, 3.99), Vector3(1.25, 1.62, 0.035), glass)
		_box(root, Vector3(x, 2.1, 4.02), Vector3(0.09, 1.7, 0.045), wood)
		_box(root, Vector3(x, 2.1, 4.03), Vector3(1.3, 0.09, 0.045), wood)
		_box(root, Vector3(x, 3.13, 3.92), Vector3(1.75, 0.16, 0.22), trim)
		_box(root, Vector3(x, 1.07, 3.92), Vector3(1.75, 0.16, 0.22), trim)
	for x in range(-4, 5):
		_box(root, Vector3(float(x), 2.1, 3.62), Vector3(0.045, 4.0, 0.055), wood)
	if porch:
		for x in [-4.7, 0.0, 4.7]:
			_box(root, Vector3(x, 1.55, 6.18), Vector3(0.2, 3.1, 0.2), trim)
			_box(root, Vector3(x, 3.12, 6.18), Vector3(0.36, 0.14, 0.36), wood)
		_box(root, Vector3(0, 0.48, 6.35), Vector3(11, 0.28, 1.0), porch_wood)
	for x in [-1.35, 1.35]:
		_sphere(root, Vector3(x, 2.75, 4.0), Vector3(0.18, 0.24, 0.16), Color(1.0, 0.62, 0.22))
		var light := OmniLight3D.new()
		light.position = Vector3(x, 2.75, 4.15)
		light.light_color = Color(1.0, 0.58, 0.28)
		light.light_energy = 0.45
		light.omni_range = 5.0
		root.add_child(light)

func _scatter_ground_detail() -> void:
	var grass := _material(Color(0.39, 0.34, 0.19), 1.0)
	var stone := _material(Color(0.57, 0.43, 0.31), 1.0)
	for i in range(520):
		var x := randf_range(-115.0, 115.0)
		var z := randf_range(-115.0, 115.0)
		if Vector2(x, z).length() < 18.0:
			continue
		var h := randf_range(0.12, 0.42)
		var tuft := _cylinder(self, Vector3(x, h * 0.5, z), randf_range(0.025, 0.06), h, Color(0.39, 0.34, 0.19), 5)
		tuft.material_override = grass
	for i in range(340):
		var x := randf_range(-125.0, 125.0)
		var z := randf_range(-125.0, 125.0)
		if Vector2(x, z).length() < 17.0:
			continue
		var pebble := _sphere(self, Vector3(x, 0.06, z), Vector3(randf_range(0.08, 0.3), randf_range(0.05, 0.14), randf_range(0.08, 0.25)), Color(0.55, 0.4, 0.28))
		pebble.material_override = stone

func _build_town() -> void:
	_scatter_ground_detail()
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
			var wheel := _cylinder(self, Vector3(x, 0.9, z), 0.9, 0.38, Color(0.07, 0.07, 0.07), 16)
			wheel.rotation.x = PI / 2
func _weathered_wood_material(base: Color, roof := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.32, 0.17, 0.09, 1.0);
uniform float grain_scale = 5.0;
varying vec3 world_pos;
float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),
		mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),
		mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float broad = noise3(world_pos * vec3(0.24, 0.07, 0.24));
	float fine = noise3(world_pos * vec3(3.2, 0.32, 3.2));
	float fibers = sin((world_pos.x + world_pos.z * 0.31 + broad * 0.8) * grain_scale * 6.28318);
	float grain = smoothstep(0.28, 0.82, fibers * 0.5 + 0.5);
	float knots = smoothstep(0.76, 0.96, noise3(world_pos * 1.7 + vec3(4.2, 0.0, 8.1)));
	float pores = noise3(world_pos * 18.0);
	vec3 color = mix(tint.rgb * 0.48, tint.rgb * (1.0 + grain * 0.22), 0.42 + broad * 0.38);
	color = mix(color, tint.rgb * 0.34, knots * 0.42);
	color *= 0.88 + fine * 0.18 + pores * 0.055;
	float bleach = smoothstep(0.48, 0.92, noise3(world_pos * 0.42 + vec3(13.0))) * 0.6;
	color = mix(color, color * vec3(1.24, 1.12, 0.88), bleach * 0.22);
	ALBEDO = color;
	ROUGHNESS = 0.78 + pores * 0.18;
	SPECULAR = 0.18;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", base)
	material.set_shader_parameter("grain_scale", 1.8 if roof else 5.0)
	return material

func _build_building(pos: Vector3, sign_text: String, wall: Color, porch: bool) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var wall_surface := _weathered_wood_material(wall)
	var roof_surface := _weathered_wood_material(Color(0.24, 0.14, 0.11), true)
	_box(root, Vector3(0, 2.1, 0), Vector3(10, 4.2, 7), wall_surface)
	_box(root, Vector3(0, 4.45, 0), Vector3(11, 0.45, 8), roof_surface)
	var roof := PrismMesh.new()
	roof.size = Vector3(11, 2.7, 8)
	_mesh(root, roof, roof_surface, Vector3(0, 5.9, 0))
	_box(root, Vector3(0, 2.0, 3.57), Vector3(1.45, 2.8, 0.16), _weathered_wood_material(Color(0.16, 0.1, 0.07)))
	for x in [-3.3, 3.3]:
		_box(root, Vector3(x, 2.1, 3.66), Vector3(1.25, 1.7, 0.18), Color(0.16, 0.29, 0.34))
		_box(root, Vector3(x, 2.1, 3.78), Vector3(1.4, 0.12, 0.12), _weathered_wood_material(Color(0.24, 0.15, 0.1)))
	if porch:
		_box(root, Vector3(0, 1.7, 5.0), Vector3(11, 0.25, 3), _weathered_wood_material(Color(0.3, 0.2, 0.13)))
		for x in [-4.7, 0, 4.7]:
			_cylinder(root, Vector3(x, 1.5, 6.2), 0.12, 3, Color(0.25, 0.16, 0.1), 8)
	var sign := Label3D.new()
	sign.text = sign_text
	sign.font_size = 42
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 4.0, 4.08)
	sign.rotation_degrees.y = 0
	sign.modulate = Color(1.0, 0.79, 0.48)
	root.add_child(sign)
	_add_building_details(root, wall, porch)
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
	var hide := _material(Color(0.36, 0.34, 0.24), 0.94)
	var flank := _material(Color(0.48, 0.44, 0.31), 0.91)
	var shadow := _material(Color(0.22, 0.23, 0.17), 0.98)
	var horn := _material(Color(0.72, 0.62, 0.43), 0.82)
	var eye := _material(Color(0.035, 0.028, 0.019), 0.25)

	# Heavy barrel torso, shoulders and sloped hindquarters.
	var torso := CapsuleMesh.new()
	torso.radius = 0.73
	torso.height = 2.65
	torso.radial_segments = 32
	torso.rings = 12
	var body := _mesh(d, torso, hide, Vector3(0, 1.48, 0.05), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	body.scale = Vector3(1.0, 1.0, 1.32)
	_sphere(d, Vector3(0, 1.42, 0.92), Vector3(1.28, 1.12, 1.25), hide)
	_sphere(d, Vector3(0, 1.63, -0.93), Vector3(1.12, 1.12, 1.08), flank)
	_sphere(d, Vector3(0, 1.2, 0.12), Vector3(1.08, 0.55, 1.65), shadow)

	# Long tapering tail and muscular neck.
	var tail := CylinderMesh.new()
	tail.top_radius = 0.025
	tail.bottom_radius = 0.43
	tail.height = 2.65
	tail.radial_segments = 20
	_mesh(d, tail, hide, Vector3(0, 1.42, 2.05), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	_sphere(d, Vector3(0, 1.83, -1.47), Vector3(0.88, 0.9, 0.9), flank)
	_sphere(d, Vector3(0, 1.93, -1.98), Vector3(0.82, 0.72, 0.92), hide)
	_sphere(d, Vector3(0, 1.52, -2.23), Vector3(0.7, 0.34, 0.88), shadow)
	_sphere(d, Vector3(0, 1.47, -2.48), Vector3(0.56, 0.28, 0.58), shadow)

	# Broad scalloped frill, modeled as a custom fan mesh with raised knobs.
	var fan := SurfaceTool.new()
	fan.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 2.12, -1.57)
	var rim := PackedVector3Array()
	for i in range(25):
		var angle := PI * float(i) / 24.0
		var scallop := 1.0 + 0.055 * sin(float(i) * PI / 3.0)
		rim.append(Vector3(cos(angle) * 1.02 * scallop, sin(angle) * 1.13 * scallop, -0.12 * sin(angle)))
	for i in range(24):
		fan.set_color(Color(0.42 + 0.05 * sin(float(i) * 0.7), 0.39, 0.27))
		fan.add_vertex(center)
		fan.add_vertex(center + rim[i])
		fan.add_vertex(center + rim[i + 1])
	fan.generate_normals()
	var fan_material := StandardMaterial3D.new()
	fan_material.vertex_color_use_as_albedo = true
	fan_material.roughness = 0.9
	_mesh(d, fan.commit(), fan_material, Vector3.ZERO)
	for i in range(0, 25, 3):
		_sphere(d, center + rim[i], Vector3(0.13, 0.14, 0.13), flank)

	# Two long brow horns and the shorter nasal horn.
	for x in [-0.48, 0.48]:
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.012
		horn_mesh.bottom_radius = 0.145
		horn_mesh.height = 0.92
		horn_mesh.radial_segments = 12
		_mesh(d, horn_mesh, horn, Vector3(x, 2.52, -2.0), Vector3.ONE, Vector3(-0.48, 0, 0))
		_sphere(d, Vector3(x * 1.23, 2.18, -2.1), Vector3(0.2, 0.16, 0.2), shadow)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.01
	nose.bottom_radius = 0.11
	nose.height = 0.52
	nose.radial_segments = 12
	_mesh(d, nose, horn, Vector3(0, 2.0, -2.72), Vector3.ONE, Vector3(-0.45, 0, 0))
	for x in [-0.69, 0.69]:
		_sphere(d, Vector3(x, 2.03, -2.06), Vector3(0.095, 0.105, 0.075), eye)
		_sphere(d, Vector3(x * 0.76, 1.67, -2.64), Vector3(0.055, 0.04, 0.035), shadow)

	# Four weight-bearing legs, articulated at the hip and animated in a slow gait.
	for x in [-0.78, 0.78]:
		for z in [-0.86, 0.98]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, 1.18, z)
			d.add_child(pivot)
			var upper := CylinderMesh.new()
			upper.top_radius = 0.24
			upper.bottom_radius = 0.34
			upper.height = 0.82
			upper.radial_segments = 18
			_mesh(pivot, upper, hide, Vector3(0, -0.39, 0))
			var lower := CylinderMesh.new()
			lower.top_radius = 0.2
			lower.bottom_radius = 0.27
			lower.height = 0.66
			lower.radial_segments = 18
			_mesh(pivot, lower, shadow, Vector3(0, -1.02, -0.025))
			_sphere(pivot, Vector3(0, -1.34, -0.14), Vector3(0.43, 0.22, 0.48), shadow)
			for toe in [-0.2, 0.0, 0.2]:
				_sphere(pivot, Vector3(toe, -1.37, -0.43), Vector3(0.12, 0.1, 0.18), horn)
			var gait := create_tween().set_loops()
			gait.tween_property(pivot, "rotation:x", 0.13 if z < 0.0 else -0.13, 0.85).set_trans(Tween.TRANS_SINE)
			gait.tween_property(pivot, "rotation:x", -0.13 if z < 0.0 else 0.13, 0.85).set_trans(Tween.TRANS_SINE)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.connect("interacted", Callable(self, "_on_player_interacted"))
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
func _on_player_interacted() -> void:
	message_label.text = "YOU SEARCH THE STREET. THE FRONTIER HOLDS ITS SECRETS."
