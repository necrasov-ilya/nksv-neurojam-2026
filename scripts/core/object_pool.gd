class_name ObjectPool
extends Node3D

@export var scene_to_pool: PackedScene
@export_range(0, 256) var initial_size := 12

var available: Array[Node3D] = []


func _ready() -> void:
	for index in range(initial_size):
		available.append(_make_instance())


func acquire() -> Node3D:
	var instance: Node3D
	if available.is_empty():
		instance = _make_instance()
	else:
		instance = available.pop_back()
	instance.show()
	return instance


func release(instance: Node3D) -> void:
	if instance.get_parent() != self or available.has(instance):
		return
	instance.hide()
	available.append(instance)


func _make_instance() -> Node3D:
	var instance := scene_to_pool.instantiate() as Node3D
	add_child(instance)
	instance.hide()
	return instance
