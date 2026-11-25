extends SceneTree

func _initialize() -> void:
	var first := Node3D.new()
	first.set_script(load("res://scripts/world.gd"))
	first.call("_rock_formation", Vector3(18.0, 0.0, -26.0), 1.0)
	var second := Node3D.new()
	second.set_script(load("res://scripts/world.gd"))
	second.call("_rock_formation", Vector3(18.0, 0.0, -26.0), 1.4)
	if first.get_child_count() != 1 or second.get_child_count() != 1:
		_fail(first, second, "Each authored outcrop must create one static body.")
		return
	var first_body := first.get_child(0) as StaticBody3D
	var second_body := second.get_child(0) as StaticBody3D
	var high := first_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var low := first_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var collision := first_body.get_node_or_null("RockCollision") as CollisionShape3D
	var repeated_high := second_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var repeated_low := second_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	if high == null or low == null or collision == null or repeated_high == null or repeated_low == null:
		_fail(first, second, "Outcrop must provide near, distant and collision geometry.")
		return
	if high.mesh == null or low.mesh == null or high.mesh.get_surface_count() != 1 or low.mesh.get_surface_count() != 1:
		_fail(first, second, "Both outcrop LODs must use one complete mesh surface.")
		return
	var high_arrays := high.mesh.surface_get_arrays(0)
	var low_arrays := low.mesh.surface_get_arrays(0)
	var repeated_arrays := repeated_high.mesh.surface_get_arrays(0)
	var high_vertices: PackedVector3Array = high_arrays[Mesh.ARRAY_VERTEX]
	var low_vertices: PackedVector3Array = low_arrays[Mesh.ARRAY_VERTEX]
	var repeated_vertices: PackedVector3Array = repeated_arrays[Mesh.ARRAY_VERTEX]
	var high_normals: PackedVector3Array = high_arrays[Mesh.ARRAY_NORMAL]
	var high_colors: PackedColorArray = high_arrays[Mesh.ARRAY_COLOR]
	if high_vertices.size() != 480 or low_vertices.size() != 144:
		_fail(first, second, "Sixteen-sided near outcrop and eight-sided distant LOD must retain 480 and 144 vertices.")
		return
	if high_normals.size() != high_vertices.size() or high_colors.size() != high_vertices.size():
		_fail(first, second, "Near outcrop must retain generated normals and four-band vertex strata.")
		return
	for index in range(high_vertices.size()):
		if not is_finite(high_vertices[index].x) or not is_finite(high_vertices[index].y) or not is_finite(high_vertices[index].z):
			_fail(first, second, "Outcrop vertices must remain finite after seeded erosion offsets.")
			return
		if high_vertices[index].distance_squared_to(repeated_vertices[index]) > 0.000001:
			_fail(first, second, "The same outcrop position must produce deterministic weathered geometry.")
			return
	if low_vertices.size() >= high_vertices.size():
		_fail(first, second, "Distant outcrop LOD must be cheaper than the near silhouette.")
		return
	if collision.shape == null or not (collision.shape is ConcavePolygonShape3D):
		_fail(first, second, "Outcrop collision must use a static concave triangle mesh.")
		return
	var collision_faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
	if collision_faces.size() != low_vertices.size() or collision_faces.size() >= high_vertices.size() * 0.60:
		_fail(first, second, "Outcrop collision must reuse the lower-detail silhouette and reduce collision triangles by at least 40%.")
		return
	if absf(high.visibility_range_end - 132.0) > 0.01 or absf(low.visibility_range_begin - 118.0) > 0.01:
		_fail(first, second, "Unit-scale outcrop must retain the authored near/far LOD handoff distances.")
		return
	if absf(repeated_high.visibility_range_end - 184.8) > 0.01 or absf(repeated_low.visibility_range_begin - 165.2) > 0.01:
		_fail(first, second, "Scaled outcrop must proportionally move its LOD handoff distances.")
		return
	if high.visibility_range_end <= low.visibility_range_begin:
		_fail(first, second, "Near and distant outcrop visibility ranges must overlap for a stable handoff.")
		return
	var high_material := high.material_override as ShaderMaterial
	var low_material := low.material_override as ShaderMaterial
	if high_material == null or low_material == null or high_material.shader.code != low_material.shader.code:
		_fail(first, second, "Both outcrop LODs must share the same layered sandstone response.")
		return
	print("Rock formation regression passed: 16-sided stratified near mesh, 8-sided distant/collision mesh, scale-aware handoff and deterministic erosion.")
	first.free()
	second.free()
	quit(0)

func _fail(first: Node3D, second: Node3D, message: String) -> void:
	if is_instance_valid(first):
		first.free()
	if is_instance_valid(second):
		second.free()
	push_error(message)
	quit(1)
