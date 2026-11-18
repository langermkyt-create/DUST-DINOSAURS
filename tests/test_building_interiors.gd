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
		var lantern := _find_named(building, "InteriorLanternLight") as OmniLight3D
		if lantern == null:
			_fail("Every interior must have its warm lantern light: " + sign_text)
			return
		if lantern.light_energy < 1.0 or lantern.omni_range < 10.0:
			_fail("Interior lantern must illuminate the timber trim and furniture: " + sign_text)
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
	if _count_named_prefix(world_under_test.get_child(0), "SaloonShelfBottle") < 5:
		_fail("Saloon back-bar shelf must carry five original bottle props.")
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
