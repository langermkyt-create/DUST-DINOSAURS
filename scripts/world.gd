extends Node3D
const PlayerScript = preload("res://scripts/player.gd")
const PREVIEW_TWEEN_SPEED_SCALE := 3.5
const PREVIEW_WAYPOINT_HOLD_SECONDS := 0.35
const PREVIEW_CAMERA_FOV := 56.0
const TERRAIN_MESH_SEGMENTS := 256
const TERRAIN_COLLISION_SEGMENTS := 192
var player: CharacterBody3D
var message_label: Label
var preview_started_at_msec: int = 0
var _weathered_wood_shader: Shader
var _roof_shingle_material: StandardMaterial3D
func _ready() -> void:
	_build_atmosphere()
	_build_landscape()
	_build_town()
	_build_dinosaur_herd()
	_build_player()
	_build_hud()
	if OS.get_cmdline_user_args().has("--preview"):
		_start_preview_flythrough()
func _terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 dust_tint : source_color = vec4(0.39, 0.27, 0.18, 1.0);
uniform vec4 ochre_tint : source_color = vec4(0.58, 0.39, 0.24, 1.0);
uniform vec4 pale_tint : source_color = vec4(0.68, 0.53, 0.36, 1.0);
uniform float micro_normal_strength = 0.04;
varying vec3 world_position;
varying vec3 world_normal;
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
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float broad = fbm(world_position.xz * 0.014);
	float sediment = noise2(world_position.xz * vec2(0.045, 0.16));
	float grain = noise2(world_position.xz * 0.92);
	float gravel = noise2(world_position.xz * 5.2);
	float pores = noise2(world_position.xz * 22.0);
	float fine_grain = noise2(world_position.xz * 54.0);
	float wind_streak = sin(dot(world_position.xz, vec2(0.72, 0.69)) * 1.9
		+ noise2(world_position.xz * 0.12) * 2.8) * 0.5 + 0.5;
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float exposed_sandstone = smoothstep(0.12, 0.38, slope);
	float wash_center = -76.0 + sin(world_position.x * 0.018) * 16.0;
	float wash_mask = exp(-pow((world_position.z - wash_center) / 25.0, 2.0));
	vec3 soil = mix(dust_tint.rgb, ochre_tint.rgb, smoothstep(0.18, 0.82, broad));
	soil = mix(soil, pale_tint.rgb, smoothstep(0.62, 0.91, grain) * 0.30);
	float clay_streaks = smoothstep(0.70, 0.94, sediment);
	soil = mix(soil, soil * vec3(0.74, 0.69, 0.60), clay_streaks * 0.17);
	soil = mix(soil, dust_tint.rgb * 0.82, wash_mask * 0.12);
	vec3 sandstone = mix(vec3(0.42, 0.28, 0.20), vec3(0.56, 0.37, 0.25), broad);
	soil = mix(soil, sandstone, exposed_sandstone * 0.58);
	soil *= 0.88 + gravel * 0.16 + pores * 0.055 + fine_grain * 0.025;
	soil *= 0.96 + wind_streak * 0.08;
	vec2 micro_gradient = clamp(vec2(dFdx(fine_grain), dFdy(fine_grain)) * 0.18,
		vec2(-0.04), vec2(0.04));
	NORMAL = normalize(NORMAL + vec3(-micro_gradient.x, -micro_gradient.y, 0.0) * micro_normal_strength);
	ALBEDO = soil;
	ROUGHNESS = clamp(0.88 + pores * 0.11, 0.88, 0.99);
	SPECULAR = 0.07;
	AO = clamp(0.96 - (1.0 - gravel) * 0.05, 0.91, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("dust_tint", Color(0.39, 0.27, 0.18))
	material.set_shader_parameter("ochre_tint", Color(0.58, 0.39, 0.24))
	material.set_shader_parameter("pale_tint", Color(0.68, 0.53, 0.36))
	material.set_shader_parameter("micro_normal_strength", 0.04)
	return material

func _material(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
func _dinosaur_skin_material(base: Color, detail_scale: float = 1.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 skin_tint : source_color = vec4(0.36, 0.34, 0.24, 1.0);
uniform float detail_scale = 1.0;
uniform float micro_normal_strength = 0.07;
varying vec3 skin_world_pos;
float skin_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float skin_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float a = skin_hash(cell);
	float b = skin_hash(cell + vec3(1.0, 0.0, 0.0));
	float c = skin_hash(cell + vec3(0.0, 1.0, 0.0));
	float d = skin_hash(cell + vec3(1.0, 1.0, 0.0));
	float e = skin_hash(cell + vec3(0.0, 0.0, 1.0));
	float f = skin_hash(cell + vec3(1.0, 0.0, 1.0));
	float g = skin_hash(cell + vec3(0.0, 1.0, 1.0));
	float h = skin_hash(cell + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y),
		mix(mix(e, f, blend.x), mix(g, h, blend.x), blend.y),
		blend.z
	);
}
void vertex() {
	skin_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * detail_scale;
}
void fragment() {
	float broad_mottle = skin_noise(skin_world_pos * 1.4);
	float fine_mottle = skin_noise(skin_world_pos * 7.5);
	float pebble = skin_noise(skin_world_pos * 24.0);
	float pore = skin_noise(skin_world_pos * 61.0);
	float micro_relief = skin_noise(skin_world_pos * 96.0);
	float micro_grain = skin_noise(skin_world_pos * 164.0);
	float scale_rhythm = sin(skin_world_pos.x * 17.0
		+ skin_world_pos.z * 13.0
		+ sin(skin_world_pos.y * 9.0) * 0.7) * 0.5 + 0.5;
	float scale_edges = smoothstep(0.52, 0.94, scale_rhythm);
	vec3 skin = skin_tint.rgb * (0.78 + broad_mottle * 0.24 + fine_mottle * 0.12);
	skin = mix(skin, skin * vec3(1.12, 1.05, 0.88), scale_edges * 0.12);
	skin *= 0.96 + pebble * 0.07 + pore * 0.035 + micro_grain * 0.025;
	vec2 relief_gradient = clamp(vec2(dFdx(micro_relief), dFdy(micro_relief)) * 0.16,
		vec2(-0.08), vec2(0.08));
	NORMAL = normalize(NORMAL + vec3(-relief_gradient.x, -relief_gradient.y, 0.0) * micro_normal_strength);
	ALBEDO = skin;
	ROUGHNESS = clamp(0.79 + pebble * 0.13 + micro_grain * 0.05, 0.78, 0.97);
	SPECULAR = 0.10 + fine_mottle * 0.04;
	AO = clamp(0.94 + (micro_grain - 0.5) * 0.12, 0.86, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("skin_tint", base)
	material.set_shader_parameter("detail_scale", detail_scale)
	material.set_shader_parameter("micro_normal_strength", 0.07)
	return material

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
func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, surface: Variant, sides := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	mesh.radial_segments = maxi(sides, 16)
	var cylinder_material: Material
	if surface is Material:
		cylinder_material = surface
	else:
		cylinder_material = _material(surface as Color)
	return _mesh(parent, mesh, cylinder_material, pos)

func _add_scaled_mesh_multimesh(parent: Node3D, node_name: String, mesh: Mesh,
		positions: PackedVector3Array, scales: PackedVector3Array, material: Material,
		rotations: PackedFloat32Array) -> MultiMeshInstance3D:
	if positions.size() != scales.size() or (not rotations.is_empty() and rotations.size() != positions.size()):
		push_error("MultiMesh source arrays must have matching lengths: " + node_name)
		return null
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = positions.size()
	for index in range(positions.size()):
		var basis := Basis.from_scale(scales[index])
		if not rotations.is_empty():
			basis = Basis.from_euler(Vector3(0.0, 0.0, rotations[index])) * basis
		batch.set_instance_transform(index, Transform3D(basis, positions[index]))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = batch
	instance.material_override = material
	instance.set_meta("source_positions", positions)
	instance.set_meta("source_scales", scales)
	instance.set_meta("source_rotations", rotations)
	parent.add_child(instance)
	return instance

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
	e.ambient_light_color = Color(0.62, 0.52, 0.42)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.12
	e.ssao_enabled = true
	e.ssao_radius = 1.25
	e.ssao_intensity = 1.2
	e.sdfgi_enabled = true
	e.sdfgi_use_occlusion = true
	e.sdfgi_bounce_feedback = 0.72
	e.ssil_enabled = true
	e.ssil_intensity = 0.65
	# A restrained warm aerial haze separates distant mesas from the town and
	# keeps the sunset horizon readable without enabling costly volumetric fog.
	e.fog_enabled = true
	e.fog_light_color = Color(0.75, 0.58, 0.44)
	e.fog_density = 0.00035
	e.fog_sun_scatter = 0.14
	# Keep the procedural blue-to-ochre sky gradient visible above the dusty horizon.
	e.fog_sky_affect = 0.0
	e.volumetric_fog_enabled = false
	e.volumetric_fog_density = 0.0035
	e.volumetric_fog_albedo = Color(0.78, 0.68, 0.56)
	e.volumetric_fog_length = 180.0
	e.volumetric_fog_detail_spread = 1.5
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -28, 0)
	sun.light_color = Color(1.0, 0.77, 0.54)
	sun.light_energy = 1.4
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

func _terrain_wash_center(world_x: float) -> float:
	# A shallow, winding Arizona arroyo cuts across the open basin south of Red Rock.
	var bend_noise := (_terrain_fbm(Vector2(world_x * 0.045, 8.0)) - 0.5) * 4.0
	return -76.0 + sin(world_x * 0.018) * 16.0 + bend_noise

func _terrain_height(world_xz: Vector2) -> float:
	# Broad basin undulation, overlapping dune fields and a persistent arroyo profile
	# give the 1897 Arizona ground a readable landform instead of a near-flat plane.
	var basin := _terrain_fbm(world_xz * 0.010)
	var dune := _terrain_fbm(world_xz * 0.018)
	var fine_dune := _terrain_fbm(world_xz * 0.072)
	var basin_roll := sin(world_xz.x * 0.011 + basin * 2.2) * 0.24
	basin_roll += cos(world_xz.y * 0.013 - basin * 1.7) * 0.18
	var ripple := sin(world_xz.dot(Vector2(0.72, 0.69)) * 1.35
		+ _terrain_fbm(world_xz * 0.045) * 5.0)
	var wash_distance := absf(world_xz.y - _terrain_wash_center(world_xz.x))
	var channel := exp(-pow(wash_distance / 10.5, 2.0))
	var shoulder := exp(-pow((wash_distance - 15.5) / 6.0, 2.0))
	var wash_ripple := sin(world_xz.x * 0.65 + _terrain_fbm(world_xz * 0.12) * 2.0)
	wash_ripple *= 0.025 * exp(-wash_distance / 28.0)
	return (basin - 0.5) * 1.6 + (dune - 0.5) * 1.2 \
		+ (fine_dune - 0.5) * 0.30 + basin_roll + ripple * 0.05 \
		- channel * 0.78 + shoulder * 0.22 + wash_ripple

func _is_predator_sightline(angle: float) -> bool:
	var predator_bearing := Vector2(70.0, -112.0).angle()
	return absf(wrapf(angle - predator_bearing, -PI, PI)) < 0.28

func _make_terrain_mesh(segments: int, generate_normals: bool = true) -> ArrayMesh:
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
			# Godot's front-face winding is clockwise; keep the generated normals
			# facing up so the soil receives direct light and slope masks stay valid.
			surface.set_uv(Vector2(float(x) / segments, float(z) / segments))
			surface.add_vertex(a)
			surface.set_uv(Vector2(float(x + 1) / segments, float(z) / segments))
			surface.add_vertex(b)
			surface.set_uv(Vector2(float(x) / segments, float(z + 1) / segments))
			surface.add_vertex(c)
			surface.set_uv(Vector2(float(x + 1) / segments, float(z) / segments))
			surface.add_vertex(b)
			surface.set_uv(Vector2(float(x + 1) / segments, float(z + 1) / segments))
			surface.add_vertex(d)
			surface.set_uv(Vector2(float(x) / segments, float(z + 1) / segments))
			surface.add_vertex(c)
	if generate_normals:
		surface.generate_normals()
	return surface.commit()

func _build_landscape() -> void:
	# The visible dunes and the collision surface are generated from the same height function.
	# This removes the old mismatch where feet and rocks floated above a flat collision plane.
	var ground := _make_terrain_mesh(TERRAIN_MESH_SEGMENTS)
	ground.surface_set_material(0, _terrain_material())
	# Keep the 2 m visual grid for silhouettes and shading, but use a 2.71 m
	# collision grid from the same height function to cut static-triangle cost.
	var collision_mesh := _make_terrain_mesh(TERRAIN_COLLISION_SEGMENTS, false)
	var terrain := StaticBody3D.new()
	terrain.name = "ProceduralTerrain"
	add_child(terrain)
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = collision_mesh.create_trimesh_shape()
	terrain.add_child(ground_shape)
	var ground_instance := MeshInstance3D.new()
	ground_instance.name = "DuneSurface"
	ground_instance.mesh = ground
	terrain.add_child(ground_instance)
	for i in range(34):
		var angle := TAU * float(i) / 34.0
		# Leave a natural open break in the distant mesa ring so the predator
		# silhouette has an unobstructed line from the authored preview overlook.
		if _is_predator_sightline(angle):
			continue
		var radius := randf_range(125.0, 190.0)
		var rock_x := cos(angle) * radius
		var rock_z := sin(angle) * radius
		var p := Vector3(rock_x, _terrain_height(Vector2(rock_x, rock_z)), rock_z)
		_rock_formation(p, randf_range(0.8, 1.5))
	_scatter_boulders()
	_scatter_saguaros()
	_scatter_creosote_bushes()

func _append_cactus_tube(surface: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, base_color: Color, radial_segments: int = 16) -> void:
	var side_count := maxi(radial_segments, 6)
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
		for segment in range(side_count):
			var angle := TAU * float(segment) / float(side_count)
			var rib := 1.0 + 0.065 * cos(angle * 6.0)
			var radial := (axis_x * cos(angle) + axis_z * sin(angle)) * radii[ring_index] * rib
			ring.append(points[ring_index] + radial)
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(side_count):
			var next_segment := (segment + 1) % side_count
			var next_u := 1.0 if next_segment == 0 else float(next_segment) / float(side_count)
			var u := float(segment) / float(side_count)
			var v0 := float(ring_index) / float(maxi(1, rings.size() - 1))
			var v1 := float(ring_index + 1) / float(maxi(1, rings.size() - 1))
			var height_tint := 0.94 + 0.08 * v0
			var rib_tint := 0.96 + 0.04 * cos(TAU * u * 6.0)
			var tint := base_color * height_tint * rib_tint
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			surface.set_color(tint)
			surface.set_uv(Vector2(u, v0))
			surface.add_vertex(a)
			surface.set_uv(Vector2(next_u, v0))
			surface.add_vertex(b)
			surface.set_uv(Vector2(u, v1))
			surface.add_vertex(c)
			surface.set_color(tint)
			surface.set_uv(Vector2(next_u, v0))
			surface.add_vertex(b)
			surface.set_uv(Vector2(next_u, v1))
			surface.add_vertex(d)
			surface.set_uv(Vector2(u, v1))
			surface.add_vertex(c)
	# Cap the exposed ends so the cactus does not have hollow cut surfaces.
	var bottom_center := points[0]
	var top_center := points[points.size() - 1]
	for segment in range(side_count):
		var next_segment := (segment + 1) % side_count
		var u := float(segment) / float(side_count)
		var next_u := 1.0 if next_segment == 0 else float(next_segment) / float(side_count)
		surface.set_color(base_color * 0.88)
		surface.set_uv(Vector2(0.5, 0.0))
		surface.add_vertex(bottom_center)
		surface.set_uv(Vector2(next_u, 0.0))
		surface.add_vertex(rings[0][next_segment])
		surface.set_uv(Vector2(u, 0.0))
		surface.add_vertex(rings[0][segment])
		surface.set_color(base_color * 0.96)
		surface.set_uv(Vector2(0.5, 1.0))
		surface.add_vertex(top_center)
		surface.set_uv(Vector2(u, 1.0))
		surface.add_vertex(rings[rings.size() - 1][segment])
		surface.set_uv(Vector2(next_u, 1.0))
		surface.add_vertex(rings[rings.size() - 1][next_segment])

func _saguaro_surface_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec2 cactus_uv;
float cactus_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void vertex() {
	cactus_uv = UV;
}
void fragment() {
	float rib_phase = cos(cactus_uv.x * 37.6991118);
	float rib_highlight = smoothstep(-0.1, 0.82, rib_phase);
	float rib_shadow = 1.0 - smoothstep(-0.72, -0.10, rib_phase);
	float rib_center = abs(fract(cactus_uv.x * 6.0 + 0.5) - 0.5);
	float row_center = abs(fract(cactus_uv.y * 18.0) - 0.5);
	float areole_distance = length(vec2(rib_center * 6.0, row_center * 18.0));
	float areole = 1.0 - smoothstep(0.055, 0.18, areole_distance);
	float spine_cell = cactus_hash(floor(cactus_uv * vec2(144.0, 144.0)));
	float spine_fleck = step(0.58, spine_cell) * areole;
	vec3 cactus = COLOR.rgb * (0.88 + rib_highlight * 0.16 - rib_shadow * 0.07);
	cactus = mix(cactus, vec3(0.68, 0.64, 0.48), areole * 0.42);
	cactus = mix(cactus, vec3(0.88, 0.83, 0.69), spine_fleck * 0.62);
	ALBEDO = cactus;
	ROUGHNESS = clamp(0.87 + areole * 0.07 + spine_fleck * 0.04, 0.86, 0.98);
	SPECULAR = 0.08;
	AO = clamp(0.96 - areole * 0.08, 0.88, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _make_saguaro_mesh(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green: Color = [Color(0.19, 0.32, 0.19), Color(0.23, 0.34, 0.19), Color(0.17, 0.29, 0.17)][variant]
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
	mesh.surface_set_material(0, _saguaro_surface_material())
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

func _append_creosote_leaf(surface: SurfaceTool, center: Vector3, direction: Vector3, width: float, tint: Color) -> void:
	# A four-ring, five-sided lens gives each narrow leaf real volume instead of a flat spike.
	var forward := direction.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var normal := side.cross(forward).normalized()
	var ring_positions := [0.0, 0.44, 1.0]
	var ring_widths := [0.10, 0.82, 0.015]
	var rings: Array[PackedVector3Array] = []
	for ring_index in range(ring_positions.size()):
		var t: float = ring_positions[ring_index]
		var radius: float = width * float(ring_widths[ring_index])
		var ring_center := center + forward * ((t - 0.35) * width * 3.8)
		var ring := PackedVector3Array()
		for segment in range(4):
			var angle := TAU * float(segment) / 4.0
			ring.append(ring_center + side * cos(angle) * radius
				+ normal * sin(angle) * radius * 0.42)
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(4):
			var next_segment := (segment + 1) % 4
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			surface.set_color(tint.darkened(0.08))
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.set_color(tint.lightened(0.06))
			surface.add_vertex(b)
			surface.add_vertex(d)
			surface.add_vertex(c)

func _make_creosote_mesh(variant: int) -> ArrayMesh:
	# Creosote is a low, woody shrub native to the Sonoran/Mojave transition.
	# Branches and paired narrow leaves are authored into one instanced mesh.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var branch_count := 8 + clampi(variant, 0, 2)
	var twig_color := Color(0.25, 0.17, 0.095)
	var leaf_palette: Array[Color] = [
		Color(0.36, 0.43, 0.20),
		Color(0.43, 0.49, 0.23),
		Color(0.50, 0.51, 0.27)
	]
	for branch in range(branch_count):
		var angle := TAU * float(branch) / float(branch_count) + float(variant) * 0.19
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-outward.z, 0.0, outward.x)
		var height := 0.68 + float((branch * 3 + variant) % 4) * 0.10
		var spread := 0.56 + float((branch + variant) % 3) * 0.11
		var curl := side * sin(angle * 2.0 + float(variant)) * 0.09
		var points := PackedVector3Array([
			Vector3.ZERO,
			outward * spread * 0.40 + curl * 0.4 + Vector3.UP * height * 0.42,
			outward * spread + curl + Vector3.UP * height
		])
		# Eight-sided woody branches retain a round silhouette at a fraction of the
		# vertex cost of the shared 16-sided saguaro tube builder.
		_append_cactus_tube(surface, points,
			PackedFloat32Array([0.060, 0.038, 0.016]), twig_color, 8)
		var leaf_color: Color = leaf_palette[(branch + variant) % leaf_palette.size()]
		var branch_direction := (points[2] - points[1]).normalized()
		# Two paired leaf tiers and one terminal leaf keep a rounded canopy while
		# avoiding the dense, spiky overdraw that stalled the software-rendered route.
		for leaf_row in range(2):
			var t := 0.38 + float(leaf_row) * 0.34
			var center := points[1].lerp(points[2], t)
			var leaf_direction := (outward * 0.7 + branch_direction * 0.45 + Vector3.UP * 0.18).normalized()
			var leaf_side := side * (1.0 if leaf_row == 0 else -1.0)
			_append_creosote_leaf(surface, center,
				(leaf_direction + leaf_side * 0.9).normalized(), 0.045, leaf_color)
			_append_creosote_leaf(surface, center,
				(leaf_direction - leaf_side * 0.9).normalized(), 0.045, leaf_color.lightened(0.05))
		_append_creosote_leaf(surface, points[2],
			(outward + Vector3.UP * 0.5).normalized(), 0.036, leaf_color.lightened(0.08))
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.96
	mesh.surface_set_material(0, material)
	return mesh

func _scatter_creosote_bushes() -> void:
	# Seeded placement avoids the town, herd, predator vista and active arroyo channel.
	# Three shared meshes keep the additional ground cover to three instanced draw calls.
	for variant in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1897 + variant * 1543
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _make_creosote_mesh(variant)
		multimesh.instance_count = 42
		multimesh.custom_aabb = AABB(Vector3(-130.0, -1.0, -130.0), Vector3(260.0, 4.0, 260.0))
		var bushes := MultiMeshInstance3D.new()
		bushes.name = "CreosoteBushes_" + str(variant)
		bushes.multimesh = multimesh
		bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(bushes)
		var placement_positions := PackedVector3Array()
		for index in range(multimesh.instance_count):
			var x := 0.0
			var z := 0.0
			var placed := false
			for attempt in range(400):
				x = rng.randf_range(-118.0, 118.0)
				z = rng.randf_range(-118.0, 118.0)
				var radial := Vector2(x, z).length()
				if radial < 36.0 or radial > 130.0:
					continue
				if absf(z - _terrain_wash_center(x)) < 12.0:
					continue
				if Vector2(x + 31.0, z + 52.0).length() < 18.0:
					continue
				if Vector2(x + 39.0, z + 59.0).length() < 15.0:
					continue
				if Vector2(x + 23.0, z + 62.0).length() < 15.0:
					continue
				if Vector2(x - 70.0, z + 112.0).length() < 20.0:
					continue
				placed = true
				break
			if not placed:
				x = 80.0 + float(variant) * 2.0
				z = 80.0 + float(index) * 0.15
			var scale_factor := rng.randf_range(0.86, 1.42)
			var yaw := rng.randf_range(0.0, TAU)
			var scale := Vector3(
				scale_factor * rng.randf_range(0.9, 1.1),
				scale_factor,
				scale_factor * rng.randf_range(0.9, 1.1)
			)
			var position := Vector3(x, _terrain_height(Vector2(x, z)), z)
			placement_positions.append(position)
			multimesh.set_instance_transform(index,
				Transform3D(Basis(Vector3.UP, yaw).scaled(scale), position))
		bushes.set_meta("placement_positions", placement_positions)

func _rock_surface_material() -> ShaderMaterial:
	var rock_shader := Shader.new()
	rock_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 rock_world_pos;
float rock_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float rock_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(rock_hash(i), rock_hash(i + vec3(1,0,0)), f.x),
			mix(rock_hash(i + vec3(0,1,0)), rock_hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(rock_hash(i + vec3(0,0,1)), rock_hash(i + vec3(1,0,1)), f.x),
			mix(rock_hash(i + vec3(0,1,1)), rock_hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	rock_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float broad = rock_noise(rock_world_pos * vec3(0.42, 0.19, 0.42));
	float grain = rock_noise(rock_world_pos * vec3(5.8, 3.2, 5.8));
	float pores = rock_noise(rock_world_pos * vec3(24.0, 15.0, 24.0));
	float fine_grain = rock_noise(rock_world_pos * vec3(38.0, 22.0, 38.0));
	// Reuse the fine-grain field for normal detail; avoid another high-frequency
	// noise evaluation on every rock fragment in the software-rendered preview.
	float micro_relief = fine_grain;
	float sediment = sin((rock_world_pos.y * 3.4 + broad * 0.7 + grain * 0.12) * 6.28318) * 0.5 + 0.5;
	float bedding = smoothstep(0.56, 0.94, sediment);
	float fracture = smoothstep(0.80, 0.95, grain * 0.42 + pores * 0.58);
	float erosion = smoothstep(0.58, 0.88, pores);
	vec3 stone = COLOR.rgb * (0.82 + broad * 0.2 + grain * 0.08 + fine_grain * 0.035);
	stone = mix(stone, stone * vec3(0.68, 0.62, 0.55), bedding * 0.24);
	stone = mix(stone, stone * vec3(0.56, 0.51, 0.46), fracture * 0.16);
	stone *= 1.0 - erosion * 0.12;
	vec2 relief_gradient = clamp(vec2(dFdx(micro_relief), dFdy(micro_relief)) * 0.22,
		vec2(-0.08), vec2(0.08));
	NORMAL = normalize(NORMAL + vec3(-relief_gradient.x, -relief_gradient.y, 0.0) * 0.028);
	ALBEDO = stone;
	ROUGHNESS = clamp(0.86 + pores * 0.08 + fine_grain * 0.05, 0.86, 0.99);
	SPECULAR = 0.10;
	AO = clamp(0.95 - fracture * 0.10 - erosion * 0.04, 0.80, 1.0);
}
"""
	var rock_material := ShaderMaterial.new()
	rock_material.shader = rock_shader
	return rock_material

func _make_rock_lod_mesh(rings: Array) -> ArrayMesh:
	# The distant silhouette samples every second point from the sixteen-sided near mesh.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layer_indices := [0, 2, 4]
	var lod_strata := [
		Color(0.31, 0.145, 0.105),
		Color(0.39, 0.19, 0.135)
	]
	for layer in range(layer_indices.size() - 1):
		var lower_ring: PackedVector3Array = rings[layer_indices[layer]]
		var upper_ring: PackedVector3Array = rings[layer_indices[layer + 1]]
		for segment in range(8):
			var next_segment: int = (segment + 1) % 8
			var lower_a: Vector3 = lower_ring[segment * 2]
			var lower_b: Vector3 = lower_ring[next_segment * 2]
			var upper_a: Vector3 = upper_ring[segment * 2]
			var upper_b: Vector3 = upper_ring[next_segment * 2]
			surface.set_color(lod_strata[layer])
			surface.add_vertex(lower_a)
			surface.add_vertex(upper_a)
			surface.add_vertex(lower_b)
			surface.add_vertex(lower_b)
			surface.add_vertex(upper_a)
			surface.add_vertex(upper_b)
	var top_ring: PackedVector3Array = rings[4]
	var crown := Vector3.ZERO
	for point in top_ring:
		crown += point
	crown /= float(top_ring.size())
	for segment in range(8):
		var next_segment: int = (segment + 1) % 8
		surface.set_color(Color(0.52, 0.29, 0.21))
		surface.add_vertex(crown)
		surface.add_vertex(top_ring[next_segment * 2])
		surface.add_vertex(top_ring[segment * 2])
	var base_ring: PackedVector3Array = rings[0]
	var base_center := Vector3.ZERO
	for point in base_ring:
		base_center += point
	base_center /= float(base_ring.size())
	for segment in range(8):
		var next_segment: int = (segment + 1) % 8
		surface.set_color(Color(0.27, 0.12, 0.09))
		surface.add_vertex(base_center)
		surface.add_vertex(base_ring[segment * 2])
		surface.add_vertex(base_ring[next_segment * 2])
	surface.generate_normals()
	return surface.commit()

func _rock_formation(pos: Vector3, factor: float) -> void:
	# A sixteen-sided layered outcrop adds broken ledges and non-repeating weathered edges.
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(Vector2i(roundi(pos.x * 10.0), roundi(pos.z * 10.0))))
	var heights := [0.0, 2.2, 4.8, 7.1, 8.6]
	var radii := [8.8, 8.1, 6.9, 5.5, 3.8]
	var ring_segments := 16
	var rings: Array = []
	for layer in range(heights.size()):
		var ring := PackedVector3Array()
		for segment in range(ring_segments):
			var angle := TAU * float(segment) / float(ring_segments) + rng.randf_range(-0.025, 0.025)
			var broad_ridge := sin(angle * 3.0 + float(layer) * 0.43) * 0.055
			var broken_edge := sin(angle * 7.0 - float(layer) * 0.31) * 0.018
			var radius := float(radii[layer]) * (
				1.0 + broad_ridge + broken_edge + rng.randf_range(-0.045, 0.045))
			var ledge := sin(angle * 2.0 + float(layer) * 0.38) * 0.12
			var layer_height := float(heights[layer]) + ledge + rng.randf_range(-0.12, 0.12)
			ring.append(Vector3(cos(angle) * radius, layer_height, sin(angle) * radius))
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
		for segment in range(ring_segments):
			var next_segment: int = (segment + 1) % ring_segments
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
	# Close both ends so the rock remains watertight at steep camera angles.
	var crown := Vector3.ZERO
	for point in rings[heights.size() - 1]:
		crown += point
	crown /= float(rings[heights.size() - 1].size())
	for segment in range(ring_segments):
		var next_segment: int = (segment + 1) % ring_segments
		surface.set_color(Color(0.52, 0.29, 0.21))
		surface.add_vertex(crown)
		surface.add_vertex(rings[heights.size() - 1][next_segment])
		surface.add_vertex(rings[heights.size() - 1][segment])
	var base_center := Vector3.ZERO
	for point in rings[0]:
		base_center += point
	base_center /= float(rings[0].size())
	for segment in range(ring_segments):
		var next_segment: int = (segment + 1) % ring_segments
		surface.set_color(Color(0.27, 0.12, 0.09))
		surface.add_vertex(base_center)
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(rings[0][next_segment])
	surface.generate_normals()
	var rock_mesh := surface.commit()
	var rock_material := _rock_surface_material()
	var rock_body := StaticBody3D.new()
	rock_body.name = "RockFormation"
	rock_body.position = pos
	rock_body.scale = Vector3.ONE * factor
	add_child(rock_body)
	var rock_instance := MeshInstance3D.new()
	rock_instance.name = "RockHighDetail"
	rock_instance.mesh = rock_mesh
	rock_instance.material_override = rock_material
	rock_instance.visibility_range_end = 132.0
	rock_instance.visibility_range_end_margin = 14.0
	rock_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	rock_body.add_child(rock_instance)
	var lod_instance := MeshInstance3D.new()
	lod_instance.name = "RockDistantLOD"
	lod_instance.mesh = _make_rock_lod_mesh(rings)
	lod_instance.material_override = rock_material
	lod_instance.visibility_range_begin = 118.0
	lod_instance.visibility_range_begin_margin = 14.0
	lod_instance.visibility_range_end = 420.0
	lod_instance.visibility_range_end_margin = 35.0
	lod_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	rock_body.add_child(lod_instance)
	var rock_collision := CollisionShape3D.new()
	rock_collision.name = "RockCollision"
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
		var rock_material := _rock_surface_material()
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
				# Match the large boulder's faceted silhouette instead of using a loose box.
				collision.shape = rock_mesh.create_convex_shape()
				collision.scale = scale
				body.add_child(collision)

func _add_building_details(root: Node3D, wall: Color, porch: bool) -> void:
	var wood := _weathered_wood_material(wall.darkened(0.22))
	var trim := _weathered_wood_material(Color(0.19, 0.105, 0.065))
	var glass := _material(Color(0.12, 0.22, 0.25), 0.22, 0.12)
	var porch_wood := _weathered_wood_material(Color(0.3, 0.2, 0.13))
	# Horizontal siding stops at the doorway, keeping the open entrance readable.
	for y in [0.55, 1.0, 1.45, 1.9, 2.35, 2.8, 3.25]:
		for side in [-1.0, 1.0]:
			_box(root, Vector3(side * 2.9, y, 3.57), Vector3(4.15, 0.055, 0.035), wood)
	for x in [-4.82, 4.82]:
		_box(root, Vector3(x, 2.1, 3.62), Vector3(0.16, 4.0, 0.12), trim)
	for x in [-3.3, 3.3]:
		_box(root, Vector3(x, 2.1, 3.91), Vector3(1.52, 1.95, 0.12), trim)
		_box(root, Vector3(x, 2.1, 3.99), Vector3(1.25, 1.62, 0.035), glass)
		_box(root, Vector3(x, 2.1, 4.02), Vector3(0.09, 1.7, 0.045), wood)
		_box(root, Vector3(x, 2.1, 4.03), Vector3(1.3, 0.09, 0.045), wood)
		_box(root, Vector3(x, 3.13, 3.92), Vector3(1.75, 0.16, 0.22), trim)
		_box(root, Vector3(x, 1.07, 3.92), Vector3(1.75, 0.16, 0.22), trim)

	# Paired plank shutters sit outside the glass line. Panels, slats and iron
	# straps are batched separately so the six-building street front gains depth
	# without multiplying dozens of individual draw calls per facade.
	var shutter_panel_batch := MultiMesh.new()
	shutter_panel_batch.transform_format = MultiMesh.TRANSFORM_3D
	var shutter_panel_mesh := BoxMesh.new()
	shutter_panel_mesh.size = Vector3.ONE
	shutter_panel_batch.mesh = shutter_panel_mesh
	shutter_panel_batch.instance_count = 4
	var shutter_slat_batch := MultiMesh.new()
	shutter_slat_batch.transform_format = MultiMesh.TRANSFORM_3D
	var shutter_slat_mesh := BoxMesh.new()
	shutter_slat_mesh.size = Vector3.ONE
	shutter_slat_batch.mesh = shutter_slat_mesh
	shutter_slat_batch.instance_count = 16
	var shutter_hinge_batch := MultiMesh.new()
	shutter_hinge_batch.transform_format = MultiMesh.TRANSFORM_3D
	var shutter_hinge_mesh := BoxMesh.new()
	shutter_hinge_mesh.size = Vector3.ONE
	shutter_hinge_batch.mesh = shutter_hinge_mesh
	shutter_hinge_batch.instance_count = 8
	var shutter_positions := PackedVector3Array()
	var slat_positions := PackedVector3Array()
	var hinge_positions := PackedVector3Array()
	var panel_index := 0
	var slat_index := 0
	var hinge_index := 0
	for window_x in [-3.3, 3.3]:
		for side in [-1.0, 1.0]:
			var shutter_x: float = float(window_x) + float(side) * 0.95
			var panel_position := Vector3(shutter_x, 2.1, 4.075)
			var panel_size := Vector3(0.30, 1.56, 0.09)
			shutter_panel_batch.set_instance_transform(panel_index,
				Transform3D(Basis.from_scale(panel_size), panel_position))
			shutter_positions.append(panel_position)
			panel_index += 1
			for slat_y in [-0.48, -0.16, 0.16, 0.48]:
				var slat_position := Vector3(shutter_x, 2.1 + slat_y, 4.135)
				var slat_size := Vector3(0.34, 0.075, 0.12)
				shutter_slat_batch.set_instance_transform(slat_index,
					Transform3D(Basis.from_scale(slat_size), slat_position))
				slat_positions.append(slat_position)
				slat_index += 1
			for hinge_y in [-0.48, 0.48]:
				var hinge_position := Vector3(window_x + side * 0.79,
					2.1 + hinge_y, 4.17)
				var hinge_size := Vector3(0.055, 0.22, 0.035)
				shutter_hinge_batch.set_instance_transform(hinge_index,
					Transform3D(Basis.from_scale(hinge_size), hinge_position))
				hinge_positions.append(hinge_position)
				hinge_index += 1
	var shutter_panels := MultiMeshInstance3D.new()
	shutter_panels.name = "FrontWindowShutterPanels"
	shutter_panels.multimesh = shutter_panel_batch
	shutter_panels.material_override = _weathered_wood_material(wall.darkened(0.36))
	shutter_panels.set_meta("source_positions", shutter_positions)
	root.add_child(shutter_panels)
	var shutter_slats := MultiMeshInstance3D.new()
	shutter_slats.name = "FrontWindowShutterSlats"
	shutter_slats.multimesh = shutter_slat_batch
	shutter_slats.material_override = wood
	shutter_slats.set_meta("source_positions", slat_positions)
	root.add_child(shutter_slats)
	var shutter_hinges := MultiMeshInstance3D.new()
	shutter_hinges.name = "FrontWindowShutterHinges"
	shutter_hinges.multimesh = shutter_hinge_batch
	shutter_hinges.material_override = _material(Color(0.075, 0.065, 0.052), 0.58, 0.72)
	shutter_hinges.set_meta("source_positions", hinge_positions)
	root.add_child(shutter_hinges)
	for x in [-4.0, -2.0, -1.0, 1.0, 2.0, 4.0]:
		_box(root, Vector3(x, 2.1, 3.62), Vector3(0.045, 4.0, 0.055), wood)
	# Side elevations use exposed structural framing, but keep the repeated
	# posts/rails in two MultiMesh batches per building to avoid dozens of extra
	# draw calls across the six-building settlement.
	var side_trim_positions := PackedVector3Array()
	var side_trim_scales := PackedVector3Array()
	var side_rafter_positions := PackedVector3Array()
	var side_rafter_scales := PackedVector3Array()
	var side_course_positions := PackedVector3Array()
	var side_course_scales := PackedVector3Array()
	for side in [-1.0, 1.0]:
		for y in [0.55, 1.0, 1.45, 1.9, 2.35, 2.8, 3.25]:
			side_course_positions.append(Vector3(side * 5.02, y, 0.0))
			side_course_scales.append(Vector3(0.035, 0.055, 6.85))
		for z in [-3.36, 0.0, 3.36]:
			side_trim_positions.append(Vector3(side * 5.07, 2.05, z))
			side_trim_scales.append(Vector3(0.15, 3.95, 0.17))
		for y in [0.42, 3.72]:
			side_trim_positions.append(Vector3(side * 5.07, y, 0.0))
			side_trim_scales.append(Vector3(0.16, 0.18, 6.95))
		# Continuous eaves fascia and five exposed rafter tails give the side roof
		# a legible load-bearing transition instead of a floating flat overhang.
		side_trim_positions.append(Vector3(side * 5.48, 5.35, 0.0))
		side_trim_scales.append(Vector3(0.18, 0.22, 8.15))
		for z in [-3.75, -1.875, 0.0, 1.875, 3.75]:
			side_rafter_positions.append(Vector3(side * 5.20, 5.14, z))
			side_rafter_scales.append(Vector3(0.48, 0.18, 0.20))
	var side_course_mesh := BoxMesh.new()
	side_course_mesh.size = Vector3.ONE
	_add_scaled_mesh_multimesh(root, "SideSidingCourseBatch", side_course_mesh,
		side_course_positions, side_course_scales, wood, PackedFloat32Array())
	var side_trim_mesh := BoxMesh.new()
	side_trim_mesh.size = Vector3.ONE
	_add_scaled_mesh_multimesh(root, "SideElevationTrimBatch", side_trim_mesh,
		side_trim_positions, side_trim_scales, trim, PackedFloat32Array())
	var side_rafter_mesh := BoxMesh.new()
	side_rafter_mesh.size = Vector3.ONE
	_add_scaled_mesh_multimesh(root, "SideRafterTailBatch", side_rafter_mesh,
		side_rafter_positions, side_rafter_scales, wood, PackedFloat32Array())
	# Layered front fascia and exposed rafter ends break up the street roof silhouette.
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

func _append_desert_grass_blade(surface: SurfaceTool, root: Vector3, direction: Vector3,
		height: float, width: float, bend: float, tint: Color) -> void:
	var forward := Vector3(direction.x, 0.0, direction.z).normalized()
	var side := Vector3.UP.cross(forward).normalized()
	var longitudinal := [0.0, 0.32, 0.70, 1.0]
	var width_profile := [0.12, 0.72, 0.42, 0.015]
	var left_edges: Array[Vector3] = []
	var center_ridges: Array[Vector3] = []
	var right_edges: Array[Vector3] = []
	for ring in range(longitudinal.size()):
		var t: float = longitudinal[ring]
		var center := root + Vector3.UP * (height * t)
		center += forward * (bend * t * t) + side * (bend * 0.18 * t * t)
		var half_width := width * float(width_profile[ring]) * 0.5
		left_edges.append(center - side * half_width)
		center_ridges.append(center + Vector3.UP * (width * 0.12 * (1.0 - t)))
		right_edges.append(center + side * half_width)
	for segment in range(longitudinal.size() - 1):
		var t := float(segment) / float(longitudinal.size() - 1)
		var blade_tint := tint.lerp(Color(0.66, 0.59, 0.31), t * 0.22)
		var left_a: Vector3 = left_edges[segment]
		var ridge_a: Vector3 = center_ridges[segment]
		var right_a: Vector3 = right_edges[segment]
		var left_b: Vector3 = left_edges[segment + 1]
		var ridge_b: Vector3 = center_ridges[segment + 1]
		var right_b: Vector3 = right_edges[segment + 1]
		surface.set_color(blade_tint.darkened(0.10))
		surface.add_vertex(left_a)
		surface.set_color(blade_tint.lightened(0.06))
		surface.add_vertex(ridge_a)
		surface.set_color(blade_tint.darkened(0.06))
		surface.add_vertex(left_b)
		surface.set_color(blade_tint.lightened(0.06))
		surface.add_vertex(ridge_a)
		surface.set_color(blade_tint.lightened(0.12))
		surface.add_vertex(ridge_b)
		surface.set_color(blade_tint.darkened(0.06))
		surface.add_vertex(left_b)
		surface.set_color(blade_tint.lightened(0.06))
		surface.add_vertex(ridge_a)
		surface.set_color(blade_tint)
		surface.add_vertex(right_a)
		surface.set_color(blade_tint.lightened(0.12))
		surface.add_vertex(ridge_b)
		surface.set_color(blade_tint)
		surface.add_vertex(right_a)
		surface.set_color(blade_tint.darkened(0.02))
		surface.add_vertex(right_b)
		surface.set_color(blade_tint.lightened(0.12))
		surface.add_vertex(ridge_b)

func _make_desert_tuft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_colors := [
		Color(0.38, 0.34, 0.19),
		Color(0.49, 0.42, 0.23),
		Color(0.29, 0.30, 0.17),
		Color(0.55, 0.46, 0.26)
	]
	for blade in range(7):
		var angle := TAU * float(blade) / 7.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var height := 0.25 + 0.075 * float((blade * 3) % 5) / 4.0
		var width := 0.07 + 0.018 * float(blade % 3)
		var bend := 0.045 + 0.025 * float((blade + 1) % 3)
		var root := direction * (0.018 + 0.012 * float(blade % 2))
		var tint: Color = blade_colors[(blade * 3) % blade_colors.size()]
		_append_desert_grass_blade(surface, root, direction, height, width, bend, tint)
	surface.generate_normals()
	var mesh := surface.commit()
	var grass_shader := Shader.new()
	grass_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * 1.25 + INSTANCE_CUSTOM.r * 6.28318
		+ world_position.x * 0.16 + world_position.z * 0.11;
	float gust = sin(TIME * 0.32 + INSTANCE_CUSTOM.g * 6.28318) * 0.5;
	float sway = cos(phase) * 0.038 + gust * 0.012;
	VERTEX.x += sin(phase) * 0.048 * VERTEX.y;
	VERTEX.z += cos(phase * 0.83) * 0.024 * VERTEX.y;
	NORMAL = normalize(vec3(NORMAL.x - sway * NORMAL.y, NORMAL.y,
		NORMAL.z - sway * 0.45 * NORMAL.y));
}
void fragment() {
	float sun_bleach = clamp(world_position.y * 0.8, 0.0, 0.12);
	ALBEDO = COLOR.rgb + vec3(sun_bleach, sun_bleach * 0.82, sun_bleach * 0.5);
	ROUGHNESS = 0.98;
	SPECULAR = 0.03;
}
"""
	var material := ShaderMaterial.new()
	material.shader = grass_shader
	mesh.surface_set_material(0, material)
	return mesh

func _make_desert_pebble_mesh(variant: int) -> ArrayMesh:
	# A single icosphere subdivision keeps the stones angular without the cost of spheres.
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
	for index in range(vertices.size()):
		vertices[index] = vertices[index].normalized()
	var refined := PackedInt32Array()
	var midpoint_cache: Dictionary = {}
	for face_index in range(0, faces.size(), 3):
		var a: int = faces[face_index]
		var b: int = faces[face_index + 1]
		var c: int = faces[face_index + 2]
		var edge_keys := [
			mini(a, b) * 10000 + maxi(a, b),
			mini(b, c) * 10000 + maxi(b, c),
			mini(c, a) * 10000 + maxi(c, a)
		]
		var midpoint_indices: Array[int] = []
		var edge_vertices := [[a, b], [b, c], [c, a]]
		for edge_index in range(3):
			var key: int = edge_keys[edge_index]
			if midpoint_cache.has(key):
				midpoint_indices.append(int(midpoint_cache[key]))
			else:
				var pair: Array = edge_vertices[edge_index]
				vertices.append((vertices[pair[0]] + vertices[pair[1]]).normalized())
				var midpoint_index := vertices.size() - 1
				midpoint_cache[key] = midpoint_index
				midpoint_indices.append(midpoint_index)
		var ab: int = midpoint_indices[0]
		var bc: int = midpoint_indices[1]
		var ca: int = midpoint_indices[2]
		refined.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
	faces = refined
	var shapes: Array[Vector3] = [
		Vector3(0.56, 0.24, 0.43),
		Vector3(0.48, 0.29, 0.53)
	]
	var shape: Vector3 = shapes[clampi(variant, 0, shapes.size() - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 189700 + clampi(variant, 0, 1) * 7919
	var weathered_vertices := PackedVector3Array()
	var vertex_colors := PackedColorArray()
	for vertex in vertices:
		var direction := vertex.normalized()
		var radial := rng.randf_range(0.93, 1.07)
		weathered_vertices.append(Vector3(
			direction.x * shape.x,
			direction.y * shape.y,
			direction.z * shape.z
		) * radial)
		var sediment := clampf((direction.y + 1.0) * 0.5 + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
		vertex_colors.append(
			Color(0.30, 0.18, 0.12).lerp(Color(0.57, 0.39, 0.25), sediment * 0.48))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face_index in range(0, faces.size(), 3):
		for corner in range(3):
			var vertex_index: int = faces[face_index + corner]
			var tint: Color = vertex_colors[vertex_index] * rng.randf_range(0.96, 1.04)
			surface.set_color(tint)
			surface.add_vertex(weathered_vertices[vertex_index])
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	mesh.surface_set_material(0, material)
	return mesh

func _scatter_ground_detail() -> void:
	# Keep hundreds of small ground accents in a handful of instanced draw calls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 189711
	var grass_multimesh := MultiMesh.new()
	grass_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass_multimesh.use_custom_data = true
	grass_multimesh.mesh = _make_desert_tuft_mesh()
	grass_multimesh.instance_count = 520
	grass_multimesh.custom_aabb = AABB(Vector3(-130, -1, -130), Vector3(260, 4, 260))
	var grass := MultiMeshInstance3D.new()
	grass.name = "DesertGrassTufts"
	grass.multimesh = grass_multimesh
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	var grass_positions := PackedVector3Array()
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
		var grass_position := Vector3(x, _terrain_height(Vector2(x, z)), z)
		grass_multimesh.set_instance_transform(i, Transform3D(basis, grass_position))
		grass_multimesh.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0.0, 1.0))
		grass_positions.append(grass_position)
	grass.set_meta("placement_positions", grass_positions)
	for variant in range(2):
		var stones := MultiMesh.new()
		stones.transform_format = MultiMesh.TRANSFORM_3D
		stones.mesh = _make_desert_pebble_mesh(variant)
		stones.instance_count = 170
		stones.custom_aabb = AABB(Vector3(-130, -1, -130), Vector3(260, 3, 260))
		var stone_batch := MultiMeshInstance3D.new()
		stone_batch.name = "DesertPebbles_" + str(variant)
		stone_batch.multimesh = stones
		stone_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stone_batch)
		var placement_positions := PackedVector3Array()
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
			var ground_height: float = _terrain_height(Vector2(x, z))
			var position := Vector3(x, ground_height + 0.035, z)
			placement_positions.append(position)
			stones.set_instance_transform(i, Transform3D(
				Basis(Vector3.UP, yaw).scaled(scale), position))
		stone_batch.set_meta("placement_positions", placement_positions)

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
	vec3 base = mix(vec3(0.24, 0.15, 0.095), vec3(0.42, 0.28, 0.18), dust);
	base *= 0.88 + gravel * 0.18 + fine * 0.07;
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
	if _weathered_wood_shader == null:
		_weathered_wood_shader = Shader.new()
		_weathered_wood_shader.code = """
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
	float fine_fiber = sin((world_pos.x + world_pos.z * 0.31 + fine * 0.16) * grain_scale * 9.42478);
	float grain_lines = smoothstep(0.76, 0.96, fine_fiber * 0.5 + 0.5);
	float knots = smoothstep(0.76, 0.96, noise3(world_pos * 1.7 + vec3(4.2, 0.0, 8.1)));
	float pores = noise3(world_pos * 18.0);
	float wood_checks = smoothstep(0.78, 0.95, pores)
		* (1.0 - smoothstep(0.82, 0.97, fine_fiber * 0.5 + 0.5));
	vec3 color = mix(tint.rgb * 0.48, tint.rgb * (1.0 + grain * 0.22), 0.42 + broad * 0.38);
	color = mix(color, tint.rgb * 0.54, grain_lines * 0.16);
	color = mix(color, tint.rgb * 0.24, wood_checks * 0.34);
	color = mix(color, tint.rgb * 0.34, knots * 0.42);
	color *= 0.88 + fine * 0.18 + pores * 0.055;
	float bleach = smoothstep(0.48, 0.92, noise3(world_pos * 0.42 + vec3(13.0))) * 0.6;
	color = mix(color, color * vec3(1.24, 1.12, 0.88), bleach * 0.22);
	ALBEDO = color;
	ROUGHNESS = clamp(0.76 + pores * 0.20 + wood_checks * 0.035, 0.76, 0.99);
	SPECULAR = 0.12;
	AO = clamp(0.98 - wood_checks * 0.12 - knots * 0.06, 0.78, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = _weathered_wood_shader
	material.set_shader_parameter("tint", base)
	material.set_shader_parameter("grain_scale", 1.8 if roof else 5.0)
	return material

func _roof_shingle_surface_material() -> StandardMaterial3D:
	if _roof_shingle_material == null:
		_roof_shingle_material = StandardMaterial3D.new()
		_roof_shingle_material.vertex_color_use_as_albedo = true
		_roof_shingle_material.roughness = 0.94
		_roof_shingle_material.metallic = 0.0
	return _roof_shingle_material

func _add_building_wall_piece(root: Node3D, body: StaticBody3D, center: Vector3, size: Vector3, surface: Material) -> void:
	_box(root, center, size, surface)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

func _make_roof_shingle_mesh(seed_value: int) -> ArrayMesh:
	# Individual overlapping cedar courses follow both gable planes. The staggered
	# joints and restrained color variation break the roof's single-flat-surface look.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row_count := 7
	var column_count := 11
	var row_step := 0.75
	var tile_length := 0.9
	var column_step := 0.76
	var tile_width := 0.70
	for side in [-1.0, 1.0]:
		for row in range(row_count):
			var inner_x := 0.05 + float(row) * row_step
			var outer_x := minf(inner_x + tile_length, 5.45)
			var stagger := 0.38 if row % 2 == 1 else 0.0
			for column in range(column_count):
				var z0 := -4.0 + float(column) * column_step + stagger
				if z0 >= 4.05:
					continue
				var z1 := minf(z0 + tile_width, 4.05)
				z0 = maxf(z0, -4.05)
				var inner_y := 7.25 - inner_x * 0.49 + 0.035
				var outer_y := 7.25 - outer_x * 0.49 + 0.035
				var warp := rng.randf_range(-0.012, 0.012)
				var a := Vector3(side * inner_x, inner_y + warp, z0)
				var b := Vector3(side * outer_x, outer_y + warp, z0)
				var c := Vector3(side * inner_x, inner_y + warp, z1)
				var d := Vector3(side * outer_x, outer_y + warp, z1)
				var weathering := rng.randf_range(0.78, 1.12)
				var sun_bleach := 1.0 + rng.randf_range(0.0, 0.08) * float(row) / float(row_count)
				var tile_color := Color(0.34, 0.185, 0.13) * weathering * sun_bleach
				# Reverse winding on the opposite roof plane so both sides face outward.
				if side > 0.0:
					surface.set_color(tile_color)
					surface.add_vertex(a)
					surface.add_vertex(c)
					surface.add_vertex(b)
					surface.set_color(tile_color)
					surface.add_vertex(c)
					surface.add_vertex(d)
					surface.add_vertex(b)
				else:
					surface.set_color(tile_color)
					surface.add_vertex(a)
					surface.add_vertex(b)
					surface.add_vertex(c)
					surface.set_color(tile_color)
					surface.add_vertex(c)
					surface.add_vertex(b)
					surface.add_vertex(d)
	surface.generate_normals()
	return surface.commit()

func _add_building_archetype_details(root: Node3D, sign_text: String, wall: Color) -> void:
	if sign_text == "STABLES":
		_add_stables_architecture(root, wall)
	elif sign_text == "SHERIFF":
		_add_sheriff_architecture(root)
	elif sign_text == "GENERAL STORE":
		_add_general_store_awning(root, wall)

func _make_general_store_awning_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stripe in range(8):
		var x0 := -5.0 + float(stripe) * 1.25
		var x1 := x0 + 1.25
		var center_fall := 0.06 * (1.0 - absf(float(stripe) - 3.5) / 4.0)
		var back_left := Vector3(x0, 4.2, 3.86)
		var back_right := Vector3(x1, 4.2, 3.86)
		var front_y := 3.84 - center_fall
		var front_left := Vector3(x0, front_y, 4.95)
		var front_right := Vector3(x1, front_y, 4.95)
		var stripe_color := Color(0.66, 0.16, 0.105) if stripe % 2 == 0 else Color(0.86, 0.76, 0.58)
		# Two-sided sloped canvas keeps the underside readable from the street.
		surface.set_color(stripe_color)
		surface.add_vertex(back_left)
		surface.add_vertex(front_left)
		surface.add_vertex(back_right)
		surface.set_color(stripe_color)
		surface.add_vertex(front_left)
		surface.add_vertex(front_right)
		surface.add_vertex(back_right)
		surface.set_color(stripe_color.darkened(0.12))
		surface.add_vertex(back_left)
		surface.add_vertex(back_right)
		surface.add_vertex(front_left)
		surface.set_color(stripe_color.darkened(0.12))
		surface.add_vertex(back_right)
		surface.add_vertex(front_right)
		surface.add_vertex(front_left)
		# Short striped valance gives the canopy a finished, fabric edge.
		var valance_left := Vector3(x0, front_y - 0.20, 4.99)
		var valance_right := Vector3(x1, front_y - 0.20, 4.99)
		surface.set_color(stripe_color.darkened(0.04))
		surface.add_vertex(front_left)
		surface.add_vertex(valance_left)
		surface.add_vertex(front_right)
		surface.set_color(stripe_color.darkened(0.04))
		surface.add_vertex(valance_left)
		surface.add_vertex(valance_right)
		surface.add_vertex(front_right)
		surface.set_color(stripe_color.darkened(0.18))
		surface.add_vertex(front_left)
		surface.add_vertex(front_right)
		surface.add_vertex(valance_left)
		surface.set_color(stripe_color.darkened(0.18))
		surface.add_vertex(front_right)
		surface.add_vertex(valance_right)
		surface.add_vertex(valance_left)
	surface.generate_normals()
	return surface.commit()

func _add_general_store_awning(root: Node3D, wall: Color) -> void:
	var fabric := StandardMaterial3D.new()
	fabric.vertex_color_use_as_albedo = true
	fabric.albedo_color = Color.WHITE
	fabric.roughness = 0.96
	fabric.metallic = 0.0
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	var canvas := MeshInstance3D.new()
	canvas.name = "GeneralStoreAwningCanvas"
	canvas.mesh = _make_general_store_awning_mesh()
	canvas.material_override = fabric
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(canvas)
	var timber := _weathered_wood_material(wall.darkened(0.25))
	for side in [-1.0, 1.0]:
		var support := _box(root, Vector3(side * 4.62, 4.0, 4.38),
			Vector3(0.09, 0.09, 1.18), timber, Vector3(0.30, 0.0, 0.0))
		support.name = "GeneralStoreAwningSupport"
	var front_rail := _box(root, Vector3(0.0, 3.78, 5.02),
		Vector3(10.1, 0.10, 0.10), timber)
	front_rail.name = "GeneralStoreAwningFrontRail"

func _make_sheriff_star_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector2] = []
	for point_index in range(10):
		var angle := -PI / 2.0 + float(point_index) * PI / 5.0
		var radius := 0.42 if point_index % 2 == 0 else 0.19
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	for point_index in range(10):
		var next_index := (point_index + 1) % 10
		surface.add_vertex(Vector3(0.0, 0.0, 0.045))
		surface.add_vertex(Vector3(points[point_index].x, points[point_index].y, 0.045))
		surface.add_vertex(Vector3(points[next_index].x, points[next_index].y, 0.045))
	surface.generate_normals()
	return surface.commit()

func _add_sheriff_architecture(root: Node3D) -> void:
	# Iron grilles sit behind the exterior shutters, like a practical jail-office
	# window retrofit. The brass star is a separate raised storefront identifier.
	var iron := _material(Color(0.075, 0.068, 0.056), 0.62, 0.72)
	var bar_positions := PackedVector3Array()
	var bar_scales := PackedVector3Array()
	for window_x in [-3.3, 3.3]:
		for offset in [-0.36, 0.0, 0.36]:
			bar_positions.append(Vector3(window_x + offset, 2.1, 4.045))
			bar_scales.append(Vector3(0.055, 1.55, 0.055))
		bar_positions.append(Vector3(window_x, 2.1, 4.045))
		bar_scales.append(Vector3(1.28, 0.055, 0.055))
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3.ONE
	var bars := _add_scaled_mesh_multimesh(root, "SheriffJailBars", bar_mesh,
		bar_positions, bar_scales, iron, PackedFloat32Array())
	bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var badge := MeshInstance3D.new()
	badge.name = "SheriffStarBadge"
	badge.mesh = _make_sheriff_star_mesh()
	var badge_material := _material(Color(0.72, 0.48, 0.16), 0.34, 0.78)
	badge.material_override = badge_material
	badge.position = Vector3(0.0, 5.58, 4.28)
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(badge)
	var center_stud := _cylinder(root, Vector3(0.0, 5.58, 4.34),
		0.075, 0.035, _material(Color(0.88, 0.68, 0.30), 0.3, 0.82), 12)
	center_stud.name = "SheriffBadgeCenterStud"
	center_stud.rotation.x = PI / 2.0

func _add_stables_architecture(root: Node3D, wall: Color) -> void:
	# A working frontier stable needs a wide, track-mounted entrance and a
	# ventilated hayloft, rather than the same shopfront treatment as the town.
	var timber := _weathered_wood_material(wall.darkened(0.28))
	var trim := _weathered_wood_material(wall.lightened(0.08))
	var iron := _material(Color(0.075, 0.068, 0.056), 0.62, 0.72)
	var track := _box(root, Vector3(0.0, 3.72, 4.17), Vector3(2.95, 0.12, 0.14), iron)
	track.name = "StableSlidingDoorTrack"
	for side in [-1.0, 1.0]:
		var panel := _box(root, Vector3(side * 1.22, 2.0, 3.73),
			Vector3(0.72, 2.75, 0.11), timber)
		panel.name = "StableSlidingDoorPanel"
		panel.rotation.y = -side * 0.10
		var brace := _box(root, Vector3(side * 1.22, 2.0, 3.81),
			Vector3(0.62, 0.09, 0.07), trim, Vector3(0.0, 0.0, side * 0.62))
		brace.name = "StableSlidingDoorBrace"
		var roller := _cylinder(root, Vector3(side * 1.22, 3.76, 4.18),
			0.09, 0.12, iron, 12)
		roller.name = "StableDoorRoller"
		roller.rotation.x = PI / 2.0
	var vent_frame := _box(root, Vector3(0.0, 5.55, 4.16),
		Vector3(1.9, 0.86, 0.12), trim)
	vent_frame.name = "StableLoftVentFrame"
	var vent_dark := _box(root, Vector3(0.0, 5.55, 4.235),
		Vector3(1.55, 0.56, 0.035), Color(0.075, 0.055, 0.04))
	vent_dark.name = "StableLoftVentOpening"
	var vent_positions := PackedVector3Array()
	var vent_scales := PackedVector3Array()
	for slat_index in range(5):
		vent_positions.append(Vector3(-0.5 + float(slat_index) * 0.25, 5.55, 4.27))
		vent_scales.append(Vector3(0.055, 0.54, 0.045))
	for rail_y in [5.28, 5.82]:
		vent_positions.append(Vector3(0.0, rail_y, 4.27))
		vent_scales.append(Vector3(1.5, 0.05, 0.045))
	var vent_mesh := BoxMesh.new()
	vent_mesh.size = Vector3.ONE
	_add_scaled_mesh_multimesh(root, "StableLoftVentSlats", vent_mesh,
		vent_positions, vent_scales, timber, PackedFloat32Array())

func _build_building(pos: Vector3, sign_text: String, wall: Color, porch: bool) -> void:
	var root := Node3D.new()
	root.name = sign_text.replace(" ", "") + "Building"
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
		var width: float = x_range.y - x_range.x
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
	var shingles := MeshInstance3D.new()
	shingles.name = "RoofShingles"
	shingles.mesh = _make_roof_shingle_mesh(1897 + abs(sign_text.hash()))
	shingles.material_override = _roof_shingle_surface_material()
	shingles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(shingles)
	# Leave the entrance visibly traversable: the door is hinged and held open,
	# rather than a flat decorative panel sealing the doorway.
	var door_pivot := Node3D.new()
	door_pivot.name = "FrontDoorPivot"
	door_pivot.position = Vector3(-0.72, 0.0, 3.57)
	# Swing the leaf inward and park it parallel to the left jamb. The previous
	# outward swing left the door in the preview camera's line through the entrance.
	door_pivot.rotation.y = PI / 2.0
	root.add_child(door_pivot)
	var door_surface := _weathered_wood_material(Color(0.16, 0.1, 0.07))
	var door_edge_surface := _weathered_wood_material(Color(0.105, 0.065, 0.04))
	for plank_index in range(5):
		var plank_x := 0.15 + float(plank_index) * 0.29
		var plank := _box(door_pivot, Vector3(plank_x, 2.0, 0.0),
			Vector3(0.27, 2.76, 0.11), door_surface)
		plank.name = "FrontDoorPlank"
	for rail_y in [0.86, 3.14]:
		var rail := _box(door_pivot, Vector3(0.72, rail_y, 0.085),
			Vector3(1.38, 0.13, 0.09), door_edge_surface)
		rail.name = "FrontDoorCrossRail"
	var diagonal_brace := _box(door_pivot, Vector3(0.72, 2.0, 0.105),
		Vector3(1.28, 0.105, 0.075), door_edge_surface, Vector3(0.0, 0.0, -0.78))
	diagonal_brace.name = "FrontDoorDiagonalBrace"
	var iron_hinge_material := _material(Color(0.075, 0.065, 0.052), 0.58, 0.72)
	for hinge_y in [0.9, 3.1]:
		var hinge := _box(door_pivot, Vector3(0.22, hinge_y, 0.16),
			Vector3(0.42, 0.075, 0.035), iron_hinge_material)
		hinge.name = "FrontDoorIronHinge"
	var latch := _box(door_pivot, Vector3(1.24, 1.65, 0.16),
		Vector3(0.12, 0.24, 0.07), iron_hinge_material)
	latch.name = "FrontDoorLatch"
	_sphere(door_pivot, Vector3(1.24, 1.65, 0.22), Vector3(0.065, 0.08, 0.065),
		_material(Color(0.58, 0.39, 0.14), 0.28, 0.72))
	
	for x in [-3.3, 3.3]:
		_box(root, Vector3(x, 2.1, 3.66), Vector3(1.25, 1.7, 0.18), Color(0.16, 0.29, 0.34))
		_box(root, Vector3(x, 2.1, 3.78), Vector3(1.4, 0.12, 0.12), _weathered_wood_material(Color(0.24, 0.15, 0.1)))
	if porch:
		_box(root, Vector3(0, 1.7, 5.0), Vector3(11, 0.25, 3), _weathered_wood_material(Color(0.3, 0.2, 0.13)))
		for x in [-4.7, 0, 4.7]:
			_cylinder(root, Vector3(x, 1.5, 6.2), 0.12, 3, Color(0.25, 0.16, 0.1), 8)
	# A framed signboard gives each 1897 storefront a readable trade identity.
	# Rails, iron supports and fasteners are batched so the new joinery does not
	# erase the performance gained by the settlement's other instanced details.
	var sign_board_surface := _weathered_wood_material(wall.darkened(0.34))
	var sign_trim_surface := _weathered_wood_material(wall.lightened(0.10))
	var sign_board := _box(root, Vector3(0.0, 4.75, 4.08),
		Vector3(4.6, 0.72, 0.16), sign_board_surface)
	sign_board.name = "BuildingSignboard"
	var sign_rail_positions := PackedVector3Array([
		Vector3(0.0, 5.13, 4.12),
		Vector3(0.0, 4.37, 4.12),
		Vector3(-2.34, 4.75, 4.12),
		Vector3(2.34, 4.75, 4.12)
	])
	var sign_rail_scales := PackedVector3Array([
		Vector3(4.82, 0.10, 0.22),
		Vector3(4.82, 0.10, 0.22),
		Vector3(0.10, 0.82, 0.22),
		Vector3(0.10, 0.82, 0.22)
	])
	var sign_rail_mesh := BoxMesh.new()
	sign_rail_mesh.size = Vector3.ONE
	_add_scaled_mesh_multimesh(root, "BuildingSignboardRails", sign_rail_mesh,
		sign_rail_positions, sign_rail_scales, sign_trim_surface, PackedFloat32Array())
	var sign_iron := _material(Color(0.075, 0.065, 0.052), 0.58, 0.72)
	var sign_hardware_positions := PackedVector3Array()
	var sign_hardware_scales := PackedVector3Array()
	var sign_hardware_rotations := PackedFloat32Array()
	for x in [-1.9, 1.9]:
		sign_hardware_positions.append(Vector3(x, 5.28, 3.98))
		sign_hardware_scales.append(Vector3(0.075, 0.34, 0.075))
		sign_hardware_rotations.append(0.0)
		sign_hardware_positions.append(Vector3(x, 5.08, 4.00))
		sign_hardware_scales.append(Vector3(0.075, 0.42, 0.075))
		sign_hardware_rotations.append(-0.48 if x < 0.0 else 0.48)
	var sign_hardware_mesh := BoxMesh.new()
	sign_hardware_mesh.size = Vector3.ONE
	_add_scaled_mesh_multimesh(root, "BuildingSignboardHardware", sign_hardware_mesh,
		sign_hardware_positions, sign_hardware_scales, sign_iron, sign_hardware_rotations)
	var sign_bolt_positions := PackedVector3Array()
	var sign_bolt_scales := PackedVector3Array()
	for x in [-2.16, 2.16]:
		for y in [4.52, 4.98]:
			sign_bolt_positions.append(Vector3(x, y, 4.205))
			sign_bolt_scales.append(Vector3(0.075, 0.075, 0.045))
	var sign_bolt_mesh := SphereMesh.new()
	sign_bolt_mesh.radial_segments = 16
	sign_bolt_mesh.rings = 10
	_add_scaled_mesh_multimesh(root, "BuildingSignboardBolts", sign_bolt_mesh,
		sign_bolt_positions, sign_bolt_scales, sign_iron, PackedFloat32Array())
	var sign := Label3D.new()
	sign.name = "BuildingTradeLabel"
	sign.text = sign_text
	sign.font_size = 42
	sign.pixel_size = 0.012
	sign.position = Vector3(0, 4.75, 4.19)
	sign.rotation_degrees.y = 0
	sign.modulate = Color(1.0, 0.79, 0.48)
	root.add_child(sign)
	_build_building_interior(root, sign_text, wall)
	_add_building_details(root, wall, porch)
	_add_building_archetype_details(root, sign_text, wall)

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

func _add_interior_wall_boards(root: Node3D, wall: Color) -> void:
	# One batched timber surface dresses the rear and side walls without adding
	# dozens of separate draw calls to each of the six frontier buildings.
	var boards := MultiMeshInstance3D.new()
	boards.name = "InteriorWallBoards"
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3.ONE
	batch.mesh = board_mesh
	batch.instance_count = 21
	var rear_scale := Vector3(9.2, 0.40, 0.045)
	var side_scale := Vector3(0.045, 0.40, 6.2)
	var y_levels: Array[float] = [0.8, 1.25, 1.7, 2.15, 2.6, 3.05, 3.5]
	var placement_positions := PackedVector3Array()
	var placement_scales := PackedVector3Array()
	var instance_index := 0
	for y in y_levels:
		var rear_position := Vector3(0.0, y, -3.27)
		batch.set_instance_transform(instance_index,
			Transform3D(Basis.from_scale(rear_scale), rear_position))
		placement_positions.append(rear_position)
		placement_scales.append(rear_scale)
		instance_index += 1
		for side in [-1.0, 1.0]:
			var side_position := Vector3(side * 4.765, y, 0.0)
			batch.set_instance_transform(instance_index,
				Transform3D(Basis.from_scale(side_scale), side_position))
			placement_positions.append(side_position)
			placement_scales.append(side_scale)
			instance_index += 1
	boards.multimesh = batch
	# Keep deterministic source records because headless, unattached test roots do
	# not expose MultiMesh instance transforms through get_instance_transform().
	boards.set_meta("placement_positions", placement_positions)
	boards.set_meta("placement_scales", placement_scales)
	boards.material_override = _weathered_wood_material(wall.darkened(0.32))
	boards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(boards)


func _interior_table(root: Node3D, center: Vector3, width: float, depth: float, wood: Material) -> void:
	_interior_solid_box(root, center + Vector3(0, 0.82, 0), Vector3(width, 0.16, depth), wood, "TableTop")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_interior_solid_box(root, center + Vector3(x * (width * 0.5 - 0.12), 0.4, z * (depth * 0.5 - 0.12)), Vector3(0.16, 0.8, 0.16), wood, "TableLeg")

func _interior_lantern(root: Node3D, position: Vector3) -> void:
	var iron := _material(Color(0.075, 0.065, 0.05), 0.58, 0.62)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.95, 0.55, 0.2)
	glass.roughness = 0.28
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.36, 0.08)
	glass.emission_energy_multiplier = 0.55
	var stem := _cylinder(root, position + Vector3(0, 0.18, 0), 0.025, 0.24, iron, 8)
	stem.name = "InteriorLanternStem"
	var upper_cap := _cylinder(root, position, 0.13, 0.10, iron, 12)
	upper_cap.name = "InteriorLanternUpperCap"
	var globe := _sphere(root, position + Vector3(0, -0.22, 0), Vector3(0.14, 0.24, 0.14), glass)
	globe.name = "InteriorLanternGlobe"
	var lower_cap := _cylinder(root, position + Vector3(0, -0.43, 0), 0.09, 0.08, iron, 12)
	lower_cap.name = "InteriorLanternLowerCap"
	for offset in [
		Vector3(-0.105, -0.22, -0.105),
		Vector3(0.105, -0.22, -0.105),
		Vector3(-0.105, -0.22, 0.105),
		Vector3(0.105, -0.22, 0.105)
	]:
		var guard := _cylinder(root, position + offset, 0.012, 0.34, iron, 8)
		guard.name = "InteriorLanternGuard"
	var light := OmniLight3D.new()
	light.name = "InteriorLanternLight"
	light.position = position + Vector3(0, -0.28, 0)
	light.light_color = Color(1.0, 0.58, 0.29)
	light.light_energy = 1.1
	light.omni_range = 10.0
	light.shadow_enabled = true
	root.add_child(light)

func _make_saloon_bottle_mesh() -> ArrayMesh:
	const RADIAL_SEGMENTS := 16
	const BOTTLE_RADIUS := 0.055
	const BOTTLE_HEIGHT := 0.27
	var profile: Array[Vector2] = [
		Vector2(0.58, 0.0),
		Vector2(0.92, 0.04),
		Vector2(1.0, 0.12),
		Vector2(1.0, 0.58),
		Vector2(0.86, 0.68),
		Vector2(0.48, 0.79),
		Vector2(0.34, 0.84),
		Vector2(0.34, 0.96)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(profile.size() - 1):
		var lower := profile[ring_index]
		var upper := profile[ring_index + 1]
		for side in range(RADIAL_SEGMENTS):
			var angle0 := TAU * float(side) / float(RADIAL_SEGMENTS)
			var angle1 := TAU * float(side + 1) / float(RADIAL_SEGMENTS)
			var lower0 := Vector3(cos(angle0) * lower.x * BOTTLE_RADIUS,
				lower.y * BOTTLE_HEIGHT, sin(angle0) * lower.x * BOTTLE_RADIUS)
			var lower1 := Vector3(cos(angle1) * lower.x * BOTTLE_RADIUS,
				lower.y * BOTTLE_HEIGHT, sin(angle1) * lower.x * BOTTLE_RADIUS)
			var upper0 := Vector3(cos(angle0) * upper.x * BOTTLE_RADIUS,
				upper.y * BOTTLE_HEIGHT, sin(angle0) * upper.x * BOTTLE_RADIUS)
			var upper1 := Vector3(cos(angle1) * upper.x * BOTTLE_RADIUS,
				upper.y * BOTTLE_HEIGHT, sin(angle1) * upper.x * BOTTLE_RADIUS)
			surface.add_vertex(lower0)
			surface.add_vertex(upper0)
			surface.add_vertex(lower1)
			surface.add_vertex(lower1)
			surface.add_vertex(upper0)
			surface.add_vertex(upper1)
	var bottom_center := Vector3.ZERO
	var bottom_radius := profile[0].x * BOTTLE_RADIUS
	for side in range(RADIAL_SEGMENTS):
		var angle0 := TAU * float(side) / float(RADIAL_SEGMENTS)
		var angle1 := TAU * float(side + 1) / float(RADIAL_SEGMENTS)
		var edge0 := Vector3(cos(angle0) * bottom_radius, 0.0, sin(angle0) * bottom_radius)
		var edge1 := Vector3(cos(angle1) * bottom_radius, 0.0, sin(angle1) * bottom_radius)
		surface.add_vertex(bottom_center)
		surface.add_vertex(edge0)
		surface.add_vertex(edge1)
	var top_profile := profile[profile.size() - 1]
	var top_center := Vector3(0.0, top_profile.y * BOTTLE_HEIGHT, 0.0)
	var top_radius := top_profile.x * BOTTLE_RADIUS
	for side in range(RADIAL_SEGMENTS):
		var angle0 := TAU * float(side) / float(RADIAL_SEGMENTS)
		var angle1 := TAU * float(side + 1) / float(RADIAL_SEGMENTS)
		var edge0 := Vector3(cos(angle0) * top_radius, top_center.y,
			sin(angle0) * top_radius)
		var edge1 := Vector3(cos(angle1) * top_radius, top_center.y,
			sin(angle1) * top_radius)
		surface.add_vertex(top_center)
		surface.add_vertex(edge1)
		surface.add_vertex(edge0)
	surface.generate_normals()
	return surface.commit()


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
	# Exposed ceiling joists, corner studs and continuous lower wall trim give the
	# room a readable timber structure instead of leaving the interior as a dark box.
	for z in [-2.7, 0.0, 2.7]:
		var joist := _box(root, Vector3(0.0, 3.92, z), Vector3(9.2, 0.18, 0.22), dark_wood)
		joist.name = "InteriorCeilingJoist"
	for x in [-4.62, 4.62]:
		for z in [-3.1, 3.1]:
			var stud := _box(root, Vector3(x, 2.0, z), Vector3(0.16, 3.75, 0.16), furniture)
			stud.name = "InteriorWallStud"
	for x in [-4.62, 4.62]:
		var side_wainscot := _box(root, Vector3(x, 0.35, 0.0), Vector3(0.18, 0.42, 6.2), dark_wood)
		side_wainscot.name = "InteriorWainscot"
	var rear_wainscot := _box(root, Vector3(0.0, 0.35, -3.22), Vector3(9.2, 0.42, 0.16), dark_wood)
	rear_wainscot.name = "InteriorWainscot"
	for x in [-3.65, 3.65]:
		var front_wainscot := _box(root, Vector3(x, 0.35, 3.22), Vector3(2.1, 0.42, 0.16), dark_wood)
		front_wainscot.name = "InteriorWainscot"
	_add_interior_wall_boards(root, wall)
	_interior_lantern(root, Vector3(0, 3.65, -0.65))
	if sign_text == "SALOON":
		# A restrained second warm source lifts the bottle shelf and service surface
		# without brightening every room or relying on unavailable software GI.
		var back_bar_fill := OmniLight3D.new()
		back_bar_fill.name = "SaloonBackBarFillLight"
		back_bar_fill.position = Vector3(0.0, 2.7, -2.0)
		back_bar_fill.light_color = Color(1.0, 0.67, 0.42)
		back_bar_fill.light_energy = 0.8
		back_bar_fill.omni_range = 7.5
		back_bar_fill.shadow_enabled = false
		root.add_child(back_bar_fill)
		# Long service bar, brass foot rail, bottle shelves and card tables.
		_interior_solid_box(root, Vector3(0.0, 3.0, -3.25),
			Vector3(4.0, 0.78, 0.16), dark_wood, "SaloonMirrorFrame")
		var mirror_material := StandardMaterial3D.new()
		mirror_material.albedo_color = Color(0.20, 0.27, 0.29)
		mirror_material.metallic = 0.58
		mirror_material.roughness = 0.24
		_interior_solid_box(root, Vector3(0.0, 3.0, -3.15),
			Vector3(3.62, 0.50, 0.035), mirror_material, "SaloonMirror")
		_interior_solid_box(root, Vector3(0.0, 2.55, -3.02),
			Vector3(4.5, 0.12, 0.32), furniture, "SaloonBackShelf")
		var bottle_mesh := _make_saloon_bottle_mesh()
		var bottle_colors: Array[Color] = [
			Color(0.24, 0.38, 0.18),
			Color(0.42, 0.19, 0.07),
			Color(0.16, 0.27, 0.22),
			Color(0.34, 0.22, 0.10),
			Color(0.20, 0.31, 0.15)
		]
		var label_material := _material(Color(0.78, 0.66, 0.44), 0.88, 0.0)
		var cork_material := _material(Color(0.38, 0.24, 0.12), 0.94, 0.0)
		for bottle_index in range(5):
			var bottle_x := -1.7 + float(bottle_index) * 0.85
			var bottle_position := Vector3(bottle_x, 2.62, -2.88)
			var bottle_material := StandardMaterial3D.new()
			bottle_material.albedo_color = bottle_colors[bottle_index]
			bottle_material.roughness = 0.24
			bottle_material.metallic = 0.04
			var bottle := _mesh(root, bottle_mesh, bottle_material, bottle_position)
			bottle.name = "SaloonBottleMesh"
			var label := _box(root, bottle_position + Vector3(0, 0.14, 0.052),
				Vector3(0.064, 0.055, 0.008), label_material)
			label.name = "SaloonBottleLabel"
			var cork := _cylinder(root, bottle_position + Vector3(0, 0.267, 0),
				0.018, 0.035, cork_material, 8)
			cork.name = "SaloonBottleCork"
		_interior_solid_box(root, Vector3(0, 1.15, -1.65), Vector3(6.0, 1.9, 0.72), furniture, "SaloonBar")
		_interior_solid_box(root, Vector3(0, 2.15, -1.65), Vector3(6.2, 0.16, 0.86), dark_wood, "BarTop")
		var brass := _material(Color(0.54, 0.34, 0.12), 0.34, 0.78)
		var bar_inlay := _box(root, Vector3(0.0, 2.14, -1.215),
			Vector3(6.05, 0.025, 0.025), brass)
		bar_inlay.name = "SaloonBarBrassInlay"
		var foot_rail := _cylinder(root, Vector3(0.0, 0.48, -0.98),
			0.045, 4.8, brass, 16)
		foot_rail.rotation.z = PI / 2.0
		foot_rail.name = "SaloonFootRail"
		for support_x in [-2.0, 0.0, 2.0]:
			var bracket := _cylinder(root, Vector3(support_x, 0.48, -1.13),
				0.022, 0.32, brass, 12)
			bracket.rotation.x = PI / 2.0
			bracket.name = "SaloonFootRailBracket"
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
		_interior_solid_box(root, Vector3(-3.15, 2.35, -1.5), Vector3(0.12, 0.12, 3.5), iron, "CellTopRail")
		_interior_solid_box(root, Vector3(-3.15, 0.18, -1.5), Vector3(0.12, 0.12, 3.5), iron, "CellBottomRail")
		for z in [-3.0, -2.4, -1.8, -1.2, -0.6, 0.0]:
			_cylinder(root, Vector3(-3.15, 1.25, z), 0.045, 2.2, iron, 8)
		_interior_solid_box(root, Vector3(-3.8, 0.9, 1.4), Vector3(1.0, 1.8, 1.8), dark_wood, "JailBench")
	elif sign_text == "STABLES":
		for x in [-3.1, 3.1]:
			_interior_solid_box(root, Vector3(x, 1.15, -1.1), Vector3(0.12, 2.3, 4.2), furniture, "StallDivider")
			_interior_solid_box(root, Vector3(x * 0.5, 1.0, -2.8), Vector3(2.8, 1.0, 0.12), dark_wood, "FeedTrough")
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

func _catmull_rom_profile(p0: Vector4, p1: Vector4, p2: Vector4, p3: Vector4, t: float) -> Vector4:
	var t2 := t * t
	var t3 := t2 * t
	return (p1 * 2.0 + (p2 - p0) * t
		+ (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2
		+ (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t3) * 0.5

func _make_tyrannosaur_body_mesh() -> ArrayMesh:
	# Loft the skull, neck, rib cage and hips into one continuous anatomical shell.
	# Catmull-Rom profile interpolation adds controlled curvature without sphere seams.
	var profiles: Array[Vector4] = [
		Vector4(-3.05, 3.22, 0.38, 0.34),
		Vector4(-2.72, 3.25, 0.53, 0.43),
		Vector4(-2.28, 3.12, 0.62, 0.56),
		Vector4(-1.78, 2.92, 0.68, 0.69),
		Vector4(-1.18, 2.72, 0.76, 0.86),
		Vector4(-0.42, 2.58, 0.85, 0.98),
		Vector4(0.38, 2.56, 0.84, 0.97),
		Vector4(1.05, 2.52, 0.70, 0.82),
		Vector4(1.62, 2.48, 0.43, 0.56)
	]
	var smooth_profiles: Array[Vector4] = []
	for profile_index in range(profiles.size() - 1):
		var p0: Vector4 = profiles[maxi(profile_index - 1, 0)]
		var p1: Vector4 = profiles[profile_index]
		var p2: Vector4 = profiles[profile_index + 1]
		var p3: Vector4 = profiles[mini(profile_index + 2, profiles.size() - 1)]
		for subdivision in range(4):
			var t := float(subdivision) / 4.0
			smooth_profiles.append(_catmull_rom_profile(p0, p1, p2, p3, t))
	smooth_profiles.append(profiles[profiles.size() - 1])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 24
	var rings: Array[PackedVector3Array] = []
	for profile in smooth_profiles:
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / float(segment_count)
			ring.append(Vector3(cos(angle) * profile.z,
				profile.y + sin(angle) * profile.w, profile.x))
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next_segment := (segment + 1) % segment_count
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(d)
			surface.add_vertex(c)
	var front_center := Vector3(0.0, smooth_profiles[0].y, smooth_profiles[0].x)
	var rear := smooth_profiles[smooth_profiles.size() - 1]
	var rear_center := Vector3(0.0, rear.y, rear.x)
	for segment in range(segment_count):
		var next_segment := (segment + 1) % segment_count
		surface.add_vertex(front_center)
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(rear_center)
		surface.add_vertex(rings[rings.size() - 1][segment])
		surface.add_vertex(rings[rings.size() - 1][next_segment])
	surface.generate_normals()
	return surface.commit()

func _make_tyrannosaur_leg_mesh() -> ArrayMesh:
	# One lofted mass carries the thigh, hock and grounded foot into a single silhouette.
	# The longitudinal profile stays broad at the hip and narrows before widening over the toes.
	var profiles: Array[Vector4] = [
		Vector4(0.36, 0.04, 0.28, 0.34),
		Vector4(0.14, 0.02, 0.39, 0.42),
		Vector4(-0.18, -0.01, 0.41, 0.44),
		Vector4(-0.55, -0.04, 0.30, 0.34),
		Vector4(-0.90, -0.10, 0.20, 0.24),
		Vector4(-1.16, -0.19, 0.22, 0.30),
		Vector4(-1.36, -0.39, 0.29, 0.42),
		Vector4(-1.43, -0.48, 0.30, 0.44)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 20
	var rings: Array[PackedVector3Array] = []
	for profile in profiles:
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / float(segment_count)
			ring.append(Vector3(cos(angle) * profile.z, profile.x,
				profile.y + sin(angle) * profile.w))
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next_segment := (segment + 1) % segment_count
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(d)
			surface.add_vertex(c)
	var top_center := Vector3(0.0, profiles[0].x, profiles[0].y)
	var bottom_profile := profiles[profiles.size() - 1]
	var bottom_center := Vector3(0.0, bottom_profile.x, bottom_profile.y)
	for segment in range(segment_count):
		var next_segment := (segment + 1) % segment_count
		surface.add_vertex(top_center)
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(bottom_center)
		surface.add_vertex(rings[rings.size() - 1][segment])
		surface.add_vertex(rings[rings.size() - 1][next_segment])
	surface.generate_normals()
	return surface.commit()

func _make_triceratops_body_mesh() -> ArrayMesh:
	# One closed, smoothly lofted shell carries the shoulder barrel through the
	# rib cage and pelvis. Profiles are (longitudinal Z, center Y, half-width X,
	# half-height Y); the broadest volume sits behind the shoulder line.
	var profiles: Array[Vector4] = [
		Vector4(-1.85, 1.54, 0.42, 0.50),
		Vector4(-1.52, 1.55, 0.64, 0.67),
		Vector4(-1.02, 1.52, 0.82, 0.78),
		Vector4(-0.40, 1.49, 0.93, 0.84),
		Vector4(0.30, 1.46, 0.96, 0.84),
		Vector4(0.88, 1.41, 0.82, 0.74),
		Vector4(1.38, 1.35, 0.60, 0.59),
		Vector4(1.72, 1.32, 0.34, 0.37)
	]
	var smooth_profiles: Array[Vector4] = []
	for profile_index in range(profiles.size() - 1):
		var p0: Vector4 = profiles[maxi(profile_index - 1, 0)]
		var p1: Vector4 = profiles[profile_index]
		var p2: Vector4 = profiles[profile_index + 1]
		var p3: Vector4 = profiles[mini(profile_index + 2, profiles.size() - 1)]
		for subdivision in range(4):
			var t := float(subdivision) / 4.0
			smooth_profiles.append(_catmull_rom_profile(p0, p1, p2, p3, t))
	smooth_profiles.append(profiles[profiles.size() - 1])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 28
	var rings: Array[PackedVector3Array] = []
	for profile in smooth_profiles:
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / float(segment_count)
			ring.append(Vector3(cos(angle) * profile.z,
				profile.y + sin(angle) * profile.w, profile.x))
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next_segment := (segment + 1) % segment_count
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var next_ring_next: Vector3 = rings[ring_index + 1][next_segment]
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(next_ring_next)
			surface.add_vertex(c)
	var front := smooth_profiles[0]
	var rear := smooth_profiles[smooth_profiles.size() - 1]
	var front_center := Vector3(0.0, front.y, front.x)
	var rear_center := Vector3(0.0, rear.y, rear.x)
	for segment in range(segment_count):
		var next_segment := (segment + 1) % segment_count
		surface.add_vertex(front_center)
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(rear_center)
		surface.add_vertex(rings[rings.size() - 1][segment])
		surface.add_vertex(rings[rings.size() - 1][next_segment])
	surface.generate_normals()
	return surface.commit()

func _triceratops_leg_pivot_y(root_height: float, ground_height: float, animal_scale: float) -> float:
	# The leg mesh sole is authored at -1.12 local units; solve the pivot height
	# so the sole reaches the sampled world ground at any uniform animal scale.
	return 1.12 + (ground_height - root_height) / maxf(animal_scale, 0.001)

func _build_triceratops_toes(pivot: Node3D, shadow: Material, horn: Material) -> void:
	for toe_index in range(3):
		var toe_x := (float(toe_index) - 1.0) * 0.21
		var toe_pad := _sphere(pivot, Vector3(toe_x, -1.075, -0.54), Vector3(0.14, 0.095, 0.27), shadow)
		toe_pad.name = "TriceratopsToePad_%d" % toe_index
		var claw := CylinderMesh.new()
		claw.top_radius = 0.006
		claw.bottom_radius = 0.047
		claw.height = 0.14
		claw.radial_segments = 10
		var claw_instance := _mesh(pivot, claw, horn, Vector3(toe_x, -1.075, -0.72), Vector3.ONE, Vector3(-PI / 2.0, 0, 0))
		claw_instance.name = "TriceratopsToeClaw_%d" % toe_index

func _make_triceratops_leg_mesh(front_leg: bool) -> ArrayMesh:
	# Each limb is a closed loft from the shoulder/hip through the ankle into
	# the weight-bearing foot. Profiles are (height, forward offset, X radius, Z radius).
	var profiles: Array[Vector4]
	if front_leg:
		profiles = [
			Vector4(0.22, 0.00, 0.31, 0.33),
			Vector4(-0.02, -0.015, 0.32, 0.33),
			Vector4(-0.34, -0.045, 0.28, 0.29),
			Vector4(-0.68, -0.09, 0.22, 0.24),
			Vector4(-0.96, -0.17, 0.24, 0.29),
			Vector4(-1.12, -0.28, 0.31, 0.39)
		]
	else:
		profiles = [
			Vector4(0.22, 0.00, 0.35, 0.37),
			Vector4(-0.02, -0.015, 0.35, 0.36),
			Vector4(-0.34, -0.06, 0.30, 0.32),
			Vector4(-0.66, -0.12, 0.23, 0.26),
			Vector4(-0.93, -0.21, 0.26, 0.31),
			Vector4(-1.12, -0.29, 0.33, 0.40)
		]
	var smooth_profiles: Array[Vector4] = []
	for profile_index in range(profiles.size() - 1):
		var p0: Vector4 = profiles[maxi(profile_index - 1, 0)]
		var p1: Vector4 = profiles[profile_index]
		var p2: Vector4 = profiles[profile_index + 1]
		var p3: Vector4 = profiles[mini(profile_index + 2, profiles.size() - 1)]
		for subdivision in range(3):
			var t := float(subdivision) / 3.0
			smooth_profiles.append(_catmull_rom_profile(p0, p1, p2, p3, t))
	smooth_profiles.append(profiles[profiles.size() - 1])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 20
	var rings: Array[PackedVector3Array] = []
	for profile in smooth_profiles:
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / float(segment_count)
			ring.append(Vector3(cos(angle) * profile.z, profile.x,
				profile.y + sin(angle) * profile.w))
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next_segment := (segment + 1) % segment_count
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var next_ring_next: Vector3 = rings[ring_index + 1][next_segment]
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(next_ring_next)
			surface.add_vertex(c)
	var top := profiles[0]
	var bottom := profiles[profiles.size() - 1]
	var top_center := Vector3(0.0, top.x, top.y)
	var bottom_center := Vector3(0.0, bottom.x, bottom.y)
	for segment in range(segment_count):
		var next_segment := (segment + 1) % segment_count
		surface.add_vertex(top_center)
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(bottom_center)
		surface.add_vertex(rings[rings.size() - 1][segment])
		surface.add_vertex(rings[rings.size() - 1][next_segment])
	surface.generate_normals()
	return surface.commit()

func _build_tyrannosaur(pos: Vector3, size: float) -> void:
	var rex := Node3D.new()
	rex.position = pos
	rex.scale = Vector3.ONE * size
	add_child(rex)
	var hide := _dinosaur_skin_material(Color(0.27, 0.22, 0.16), 0.92)
	var flank := _dinosaur_skin_material(Color(0.38, 0.3, 0.2), 0.92)
	var underside := _material(Color(0.48, 0.39, 0.27), 0.96)
	var dark := _material(Color(0.12, 0.105, 0.075), 0.96)
	var teeth := _material(Color(0.82, 0.75, 0.58), 0.72)
	var eye := _material(Color(0.78, 0.48, 0.13), 0.28)
	# A single lofted shell joins the hips, rib cage, neck and skull into one silhouette.
	var body_shell := _mesh(rex, _make_tyrannosaur_body_mesh(), hide, Vector3.ZERO)
	body_shell.name = "TyrannosaurBody"
	# The lower jaw remains a separate articulated-looking mass beneath the muzzle.
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
	var rex_tail := _mesh(tail_pivot, _make_tapered_tail_mesh(4.25, 0.58, 0.24), hide, Vector3.ZERO)
	rex_tail.name = "TyrannosaurTail"
	_sphere(tail_pivot, Vector3(0, 0, 0.28), Vector3(0.84, 0.62, 0.72), flank)
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
		var leg_mass := _mesh(leg, _make_tyrannosaur_leg_mesh(), flank, Vector3.ZERO)
		leg_mass.name = "TyrannosaurLegMass"
		for toe in [-0.22, 0.0, 0.22]:
			var toe_pad := _sphere(leg, Vector3(toe, -1.45, -0.68), Vector3(0.15, 0.12, 0.25), flank)
			toe_pad.name = "TyrannosaurToe"
			var claw := CylinderMesh.new()
			claw.top_radius = 0.008
			claw.bottom_radius = 0.075
			claw.height = 0.2
			claw.radial_segments = 8
			var claw_instance := _mesh(leg, claw, teeth, Vector3(toe, -1.43, -0.91), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
			claw_instance.name = "TyrannosaurClaw"
		var gait := create_tween().set_loops()
		gait.tween_property(leg, "rotation:x", 0.12 if side < 0.0 else -0.12, 1.1).set_trans(Tween.TRANS_SINE)
		gait.tween_property(leg, "rotation:x", -0.12 if side < 0.0 else 0.12, 1.1).set_trans(Tween.TRANS_SINE)
func _make_tapered_tail_mesh(length: float, base_radius: float, upward_curve: float) -> ArrayMesh:
	# A single continuous, ring-built tail avoids the blunt cylinder seam and keeps
	# the silhouette tapered from the pelvis to the flexible tip.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_count := 9
	var segment_count := 16
	var rings: Array[PackedVector3Array] = []
	for ring_index in range(ring_count):
		var t := float(ring_index) / float(ring_count - 1)
		var radius := maxf(base_radius * pow(1.0 - t, 1.35), 0.012)
		var center := Vector3(0.0, upward_curve * sin(t * PI * 0.8), length * t)
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / float(segment_count)
			var rib := 1.0 + 0.025 * cos(angle * 8.0)
			ring.append(center + Vector3(cos(angle) * radius * rib,
				sin(angle) * radius * 0.78 * rib, 0.0))
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next_segment := (segment + 1) % segment_count
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(d)
			surface.add_vertex(c)
	var base_center := Vector3.ZERO
	var tip_center := Vector3(0.0, upward_curve * sin(PI * 0.8), length)
	for segment in range(segment_count):
		var next_segment := (segment + 1) % segment_count
		surface.add_vertex(base_center)
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(tip_center)
		surface.add_vertex(rings[ring_count - 1][segment])
		surface.add_vertex(rings[ring_count - 1][next_segment])
	surface.generate_normals()
	return surface.commit()

func _add_frill_triangle(surface: SurfaceTool, tint: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.set_color(tint)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

func _add_frill_quad(surface: SurfaceTool, tint: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_frill_triangle(surface, tint, a, b, c)
	_add_frill_triangle(surface, tint, b, d, c)

func _make_triceratops_z_loft(profiles: Array[Vector4], segment_count: int, subdivisions: int) -> ArrayMesh:
	# Profiles are (Z, center Y, half-width X, half-height Y). The shared loft
	# keeps the skull and lower beak continuous without sphere-to-sphere seams.
	var smooth_profiles: Array[Vector4] = []
	for profile_index in range(profiles.size() - 1):
		var p0: Vector4 = profiles[maxi(profile_index - 1, 0)]
		var p1: Vector4 = profiles[profile_index]
		var p2: Vector4 = profiles[profile_index + 1]
		var p3: Vector4 = profiles[mini(profile_index + 2, profiles.size() - 1)]
		for subdivision in range(subdivisions):
			var t := float(subdivision) / float(subdivisions)
			smooth_profiles.append(_catmull_rom_profile(p0, p1, p2, p3, t))
	smooth_profiles.append(profiles[profiles.size() - 1])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for profile in smooth_profiles:
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / float(segment_count)
			ring.append(Vector3(cos(angle) * profile.z,
				profile.y + sin(angle) * profile.w, profile.x))
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next_segment := (segment + 1) % segment_count
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(d)
			surface.add_vertex(c)
	var first := smooth_profiles[0]
	var last := smooth_profiles[smooth_profiles.size() - 1]
	var first_center := Vector3(0.0, first.y, first.x)
	var last_center := Vector3(0.0, last.y, last.x)
	for segment in range(segment_count):
		var next_segment := (segment + 1) % segment_count
		surface.add_vertex(first_center)
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(last_center)
		surface.add_vertex(rings[rings.size() - 1][segment])
		surface.add_vertex(rings[rings.size() - 1][next_segment])
	# Merge coincident ring vertices before normal generation so the loft
	# shades continuously across each profile instead of looking triangulated.
	surface.index()
	surface.generate_normals()
	return surface.commit()


func _make_triceratops_head_mesh() -> ArrayMesh:
	var profiles: Array[Vector4] = [
		Vector4(-1.43, 1.76, 0.46, 0.42),
		Vector4(-1.72, 1.81, 0.56, 0.48),
		Vector4(-2.02, 1.79, 0.53, 0.43),
		Vector4(-2.30, 1.68, 0.44, 0.32),
		Vector4(-2.56, 1.55, 0.34, 0.21),
		Vector4(-2.79, 1.49, 0.23, 0.14)
	]
	return _make_triceratops_z_loft(profiles, 32, 4)


func _make_triceratops_jaw_mesh() -> ArrayMesh:
	var profiles: Array[Vector4] = [
		Vector4(-1.88, 1.40, 0.30, 0.12),
		Vector4(-2.14, 1.39, 0.34, 0.13),
		Vector4(-2.42, 1.39, 0.29, 0.105),
		Vector4(-2.69, 1.42, 0.19, 0.085)
	]
	return _make_triceratops_z_loft(profiles, 24, 4)


func _make_triceratops_horn_mesh(base: Vector3, tip: Vector3, base_radius: float, bend: Vector3) -> ArrayMesh:
	# A curved keratin tube tapers continuously from a broad embedded root to
	# a fine point. The local frame follows the curved centerline, avoiding the
	# blunt, constant-cross-section look of rotated CylinderMesh horns.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_count := 20
	var segment_count := 14
	var rings: Array[PackedVector3Array] = []
	for ring_index in range(ring_count):
		var t := float(ring_index) / float(ring_count - 1)
		var center := base.lerp(tip, t) + bend * sin(t * PI)
		var tangent := (tip - base + bend * PI * cos(t * PI)).normalized()
		var reference := Vector3.UP
		if absf(tangent.dot(reference)) > 0.94:
			reference = Vector3.FORWARD
		var side := tangent.cross(reference).normalized()
		var up := side.cross(tangent).normalized()
		var radius := base_radius * pow(1.0 - t, 0.88) + 0.004
		if ring_index == 0:
			radius *= 1.08
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / float(segment_count)
			var radial := side * cos(angle) + up * sin(angle)
			ring.append(center + radial * radius)
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next_segment := (segment + 1) % segment_count
			var a: Vector3 = rings[ring_index][segment]
			var b: Vector3 = rings[ring_index][next_segment]
			var c: Vector3 = rings[ring_index + 1][segment]
			var d: Vector3 = rings[ring_index + 1][next_segment]
			# Winding faces away from the centerline.
			surface.add_vertex(a)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(b)
			surface.add_vertex(c)
			surface.add_vertex(d)
	for segment in range(segment_count):
		var next_segment := (segment + 1) % segment_count
		surface.add_vertex(base)
		surface.add_vertex(rings[0][segment])
		surface.add_vertex(rings[0][next_segment])
		surface.add_vertex(tip)
		surface.add_vertex(rings[rings.size() - 1][next_segment])
		surface.add_vertex(rings[rings.size() - 1][segment])
	surface.index()
	surface.generate_normals()
	return surface.commit()


func _make_triceratops_frill_mesh(center: Vector3, rim: PackedVector3Array, thickness: float) -> ArrayMesh:
	# A shallow convex front and rear are joined around the complete outline.
	# The basal chord is deliberately split at the center and mid-ring points,
	# so no open boundary remains where the semicircular plate meets the skull.
	var front_rim := PackedVector3Array()
	var back_rim := PackedVector3Array()
	var front_mid := PackedVector3Array()
	var back_mid := PackedVector3Array()
	for point_index in range(rim.size()):
		var angle := PI * float(point_index) / float(rim.size() - 1)
		var front_point: Vector3 = center + rim[point_index]
		var mid_point := center.lerp(front_point, 0.52) + Vector3(0.0, 0.0, -0.035 * sin(angle))
		front_rim.append(front_point)
		back_rim.append(front_point + Vector3(0.0, 0.0, thickness))
		front_mid.append(mid_point)
		back_mid.append(mid_point + Vector3(0.0, 0.0, thickness))
	var back_center := center + Vector3(0.0, 0.0, thickness)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(rim.size() - 1):
		var front_a: Vector3 = front_rim[segment]
		var front_b: Vector3 = front_rim[segment + 1]
		var back_a: Vector3 = back_rim[segment]
		var back_b: Vector3 = back_rim[segment + 1]
		var mid_a: Vector3 = front_mid[segment]
		var mid_b: Vector3 = front_mid[segment + 1]
		var back_mid_a: Vector3 = back_mid[segment]
		var back_mid_b: Vector3 = back_mid[segment + 1]
		var plate_tint := Color(0.42 + 0.05 * sin(float(segment) * 0.7), 0.39, 0.27)
		# Front: center fan plus a second ring gives the plate a restrained convex crown.
		_add_frill_triangle(surface, plate_tint, center, mid_a, mid_b)
		_add_frill_triangle(surface, plate_tint, mid_a, front_a, front_b)
		_add_frill_triangle(surface, plate_tint, mid_a, front_b, mid_b)
		# Rear face uses the reverse winding and a darker mineral tint.
		_add_frill_triangle(surface, plate_tint * 0.86, back_center, back_mid_b, back_mid_a)
		_add_frill_triangle(surface, plate_tint * 0.86, back_mid_a, back_b, back_a)
		_add_frill_triangle(surface, plate_tint * 0.86, back_mid_a, back_mid_b, back_b)
		# Scalloped outer edge closes the front and rear plates.
		_add_frill_triangle(surface, plate_tint * 0.72, front_a, front_b, back_a)
		_add_frill_triangle(surface, plate_tint * 0.72, front_b, back_b, back_a)
	# Close the basal chord in four strips, following the center and mid-ring
	# boundary vertices so every perimeter edge is shared by exactly two faces.
	var edge_tint := Color(0.30, 0.28, 0.20)
	_add_frill_quad(surface, edge_tint, center, front_mid[0], back_center, back_mid[0])
	_add_frill_quad(surface, edge_tint, front_mid[0], front_rim[0], back_mid[0], back_rim[0])
	var last := rim.size() - 1
	_add_frill_quad(surface, edge_tint, center, front_mid[last], back_center, back_mid[last])
	_add_frill_quad(surface, edge_tint, front_mid[last], front_rim[last], back_mid[last], back_rim[last])
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _triceratops_gait_direction(leg_x: float, leg_z: float) -> float:
	# Same-sign X/Z legs form one diagonal pair; the other pair moves in opposition.
	return 1.0 if leg_x * leg_z > 0.0 else -1.0


func _make_triceratops(pos: Vector3, size: float, yaw: float) -> void:
	var d := Node3D.new()
	d.position = pos
	d.rotation.y = yaw
	d.scale = Vector3.ONE * size
	add_child(d)
	var hide := _dinosaur_skin_material(Color(0.36, 0.34, 0.24), 1.0)
	var flank := _dinosaur_skin_material(Color(0.48, 0.44, 0.31), 1.0)
	var shadow := _material(Color(0.22, 0.23, 0.17), 0.98)
	var horn := _material(Color(0.72, 0.62, 0.43), 0.82)
	var eye := _material(Color(0.035, 0.028, 0.019), 0.25)

	# A single loft replaces the old capsule, shoulder sphere, hip sphere and
	# belly primitive, removing the visible seams between major body masses.
	var body_shell := _mesh(d, _make_triceratops_body_mesh(), hide, Vector3.ZERO)
	body_shell.name = "TriceratopsBody"

	# Long tapered tail with a continuous hide surface and gentle vertical sweep.
	var tail_pivot := Node3D.new()
	tail_pivot.position = Vector3(0, 1.42, 2.05)
	d.add_child(tail_pivot)
	var tail_instance := _mesh(tail_pivot, _make_tapered_tail_mesh(2.85, 0.43, 0.16), hide, Vector3.ZERO)
	tail_instance.name = "TriceratopsTail"
	if is_inside_tree():
		var tail_sway := create_tween().set_loops()
		tail_sway.tween_property(tail_pivot, "rotation:y", 0.085, 2.4).set_trans(Tween.TRANS_SINE)
		tail_sway.tween_property(tail_pivot, "rotation:y", -0.085, 2.4).set_trans(Tween.TRANS_SINE)
	# The skull and frill share a small pivot so later motion reads as a living head,
	# while the continuous loft removes the old stack of intersecting spheres.
	var head_rig := Node3D.new()
	head_rig.name = "TriceratopsHeadRig"
	head_rig.position = Vector3(0.0, 1.72, -1.72)
	d.add_child(head_rig)
	var head_offset := -head_rig.position
	var head_shell := _mesh(head_rig, _make_triceratops_head_mesh(), hide, head_offset)
	head_shell.name = "TriceratopsHead"
	var lower_jaw := _mesh(head_rig, _make_triceratops_jaw_mesh(), shadow, head_offset)
	lower_jaw.name = "TriceratopsLowerJaw"

	# The fan is curved across its face and sealed along both the scalloped
	# rim and the straight basal chord; the same mesh carries the vertex tint.
	var center := Vector3(0, 2.12, -1.57)
	var rim := PackedVector3Array()
	for i in range(25):
		var angle := PI * float(i) / 24.0
		var scallop := 1.0 + 0.055 * sin(float(i) * PI / 3.0)
		rim.append(Vector3(cos(angle) * 1.02 * scallop, sin(angle) * 1.13 * scallop, -0.12 * sin(angle)))
	var frill_thickness := 0.16
	var fan_material := StandardMaterial3D.new()
	fan_material.vertex_color_use_as_albedo = true
	fan_material.roughness = 0.9
	var frill := _mesh(head_rig, _make_triceratops_frill_mesh(center, rim, frill_thickness), fan_material, head_offset)
	frill.name = "TriceratopsFrill"
	for i in range(0, 25, 3):
		_sphere(head_rig, center + rim[i] + head_offset, Vector3(0.13, 0.14, 0.13), flank)

	# Two forward-swept brow horns emerge from fleshy root collars; a shorter
	# nasal horn follows the same tapered, curved keratin construction.
	for x in [-0.40, 0.40]:
		var brow_base := Vector3(x, 2.06, -2.13)
		var brow_tip := Vector3(x * 1.38, 2.83, -2.78)
		var brow_bend := Vector3(x * 0.08, 0.10, -0.07)
		var root := _sphere(head_rig, brow_base + head_offset, Vector3(0.25, 0.22, 0.24), flank)
		root.name = "TriceratopsHornRoot"
		var brow := _mesh(head_rig, _make_triceratops_horn_mesh(brow_base, brow_tip, 0.14, brow_bend), horn, head_offset)
		brow.name = "TriceratopsBrowHorn"
	var nasal_base := Vector3(0.0, 1.72, -2.62)
	var nasal_tip := Vector3(0.0, 2.24, -3.02)
	var nasal_root := _sphere(head_rig, nasal_base + head_offset, Vector3(0.21, 0.17, 0.20), flank)
	nasal_root.name = "TriceratopsHornRoot"
	var nasal_horn := _mesh(head_rig,
		_make_triceratops_horn_mesh(nasal_base, nasal_tip, 0.105, Vector3(0.0, 0.075, -0.045)),
		horn, head_offset)
	nasal_horn.name = "TriceratopsNasalHorn"
	for x in [-0.40, 0.40]:
		var socket := _sphere(head_rig, Vector3(x, 1.96, -2.12) + head_offset, Vector3(0.17, 0.16, 0.09), flank)
		socket.name = "TriceratopsEyeSocket"
		var eye_globe := _sphere(head_rig, Vector3(x * 1.02, 1.97, -2.16) + head_offset, Vector3(0.095, 0.09, 0.055), eye)
		eye_globe.name = "TriceratopsEye"
		_sphere(head_rig, Vector3(x * 1.02, 1.98, -2.205) + head_offset, Vector3(0.034, 0.038, 0.022), horn)
		_sphere(head_rig, Vector3(x * 1.02, 1.98, -2.224) + head_offset, Vector3(0.017, 0.027, 0.012), shadow)
		_sphere(head_rig, Vector3(x * 0.42, 1.57, -2.69) + head_offset, Vector3(0.035, 0.025, 0.018), shadow)

	# Four continuous, weight-bearing limbs. Their neutral sole height is
	# corrected against the actual terrain under each foot, not the herd center.
	var leg_index := 0
	for x in [-0.78, 0.78]:
		for z in [-0.86, 0.98]:
			var sole_offset_z := -0.28 if z < 0.0 else -0.29
			var sole_local := Vector3(x, 0.0, z + sole_offset_z)
			var foot_world := pos + sole_local.rotated(Vector3.UP, yaw) * size
			var ground_height := _terrain_height(Vector2(foot_world.x, foot_world.z))
			var pivot := Node3D.new()
			pivot.name = "TriceratopsLegPivot_%d" % leg_index
			pivot.position = Vector3(x, _triceratops_leg_pivot_y(pos.y, ground_height, size), z)
			d.add_child(pivot)
			var front_leg: bool = z < 0.0
			var leg_mass := _mesh(pivot, _make_triceratops_leg_mesh(front_leg), hide, Vector3.ZERO)
			leg_mass.name = "TriceratopsLegMass"
			_build_triceratops_toes(pivot, shadow, horn)
			# Diagonal pairs alternate with a restrained stride so the feet remain
			# close to the ground instead of swinging like four independent rods.
			if is_inside_tree():
				var gait_direction := _triceratops_gait_direction(x, z)
				var stride_amplitude := 0.065
				pivot.rotation.x = -gait_direction * stride_amplitude
				var gait := create_tween().set_loops()
				gait.tween_property(pivot, "rotation:x", gait_direction * stride_amplitude, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				gait.tween_property(pivot, "rotation:x", -gait_direction * stride_amplitude, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			leg_index += 1
	# Animation is attached only after the animal enters the live scene tree;
	# off-tree procedural builds stay deterministic and safe for geometry tests.
	if is_inside_tree():
		var breathing := create_tween().set_loops()
		breathing.tween_property(body_shell, "scale:y", 1.012, 2.1).set_trans(Tween.TRANS_SINE)
		breathing.tween_property(body_shell, "scale:y", 1.0, 2.1).set_trans(Tween.TRANS_SINE)
		var head_motion := create_tween().set_loops()
		head_motion.tween_property(head_rig, "rotation:x", 0.022, 1.9).set_trans(Tween.TRANS_SINE)
		head_motion.tween_property(head_rig, "rotation:x", -0.014, 2.1).set_trans(Tween.TRANS_SINE)

func _preview_route() -> Array[Dictionary]:
	# The north-and-west exit keeps the camera outside building collision volumes.
	# Each stop frames a distinct town, herd, or predator landmark.
	return [
		{
			"id": "town_establishing",
			"position": Vector3(0.0, _terrain_height(Vector2(0.0, 38.0)) + 0.2, 38.0),
			"target": Vector3(-12.0, 2.6, -12.0),
			"duration": 2.0
		},
		{
			"id": "main_street",
			"position": Vector3(0.0, _terrain_height(Vector2(0.0, 8.0)) + 0.2, 8.0),
			"target": Vector3(12.0, 2.5, -8.0),
			"duration": 2.0
		},
		{
			"id": "saloon_approach",
			# Hold farther out so the full signboard, shutters and porch fit in frame.
			"position": Vector3(-12.0, _terrain_height(Vector2(-12.0, 0.5)) + 0.2, 0.5),
			"target": Vector3(-12.0, _terrain_height(Vector2(-12.0, -12.0)) + 2.35, -8.25),
			"duration": 1.0
		},
		{
			"id": "saloon_interior",
			# The camera passes through the open doorway and frames the bar and back shelf.
			"position": Vector3(-12.0, _terrain_height(Vector2(-12.0, -9.5)) + 0.2, -9.5),
			"target": Vector3(-12.0, _terrain_height(Vector2(-12.0, -12.0)) + 2.7, -13.8),
			"duration": 2.0
		},
		{
			"id": "saloon_exit",
			"position": Vector3(-12.0, _terrain_height(Vector2(-12.0, 0.5)) + 0.2, 0.5),
			"target": Vector3(-12.0, _terrain_height(Vector2(-12.0, 0.5)) + 2.4, 1.7),
			"duration": 1.0
		},
		{
			"id": "town_street_clearance",
			# Rejoin the open street before turning north; the diagonal from the saloon
			# would otherwise clip the sheriff office footprint.
			"position": Vector3(0.0, _terrain_height(Vector2(0.0, -2.0)) + 0.2, -2.0),
			"target": Vector3(-12.0, 2.6, -12.0),
			"duration": 1.0
		},
		{
			"id": "town_north_exit",
			"position": Vector3(0.0, _terrain_height(Vector2(0.0, 42.0)) + 0.2, 42.0),
			"target": Vector3(-12.0, 2.6, -12.0),
			"duration": 2.0
		},
		{
			"id": "west_ridge_approach",
			"position": Vector3(-48.0, _terrain_height(Vector2(-48.0, 42.0)) + 0.2, 42.0),
			"target": Vector3(-31.0, 2.2, -58.0),
			"duration": 2.0
		},
		{
			"id": "herd_approach",
			"position": Vector3(-42.0, _terrain_height(Vector2(-42.0, -30.0)) + 0.2, -30.0),
			"target": Vector3(-31.0, 2.2, -57.0),
			"duration": 2.0
		},
		{
			"id": "herd_close",
			# A deliberate 6.3 m head detail shot on the west flank; the following
			# clearance leg moves monotonically away from the family before turning south.
			"position": Vector3(-37.0, _terrain_height(Vector2(-37.0, -50.0)) + 1.35, -50.0),
			"target": Vector3(-31.0, _terrain_height(Vector2(-31.0, -52.0)) + 1.95, -54.2),
			"duration": 2.0
		},
		{
			"id": "herd_clearance",
			# Move west of the herd before the longer southbound leg; never cut between animals.
			"position": Vector3(-52.0, _terrain_height(Vector2(-52.0, -45.0)) + 0.2, -45.0),
			"target": Vector3(-31.0, 2.2, -58.0),
			"duration": 1.0
		},
		{
			"id": "south_detour",
			"position": Vector3(-52.0, _terrain_height(Vector2(-52.0, -95.0)) + 0.2, -95.0),
			"target": Vector3(70.0, 5.2, -112.0),
			"duration": 1.5
		},
		{
			"id": "tyrannosaur_vista",
			# The overlook moves closer while keeping the full animal in the open mesa corridor.
			"position": Vector3(82.0, _terrain_height(Vector2(82.0, -132.0)) + 1.2, -132.0),
			"target": Vector3(70.0, 5.2, -112.0),
			"duration": 2.5
		},
		{
			"id": "return_overlook",
			"position": Vector3(8.0, _terrain_height(Vector2(8.0, -38.0)) + 0.2, -38.0),
			"target": Vector3(-12.0, 2.6, -12.0),
			"duration": 1.0
		},
		{
			"id": "town_return",
			"position": Vector3(0.0, _terrain_height(Vector2(0.0, 38.0)) + 0.2, 38.0),
			"target": Vector3(-12.0, 2.6, -12.0),
			"duration": 1.0
		}
	]

func _preview_aim(origin: Vector3, target: Vector3) -> Vector2:
	var look_basis := Basis.looking_at(target - origin, Vector3.UP)
	var euler := look_basis.get_euler()
	var yaw := euler.y
	var pitch := clampf(euler.x, -1.2, 1.2)
	return Vector2(yaw, pitch)

func _start_preview_flythrough() -> void:
	# Wait for a rendered game frame before CI starts recording.
	DisplayServer.window_set_title("DUST & DINOSAURS — PREVIEW READY")
	player.set_physics_process(false)
	player.set_process_input(false)
	# A tighter preview lens gives the herd and distant predator readable screen
	# coverage without changing the player's normal 78-degree gameplay view.
	player.camera.fov = PREVIEW_CAMERA_FOV
	message_label.text = "AUTOMATED PREVIEW ROUTE — RED ROCK, ARIZONA 1897"
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(1.5).timeout
	preview_started_at_msec = Time.get_ticks_msec()
	print("PREVIEW_READY")
	_run_preview_route()

func _run_preview_route() -> void:
	# Use one awaited tween per stop; this keeps the route strictly sequential.
	await get_tree().create_timer(1.0).timeout
	for waypoint in _preview_route():
		var destination: Vector3 = waypoint["position"]
		var target: Vector3 = waypoint["target"]
		var travel_time: float = waypoint["duration"]
		var camera_origin: Vector3 = destination + Vector3.UP * player.camera_pivot.position.y
		var aim := _preview_aim(camera_origin, target)
		var target_yaw := player.rotation.y + wrapf(aim.x - player.rotation.y, -PI, PI)
		var segment := create_tween()
		segment.tween_property(player, "position", destination, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		segment.parallel().tween_property(player, "rotation:y", target_yaw, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		segment.parallel().tween_property(player.camera_pivot, "rotation:x", aim.y, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Software-rendered CI can clamp large frame deltas. Accelerate only this
		# deterministic preview tween and hold each composition long enough to inspect.
		segment.set_speed_scale(PREVIEW_TWEEN_SPEED_SCALE)
		await segment.finished
		_log_preview_waypoint(str(waypoint["id"]))
		await get_tree().create_timer(PREVIEW_WAYPOINT_HOLD_SECONDS).timeout
	var elapsed := float(Time.get_ticks_msec() - preview_started_at_msec) / 1000.0
	print("PREVIEW_ROUTE_COMPLETE: elapsed=" + str(snappedf(elapsed, 0.01)))

func _log_preview_waypoint(waypoint_id: String) -> void:
	var elapsed := float(Time.get_ticks_msec() - preview_started_at_msec) / 1000.0
	print("PREVIEW_WAYPOINT_COMPLETE: " + waypoint_id + " elapsed=" +
		str(snappedf(elapsed, 0.01)) + " position=" + str(player.global_position))

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
