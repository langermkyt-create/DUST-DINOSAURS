extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	var frill := world.find_child("TriceratopsFrill", true, false) as MeshInstance3D
	if frill == null or frill.mesh == null or frill.mesh.get_surface_count() != 1:
		_fail(world, "Triceratops must install one closed frill plate mesh.")
		return
	var arrays := frill.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bounds := frill.mesh.get_aabb()
	if vertices.size() < 288 or vertices.size() % 3 != 0 or normals.size() != vertices.size():
		_fail(world, "Frill plate must contain front, back and perimeter triangles with generated normals.")
		return
	if bounds.size.z < 0.15 or bounds.size.x < 1.8 or bounds.size.y < 1.8:
		_fail(world, "Frill plate must preserve its broad scalloped silhouette and measurable thickness.")
		return
	print("Triceratops frill regression passed: ", vertices.size() / 3,
		" closed-plate triangles, generated normals, and ", snappedf(bounds.size.z, 0.01), " m thickness.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
