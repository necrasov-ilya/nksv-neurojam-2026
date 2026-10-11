extends Node3D

const Rooms := preload("res://scripts/campaign/rooms.gd")
var cube: RigidBody3D
var carried := false
var picked := false
var placed := false
var dropped := false
var modified := false
var restored := false
var _was_released_high := false
var _material: StandardMaterial3D
var _lamp: OmniLight3D
var _settle := 0.0
var actions := {"cube": Vector3(2, 0.4, 1), "material": Vector3(-3, 1.2, 0), "light": Vector3(3, 1.2, 0), "reset": Vector3(-3, 1.2, -3), "finish_calibration": Vector3(3, 1.2, -3)}

static func make_cube(parent: Node3D, p: Vector3, mass_value: float, color: Color) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = p
	body.mass = mass_value
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.9
	body.physics_material_override.bounce = 0.08
	body.continuous_cd = true
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.55, 0.55)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = box.size
	shape.shape = collision
	body.add_child(shape)
	parent.add_child(body)
	return body

func _ready() -> void:
	var g := Rooms.geometry(self)
	Rooms.shell(g, 5.0, 6.0)
	g.label("КАЛИБРОВКА / ЛОКАЛЬНАЯ СИМУЛЯЦИЯ", Vector3(0, 2.7, -5.8), 28, "accent_violet", Vector3.ZERO, 0.008)
	g.box(Vector3(0, 0.36, -1.1), Vector3(1.8, 0.72, 1.4), "accent_violet")
	g.solid(Vector3(0, 0.36, -1.1), Vector3(1.8, 0.72, 1.4))
	g.box(Vector3(0, 0.735, -1.1), Vector3(1.0, 0.03, 1.0), "mustard")
	g.label("ПЛОЩАДКА", Vector3(0, 1.6, -1.75), 24, "petrol", Vector3.ZERO, 0.007)
	for spec in [[-3.0, 0.0, "МАТЕРИАЛ", "accent_magenta"], [3.0, 0.0, "СВЕТ", "mustard"], [-3.0, -3.0, "СБРОС", "accent_violet"], [3.0, -3.0, "ЗАВЕРШИТЬ", "cross_green"]]:
		var p := Vector3(spec[0], 0, spec[1])
		g.box(p + Vector3(0, 0.70, 0), Vector3(0.7, 1.4, 0.50), "cream")
		g.solid(p + Vector3(0, 0.70, 0), Vector3(0.7, 1.4, 0.50))
		g.box(p + Vector3(0, 1.25, 0.27), Vector3(0.4, 0.25, 0.03), spec[3])
		g.label(spec[2], p + Vector3(0, 1.8, 0.2), 23, "petrol", Vector3.ZERO, 0.006)
	g.flush()
	cube = make_cube(self, Vector3(2, 0.32, 1), 1.5, Color("f2c750"))
	cube.name = "CalibrationCube"
	_material = cube.get_child(0).material_override
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 2.8, 0)
	_lamp.omni_range = 9.0
	_lamp.light_energy = 0.5
	_lamp.light_color = Color("ffdbb2")
	add_child(_lamp)

func _physics_process(delta: float) -> void:
	if carried:
		return
	var p := cube.position
	if _was_released_high and p.y < 0.36 and cube.linear_velocity.length() < 0.7:
		dropped = true
	if absf(p.x) < 0.58 and absf(p.z + 1.1) < 0.40 and p.y > 0.92 and p.y < 1.12 and cube.linear_velocity.length() < 0.25:
		_settle += delta
		if _settle > 0.35:
			placed = true
	else:
		_settle = 0
	if p.y < -4 or absf(p.x) > 7 or absf(p.z) > 8:
		reset_cube(false)

func pickup() -> void:
	carried = true
	picked = true
	cube.freeze = true
	cube.collision_layer = 0
	cube.collision_mask = 0

func carry(camera: Camera3D) -> void:
	if carried:
		cube.global_position = camera.to_global(Vector3(0, -0.48, -1.55))
		cube.global_rotation = Vector3(0, camera.global_rotation.y, 0)

func release() -> void:
	if not carried:
		return
	_was_released_high = cube.position.y > 0.75
	carried = false
	cube.collision_layer = 1
	cube.collision_mask = 1
	cube.freeze = false
	cube.sleeping = false
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO

func change_material() -> void:
	_material.albedo_color = Color("38ba91") if _material.albedo_color != Color("38ba91") else Color("f2c750")
	modified = true

func change_light() -> void:
	_lamp.light_color = Color("bcb4ff") if _lamp.light_color != Color("bcb4ff") else Color("ffdbb2")
	_lamp.light_energy = 1.2 if _lamp.light_energy < 1 else 0.5
	modified = true

func reset_cube(count_step := true) -> void:
	carried = false
	cube.freeze = true
	cube.collision_layer = 1
	cube.collision_mask = 1
	cube.position = Vector3(2, 0.32, 1)
	cube.rotation = Vector3.ZERO
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO
	_material.albedo_color = Color("f2c750")
	_lamp.light_color = Color("ffdbb2")
	_lamp.light_energy = 0.5
	cube.freeze = false
	cube.sleeping = false
	_was_released_high = false
	if count_step and picked and placed and dropped and modified:
		restored = true

func complete() -> bool:
	return picked and placed and dropped and modified and restored

func checklist() -> String:
	var text := "ПРАКТИЧЕСКАЯ ПРОБА\n"
	for entry in [[picked, "Поднять куб"], [placed, "Поставить на жёлтую площадку"], [dropped, "Уронить на пол"], [modified, "Изменить материал или свет"], [restored, "После проверок выполнить сброс"]]:
		text += ("✓ " if entry[0] else "○ ") + entry[1] + "\n"
	return text

func begin() -> void:
	picked = false
	placed = false
	dropped = false
	modified = false
	restored = false
	_settle = 0
	reset_cube(false)
