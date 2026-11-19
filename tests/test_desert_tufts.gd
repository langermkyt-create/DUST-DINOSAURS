extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var repeated_world := Node3D.new()
	repeated_world.set_script(load("res://scripts/world.gd"))
	var tuft_mesh: ArrayMesh = world.call("_make_desert_tuft_mesh")
	if tuft_mesh == null or tuft_mesh.get_surface_count() != 1:
		_fail(world, repeated_world, "Desert tuft builder must return one combined blade surface.")
		return
	var arrays := tuft_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if vertices.size() != 252 or normals.size() != vertices.size() or colors.size() != vertices.size():
		_fail(world, repeated_world, "Seven curved grass blades must retain 252 vertices, generated normals and per-vertex dry-tip colors.")
		return
	for index in range(vertices.size()):
		if not is_finite(vertices[index].x) or not is_finite(vertices[index].y) or not is_finite(vertices[index].z):
			_fail(world, repeated_world, "Curved grass blade vertices must remain finite.")
			return
		if not is_finite(normals[index].x) or not is_finite(normals[index].y) or not is_finite(normals[index].z):
			_fail(world, repeated_world, "Curved grass blade normals must remain finite.")
			return
	var bounds := tuft_mesh.get_aabb()
	if bounds.size.y < 0.30 or bounds.size.x < 0.12 or bounds.size.z < 0.12:
		_fail(world, repeated_world, "Desert tuft silhouette must remain upright, broad and grounded.")
		return
	var material := tuft_mesh.surface_get_material(0) as ShaderMaterial
	if material == null or material.shader == null:
		_fail(world, repeated_world, "Desert grass must retain its animated surface shader.")
		return
	for token in ["INSTANCE_CUSTOM.r", "INSTANCE_CUSTOM.g", "TIME", "VERTEX.z", "ROUGHNESS"]:
		if not material.shader.code.contains(token):
			_fail(world, repeated_world, "Grass wind shader is missing per-instance motion or a surface response: " + token)
			return
	world.call("_scatter_ground_detail")
	repeated_world.call("_scatter_ground_detail")
	if world.get_child_count() != 3 or repeated_world.get_child_count() != 3:
		_fail(world, repeated_world, "Ground cover must stay batched into one tuft node and two pebble nodes.")
		return
	var grass := world.get_node_or_null("DesertGrassTufts") as MultiMeshInstance3D
	var repeated_grass := repeated_world.get_node_or_null("DesertGrassTufts") as MultiMeshInstance3D
	if grass == null or repeated_grass == null or grass.multimesh.instance_count != 520:
		_fail(world, repeated_world, "The 520 grass tufts must remain in one instanced draw batch.")
		return
	if not grass.multimesh.use_custom_data:
		_fail(world, repeated_world, "Each grass tuft must carry its own wind phase.")
		return
	var phase_data := grass.multimesh.get_instance_custom_data(0)
	var repeated_phase_data := repeated_grass.multimesh.get_instance_custom_data(0)
	if absf(phase_data.r - repeated_phase_data.r) > 0.0001 or absf(phase_data.g - repeated_phase_data.g) > 0.0001:
		_fail(world, repeated_world, "Per-instance wind phases must be deterministic between runs.")
		return
	for index in range(520):
		var transform := grass.multimesh.get_instance_transform(index)
		var expected_height: float = float(world.call("_terrain_height", Vector2(transform.origin.x, transform.origin.z)))
		if absf(transform.origin.y - expected_height) > 0.001:
			_fail(world, repeated_world, "Grass roots must remain attached to the procedural terrain.")
			return
	for variant in range(2):
		var pebble_name := "DesertPebbles_" + str(variant)
		var pebble_batch := world.get_node_or_null(pebble_name) as MultiMeshInstance3D
		if pebble_batch == null or pebble_batch.multimesh.instance_count != 170:
			_fail(world, repeated_world, "Curved grass pass must preserve both 170-instance faceted pebble batches.")
			return
	print("Desert tuft regression passed: seven curved blades, per-instance deterministic wind phases, 520 terrain-rooted tufts and both pebble batches.")
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
