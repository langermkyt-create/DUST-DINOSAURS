extends SceneTree

func _initialize() -> void:
	var world := Node3D.new()
	world.set_script(load("res://scripts/world.gd"))
	world.call("_build_atmosphere")
	if world.get_child_count() != 2:
		_fail(world, "Atmosphere builder must create one environment and one directional sun.")
		return
	var world_environment := world.get_child(0) as WorldEnvironment
	var sun := world.get_child(1) as DirectionalLight3D
	if world_environment == null or world_environment.environment == null:
		_fail(world, "Arizona atmosphere must provide a configured WorldEnvironment.")
		return
	var environment := world_environment.environment
	if not environment.fog_enabled:
		_fail(world, "Distant Arizona mesas need restrained aerial perspective.")
		return
	if environment.fog_density < 0.0010 or environment.fog_density > 0.0012:
		_fail(world, "Aerial haze density must remain subtle and bounded.")
		return
	if environment.fog_light_color.r <= environment.fog_light_color.b:
		_fail(world, "Aerial haze must retain a warm desert-sand tint.")
		return
	if environment.volumetric_fog_enabled:
		_fail(world, "The compatibility-safe atmosphere must not force volumetric fog.")
		return
	if sun == null or not sun.shadow_enabled or sun.directional_shadow_max_distance < 200.0:
		_fail(world, "The sunset sun must retain long-range directional shadows.")
		return
	print("Atmosphere regression passed: warm distance haze, compatibility-safe non-volumetric fog, and long-range sunset shadows.")
	world.free()
	quit(0)

func _fail(world: Node3D, message: String) -> void:
	if is_instance_valid(world):
		world.free()
	push_error(message)
	quit(1)
