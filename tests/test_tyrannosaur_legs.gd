extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	world.call("_build_tyrannosaur", Vector3.ZERO, 1.0)
	var legs := world.find_children("TyrannosaurLegMass", "MeshInstance3D", true, false)
	if legs.size() != 2:
		_fail(world, "Tyrannosaur must install two continuous hind-leg masses.")
		return
	for leg_node in legs:
		var leg := leg_node as MeshInstance3D
		if leg.mesh == null or leg.mesh.get_surface_count() != 1:
			_fail(world, "Each hind leg must use one continuous lofted mesh.")
			return
		var arrays := leg.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bounds := leg.mesh.get_aabb()
		if vertices.size() < 900 or vertices.size() % 3 != 0 or normals.size() != vertices.size():
			_fail(world, "Hind-leg loft must contain complete triangles and generated normals.")
			return
		if bounds.size.y < 1.7 or bounds.size.x < 0.5 or bounds.size.z < 1.2:
			_fail(world, "Hind-leg loft must preserve a full thigh-to-foot silhouette.")
			return
	var toe_count := 0
	var claw_count := 0
	for mesh_node in world.find_children("*", "MeshInstance3D", true, false):
		if mesh_node.name.begins_with("TyrannosaurToe"):
			toe_count += 1
		elif mesh_node.name.begins_with("TyrannosaurClaw"):
			claw_count += 1
	if toe_count != 6 or claw_count != 6:
		_fail(world, "Both feet must retain three toe pads and three claws.")
		return
	print("Tyrannosaur leg regression passed: two continuous thigh-to-foot lofts, six toe pads and six claws.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
