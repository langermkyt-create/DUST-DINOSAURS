extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	for variant in range(3):
		var mesh: ArrayMesh = world.call("_make_saguaro_mesh", variant)
		if mesh == null or mesh.get_surface_count() != 1:
			_fail(world, "Each saguaro variant must use one combined tube surface.")
			return
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if vertices.size() < 700 or vertices.size() > 2200 or vertices.size() % 3 != 0:
			_fail(world, "Saguaro geometry must retain a bounded, closed tube mesh.")
			return
		if normals.size() != vertices.size() or uvs.size() != vertices.size():
			_fail(world, "Saguaro tube vertices must carry generated normals and continuous UV coordinates.")
			return
		for index in range(vertices.size()):
			if not is_finite(uvs[index].x) or not is_finite(uvs[index].y):
				_fail(world, "Saguaro UV coordinates must be finite.")
				return
			if uvs[index].x < -0.001 or uvs[index].x > 1.001 or uvs[index].y < -0.001 or uvs[index].y > 1.001:
				_fail(world, "Saguaro tube UV coordinates must stay within the wrapped 0–1 surface domain.")
				return
			if not is_finite(normals[index].x) or not is_finite(normals[index].y) or not is_finite(normals[index].z):
				_fail(world, "Saguaro generated normals must remain finite.")
				return
		var material := mesh.surface_get_material(0) as ShaderMaterial
		if material == null or material.shader == null:
			_fail(world, "Saguaro surfaces must use the procedural rib and spine shader.")
			return
		var shader_code := material.shader.code
		for token in ["cactus_uv", "rib_phase", "areole", "spine_fleck", "ROUGHNESS"]:
			if not shader_code.contains(token):
				_fail(world, "Saguaro shader is missing its authored surface detail: " + token)
				return
		if mesh.get_aabb().size.y < 2.0:
			_fail(world, "Saguaro trunk must preserve its tall columnar silhouette.")
			return
	print("Saguaro detail regression passed: three bounded, UV-mapped variants with procedural ribs, areoles and spine flecks.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
