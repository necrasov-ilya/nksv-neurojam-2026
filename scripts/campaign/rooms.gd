extends RefCounted

const Geometry := preload("res://scripts/campaign/architecture.gd")
const People := preload("res://scripts/campaign/people.gd")

static func geometry(parent: Node3D) -> Geometry:
	var result := Geometry.new()
	parent.add_child(result)
	return result

static func block(g: Geometry, p: Vector3, size: Vector3, material: String) -> void:
	g.box(p, size, material)
	g.solid(p, size)

static func shell(g: Geometry, half_width: float, half_depth: float, domestic := false, back_opening := 0.0) -> void:
	block(g, Vector3(0, -0.14, 0), Vector3(half_width * 2, 0.28, half_depth * 2), "wood" if domestic else "tile")
	for x in [-half_width, half_width]:
		block(g, Vector3(x, 1.8, 0), Vector3(0.3, 3.6, half_depth * 2), "cream")
		g.box(Vector3(x * 0.986, 0.11, 0), Vector3(0.08, 0.22, half_depth * 2), "petrol")
		for z in range(-int(half_depth) + 2, int(half_depth), 4):
			g.box(Vector3(x * 0.975, 1.8, z), Vector3(0.28, 3.6, 0.22), "concrete")
	if back_opening > 0:
		var panel_width := half_width - back_opening * 0.5
		for side in [-1, 1]:
			block(g, Vector3(side * (back_opening + panel_width) * 0.5, 1.8, half_depth), Vector3(panel_width, 3.6, 0.3), "cream")
		block(g, Vector3(0, 3.3, half_depth), Vector3(back_opening, 0.6, 0.3), "cream")
	else:
		block(g, Vector3(0, 1.8, half_depth), Vector3(half_width * 2, 3.6, 0.3), "cream")
	# Real window openings; the skyline is outside the building, not painted on its wall.
	block(g, Vector3(0, 0.43, -half_depth), Vector3(half_width * 2, 0.86, 0.45), "concrete")
	block(g, Vector3(0, 3.25, -half_depth), Vector3(half_width * 2, 0.7, 0.45), "cream")
	g.box(Vector3(0, 0.89, -half_depth + 0.10), Vector3(half_width * 2, 0.1, 0.7), "white")
	g.box(Vector3(0, 1.9, -half_depth), Vector3(half_width * 2, 2.05, 0.04), "clear_glass")
	g.solid(Vector3(0, 1.9, -half_depth), Vector3(half_width * 2, 2.05, 0.08))
	for x in range(-int(half_width), int(half_width) + 1, 2):
		g.box(Vector3(x, 1.9, -half_depth + 0.03), Vector3(0.09, 2.1, 0.2), "petrol")
	g.box(Vector3(0, 3.64, 0), Vector3(half_width * 2, 0.18, half_depth * 2), "cream")
	for z in range(-int(half_depth) + 1, int(half_depth), 3):
		g.box(Vector3(0, 3.44, z), Vector3(half_width * 2, 0.25, 0.17), "white")
	for x in [-half_width + 0.4, half_width - 0.4]:
		g.box(Vector3(x, 3.38, 0), Vector3(0.36, 0.2, half_depth * 2), "petrol")
	skyline(g, Vector3(0, -5, -half_depth - 14), half_width)

static func skyline(g: Geometry, origin: Vector3, width: float) -> void:
	for i in range(-4, 5):
		var x := i * 4.8
		var height := 5.0 + posmod(i * 7, 5) * 0.8
		g.box(origin + Vector3(x, height * 0.5, -absf(i) * 1.2), Vector3(3.9, height, 3.0), "navy" if i % 2 == 0 else "steel")
		for y in range(1, int(height)):
			for column in 3:
				g.box(origin + Vector3(x - 1.25 + column * 1.2, y, 1.53 - absf(i) * 1.2), Vector3(0.5, 0.65, 0.03), "sand" if (y + column + i) % 3 == 0 else "petrol")
	g.box(origin + Vector3(0, -0.4, 0), Vector3(width * 8, 0.3, 20), "petrol")

static func lamp(parent: Node3D, g: Geometry, p: Vector3, warm := false, energy := 1.0) -> SpotLight3D:
	g.box(p, Vector3(2.4, 0.12, 0.35), "petrol")
	g.box(p - Vector3(0, 0.067, 0), Vector3(2.22, 0.025, 0.23), "sand" if warm else "white")
	for x in [-0.9, 0.9]:
		g.cylinder(p + Vector3(x, 0.2, 0), 0.012, 0.4, "steel")
	var light := SpotLight3D.new()
	light.position = p - Vector3(0, 0.12, 0)
	light.rotation.x = -PI / 2
	light.light_color = Color("ffdeaf") if warm else Color("e5e9ff")
	light.light_energy = energy
	light.spot_range = 11
	light.spot_angle = 70
	light.spot_attenuation = 0.5
	light.shadow_enabled = true
	parent.add_child(light)
	return light

