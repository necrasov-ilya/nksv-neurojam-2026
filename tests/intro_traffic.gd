extends SceneTree

const City = preload("res://scripts/intro/city.gd")
var _failed := false

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var city := City.new()
	root.add_child(city)
	city.set_process(false)
	city._background_traffic()
	for vehicle in city._traffic:
		var car: Node3D = vehicle["node"]
		var speed: float = vehicle["speed"]
		var axles: Array[Vector3] = []
		for wheel: Node3D in vehicle["wheels"]:
			axles.append(wheel.position)
		# Both cars drive forwards in their own frame despite opposite world directions.
		_expect((car.basis.x * absf(speed)).is_equal_approx(Vector3(0, 0, speed)), "Car faces away from its travel direction")
		for delta in [0.016, 0.1, 0.0]:
			var previous_z := car.position.z
			var previous_angle: float = vehicle["wheel_angle"]
			city._process(delta)
			var travel := absf(car.position.z - previous_z)
			var expected := previous_angle - travel / City.CAR_WHEEL_RADIUS
			_check_wheels(vehicle, axles, expected)
		# The route teleport must not be interpreted as hundreds of metres of rolling.
		car.position.z = -224.99 if speed < 0 else 179.99
		var previous_angle: float = vehicle["wheel_angle"]
		city._process(0.1)
		_expect(is_equal_approx(car.position.z, 180.0 if speed < 0 else -225.0), "Car did not wrap at the route boundary")
		_check_wheels(vehicle, axles, previous_angle - absf(speed) * 0.1 / City.CAR_WHEEL_RADIUS)
		vehicle["speed"] = 0.0
		previous_angle = vehicle["wheel_angle"]
		city._process(0.1)
		_check_wheels(vehicle, axles, previous_angle)
	city.free()
	if _failed:
		quit(1)
	else:
		print("INTRO_TRAFFIC_PASS: both lanes roll without axle drift; zero travel and route wraps preserve wheel phase")
		quit(0)

func _check_wheels(vehicle: Dictionary, axles: Array[Vector3], angle: float) -> void:
	var car: Node3D = vehicle["node"]
	var expected_radial := Vector3(cos(angle), sin(angle), 0)
	for i in axles.size():
		var wheel: Node3D = vehicle["wheels"][i]
		_expect(wheel.position.is_equal_approx(axles[i]), "Wheel orbits instead of rotating about its axle")
		# World-position subtraction at z~200 loses a few micrometres in float32.
		_expect(wheel.basis.x.distance_to(expected_radial) < 0.0001, "Wheel slips or rolls backwards")
		_expect(wheel.global_basis.z.is_equal_approx(car.global_basis.z), "Wheel rotates around the wrong axis")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
