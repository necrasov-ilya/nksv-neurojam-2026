class_name SessionState
extends Node

signal phase_changed(phase: Phase)

enum Phase { READY, RUNNING, PAUSED }

var phase: Phase = Phase.READY


func start() -> void:
	if phase == Phase.READY or phase == Phase.PAUSED:
		_set_phase(Phase.RUNNING)


func pause() -> void:
	if phase == Phase.RUNNING:
		_set_phase(Phase.PAUSED)


func reset() -> void:
	_set_phase(Phase.READY)


func _set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)

