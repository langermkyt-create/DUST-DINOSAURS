extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var mesh: ArrayMesh = world.call("_make_tyrannosaur_body_mesh")
	if mesh == null or mesh.get_surface_count() != 1:
		_fail(world, "Tyrannosaur body loft must produce one continuous surface.")
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bounds := mesh.get_aabb()
	if vertices.size() < 1200 or vertices.size() % 3 != 0 or normals.size() != vertices.size():
		_fail(world, "Tyrannosaur body loft must contain a dense, fully-normaled triangle surface.")
		return
	if bounds.size.x < 1.5 or bounds.size.y < 1.5 or bounds.size.z < 4.0:
		_fail(world, "Tyrannosaur body loft must retain muzzle-to-pelvis anatomical proportions.")
		return

	world.call("_build_tyrannosaur", Vector3.ZERO, 1.0)
	var body := world.find_child("TyrannosaurBody", true, false) as MeshInstance3D
	if body == null or body.mesh == null:
		_fail(world, "The live tyrannosaur must install the continuous body loft.")
		return
	print("Tyrannosaur anatomy regression passed: ", vertices.size() / 3,
		" continuous body triangles, generated normals, and live scene integration.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