static func plaque(g: Geometry, text: String, p: Vector3, width := 1.6, ink := "petrol", yaw := 0.0) -> Label3D:
	g.box(p, Vector3(width, 0.30, 0.045), "cream", Vector3(0, yaw, 0))
	return g.label(text, p + Vector3(0, 0, 0.03).rotated(Vector3.UP, yaw), 27, ink, Vector3(0, yaw, 0), 0.006, width - 0.12, 0.23)

static func door_frame(g: Geometry, p: Vector3, title: String, ink := "accent_violet", yaw := 0.0) -> void:
	for x in [-0.93, 0.93]:
		g.box(p + Vector3(x, 1.42, 0), Vector3(0.16, 2.84, 0.36), "petrol")
	g.box(p + Vector3(0, 2.84, 0), Vector3(2.02, 0.16, 0.36), "petrol")
	g.box(p + Vector3(0, 1.35, 0.08), Vector3(1.7, 2.7, 0.12), ink)
	g.box(p + Vector3(0.62, 1.04, -0.06), Vector3(0.05, 0.35, 0.08), "steel")
	plaque(g, title, p + Vector3(0, 3.1, -0.16 if yaw != 0 else 0.16), 2.0, "petrol", yaw)

static func mug(g: Geometry, p: Vector3, ink := "accent_magenta") -> void:
	g.cylinder(p + Vector3(0, 0.07, 0), 0.075, 0.14, ink)
	g.cylinder(p + Vector3(0, 0.143, 0), 0.061, 0.004, "petrol")
	g.torus(p + Vector3(0.09, 0.07, 0), 0.024, 0.037, ink, Vector3(PI / 2, 0, 0))

static func papers(g: Geometry, p: Vector3, ink := "accent_violet") -> void:
	g.box(p, Vector3(0.42, 0.026, 0.31), "white", Vector3(0, 0.12, 0))
	for n in 4:
		g.box(p + Vector3(-0.04, 0.015, -0.1 + n * 0.05), Vector3(0.27 if n < 3 else 0.13, 0.005, 0.012), ink)
	g.cylinder(p + Vector3(0.27, 0.023, 0), 0.012, 0.27, ink, Vector3(PI / 2, 0, -0.12))

static func desk(g: Geometry, p: Vector3, wide := 2.4) -> void:
	block(g, p + Vector3(0, 0.77, 0), Vector3(wide, 0.12, 1.15), "wood")
	for x in [-wide * 0.42, wide * 0.42]:
		g.box(p + Vector3(x, 0.36, 0), Vector3(0.06, 0.72, 0.74), "steel")
		g.box(p + Vector3(x, 0.05, 0), Vector3(0.35, 0.06, 0.82), "petrol")
	g.box(p + Vector3(0, 1.22, -0.24), Vector3(1.1, 0.68, 0.08), "petrol")
	g.box(p + Vector3(0, 1.22, -0.19), Vector3(1.01, 0.59, 0.012), "glass")
	for n in 3:
		g.box(p + Vector3(-0.12, 1.37 - n * 0.12, -0.18), Vector3(0.58 - n * 0.12, 0.025, 0.006), "lilac")
	g.box(p + Vector3(0, 0.93, -0.24), Vector3(0.10, 0.24, 0.1), "steel")
	g.box(p + Vector3(0, 0.84, -0.24), Vector3(0.45, 0.04, 0.3), "petrol")
	g.box(p + Vector3(-0.10, 0.85, 0.28), Vector3(0.60, 0.04, 0.23), "petrol")
	for row in 3:
		for key in 9:
			g.box(p + Vector3(-0.35 + key * 0.062, 0.873, 0.20 + row * 0.064), Vector3(0.047, 0.012, 0.04), "steel")
	g.ellipsoid(p + Vector3(0.43, 0.865, 0.28), Vector3(0.10, 0.07, 0.15), "petrol")
	g.box(p + Vector3(wide * 0.37, 0.3, -0.18), Vector3(0.30, 0.55, 0.50), "petrol")
	for n in 5:
		g.box(p + Vector3(wide * 0.37, 0.25 + n * 0.04, 0.08), Vector3(0.22, 0.009, 0.012), "steel")
	g.cylinder(p + Vector3(0, 0.46, -0.38), 0.013, 0.65, "petrol")
	chair(g, p + Vector3(0, 0, 1.07))
	mug(g, p + Vector3(-wide * 0.37, 0.84, 0.20))
	papers(g, p + Vector3(wide * 0.34, 0.85, 0.18))

