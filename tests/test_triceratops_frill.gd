extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var center := Vector3(0, 2.12, -1.57)
	var rim := PackedVector3Array()
	for i in range(25):
		var angle := PI * float(i) / 24.0
		var scallop := 1.0 + 0.055 * sin(float(i) * PI / 3.0)
		rim.append(Vector3(cos(angle) * 1.02 * scallop, sin(angle) * 1.13 * scallop, -0.12 * sin(angle)))
	var frill_mesh := world.call("_make_triceratops_frill_mesh", center, rim, 0.16) as ArrayMesh
	if frill_mesh == null or frill_mesh.get_surface_count() != 1:
		_fail(world, "Triceratops must generate one closed frill plate mesh.")
		return
	var arrays := frill_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bounds := frill_mesh.get_aabb()
	if vertices.size() < 250 or normals.size() != vertices.size():
		_fail(world, "Frill plate must contain a curved front, rear and generated normals.")
		return
	if bounds.size.z < 0.15 or bounds.size.x < 1.8 or bounds.size.y < 1.0:
		_fail(world, "Frill plate must preserve its broad scalloped silhouette and measurable thickness.")
		return
	var triangle_indices := PackedInt32Array()
	if indices.size() > 0:
		triangle_indices = indices
	else:
		for vertex_index in range(vertices.size()):
			triangle_indices.append(vertex_index)
	if triangle_indices.size() % 3 != 0:
		_fail(world, "Frill plate triangle index count must be divisible by three.")
		return
	var edge_counts: Dictionary = {}
	for triangle_index in range(0, triangle_indices.size(), 3):
		var a: Vector3 = vertices[triangle_indices[triangle_index]]
		var b: Vector3 = vertices[triangle_indices[triangle_index + 1]]
		var c: Vector3 = vertices[triangle_indices[triangle_index + 2]]
		_count_edge(a, b, edge_counts)
		_count_edge(b, c, edge_counts)
		_count_edge(c, a, edge_counts)
	for edge in edge_counts:
		if int(edge_counts[edge]) != 2:
			_fail(world, "Frill plate must be watertight; found a boundary or non-manifold edge.")
			return
	for normal in normals:
		if not normal.is_finite() or normal.length() < 0.9:
			_fail(world, "Frill plate contains invalid or degenerate normals.")
			return
	print("Triceratops frill regression passed: ", triangle_indices.size() / 3,
		" triangles, watertight basal chord and rim, curved faces, and generated normals.")
	world.free()
	quit(0)

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
