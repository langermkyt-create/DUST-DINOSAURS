extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var mesh: ArrayMesh = world.call("_make_roof_shingle_mesh", 1897)
	var repeated: ArrayMesh = world.call("_make_roof_shingle_mesh", 1897)
	if mesh == null or mesh.get_surface_count() != 1:
		_fail(world, "Roof shingle builder must return one mesh surface.")
		return
	var arrays := mesh.surface_get_arrays(0)
	var repeated_arrays := repeated.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var repeated_vertices: PackedVector3Array = repeated_arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() < 800 or vertices.size() % 3 != 0:
		_fail(world, "Gable roof must contain complete, individually staggered shingle triangles.")
		return
	if normals.size() != vertices.size() or colors.size() != vertices.size():
		_fail(world, "Roof shingles must carry generated normals and per-tile weathering colors.")
		return
	if vertices.size() != repeated_vertices.size():
		_fail(world, "Seeded roof shingle generation must be deterministic.")
		return
	for i in range(vertices.size()):
		if vertices[i].distance_squared_to(repeated_vertices[i]) > 0.000001:
			_fail(world, "Roof shingle geometry changed for the same seed.")
			return
		if absf(vertices[i].x) > 5.5 or vertices[i].y < 4.45 or vertices[i].y > 7.35 or absf(vertices[i].z) > 4.1:
			_fail(world, "Roof shingle vertex escaped the authored gable surface bounds.")
			return
	world.call("_build_building", Vector3.ZERO, "SALOON", Color(0.43, 0.18, 0.12), true)
	var building := world.get_child(0) as Node3D
	var installed := building.get_node_or_null("RoofShingles") as MeshInstance3D
	if installed == null or installed.mesh == null:
		_fail(world, "Built frontier buildings must install the shingle mesh.")
		return
	print("Roof shingle regression passed: ", vertices.size() / 3,
		" triangles, seeded weathering, generated normals, and building integration.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
