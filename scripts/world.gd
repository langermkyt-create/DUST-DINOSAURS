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
func _terrain_hash(point: Vector2) -> float:
	var p := Vector2(
		fposmod(point.x * 123.34, 1.0),
		fposmod(point.y * 456.21, 1.0)
	)
	var offset := p.dot(p + Vector2.ONE * 45.32)
	p += Vector2.ONE * offset
	return fposmod(p.x * p.y, 1.0)

func _terrain_noise(point: Vector2) -> float:
	var cell := Vector2(floor(point.x), floor(point.y))
	var blend := point - cell
	blend = blend * blend * (Vector2.ONE * 3.0 - blend * 2.0)
	var a := _terrain_hash(cell)
	var b := _terrain_hash(cell + Vector2.RIGHT)
	var c := _terrain_hash(cell + Vector2.DOWN)
	var d := _terrain_hash(cell + Vector2.ONE)
	return lerpf(lerpf(a, b, blend.x), lerpf(c, d, blend.x), blend.y)

func _terrain_fbm(point: Vector2) -> float:
	var p := point
	var value := 0.0
	var amplitude := 0.5
	for octave in range(5):
		value += _terrain_noise(p) * amplitude
		p *= 2.03
		amplitude *= 0.5
	return value

func _terrain_height(world_xz: Vector2) -> float:
	var dune := _terrain_fbm(world_xz * 0.018)
	var ripple := sin(world_xz.dot(Vector2(0.72, 0.69)) * 1.35
		+ _terrain_fbm(world_xz * 0.045) * 5.0)
	return (dune - 0.5) * 1.15 + ripple * 0.035

