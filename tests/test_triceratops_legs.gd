extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	var pivots: Array[Node] = []
	_collect_named(world, "TriceratopsLegPivot_", pivots)
	if pivots.size() != 4:
		_fail(world, "Triceratops must have four independently articulated leg pivots.")
		return
	var toe_pads := 0
	for pivot_node in pivots:
		var pivot := pivot_node as Node3D
		var leg := pivot.get_node_or_null("TriceratopsLegMass") as MeshInstance3D
		if leg == null or not leg.mesh is ArrayMesh:
			_fail(world, "Every triceratops leg must be one continuous lofted mesh.")
			return
		var arrays := leg.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bounds := leg.mesh.get_aabb()
		if vertices.size() < 1500 or normals.size() != vertices.size():
			_fail(world, "Triceratops leg loft is missing dense geometry or generated normals.")
			return
		if bounds.size.x < 0.5 or bounds.size.y < 1.2 or bounds.size.z < 0.55:
			_fail(world, "Triceratops leg loft must transition from a broad limb into a grounded foot.")
			return
		if absf(bounds.position.y + 1.12) > 0.035:
			_fail(world, "Triceratops leg sole must terminate at the authored ground-contact plane.")
			return
		for child in pivot.get_children():
			if child.name.begins_with("TriceratopsToePad_"):
				toe_pads += 1
		var sole_offset_z := -0.28 if pivot.position.z < 0.0 else -0.29
		var sole_xz := Vector2(pivot.position.x, pivot.position.z + sole_offset_z)
		var sole_height := pivot.position.y + bounds.position.y
		var ground := float(world.call("_terrain_height", sole_xz))
		if absf(sole_height - ground) > 0.06:
			_fail(world, "Triceratops leg sole is not aligned to the terrain beneath its foot.")
			return
	if toe_pads != 12:
		_fail(world, "Each of the four triceratops feet must retain three toe pads.")
		return
	print("Triceratops leg regression passed: four continuous lofts, twelve toe pads, and terrain-aligned soles.")
	world.free()
	quit(0)

func _collect_named(node: Node, prefix: String, output: Array[Node]) -> void:
	for child in node.get_children():
		if child.name.begins_with(prefix):
			output.append(child)
		_collect_named(child, prefix, output)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
