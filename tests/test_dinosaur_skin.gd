extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	world.call("_make_triceratops", Vector3.ZERO, 1.0, 0.0)
	world.call("_build_tyrannosaur", Vector3(40.0, 0.0, -20.0), 1.0)
	var skin_meshes := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var material := mesh_instance.material_override as ShaderMaterial
		if material == null or material.shader == null:
			continue
		if material.shader.code.contains("skin_world_pos"):
			skin_meshes += 1
			if float(material.get_shader_parameter("detail_scale")) <= 0.0:
				_fail(world, "Dinosaur skin detail scale must remain positive.")
				return
	if skin_meshes < 12:
		_fail(world, "Both dinosaur species must use the shared procedural skin material on their hide meshes.")
		return
	print("Dinosaur skin regression passed: ", skin_meshes,
		" hide meshes use world-space mottling, scale breakup, and roughness variation.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
