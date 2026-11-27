extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	world.call("_make_triceratops", Vector3(18.0, 0.0, -18.0), 0.78, 0.45)

	if world.get_child_count() != 2:
		_fail(world, "Tail attachment regression must construct two differently scaled herd animals.")
		return
	var first_animal := world.get_child(0) as Node3D
	var second_animal := world.get_child(1) as Node3D
	var first_body := first_animal.get_node_or_null("TriceratopsBody") as MeshInstance3D
	var second_body := second_animal.get_node_or_null("TriceratopsBody") as MeshInstance3D
	var first_pivot := first_animal.get_node_or_null("TriceratopsTailPivot") as Node3D
	var second_pivot := second_animal.get_node_or_null("TriceratopsTailPivot") as Node3D
	var first_tail := first_animal.find_child("TriceratopsTail", true, false) as MeshInstance3D
	var second_tail := second_animal.find_child("TriceratopsTail", true, false) as MeshInstance3D
	if first_body == null or second_body == null or first_pivot == null or second_pivot == null or first_tail == null or second_tail == null:
		_fail(world, "Each triceratops must expose a body, named tail pivot and tail mesh for attachment validation.")
		return
	if first_tail.mesh == null or first_tail.mesh != second_tail.mesh:
		_fail(world, "Herd triceratops must reuse one cached tail mesh.")
		return
	if first_tail.material_override == second_tail.material_override:
		_fail(world, "Each animal must retain its own skin material while sharing only immutable tail geometry.")
		return
	var tail_arrays := first_tail.mesh.surface_get_arrays(0)
	var tail_vertices: PackedVector3Array = tail_arrays[Mesh.ARRAY_VERTEX]
	var tail_indices: PackedInt32Array = tail_arrays[Mesh.ARRAY_INDEX]
	if tail_vertices.size() != 242 or tail_indices.size() != 1440:
		_fail(world, "High-resolution triceratops tail must retain 12 rings × 20 sides with indexed geometry.")
		return
	if not _verify_embedded_root(world, first_body, first_pivot, first_tail):
		return
	if not _verify_embedded_root(world, second_body, second_pivot, second_tail):
		return

	print("Triceratops tail attachment regression passed: both scaled/yawed animals bury the indexed tail cap inside the pelvis and reuse one shared tail mesh.")
	world.free()
	quit(0)


func _verify_embedded_root(world: Node3D, body: MeshInstance3D, pivot: Node3D, tail: MeshInstance3D) -> bool:
	if body.mesh == null or tail.mesh == null:
		_fail(world, "Pelvis and tail must both have generated meshes.")
		return false
	var body_vertices: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tail_vertices: PackedVector3Array = tail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nearest_ring_z := 0.0
	var nearest_delta := INF
	for vertex in body_vertices:
		var delta := absf(vertex.z - pivot.position.z)
		if delta < nearest_delta:
			nearest_delta = delta
			nearest_ring_z = vertex.z
	if nearest_delta > 0.08:
		_fail(world, "Tail root must sit within the rear pelvis loft, not beyond its last profile ring.")
		return false

	var ring_vertex_count := 0
	var ring_half_width := 0.0
	var ring_min_y := INF
	var ring_max_y := -INF
	for vertex in body_vertices:
		if absf(vertex.z - nearest_ring_z) <= 0.0001:
			ring_vertex_count += 1
			ring_half_width = maxf(ring_half_width, absf(vertex.x))
			ring_min_y = minf(ring_min_y, vertex.y)
			ring_max_y = maxf(ring_max_y, vertex.y)
	if ring_vertex_count < 20:
		_fail(world, "Pelvis attachment section must resolve to a complete loft ring.")
		return false
	var ring_center_y := (ring_min_y + ring_max_y) * 0.5
	var ring_half_height := (ring_max_y - ring_min_y) * 0.5
	if ring_half_width <= 0.39 or ring_half_height <= 0.30:
		_fail(world, "Pelvis section must be wide/deep enough to contain the tail root cap.")
		return false

	var root_point_count := 0
	var maximum_ellipse_ratio := 0.0
	for vertex in tail_vertices:
		if absf(vertex.z) <= 0.0001:
			root_point_count += 1
			var root_point := pivot.position + vertex
			var ellipse_ratio := pow(root_point.x / ring_half_width, 2.0) + pow((root_point.y - ring_center_y) / ring_half_height, 2.0)
			maximum_ellipse_ratio = maxf(maximum_ellipse_ratio, ellipse_ratio)
			if absf(root_point.z - nearest_ring_z) > 0.08:
				_fail(world, "Tail cap plane must remain aligned with the sampled pelvis cross-section.")
				return false
	if root_point_count < 20:
		_fail(world, "Tail must retain a complete indexed root cap inside the pelvis.")
		return false
	if maximum_ellipse_ratio >= 0.92:
		_fail(world, "Every tail root-cap vertex must remain inside the pelvis cross-section to prevent a visible gap.")
		return false
	var body_rear_z := body.mesh.get_aabb().end.z
	if body_rear_z - pivot.position.z < 0.18:
		_fail(world, "Tail cap must remain buried at least 0.18 m inside the rear body silhouette.")
		return false

	# The first tail ring that reaches the rear body plane must cover the closed
	# pelvis cap; otherwise the root can be buried yet still leave a visible rim.
	var body_rear_half_width := 0.0
	var body_rear_min_y := INF
	var body_rear_max_y := -INF
	for vertex in body_vertices:
		if absf(vertex.z - body_rear_z) <= 0.0001:
			body_rear_half_width = maxf(body_rear_half_width, absf(vertex.x))
			body_rear_min_y = minf(body_rear_min_y, vertex.y)
			body_rear_max_y = maxf(body_rear_max_y, vertex.y)
	var target_tail_z := body_rear_z - pivot.position.z
	var nearest_tail_ring_z := 0.0
	var nearest_tail_delta := INF
	for vertex in tail_vertices:
		var delta := absf(vertex.z - target_tail_z)
		if delta < nearest_tail_delta:
			nearest_tail_delta = delta
			nearest_tail_ring_z = vertex.z
	var tail_ring_count := 0
	var tail_half_width := 0.0
	var tail_min_y := INF
	var tail_max_y := -INF
	for vertex in tail_vertices:
		if absf(vertex.z - nearest_tail_ring_z) <= 0.0001:
			tail_ring_count += 1
			tail_half_width = maxf(tail_half_width, absf(vertex.x))
			tail_min_y = minf(tail_min_y, pivot.position.y + vertex.y)
			tail_max_y = maxf(tail_max_y, pivot.position.y + vertex.y)
	if nearest_tail_delta > 0.04 or tail_ring_count < 20:
		_fail(world, "A complete tapered-tail ring must cross the rear pelvis cap plane.")
		return false
	if tail_half_width < body_rear_half_width - 0.02 or tail_min_y > body_rear_min_y + 0.02 or tail_max_y < body_rear_max_y - 0.02:
		_fail(world, "The tail's first rear-plane ring must cover the pelvis cap in width and height to hide the attachment seam.")
		return false
	return true


func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
