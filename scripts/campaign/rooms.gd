extends RefCounted

const Geometry := preload("res://scripts/intro/geometry.gd")
const People := preload("res://scripts/intro/pedestrians.gd")

static func geometry(parent: Node3D) -> Geometry:
	var result := Geometry.new()
	parent.add_child(result)
	return result

static func shell(g: Geometry, half_width: float, half_depth: float) -> void:
	g.box(Vector3(0, -0.13, 0), Vector3(half_width * 2, 0.26, half_depth * 2), "tile")
	g.solid(Vector3(0, -0.13, 0), Vector3(half_width * 2, 0.26, half_depth * 2))
	for x in [-half_width, half_width]:
		g.box(Vector3(x, 1.75, 0), Vector3(0.22, 3.5, half_depth * 2), "cream")
		g.solid(Vector3(x, 1.75, 0), Vector3(0.22, 3.5, half_depth * 2))
	for z in [-half_depth, half_depth]:
		g.box(Vector3(0, 1.75, z), Vector3(half_width * 2, 3.5, 0.22), "cream")
		g.solid(Vector3(0, 1.75, z), Vector3(half_width * 2, 3.5, 0.22))
	for x in [-half_width + 0.18, half_width - 0.18]:
		g.box(Vector3(x, 0.11, 0), Vector3(0.08, 0.22, half_depth * 2), "accent_violet")
	g.box(Vector3(0, 3.48, 0), Vector3(half_width * 2, 0.12, half_depth * 2), "lilac")

static func desk(g: Geometry, p: Vector3, wide := 2.4) -> void:
	g.box(p + Vector3(0, 0.78, 0), Vector3(wide, 0.10, 1.1), "white")
	g.solid(p + Vector3(0, 0.73, 0), Vector3(wide, 0.2, 1.1))
	for x in [-wide * 0.40, wide * 0.40]:
		g.box(p + Vector3(x, 0.35, 0), Vector3(0.08, 0.7, 0.65), "accent_violet")
	g.box(p + Vector3(0, 1.23, -0.23), Vector3(1.08, 0.72, 0.10), "dark")
	g.box(p + Vector3(0, 1.23, -0.16), Vector3(0.99, 0.62, 0.02), "glass")
	g.box(p + Vector3(0, 0.91, -0.23), Vector3(0.12, 0.25, 0.10), "steel")
	g.box(p + Vector3(-0.12, 0.86, 0.30), Vector3(0.65, 0.035, 0.22), "petrol")
	g.box(p + Vector3(0.50, 0.86, 0.32), Vector3(0.10, 0.035, 0.15), "accent_magenta")
	g.box(p + Vector3(0, 0.43, 1.03), Vector3(0.55, 0.12, 0.55), "accent_violet")
	g.box(p + Vector3(0, 0.79, 1.23), Vector3(0.55, 0.66, 0.12), "accent_violet")
	g.cylinder(p + Vector3(0, 0.20, 1.03), 0.08, 0.40, "steel")

static func plant(g: Geometry, p: Vector3, height := 1.2) -> void:
	g.cylinder(p + Vector3(0, 0.20, 0), 0.22, 0.40, "accent_magenta")
	g.cylinder(p + Vector3(0, height * 0.5 + 0.25, 0), 0.035, height, "leaf_dark")
	for n in 5:
		var angle := n * 1.9
		g.ellipsoid(p + Vector3(cos(angle) * 0.22, 0.6 + n * 0.14, sin(angle) * 0.22), Vector3(0.27, 0.14, 0.12), "leaf_light" if n % 2 == 0 else "leaf")

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
	var gate := Node3D.new()
	gate.position = p
	parent.add_child(gate)
	var g := geometry(gate)
	g.box(Vector3(0, 1.30, 0), Vector3(1.8, 2.6, 0.18), "accent_violet")
	g.box(Vector3(0, 1.38, 0.11), Vector3(1.55, 1.22, 0.025), "pane")
	g.box(Vector3(0, 0.57, 0.12), Vector3(1.55, 0.12, 0.04), "mustard")
	g.label("МЕСТНЫЙ ПРИВОД", Vector3(0, 2.20, 0.13), 26, "white", Vector3.ZERO, 0.006)
	g.solid(Vector3(0, 1.30, 0), Vector3(1.8, 2.6, 0.18))
	g.flush()
	return gate

static func set_gate_open(gate: Node3D, opened: bool) -> void:
	gate.position.y = 2.8 if opened else 0.0
	for body in gate.find_children("*", "CollisionShape3D", true, false):
		body.set_deferred("disabled", opened)

