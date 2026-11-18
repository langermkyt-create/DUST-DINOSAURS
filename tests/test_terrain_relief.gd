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
	for vertex in vertices:
		min_height = minf(min_height, vertex.y)
		max_height = maxf(max_height, vertex.y)
	if max_height - min_height < 0.25:
		_fail(world, "Terrain relief mesh must contain measurable elevation variation.")
		return
	var upward_triangles := 0
	for index in range(0, vertices.size(), 3):
		var edge_a: Vector3 = vertices[index + 1] - vertices[index]
		var edge_b: Vector3 = vertices[index + 2] - vertices[index]
		var geometric_normal := edge_a.cross(edge_b).normalized()
		if geometric_normal.y < 0.90:
			_fail(world, "Terrain triangle winding must face upward across the complete basin.")
			return
		upward_triangles += 1
		for normal_index in range(index, index + 3):
			if normals[normal_index].length_squared() < 0.5:
				_fail(world, "Generated terrain vertex normals must be non-zero and normalized.")
				return
	print("Terrain relief regression passed: basin=", snappedf(max_sample - min_sample, 0.01),
		" m range, arroyo bank=", snappedf(bank_height - channel_height, 0.01),
		" m above channel, ", upward_triangles, " upward triangles and generated normals.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
