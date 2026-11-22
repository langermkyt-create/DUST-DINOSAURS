extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	world_under_test = Node3D.new()
	world_under_test.set_script(load("res://scripts/world.gd"))
	world_under_test.call("_build_building", Vector3.ZERO, "STABLES", Color(0.48, 0.31, 0.18), true)
	world_under_test.call("_build_building", Vector3(30.0, 0.0, 0.0), "SHERIFF", Color(0.36, 0.27, 0.19), false)
	world_under_test.call("_build_building", Vector3(60.0, 0.0, 0.0), "GENERAL STORE", Color(0.55, 0.38, 0.22), false)
	var stables := world_under_test.get_child(0)
	var sheriff := world_under_test.get_child(1)
	var general_store := world_under_test.get_child(2)

	var stable_track := _find_named(stables, "StableSlidingDoorTrack") as MeshInstance3D
	var stable_vent := _find_named(stables, "StableLoftVentSlats") as MultiMeshInstance3D
	if stable_track == null or stable_track.mesh == null or stable_vent == null:
		_fail("Stables must have a track-mounted double entrance and ventilated hayloft.")
		return
	if _count_named_prefix(stables, "StableSlidingDoorPanel") != 2:
		_fail("Stable entrance must have two individually modeled sliding door leaves.")
		return
	if _count_named_prefix(stables, "StableSlidingDoorBrace") != 2 or _count_named_prefix(stables, "StableDoorRoller") != 2:
		_fail("Both stable door leaves must retain their diagonal bracing and iron rollers.")
		return
	if stable_vent.multimesh == null or stable_vent.multimesh.instance_count != 7:
		_fail("Hayloft vent must batch five vertical slats and two horizontal rails.")
		return
	if stable_vent.get_meta("source_positions").size() != 7:
		_fail("Hayloft vent batch must preserve its deterministic placement record.")
		return

	var jail_bars := _find_named(sheriff, "SheriffJailBars") as MultiMeshInstance3D
	var badge := _find_named(sheriff, "SheriffStarBadge") as MeshInstance3D
	var badge_stud := _find_named(sheriff, "SheriffBadgeCenterStud") as MeshInstance3D
	if jail_bars == null or jail_bars.multimesh == null or badge == null or badge.mesh == null or badge_stud == null:
		_fail("Sheriff office must have barred windows and a raised brass star badge.")
		return
	if jail_bars.multimesh.instance_count != 8 or jail_bars.get_meta("source_positions").size() != 8:
		_fail("Sheriff grille must contain six vertical bars and two horizontal crossbars.")
		return
	var star_arrays := badge.mesh.surface_get_arrays(0)
	var star_vertices: PackedVector3Array = star_arrays[Mesh.ARRAY_VERTEX]
	var badge_material := badge.material_override as StandardMaterial3D
	if star_vertices.size() != 30 or badge.mesh.get_aabb().size.x < 0.8 or badge.mesh.get_aabb().size.y < 0.8:
		_fail("Sheriff badge must be a complete ten-point star silhouette, not a flat circle.")
		return
	if badge_material == null or badge_material.metallic < 0.6 or badge_material.roughness > 0.5:
		_fail("Sheriff badge must read as worn brass with a restrained metallic response.")
		return
	if badge_material.cull_mode != BaseMaterial3D.CULL_DISABLED or not badge_material.emission_enabled or badge.position.z < 4.38:
		_fail("Sheriff star must remain legible from the street beneath the deep front gable.")
		return

	var awning := _find_named(general_store, "GeneralStoreAwningCanvas") as MeshInstance3D
	var awning_rail := _find_named(general_store, "GeneralStoreAwningFrontRail") as MeshInstance3D
	if awning == null or awning.mesh == null or awning_rail == null:
		_fail("General store must have a supported striped canvas awning.")
		return
	var awning_arrays := awning.mesh.surface_get_arrays(0)
	var awning_vertices: PackedVector3Array = awning_arrays[Mesh.ARRAY_VERTEX]
	var awning_colors: PackedColorArray = awning_arrays[Mesh.ARRAY_COLOR]
	var fabric := awning.material_override as StandardMaterial3D
	var awning_bounds := awning.mesh.get_aabb()
	if awning_vertices.size() < 192 or awning_colors.size() != awning_vertices.size():
		_fail("Awning must retain eight two-sided striped canvas panels and their vertex colors.")
		return
	if awning_bounds.size.x < 9.8 or awning_bounds.size.z < 1.0 or awning_bounds.size.y < 0.3:
		_fail("Awning must span the storefront and slope outward over the windows.")
		return
	if fabric == null or not fabric.vertex_color_use_as_albedo or fabric.roughness < 0.9 or fabric.cull_mode != BaseMaterial3D.CULL_DISABLED:
		_fail("Canvas material must preserve stripe colors, remain matte, and render from both sides.")
		return
	if _count_named_prefix(general_store, "GeneralStoreAwningSupport") != 2:
		_fail("Awning must retain two sloped timber support arms.")
		return
	if _find_named(stables, "GeneralStoreAwningCanvas") != null or _find_named(sheriff, "GeneralStoreAwningCanvas") != null:
		_fail("Archetype details must not leak onto unrelated storefronts.")
		return

	print("Building archetype regression passed: stable doors/loft vent, sheriff grilles/badge, and general-store striped awning.")
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
