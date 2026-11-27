extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	var world_script: Script = load("res://scripts/world.gd")
	world_under_test = Node3D.new()
	world_under_test.set_script(world_script)
	world_under_test.call("_rock_formation", Vector3.ZERO, 1.0)
	world_under_test.call("_rock_formation", Vector3(24.0, 0.0, 0.0), 0.9)
	world_under_test.call("_rock_formation", Vector3(-24.0, 0.0, 0.0), 1.5)

	if world_under_test.get_child_count() != 3:
		_fail("Rock builder must create three differently scaled static bodies for shared-material and LOD verification.")
		return
	var rock_body := world_under_test.get_child(0) as StaticBody3D
	var second_rock_body := world_under_test.get_child(1) as StaticBody3D
	var third_rock_body := world_under_test.get_child(2) as StaticBody3D
	var second_high := second_rock_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var second_low := second_rock_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var third_high := third_rock_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var third_low := third_rock_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var high := rock_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var low := rock_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var collision := rock_body.get_node_or_null("RockCollision") as CollisionShape3D
	if high == null or low == null or collision == null:
		_fail("Rock must contain high-detail, distant LOD, and collision nodes.")
		return
	if high.mesh == null or low.mesh == null:
		_fail("Rock LOD meshes must both be assigned.")
		return
	var high_arrays := high.mesh.surface_get_arrays(0)
	var low_arrays := low.mesh.surface_get_arrays(0)
	var high_vertices: PackedVector3Array = high_arrays[Mesh.ARRAY_VERTEX]
	var low_vertices: PackedVector3Array = low_arrays[Mesh.ARRAY_VERTEX]
	var high_indices: PackedInt32Array = high_arrays[Mesh.ARRAY_INDEX]
	var low_indices: PackedInt32Array = low_arrays[Mesh.ARRAY_INDEX]
	if high_vertices.size() != 354 or low_vertices.size() != 58:
		_fail("Indexed near and distant sandstone meshes must use 354 and 58 unique vertices.")
		return
	if high_indices.size() != 1728 or low_indices.size() != 240:
		_fail("Indexed near and distant sandstone meshes must retain 576 and 80 triangles.")
		return
	if low_indices.is_empty() or low_indices.size() >= high_indices.size():
		_fail("Distant rock LOD must be non-empty and cheaper than the near mesh by index count.")
		return
	for index in high_indices:
		if index < 0 or index >= high_vertices.size():
			_fail("Near sandstone index must reference an existing shared vertex.")
			return
	for index in low_indices:
		if index < 0 or index >= low_vertices.size():
			_fail("Distant sandstone index must reference an existing shared vertex.")
			return
	for triangle_start in range(0, low_indices.size(), 3):
		var a: Vector3 = low_vertices[low_indices[triangle_start]]
		var b: Vector3 = low_vertices[low_indices[triangle_start + 1]]
		var c_vertex: Vector3 = low_vertices[low_indices[triangle_start + 2]]
		if (b - a).cross(c_vertex - a).length_squared() < 0.000001:
			_fail("Distant sandstone LOD must not contain degenerate triangles.")
			return
	if high.visibility_range_end <= low.visibility_range_begin:
		_fail("Near and distant rock visibility ranges must overlap.")
		return
	if second_high == null or second_low == null or third_high == null or third_low == null:
		_fail("Every rock size must retain both near and distant LOD nodes.")
		return
	if absf(second_high.visibility_range_end - 118.8) > 0.01 or absf(second_low.visibility_range_begin - 106.2) > 0.01:
		_fail("A 0.9-scale outcrop must scale both LOD handoff distances proportionally.")
		return
	if absf(third_high.visibility_range_end - 198.0) > 0.01 or absf(third_low.visibility_range_begin - 177.0) > 0.01:
		_fail("A 1.5-scale outcrop must scale both LOD handoff distances proportionally.")
		return
	if collision.shape == null or not (collision.shape is ConcavePolygonShape3D):
		_fail("Rock collision must use a static concave triangle mesh.")
		return
	var collision_faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
	if collision_faces.size() % 3 != 0:
		_fail("Static rock collision faces must contain complete triangles.")
		return
	var collision_triangle_count := int(collision_faces.size() / 3)
	var near_triangle_count := int(high_indices.size() / 3)
	var far_triangle_count := int(low_indices.size() / 3)
	if collision_triangle_count != far_triangle_count or float(collision_triangle_count) / float(near_triangle_count) >= 0.20:
		_fail("Static rock collision must match the 80-triangle distant silhouette and remain below 20% of near triangles.")
		return
	if high.mesh.get_aabb().size.length_squared() <= 0.0 or low.mesh.get_aabb().size.length_squared() <= 0.0:
		_fail("Rock LOD meshes must have non-zero bounds.")
		return
	var high_normals: PackedVector3Array = high_arrays[Mesh.ARRAY_NORMAL]
	var low_normals: PackedVector3Array = low_arrays[Mesh.ARRAY_NORMAL]
	var high_colors: PackedColorArray = high_arrays[Mesh.ARRAY_COLOR]
	if high_normals.size() != high_vertices.size() or high_colors.size() != high_vertices.size():
		_fail("Near sandstone mesh must retain generated normals and layered vertex strata.")
		return
	if low_normals.size() != low_vertices.size():
		_fail("Distant sandstone mesh must retain generated normals for its indexed vertices.")
		return
	if low_normals[40].dot(Vector3.UP) < 0.90 or low_normals[49].dot(Vector3.DOWN) < 0.90:
		_fail("Distant sandstone crown and base cap rings must retain their own outward-facing normals.")
		return
	if low_normals[48].dot(Vector3.UP) < 0.90 or low_normals[57].dot(Vector3.DOWN) < 0.90:
		_fail("Distant sandstone cap centers must retain explicit upward/downward normals.")
		return
	var minimum_far_radial_dot := 1.0
	var minimum_far_radial_index := -1
	for vertex_index in range(40):
		var radial_direction := Vector3(low_vertices[vertex_index].x, 0.0, low_vertices[vertex_index].z).normalized()
		var radial_dot := low_normals[vertex_index].dot(radial_direction)
		if radial_dot < minimum_far_radial_dot:
			minimum_far_radial_dot = radial_dot
			minimum_far_radial_index = vertex_index
	print("Distant sandstone minimum outward-normal dot: ", minimum_far_radial_dot, " at vertex ", minimum_far_radial_index)
	if minimum_far_radial_dot < 0.15:
		_fail("Distant sandstone side-ring normals fall below the outward-facing threshold: min dot=" + str(minimum_far_radial_dot) + ".")
		return
	var low_side_dot := low_normals[8].dot(Vector3.RIGHT)
	if low_side_dot < 0.25:
		_fail("Distant sandstone side-wall normals must remain outward-facing: dot=" + str(low_side_dot) + ".")
		return
	var high_material := high.material_override as ShaderMaterial
	var low_material := low.material_override as ShaderMaterial
	if high_material == null or low_material == null or high_material.shader == null or low_material.shader == null:
		_fail("Both sandstone LODs must share the procedural sediment and erosion material.")
		return
	if high_material != low_material:
		_fail("Near and distant sandstone LODs must reference one shared ShaderMaterial resource.")
		return
	if second_high.material_override != high_material or third_high.material_override != high_material:
		_fail("All outcrops in one world must reuse the cached sandstone ShaderMaterial.")
		return
	if high_material.shader.code != low_material.shader.code:
		_fail("Near and distant sandstone LODs must use the same surface response.")
		return
	for token in ["fine_grain", "sediment", "fracture", "ALBEDO = stone", "ROUGHNESS"]:
		if not high_material.shader.code.contains(token):
			_fail("Sandstone material is missing its multi-scale erosion detail: " + token)
			return
	for token in ["fine_grain * 0.035", "ROUGHNESS", "sediment", "fracture", "bedding_breakup", "iron_oxide", "rock_world_pos.y * 0.78"]:
		if not high_material.shader.code.contains(token):
			_fail("Sandstone must retain irregular bedding, iron-rich weathering and multi-scale albedo/roughness detail: " + token)
			return
	for token in ["dFdx(rock_world_pos)", "height_gradient", "bump_world_normal"]:
		if high_material.shader.code.contains(token):
			_fail("Rock shader must keep stable geometric normals until derivative bump artifacts are resolved: " + token)
			return

	print("Rock LOD regression passed: near=", high_indices.size() / 3,
		" triangles from ", high_vertices.size(), " vertices; far/collision=",
		low_indices.size() / 3, " triangles from ", low_vertices.size(),
		" vertices; triangle-based collision budget, shared material and scale-aware handoff ranges.")
	world_under_test.free()
	world_under_test = null
	quit(0)

func _fail(message: String) -> void:
	if is_instance_valid(world_under_test):
		world_under_test.free()
		world_under_test = null
	push_error(message)
	quit(1)