static func chair(g: Geometry, p: Vector3, ink := "petrol") -> void:
	g.box(p + Vector3(0, 0.46, 0), Vector3(0.53, 0.10, 0.5), ink)
	g.box(p + Vector3(0, 0.80, 0.23), Vector3(0.53, 0.65, 0.10), ink, Vector3(-0.08, 0, 0))
	g.cylinder(p + Vector3(0, 0.23, 0), 0.045, 0.46, "steel")
	for n in 5:
		var angle := n * TAU / 5
		g.box(p + Vector3(sin(angle) * 0.18, 0.09, cos(angle) * 0.18), Vector3(0.04, 0.035, 0.36), "steel", Vector3(0, angle, 0))
		g.ellipsoid(p + Vector3(sin(angle) * 0.34, 0.05, cos(angle) * 0.34), Vector3(0.09, 0.08, 0.10), "petrol")

static func plant(g: Geometry, p: Vector3, height := 1.2) -> void:
	g.cylinder(p + Vector3(0, 0.2, 0), 0.22, 0.4, "concrete")
	g.cylinder(p + Vector3(0, 0.405, 0), 0.19, 0.02, "petrol")
	g.cylinder(p + Vector3(0, height * 0.5 + 0.25, 0), 0.025, height, "leaf_dark")
	for n in 8:
		var angle := n * 1.9
		g.ellipsoid(p + Vector3(cos(angle) * 0.25, 0.60 + n * height * 0.085, sin(angle) * 0.25), Vector3(0.36, 0.12, 0.18), "leaf_light" if n % 3 == 0 else "leaf_dark")

static func actor(parent: Node3D, id: String, p: Vector3, appearance: int, yaw := PI) -> Node3D:
	var root := Node3D.new()
	root.name = id
	root.position = p
	parent.add_child(root)
	var person := People.new()
	root.add_child(person)
	person.populate_stationary(Vector3.ZERO, yaw, appearance)
	return root

static func sliding_gate(parent: Node3D, p: Vector3) -> Node3D:
	var frame := geometry(parent)
	for x in [-1.03, 1.03]:
		frame.box(p + Vector3(x, 1.45, 0), Vector3(0.20, 2.9, 0.45), "steel")
	frame.box(p + Vector3(0, 2.95, 0), Vector3(2.28, 0.28, 0.50), "petrol")
	frame.flush()
	var gate := Node3D.new()
	gate.position = p
	parent.add_child(gate)
	var g := geometry(gate)
	g.box(Vector3(0, 1.3, 0), Vector3(1.8, 2.6, 0.15), "steel")
	g.box(Vector3(0, 1.5, 0.086), Vector3(1.5, 1.1, 0.018), "pane")
	g.box(Vector3(0, 0.6, 0.09), Vector3(1.55, 0.10, 0.025), "mustard")
	for x in [-0.68, 0.68]:
		g.box(Vector3(x, 0.86, 0.12), Vector3(0.04, 0.28, 0.05), "petrol")
	g.solid(Vector3(0, 1.3, 0), Vector3(1.8, 2.6, 0.18))
	g.flush()
	return gate

static func set_gate_open(gate: Node3D, opened: bool) -> void:
	gate.position.y = 2.8 if opened else 0.0
	for body in gate.find_children("*", "CollisionShape3D", true, false):
		body.set_deferred("disabled", opened)

