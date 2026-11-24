extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var wash_center: float = world.call("_terrain_wash_center", 0.0)
	var channel_height: float = world.call("_terrain_height", Vector2(0.0, wash_center))
	var bank_height: float = world.call("_terrain_height", Vector2(0.0, wash_center + 15.5))
	if bank_height - channel_height < 0.55:
		_fail(world, "The dry arroyo must sit clearly below its raised bank shoulders.")
		return

	var min_sample := 1.0e20
	var max_sample := -1.0e20
	for x in range(-160, 161, 20):
		for z in range(-160, 161, 20):
			var height: float = world.call("_terrain_height", Vector2(float(x), float(z)))
			min_sample = minf(min_sample, height)
			max_sample = maxf(max_sample, height)
	if max_sample - min_sample < 1.0:
		_fail(world, "The basin and dune fields must create measurable large-scale elevation variation.")
		return

	var mesh: ArrayMesh = world.call("_make_terrain_mesh", 48)
	if mesh == null or mesh.get_surface_count() != 1:
		_fail(world, "Terrain relief builder must return one triangle surface.")
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != 49 * 49 or indices.size() != 48 * 48 * 6 or normals.size() != vertices.size():
		_fail(world, "Terrain relief mesh must share its 49x49 grid vertices through a complete indexed triangle buffer.")
		return
	# SurfaceTool may reorder vertex storage while generating shared normals;
	# validate lattice membership rather than assuming a particular array order.
	var occupied_lattice_points := {}
	var lattice_step := 520.0 / 48.0
	for vertex_index in range(vertices.size()):
		var vertex: Vector3 = vertices[vertex_index]
		var grid_x := roundi((vertex.x + 260.0) / lattice_step)
		var grid_z := roundi((vertex.z + 260.0) / lattice_step)
		if grid_x < 0 or grid_x > 48 or grid_z < 0 or grid_z > 48:
			_fail(world, "Indexed terrain vertices must remain inside the deterministic world-space lattice.")
			return
		var expected_x := -260.0 + float(grid_x) * lattice_step
		var expected_z := -260.0 + float(grid_z) * lattice_step
		if absf(vertex.x - expected_x) > 0.001 or absf(vertex.z - expected_z) > 0.001:
			_fail(world, "Indexed terrain vertices must remain on the deterministic world-space lattice.")
			return
		var lattice_key := grid_z * 49 + grid_x
		if occupied_lattice_points.has(lattice_key):
			_fail(world, "Indexed terrain must not duplicate a shared lattice vertex.")
			return
		var expected_height: float = world.call("_terrain_height", Vector2(vertex.x, vertex.z))
		if absf(vertex.y - expected_height) > 0.01:
			_fail(world, "Indexed terrain vertex height must match the shared authored height field.")
			return
		occupied_lattice_points[lattice_key] = vertex_index
	if occupied_lattice_points.size() != 49 * 49:
		_fail(world, "Indexed terrain must contain every lattice point exactly once.")
		return
	for index in indices:
		if index < 0 or index >= vertices.size():
			_fail(world, "Terrain index buffer must reference only valid shared grid vertices.")
			return
	# Confirm every cell's six indices still form the original two triangles.
	# Map lattice coordinates to actual array indices instead of relying on
	# SurfaceTool's internal vertex ordering.
	for z in range(48):
		for x in range(48):
			var a_key := z * 49 + x
			var b_key := a_key + 1
			var c_key := a_key + 49
			var d_key := c_key + 1
			var expected_cell := [occupied_lattice_points[a_key], occupied_lattice_points[b_key],
				occupied_lattice_points[c_key], occupied_lattice_points[b_key],
				occupied_lattice_points[d_key], occupied_lattice_points[c_key]]
			var cell_start := (z * 48 + x) * 6
			for corner in range(6):
				if indices[cell_start + corner] != expected_cell[corner]:
					_fail(world, "Indexed terrain cells must preserve the authored triangle topology and winding.")
					return
	var min_height := 1.0e20
	var max_height := -1.0e20
	var minimum_normal_up := 1.0
	for index in range(vertices.size()):
		min_height = minf(min_height, vertices[index].y)
		max_height = maxf(max_height, vertices[index].y)
		minimum_normal_up = minf(minimum_normal_up, normals[index].y)
	if max_height - min_height < 0.25:
		_fail(world, "Terrain relief mesh must contain measurable elevation variation.")
		return
	if minimum_normal_up < 0.90:
		_fail(world, "Generated terrain normals must face upward so the soil receives direct light.")
		return
	var visual_mesh: ArrayMesh = world.call("_make_terrain_mesh", 256, true)
	var collision_mesh: ArrayMesh = world.call("_make_terrain_mesh", 192, false)
	var visual_arrays := visual_mesh.surface_get_arrays(0)
	var visual_vertices: PackedVector3Array = visual_arrays[Mesh.ARRAY_VERTEX]
	var visual_indices: PackedInt32Array = visual_arrays[Mesh.ARRAY_INDEX]
	var collision_arrays := collision_mesh.surface_get_arrays(0)
	var collision_vertices: PackedVector3Array = collision_arrays[Mesh.ARRAY_VERTEX]
	var collision_indices: PackedInt32Array = collision_arrays[Mesh.ARRAY_INDEX]
	var collision_normals = collision_arrays[Mesh.ARRAY_NORMAL]
	if visual_vertices.size() != 257 * 257 or collision_vertices.size() != 193 * 193:
		_fail(world, "Visual and collision terrain must use one shared vertex per lattice point at their authored 256/192 segment budgets.")
		return
	if visual_indices.size() != 256 * 256 * 6 or collision_indices.size() != 192 * 192 * 6:
		_fail(world, "Visual and collision terrain index buffers must preserve all six indices per grid cell.")
		return
	if collision_vertices.size() >= visual_vertices.size() * 0.60 or (collision_normals != null and not collision_normals.is_empty()):
		_fail(world, "Collision terrain must use at least 40% fewer unique vertices than the visual grid and omit unused normals.")
		return
	var maximum_collision_error := 0.0
	for sample_x in range(21):
		for sample_z in range(21):
			var point := Vector2(-210.0 + float(sample_x) * 21.0,
				-210.0 + float(sample_z) * 21.0)
			var actual_height: float = world.call("_terrain_height", point)
			var sampled_height := _sample_mesh_height(collision_vertices, collision_indices, 192, point)
			maximum_collision_error = maxf(maximum_collision_error, absf(actual_height - sampled_height))
	if maximum_collision_error > 0.08:
		_fail(world, "Reduced terrain collision grid deviates from the authored height field by "
			+ str(maximum_collision_error) + " m; limit is 0.08 m.")
		return

	print("Terrain relief regression passed: basin=", snappedf(max_sample - min_sample, 0.01),
		" m range, arroyo bank=", snappedf(bank_height - channel_height, 0.01),
		" m above channel, ", indices.size() / 3,
		" indexed visual test triangles, ", snappedf((1.0 - float(collision_vertices.size()) / float(visual_vertices.size())) * 100.0, 0.1),
		"% fewer unique collision-grid vertices, max collision height error=",
		snappedf(maximum_collision_error, 0.001), " m and upward generated normals (minimum Y=",
		snappedf(minimum_normal_up, 0.001), ").")
	world.free()
	quit(0)


func _sample_mesh_height(vertices: PackedVector3Array, indices: PackedInt32Array, segments: int, point: Vector2) -> float:
	var step := 520.0 / float(segments)
	var cell_x := clampi(floori((point.x + 260.0) / step), 0, segments - 1)
	var cell_z := clampi(floori((point.y + 260.0) / step), 0, segments - 1)
	var x0 := -260.0 + float(cell_x) * step
	var z0 := -260.0 + float(cell_z) * step
	var u := clampf((point.x - x0) / step, 0.0, 1.0)
	var v := clampf((point.y - z0) / step, 0.0, 1.0)
	var first := (cell_z * segments + cell_x) * 6
	var a: Vector3 = vertices[indices[first]]
	var b: Vector3 = vertices[indices[first + 1]]
	var c: Vector3 = vertices[indices[first + 2]]
	var d: Vector3 = vertices[indices[first + 4]]
	if u + v <= 1.0:
		return a.y * (1.0 - u - v) + b.y * u + c.y * v
	return b.y * (1.0 - v) + d.y * (u + v - 1.0) + c.y * (1.0 - u)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
