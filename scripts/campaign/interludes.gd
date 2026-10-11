extends RefCounted

const Rooms := preload("res://scripts/campaign/rooms.gd")
const City := preload("res://scripts/intro/city.gd")

static func evening(parent: Node3D) -> Dictionary:
	var g := Rooms.geometry(parent)
	Rooms.block(g, Vector3(0, -0.15, 0), Vector3(44, 0.3, 62), "stone")
	g.box(Vector3(-10, 0.014, 0), Vector3(8, 0.025, 62), "asphalt")
	for z in range(-28, 30, 5):
		g.box(Vector3(-10, 0.035, z), Vector3(0.10, 0.02, 2.4), "cream")
	for x in [-14.2, -5.8]:
		Rooms.block(g, Vector3(x, 0.10, 0), Vector3(0.25, 0.2, 62), "concrete")
	# Existing procedural city builders supply the same architectural vocabulary.
	var city := City.new()
	parent.add_child(city)
	city.set("_g", g)
	city.set_process(false)
	city.call("_building", Vector3(16, 0, 19), -PI / 2, 15.0, 10.0, 3, 0, "LATENT SYSTEMS")
	city.call("_building", Vector3(16, 0, -12), -PI / 2, 16.0, 10.0, 2, 2, "КОФЕ / ХЛЕБ")
	for z in [-23, -5, 13]:
		city.call("_building", Vector3(-23, 0, z), PI / 2, 14.0, 10.0, 3, 1, "МАСТЕРСКАЯ")
	for z in [-24, -7, 10, 27]:
		city.call("_lamp", Vector3(-4.8, 0, z), 0.0)
		city.call("_tree", Vector3(1, 0, z), 1.0, true)
	for p in [Vector3(6, 0, -10), Vector3(6, 0, -16), Vector3(3, 0, -21)]:
		city.call("_cafe_table", p, false)
	city.call("_menu_board", Vector3(3, 0, -6), PI)
	city.call("_stop", Vector3(-2.0, 0, -24))
	city.call("_bus", Vector3(-10, 0, -24), -PI / 2)
	city.call("_bench", Vector3(2, 0, 19), -PI / 2)
	city.call("_bin", Vector3(2, 0, 16))
	Rooms.plaque(g, "CENTRAL / 18", Vector3(3, 2.4, -5.7), 2.2, "petrol", PI)
	# Close the short route with architecture, not an invisible open-world promise.
	Rooms.block(g, Vector3(0, 0.65, 30), Vector3(44, 1.3, 0.7), "concrete")
	Rooms.block(g, Vector3(0, 0.65, -31), Vector3(44, 1.3, 0.7), "concrete")
	g.flush()
	var sunset := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 3.0
	disc.height = 6.0
	sunset.mesh = disc
	sunset.position = Vector3(-8, 7, -65)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffd6a2")
	sunset.material_override = glow
	parent.add_child(sunset)
	Rooms.actor(parent, "CafeGuest", Vector3(8, 0, -17), 5, -PI / 2)
	Rooms.actor(parent, "EveningWalker", Vector3(-2.5, 0, 6), 9, PI)
	var cafe_audio := AudioStreamPlayer3D.new()
	cafe_audio.stream = preload("res://assets/audio/intro/cafe_loop.ogg").duplicate()
	cafe_audio.stream.loop = true
	cafe_audio.position = Vector3(7, 1.3, -12)
	cafe_audio.unit_size = 4
	cafe_audio.max_distance = 18
	cafe_audio.volume_db = -14
	parent.add_child(cafe_audio)
	return {"audio": cafe_audio, "sunset": sunset, "actions": {"cafe_sit": Vector3(6, 1, -8.7), "bus_board": Vector3(-8.1, 1.1, -19.4)}, "seat": Vector3(6, -0.45, -8.7)}