static func build_lab(parent: Node3D) -> Dictionary:
	var g := geometry(parent)
	shell(g, 10, 12)
	# A low entrance screen frames the first view, without interrupting the central route.
	block(g, Vector3(-3.3, 1.35, 5.8), Vector3(0.18, 2.7, 4.3), "petrol")
	g.box(Vector3(-3.18, 1.4, 5.8), Vector3(0.04, 1.4, 3.2), "accent_violet")
	g.label("LATENT\nSYSTEMS", Vector3(-3.13, 1.8, 6.5), 40, "white", Vector3(0, PI / 2, 0), 0.009, 2, 1)
	g.box(Vector3(2.8, 0.014, 0), Vector3(4.8, 0.025, 4.2), "lilac")
	g.box(Vector3(-5.5, 0.014, -4.2), Vector3(5, 0.025, 9), "petrol")
	for z in [-8.6, -3.7]:
		for x in [-8.8, -2.4]:
			g.box(Vector3(x, 1.3, z), Vector3(0.07, 2.6, 0.1), "steel")
		g.box(Vector3(-5.6, 0.55, z), Vector3(6.4, 1.1, 0.10), "concrete")
		g.box(Vector3(-5.6, 1.85, z), Vector3(6.4, 1.5, 0.025), "clear_glass")
	desk(g, Vector3(2.6, 0, 0))
	desk(g, Vector3(-5.5, 0, -6.8))
	desk(g, Vector3(-5.5, 0, -1.5))
	plaque(g, "01 / КАНДИДАТ", Vector3(3.3, 0.98, -0.40), 0.9)
	plaque(g, "НИКА / QA", Vector3(-6.3, 0.98, -7.1), 0.9, "accent_magenta")
	plaque(g, "АРХИВ НАБЛЮДЕНИЙ", Vector3(-5.5, 1.83, -1.85), 1.65)
	for x in [-8.5, -1.8, 8.5]:
		plant(g, Vector3(x, 0, -10.5), 1.7)
	# Kitchen: worktop, tiled splashback, sink, coffee machine and drying rack.
	block(g, Vector3(-7.7, 0.45, 6.35), Vector3(3.3, 0.9, 0.8), "wood")
	g.box(Vector3(-7.7, 0.94, 6.35), Vector3(3.42, 0.09, 0.94), "cream")
	g.box(Vector3(-7.7, 1.45, 5.95), Vector3(3.4, 0.9, 0.06), "tile")
	for x in [-8.7, -7.7, -6.7]:
		g.box(Vector3(x, 0.48, 6.765), Vector3(0.94, 0.78, 0.03), "concrete")
		g.box(Vector3(x, 0.78, 6.79), Vector3(0.35, 0.035, 0.035), "steel")
	g.box(Vector3(-8.7, 1.19, 6.3), Vector3(0.6, 0.47, 0.52), "petrol")
	g.box(Vector3(-8.7, 1.17, 6.58), Vector3(0.36, 0.22, 0.02), "steel")
	g.box(Vector3(-6.7, 0.993, 6.35), Vector3(0.65, 0.02, 0.52), "steel")
	g.cylinder(Vector3(-6.7, 1.15, 6.05), 0.025, 0.35, "steel")
	g.cylinder(Vector3(-6.7, 1.31, 6.15), 0.025, 0.22, "steel", Vector3(PI / 2, 0, 0))
	mug(g, Vector3(-7.5, 0.99, 6.35))
	papers(g, Vector3(-7.8, 0.99, 6.5))
	plaque(g, "ПЕРЕРЫВ / ВОДА / КОФЕ", Vector3(-7.7, 2.05, 5.97), 2.8)
	door_frame(g, Vector3(-6.3, 0, 11.72), "ЛИФТ / В ГОРОД", "accent_violet", PI)
	door_frame(g, Vector3(7.5, 0, 11.72), "ЭКСПЛУАТАЦИЯ", "petrol", PI)
	for x in [4.8, 8.5]:
		block(g, Vector3(x, 0.45, -5), Vector3(1.8, 0.9, 0.16), "concrete")
		g.box(Vector3(x, 1.95, -5), Vector3(1.8, 2.1, 0.04), "clear_glass")
		g.solid(Vector3(x, 1.95, -5), Vector3(1.8, 2.1, 0.08))
		for edge in [-0.87, 0.87]:
			g.box(Vector3(x + edge, 1.5, -5), Vector3(0.045, 3, 0.12), "steel")
	g.box(Vector3(5.1, 1.05, -4.75), Vector3(0.32, 0.45, 0.18), "mustard")
	plaque(g, "МЕСТНЫЙ РЕЖИМ", Vector3(5.1, 1.53, -4.70), 1.4)
	plaque(g, "НАБЛЮДАТЕЛЬНЫЙ ПОСТ", Vector3(6.6, 3.25, -4.78), 3)
	for x in [5.2, 8.3]:
		block(g, Vector3(x, 0.6, -9.2), Vector3(1.7, 1.2, 1.0), "petrol")
		g.box(Vector3(x, 1.35, -9.25), Vector3(1.4, 0.24, 0.8), "steel")
	# A printer bay, acoustic lining and lockers make the circulation edge useful.
	block(g, Vector3(8.9, 0.48, 3.5), Vector3(1.2, 0.96, 3.0), "wood")
	g.box(Vector3(8.9, 1.14, 3.8), Vector3(0.78, 0.36, 0.92), "cream")
	g.box(Vector3(8.48, 1.20, 3.8), Vector3(0.035, 0.16, 0.57), "petrol")
	papers(g, Vector3(8.8, 0.99, 2.6))
	for n in 16:
		g.box(Vector3(9.76, 1.86, 1.8 + n * 0.23), Vector3(0.15, 2.35, 0.11), "wood")
	for x in [-0.4, 0.5, 1.4]:
		block(g, Vector3(x, 1.15, 11.3), Vector3(0.82, 2.3, 0.55), "concrete")
		g.box(Vector3(x, 1.15, 10.99), Vector3(0.72, 2.15, 0.04), "steel")
		g.box(Vector3(x + 0.23, 1.2, 10.95), Vector3(0.045, 0.25, 0.05), "petrol")
		for n in 3:
			g.box(Vector3(x, 1.97 + n * 0.05, 10.96), Vector3(0.37, 0.012, 0.01), "petrol")
	g.cylinder(Vector3(-1.2, 2.45, 11.70), 0.3, 0.08, "petrol", Vector3(PI / 2, 0, 0))
	g.cylinder(Vector3(-1.2, 2.45, 11.64), 0.27, 0.015, "cream", Vector3(PI / 2, 0, 0))
	g.box(Vector3(-1.2, 2.54, 11.61), Vector3(0.018, 0.18, 0.02), "petrol")
	g.box(Vector3(-1.11, 2.45, 11.61), Vector3(0.18, 0.018, 0.02), "petrol")
	var lights: Array = []
	for p in [Vector3(2.6, 3.05, 0), Vector3(-5.5, 3.05, -5), Vector3(-7.6, 3.05, 6.4), Vector3(6.6, 3.05, -8)]:
		lights.append(lamp(parent, g, p, p.z > 3, 1.2))
	lights[1].shadow_enabled = false
	lights[2].shadow_enabled = false
	lights[3].shadow_enabled = false
	g.flush()
	var gate := sliding_gate(parent, Vector3(6.6, 0, -5))
	set_gate_open(gate, true)
	var nika := actor(parent, "Nika", Vector3(-5.2, 0, -5.3), 2)
	var artem := actor(parent, "Artem", Vector3(6.6, 0, -7), 1)
	var elena := actor(parent, "Elena", Vector3(4.2, 0, -2.0), 4)
	var day_details := Node3D.new()
	day_details.name = "ShiftDetails"
	parent.add_child(day_details)
	return {"gate": gate, "nika": nika, "artem": artem, "elena": elena, "details": day_details, "lights": lights, "actions": {"computer": Vector3(2.6, 1.3, -0.12), "archive": Vector3(-5.5, 1.3, -1.6), "nika": Vector3(-5.2, 1.3, -5.3), "coffee": Vector3(-7.5, 1, 6.35), "exit": Vector3(-6.3, 1.3, 11.6), "service": Vector3(7.5, 1.3, 11.6), "lab_gate": Vector3(5.1, 1.15, -4.65)}}

