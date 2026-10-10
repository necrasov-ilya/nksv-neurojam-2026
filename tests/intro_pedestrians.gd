extends SceneTree

const Pedestrians = preload("res://scripts/intro/pedestrians.gd")

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var people := Pedestrians.new()
	root.add_child(people)
	people.populate([[Vector3.ZERO, Vector3(0, 0, 10)]], 1, 42)
	people.set_process(false)
	var walker = people._walkers[0]
	walker.wait = 0.0
	# An avoidance retreat can end below the movement threshold after
	# floating-point subtraction. It must not trap the pedestrian forever.
	walker.retreat_remaining = 0.000032
	var initial: Vector3 = walker.position
	for step in 10:
		people._process(0.05)
	var resumed: bool = walker.position.z > initial.z + 0.2
	people.free()
	if not resumed:
		push_error("Pedestrian cannot resume its route after a sub-millimetre retreat remainder")
		quit(1)
		return
	print("INTRO_PEDESTRIANS_PASS: route resumes after an avoidance retreat remainder")
	quit(0)
