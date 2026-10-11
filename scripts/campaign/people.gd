extends "res://scripts/intro/pedestrians.gd"

func face_toward(target: Vector3) -> void:
	for walker: Walker in _walkers:
		var direction := to_local(target) - walker.position
		direction.y = 0
		if direction.length_squared() < 0.001:
			continue
		walker.heading = direction.normalized()
		walker.yaw = atan2(-direction.x, -direction.z)
		_snapshot(walker)
		_pose(walker, 1.0)
		_draw(walker)

func _build_person(w: Walker, index: int) -> void:
	super._build_person(w, index)
	if index not in [1, 2]:
		return
	var ink := Color("ac2954") if index == 2 else Color("d9b24f")
	if index == 2:
		var original := _material_color("accent_violet")
		for part in w.parts:
			if part.color == original:
				part.color = Color("69485e")
		# Thin glasses and a magenta lanyard identify Nika in every scene.
		for side in SIDES:
			_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.05, 0.055, -0.12), Vector3(0.075, 0.006, 0.012), Color("29263a"))
			_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.083, 0.032, -0.12), Vector3(0.006, 0.046, 0.012), Color("29263a"))
		_part(w, Shape.BOX, Joint.HEAD, Vector3(0, 0.048, -0.122), Vector3(0.025, 0.006, 0.012), Color("29263a"))
	else:
		_part(w, Shape.BOX, Joint.BODY, Vector3(-0.13, 1.20, -0.15), Vector3(0.085, 0.16, 0.035), Color("29263a"))
		_part(w, Shape.COLUMN, Joint.BODY, Vector3(-0.15, 1.34, -0.16), Vector3(0.01, 0.15, 0.01), Color("29263a"))
	for side in SIDES:
		_shirt_detail(w, Vector2(side * 0.035, 1.36), Vector2(0.016, 0.24), ink, side * 0.18, 0.012, 0.025)
	_shirt_detail(w, Vector2(0, 1.23), Vector2(0.09, 0.13), Color("f5f3fb"), 0, 0.016, 0.028)
	_shirt_detail(w, Vector2(0, 1.255), Vector2(0.06, 0.027), ink, 0, 0.016, 0.04)
