extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	var body := world.find_child("TriceratopsBody", true, false) as MeshInstance3D
	if body == null or body.mesh == null or body.mesh.get_surface_count() != 1:
		_fail(world, "Triceratops must use one continuous body shell.")
		return
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bounds := body.mesh.get_aabb()
	if vertices.size() < 4500 or vertices.size() % 3 != 0 or normals.size() != vertices.size():
		_fail(world, "Triceratops body loft must retain dense triangulation and generated normals.")
		return
	if bounds.size.x < 1.8 or bounds.size.y < 1.45 or bounds.size.z < 3.3:
		_fail(world, "Triceratops body loft must preserve a broad barrel, deep chest and tapered pelvis.")
		return
	for normal in normals:
		if not normal.is_finite() or normal.length() < 0.9:
			_fail(world, "Triceratops body loft contains invalid or degenerate normals.")
			return
	print("Triceratops body regression passed: ", vertices.size() / 3,
		" triangles, ", vertices.size(), " vertices, and continuous shoulder-to-pelvis bounds.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
