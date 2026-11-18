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
	if vertices.size() != 48 * 48 * 6 or normals.size() != vertices.size():
		_fail(world, "Terrain relief mesh must preserve complete triangles and generated normals.")
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
	var visual_vertices: PackedVector3Array = visual_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var collision_arrays := collision_mesh.surface_get_arrays(0)
	var collision_vertices: PackedVector3Array = collision_arrays[Mesh.ARRAY_VERTEX]
	var collision_normals = collision_arrays[Mesh.ARRAY_NORMAL]
	if visual_vertices.size() != 256 * 256 * 6 or collision_vertices.size() != 192 * 192 * 6:
		_fail(world, "Visual and collision terrain grids must use their authored 256/192 segment budgets.")
		return
	if collision_vertices.size() >= visual_vertices.size() * 0.60 or (collision_normals != null and not collision_normals.is_empty()):
		_fail(world, "Collision terrain must reduce submitted vertices by at least 40% and omit unused normals.")
		return
	var maximum_collision_error := 0.0
	for sample_x in range(21):
		for sample_z in range(21):
			var point := Vector2(-210.0 + float(sample_x) * 21.0,
				-210.0 + float(sample_z) * 21.0)
			var actual_height: float = world.call("_terrain_height", point)
			var sampled_height := _sample_mesh_height(collision_vertices, 192, point)
			maximum_collision_error = maxf(maximum_collision_error, absf(actual_height - sampled_height))
	if maximum_collision_error > 0.08:
		_fail(world, "Reduced terrain collision grid deviates from the authored height field by "
			+ str(maximum_collision_error) + " m; limit is 0.08 m.")
		return

	print("Terrain relief regression passed: basin=", snappedf(max_sample - min_sample, 0.01),
		" m range, arroyo bank=", snappedf(bank_height - channel_height, 0.01),
		" m above channel, ", vertices.size() / 3,
		" visual test triangles, 43.75% fewer collision vertices, max collision height error=",
		snappedf(maximum_collision_error, 0.001), " m and upward generated normals (minimum Y=",
		snappedf(minimum_normal_up, 0.001), ").")
	world.free()
	quit(0)


func _sample_mesh_height(vertices: PackedVector3Array, segments: int, point: Vector2) -> float:
	var step := 520.0 / float(segments)
	var cell_x := clampi(floori((point.x + 260.0) / step), 0, segments - 1)
	var cell_z := clampi(floori((point.y + 260.0) / step), 0, segments - 1)
	var x0 := -260.0 + float(cell_x) * step
	var z0 := -260.0 + float(cell_z) * step
	var u := clampf((point.x - x0) / step, 0.0, 1.0)
	var v := clampf((point.y - z0) / step, 0.0, 1.0)
	var first := (cell_z * segments + cell_x) * 6
	var a: Vector3 = vertices[first]
	var b: Vector3 = vertices[first + 1]
	var c: Vector3 = vertices[first + 2]
	var d: Vector3 = vertices[first + 4]
	if u + v <= 1.0:
		return a.y * (1.0 - u - v) + b.y * u + c.y * v
	return b.y * (1.0 - v) + d.y * (u + v - 1.0) + c.y * (1.0 - u)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
