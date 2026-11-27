extends SceneTree

func _initialize() -> void:
	var first := Node3D.new()
	first.set_script(load("res://scripts/world.gd"))
	first.call("_rock_formation", Vector3(18.0, 0.0, -26.0), 1.0)
	var second := Node3D.new()
	second.set_script(load("res://scripts/world.gd"))
	second.call("_rock_formation", Vector3(18.0, 0.0, -26.0), 1.4)
	if first.get_child_count() != 1 or second.get_child_count() != 1:
		_fail(first, second, "Each authored outcrop must create one static body.")
		return
	var first_body := first.get_child(0) as StaticBody3D
	var second_body := second.get_child(0) as StaticBody3D
	var high := first_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var low := first_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var collision := first_body.get_node_or_null("RockCollision") as CollisionShape3D
	var repeated_high := second_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var repeated_low := second_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	if high == null or low == null or collision == null or repeated_high == null or repeated_low == null:
		_fail(first, second, "Outcrop must provide near, distant and collision geometry.")
		return
	if high.mesh == null or low.mesh == null or high.mesh.get_surface_count() != 1 or low.mesh.get_surface_count() != 1:
		_fail(first, second, "Both outcrop LODs must use one complete mesh surface.")
		return
	var high_arrays := high.mesh.surface_get_arrays(0)
	var low_arrays := low.mesh.surface_get_arrays(0)
	var repeated_arrays := repeated_high.mesh.surface_get_arrays(0)
	var high_vertices: PackedVector3Array = high_arrays[Mesh.ARRAY_VERTEX]
	var low_vertices: PackedVector3Array = low_arrays[Mesh.ARRAY_VERTEX]
	var repeated_vertices: PackedVector3Array = repeated_arrays[Mesh.ARRAY_VERTEX]
	var high_indices: PackedInt32Array = high_arrays[Mesh.ARRAY_INDEX]
	var low_indices: PackedInt32Array = low_arrays[Mesh.ARRAY_INDEX]
	var repeated_indices: PackedInt32Array = repeated_arrays[Mesh.ARRAY_INDEX]
	var high_normals: PackedVector3Array = high_arrays[Mesh.ARRAY_NORMAL]
	var high_colors: PackedColorArray = high_arrays[Mesh.ARRAY_COLOR]
	if high_vertices.size() != 354 or low_vertices.size() != 58:
		_fail(first, second, "Indexed near and distant sandstone meshes must use 354 and 58 unique vertices.")
		return
	if high_indices.size() != 1728 or low_indices.size() != 240:
		_fail(first, second, "Indexed near and distant sandstone meshes must retain 576 and 80 triangles.")
		return
	if repeated_indices != high_indices:
		_fail(first, second, "Identical seeded outcrops must retain the same indexed topology.")
		return
	for index in high_indices:
		if index < 0 or index >= high_vertices.size():
			_fail(first, second, "Near outcrop index must reference a valid shared vertex.")
			return
	for index in low_indices:
		if index < 0 or index >= low_vertices.size():
			_fail(first, second, "Distant outcrop index must reference a valid shared vertex.")
			return
	if high_indices.size() % 3 != 0 or low_indices.size() % 3 != 0:
		_fail(first, second, "Indexed outcrop surfaces must contain complete triangles.")
		return
	for triangle_start in range(0, high_indices.size(), 3):
		var a: Vector3 = high_vertices[high_indices[triangle_start]]
		var b: Vector3 = high_vertices[high_indices[triangle_start + 1]]
		var c_vertex: Vector3 = high_vertices[high_indices[triangle_start + 2]]
		if (b - a).cross(c_vertex - a).length_squared() < 0.000001:
			_fail(first, second, "Indexed near outcrop must not contain degenerate triangles.")
			return
	for triangle_start in range(0, low_indices.size(), 3):
		var a: Vector3 = low_vertices[low_indices[triangle_start]]
		var b: Vector3 = low_vertices[low_indices[triangle_start + 1]]
		var c_vertex: Vector3 = low_vertices[low_indices[triangle_start + 2]]
		if (b - a).cross(c_vertex - a).length_squared() < 0.000001:
			_fail(first, second, "Indexed distant outcrop must not contain degenerate triangles.")
			return
	if high_normals.size() != high_vertices.size() or high_colors.size() != high_vertices.size():
		_fail(first, second, "Near outcrop must retain generated normals and layered vertex strata.")
		return
	for normal_index in range(high_normals.size()):
		var normal: Vector3 = high_normals[normal_index]
		if not is_finite(normal.x) or not is_finite(normal.y) or not is_finite(normal.z):
			_fail(first, second, "Indexed sandstone normals must remain finite at every shared vertex.")
			return
		if absf(normal.length() - 1.0) > 0.03:
			_fail(first, second, "Indexed sandstone normals must remain normalized after shared-ring generation.")
			return
	var minimum_near_radial_dot := 1.0
	var minimum_near_radial_index := -1
	for vertex_index in range(9 * 32):
		var radial_direction := Vector3(high_vertices[vertex_index].x, 0.0, high_vertices[vertex_index].z).normalized()
		var radial_dot := high_normals[vertex_index].dot(radial_direction)
		if radial_dot < minimum_near_radial_dot:
			minimum_near_radial_dot = radial_dot
			minimum_near_radial_index = vertex_index
	print("Near sandstone minimum outward-normal dot: ", minimum_near_radial_dot, " at vertex ", minimum_near_radial_index)
	if minimum_near_radial_dot < 0.15:
		_fail(first, second, "Near sandstone side-ring normals fall below the outward-facing threshold: min dot=" + str(minimum_near_radial_dot) + ".")
		return
	var low_normals: PackedVector3Array = low_arrays[Mesh.ARRAY_NORMAL]
	if low_normals.size() != low_vertices.size():
		_fail(first, second, "Distant sandstone must provide one normal per indexed vertex.")
		return
	for normal_index in range(low_normals.size()):
		var normal: Vector3 = low_normals[normal_index]
		if not is_finite(normal.x) or not is_finite(normal.y) or not is_finite(normal.z) or absf(normal.length() - 1.0) > 0.03:
			_fail(first, second, "Distant sandstone normals must be finite and normalized.")
			return
	var minimum_far_radial_dot := 1.0
	var minimum_far_radial_index := -1
	for vertex_index in range(5 * 8):
		var radial_direction := Vector3(low_vertices[vertex_index].x, 0.0, low_vertices[vertex_index].z).normalized()
		var radial_dot := low_normals[vertex_index].dot(radial_direction)
		if radial_dot < minimum_far_radial_dot:
			minimum_far_radial_dot = radial_dot
			minimum_far_radial_index = vertex_index
	print("Far sandstone minimum outward-normal dot: ", minimum_far_radial_dot, " at vertex ", minimum_far_radial_index)
	if minimum_far_radial_dot < 0.15:
		_fail(first, second, "Far sandstone side-ring normals fall below the outward-facing threshold: min dot=" + str(minimum_far_radial_dot) + ".")
		return
	# The top and base cap rings intentionally duplicate their side-ring positions.
	# Their normals must stay oriented to the cap planes rather than bleeding across
	# the sharp geological boundary into the smoothed side wall.
	var top_side_normal: Vector3 = high_normals[8 * 32]
	var top_cap_normal: Vector3 = high_normals[9 * 32]
	var top_center_normal: Vector3 = high_normals[9 * 32 + 32]
	var base_side_normal: Vector3 = high_normals[0]
	var base_cap_normal: Vector3 = high_normals[9 * 32 + 1 + 32]
	var base_center_normal: Vector3 = high_normals[9 * 32 + 1 + 2 * 32]
	var top_cap_up_dot := top_cap_normal.dot(Vector3.UP)
	var base_cap_down_dot := base_cap_normal.dot(Vector3.DOWN)
	if top_cap_up_dot < 0.90 or base_cap_down_dot < 0.90:
		_fail(first, second, "Sandstone cap orientation mismatch: top-up dot=" + str(top_cap_up_dot) + ", base-down dot=" + str(base_cap_down_dot) + ".")
		return
	if top_center_normal.dot(Vector3.UP) < 0.90 or base_center_normal.dot(Vector3.DOWN) < 0.90:
		_fail(first, second, "Sandstone cap center vertices must retain explicit upward/downward normals.")
		return
	var top_side_dot := top_side_normal.dot(Vector3.RIGHT)
	var mid_side_dot := high_normals[4 * 32].dot(Vector3.RIGHT)
	if top_side_dot < 0.25 or mid_side_dot < 0.25:
		_fail(first, second, "Shared sandstone side-wall normals must remain outward-facing: top dot=" + str(top_side_dot) + ", middle dot=" + str(mid_side_dot) + ".")
		return
	if top_cap_normal.dot(top_side_normal) > 0.92 or base_cap_normal.dot(base_side_normal) > 0.92:
		_fail(first, second, "Sandstone cap normals must remain isolated from the side-wall normals at the ledge seams.")
		return
	var distinct_strata_colors: Dictionary = {}
	for color in high_colors:
		distinct_strata_colors[color.to_rgba32()] = true
	if distinct_strata_colors.size() < 24:
		_fail(first, second, "Expanded sandstone strata must retain seeded color variation instead of collapsing to flat bands.")
		return
	var near_bounds := high.mesh.get_aabb()
	if near_bounds.size.y < 8.2 or near_bounds.size.y > 9.6:
		_fail(first, second, "Terrain-conformed outcrop must preserve its mesa height while burying the base ring below the dune surface.")
		return
	for index in range(high_vertices.size()):
		if not is_finite(high_vertices[index].x) or not is_finite(high_vertices[index].y) or not is_finite(high_vertices[index].z):
			_fail(first, second, "Outcrop vertices must remain finite after seeded erosion offsets.")
			return
		if high_vertices[index].distance_squared_to(repeated_vertices[index]) > 0.000001:
			_fail(first, second, "The same outcrop position must produce deterministic weathered geometry.")
			return
	for segment in range(32):
		var base_vertex: Vector3 = high_vertices[segment]
		var expected_base_y := float(first.call("_terrain_height",
			Vector2(18.0 + base_vertex.x, -26.0 + base_vertex.z))) - 0.35
		if absf(base_vertex.y - expected_base_y) > 0.02:
			_fail(first, second, "Every sandstone base-ring vertex must sit 0.35 m below the sampled terrain surface.")
			return
	if low_vertices.size() >= high_vertices.size():
		_fail(first, second, "Distant outcrop LOD must be cheaper than the near silhouette.")
		return
	if collision.shape == null or not (collision.shape is ConcavePolygonShape3D):
		_fail(first, second, "Outcrop collision must use a static concave triangle mesh.")
		return
	var collision_faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
	if collision_faces.size() % 3 != 0:
		_fail(first, second, "Outcrop collision faces must contain complete triangles.")
		return
	var near_triangle_count := int(high_indices.size() / 3)
	var far_triangle_count := int(low_indices.size() / 3)
	var collision_triangle_count := int(collision_faces.size() / 3)
	if collision_triangle_count != far_triangle_count:
		_fail(first, second, "Outcrop collision must contain exactly the distant LOD's triangle count.")
		return
	var collision_triangle_ratio := float(collision_triangle_count) / float(near_triangle_count)
	if collision_triangle_ratio >= 0.20:
		_fail(first, second, "Static collision must remain below 20% of the near-mesh triangle budget.")
		return
	var expected_collision_triangles: Dictionary = {}
	for triangle_start in range(0, low_indices.size(), 3):
		var expected_key := _triangle_key(
			low_vertices[low_indices[triangle_start]],
			low_vertices[low_indices[triangle_start + 1]],
			low_vertices[low_indices[triangle_start + 2]])
		expected_collision_triangles[expected_key] = int(expected_collision_triangles.get(expected_key, 0)) + 1
	var actual_collision_triangles: Dictionary = {}
	for triangle_start in range(0, collision_faces.size(), 3):
		var actual_key := _triangle_key(collision_faces[triangle_start],
			collision_faces[triangle_start + 1], collision_faces[triangle_start + 2])
		actual_collision_triangles[actual_key] = int(actual_collision_triangles.get(actual_key, 0)) + 1
	if actual_collision_triangles != expected_collision_triangles:
		_fail(first, second, "Static collision triangles must match the distant render mesh topology, not only its triangle count.")
		return
	if absf(high.visibility_range_end - 132.0) > 0.01 or absf(low.visibility_range_begin - 118.0) > 0.01:
		_fail(first, second, "Unit-scale outcrop must retain the authored near/far LOD handoff distances.")
		return
	if absf(repeated_high.visibility_range_end - 184.8) > 0.01 or absf(repeated_low.visibility_range_begin - 165.2) > 0.01:
		_fail(first, second, "Scaled outcrop must proportionally move its LOD handoff distances.")
		return
	if high.visibility_range_end <= low.visibility_range_begin:
		_fail(first, second, "Near and distant outcrop visibility ranges must overlap for a stable handoff.")
		return
	var high_material := high.material_override as ShaderMaterial
	var low_material := low.material_override as ShaderMaterial
	if high_material == null or low_material == null or high_material.shader.code != low_material.shader.code:
		_fail(first, second, "Both outcrop LODs must share the same layered sandstone response.")
		return
	print("Rock formation regression passed: indexed near mesh (354 vertices/576 triangles), indexed far mesh (58 vertices/80 triangles), exact collision topology, seeded strata, shared material and scale-aware LOD.")
	first.free()
	second.free()
	quit(0)

func _point_key(point: Vector3) -> String:
	return str(Vector3i(roundi(point.x * 10000.0), roundi(point.y * 10000.0), roundi(point.z * 10000.0)))

func _triangle_key(a: Vector3, b: Vector3, c: Vector3) -> String:
	var points := [_point_key(a), _point_key(b), _point_key(c)]
	points.sort()
	return points[0] + "|" + points[1] + "|" + points[2]

func _fail(first: Node3D, second: Node3D, message: String) -> void:
	if is_instance_valid(first):
		first.free()
	if is_instance_valid(second):
		second.free()
	push_error(message)
	quit(1)
