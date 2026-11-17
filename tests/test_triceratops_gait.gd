extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var front_left: float = world.call("_triceratops_gait_direction", -0.78, -0.86)
	var rear_right: float = world.call("_triceratops_gait_direction", 0.78, 0.98)
	var front_right: float = world.call("_triceratops_gait_direction", 0.78, -0.86)
	var rear_left: float = world.call("_triceratops_gait_direction", -0.78, 0.98)
	if front_left != rear_right or front_right != rear_left:
		_fail(world, "Triceratops gait must synchronize matching diagonal limb pairs.")
		return
	if front_left == front_right:
		_fail(world, "Opposing diagonal pairs must move out of phase.")
		return
	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	var pivots := 0
	for node in world.find_children("*", "Node3D", true, false):
		if node.name.begins_with("TriceratopsLegPivot_"):
			pivots += 1
	if pivots != 4:
		_fail(world, "The animated gait rig must retain four independent leg pivots.")
		return
	print("Triceratops gait regression passed: paired diagonal timing and four independent leg pivots.")
	world.free()
	quit(0)


func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
