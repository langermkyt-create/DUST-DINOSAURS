extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var head_mesh := world.call("_make_triceratops_head_mesh") as ArrayMesh
	var jaw_mesh := world.call("_make_triceratops_jaw_mesh") as ArrayMesh
	if not _validate_closed_loft(world, head_mesh, 3500, Vector3(1.0, 0.8, 1.25), "head"):
		return
	if not _validate_closed_loft(world, jaw_mesh, 1400, Vector3(0.35, 0.12, 0.7), "lower jaw"):
		return
	var brow_left := world.call("_make_triceratops_horn_mesh",
		Vector3(-0.40, 2.06, -2.13), Vector3(-0.55, 2.83, -2.78), 0.14,
		Vector3(-0.032, 0.10, -0.07)) as ArrayMesh
	var brow_right := world.call("_make_triceratops_horn_mesh",
		Vector3(0.40, 2.06, -2.13), Vector3(0.55, 2.83, -2.78), 0.14,
		Vector3(0.032, 0.10, -0.07)) as ArrayMesh
	var nasal := world.call("_make_triceratops_horn_mesh",
		Vector3(0.0, 1.72, -2.62), Vector3(0.0, 2.24, -3.02), 0.105,
		Vector3(0.0, 0.075, -0.045)) as ArrayMesh
	for horn_mesh in [brow_left, brow_right, nasal]:
		if not _validate_closed_loft(world, horn_mesh, 1500, Vector3(0.12, 0.3, 0.3), "horn"):
			return
	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	var head := world.find_child("TriceratopsHead", true, false) as MeshInstance3D
	var jaw := world.find_child("TriceratopsLowerJaw", true, false) as MeshInstance3D
	var rig := world.find_child("TriceratopsHeadRig", true, false) as Node3D
	if head == null or jaw == null or rig == null:
		_fail(world, "The live triceratops assembly must install its continuous head, jaw and shared head rig.")
		return
	if head.get_parent() != rig or jaw.get_parent() != rig:
		_fail(world, "Skull and lower jaw must share the animated head pivot.")
		return
	var sockets := 0
	var eyes := 0
	var brow_horns := 0
	var nasal_horns := 0
	var horn_roots := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if node.name == "TriceratopsEyeSocket":
			sockets += 1
		elif node.name == "TriceratopsEye":
			eyes += 1
		elif node.name == "TriceratopsBrowHorn":
			brow_horns += 1
		elif node.name == "TriceratopsNasalHorn":
			nasal_horns += 1
		elif node.name == "TriceratopsHornRoot":
			horn_roots += 1
	if sockets != 2 or eyes != 2:
		_fail(world, "Triceratops must have two recessed eye sockets and two eye globes.")
		return
	if brow_horns != 2 or nasal_horns != 1 or horn_roots != 3:
		_fail(world, "Triceratops must install two swept brow horns, one nasal horn and three root collars.")
		return
	print("Triceratops head regression passed: closed skull/jaw, paired eye sockets, two curved brow horns, one nasal horn and three root collars.")
	world.free()
	quit(0)


func _validate_closed_loft(world: Node3D, mesh: ArrayMesh, minimum_vertices: int, minimum_bounds: Vector3, label: String) -> bool:
	if mesh == null or mesh.get_surface_count() != 1:
		_fail(world, "Triceratops " + label + " generator must return one mesh surface.")
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bounds := mesh.get_aabb()
	if vertices.size() < minimum_vertices or vertices.size() % 3 != 0 or normals.size() != vertices.size():
		_fail(world, "Triceratops " + label + " loft must retain dense triangles and generated normals.")
		return false
	if bounds.size.x < minimum_bounds.x or bounds.size.y < minimum_bounds.y or bounds.size.z < minimum_bounds.z:
		_fail(world, "Triceratops " + label + " loft has insufficient anatomical bounds.")
		return false
	for normal in normals:
		if not normal.is_finite() or normal.length() < 0.9:
			_fail(world, "Triceratops " + label + " loft contains invalid or degenerate normals.")
			return false
	var edge_counts: Dictionary = {}
	for triangle_index in range(0, vertices.size(), 3):
		_count_edge(vertices[triangle_index], vertices[triangle_index + 1], edge_counts)
		_count_edge(vertices[triangle_index + 1], vertices[triangle_index + 2], edge_counts)
		_count_edge(vertices[triangle_index + 2], vertices[triangle_index], edge_counts)
	for edge in edge_counts:
		if int(edge_counts[edge]) != 2:
			_fail(world, "Triceratops " + label + " loft contains an open or non-manifold edge.")
			return false
	return true


func _count_edge(a: Vector3, b: Vector3, counts: Dictionary) -> void:
	var a_key := _point_key(a)
	var b_key := _point_key(b)
	var edge_key := a_key + "|" + b_key if a_key < b_key else b_key + "|" + a_key
	counts[edge_key] = int(counts.get(edge_key, 0)) + 1


func _point_key(point: Vector3) -> String:
	var quantized := Vector3i(roundi(point.x * 10000.0), roundi(point.y * 10000.0), roundi(point.z * 10000.0))
	return "%d,%d,%d" % [quantized.x, quantized.y, quantized.z]


func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
