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
	print("Frontier exterior regression pass 1: six buildings retain exposed siding, six side posts, four belt rails, two eaves fascias and ten rafter tails per building.")
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
