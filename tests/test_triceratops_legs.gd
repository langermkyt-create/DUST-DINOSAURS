extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var front_mesh := world.call("_make_triceratops_leg_mesh", true) as ArrayMesh
	var hind_mesh := world.call("_make_triceratops_leg_mesh", false) as ArrayMesh
	if front_mesh == null or hind_mesh == null:
		_fail(world, "Fore and hind leg generators must both return meshes.")
		return
	var leg_meshes: Array[ArrayMesh] = [front_mesh, hind_mesh]
	for leg_mesh in leg_meshes:
		if leg_mesh.get_surface_count() != 1:
			_fail(world, "Each triceratops limb must be one continuous lofted surface.")
			return
		var arrays: Array = leg_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bounds: AABB = leg_mesh.get_aabb()
		if vertices.size() < 1500 or normals.size() != vertices.size():
			_fail(world, "Triceratops leg loft is missing dense geometry or generated normals.")
			return
		if bounds.size.x < 0.5 or bounds.size.y < 1.2 or bounds.size.z < 0.55:
			_fail(world, "Triceratops leg loft must transition from a broad limb into a grounded foot.")
			return
		if absf(bounds.position.y + 1.12) > 0.035:
			_fail(world, "Triceratops leg sole must terminate at the authored ground-contact plane.")
			return
		for normal in normals:
			if not normal.is_finite() or normal.length() < 0.9:
				_fail(world, "Triceratops leg loft contains invalid or degenerate normals.")
				return
	var pivot := Node3D.new()
	var hide := StandardMaterial3D.new()
	var horn := StandardMaterial3D.new()
	world.call("_build_triceratops_toes", pivot, hide, horn)
	var toe_pads := 0
	var claws := 0
	for child in pivot.get_children():
		if child.name.begins_with("TriceratopsToePad_"):
			toe_pads += 1
		elif child.name.begins_with("TriceratopsToeClaw_"):
			claws += 1
	if toe_pads != 3 or claws != 3:
		_fail(world, "Each triceratops foot must retain three toe pads and three tapered claws.")
		return
	for size in [0.66, 0.78, 1.0]:
		var root_height: float = 0.37
		var ground_height: float = -0.18
		var pivot_y: float = float(world.call("_triceratops_leg_pivot_y", root_height, ground_height, size))
		var sole_world_y: float = root_height + (pivot_y - 1.12) * size
		if absf(sole_world_y - ground_height) > 0.0001:
			_fail(world, "Triceratops sole-height solver must preserve ground contact at every herd scale.")
			return
	print("Triceratops leg regression passed: fore/hind lofts, three toes and claws per foot, and scale-aware sole contact.")
	pivot.free()
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
