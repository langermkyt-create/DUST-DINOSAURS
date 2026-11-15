extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	world_under_test = Node3D.new()
	world_under_test.set_script(load("res://scripts/world.gd"))
	var route: Array = world_under_test.call("_preview_route")
	if route.size() < 9:
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
		var camera_origin := position + Vector3.UP * 1.58
		var aim: Vector2 = world_under_test.call("_preview_aim", camera_origin, target)
		var desired_horizontal := Vector3(target.x - camera_origin.x, 0.0, target.z - camera_origin.z).normalized()
		var camera_forward := Vector3.FORWARD.rotated(Vector3.UP, aim.x)
		if camera_forward.dot(desired_horizontal) < 0.995:
			_fail("Preview yaw must point toward each waypoint's authored landmark.")
			return
		if absf(aim.x) > PI + 0.001 or absf(aim.y) > 1.2:
			_fail("Preview aim angles must remain within the camera's valid range.")
			return
		waypoints[waypoint_id] = waypoint
		total_duration += duration

	for required_id in ["town_establishing", "main_street", "town_north_exit", "west_ridge_approach", "herd_close", "tyrannosaur_vista", "town_return"]:
		if not waypoints.has(required_id):
			_fail("Preview route is missing required landmark: " + required_id)
			return

	if not _route_avoids_buildings(route):
		_fail("Preview camera route must not pass through authored building footprints.")
		return
	var predator_bearing := Vector2(70.0, -112.0).angle()
	if not bool(world_under_test.call("_is_predator_sightline", predator_bearing)):
		_fail("Predator vista must reserve an open sector through the distant mesa ring.")
		return
	if bool(world_under_test.call("_is_predator_sightline", predator_bearing + 0.6)):
		_fail("Predator sightline opening must remain a focused corridor, not remove the whole mesa ring.")
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


func _route_avoids_buildings(route: Array) -> bool:
	var footprints: Array[Dictionary] = [
		{"center": Vector2(-12.0, -12.0), "half_size": Vector2(6.0, 5.0)},
		{"center": Vector2(12.0, -8.0), "half_size": Vector2(6.0, 5.0)},
		{"center": Vector2(-13.0, 12.0), "half_size": Vector2(6.0, 5.0)},
		{"center": Vector2(13.0, 16.0), "half_size": Vector2(6.0, 7.0)},
		{"center": Vector2(-30.0, -3.0), "half_size": Vector2(6.0, 5.0)},
		{"center": Vector2(31.0, 7.0), "half_size": Vector2(6.0, 5.0)}
	]
	for segment_index in range(route.size() - 1):
		var start: Vector3 = route[segment_index]["position"]
		var finish: Vector3 = route[segment_index + 1]["position"]
		for sample_index in range(21):
			var sample := start.lerp(finish, float(sample_index) / 20.0)
			for footprint in footprints:
				var center: Vector2 = footprint["center"]
				var half_size: Vector2 = footprint["half_size"]
				if absf(sample.x - center.x) < half_size.x and absf(sample.z - center.y) < half_size.y:
					return false
	return true

func _fail(message: String) -> void:
	if is_instance_valid(world_under_test):
		world_under_test.free()
		world_under_test = null
	push_error(message)
	quit(1)