func _make_terrain_mesh(segments: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_extent := 260.0
	var step := 520.0 / float(segments)
	for z in range(segments):
		for x in range(segments):
			var x0 := -half_extent + float(x) * step
			var x1 := x0 + step
			var z0 := -half_extent + float(z) * step
			var z1 := z0 + step
			var a := Vector3(x0, _terrain_height(Vector2(x0, z0)), z0)
			var b := Vector3(x1, _terrain_height(Vector2(x1, z0)), z0)
			var c := Vector3(x0, _terrain_height(Vector2(x0, z1)), z1)
			var d := Vector3(x1, _terrain_height(Vector2(x1, z1)), z1)
			surface.set_uv(Vector2(float(x) / segments, float(z) / segments))
			surface.add_vertex(a)
			surface.set_uv(Vector2(float(x) / segments, float(z + 1) / segments))
			surface.add_vertex(c)
			surface.set_uv(Vector2(float(x + 1) / segments, float(z) / segments))
			surface.add_vertex(b)
			surface.set_uv(Vector2(float(x + 1) / segments, float(z) / segments))
			surface.add_vertex(b)
			surface.set_uv(Vector2(float(x) / segments, float(z + 1) / segments))
			surface.add_vertex(c)
			surface.set_uv(Vector2(float(x + 1) / segments, float(z + 1) / segments))
			surface.add_vertex(d)
	surface.generate_normals()
	return surface.commit()

func _build_landscape() -> void:
	# The visible dunes and the collision surface are generated from the same height function.
	# This removes the old mismatch where feet and rocks floated above a flat collision plane.
	var ground := _make_terrain_mesh(180)
	ground.surface_set_material(0, _terrain_material())
	var terrain := StaticBody3D.new()
	terrain.name = "ProceduralTerrain"
	add_child(terrain)
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = ground.create_trimesh_shape()
	terrain.add_child(ground_shape)
	var ground_instance := MeshInstance3D.new()
	ground_instance.name = "DuneSurface"
	ground_instance.mesh = ground
	terrain.add_child(ground_instance)
	for i in range(34):
		var angle := TAU * float(i) / 34.0
		var radius := randf_range(125.0, 190.0)
		var p := Vector3(cos(angle) * radius, randf_range(13.0, 25.0), sin(angle) * radius)
		_rock_formation(p, randf_range(0.8, 1.5))
	_scatter_boulders()
	_scatter_saguaros()

func _append_cactus_tube(surface: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, base_color: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	for ring_index in range(points.size()):
		var tangent: Vector3
		if ring_index == 0:
			tangent = (points[1] - points[0]).normalized()
		elif ring_index == points.size() - 1:
			tangent = (points[ring_index] - points[ring_index - 1]).normalized()
		else:
			tangent = (points[ring_index + 1] - points[ring_index - 1]).normalized()
		var reference := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.92 else Vector3.FORWARD
		var axis_x := tangent.cross(reference).normalized()
		var axis_z := tangent.cross(axis_x).normalized()
		var ring := PackedVector3Array()
		for segment in range(16):
			var angle := TAU * float(segment) / 16.0
			var rib := 1.0 + 0.075 * cos(angle * 8.0)
			var radial := (axis_x * cos(angle) + axis_z * sin(angle)) * radii[ring_index] * rib
			ring.append(points[ring_index] + radial)
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(16):
			var next_segment := (segment + 1) % 16
			var height_tint := 0.94 + 0.08 * float(ring_index) / float(maxi(1, rings.size() - 1))
			var rib_tint := 0.94 + 0.06 * cos(TAU * float(segment) / 16.0 * 8.0)
			var tint := base_color * height_tint * rib_tint
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			surface.set_color(tint)
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.set_color(tint)
			surface.add_vertex(b)
			surface.add_vertex(d)
			surface.add_vertex(c)
	# Cap the exposed ends so the cactus does not have hollow cut surfaces.
	var bottom_center := points[0]
	var top_center := points[points.size() - 1]
	for segment in range(16):
		var next_segment := (segment + 1) % 16
		surface.set_color(base_color * 0.88)
		surface.add_vertex(bottom_center)
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(rings[0][segment])
		surface.set_color(base_color * 0.96)
		surface.add_vertex(top_center)
		surface.add_vertex(rings[rings.size() - 1][segment])
		surface.add_vertex(rings[rings.size() - 1][next_segment])

func _make_saguaro_mesh(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := [Color(0.19, 0.32, 0.19), Color(0.23, 0.34, 0.19), Color(0.17, 0.29, 0.17)][variant]
	var trunk_points := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.025, 0.08, 0.0),
		Vector3(0.04, 0.38, 0.0), Vector3(0.015, 0.9, 0.0),
		Vector3(-0.025, 1.65, 0.0), Vector3(-0.045, 2.45, 0.0),
		Vector3(-0.02, 3.25, 0.0), Vector3(0.0, 3.55, 0.0)
	])
	var trunk_radii := PackedFloat32Array([0.23, 0.26, 0.27, 0.255, 0.235, 0.205, 0.17, 0.12])
	_append_cactus_tube(surface, trunk_points, trunk_radii, green)
	if variant != 2:
		var side := -1.0 if variant == 0 else 1.0
		var branch_points := PackedVector3Array([
			Vector3(side * 0.19, 1.05, 0.0), Vector3(side * 0.43, 1.09, 0.0),
			Vector3(side * 0.66, 1.28, 0.0), Vector3(side * 0.68, 1.58, 0.0),
			Vector3(side * 0.68, 1.92, 0.0), Vector3(side * 0.68, 2.12, 0.0)
		])
		_append_cactus_tube(surface, branch_points, PackedFloat32Array([0.17, 0.15, 0.13, 0.115, 0.095, 0.07]), green)
		if variant == 0:
			var other_points := PackedVector3Array([
				Vector3(-0.19, 1.58, 0.0), Vector3(-0.4, 1.61, 0.0),
				Vector3(-0.57, 1.79, 0.0), Vector3(-0.57, 2.06, 0.0),
				Vector3(-0.57, 2.34, 0.0)
			])
			_append_cactus_tube(surface, other_points, PackedFloat32Array([0.15, 0.13, 0.115, 0.09, 0.065]), green * 1.035)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	mesh.surface_set_material(0, material)
	return mesh

