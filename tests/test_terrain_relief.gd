extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var wash_center: float = world.call("_terrain_wash_center", 0.0)
	var channel_height: float = world.call("_terrain_height", Vector2(0.0, wash_center))
	var bank_height: float = world.call("_terrain_height", Vector2(0.0, wash_center + 12.0))
	if bank_height - channel_height < 0.25:
		_fail(world, "The dry arroyo must be visibly lower than its bank shoulders.")
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
	print("Terrain relief regression passed: winding arroyo, raised shoulders, ", vertices.size() / 3,
		" triangles, and matching generated vertex normals.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
