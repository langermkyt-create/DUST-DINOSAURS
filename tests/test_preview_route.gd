extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	world_under_test = Node3D.new()
	world_under_test.set_script(load("res://scripts/world.gd"))
	var route: Array = world_under_test.call("_preview_route")
	if route.size() < 10:
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

	for required_id in ["town_establishing", "main_street", "town_north_exit", "west_ridge_approach", "herd_close", "herd_clearance", "south_detour", "tyrannosaur_vista", "town_return"]:
		if not waypoints.has(required_id):
			_fail("Preview route is missing required landmark: " + required_id)
			return

	if not _route_avoids_buildings(route):
		_fail("Preview camera route must not pass through authored building footprints.")
		return
	if not _route_exits_herd_safely(route):
		_fail("The head close-up must leave the nearest animal monotonically and keep clear of the other herd members.")
		return
	if not _route_avoids_herd_after_close(route):
		_fail("Preview camera route must detour around the herd after its intentional close-up.")
		return
	if waypoints["herd_clearance"]["position"].distance_to(Vector3(-52.0, waypoints["herd_clearance"]["position"].y, -45.0)) > 0.1:
		_fail("Herd clearance waypoint must move west of the animals before the southbound leg.")
		return
	var predator_bearing := Vector2(70.0, -112.0).angle()
	if not bool(world_under_test.call("_is_predator_sightline", predator_bearing)):
		_fail("Predator vista must reserve an open sector through the distant mesa ring.")
		return
	if bool(world_under_test.call("_is_predator_sightline", predator_bearing + 0.6)):
		_fail("Predator sightline opening must remain a focused corridor, not remove the whole mesa ring.")
		return

	var herd_target: Vector3 = waypoints["herd_close"]["target"]
	var expected_head_height: float = float(world_under_test.call("_terrain_height", Vector2(-31.0, -52.0))) + 1.95
	if herd_target.distance_to(Vector3(-31.0, expected_head_height, -54.2)) > 0.1:
		_fail("Herd close-up must aim at the lead triceratops head, not the center of the family group.")
		return
	var herd_position: Vector3 = waypoints["herd_close"]["position"]
	var herd_distance := Vector2(herd_position.x + 31.0, herd_position.z + 52.0).length()
	if herd_distance < 5.5 or herd_distance > 7.5:
		_fail("Triceratops head close-up must hold a safe 5.5–7.5 m framing distance.")
		return
	var predator_position: Vector3 = waypoints["tyrannosaur_vista"]["position"]
	var predator_distance := Vector2(predator_position.x - 70.0, predator_position.z + 112.0).length()
	if predator_distance < 20.0 or predator_distance > 27.0:
		_fail("Tyrannosaur vista camera must frame the authored animal from 20–27 m.")
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


func _route_exits_herd_safely(route: Array) -> bool:
	var close_index := -1
	var clearance_index := -1
	for index in range(route.size()):
		var waypoint_id := str(route[index]["id"])
		if waypoint_id == "herd_close":
			close_index = index
		elif waypoint_id == "herd_clearance":
			clearance_index = index
	if close_index < 0 or clearance_index != close_index + 1:
		return false
	var herd_centers: Array[Vector2] = [
		Vector2(-31.0, -52.0),
		Vector2(-39.0, -59.0),
		Vector2(-23.0, -62.0)
	]
	var start: Vector3 = route[close_index]["position"]
	var finish: Vector3 = route[clearance_index]["position"]
	var previous_distance := Vector2(start.x + 31.0, start.z + 52.0).length()
	for sample_index in range(1, 21):
		var sample := start.lerp(finish, float(sample_index) / 20.0)
		var sample_xz := Vector2(sample.x, sample.z)
		var lead_distance := sample_xz.distance_to(herd_centers[0])
		if lead_distance + 0.01 < previous_distance:
			return false
		previous_distance = lead_distance
		for herd_index in range(1, herd_centers.size()):
			if sample_xz.distance_to(herd_centers[herd_index]) < 8.0:
				return false
	return true


func _route_avoids_herd_after_close(route: Array) -> bool:
	var clearance_index := -1
	var predator_index := -1
	for index in range(route.size()):
		var waypoint_id := str(route[index]["id"])
		if waypoint_id == "herd_clearance":
			clearance_index = index
		elif waypoint_id == "tyrannosaur_vista":
			predator_index = index
	if clearance_index < 0 or predator_index <= clearance_index:
		return false
	var herd_centers: Array[Vector2] = [
		Vector2(-31.0, -52.0),
		Vector2(-39.0, -59.0),
		Vector2(-23.0, -62.0)
	]
	for segment_index in range(clearance_index, predator_index):
		var start: Vector3 = route[segment_index]["position"]
		var finish: Vector3 = route[segment_index + 1]["position"]
		for sample_index in range(21):
			var sample := start.lerp(finish, float(sample_index) / 20.0)
			var sample_xz := Vector2(sample.x, sample.z)
			for herd_center in herd_centers:
				if sample_xz.distance_to(herd_center) < 8.0:
					return false
	return true


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