func _scatter_saguaros() -> void:
	for variant in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1897 + variant * 421
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _make_saguaro_mesh(variant)
		multimesh.instance_count = 74
		multimesh.custom_aabb = AABB(Vector3(-125, -1, -125), Vector3(250, 8, 250))
		var plants := MultiMeshInstance3D.new()
		plants.multimesh = multimesh
		plants.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(plants)
		for i in range(74):
			var x := 0.0
			var z := 0.0
			for attempt in range(80):
				x = rng.randf_range(-115.0, 115.0)
				z = rng.randf_range(-115.0, 115.0)
				if Vector2(x, z).length() > 23.0:
					break
			var scale_factor := rng.randf_range(0.72, 1.28)
			var yaw := rng.randf_range(0.0, TAU)
			var position := Vector3(x, _terrain_height(Vector2(x, z)), z)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(
				scale_factor * rng.randf_range(0.9, 1.1),
				scale_factor,
				scale_factor * rng.randf_range(0.9, 1.1)
			))
			multimesh.set_instance_transform(i, Transform3D(basis, position))

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
			var position := Vector3(x, _terrain_height(Vector2(x, z)) + scale.y * 0.42, z)
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
	# Side elevations receive the same hand-laid board rhythm as the street-facing facade.
	for side in [-1.0, 1.0]:
		for y in [0.55, 1.0, 1.45, 1.9, 2.35, 2.8, 3.25]:
			_box(root, Vector3(side * 5.02, y, 0.0), Vector3(0.035, 0.055, 6.85), wood)
		_box(root, Vector3(side * 5.06, 2.1, 0.0), Vector3(0.12, 4.0, 7.0), trim)
		for z in [-3.25, 3.25]:
			_box(root, Vector3(side * 5.08, 2.1, z), Vector3(0.12, 4.0, 0.12), trim)
	# Layered fascia and exposed rafter ends break up the single-piece roof silhouette.
	for z in [-4.02, 4.02]:
		_box(root, Vector3(0, 5.35, z), Vector3(11.2, 0.22, 0.18), trim)
	for x in [-4.7, -2.35, 0.0, 2.35, 4.7]:
		_box(root, Vector3(x, 5.15, 3.88), Vector3(0.16, 0.42, 0.22), wood)
	if porch:
		# Porch railings, posts and a worn two-step approach.
		for x in [-4.7, -2.35, 2.35, 4.7]:
			_box(root, Vector3(x, 1.02, 5.82), Vector3(0.12, 1.1, 0.12), trim)
		_box(root, Vector3(0, 1.42, 5.82), Vector3(9.4, 0.12, 0.12), wood)
		_box(root, Vector3(0, 0.86, 5.82), Vector3(9.4, 0.1, 0.12), wood)
		_box(root, Vector3(0, 0.24, 7.2), Vector3(3.2, 0.24, 0.8), porch_wood)
		_box(root, Vector3(0, 0.48, 6.8), Vector3(3.2, 0.24, 0.8), porch_wood)
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