static func build_home(parent: Node3D) -> Dictionary:
	var g := geometry(parent)
	shell(g, 5, 6, true)
	# Open doorways preserve the route from the entrance to every interaction.
	block(g, Vector3(-0.3, 1.45, 4.8), Vector3(0.16, 2.9, 2.0), "cream")
	block(g, Vector3(-0.3, 1.45, 0.8), Vector3(0.16, 2.9, 1.8), "cream")
	g.box(Vector3(-0.3, 2.98, 2.8), Vector3(0.22, 0.2, 2.1), "wood")
	block(g, Vector3(-3.5, 0.46, -4.8), Vector3(2.55, 0.92, 0.9), "wood")
	g.box(Vector3(-3.5, 0.96, -4.8), Vector3(2.65, 0.08, 1.0), "cream")
	for x in [-4.3, -3.5, -2.7]:
		g.box(Vector3(x, 0.47, -4.335), Vector3(0.75, 0.80, 0.035), "sand")
		g.box(Vector3(x, 0.77, -4.30), Vector3(0.27, 0.03, 0.04), "petrol")
	g.box(Vector3(-4.2, 1.01, -4.7), Vector3(0.58, 0.015, 0.58), "petrol")
	for x in [-4.35, -4.05]:
		g.torus(Vector3(x, 1.028, -4.7), 0.075, 0.09, "steel")
	mug(g, Vector3(-3.35, 1.01, -4.4), "cream")
	g.cylinder(Vector3(-3.8, 1.13, -4.8), 0.14, 0.22, "steel")
	block(g, Vector3(-4.4, 1.05, -2.8), Vector3(0.8, 2.1, 0.9), "cream")
	g.box(Vector3(-4.4, 1.2, -2.34), Vector3(0.73, 0.025, 0.02), "steel")
	g.box(Vector3(-4.12, 1.48, -2.32), Vector3(0.04, 0.45, 0.04), "petrol")
	papers(g, Vector3(-2.7, 1.025, -4.55))
	desk(g, Vector3(2.5, 0, -3.8), 2.2)
	# Shelves and lived-in objects, not a second corporate workstation.
	for y in [1.9, 2.5]:
		g.box(Vector3(3.1, y, -5.45), Vector3(3.0, 0.06, 0.5), "wood")
		for n in 7:
			g.box(Vector3(2 + n * 0.22, y + 0.17, -5.5), Vector3(0.15, 0.28 + (n % 3) * 0.04, 0.22), ["petrol", "rose", "lilac"][n % 3])
	block(g, Vector3(3.0, 0.3, 3.6), Vector3(2.6, 0.60, 3.2), "wood")
	g.box(Vector3(3.0, 0.69, 3.6), Vector3(2.55, 0.26, 3.12), "cream")
	g.box(Vector3(3.0, 0.85, 4.0), Vector3(2.57, 0.10, 2.3), "rose")
	for n in 8:
		g.box(Vector3(1.85 + n * 0.32, 0.907, 4), Vector3(0.015, 0.008, 2.2), "lilac")
	g.ellipsoid(Vector3(3.0, 0.90, 2.3), Vector3(1.6, 0.30, 0.67), "sand")
	g.box(Vector3(3, 0.9, 2.02), Vector3(2.7, 0.95, 0.12), "wood")
	block(g, Vector3(4.5, 0.4, 2.2), Vector3(0.6, 0.8, 0.55), "wood")
	g.cylinder(Vector3(4.5, 1.02, 2.2), 0.023, 0.4, "steel")
	g.cone(Vector3(4.5, 1.25, 2.2), 0.22, 0.3, "sand")
	g.box(Vector3(1.0, 0.02, 3.6), Vector3(1.2, 0.035, 3.5), "lilac")
	block(g, Vector3(-3.25, 0.4, 1.0), Vector3(2.4, 0.55, 1.0), "petrol")
	g.box(Vector3(-3.25, 0.9, 0.58), Vector3(2.4, 0.85, 0.18), "navy")
	for x in [-4.35, -2.15]:
		g.box(Vector3(x, 0.73, 1.0), Vector3(0.18, 0.6, 1.0), "navy")
	g.box(Vector3(-3.0, 0.74, 1.03), Vector3(0.8, 0.09, 0.8), "rose")
	g.box(Vector3(-3.2, 0.04, 2.65), Vector3(2.2, 0.03, 1.5), "sand")
	g.cylinder(Vector3(-3.2, 0.48, 2.65), 0.52, 0.07, "wood")
	g.cylinder(Vector3(-3.2, 0.24, 2.65), 0.05, 0.46, "steel")
	papers(g, Vector3(-3.2, 0.53, 2.65))
	# Curtain folds leave an actual view of the city.
	for x in [-4.6, -2.25, 0.2, 4.5]:
		for fold in 4:
			g.cylinder(Vector3(x + fold * 0.1, 1.93, -5.68), 0.09, 2.25, "sand")
	door_frame(g, Vector3(-1.8, 0, 5.8), "", "wood", PI)
	g.box(Vector3(-3.5, 1.02, 5.53), Vector3(1.35, 0.08, 0.35), "wood")
	g.torus(Vector3(-3.3, 1.07, 5.45), 0.04, 0.055, "steel")
	g.box(Vector3(-3.5, 1.07, 5.42), Vector3(0.12, 0.014, 0.18), "accent_violet")
	for x in [-3.8, -3.4]:
		g.ellipsoid(Vector3(x, 0.09, 5.1), Vector3(0.17, 0.18, 0.38), "petrol")
	plant(g, Vector3(4.2, 0, -5.0), 0.9)
	var lights := [lamp(parent, g, Vector3(-3.3, 3.05, -3.8), true, 1.1), lamp(parent, g, Vector3(2.5, 3.05, -3.6), true, 0.7)]
	var bedside := OmniLight3D.new()
	bedside.position = Vector3(4.5, 1.26, 2.2)
	bedside.light_color = Color("ffbb7d")
	bedside.light_energy = 0.65
	bedside.omni_range = 4
	parent.add_child(bedside)
	lights.append(bedside)
	g.flush()
	var details := Node3D.new()
	parent.add_child(details)
	return {"details": details, "lights": lights, "actions": {"home_pc": Vector3(2.5, 1.3, -3.9), "bed": Vector3(2.2, 1.0, 2.3), "home_exit": Vector3(-1.8, 1.3, 5.65), "home_coffee": Vector3(-3.35, 1.1, -4.4)}}