static func bus(parent: Node3D) -> Dictionary:
	var g := Rooms.geometry(parent)
	Rooms.block(g, Vector3(0, -0.12, 0), Vector3(2.6, 0.24, 10.4), "petrol")
	g.box(Vector3(0, 2.35, 0), Vector3(2.8, 0.15, 10.6), "cream")
	for x in [-1.35, 1.35]:
		Rooms.block(g, Vector3(x, 0.48, 0), Vector3(0.12, 0.96, 10.5), "wood")
		g.box(Vector3(x, 1.60, 0), Vector3(0.02, 1.2, 10.4), "clear_glass")
		g.box(Vector3(x, 2.22, 0), Vector3(0.14, 0.25, 10.5), "petrol")
		for z in range(-5, 6, 2):
			g.box(Vector3(x, 1.6, z), Vector3(0.15, 1.3, 0.12), "petrol")
		g.cylinder(Vector3(x * 0.65, 2.08, 0), 0.025, 9.8, "mustard", Vector3(PI / 2, 0, 0))
	for z in [-3.3, -1.6, 0.1, 1.8, 3.5]:
		for x in [-0.87, 0.87]:
			g.box(Vector3(x, 0.53, z), Vector3(0.75, 0.12, 0.67), "navy")
			g.box(Vector3(x, 0.98, z + 0.3), Vector3(0.75, 0.95, 0.12), "navy")
			g.box(Vector3(x, 0.25, z), Vector3(0.08, 0.5, 0.4), "steel")
			g.cylinder(Vector3(x * 0.52, 1.28, z + 0.37), 0.025, 2.05, "mustard")
			g.torus(Vector3(x * 0.6, 1.88, z), 0.09, 0.105, "petrol", Vector3(PI / 2, 0, 0))
	Rooms.block(g, Vector3(0, 0.7, -5.1), Vector3(2.7, 1.4, 0.25), "petrol")
	g.box(Vector3(0, 1.75, -5.12), Vector3(2.6, 1.0, 0.025), "clear_glass")
	g.torus(Vector3(-0.8, 1.12, -4.8), 0.17, 0.2, "petrol", Vector3(0.6, 0, 0))
	Rooms.plaque(g, "18 / ПАРКОВАЯ → ДОМ", Vector3(0, 2.05, -4.98), 2.15)
	Rooms.lamp(parent, g, Vector3(0, 2.22, 0), true, 0.55)
	g.flush()
	var scenery: Array[Node3D] = []
	for section in 3:
		var chunk := Node3D.new()
		chunk.position.z = -30 + section * 30
		parent.add_child(chunk)
		var outside := Rooms.geometry(chunk)
		outside.box(Vector3(0, -0.45, 0), Vector3(35, 0.5, 30), "asphalt")
		for side in [-1, 1]:
			outside.box(Vector3(side * 5, -0.15, 0), Vector3(3, 0.15, 30), "stone")
			for n in 4:
				var z := -12.0 + n * 7
				var h := 6.0 + ((section + n) % 3) * 2
				outside.box(Vector3(side * 10, h * 0.5 - 1, z), Vector3(5, h, 5), "concrete" if n % 2 == 0 else "navy")
				for floor_index in 3:
					for column in 3:
						outside.box(Vector3(side * 7.46, floor_index * 1.8 + 0.7, z - 1.6 + column * 1.6), Vector3(0.03, 0.8, 0.75), "sand" if column % 2 == 0 else "petrol")
				outside.cylinder(Vector3(side * 5, 2.2, z), 0.06, 4.6, "petrol")
		outside.flush()
		scenery.append(chunk)
	var audio := AudioStreamPlayer.new()
	audio.stream = preload("res://assets/audio/intro/bus_idle.ogg").duplicate()
	audio.stream.loop = true
	audio.volume_db = -10
	parent.add_child(audio)
	return {"scenery": scenery, "audio": audio, "actions": {}}

static func dream(parent: Node3D) -> Dictionary:
	var g := Rooms.geometry(parent)
	Rooms.block(g, Vector3(0, -0.12, -65), Vector3(5, 0.24, 160), "tile")
	for x in [-2.6, 2.6]:
		Rooms.block(g, Vector3(x, 1.8, -65), Vector3(0.2, 3.6, 160), "concrete")
	g.box(Vector3(0, 3.65, -65), Vector3(5.4, 0.1, 160), "petrol")
	g.flush()
	var frames: Array[Node3D] = []
	for n in 12:
		var frame := Node3D.new()
		frame.position.z = -n * 5.0
		parent.add_child(frame)
		var geo := Rooms.geometry(frame)
		for x in [-2.42, 2.42]:
			geo.box(Vector3(x, 1.8, 0), Vector3(0.15, 3.6, 0.3), "petrol")
			geo.box(Vector3(x * 0.97, 1.35, -1.8), Vector3(0.10, 2.7, 1.5), "navy")
		geo.box(Vector3(0, 3.4, 0), Vector3(4.9, 0.18, 0.3), "cream")
		geo.box(Vector3(0, 3.3, 0), Vector3(1.4, 0.05, 0.15), "white")
		Rooms.plaque(geo, "1406", Vector3(1.98, 2.5, -1.0), 0.65)
		geo.flush()
		frames.append(frame)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2, -8)
	light.omni_range = 32
	light.light_color = Color("e6e2ff")
	light.light_energy = 1.8
	parent.add_child(light)
	var exit := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(5.2, 3.6)
	exit.mesh = plane
	exit.position = Vector3(0, 1.8, -62)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	exit.material_override = material
	parent.add_child(exit)
	return {"frames": frames, "exit": exit, "light": light, "actions": {}}
