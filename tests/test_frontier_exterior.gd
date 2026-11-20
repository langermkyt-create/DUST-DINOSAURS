extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	world_under_test = Node3D.new()
	world_under_test.set_script(load("res://scripts/world.gd"))
	var building_types: Array[String] = [
		"SALOON", "GENERAL STORE", "SHERIFF", "STABLES", "HOTEL", "RAIL OFFICE"
	]
	for index in range(building_types.size()):
		world_under_test.call("_build_building",
			Vector3(float(index) * 30.0, 0.0, 0.0),
			building_types[index], Color(0.43, 0.25, 0.16), index % 2 == 0)
		var building := world_under_test.get_child(index)
		if _count_named_prefix(building, "SideElevationPost") != 6:
			_fail("Each building must expose three structural side posts on both long elevations.")
			return
		if _count_named_prefix(building, "SideElevationBeltRail") != 4:
			_fail("Each side elevation must have lower and upper continuous timber belt rails.")
			return
		if _count_named_prefix(building, "SideEavesFascia") != 2:
			_fail("Both roof eaves must have a continuous side fascia.")
			return
		if _count_named_prefix(building, "SideRafterTail") != 10:
			_fail("Each building must expose five rafter tails on each side eave.")
			return
		var first_post := _find_named(building, "SideElevationPost") as MeshInstance3D
		if first_post == null or first_post.mesh == null:
			_fail("Side structural posts must be visible mesh geometry.")
			return
		var post_bounds := first_post.mesh.get_aabb()
		if post_bounds.size.y < 3.9 or post_bounds.size.x > 0.2:
			_fail("Side posts must read as narrow full-height timber members, not wall-covering slabs.")
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
		if _count_named_prefix(building, "BuildingSignboardTopRail") != 1:
			_fail("Trade signboard must have a continuous top timber rail.")
			return
		if _count_named_prefix(building, "BuildingSignboardBottomRail") != 1:
			_fail("Trade signboard must have a continuous lower timber rail.")
			return
		if _count_named_prefix(building, "BuildingSignboardSideRail") != 2:
			_fail("Trade signboard must have two framed vertical ends.")
			return
		if _count_named_prefix(building, "BuildingSignboardHanger") != 2 or _count_named_prefix(building, "BuildingSignboardBrace") != 2:
			_fail("Trade signboard must be supported by paired iron hangers and braces.")
			return
		if _count_named_prefix(building, "BuildingSignboardBolt") != 4:
			_fail("Trade signboard must retain four visible corner fasteners.")
			return
		var board_bounds := sign_board.mesh.get_aabb()
		if board_bounds.size.x < 4.5 or board_bounds.size.y < 0.7:
			_fail("Trade signboard backing must be a broad framed timber panel.")
			return
		if trade_label.text != building_types[index] or absf(trade_label.position.y - 4.75) > 0.01:
			_fail("Trade lettering must remain centered on the new physical signboard.")
			return
	print("Frontier exterior regression: six buildings retain exposed side framing, batched shutter sets and framed, supported trade signboards.")
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
