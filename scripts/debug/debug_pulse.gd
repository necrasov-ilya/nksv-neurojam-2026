class_name DebugPulse
extends Node3D

const DURATION := 0.45

var elapsed := 0.0
var active := false


func activate(at_position: Vector3) -> void:
	position = at_position
	scale = Vector3.ONE
	elapsed = 0.0
	active = true


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	scale = Vector3.ONE * (1.0 + elapsed * 1.8)
	if elapsed >= DURATION:
		active = false
		(get_parent() as ObjectPool).release(self)

