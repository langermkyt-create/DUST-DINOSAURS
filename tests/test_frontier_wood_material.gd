extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	var wall_tint := Color(0.43, 0.18, 0.12)
	var wall_material: ShaderMaterial = world.call("_weathered_wood_material", wall_tint, false)
	var roof_material: ShaderMaterial = world.call("_weathered_wood_material", Color(0.24, 0.14, 0.11), true)
	if wall_material == null or roof_material == null:
		_fail(world, "Frontier wood material builder must return shader materials for walls and roof boards.")
		return
	if wall_material.shader == null or roof_material.shader == null:
		_fail(world, "Frontier wood materials must retain their procedural shader.")
		return
	if wall_material.shader.code != roof_material.shader.code:
		_fail(world, "Wall boards and roof shingles must share one consistent weathered timber response.")
		return
	var code: String = wall_material.shader.code
	for token in ["fine_fiber", "grain_lines", "wood_checks", "knots", "bleach", "ROUGHNESS", "AO"]:
		if not code.contains(token):
			_fail(world, "Weathered wood shader is missing its authored surface feature: " + token)
			return
	var wall_scale := float(wall_material.get_shader_parameter("grain_scale"))
	var roof_scale := float(roof_material.get_shader_parameter("grain_scale"))
	if absf(wall_scale - 5.0) > 0.001 or absf(roof_scale - 1.8) > 0.001:
		_fail(world, "Long wall boards and broad roof shingles must retain distinct, scale-appropriate grain spacing.")
		return
	var tint: Color = wall_material.get_shader_parameter("tint")
	if absf(tint.r - wall_tint.r) > 0.001 or absf(tint.g - wall_tint.g) > 0.001 or absf(tint.b - wall_tint.b) > 0.001:
		_fail(world, "Weathered wood shader must preserve each building's authored timber palette.")
		return
	print("Frontier wood material regression passed: shared directional grain, fine checks, knots, sun bleaching, roughness and AO with separate wall/roof grain scales.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