static func build_lab(parent: Node3D) -> Dictionary:
	var g := geometry(parent)
	shell(g, 10, 12)
	for x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		g.box(Vector3(x, 0.015, 0), Vector3(0.025, 0.02, 23.5), "lilac")
	for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		g.box(Vector3(0, 0.015, z), Vector3(19.5, 0.02, 0.025), "lilac")
	g.box(Vector3(-2.5, 0.025, 3.0), Vector3(0.14, 0.04, 15), "accent_magenta")
	g.label("LATENT SYSTEMS", Vector3(0, 2.7, -11.85), 50, "accent_violet", Vector3.ZERO, 0.011)
	g.label("WORLD MODELS / ИСПЫТАНИЯ", Vector3(0, 2.1, -11.85), 30, "petrol", Vector3.ZERO, 0.011)
	for x in [-7.0, -3.5, 3.5, 7.0]:
		g.box(Vector3(x, 1.65, -11.82), Vector3(2.6, 1.9, 0.035), "sky")
		g.box(Vector3(x, 1.65, -11.78), Vector3(0.045, 1.9, 0.04), "accent_violet")
		g.box(Vector3(x, 1.65, -11.78), Vector3(2.6, 0.045, 0.04), "accent_violet")
	desk(g, Vector3(2.6, 0, 0))
	g.label("ТВОЁ РАБОЧЕЕ МЕСТО", Vector3(2.6, 1.70, -0.20), 22, "accent_violet", Vector3.ZERO, 0.006)
	desk(g, Vector3(-5.5, 0, -6.8))
	g.label("НИКА ОРЛОВА / QA", Vector3(-5.5, 1.70, -7), 24, "accent_magenta", Vector3.ZERO, 0.006)
	desk(g, Vector3(-5.5, 0, -1.5))
	g.label("ИСТОРИЯ ВЫПУСКА", Vector3(-5.5, 1.70, -1.7), 23, "accent_violet", Vector3.ZERO, 0.006)
	for x in [-8.0, -1.0, 8.2]:
		plant(g, Vector3(x, 0, -10.0))
	g.box(Vector3(-7.9, 0.42, 6.3), Vector3(2.8, 0.84, 0.80), "lilac")
	g.solid(Vector3(-7.9, 0.42, 6.3), Vector3(2.8, 0.84, 0.80))
	g.box(Vector3(-7.9, 1.2, 6.0), Vector3(2.8, 0.65, 0.11), "cream")
	g.cylinder(Vector3(-7.5, 0.89, 6.35), 0.11, 0.13, "accent_magenta")
	g.label("КОФЕ / ПАУЗА", Vector3(-7.9, 1.8, 5.95), 28, "accent_magenta", Vector3.ZERO, 0.008)
	g.box(Vector3(-6.3, 1.35, 11.83), Vector3(1.5, 2.7, 0.08), "accent_violet")
	g.label("ВЫХОД", Vector3(-6.3, 2.92, 11.7), 29, "petrol", Vector3(0, PI, 0), 0.007)
	g.box(Vector3(7.5, 1.3, 11.83), Vector3(1.5, 2.6, 0.08), "petrol")
	g.label("СЛУЖЕБНЫЙ СЕКТОР", Vector3(7.5, 2.90, 11.7), 23, "accent_violet", Vector3(0, PI, 0), 0.006)
	for x in [4.8, 8.5]:
		g.box(Vector3(x, 1.5, -5.0), Vector3(1.8, 3, 0.08), "clear_glass")
		g.solid(Vector3(x, 1.5, -5.0), Vector3(1.8, 3, 0.08))
	g.box(Vector3(5.1, 1.05, -4.75), Vector3(0.32, 0.45, 0.18), "mustard")
	g.label("МЕСТНЫЙ РЕЖИМ", Vector3(5.1, 1.55, -4.62), 23, "petrol", Vector3.ZERO, 0.005)
	g.label("НАБЛЮДАТЕЛЬНЫЙ ПОСТ", Vector3(6.7, 3.0, -4.8), 24, "accent_violet", Vector3.ZERO, 0.007)
	g.flush()
	var gate := sliding_gate(parent, Vector3(6.6, 0, -5))
	set_gate_open(gate, true)
	var nika := actor(parent, "Nika", Vector3(-5.2, 0, -5.3), 2)
	var artem := actor(parent, "Artem", Vector3(6.6, 0, -7), 1)
	return {"gate": gate, "nika": nika, "artem": artem, "actions": {"computer": Vector3(2.6, 1.3, -0.12), "archive": Vector3(-5.5, 1.3, -1.6), "nika": Vector3(-5.2, 1.3, -5.3), "coffee": Vector3(-7.5, 1, 6.35), "exit": Vector3(-6.3, 1.3, 11.6), "service": Vector3(7.5, 1.3, 11.6), "lab_gate": Vector3(5.1, 1.15, -4.65)}}

