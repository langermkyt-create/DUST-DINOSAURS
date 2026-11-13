extends CharacterBody3D
@export var walk_speed := 6.0
@export var sprint_speed := 10.5
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0018
var gravity: float = 18.0
var camera_pivot: Node3D
var camera: Camera3D
var pitch := 0.0
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.58
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.08
	camera.far = 900.0
	camera_pivot.add_child(camera)
	camera.current = true
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		camera_pivot.rotation.x = pitch
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 5.0 * delta)
	move_and_slide()
