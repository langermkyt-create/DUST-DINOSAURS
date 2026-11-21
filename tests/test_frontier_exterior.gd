extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	world_under_test = Node3D.new()
	world_under_test.set_script(load("res://scripts/world.gd"))
	var shared_wood_shader: Shader
	var shared_roof_material: Material
	var building_types: Array[String] = [
		"SALOON", "GENERAL STORE", "SHERIFF", "STABLES", "HOTEL", "RAIL OFFICE"
	]
	for index in range(building_types.size()):
		world_under_test.call("_build_building",
			Vector3(float(index) * 30.0, 0.0, 0.0),
			building_types[index], Color(0.43, 0.25, 0.16), index % 2 == 0)
		var building := world_under_test.get_child(index)
		var wood_shader := world_under_test.get("_weathered_wood_shader") as Shader
		var roof_mesh := _find_named(building, "RoofShingles") as MeshInstance3D
		if wood_shader == null or roof_mesh == null or roof_mesh.material_override == null:
			_fail("Frontier buildings must initialize the shared timber shader and roof material.")
			return
		if index == 0:
			shared_wood_shader = wood_shader
			shared_roof_material = roof_mesh.material_override
		elif wood_shader != shared_wood_shader or roof_mesh.material_override != shared_roof_material:
			_fail("All six buildings must reuse the same wood shader and vertex-color shingle material.")
			return
		var siding_courses := _find_named(building, "SideSidingCourseBatch") as MultiMeshInstance3D
		if siding_courses == null or siding_courses.multimesh == null or siding_courses.multimesh.instance_count != 14:
			_fail("Both side elevations must batch seven exposed horizontal siding courses each.")
			return
		var course_positions: PackedVector3Array = siding_courses.get_meta("source_positions")
		var course_scales: PackedVector3Array = siding_courses.get_meta("source_scales")
		if course_positions.size() != 14 or course_scales.size() != 14:
			_fail("Siding-course batch must preserve deterministic positions and dimensions.")
			return
		for course_scale in course_scales:
			if course_scale.z < 6.8 or course_scale.y > 0.06:
				_fail("Siding courses must remain narrow horizontal boards across the side elevation.")
				return
		var side_trim := _find_named(building, "SideElevationTrimBatch") as MultiMeshInstance3D
		var side_rafters := _find_named(building, "SideRafterTailBatch") as MultiMeshInstance3D
		if side_trim == null or side_rafters == null:
			_fail("Side elevations must keep structural trim and exposed rafter tails in explicit batches.")
			return
		if side_trim.multimesh == null or side_trim.multimesh.instance_count != 12:
			_fail("Both side elevations must batch six posts, four belt rails and two eaves fascias.")
			return
		if side_rafters.multimesh == null or side_rafters.multimesh.instance_count != 10:
			_fail("Both side eaves must batch five exposed rafter tails each.")
			return
		var side_trim_positions: PackedVector3Array = side_trim.get_meta("source_positions")
		var side_trim_scales: PackedVector3Array = side_trim.get_meta("source_scales")
		if side_trim_positions.size() != 12 or side_trim_scales.size() != 12:
			_fail("Side trim batches must preserve deterministic source geometry.")
			return
		for post_index in range(3):
			if side_trim_scales[post_index].y < 3.9 or side_trim_scales[post_index].x > 0.2:
				_fail("Batched side posts must remain narrow full-height timber members, not wall-covering slabs.")
				return
		var shutter_panels := _find_named(building, "FrontWindowShutterPanels") as MultiMeshInstance3D
		var shutter_slats := _find_named(building, "FrontWindowShutterSlats") as MultiMeshInstance3D
		var shutter_hinges := _find_named(building, "FrontWindowShutterHinges") as MultiMeshInstance3D
		if shutter_panels == null or shutter_slats == null or shutter_hinges == null:
			_fail("Every street facade must retain batched shutter panels, slats and iron hinges.")
			return
		if shutter_panels.multimesh == null or shutter_panels.multimesh.instance_count != 4:
			_fail("Two front windows must each have a paired set of timber shutters.")
			return
		if shutter_slats.multimesh == null or shutter_slats.multimesh.instance_count != 16:
			_fail("Each shutter must have four individually spaced horizontal slats.")
			return
		if shutter_hinges.multimesh == null or shutter_hinges.multimesh.instance_count != 8:
			_fail("Each shutter must have two visible iron hinge straps.")
			return
		var panel_positions: PackedVector3Array = shutter_panels.get_meta("source_positions")
		var slat_positions: PackedVector3Array = shutter_slats.get_meta("source_positions")
		if panel_positions.size() != 4 or slat_positions.size() != 16:
			_fail("Shutter batches must preserve deterministic source positions for regression checks.")
			return
		for panel_position in panel_positions:
			if panel_position.z < 4.0 or absf(panel_position.y - 2.1) > 0.01:
				_fail("Shutters must sit on the exterior side of the front window frames.")
				return
		var sign_board := _find_named(building, "BuildingSignboard") as MeshInstance3D
		var trade_label := _find_named(building, "BuildingTradeLabel") as Label3D
		if sign_board == null or sign_board.mesh == null or trade_label == null:
			_fail("Every storefront must have a physical signboard carrying its trade label.")
			return
		var sign_rails := _find_named(building, "BuildingSignboardRails") as MultiMeshInstance3D
		var sign_hardware := _find_named(building, "BuildingSignboardHardware") as MultiMeshInstance3D
		var sign_bolts := _find_named(building, "BuildingSignboardBolts") as MultiMeshInstance3D
		if sign_rails == null or sign_hardware == null or sign_bolts == null:
			_fail("Trade signboard must retain batched rails, iron supports and corner fasteners.")
			return
		if sign_rails.multimesh == null or sign_rails.multimesh.instance_count != 4:
			_fail("Trade signboard must batch one top rail, one lower rail and two side rails.")
			return
		if sign_hardware.multimesh == null or sign_hardware.multimesh.instance_count != 4:
			_fail("Trade signboard must batch paired iron hangers and diagonal braces.")
			return
		if sign_bolts.multimesh == null or sign_bolts.multimesh.instance_count != 4:
			_fail("Trade signboard must batch four visible corner fasteners.")
			return
		var rail_scales: PackedVector3Array = sign_rails.get_meta("source_scales")
		var hardware_rotations: PackedFloat32Array = sign_hardware.get_meta("source_rotations")
		if rail_scales.size() != 4 or hardware_rotations.size() != 4:
			_fail("Signboard batches must preserve deterministic dimensions and bracket angles.")
			return
		if absf(hardware_rotations[1] + 0.48) > 0.01 or absf(hardware_rotations[3] - 0.48) > 0.01:
			_fail("Signboard diagonal braces must angle outward from the paired hangers.")
			return
		var board_bounds := sign_board.mesh.get_aabb()
		if board_bounds.size.x < 4.5 or board_bounds.size.y < 0.7:
			_fail("Trade signboard backing must be a broad framed timber panel.")
			return
		if trade_label.text != building_types[index] or absf(trade_label.position.y - 4.75) > 0.01:
			_fail("Trade lettering must remain centered on the new physical signboard.")
			return
	print("Frontier exterior regression: six buildings retain batched side framing, shutters and framed trade signboards within a fixed facade draw-batch budget.")
	world_under_test.free()
	world_under_test = null
	quit(0)


func _find_named(node: Node, expected_name: String) -> Node:
	if str(node.name) == expected_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, expected_name)
		if found != null:
			return found
	return null


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _fail(message: String) -> void:
	if is_instance_valid(world_under_test):
		world_under_test.free()
		world_under_test = null
	push_error(message)
	quit(1)