static func build_home(parent: Node3D) -> Dictionary:
	var g := geometry(parent)
	shell(g, 5, 6)
	g.box(Vector3(0, 0.012, 0), Vector3(9.8, 0.025, 11.8), "wood")
	for x in range(-4, 5):
		g.box(Vector3(x, 0.027, 0), Vector3(0.018, 0.018, 11.8), "lilac")
	g.box(Vector3(-3.7, 0.65, -4.6), Vector3(2.1, 1.3, 0.80), "rose")
	g.box(Vector3(-3.7, 1.35, -4.6), Vector3(2.1, 0.10, 0.90), "cream")
	g.solid(Vector3(-3.7, 0.6, -4.6), Vector3(2.1, 1.2, 0.9))
	g.cylinder(Vector3(-3.35, 1.46, -4.4), 0.10, 0.20, "accent_magenta")
	g.box(Vector3(-4.7, 1.5, -2.4), Vector3(0.3, 3, 1.3), "lilac")
	g.box(Vector3(-4.48, 1.5, -2.4), Vector3(0.05, 2.7, 1.12), "white")
	g.label("НЕ ЗАБЫТЬ КЛЮЧИ", Vector3(-3.9, 2.0, -5.82), 22, "accent_magenta", Vector3.ZERO, 0.006)
	desk(g, Vector3(2.5, 0, -3.8), 2.2)
	g.label("ЛИЧНЫЕ ЗАПИСИ", Vector3(2.5, 1.72, -4), 22, "accent_magenta", Vector3.ZERO, 0.006)
	g.box(Vector3(3.0, 0.40, 3.6), Vector3(2.7, 0.5, 3.4), "accent_violet")
	g.box(Vector3(3.0, 0.75, 3.6), Vector3(2.6, 0.30, 3.3), "cream")
	g.box(Vector3(3.0, 0.96, 3.9), Vector3(2.6, 0.16, 2.5), "rose")
	g.box(Vector3(3.0, 1.00, 2.25), Vector3(1.55, 0.22, 0.6), "lilac")
	g.solid(Vector3(3.0, 0.45, 3.6), Vector3(2.7, 0.9, 3.4))
	g.box(Vector3(-1.0, 0.03, 2.2), Vector3(2.2, 0.05, 4.1), "lilac")
	g.box(Vector3(-3.4, 0.57, 2.3), Vector3(1.0, 1.14, 1.4), "accent_magenta")
	g.box(Vector3(-3.5, 1.38, 2.4), Vector3(0.85, 0.5, 0.10), "rose")
	g.box(Vector3(-3.5, 0.30, 2.95), Vector3(0.80, 0.3, 0.4), "petrol")
	g.box(Vector3(-1.5, 1.4, -5.84), Vector3(2.0, 2.0, 0.025), "navy")
	for x in [-2.1, -1.5, -0.9]:
		g.box(Vector3(x, 1.35, -5.80), Vector3(0.18, 0.65 + absf(x) * 0.10, 0.015), "accent_pink")
	g.label("ВЕЧЕРНИЙ ГОРОД", Vector3(-1.5, 2.18, -5.75), 22, "white", Vector3.ZERO, 0.006)
	plant(g, Vector3(4.2, 0, -5.1), 0.8)
	g.box(Vector3(-1.8, 1.35, 5.83), Vector3(1.4, 2.7, 0.08), "accent_violet")
	g.label("КЛЮЧИ / ПРОПУСК", Vector3(-1.8, 2.86, 5.65), 24, "petrol", Vector3(0, PI, 0), 0.006)
	g.label("ДОМОЙ", Vector3(0.7, 2.7, -5.75), 30, "accent_magenta", Vector3.ZERO, 0.009)
	g.flush()
	return {"actions": {"home_pc": Vector3(2.5, 1.3, -3.9), "bed": Vector3(2.2, 1.0, 2.3), "home_exit": Vector3(-1.8, 1.3, 5.65), "home_coffee": Vector3(-3.35, 1.4, -4.4)}}

