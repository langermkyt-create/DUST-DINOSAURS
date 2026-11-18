extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var material: ShaderMaterial = world.call("_terrain_material")
	if material == null or material.shader == null:
		_fail(world, "Terrain material builder must return a shader material.")
		return
	var code: String = material.shader.code
	for token in [
		"MODEL_NORMAL_MATRIX",
		"world_normal",
		"exposed_sandstone",
		"wash_mask",
		"clay_streaks",
		"fine_grain",
		"dFdx",
		"micro_normal_strength",
		"ROUGHNESS",
		"AO"
	]:
		if not code.contains(token):
			_fail(world, "Layered terrain shader is missing its required response channel: " + token)
			return
	var dust: Color = material.get_shader_parameter("dust_tint")
	var ochre: Color = material.get_shader_parameter("ochre_tint")
	var pale: Color = material.get_shader_parameter("pale_tint")
	if dust.r < 0.35 or ochre.r <= dust.r or pale.r <= ochre.r:
		_fail(world, "Arizona soil palette must progress from dark dust through ochre to sun-bleached sand.")
		return
	if float(material.get_shader_parameter("micro_normal_strength")) <= 0.0:
		_fail(world, "Fine sediment must contribute a restrained micro-normal response.")
		return
	print("Terrain material regression passed: slope-aware sandstone, arroyo sediment, layered dust/ochre palette, micro-normal, roughness and AO.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
