extends SceneTree

var second_world_under_test: Node3D

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var total_instanced_vertices := 0
	for variant in range(3):
		var mesh: ArrayMesh = world.call("_make_creosote_mesh", variant)
		var repeated: ArrayMesh = world.call("_make_creosote_mesh", variant)
		if mesh == null or mesh.get_surface_count() != 1:
			_fail(world, "Creosote builder must return one combined shrub surface.")
			return
		var arrays := mesh.surface_get_arrays(0)
		var repeated_arrays := repeated.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var repeated_vertices: PackedVector3Array = repeated_arrays[Mesh.ARRAY_VERTEX]
		if vertices.size() < 3000 or vertices.size() > 4000 or vertices.size() % 3 != 0:
			_fail(world, "Creosote mesh must retain a dense canopy within the 3,000–4,000 vertex performance budget.")
			return
		if normals.size() != vertices.size() or colors.size() != vertices.size():
			_fail(world, "Creosote mesh must carry generated normals and per-leaf color variation.")
			return
		if vertices.size() != repeated_vertices.size():
			_fail(world, "Creosote mesh generation must be deterministic for each variant.")
			return
		for index in range(vertices.size()):
			if vertices[index].distance_squared_to(repeated_vertices[index]) > 0.000001:
				_fail(world, "Creosote geometry changed for the same variant.")
				return
		total_instanced_vertices += vertices.size() * 42
		var bounds := mesh.get_aabb()
		if bounds.size.x < 0.9 or bounds.size.z < 0.9 or bounds.size.y < 0.6 or bounds.size.y > 1.8:
			_fail(world, "Creosote shrub proportions must remain low, broad and grounded.")
			return

	if total_instanced_vertices > 470000:
		_fail(world, "Three creosote batches exceed the 470k submitted-vertex budget: " + str(total_instanced_vertices))
		return
	world.call("_scatter_creosote_bushes")
	second_world_under_test = Node3D.new()
	second_world_under_test.set_script(load("res://scripts/world.gd"))
	second_world_under_test.call("_scatter_creosote_bushes")
	if world.get_child_count() != 3 or second_world_under_test.get_child_count() != 3:
		_fail(world, "Creosote variants must be batched into exactly three instanced nodes.")
		return
	for variant in range(3):
		var first := world.get_child(variant) as MultiMeshInstance3D
		var second := second_world_under_test.get_child(variant) as MultiMeshInstance3D
		if first == null or second == null or first.multimesh.instance_count != 42:
			_fail(world, "Each creosote variant must contain forty-two instanced shrubs.")
			return
		var first_positions: PackedVector3Array = first.get_meta("placement_positions")
		var second_positions: PackedVector3Array = second.get_meta("placement_positions")
		if first_positions.size() != 42 or second_positions.size() != 42:
			_fail(world, "Each creosote batch must retain forty-two authored placement records.")
			return
		for index in range(42):
			var position: Vector3 = first_positions[index]
			if position.distance_squared_to(second_positions[index]) > 0.000001:
				_fail(world, "Seeded creosote placement must be deterministic.")
				return
			var expected_height: float = world.call("_terrain_height", Vector2(position.x, position.z))
			var height_error := absf(position.y - expected_height)
			if height_error > 0.001:
				_fail(world, "Creosote root height mismatch: variant=" + str(variant)
					+ " index=" + str(index) + " actual=" + str(position.y)
					+ " expected=" + str(expected_height) + " error=" + str(height_error))
				return
			if Vector2(position.x, position.z).length() < 36.0:
				_fail(world, "Creosote shrubs must remain outside the settlement footprint.")
				return
			if absf(position.z - float(world.call("_terrain_wash_center", position.x))) < 12.0:
				_fail(world, "Creosote shrubs must not be scattered into the arroyo channel.")
				return
	print("Creosote regression passed: three volumetric canopy variants, ", total_instanced_vertices,
		" instanced source vertices, 126 deterministic terrain-aligned shrubs, and clear arroyo/settlement spacing.")
	world.free()
	second_world_under_test.free()
	second_world_under_test = null
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	if is_instance_valid(second_world_under_test):
		second_world_under_test.free()
		second_world_under_test = null
	push_error(message)
	quit(1)
