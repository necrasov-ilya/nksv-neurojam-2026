class_name JamCameraManager
extends Node3D

@export var move_speed := 8.0
@export var rotate_speed := 1.5

@onready var camera: Camera3D = $Camera3D
@onready var input_manager: JamInputManager = $"../InputManager"
@onready var session: SessionState = $"../SessionState"


func _ready() -> void:
	camera.look_at(global_position, Vector3.UP)


func _process(delta: float) -> void:
	if session.phase != SessionState.Phase.RUNNING:
		return
	rotation.y += input_manager.rotation_axis() * rotate_speed * delta
	var movement := input_manager.move_vector()
	var direction := (global_basis.x * movement.x + global_basis.z * movement.y).normalized()
	global_position += direction * move_speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var wheel := event as InputEventMouseButton
		if not wheel.pressed:
			return
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position *= 0.9
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position *= 1.1
		camera.position = camera.position.normalized() * clampf(camera.position.length(), 6.0, 35.0)

