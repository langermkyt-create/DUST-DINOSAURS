extends SceneTree

var world_under_test: Node3D

func _initialize() -> void:
	var world_script: Script = load("res://scripts/world.gd")
	world_under_test = Node3D.new()
	world_under_test.set_script(world_script)
	world_under_test.call("_rock_formation", Vector3.ZERO, 1.0)
	world_under_test.call("_rock_formation", Vector3(24.0, 0.0, 0.0), 0.9)
	world_under_test.call("_rock_formation", Vector3(-24.0, 0.0, 0.0), 1.5)

	if world_under_test.get_child_count() != 3:
		_fail("Rock builder must create three differently scaled static bodies for shared-material and LOD verification.")
		return
	var rock_body := world_under_test.get_child(0) as StaticBody3D
	var second_rock_body := world_under_test.get_child(1) as StaticBody3D
	var third_rock_body := world_under_test.get_child(2) as StaticBody3D
	var second_high := second_rock_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var second_low := second_rock_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var third_high := third_rock_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var third_low := third_rock_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var high := rock_body.get_node_or_null("RockHighDetail") as MeshInstance3D
	var low := rock_body.get_node_or_null("RockDistantLOD") as MeshInstance3D
	var collision := rock_body.get_node_or_null("RockCollision") as CollisionShape3D
	if high == null or low == null or collision == null:
		_fail("Rock must contain high-detail, distant LOD, and collision nodes.")
		return
	if high.mesh == null or low.mesh == null:
		_fail("Rock LOD meshes must both be assigned.")
		return
	var high_arrays := high.mesh.surface_get_arrays(0)
	var low_arrays := low.mesh.surface_get_arrays(0)
	var high_vertices: PackedVector3Array = high_arrays[Mesh.ARRAY_VERTEX]
	var low_vertices: PackedVector3Array = low_arrays[Mesh.ARRAY_VERTEX]
	if high_vertices.size() % 3 != 0 or low_vertices.size() % 3 != 0:
		_fail("Rock meshes must contain complete triangles.")
		return
	if high_vertices.size() != 1008 or low_vertices.size() != 192:
		_fail("Near and distant sandstone LODs must retain the expanded 24-sided/7-ring and 8-sided/4-level vertex budgets.")
		return
	if low_vertices.is_empty() or low_vertices.size() >= high_vertices.size():
		_fail("Distant rock LOD must be non-empty and cheaper than the near mesh.")
		return
	if high.visibility_range_end <= low.visibility_range_begin:
		_fail("Near and distant rock visibility ranges must overlap.")
		return
	if second_high == null or second_low == null or third_high == null or third_low == null:
		_fail("Every rock size must retain both near and distant LOD nodes.")
		return
	if absf(second_high.visibility_range_end - 118.8) > 0.01 or absf(second_low.visibility_range_begin - 106.2) > 0.01:
		_fail("A 0.9-scale outcrop must scale both LOD handoff distances proportionally.")
		return
	if absf(third_high.visibility_range_end - 198.0) > 0.01 or absf(third_low.visibility_range_begin - 177.0) > 0.01:
		_fail("A 1.5-scale outcrop must scale both LOD handoff distances proportionally.")
		return
	if collision.shape == null or not (collision.shape is ConcavePolygonShape3D):
		_fail("Rock collision must use a static concave triangle mesh.")
		return
	var collision_faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
	if collision_faces.size() != low_vertices.size() or collision_faces.size() >= high_vertices.size() * 0.60:
		_fail("Static rock collision must reuse the distant silhouette and stay below 60% of near-mesh triangle vertices.")
		return
	if high.mesh.get_aabb().size.length_squared() <= 0.0 or low.mesh.get_aabb().size.length_squared() <= 0.0:
		_fail("Rock LOD meshes must have non-zero bounds.")
		return
	var high_normals: PackedVector3Array = high_arrays[Mesh.ARRAY_NORMAL]
	var high_colors: PackedColorArray = high_arrays[Mesh.ARRAY_COLOR]
	if high_normals.size() != high_vertices.size() or high_colors.size() != high_vertices.size():
		_fail("Near sandstone mesh must retain generated normals and layered vertex strata.")
		return
	var high_material := high.material_override as ShaderMaterial
	var low_material := low.material_override as ShaderMaterial
	if high_material == null or low_material == null or high_material.shader == null or low_material.shader == null:
		_fail("Both sandstone LODs must share the procedural sediment and erosion material.")
		return
	if high_material != low_material:
		_fail("Near and distant sandstone LODs must reference one shared ShaderMaterial resource.")
		return
	if second_high.material_override != high_material or third_high.material_override != high_material:
		_fail("All outcrops in one world must reuse the cached sandstone ShaderMaterial.")
		return
	if high_material.shader.code != low_material.shader.code:
		_fail("Near and distant sandstone LODs must use the same surface response.")
		return
	for token in ["fine_grain", "micro_relief", "sediment", "fracture", "NORMAL", "ROUGHNESS"]:
		if not high_material.shader.code.contains(token):
			_fail("Sandstone material is missing its multi-scale erosion detail: " + token)
			return
	if not high_material.shader.code.contains("micro_relief = grain"):
		_fail("Sandstone bump height must reuse the lower-frequency grain field to avoid sub-pixel normal aliasing.")
		return
	if high_material.shader.code.contains("micro_relief = fine_grain"):
		_fail("Sandstone bump mapping must not use the highest-frequency albedo noise as a normal height.")
		return
	for token in ["dFdx(rock_world_pos)", "cross(dpdy, geometric_normal)", "safe_determinant", "height_gradient * 0.0035", "VIEW_MATRIX * vec4(bump_world_normal"]:
		if not high_material.shader.code.contains(token):
			_fail("Sandstone bump mapping must derive a stable world-space surface normal: " + token)
			return
	if high_material.shader.code.contains("NORMAL + vec3(-relief_gradient"):
		_fail("Rock micro-relief must not perturb arbitrary view-space normal axes.")
		return
	if high_material.shader.code.contains("fracture_noise"):
		_fail("Sandstone fracture mask must reuse existing material fields to stay inside the fragment-noise budget.")
		return

	print("Rock LOD regression passed: near=", high_vertices.size() / 3,
		" triangles, far/collision=", low_vertices.size() / 3,
		" triangles, derivative bump mapping, shared material, and scale-aware handoff ranges.")
	world_under_test.free()
	world_under_test = null
	quit(0)

func _fail(message: String) -> void:
	if is_instance_valid(world_under_test):
		world_under_test.free()
		world_under_test = null
	push_error(message)
	quit(1)
