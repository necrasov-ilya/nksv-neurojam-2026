extends CharacterBody3D
signal stepped
const WALK_SPEED := 3.8
var camera: Camera3D
# Modal screens freeze the body as well as input, including gravity.
var enabled := true:
	set(value):
		enabled = value
		set_physics_process(value)
var _step_distance := 0.0
var _pitch := 0.0
var _discard_capture_motion := false

func _ready() -> void:
	name = "Player"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 72.0
	camera.near = 0.07
	camera.far = 420.0
	add_child(camera)
	camera.current = true
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(45)
	_register_action("intro_forward", KEY_W)
	_register_action("intro_back", KEY_S)
	_register_action("intro_left", KEY_A)
	_register_action("intro_right", KEY_D)
	_register_action("intro_use", KEY_E)

func _register_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func capture_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	_discard_capture_motion = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		if _discard_capture_motion:
			_discard_capture_motion = false
			return
		rotation.y -= event.screen_relative.x * 0.0022
		_pitch = clampf(_pitch - event.screen_relative.y * 0.0022, -1.35, 1.35)
		camera.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	var axis := Input.get_vector("intro_left", "intro_right", "intro_forward", "intro_back")
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	var previous := global_position
	move_and_slide()
	var travelled := global_position - previous
	travelled.y = 0
	_step_distance += travelled.length()
	if _step_distance > 1.65 and is_on_floor():
		_step_distance = 0
		stepped.emit()

func place(p: Vector3, yaw: float) -> void:
	global_position = p
	rotation.y = yaw
	_pitch = 0
	camera.rotation.x = 0
	velocity = Vector3.ZERO
	_step_distance = 0
