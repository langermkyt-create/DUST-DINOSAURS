extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var mesh: ArrayMesh = world.call("_make_tapered_tail_mesh", 3.0, 0.5, 0.18)
	if mesh == null or mesh.get_surface_count() != 1:
		_fail(world, "Tapered tail builder must return one continuous surface.")
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.size() % 3 != 0 or normals.size() != vertices.size():
		_fail(world, "Tail mesh must contain complete triangles and generated normals.")
		return
	var base_radius := 0.0
	var tip_radius := 0.0
	var tip_center_y := 0.18 * sin(PI * 0.8)
	for vertex in vertices:
		if absf(vertex.z) < 0.0001:
			base_radius = maxf(base_radius, Vector2(vertex.x, vertex.y).length())
		if absf(vertex.z - 3.0) < 0.0001:
			tip_radius = maxf(tip_radius, Vector2(vertex.x, vertex.y - tip_center_y).length())
	if base_radius < 0.45 or tip_radius > base_radius * 0.08:
		_fail(world, "Tail silhouette must taper continuously from a broad base to a narrow tip.")
		return

	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	world.call("_build_tyrannosaur", Vector3(20.0, 0.0, -20.0), 1.0)
	var triceratops_tail := world.find_child("TriceratopsTail", true, false) as MeshInstance3D
	var tyrannosaur_tail := world.find_child("TyrannosaurTail", true, false) as MeshInstance3D
	if triceratops_tail == null or tyrannosaur_tail == null:
		_fail(world, "Both dinosaur species must install the shared tapered tail mesh.")
		return
	if triceratops_tail.mesh == null or tyrannosaur_tail.mesh == null:
		_fail(world, "Dinosaur tail mesh integration must not leave empty instances.")
		return
	print("Dinosaur tail regression passed: ", vertices.size() / 3,
		" tapered triangles, generated normals, and both species integrated.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
