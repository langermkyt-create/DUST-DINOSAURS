extends CharacterBody3D

signal interacted

@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.5
@export var jump_velocity: float = 5.8
@export var mouse_sensitivity: float = 0.0018
@export var acceleration: float = 24.0
@export var air_control: float = 0.35

var gravity: float = 18.0
var camera_pivot: Node3D
var camera: Camera3D
var pitch: float = 0.0
var jump_requested: bool = false
var interaction_cooldown: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
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
	camera.far = 1200.0
	camera_pivot.add_child(camera)
	camera.current = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		camera_pivot.rotation.x = pitch
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			jump_requested = true
		if event.physical_keycode == KEY_E:
			interacted.emit()

func _physics_process(delta: float) -> void:
	interaction_cooldown = maxf(0.0, interaction_cooldown - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	if jump_requested and is_on_floor():
		velocity.y = jump_velocity
	jump_requested = false

	# Read physical keys directly as a fallback for keyboard layouts and missed InputMap events.
	var move_x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var move_z := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var move_input := Vector2(move_x, move_z)
	if move_input.length_squared() > 1.0:
		move_input = move_input.normalized()
	var direction := (transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT)
	var speed := sprint_speed if sprinting else walk_speed
	var control := 1.0 if is_on_floor() else air_control
	var target_x := direction.x * speed
	var target_z := direction.z * speed
	velocity.x = move_toward(velocity.x, target_x, acceleration * control * delta)
	velocity.z = move_toward(velocity.z, target_z, acceleration * control * delta)
	move_and_slide()
