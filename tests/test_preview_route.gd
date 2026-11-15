extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	world_under_test = Node3D.new()
	world_under_test.set_script(load("res://scripts/world.gd"))
	var route: Array = world_under_test.call("_preview_route")
	if route.size() < 6:
		_fail("Preview route must cover the town, herd, and distant predator.")
		return

	var waypoints: Dictionary = {}
	var total_duration := 0.0
	for entry in route:
		if not entry is Dictionary:
			_fail("Every preview route entry must be a dictionary.")
			return
		var waypoint: Dictionary = entry
		var waypoint_id := str(waypoint.get("id", ""))
		if waypoint_id.is_empty() or waypoints.has(waypoint_id):
			_fail("Preview waypoint IDs must be present and unique.")
			return
		if not waypoint.get("position") is Vector3 or not waypoint.get("target") is Vector3:
			_fail("Each preview waypoint must define a world position and an aim target.")
			return
		var duration: float = waypoint.get("duration", 0.0)
		if duration <= 0.0:
			_fail("Preview waypoint durations must be positive.")
			return
		var position: Vector3 = waypoint["position"]
		var target: Vector3 = waypoint["target"]
		var aim: Vector2 = world_under_test.call(
			"_preview_aim", position + Vector3.UP * 1.58, target
		)
		if absf(aim.x) > PI + 0.001 or absf(aim.y) > 1.2:
			_fail("Preview aim angles must remain within the camera's valid range.")
			return
		waypoints[waypoint_id] = waypoint
		total_duration += duration

	for required_id in ["town_establishing", "main_street", "herd_close", "tyrannosaur_vista", "town_return"]:
		if not waypoints.has(required_id):
			_fail("Preview route is missing required landmark: " + required_id)
			return

	var herd_target: Vector3 = waypoints["herd_close"]["target"]
	if herd_target.distance_to(Vector3(-31.0, 2.2, -58.0)) > 0.1:
		_fail("Herd close-up must aim at the authored triceratops family location.")
		return
	var predator_target: Vector3 = waypoints["tyrannosaur_vista"]["target"]
	if predator_target.distance_to(Vector3(70.0, 5.2, -112.0)) > 0.1:
		_fail("Distant predator vista must aim at the authored tyrannosaur location.")
		return
	if total_duration < 35.0 or total_duration > 40.0:
		_fail("Preview route duration must fit inside the 42-second CI capture.")
		return

	print("Preview route regression passed: ", route.size(),
		" unique stops, town + triceratops + tyrannosaur, ",
		total_duration, " seconds of camera travel.")
	world_under_test.free()
	world_under_test = null
	quit(0)

func _fail(message: String) -> void:
	if is_instance_valid(world_under_test):
		world_under_test.free()
		world_under_test = null
	push_error(message)
	quit(1)