static func build_service(parent: Node3D) -> Dictionary:
	var g := geometry(parent)
	shell(g, 6, 7, false, 2.4)
	block(g, Vector3(0, -0.14, 8.5), Vector3(3.2, 0.28, 4.0), "tile")
	for x in [-1.6, 1.6]:
		block(g, Vector3(x, 1.6, 8.5), Vector3(0.2, 3.2, 4.0), "petrol")
	block(g, Vector3(0, 1.6, 10.4), Vector3(3.2, 3.2, 0.2), "petrol")
	g.box(Vector3(0, 0.012, 1), Vector3(2.2, 0.025, 11), "petrol")
	for x in [-1.18, 1.18]:
		g.box(Vector3(x, 0.03, 1), Vector3(0.05, 0.015, 11), "mustard")
	for x in [-3.6, 3.6]:
		for z in [-5.4, -3.4]:
			block(g, Vector3(x, 1.35, z), Vector3(1.4, 2.7, 1.2), "petrol")
			for edge in [-0.64, 0.64]:
				g.box(Vector3(x + edge, 1.35, z + 0.64), Vector3(0.055, 2.55, 0.05), "steel")
			for row in 9:
				var y := 0.27 + row * 0.26
				g.box(Vector3(x, y, z + 0.63), Vector3(1.16, 0.2, 0.06), "steel")
				for vent in 6:
					g.box(Vector3(x - 0.35 + vent * 0.12, y, z + 0.67), Vector3(0.045, 0.13, 0.01), "petrol")
				g.box(Vector3(x - 0.49, y, z + 0.68), Vector3(0.028, 0.028, 0.015), "cross_green")
		g.box(Vector3(x, 3.15, -3.8), Vector3(1.0, 0.14, 5.8), "steel")
		for cable in 5:
			g.cylinder(Vector3(x - 0.3 + cable * 0.15, 3.26, -3.8), 0.033, 5.7, "petrol", Vector3(PI / 2, 0, 0))
	for x in [-5.6, 5.6]:
		g.cylinder(Vector3(x, 2.8, 0), 0.18, 13, "steel", Vector3(PI / 2, 0, 0))
		for z in [-5, -1, 3, 6]:
			g.torus(Vector3(x, 2.8, z), 0.18, 0.22, "petrol", Vector3(PI / 2, 0, 0))
	for x in [-3.6, 3.6]:
		block(g, Vector3(x, 0.4, -2), Vector3(4.6, 0.8, 0.16), "concrete")
		g.box(Vector3(x, 1.93, -2), Vector3(4.6, 2.25, 0.03), "clear_glass")
		g.solid(Vector3(x, 1.93, -2), Vector3(4.6, 2.25, 0.08))
		g.box(Vector3(x, 3.13, -2), Vector3(4.6, 0.16, 0.16), "petrol")
		for dx in [-2.24, 0, 2.24]:
			g.box(Vector3(x + dx, 1.9, -2), Vector3(0.045, 2.4, 0.14), "steel")
	plaque(g, "СЛУЖЕБНЫЙ ШЛЮЗ", Vector3(0, 3.3, -1.85), 2.4)
	block(g, Vector3(-3.7, 1.2, 2.8), Vector3(1.5, 2.4, 0.55), "petrol")
	g.box(Vector3(-3.7, 1.4, 3.09), Vector3(1.18, 0.83, 0.07), "glass")
	g.box(Vector3(-3.7, 0.8, 3.14), Vector3(0.35, 0.2, 0.08), "mustard")
	plaque(g, "01 / ИЗОЛЯЦИЯ СЕТИ", Vector3(-3.7, 2.65, 3.17), 1.9)
	desk(g, Vector3(3.6, 0, 3.0), 2.0)
	plaque(g, "ДОПУСК ЭКСПЛУАТАЦИИ", Vector3(3.6, 1.8, 2.8), 1.9)
	block(g, Vector3(0, 0.06, 1.3), Vector3(1.1, 0.12, 1.1), "mustard")
	g.box(Vector3(0, 0.127, 1.3), Vector3(0.85, 0.015, 0.85), "steel")
	for n in 7:
		g.box(Vector3(-0.36 + n * 0.12, 0.139, 1.3), Vector3(0.04, 0.008, 0.78), "petrol")
	g.box(Vector3(0, 1.05, 0.48), Vector3(0.12, 1.85, 0.12), "steel")
	g.torus(Vector3(0, 1.4, 0.48), 0.16, 0.25, "accent_magenta", Vector3(PI / 2, 0, 0))
	for x in [-0.5, 0.5]:
		g.cylinder(Vector3(x, 0.29, 0.55), 0.06, 0.45, "steel")
	plaque(g, "02 / УДЕРЖАНИЕ", Vector3(0, 2.1, 0.60), 1.7)
	plaque(g, "НАГРУЗКА ≥ 5 КГ", Vector3(0, 0.3, 1.89), 1.1)
	g.box(Vector3(-3.4, 0.025, -0.2), Vector3(1.4, 0.05, 1.4), "mustard")
	plaque(g, "КЕРАМИКА / 8 КГ", Vector3(-3.4, 0.35, -0.82), 1.4)
	plaque(g, "ВЫХОД НА ЭТАЖ", Vector3(0, 3.25, 6.72), 2.2, "petrol", PI)
	var lights := [lamp(parent, g, Vector3(0, 3.18, 3.5), false, 1.3), lamp(parent, g, Vector3(0, 3.18, -4), false, 1.4)]
	g.flush()
	var gate := sliding_gate(parent, Vector3(0, 0, -2))
	var exit_gate := sliding_gate(parent, Vector3(0, 0, 6.78))
	exit_gate.rotation.y = PI
	var nika := actor(parent, "NikaInSector", Vector3(1.8, 0, -4.5), 2)
	var artem := actor(parent, "ArtemAtExit", Vector3(2.0, 0, 5.7), 1, 0)
	var sign := geometry(parent)
	var occupancy := plaque(sign, "ЗАНЯТОСТЬ: 0 / ПРОГНОЗ", Vector3(2.7, 2.45, -1.84), 2.9, "accent_magenta")
	sign.flush()
	return {"gate": gate, "exit_gate": exit_gate, "nika": nika, "artem": artem, "occupancy": occupancy, "lights": lights, "actions": {"isolate": Vector3(-3.7, 1.2, 3.2), "permit": Vector3(3.6, 1.3, 2.9), "valve": Vector3(0, 1.3, 0.48), "escape": Vector3(0, 1.3, 6.6), "sector_window": Vector3(2.7, 1.6, -1.8)}}

