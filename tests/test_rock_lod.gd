extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	var world_script: Script = load("res://scripts/world.gd")
	world_under_test = Node3D.new()
	world_under_test.set_script(world_script)
	world_under_test.call("_rock_formation", Vector3.ZERO, 1.0)

	if world_under_test.get_child_count() != 1:
		_fail("Rock builder did not create exactly one static body.")
		return
	var rock_body := world_under_test.get_child(0) as StaticBody3D
	var high := rock_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var low := rock_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var collision := rock_body.get_node_or_null("RockCollision") as CollisionShape3D
	if high == null or low == null or collision == null:
		_fail("Rock must contain high-detail, distant LOD, and collision nodes.")
		return
	if high.mesh == null or low.mesh == null:
		_fail("Rock LOD meshes must both be assigned.")
		return
	var high_arrays := high.mesh.surface_get_arrays(0)
	var low_arrays := low.mesh.surface_get_arrays(0)
	var high_vertices: PackedVector3Array = high_arrays[Mesh.ARRAY_VERTEX]
	var low_vertices: PackedVector3Array = low_arrays[Mesh.ARRAY_VERTEX]
	if high_vertices.size() % 3 != 0 or low_vertices.size() % 3 != 0:
		_fail("Rock meshes must contain complete triangles.")
		return
	if low_vertices.is_empty() or low_vertices.size() >= high_vertices.size():
		_fail("Distant rock LOD must be non-empty and cheaper than the near mesh.")
		return
	if high.visibility_range_end <= low.visibility_range_begin:
		_fail("Near and distant rock visibility ranges must overlap.")
		return
	if collision.shape == null or not (collision.shape is ConcavePolygonShape3D):
		_fail("Rock collision must use the detailed triangle mesh.")
		return
	if high.mesh.get_aabb().size.length_squared() <= 0.0 or low.mesh.get_aabb().size.length_squared() <= 0.0:
		_fail("Rock LOD meshes must have non-zero bounds.")
		return

	print("Rock LOD regression passed: high=", high_vertices.size() / 3,
		" triangles, low=", low_vertices.size() / 3, " triangles, detailed collision present.")
	world_under_test.free()
	world_under_test = null
	quit(0)

func _fail(message: String) -> void:
	if is_instance_valid(world_under_test):
		world_under_test.free()
		world_under_test = null
	push_error(message)
	quit(1)