func _make_desert_tuft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_colors := [
		Color(0.38, 0.34, 0.19),
		Color(0.49, 0.42, 0.23),
		Color(0.29, 0.3, 0.17)
	]
	for blade in range(5):
		var angle := TAU * float(blade) / 5.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x) * 0.035
		var lean := direction * (0.06 + 0.025 * float(blade % 2))
		var height := 0.24 + 0.075 * float((blade * 3) % 4) / 3.0
		var root := direction * 0.025
		var tip := root + lean + Vector3(0.0, height, 0.0)
		var color := blade_colors[blade % blade_colors.size()]
		surface.set_color(color.darkened(0.12))
		surface.add_vertex(root - side)
		surface.set_color(color.lightened(0.12))
		surface.add_vertex(tip)
		surface.set_color(color)
		surface.add_vertex(root + side)
		surface.set_color(color.darkened(0.12))
		surface.add_vertex(root + side)
		surface.set_color(color.lightened(0.12))
		surface.add_vertex(tip)
		surface.set_color(color)
		surface.add_vertex(root - side)
	surface.generate_normals()
	var mesh := surface.commit()
	var grass_shader := Shader.new()
	grass_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * 1.25 + world_position.x * 0.16 + world_position.z * 0.11;
	float bend = cos(phase) * 0.065;
	VERTEX.x += sin(phase) * 0.065 * VERTEX.y;
	NORMAL = normalize(vec3(NORMAL.x - bend * NORMAL.y, NORMAL.y, NORMAL.z));
}
void fragment() {
	float sun_bleach = clamp(world_position.y * 0.8, 0.0, 0.12);
	ALBEDO = COLOR.rgb + vec3(sun_bleach, sun_bleach * 0.82, sun_bleach * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.04;
}
"""
	var material := ShaderMaterial.new()
	material.shader = grass_shader
	mesh.surface_set_material(0, material)
	return mesh

func _scatter_ground_detail() -> void:
	# Keep hundreds of small ground accents in a handful of instanced draw calls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 189711
	var grass_multimesh := MultiMesh.new()
	grass_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass_multimesh.mesh = _make_desert_tuft_mesh()
	grass_multimesh.instance_count = 520
	grass_multimesh.custom_aabb = AABB(Vector3(-130, -1, -130), Vector3(260, 4, 260))
	var grass := MultiMeshInstance3D.new()
	grass.multimesh = grass_multimesh
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	for i in range(520):
		var x := 0.0
		var z := 0.0
		for attempt in range(80):
			x = rng.randf_range(-115.0, 115.0)
			z = rng.randf_range(-115.0, 115.0)
			if Vector2(x, z).length() > 18.0:
				break
		var scale_factor := rng.randf_range(0.55, 1.45)
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale_factor, scale_factor, scale_factor))
		grass_multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, _terrain_height(Vector2(x, z)), z)))
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radial_segments = 16
	pebble_mesh.rings = 10
	var stone_material := _material(Color(0.55, 0.42, 0.3), 1.0)
	for variant in range(2):
		var stones := MultiMesh.new()
		stones.transform_format = MultiMesh.TRANSFORM_3D
		stones.mesh = pebble_mesh
		stones.instance_count = 170
		stones.custom_aabb = AABB(Vector3(-130, -1, -130), Vector3(260, 3, 260))
		var stone_batch := MultiMeshInstance3D.new()
		stone_batch.multimesh = stones
		stone_batch.material_override = stone_material
		stone_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stone_batch)
		for i in range(170):
			var x := 0.0
			var z := 0.0
			for attempt in range(80):
				x = rng.randf_range(-125.0, 125.0)
				z = rng.randf_range(-125.0, 125.0)
				if Vector2(x, z).length() > 17.0:
					break
			var size_factor := rng.randf_range(0.12, 0.32)
			var scale := Vector3(
				size_factor * rng.randf_range(0.8, 1.3),
				size_factor * rng.randf_range(0.28, 0.52),
				size_factor * rng.randf_range(0.75, 1.25)
			)
			var yaw := rng.randf_range(0.0, TAU)
			stones.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(scale), Vector3(x, _terrain_height(Vector2(x, z)) + 0.035, z)))

func _road_material() -> ShaderMaterial:
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
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float dust = noise2(world_position.xz * 2.7);
	float gravel = noise2(world_position.xz * 13.0);
	float fine = noise2(world_position.xz * 47.0);
	float wheel_ruts = exp(-pow((abs(world_position.x) - 2.2) * 1.7, 2.0));
	float hoof_wear = exp(-pow(world_position.x * 0.55, 2.0)) * 0.22;
	float ruts = max(wheel_ruts, hoof_wear);
	vec3 base = mix(vec3(0.19, 0.105, 0.06), vec3(0.34, 0.21, 0.13), dust);
	base *= 0.82 + gravel * 0.23 + fine * 0.08;
	base *= 1.0 - ruts * 0.13;
	ALBEDO = base;
	ROUGHNESS = 0.99;
	SPECULAR = 0.025;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _make_town_road_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width_segments := 32
	var length_segments := 180
	for z_index in range(length_segments):
		for x_index in range(width_segments):
			var x0 := -9.5 + 19.0 * float(x_index) / float(width_segments)
			var x1 := -9.5 + 19.0 * float(x_index + 1) / float(width_segments)
			var z0 := -55.0 + 110.0 * float(z_index) / float(length_segments)
			var z1 := -55.0 + 110.0 * float(z_index + 1) / float(length_segments)
			var a := Vector3(x0, _terrain_height(Vector2(x0, z0)) + 0.045, z0)
			var b := Vector3(x1, _terrain_height(Vector2(x1, z0)) + 0.045, z0)
			var c := Vector3(x0, _terrain_height(Vector2(x0, z1)) + 0.045, z1)
			var d := Vector3(x1, _terrain_height(Vector2(x1, z1)) + 0.045, z1)
			surface.set_uv(Vector2(float(x_index) / width_segments, float(z_index) / length_segments))
			surface.add_vertex(a)
			surface.set_uv(Vector2(float(x_index) / width_segments, float(z_index + 1) / length_segments))
			surface.add_vertex(c)
			surface.set_uv(Vector2(float(x_index + 1) / width_segments, float(z_index) / length_segments))
			surface.add_vertex(b)
			surface.set_uv(Vector2(float(x_index + 1) / width_segments, float(z_index) / length_segments))
			surface.add_vertex(b)
			surface.set_uv(Vector2(float(x_index) / width_segments, float(z_index + 1) / length_segments))
			surface.add_vertex(c)
			surface.set_uv(Vector2(float(x_index + 1) / width_segments, float(z_index + 1) / length_segments))
			surface.add_vertex(d)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, _road_material())
	return mesh

func _build_town() -> void:
	_scatter_ground_detail()
	var road_instance := MeshInstance3D.new()
	road_instance.name = "WornDirtStreet"
	road_instance.mesh = _make_town_road_mesh()
	add_child(road_instance)
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

func _add_building_wall_piece(root: Node3D, body: StaticBody3D, center: Vector3, size: Vector3, surface: Material) -> void:
	_box(root, center, size, surface)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

func _build_building(pos: Vector3, sign_text: String, wall: Color, porch: bool) -> void:
	var root := Node3D.new()
	root.position = pos + Vector3(0.0, _terrain_height(Vector2(pos.x, pos.z)), 0.0)
	add_child(root)
	var wall_surface := _weathered_wood_material(wall)
	var roof_surface := _weathered_wood_material(Color(0.24, 0.14, 0.11), true)
	# Build the shell from separate wall panels. The street facade has real door and
	# window apertures instead of a solid box hidden behind decorative overlays.
	var building_body := StaticBody3D.new()
	building_body.name = "BuildingCollision"
	root.add_child(building_body)
	var thickness := 0.22
	_add_building_wall_piece(root, building_body, Vector3(0, 2.1, -3.5), Vector3(10, 4.2, thickness), wall_surface)
	_add_building_wall_piece(root, building_body, Vector3(-4.89, 2.1, 0), Vector3(thickness, 4.2, 7), wall_surface)
	_add_building_wall_piece(root, building_body, Vector3(4.89, 2.1, 0), Vector3(thickness, 4.2, 7), wall_surface)
	# Front wall: full-height piers, lower/upper window panels and a door lintel.
	for x_range in [Vector2(-5.0, -3.95), Vector2(-2.65, -0.82), Vector2(0.82, 2.65), Vector2(3.95, 5.0)]:
		var width := x_range.y - x_range.x
		_add_building_wall_piece(root, building_body,
			Vector3((x_range.x + x_range.y) * 0.5, 2.1, 3.5),
			Vector3(width, 4.2, thickness), wall_surface)
	for window_x in [-3.3, 3.3]:
		_add_building_wall_piece(root, building_body, Vector3(window_x, 0.56, 3.5),
			Vector3(1.3, 1.12, thickness), wall_surface)
		_add_building_wall_piece(root, building_body, Vector3(window_x, 3.64, 3.5),
			Vector3(1.3, 1.12, thickness), wall_surface)
	_add_building_wall_piece(root, building_body, Vector3(0, 3.5, 3.5),
		Vector3(1.64, 1.4, thickness), wall_surface)
	# Dark interior backing gives the openings depth until full room interiors are built.
	_box(root, Vector3(0, 2.1, -3.34), Vector3(9.5, 4.0, 0.08), Color(0.12, 0.095, 0.07))
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
	_build_building_interior(root, sign_text, wall)
	_add_building_details(root, wall, porch)

func _interior_solid_box(root: Node3D, center: Vector3, size: Vector3, material: Material, node_name: String = "InteriorProp") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	root.add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _interior_table(root: Node3D, center: Vector3, width: float, depth: float, wood: Material) -> void:
	_interior_solid_box(root, center + Vector3(0, 0.82, 0), Vector3(width, 0.16, depth), wood, "TableTop")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_interior_solid_box(root, center + Vector3(x * (width * 0.5 - 0.12), 0.4, z * (depth * 0.5 - 0.12)), Vector3(0.16, 0.8, 0.16), wood, "TableLeg")

func _interior_lantern(root: Node3D, position: Vector3) -> void:
	var iron := _material(Color(0.075, 0.065, 0.05), 0.58, 0.62)
	var glass := _material(Color(0.95, 0.55, 0.2), 0.25)
	_cylinder(root, position, 0.12, 0.28, Color(0.08, 0.065, 0.045), 12)
	_sphere(root, position + Vector3(0, -0.22, 0), Vector3(0.14, 0.24, 0.14), glass)
	var light := OmniLight3D.new()
	light.position = position + Vector3(0, -0.28, 0)
	light.light_color = Color(1.0, 0.58, 0.29)
	light.light_energy = 0.65
	light.omni_range = 8.0
	light.shadow_enabled = true
	root.add_child(light)

func _build_building_interior(root: Node3D, sign_text: String, wall: Color) -> void:
	var floor_wood := _weathered_wood_material(wall.darkened(0.38))
	var furniture := _weathered_wood_material(Color(0.24, 0.135, 0.075))
	var dark_wood := _weathered_wood_material(Color(0.12, 0.075, 0.045))
	var iron := _material(Color(0.075, 0.07, 0.06), 0.62, 0.68)
	# A walkable plank floor replaces the dark placeholder void; one hidden collider
	# supports the entire room while individual furniture pieces have their own collision.
	_interior_solid_box(root, Vector3(0, -0.06, 0), Vector3(9.55, 0.2, 6.65), floor_wood, "InteriorFloor")
	for plank in range(15):
		var z := -3.0 + float(plank) * 0.43
		_box(root, Vector3(0, 0.052, z), Vector3(9.45, 0.018, 0.39), floor_wood)
	_interior_lantern(root, Vector3(0, 3.65, -0.65))
	if sign_text == "SALOON":
		# Long service bar, brass foot rail, bottle shelves and card tables.
		_interior_solid_box(root, Vector3(0, 1.15, -1.65), Vector3(6.0, 1.9, 0.72), furniture, "SaloonBar")
		_interior_solid_box(root, Vector3(0, 2.15, -1.65), Vector3(6.2, 0.16, 0.86), dark_wood, "BarTop")
		for x in [-2.2, -1.1, 0.0, 1.1, 2.2]:
			_cylinder(root, Vector3(x, 2.42, -1.65), 0.075, 0.42, iron, 10)
			_sphere(root, Vector3(x, 2.65, -1.65), Vector3(0.16, 0.2, 0.16), _material(Color(0.32, 0.12, 0.06), 0.22))
		for x in [-2.3, 2.3]:
			_interior_table(root, Vector3(x, 0, 1.05), 1.45, 1.05, furniture)
			for side in [-1.0, 1.0]:
				_cylinder(root, Vector3(x + side * 0.95, 0.42, 1.05), 0.24, 0.82, dark_wood, 12)
	elif sign_text == "GENERAL STORE":
		# Deep merchandise shelving with crates and a central sales counter.
		for side in [-1.0, 1.0]:
			_interior_solid_box(root, Vector3(side * 4.05, 1.55, -0.1), Vector3(0.52, 3.0, 5.8), dark_wood, "StoreShelf")
			for level in [0.55, 1.35, 2.15, 2.85]:
				_interior_solid_box(root, Vector3(side * 3.68, level, -0.1), Vector3(0.72, 0.12, 5.5), furniture, "ShelfBoard")
			for z in [-2.0, -0.7, 0.7, 2.0]:
				_box(root, Vector3(side * 3.62, 0.86, z), Vector3(0.38, 0.48, 0.42), _material(Color(0.42, 0.25, 0.12)))
		_interior_solid_box(root, Vector3(0, 1.0, -1.25), Vector3(3.2, 1.5, 0.7), furniture, "ShopCounter")
	elif sign_text == "SHERIFF":
		_interior_table(root, Vector3(0, 0, -1.35), 2.4, 1.2, furniture)
		_interior_solid_box(root, Vector3(-3.15, 1.2, -1.5), Vector3(0.12, 2.4, 3.5), iron, "CellBars")
		for z in [-2.8, -2.1, -1.4, -0.7, 0.0]:
			_cylinder(root, Vector3(-3.15, 1.2, z), 0.045, 2.4, iron, 8)
		_interior_solid_box(root, Vector3(-3.8, 0.9, 1.4), Vector3(1.0, 1.8, 1.8), dark_wood, "JailBench")
	elif sign_text == "STABLES":
		for x in [-3.1, 0.0, 3.1]:
			_interior_solid_box(root, Vector3(x, 1.15, -1.1), Vector3(0.12, 2.3, 4.2), furniture, "StallDivider")
			_interior_solid_box(root, Vector3(x, 1.0, -2.8), Vector3(2.8, 1.0, 0.12), dark_wood, "FeedTrough")
	elif sign_text == "HOTEL":
		for x in [-2.6, 2.6]:
			_interior_solid_box(root, Vector3(x, 0.52, -1.0), Vector3(2.0, 0.55, 3.0), furniture, "BedFrame")
			_interior_solid_box(root, Vector3(x, 0.92, -1.0), Vector3(1.9, 0.28, 2.9), _material(Color(0.48, 0.35, 0.25)), "Mattress")
			_interior_solid_box(root, Vector3(x, 1.28, -2.25), Vector3(1.9, 0.45, 0.48), _material(Color(0.72, 0.62, 0.46)), "Pillow")
			_interior_solid_box(root, Vector3(x, 0.55, 2.1), Vector3(0.9, 1.1, 0.9), dark_wood, "BedsideChest")
	else:
		_interior_table(root, Vector3(0, 0, -1.1), 2.8, 1.3, furniture)
		_interior_solid_box(root, Vector3(-3.6, 1.15, -1.8), Vector3(1.1, 2.3, 0.7), dark_wood, "FilingCabinet")
		_interior_solid_box(root, Vector3(3.4, 1.1, -1.8), Vector3(1.2, 2.2, 0.6), furniture, "MapCabinet")

func _build_dinosaur_herd() -> void:
	_make_triceratops(Vector3(-31, _terrain_height(Vector2(-31, -52)), -52), 1.0, 0.0)
	_make_triceratops(Vector3(-39, _terrain_height(Vector2(-39, -59)), -59), 0.78, 0.45)
	_make_triceratops(Vector3(-23, _terrain_height(Vector2(-23, -62)), -62), 0.66, -0.3)
	_build_tyrannosaur(Vector3(70, _terrain_height(Vector2(70, -112)), -112), 2.3)

func _build_tyrannosaur(pos: Vector3, size: float) -> void:
	var rex := Node3D.new()
	rex.position = pos
	rex.scale = Vector3.ONE * size
	add_child(rex)
	var hide := _material(Color(0.27, 0.22, 0.16), 0.93)
	var flank := _material(Color(0.38, 0.3, 0.2), 0.91)
	var underside := _material(Color(0.48, 0.39, 0.27), 0.96)
	var dark := _material(Color(0.12, 0.105, 0.075), 0.96)
	var teeth := _material(Color(0.82, 0.75, 0.58), 0.72)
	var eye := _material(Color(0.78, 0.48, 0.13), 0.28)
	# Deep rib cage, heavy hips and a raised shoulder line.
	_sphere(rex, Vector3(0, 2.55, 0.15), Vector3(1.42, 1.55, 2.35), hide)
	_sphere(rex, Vector3(0, 2.48, 0.92), Vector3(1.3, 1.35, 1.18), flank)
	_sphere(rex, Vector3(0, 1.98, -0.08), Vector3(1.1, 0.48, 1.72), underside)
	_sphere(rex, Vector3(0, 2.82, -1.15), Vector3(0.98, 1.02, 1.15), flank)
	# Forward neck, broad skull, hinged lower jaw and visible teeth.
	_sphere(rex, Vector3(0, 3.05, -1.65), Vector3(0.86, 0.78, 0.92), hide)
	_sphere(rex, Vector3(0, 3.42, -2.22), Vector3(0.92, 0.76, 0.88), hide)
	_sphere(rex, Vector3(0, 3.12, -2.72), Vector3(0.73, 0.4, 0.9), flank)
	_sphere(rex, Vector3(0, 2.84, -2.62), Vector3(0.69, 0.2, 0.82), dark)
	_sphere(rex, Vector3(0, 2.77, -2.56), Vector3(0.62, 0.12, 0.73), underside)
	for side in [-1.0, 1.0]:
		_sphere(rex, Vector3(side * 0.69, 3.49, -2.42), Vector3(0.105, 0.12, 0.1), eye)
		_sphere(rex, Vector3(side * 0.73, 3.51, -2.44), Vector3(0.045, 0.07, 0.045), dark)
		_sphere(rex, Vector3(side * 0.38, 3.23, -2.94), Vector3(0.065, 0.055, 0.045), dark)
		for tooth_index in range(5):
			var tooth := CylinderMesh.new()
			tooth.top_radius = 0.008
			tooth.bottom_radius = 0.045
			tooth.height = 0.17
			tooth.radial_segments = 8
			_mesh(rex, tooth, teeth, Vector3(side * (0.2 + float(tooth_index) * 0.095), 2.91, -2.85 + float(tooth_index % 2) * 0.19), Vector3.ONE, Vector3(PI, 0, 0))
	# Long counterbalancing tail, tapered from the pelvis to a narrow tip.
	var tail_pivot := Node3D.new()
	tail_pivot.position = Vector3(0, 2.55, 0.95)
	rex.add_child(tail_pivot)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.035
	tail.bottom_radius = 0.58
	tail.height = 3.9
	tail.radial_segments = 20
	_mesh(tail_pivot, tail, hide, Vector3(0, 0, 1.95), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	_sphere(tail_pivot, Vector3(0, 0, 0.38), Vector3(0.92, 0.68, 0.9), flank)
	var tail_sway := create_tween().set_loops()
	tail_sway.tween_property(tail_pivot, "rotation:y", 0.11, 1.7).set_trans(Tween.TRANS_SINE)
	tail_sway.tween_property(tail_pivot, "rotation:y", -0.11, 1.7).set_trans(Tween.TRANS_SINE)
	# Small, two-fingered forelimbs tucked close to the chest.
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.7, 2.48, -1.08)
		rex.add_child(arm)
		var upper_arm := CylinderMesh.new()
		upper_arm.top_radius = 0.105
		upper_arm.bottom_radius = 0.15
		upper_arm.height = 0.42
		_mesh(arm, upper_arm, flank, Vector3(0, -0.16, -0.08), Vector3.ONE, Vector3(-0.55, 0, side * 0.15))
		var forearm := CylinderMesh.new()
		forearm.top_radius = 0.07
		forearm.bottom_radius = 0.11
		forearm.height = 0.32
		_mesh(arm, forearm, hide, Vector3(0, -0.38, -0.19), Vector3.ONE, Vector3(-0.7, 0, side * 0.15))
		for claw in range(2):
			_sphere(arm, Vector3((float(claw) - 0.5) * 0.13, -0.52, -0.34), Vector3(0.045, 0.045, 0.12), teeth)
	# Muscular hind legs with separate thighs, shins and broad three-toed feet.
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.63, 1.7, 0.56)
		rex.add_child(leg)
		var thigh := CapsuleMesh.new()
		thigh.radius = 0.34
		thigh.height = 1.05
		thigh.radial_segments = 20
		thigh.rings = 8
		_mesh(leg, thigh, flank, Vector3(0, -0.28, 0.03), Vector3(1.0, 1.0, 1.25), Vector3(-0.2, 0, side * -0.08))
		var shin := CylinderMesh.new()
		shin.top_radius = 0.2
		shin.bottom_radius = 0.27
		shin.height = 0.86
		shin.radial_segments = 16
		_mesh(leg, shin, hide, Vector3(0, -0.94, -0.08), Vector3.ONE, Vector3(-0.12, 0, 0))
		_sphere(leg, Vector3(0, -1.43, -0.34), Vector3(0.42, 0.2, 0.56), dark)
		for toe in [-0.22, 0.0, 0.22]:
			_sphere(leg, Vector3(toe, -1.45, -0.66), Vector3(0.15, 0.12, 0.25), flank)
			var claw := CylinderMesh.new()
			claw.top_radius = 0.008
			claw.bottom_radius = 0.075
			claw.height = 0.2
			claw.radial_segments = 8
			_mesh(leg, claw, teeth, Vector3(toe, -1.43, -0.84), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
		var gait := create_tween().set_loops()
		gait.tween_property(leg, "rotation:x", 0.12 if side < 0.0 else -0.12, 1.1).set_trans(Tween.TRANS_SINE)
		gait.tween_property(leg, "rotation:x", -0.12 if side < 0.0 else 0.12, 1.1).set_trans(Tween.TRANS_SINE)
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
	player.position = Vector3(0, _terrain_height(Vector2(0, 38)) + 0.2, 38)
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