static func dress_shift(info: Dictionary, day: int, profile: Dictionary, domestic := false, evening := true) -> void:
	var details: Node3D = info.details
	for child in details.get_children():
		child.free()
	var g := geometry(details)
	if domestic:
		if day >= 1:
			papers(g, Vector3(3.25, 0.87, -3.6), "accent_magenta")
			mug(g, Vector3(2.9, 0.85, -3.4), "cream")
		if day >= 2:
			for n in 3:
				papers(g, Vector3(1.8 + n * 0.33, 0.86 + n * 0.016, -3.75))
		for light in info.lights:
			light.visible = evening
	else:
		var note := "ЗАПИСЫВАЙ УСЛОВИЯ" if profile.get("verification", -1) == 0 else "ПРОВЕРИМ ВМЕСТЕ" if profile.get("verification", -1) == 1 else "НЕПОДТВЕРЖДЁННОЕ ≠ ЛОЖНОЕ"
		plaque(g, note, Vector3(2.6, 1.82, -0.44), 2.2, "accent_violet")
		if day >= 2:
			g.box(Vector3(8.8, 0.23, -3.9), Vector3(0.8, 0.45, 0.5), "mustard")
			plaque(g, "ЗАЯВКА 014 / ПРИВОД", Vector3(8.5, 1.4, -4.86), 1.6)
			for n in 3:
				g.cylinder(Vector3(8.6 + n * 0.14, 0.49, -3.9), 0.025, 0.36, "steel", Vector3(PI / 2, 0, 0))
		if day == 3:
			g.box(Vector3(-5.0, 0.86, -6.6), Vector3(0.24, 0.025, 0.16), "accent_magenta")
			papers(g, Vector3(-5.8, 0.88, -6.55))
			plaque(g, "Я В СЕКТОРЕ. Н.", Vector3(-5.5, 1.84, -7.05), 1.8, "accent_magenta")
		for i in info.lights.size():
			info.lights[i].light_energy = 0.35 if day == 3 and i == 1 else 1.2
	g.flush()
