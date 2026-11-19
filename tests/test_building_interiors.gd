extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	world_under_test = Node3D.new()
	world_under_test.set_script(load("res://scripts/world.gd"))
	var building_types: Array[String] = [
		"SALOON", "GENERAL STORE", "SHERIFF", "STABLES", "HOTEL", "RAIL OFFICE"
	]
	for index in range(building_types.size()):
		var sign_text := building_types[index]
		world_under_test.call("_build_building",
			Vector3(float(index) * 30.0, 0.0, 0.0),
			sign_text, Color(0.43, 0.25, 0.16), index % 2 == 0)
		var building := world_under_test.get_child(index)
		if _find_named(building, "InteriorFloor") == null:
			_fail("Every frontier building must have a walkable plank floor: " + sign_text)
			return
		if _count_named_prefix(building, "InteriorCeilingJoist") != 3:
			_fail("Every interior must have three exposed ceiling joists: " + sign_text)
			return
		if _count_named_prefix(building, "InteriorWallStud") != 4:
			_fail("Every interior must have four structural corner studs: " + sign_text)
			return
		if _count_named_prefix(building, "InteriorWainscot") != 5:
			_fail("Every interior must have continuous lower wall trim without blocking the doorway: " + sign_text)
			return
		var wall_boards := _find_named(building, "InteriorWallBoards") as MultiMeshInstance3D
		if wall_boards == null or wall_boards.multimesh == null or wall_boards.multimesh.instance_count != 21:
			_fail("Every room must batch seven rear and fourteen side-wall timber courses: " + sign_text)
			return
		if wall_boards.multimesh.mesh == null or not wall_boards.multimesh.mesh is BoxMesh:
			_fail("Interior wall boards must share one reusable box mesh instead of separate draw-call geometry: " + sign_text)
			return
		var board_positions: PackedVector3Array = wall_boards.get_meta("placement_positions")
		var board_scales: PackedVector3Array = wall_boards.get_meta("placement_scales")
		if board_positions.size() != 21 or board_scales.size() != 21:
			_fail("Every interior wall-board instance must retain its deterministic placement record: " + sign_text)
			return
		for row in range(7):
			var rear_index := row * 3
			var rear_position := board_positions[rear_index]
			var rear_scale := board_scales[rear_index]
			if absf(rear_position.z + 3.27) > 0.01 or absf(rear_scale.x - 9.2) > 0.02 or absf(rear_scale.y - 0.4) > 0.02:
				_fail("Rear timber courses must sit flush to the back wall with consistent board dimensions: " + sign_text)
				return
			for side_index in [1, 2]:
				var side_index_in_batch: int = rear_index + int(side_index)
				var side_position := board_positions[side_index_in_batch]
				var side_scale := board_scales[side_index_in_batch]
				if absf(absf(side_position.x) - 4.765) > 0.01 or absf(side_scale.z - 6.2) > 0.02 or absf(side_scale.y - 0.4) > 0.02:
					_fail("Side timber courses must remain aligned to both interior elevations: " + sign_text)
					return
		var board_material := wall_boards.material_override as ShaderMaterial
		if board_material == null or not board_material.shader.code.contains("wood_checks"):
			_fail("Interior timber courses must use the shared weathered wood response: " + sign_text)
			return
		var lantern := _find_named(building, "InteriorLanternLight") as OmniLight3D
		if lantern == null:
			_fail("Every interior must have its warm lantern light: " + sign_text)
			return
		if lantern.light_energy < 1.0 or lantern.omni_range < 10.0:
			_fail("Interior lantern must illuminate the timber trim and furniture: " + sign_text)
			return
		var globe := _find_named(building, "InteriorLanternGlobe") as MeshInstance3D
		var stem := _find_named(building, "InteriorLanternStem")
		if globe == null or stem == null:
			_fail("Interior lantern must have a glass globe and ceiling stem: " + sign_text)
			return
		var globe_material := globe.material_override as StandardMaterial3D
		if globe_material == null or not globe_material.emission_enabled:
			_fail("Interior lantern globe must use a visible warm emissive glass material: " + sign_text)
			return
		if _count_named_prefix(building, "InteriorLanternGuard") != 4:
			_fail("Interior lantern must have four protective iron cage bars: " + sign_text)
			return
		var door_pivot := _find_named(building, "FrontDoorPivot") as Node3D
		if door_pivot == null or absf(door_pivot.rotation.y - PI / 2.0) > 0.01:
			_fail("Every frontier entrance must park its open door leaf inward against the left jamb: " + sign_text)
			return
		if _count_named_prefix(door_pivot, "FrontDoorPlank") != 5:
			_fail("Front door must use five individually weathered vertical boards: " + sign_text)
			return
		if _count_named_prefix(door_pivot, "FrontDoorCrossRail") != 2:
			_fail("Front door must retain two structural cross rails: " + sign_text)
			return
		if _find_named(door_pivot, "FrontDoorDiagonalBrace") == null or _find_named(door_pivot, "FrontDoorLatch") == null:
			_fail("Front door must retain a diagonal brace and iron latch: " + sign_text)
			return
	if _find_named(world_under_test.get_child(0), "SaloonBar") == null:
		_fail("Saloon interior must retain its service bar.")
		return
	if _find_named(world_under_test.get_child(0), "SaloonMirror") == null:
		_fail("Saloon interior must have a framed mirror behind the bar.")
		return
	if _find_named(world_under_test.get_child(0), "SaloonBackShelf") == null:
		_fail("Saloon interior must have a back-bar shelf.")
		return
	var saloon := world_under_test.get_child(0)
	var bar_fill := _find_named(saloon, "SaloonBackBarFillLight") as OmniLight3D
	if bar_fill == null or bar_fill.light_energy < 0.7 or bar_fill.omni_range < 7.0:
		_fail("Saloon back-bar fill light must illuminate the bottle shelf and counter.")
		return
	if bar_fill.shadow_enabled:
		_fail("The local saloon fill light must remain shadowless to avoid unnecessary per-frame shadow cost.")
		return
	if _count_named_prefix(saloon, "SaloonBottleMesh") != 5:
		_fail("Saloon back-bar shelf must carry five shaped glass bottles.")
		return
	if _count_named_prefix(saloon, "SaloonBottleCork") != 5:
		_fail("Each saloon bottle must have a separate cork stopper.")
		return
	if _count_named_prefix(saloon, "SaloonBottleLabel") != 5:
		_fail("Each saloon bottle must have a paper label facing the room.")
		return
	var foot_rail := _find_named(saloon, "SaloonFootRail") as MeshInstance3D
	if foot_rail == null or not foot_rail.mesh is CylinderMesh:
		_fail("Saloon service bar must have a continuous brass foot rail.")
		return
	var rail_mesh := foot_rail.mesh as CylinderMesh
	if absf(rail_mesh.height - 4.8) > 0.01 or absf(foot_rail.rotation.z - PI / 2.0) > 0.01:
		_fail("Saloon foot rail must span the customer side of the bar horizontally.")
		return
	if _count_named_prefix(saloon, "SaloonFootRailBracket") != 3:
		_fail("Saloon foot rail must have three evenly spaced support brackets.")
		return
	var bar_inlay := _find_named(saloon, "SaloonBarBrassInlay") as MeshInstance3D
	if bar_inlay == null:
		_fail("Saloon bar must retain its narrow brass counter-edge inlay.")
		return
	for child in saloon.get_children():
		if str(child.name) != "SaloonBottleMesh":
			continue
		var bottle := child as MeshInstance3D
		if bottle == null or bottle.mesh == null or bottle.mesh.get_surface_count() != 1:
			_fail("Saloon bottle must use one continuous custom mesh surface.")
			return
		var bottle_bounds := bottle.mesh.get_aabb()
		if bottle_bounds.size.y < 0.25 or bottle_bounds.size.y > 0.28:
			_fail("Saloon bottle silhouette must retain its authored shoulder and neck height.")
			return
		if bottle_bounds.size.x < 0.10 or bottle_bounds.size.x > 0.12:
			_fail("Saloon bottle body must retain a consistent glass diameter.")
			return
	print("Building interior regression passed: six walkable room archetypes, 18 exposed joists, 24 corner studs, 30 wall trims, six lantern lights, and a furnished saloon back bar.")
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
