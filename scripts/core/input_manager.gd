class_name JamInputManager
extends Node


func _ready() -> void:
	_bind_key("move_left", KEY_A)
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_right", KEY_D)
	_bind_key("move_right", KEY_RIGHT)
	_bind_key("move_forward", KEY_W)
	_bind_key("move_forward", KEY_UP)
	_bind_key("move_back", KEY_S)
	_bind_key("move_back", KEY_DOWN)
	_bind_key("rotate_left", KEY_Q)
	_bind_key("rotate_right", KEY_E)
	_bind_key("spawn_debug", KEY_SPACE)
	_bind_key("toggle_pause", KEY_ESCAPE)


func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func rotation_axis() -> float:
	return Input.get_axis("rotate_left", "rotate_right")


func debug_pressed() -> bool:
	return Input.is_action_just_pressed("spawn_debug")


func pause_pressed() -> bool:
	return Input.is_action_just_pressed("toggle_pause")


func _bind_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