static func build_service(parent: Node3D) -> Dictionary:
	var g := geometry(parent)
	shell(g, 6, 7)
	for x in [-3.6, 3.6]:
		for z in [-5.4, -3.4]:
			g.box(Vector3(x, 1.3, z), Vector3(1.4, 2.6, 1.2), "petrol")
			g.solid(Vector3(x, 1.3, z), Vector3(1.4, 2.6, 1.2))
			for y in [0.55, 1.0, 1.45, 1.9, 2.3]:
				g.box(Vector3(x, y, z + 0.63), Vector3(1.15, 0.06, 0.03), "steel")
				g.box(Vector3(x - 0.42, y, z + 0.66), Vector3(0.04, 0.04, 0.035), "cross_green")
	for x in [-3.6, 3.6]:
		g.box(Vector3(x, 1.55, -2), Vector3(4.6, 3.1, 0.12), "clear_glass")
		g.solid(Vector3(x, 1.55, -2), Vector3(4.6, 3.1, 0.12))
	g.box(Vector3(0, 3.15, -2), Vector3(2.5, 0.4, 0.2), "mustard")
	g.label("СЛУЖЕБНЫЙ ШЛЮЗ", Vector3(0, 3.15, -1.85), 26, "petrol", Vector3.ZERO, 0.006)
	g.box(Vector3(-3.7, 1.2, 2.8), Vector3(1.5, 2.4, 0.55), "petrol")
	g.solid(Vector3(-3.7, 1.2, 2.8), Vector3(1.5, 2.4, 0.55))
	g.box(Vector3(-3.7, 1.40, 3.09), Vector3(1.18, 0.83, 0.07), "glass")
	g.box(Vector3(-3.7, 0.80, 3.14), Vector3(0.35, 0.20, 0.08), "mustard")
	g.label("СЕТЬ / МЕСТНЫЙ РЕЖИМ", Vector3(-3.7, 2.6, 3.17), 24, "accent_violet", Vector3.ZERO, 0.006)
	desk(g, Vector3(3.6, 0, 3.0), 2.0)
	g.label("ДОПУСК ЭКСПЛУАТАЦИИ", Vector3(3.6, 1.7, 2.8), 23, "accent_magenta", Vector3.ZERO, 0.005)
	g.box(Vector3(0, 0.06, 1.3), Vector3(1.1, 0.12, 1.1), "mustard")
	g.solid(Vector3(0, 0.06, 1.3), Vector3(1.1, 0.12, 1.1))
	g.box(Vector3(0, 1.05, 0.48), Vector3(0.12, 1.85, 0.12), "steel")
	g.torus(Vector3(0, 1.40, 0.48), 0.16, 0.25, "accent_magenta", Vector3(PI / 2, 0, 0))
	g.label("УДЕРЖАНИЕ ПРИВОДА", Vector3(0, 2.1, 0.87), 23, "petrol", Vector3.ZERO, 0.006)
	g.label("НАГРУЗКА ≥ 5 КГ", Vector3(0, 0.32, 1.61), 20, "petrol", Vector3.ZERO, 0.005)
	g.box(Vector3(-3.4, 0.04, -0.20), Vector3(1.4, 0.08, 1.4), "lilac")
	g.label("КЕРАМИЧЕСКИЙ ГРУЗ / 8 КГ", Vector3(-3.4, 1.7, -0.45), 21, "accent_violet", Vector3.ZERO, 0.005)
	g.label("ВЫХОД НА ЭТАЖ", Vector3(0, 2.7, 6.83), 27, "petrol", Vector3(0, PI, 0), 0.007)
	g.flush()
	var gate := sliding_gate(parent, Vector3(0, 0, -2))
	var exit_gate := sliding_gate(parent, Vector3(0, 0, 6.78))
	exit_gate.rotation.y = PI
	var nika := actor(parent, "NikaInSector", Vector3(0, 0, -4.5), 2)
	var artem := actor(parent, "ArtemAtExit", Vector3(2.0, 0, 5.7), 1, 0)
	var occupancy := geometry(parent).label("ЗАНЯТОСТЬ: 0\nПРОГНОЗ · НЕ НАБЛЮДЕНИЕ", Vector3(2.7, 2.4, -1.84), 24, "accent_magenta", Vector3.ZERO, 0.006)
	return {"gate": gate, "exit_gate": exit_gate, "nika": nika, "artem": artem, "occupancy": occupancy, "actions": {"isolate": Vector3(-3.7, 1.2, 3.2), "permit": Vector3(3.6, 1.3, 2.9), "valve": Vector3(0, 1.3, 0.48), "escape": Vector3(0, 1.3, 6.6), "sector_window": Vector3(2.7, 1.6, -1.8)}}
