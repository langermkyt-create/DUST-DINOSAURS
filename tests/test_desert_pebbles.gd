extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var repeated_world := Node3D.new()
	repeated_world.set_script(load("res://scripts/world.gd"))
	for variant in range(2):
		var mesh: ArrayMesh = world.call("_make_desert_pebble_mesh", variant)
		var repeated: ArrayMesh = world.call("_make_desert_pebble_mesh", variant)
		if mesh == null or mesh.get_surface_count() != 1:
			_fail(world, repeated_world, "Each desert pebble variant must use one faceted surface.")
			return
		var arrays := mesh.surface_get_arrays(0)
		var repeated_arrays := repeated.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var repeated_vertices: PackedVector3Array = repeated_arrays[Mesh.ARRAY_VERTEX]
		if vertices.size() != 240 or vertices.size() % 3 != 0:
			_fail(world, repeated_world, "One-subdivision pebble mesh must contain exactly eighty faceted triangles.")
			return
		if normals.size() != vertices.size() or colors.size() != vertices.size():
			_fail(world, repeated_world, "Every pebble triangle must retain generated normals and sediment vertex colors.")
			return
		for index in range(vertices.size()):
			if not is_finite(normals[index].x) or not is_finite(normals[index].y) or not is_finite(normals[index].z):
				_fail(world, repeated_world, "Pebble normals must remain finite.")
				return
			if vertices[index].distance_squared_to(repeated_vertices[index]) > 0.000001:
				_fail(world, repeated_world, "Pebble geometry must be deterministic for each authored variant.")
				return
		var bounds := mesh.get_aabb()
		if bounds.size.y >= bounds.size.x or bounds.size.y >= bounds.size.z:
			_fail(world, repeated_world, "Desert pebbles must retain a flattened, naturally weathered silhouette.")
			return
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		if material == null or not material.vertex_color_use_as_albedo or material.roughness < 0.9:
			_fail(world, repeated_world, "Pebbles must use rough layered sediment colors rather than a smooth sphere material.")
			return
	world.call("_scatter_ground_detail")
	repeated_world.call("_scatter_ground_detail")
	if world.get_child_count() != 3 or repeated_world.get_child_count() != 3:
		_fail(world, repeated_world, "Ground detail must remain batched into one tuft node and two pebble nodes.")
		return
	for variant in range(2):
		var node_name := "DesertPebbles_" + str(variant)
		var first_batch := world.get_node_or_null(node_name) as MultiMeshInstance3D
		var second_batch := repeated_world.get_node_or_null(node_name) as MultiMeshInstance3D
		if first_batch == null or second_batch == null or first_batch.multimesh.instance_count != 170:
			_fail(world, repeated_world, "Each pebble variant must retain one 170-instance batch.")
			return
		if first_batch.multimesh.mesh == null or first_batch.multimesh.mesh.get_surface_count() != 1:
			_fail(world, repeated_world, "Instanced pebble batches must use the new faceted mesh.")
			return
		var first_positions: PackedVector3Array = first_batch.get_meta("placement_positions")
		var second_positions: PackedVector3Array = second_batch.get_meta("placement_positions")
		if first_positions.size() != 170 or second_positions.size() != 170:
			_fail(world, repeated_world, "Each pebble batch must retain all 170 authored placement records.")
			return
		for index in range(170):
			var first_position: Vector3 = first_positions[index]
			var second_position: Vector3 = second_positions[index]
			if first_position.distance_squared_to(second_position) > 0.000001:
				_fail(world, repeated_world, "Seeded pebble placement must remain deterministic.")
				return
			var expected_height: float = float(world.call(
				"_terrain_height", Vector2(first_position.x, first_position.z))) + 0.035
			if absf(first_position.y - expected_height) > 0.001:
				_fail(world, repeated_world, "Pebble placement must follow the authored terrain height.")
				return
	print("Desert pebble regression passed: two deterministic 80-triangle sediment variants and 340 terrain-aligned instances.")
	world.free()
	repeated_world.free()
	quit(0)

func _fail(world: Node3D, repeated_world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	if is_instance_valid(repeated_world):
		repeated_world.free()
	push_error(message)
	quit(1)
