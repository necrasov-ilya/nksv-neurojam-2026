extends Node3D
## Independent interior roots; all positions and interaction anchors are local.
const Geometry = preload("res://scripts/intro/geometry.gd")
static var CHAMFERED_SEAT := PackedVector2Array([
	Vector2(-0.23, -0.29), Vector2(0.23, -0.29), Vector2(0.32, -0.19),
	Vector2(0.32, 0.20), Vector2(0.22, 0.29), Vector2(-0.22, 0.29),
	Vector2(-0.32, 0.20), Vector2(-0.32, -0.19)
])
static var BACK_PANEL := PackedVector2Array([
	Vector2(-0.047, 0.0), Vector2(0.047, 0.0),
	Vector2(0.058, 0.50), Vector2(0.035, 0.55),
	Vector2(-0.035, 0.55), Vector2(-0.058, 0.50)
])
static var LEAF_PROFILE := PackedVector2Array([
	Vector2(0.0, 0.0), Vector2(0.13, 0.26), Vector2(0.09, 0.53),
	Vector2(0.0, 0.70), Vector2(-0.09, 0.53), Vector2(-0.13, 0.26)
])
static var DESK_END := PackedVector2Array([
	Vector2(-0.33, 0.0), Vector2(0.33, 0.0), Vector2(0.40, 0.72),
	Vector2(0.30, 0.79), Vector2(-0.30, 0.79), Vector2(-0.40, 0.72)
])
var pedestrian_routes: Array = []
var anchors: Dictionary = {}
var office_door: Node3D
var _g = Geometry.new()

func build_lobby() -> void:
	add_child(_g)
	anchors = {
		"exit": Vector3(0, 1.3, 13),
		"lift": Vector3(0, 1.4, -11),
		"floor14": Vector3(1.25, 1.45, -14.67),
		"reception": Vector3(-8, 1.45, -4.15)
	}
	pedestrian_routes = [
		[Vector3(-2.9, 0, 10), Vector3(-2.9, 0, 2), Vector3(-2.9, 0, -9)],
		[Vector3(4.5, 0, 10), Vector3(4.5, 0, 2), Vector3(4.5, 0, -8)],
		[Vector3(6.2, 0, -7.8), Vector3(9.4, 0, -7.8), Vector3(9.4, 0, -4.3), Vector3(6.2, 0, -4.3), Vector3(6.2, 0, -7.8)]
	]
	_block(Vector3(0, -0.16, -1.5), Vector3(32, 0.32, 33), "cream")
	_block(Vector3(0, 8.16, -1.5), Vector3(32, 0.32, 33), "cream")
	_block(Vector3(0, 4, -18), Vector3(32, 8, 0.35), "cream")
	# Solid wall bays bound opaque window panes: this isolated lobby has no exterior backdrop.
	for side in [-1.0, 1.0]:
		_block(Vector3(side * 16, 0.48, -1.5), Vector3(0.32, 0.96, 33), "concrete")
		_block(Vector3(side * 16, 1.83, -1.5), Vector3(0.32, 1.74, 33), "cream")
		_block(Vector3(side * 16, 6.75, -1.5), Vector3(0.32, 2.5, 33), "cream")
		_block(Vector3(side * 16, 4.1, -16.7), Vector3(0.32, 2.8, 2.6), "cream")
		_block(Vector3(side * 16, 4.1, 14.7), Vector3(0.32, 2.8, 0.6), "cream")
		for bay in [Vector2(-12, 5.2), Vector2(-6, 5.2), Vector2(0, 5.2), Vector2(6, 5.2), Vector2(11.5, 4.2)]:
			_block(Vector3(side * 16, 4.1, bay.x), Vector3(0.10, 2.8, bay.y), "glass")
		for z in [-15.0, -9.0, -3.0, 3.0, 9.0, 14.0]:
			_block(Vector3(side * 16, 4.1, z), Vector3(0.32, 2.8, 0.8), "cream")
			_g.box(Vector3(side * 15.88, 4, z), Vector3(0.2, 6.3, 0.12), "petrol")
			_g.box(Vector3(side * 15.78, 4.05, z + 0.28), Vector3(0.04, 5.4, 0.05), "teal")
		for y in [2.7, 5.5]:
			_g.box(Vector3(side * 15.87, y, -1.5), Vector3(0.18, 0.12, 33), "petrol")
		for z in [-11.0, -3.0, 5.0, 12.0]:
			_column(Vector3(side * 12.5, 0, z))
	# The entrance has an honest four-metre opening, clear of collision.
	for side in [-1.0, 1.0]:
		_block(Vector3(side * 9, 0.48, 15), Vector3(14, 0.96, 0.22), "concrete")
		_block(Vector3(side * 9, 1.83, 15), Vector3(14, 1.74, 0.22), "cream")
		_block(Vector3(side * 9, 6.75, 15), Vector3(14, 2.5, 0.22), "cream")
		for x in [2.4, 9.0, 15.6]:
			_block(Vector3(side * x, 4.1, 15), Vector3(0.8, 2.8, 0.22), "cream")
		for x in [5.7, 12.3]:
			_block(Vector3(side * x, 4.1, 15), Vector3(5.8, 2.8, 0.10), "glass")
			for y in [2.7, 5.5]:
				_g.box(Vector3(side * x, y, 14.83), Vector3(5.8, 0.12, 0.12), "petrol")
		for x in [2.8, 8.6, 9.4, 15.2]:
			_g.box(Vector3(side * x, 4.1, 14.83), Vector3(0.12, 2.8, 0.12), "petrol")
		_block(Vector3(side * 2.1, 1.7, 15), Vector3(0.2, 3.4, 0.35), "petrol")
		_g.box(Vector3(side * 8.9, 3.4, 14.87), Vector3(13.5, 0.16, 0.18), "cream")
	_block(Vector3(0, 5.7, 15), Vector3(4, 4.6, 0.3), "teal")
	_g.label("ВЫХОД · ГОРОД", Vector3(0, 2.95, 14.78), 42, "cream", Vector3(0, PI, 0), 0.007)
	# Flush stone inlay guides the walk without catching the player's feet.
	for x in [-2.4, 2.4]:
		_g.box(Vector3(x, 0.002, 1), Vector3(0.09, 0.004, 26), "mustard")
	for z in range(-16, 15, 3):
		_g.box(Vector3(0, 0.001, z), Vector3(31.5, 0.002, 0.025), "concrete")
	_lobby_finish()
	_reception(Vector3(-8, 0, -5))
	# A quiet west-side waiting nook leaves the reception approach open.
	_sofa(Vector3(-10, 0, 3.5), 0, "teal")
	_coffee_table(Vector3(-10, 0, 1.7))
	_g.box(Vector3(-10, 0.006, 2.8), Vector3(4.4, 0.012, 4.0), "concrete")
	for x in [-11.9, -8.1]:
		_g.box(Vector3(x, 0.014, 2.8), Vector3(0.04, 0.004, 3.6), "cream")
	_wall_art(Vector3(11, 2.4, -11.85), 0, 2.2)
	for z in [3.0, 8.0]:
		_sofa(Vector3(11, 0, z), PI / 2, "teal")
		_sofa(Vector3(7, 0, z), -PI / 2, "brick")
		_coffee_table(Vector3(9, 0, z))
	for p in [Vector3(-11, 0, 8), Vector3(-11, 0, -10), Vector3(11, 0, -9), Vector3(13.6, 0, 0)]:
		_planter(p, 0.8)
	_g.box(Vector3(-8,3.45,-11.78),Vector3(8.5,1.15,0.18),"petrol")
	_g.label("LATENT SYSTEMS",Vector3(-8,3.45,-11.66),64,"cream",Vector3.ZERO,0.008,7.9,0.85)
	_g.label("ЛЮДИ · ИДЕИ · БУДУЩЕЕ",Vector3(-8,2.6,-11.65),34,"petrol",Vector3.ZERO,0.007,6.8,0.3)
	# A suspended coffered canopy, with solid chamfered ribs and warm diffusers.
	for z in [-8.0, 0.0, 8.0]:
		for x in [-6.0, 0.0, 6.0]:
			_g.box(Vector3(x, 7.05, z), Vector3(4.9, 0.22, 3.2), "wood")
			_g.box(Vector3(x, 6.91, z), Vector3(4.35, 0.07, 2.65), "white")
			for dx in [-2.55, 2.55]:
				_g.prism(Vector3(x + dx, 6.83, z), PackedVector2Array([
					Vector2(-0.13, 0), Vector2(0.13, 0), Vector2(0.24, 0.45), Vector2(-0.24, 0.45)
				]), 3.6, "cream")
			for dx in [-1.9, 1.9]:
				_g.cylinder(Vector3(x + dx, 7.6, z), 0.022, 0.8, "petrol")
	_elevator()
	_directory()
	_g.flush()

func _directory() -> void:
	var p := Vector3(6,2.05,-11.87)
	_g.box(p,Vector3(4.8,2.8,0.17),"wood")
	_g.box(p+Vector3(0,0,0.1),Vector3(4.55,2.55,0.045),"cream")
	_g.label("LATENT / ЭТАЖИ",p+Vector3(0,1.05,0.14),36,"petrol",Vector3.ZERO,0.007,4.1,0.3)
	var rows := ["14 · СОБЕСЕДОВАНИЯ","01 · ПРИЁМ ПОСЕТИТЕЛЕЙ","06 · ИССЛЕДОВАНИЯ","12 · WORLD MODELS","18 · ПРОЕКТИРОВАНИЕ"]
	for i in rows.size():
		var y := 0.6-float(i)*0.36
		_g.box(p+Vector3(0,y,0.15),Vector3(4.3,0.3,0.025),"petrol" if i == 0 else "white")
		_g.label(rows[i],p+Vector3(0,y,0.175),28,"cream" if i == 0 else "petrol",Vector3.ZERO,0.005,4.0,0.23)

func build_office() -> void:
	add_child(_g)
	anchors = {
		"office_door": Vector3(3.4, 1.4, -14),
		"computer": Vector3(10, 1.25, -18.7),
		"lift_return": Vector3(0, 1.4, 10)
	}
	pedestrian_routes = [
		[Vector3(-1.6, 0, 6), Vector3(-1.6, 0, -5), Vector3(-1.6, 0, -18)],
		[Vector3(1.8, 0, 4), Vector3(1.8, 0, -8), Vector3(1.8, 0, -18)]
	]
	# The principal six-metre corridor has a one-metre recessed east threshold.
	_block(Vector3(0.5, -0.14, -5), Vector3(7, 0.28, 34), "cream")
	_block(Vector3(0.5, 3.74, -5), Vector3(7, 0.28, 34), "cream")
	_block(Vector3(-3.18, 1.8, -5), Vector3(0.36, 3.6, 34), "cream")
	_block(Vector3(0.5, 1.8, -22.18), Vector3(7, 3.6, 0.36), "teal")
	_block(Vector3(0.5, 1.8, 12.18), Vector3(7, 3.6, 0.36), "cream")
	# East wall segments end at the 1406 doorway: no hidden solid across it.
	_block(Vector3(4, 1.8, -18.5), Vector3(0.3, 3.6, 7), "cream")
	_block(Vector3(4, 1.8, -0.5), Vector3(0.3, 3.6, 25), "cream")
	_block(Vector3(4, 3.15, -14), Vector3(0.3, 0.9, 2), "cream")
	for side in [-1.0, 1.0]:
		var x := -2.95 if side < 0 else 3.8
		var trim_segments := [Vector2(-5, 34)] if side < 0 else [Vector2(-18.59, 6.82), Vector2(-0.41, 24.82)]
		for segment in trim_segments:
			_g.box(Vector3(x, 0.14, segment.x), Vector3(0.06, 0.28, segment.y), "petrol")
			_g.box(Vector3(x, 1.05, segment.x), Vector3(0.07, 0.07, segment.y), "wood")
		_g.box(Vector3(x, 3.3, -5), Vector3(0.09, 0.12, 34), "petrol")
	for z in [6.0, -2.0, -10.0, -18.0]:
		_g.box(Vector3(0.3, 3.5, z), Vector3(2.5, 0.13, 1.2), "petrol")
		_g.box(Vector3(0.3, 3.42, z), Vector3(2.25, 0.035, 0.96), "white")
		_g.box(Vector3(-2.90, 2.0, z - 3.4), Vector3(0.10, 0.72, 1.1), "wood")
		_g.box(Vector3(-2.84, 2.0, z - 3.4), Vector3(0.025, 0.60, 0.98), "white")
		for line_index in 3:
			_g.box(Vector3(-2.82, 2.14 - line_index * 0.14, z - 3.4), Vector3(0.015, 0.035, 0.65 - line_index * 0.12), "teal")
		for x in [-1.0, 2.0]:
			_g.box(Vector3(x, 0.002, z), Vector3(0.045, 0.004, 7), "mustard")
	# Recessed acoustic wall bays stay entirely outside the walking strip.
	for z in [0.0, -8.0, -16.0]:
		_g.box(Vector3(-2.90, 1.82, z), Vector3(0.075, 1.2, 2.3), "wood")
		for rib in 9:
			_g.box(Vector3(-2.84, 1.82, z - 1.04 + rib * 0.26), Vector3(0.055, 1.12, 0.055), "cream")
		_g.box(Vector3(-2.82, 2.52, z), Vector3(0.10, 0.09, 2.45), "petrol")
	for z in range(-20, 12, 4):
		_g.box(Vector3(0.4, 0.008, z), Vector3(6.6, 0.012, 0.022), "concrete")
	for index in range(5):
		var east := index % 2 == 1
		var z := 4.0 - float(index >> 1) * 8.0
		_corridor_door(Vector3(3.80 if east else -2.95, 0, z), 1401 + index, east)
	_g.box(Vector3(0, 1.55, 11.92), Vector3(2.3, 3.1, 0.15), "petrol")
	for x in [-0.57, 0.57]:
		_g.box(Vector3(x, 1.4, 11.82), Vector3(1.10, 2.8, 0.08), "concrete")
	_g.box(Vector3(0, 2.96, 11.7), Vector3(1.2, 0.32, 0.10), "dark")
	_g.label("14", Vector3(0, 2.96, 11.63), 40, "mustard", Vector3(0, PI, 0), 0.006)
	_g.label("ЛИФТ · 1 ЭТАЖ", Vector3(0, 1.9, 11.70), 36, "cream", Vector3(0, PI, 0), 0.005)
	_g.box(Vector3(1.55, 1.35, 11.7), Vector3(0.24, 0.5, 0.08), "dark")
	_g.cylinder(Vector3(1.55, 1.35, 11.64), 0.07, 0.04, "mustard", Vector3(PI / 2, 0, 0))
	_g.box(Vector3(0.5, 2.55, -21.95), Vector3(2.9, 0.7, 0.10), "petrol")
	_g.label("14 / СОБЕСЕДОВАНИЯ", Vector3(0.5, 2.55, -21.88), 40, "cream", Vector3.ZERO, 0.005)
	_planter(Vector3(-2.15, 0, -20.5), 0.45)
	_office_room()
	_office_hinged_door()
	_g.flush()

func _block(p: Vector3, size: Vector3, color: String) -> void:
	_g.box(p, size, color)
	_g.solid(p, size)

func _column(p: Vector3) -> void:
	_g.cylinder(p + Vector3(0, 0.15, 0), 0.76, 0.3, "petrol")
	_g.cylinder(p + Vector3(0, 3.9, 0), 0.53, 7.5, "cream")
	_g.cylinder(p + Vector3(0, 7.65, 0), 0.80, 0.3, "cream")
	_g.cylinder(p + Vector3(0, 0.43, 0), 0.57, 0.18, "mustard")
	_g.solid(p + Vector3(0, 4, 0), Vector3(1.06, 8, 1.06))
	for a in range(10):
		var angle := float(a) * TAU / 10.0
		_g.cylinder(p + Vector3(cos(angle) * 0.525, 4, sin(angle) * 0.525), 0.022, 6.8, "white")

func _reception(p: Vector3) -> void:
	_g.prism(p, PackedVector2Array([
		Vector2(-3.8, 0.12), Vector2(3.8, 0.12), Vector2(3.65, 1.10),
		Vector2(3.45, 1.25), Vector2(-3.45, 1.25), Vector2(-3.65, 1.10)
	]), 1.5, "wood")
	_g.solid(p + Vector3(0, 0.6, 0), Vector3(7.6, 1.2, 1.5))
	_g.box(p + Vector3(0, 1.28, 0), Vector3(7.8, 0.12, 1.7), "cream")
	for x in range(-3, 4):
		_g.box(p + Vector3(x, 0.68, 0.76), Vector3(0.52, 0.85, 0.07), "teal")
		_g.box(p + Vector3(x, 0.25, 0.82), Vector3(0.04, 0.22, 0.06), "mustard")
	# Raised light plaque clears the alternating front panels.
	_g.box(p + Vector3(0, 0.86, 0.845), Vector3(3.30, 0.56, 0.065), "petrol")
	_g.box(p + Vector3(0, 0.86, 0.882), Vector3(3.14, 0.42, 0.016), "cream")
	var plaque := _g.label("РЕСЕПШЕН", p + Vector3(0, 0.86, 0.899), 48, "petrol", Vector3.ZERO, 0.007, 2.95, 0.32)
	plaque.name = "ReceptionDeskPlaque"
	plaque.no_depth_test = false
	_g.box(p + Vector3(0, 0.39, 0.825), Vector3(6.85, 0.035, 0.025), "white")
	# Overhead marker makes the destination readable from the entrance.
	for x in [-2.0, 2.0]:
		_g.cylinder(p + Vector3(x, 5.73, -0.1), 0.018, 2.54, "petrol")
	_g.box(p + Vector3(0, 4.02, -0.1), Vector3(5.4, 0.84, 0.16), "petrol")
	_g.box(p + Vector3(0, 4.02, -0.005), Vector3(5.18, 0.62, 0.024), "cream")
	var marker := _g.label("РЕСЕПШЕН", p + Vector3(0, 4.02, 0.018), 64, "petrol", Vector3.ZERO, 0.009, 4.85, 0.46)
	marker.name = "ReceptionOverheadSign"
	marker.no_depth_test = false
	var light := OmniLight3D.new()
	light.name = "ReceptionAccentLight"
	light.position = p + Vector3(0, 2.6, 1.1)
	light.light_color = Color("eee8ff")
	light.light_energy = 0.65
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)
	_g.box(p + Vector3(0,1.46,0.38),Vector3(1.65,0.3,0.09),"petrol")
	_g.label("ПРИЁМ ПОСЕТИТЕЛЕЙ",p + Vector3(0,1.46,0.44),28,"cream",Vector3.ZERO,0.005,1.45,0.2)
	for x in [-2.2, 2.2]:
		_g.box(p + Vector3(x, 1.58, -0.28), Vector3(0.8, 0.47, 0.09), "dark")
		_g.box(p + Vector3(x, 1.58, -0.22), Vector3(0.69, 0.36, 0.025), "teal")
		_g.cylinder(p + Vector3(x, 1.36, -0.28), 0.055, 0.14, "petrol")
		_g.box(p + Vector3(x, 1.35, -0.28), Vector3(0.4, 0.03, 0.23), "petrol")
		_chair(p + Vector3(x, 0, -1.75), 0)
	_g.box(p + Vector3(1, 1.36, 0.45), Vector3(0.65, 0.045, 0.42), "brick")
	_g.box(p + Vector3(1, 1.39, 0.45), Vector3(0.58, 0.018, 0.36), "cream")
	_g.cylinder(p + Vector3(-0.9, 1.40, 0.35), 0.10, 0.14, "petrol")
	for x in [-0.94, -0.89, -0.85]:
		_g.cylinder(p + Vector3(x, 1.52, 0.35), 0.008, 0.24, "mustard")

	# Counter returns, a recessed toe kick, and small task lamps give depth.
	_g.box(p + Vector3(0, 0.14, 0.78), Vector3(7.05, 0.18, 0.09), "petrol")
	for x in [-3.55, 3.55]:
		_g.box(p + Vector3(x, 0.76, 0.05), Vector3(0.10, 1.02, 1.52), "cream")
	for x in [-2.95, 2.95]:
		_g.cylinder(p + Vector3(x, 1.36, -0.12), 0.15, 0.045, "petrol")
		_rod(p + Vector3(x, 1.38, -0.12), p + Vector3(x, 1.9, -0.12), 0.021, "petrol")
		_g.cone(p + Vector3(x, 1.93, -0.12), 0.24, 0.22, "cream")
		_g.cylinder(p + Vector3(x, 1.816, -0.12), 0.18, 0.015, "white")
	_g.box(p + Vector3(-0.1, 1.365, -0.36), Vector3(0.72, 0.04, 0.44), "petrol")
	for row in 3:
		for key in 10:
			_g.box(p + Vector3(-0.40 + key * 0.066, 1.394, -0.48 + row * 0.105), Vector3(0.05, 0.018, 0.07), "cream")

func _lobby_finish() -> void:
	# Large stone fields with a slim perimeter reveal, not tiled cube carpeting.
	for side in [-1.0, 1.0]:
		_g.box(Vector3(side * 15.7, 0.19, -1.5), Vector3(0.13, 0.38, 32.5), "petrol")
		_g.box(Vector3(side * 15.7, 7.1, -1.5), Vector3(0.20, 0.18, 32.5), "wood")
		_g.box(Vector3(side * 14.0, 0.008, -1.0), Vector3(0.07, 0.012, 30), "wood")
		for z in [-10.0, 0.0, 10.0]:
			_g.box(Vector3(side * 8.5, 0.009, z), Vector3(10.4, 0.012, 0.055), "wood")
	# Timber reception backdrop has deep alternating fins and a stone lower rail.
	_g.box(Vector3(-8, 0.3, -11.87), Vector3(8.6, 0.6, 0.19), "petrol")
	_g.box(Vector3(-8, 1.65, -11.90), Vector3(8.5, 2.05, 0.12), "wood")
	for rib in 23:
		var x := -12.03 + rib * 0.365
		_g.box(Vector3(x, 1.65, -11.79), Vector3(0.08, 1.95, 0.12), "cream")
	_g.box(Vector3(-8, 4.32, -11.84), Vector3(8.7, 0.16, 0.27), "wood")
	_g.box(Vector3(-8, 4.22, -11.68), Vector3(8.3, 0.025, 0.10), "white")
	# Low-glare spun shades hang above seating, leaving the lift axis unobstructed.
	for z in [3.0, 8.0]:
		_g.cylinder(Vector3(9, 5.18, z), 0.024, 3.6, "petrol")
		_g.cone(Vector3(9, 3.38, z), 0.63, 0.55, "cream")
		_g.cylinder(Vector3(9, 3.092, z), 0.53, 0.035, "white")
		_g.cylinder(Vector3(9, 3.075, z), 0.20, 0.035, "mustard")
	# Sculptural ceramic vessel and a few quiet objects on the waiting tables.
	_g.ellipsoid(Vector3(-10.35, 0.66, 1.72), Vector3(0.19, 0.27, 0.19), "AC2954")
	_g.cylinder(Vector3(-10.35, 0.80, 1.72), 0.047, 0.055, "cream")
	_rod(Vector3(-10.35, 0.82, 1.72), Vector3(-10.28, 1.17, 1.74), 0.009, "leaf")
	_g.ellipsoid(Vector3(-10.25, 1.14, 1.74), Vector3(0.11, 0.18, 0.055), "leaf")

func _window_view() -> void:
	# Independent, actual roof volumes beyond the fourteenth-floor glazing.
	# Tops sit below or close to eye level, keeping a broad morning-sky view.
	var rooftops := [
		Vector4(-5, -36, 9, 0.2), Vector4(6, -43, 8, 1.5),
		Vector4(17, -35, 7, -0.5), Vector4(27, -48, 11, 2.2),
		Vector4(-16, -55, 12, 2.8), Vector4(9, -65, 10, 3.1)
	]
	for index in rooftops.size():
		var roof: Vector4 = rooftops[index]
		var depth := 8.0 + float(index % 3) * 2.0
		var color := "concrete" if index % 2 == 0 else "cream"
		_g.box(Vector3(roof.x, roof.w - 9, roof.y), Vector3(roof.z, 18, depth), color)
		_g.box(Vector3(roof.x, roof.w + 0.08, roof.y), Vector3(roof.z + 0.18, 0.16, depth + 0.18), "petrol")
		for side in [-1.0, 1.0]:
			_g.box(Vector3(roof.x + side * roof.z * 0.48, roof.w + 0.3, roof.y), Vector3(0.18, 0.46, depth), color)
		_g.box(Vector3(roof.x, roof.w + 0.3, roof.y + depth * 0.48), Vector3(roof.z, 0.46, 0.18), color)
		_g.box(Vector3(roof.x + roof.z * 0.2, roof.w + 0.55, roof.y - 1), Vector3(2.4, 1.0, 1.5), "concrete")
		for slat in 5:
			_g.box(Vector3(roof.x + roof.z * 0.2 - 0.8 + slat * 0.4, roof.w + 0.65, roof.y - 0.23), Vector3(0.08, 0.50, 0.045), "petrol")
		for floor_index in 4:
			for bay in 4:
				var x := roof.x + (float(bay) - 1.5) * roof.z * 0.21
				_g.box(Vector3(x, roof.w - 1.5 - floor_index * 2.7, roof.y + depth * 0.5 + 0.035), Vector3(roof.z * 0.13, 1.45, 0.045), "glass")
				_g.box(Vector3(x, roof.w - 2.27 - floor_index * 2.7, roof.y + depth * 0.5 + 0.07), Vector3(roof.z * 0.15, 0.10, 0.10), "petrol")
		_rod(Vector3(roof.x - 1.5, roof.w + 0.18, roof.y), Vector3(roof.x - 1.5, roof.w + 1.7, roof.y), 0.025, "petrol")
		_rod(Vector3(roof.x - 2.0, roof.w + 1.45, roof.y), Vector3(roof.x - 1.0, roof.w + 1.45, roof.y), 0.018, "petrol")

func _sofa(p: Vector3, angle: float, color: String) -> void:
	var b := Basis(Vector3.UP, angle)
	var sideways := absf(sin(angle)) > 0.7
	for x in [-1.25, 1.25]:
		for z in [-0.32, 0.32]:
			_g.cylinder(p + b * Vector3(x, 0.14, z), 0.055, 0.28, "petrol")
	_g.box(p + Vector3(0, 0.29, 0), Vector3(3.1, 0.24, 0.95), "wood", Vector3(0, angle, 0))
	# Rounded upholstery rests on a separate timber frame, not a stack of blocks.
	for x in [-0.96, 0.0, 0.96]:
		_g.ellipsoid(p + b * Vector3(x, 0.51, -0.06), Vector3(0.84, 0.29, 0.94) if sideways else Vector3(0.94, 0.29, 0.84), color)
		_g.ellipsoid(p + b * Vector3(x, 0.86, 0.35), Vector3(0.29, 0.68, 0.95) if sideways else Vector3(0.95, 0.68, 0.29), color)
		_g.box(p + b * Vector3(x, 0.40, -0.45), Vector3(0.77, 0.025, 0.025), "cream", Vector3(0, angle, 0))
	for x in [-1.53, 1.53]:
		_g.ellipsoid(p + b * Vector3(x, 0.68, 0), Vector3(1.02, 0.66, 0.28) if sideways else Vector3(0.28, 0.66, 1.02), color)
		_g.box(p + b * Vector3(x, 0.36, 0), Vector3(0.17, 0.14, 0.85), "wood", Vector3(0, angle, 0))
	for x in [-0.94, 0.94]:
		_g.ellipsoid(p + b * Vector3(x, 0.78, 0.09), Vector3(0.17, 0.45, 0.43) if sideways else Vector3(0.43, 0.45, 0.17), "cream" if x < 0 else "AC2954")
	_g.solid(p + Vector3(0, 0.58, 0), Vector3(1.1, 1.16, 3.4) if absf(angle) > 1 else Vector3(3.4, 1.16, 1.1))

func _coffee_table(p: Vector3) -> void:
	_g.cylinder(p + Vector3(0, 0.47, 0), 0.82, 0.09, "wood")
	_g.cylinder(p + Vector3(0, 0.21, 0), 0.095, 0.42, "petrol")
	_g.cylinder(p + Vector3(0, 0.045, 0), 0.48, 0.09, "petrol")
	_g.solid(p + Vector3(0, 0.26, 0), Vector3(1.6, 0.52, 1.6))
	_g.box(p + Vector3(0.1, 0.54, 0.0), Vector3(0.48, 0.04, 0.34), "cream", Vector3(0, 0.2, 0))
	_g.box(p + Vector3(0.05, 0.58, 0.03), Vector3(0.43, 0.035, 0.3), "teal", Vector3(0, -0.1, 0))
	_g.cylinder(p + Vector3(-0.36, 0.59, -0.18), 0.08, 0.16, "cream")

func _planter(p: Vector3, radius: float) -> void:
	_g.cylinder(p + Vector3(0, 0.29, 0), radius * 0.88, 0.58, "cream")
	_g.cylinder(p + Vector3(0, 0.065, 0), radius * 0.69, 0.09, "petrol")
	_g.cylinder(p + Vector3(0, 0.59, 0), radius * 0.94, 0.10, "cream")
	_g.cylinder(p + Vector3(0, 0.647, 0), radius * 0.83, 0.018, "wood")
	_g.solid(p + Vector3(0, 0.32, 0), Vector3(radius * 1.8, 0.64, radius * 1.8))
	for i in range(9):
		var angle := float(i) * TAU / 9.0
		var tip := p + Vector3(cos(angle) * radius * 0.6, 1.0 + float(i % 3) * 0.27, sin(angle) * radius * 0.6)
		_rod(p + Vector3(0, 0.65, 0), tip, 0.018, "leaf")
		var orientation := Vector3(0.28 + float(i % 2) * 0.20, angle, 0.4)
		_g.ellipsoid(tip + Vector3(0, 0.24, 0), Vector3(radius * 0.42, 0.76, 0.10), "leaf" if i % 2 == 0 else "teal")
		_g.prism(tip + Vector3(0, 0.01, 0), LEAF_PROFILE, 0.028, "leaf", orientation)

func _elevator() -> void:
	# The landing wall and shaft continue through the lobby ceiling; the lower
	# cabin ceiling is an interior fit-out, not the top of the elevator core.
	var core_top := 8.32
	var cabin_wall_top := 3.1
	var landing_header_bottom := 3.5
	for side in [-1.0, 1.0]:
		_block(Vector3(side * 9, core_top * 0.5, -12.25), Vector3(14.4, core_top, 0.6), "cream")
		_g.box(Vector3(side * 1.3, 1.55, -11.92), Vector3(0.38, 3.1, 0.32), "petrol")
		_g.box(Vector3(side * 1.4, 1.4, -12.38), Vector3(0.3, 2.8, 0.07), "concrete")
		_block(Vector3(side * 1.6, 1.55, -14.75), Vector3(0.2, 3.1, 5.3), "concrete")
		_block(Vector3(side * 1.6, (cabin_wall_top + core_top) * 0.5, -14.75), Vector3(0.2, core_top - cabin_wall_top, 5.3), "concrete")
		_g.box(Vector3(side * 1.48, 0.3, -14.75), Vector3(0.06, 0.16, 5), "dark")
		_g.box(Vector3(side * 1.48, 2.8, -14.75), Vector3(0.06, 0.08, 5), "cream")
		for z in [-13.0, -14.4, -15.8, -17.1]:
			_g.box(Vector3(side * 1.48, 1.8, z), Vector3(0.035, 1.75, 0.035), "cream")
		_rod(Vector3(side * 1.35, 0.95, -13), Vector3(side * 1.35, 0.95, -17), 0.035, "petrol")
	_block(Vector3(0, 3.25, -12.1), Vector3(3.6, 0.5, 0.7), "petrol")
	_block(Vector3(0, (landing_header_bottom + core_top) * 0.5, -12.25), Vector3(3.6, core_top - landing_header_bottom, 0.6), "cream")
	_block(Vector3(0, 1.55, -17.5), Vector3(3.4, 3.1, 0.2), "concrete")
	_block(Vector3(0, (cabin_wall_top + core_top) * 0.5, -17.5), Vector3(3.4, core_top - cabin_wall_top, 0.2), "concrete")
	_block(Vector3(0, 3.16, -14.8), Vector3(3.4, 0.22, 5.6), "cream")
	_g.box(Vector3(0, 3.01, -15.0), Vector3(2.55, 0.07, 3.8), "white")
	_g.box(Vector3(0, 0.001, -14.8), Vector3(3.1, 0.002, 5.4), "road")
	_g.box(Vector3(0, 0.002, -12), Vector3(2.2, 0.004, 0.32), "mustard")
	_rod(Vector3(-1.3, 0.95, -17.32), Vector3(1.3, 0.95, -17.32), 0.035, "petrol")
	for x in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		_g.box(Vector3(x, 1.7, -17.37), Vector3(0.025, 2.35, 0.035), "cream")
	# Brushed-metal lower panels and a clear, softly colored rear inset.
	_g.box(Vector3(0, 1.94, -17.34), Vector3(2.55, 1.53, 0.035), "teal")
	_g.box(Vector3(0, 1.94, -17.31), Vector3(2.35, 1.33, 0.025), "cream")
	_g.box(Vector3(0, 0.42, -17.34), Vector3(2.65, 0.43, 0.035), "petrol")
	_g.label("LATENT SYSTEMS", Vector3(0, 1.8, -17.28), 32, "petrol", Vector3.ZERO, 0.004, 2.05, 0.3)
	_g.box(Vector3(0, 3.67, -11.87), Vector3(3.5, 0.75, 0.12), "petrol")
	_g.label("ЛИФТ / 14", Vector3(0, 3.67, -11.77), 52, "cream", Vector3.ZERO, 0.007)
	_g.box(Vector3(0, 2.92, -11.75), Vector3(0.62, 0.25, 0.08), "dark")
	_g.label("1", Vector3(0, 2.92, -11.69), 32, "mustard", Vector3.ZERO, 0.005)
	_g.box(Vector3(1.43,1.53,-14.66),Vector3(0.13,1.65,1.16),"petrol")
	_g.box(Vector3(1.35,1.53,-14.66),Vector3(0.035,1.5,1.04),"wood")
	for index in 22:
		var floor_number := 22-index
		var row := index/4
		var column := index%4
		var p := Vector3(1.31,2.07-float(row)*0.22,-15.05+float(column)*0.26)
		_g.cylinder(p,0.075,0.07,"mustard" if floor_number == 14 else "concrete",Vector3(0,0,PI/2))
		_g.label(str(floor_number),p+Vector3(-0.047,0,0),22,"dark",Vector3(0,-PI/2,0),0.0038,0.115,0.1)
	_g.label("ЭТАЖИ 1–22",Vector3(1.32,2.34,-14.66),30,"cream",Vector3(0,-PI/2,0),0.004,0.9,0.15)
	# Raised button bezels, tactile dots, and a restrained selected-floor marker.
	for index in 22:
		var row := index / 4
		var column := index % 4
		var p := Vector3(1.26, 2.07 - float(row) * 0.22, -15.05 + float(column) * 0.26)
		for dot in 2:
			_g.ellipsoid(p + Vector3(-0.008, -0.064, -0.022 + dot * 0.042), Vector3(0.012, 0.012, 0.012), "cream")
	_g.box(Vector3(1.30, 1.64, -15.155), Vector3(0.025, 0.14, 0.025), "AC2954")
	for z in [-13.0, -17.0]:
		_g.box(Vector3(0, 2.99, z), Vector3(2.7, 0.06, 0.20), "petrol")
		_g.box(Vector3(0, 2.947, z), Vector3(2.45, 0.018, 0.10), "white")
	for side in [-1.0, 1.0]:
		for z in [-13.1, -16.7]:
			_rod(Vector3(side * 1.48, 0.95, z), Vector3(side * 1.35, 0.95, z), 0.035, "petrol")
	for z in [-12.16, -12.04, -11.92]:
		_g.box(Vector3(0, 0.009, z), Vector3(2.16, 0.012, 0.018), "petrol")
	_g.label("СОБЕСЕДОВАНИЯ", Vector3(0, 2.25, -17.28), 34, "petrol", Vector3.ZERO, 0.004, 2.15, 0.25)

func _corridor_door(p: Vector3, number: int, east: bool) -> void:
	var angle := -PI / 2 if east else PI / 2
	_g.box(p + Vector3(0, 1.35, 0), Vector3(0.09, 2.7, 1.45), "wood")
	for z in [-0.79, 0.79]:
		_g.box(p + Vector3(0, 1.43, z), Vector3(0.15, 2.86, 0.11), "petrol")
	_g.box(p + Vector3(0, 2.83, 0), Vector3(0.15, 0.12, 1.7), "petrol")
	var visible_x := p.x - 0.085 if east else p.x + 0.085
	_g.box(Vector3(visible_x, 2.16, p.z), Vector3(0.04, 0.3, 0.7), "cream")
	_g.label(str(number), Vector3(visible_x - 0.03 if east else visible_x + 0.03, 2.16, p.z), 40, "petrol", Vector3(0, angle, 0), 0.005)
	_g.box(Vector3(visible_x, 1.05, p.z + 0.5), Vector3(0.08, 0.05, 0.22), "mustard")

func _office_room() -> void:
	_block(Vector3(9.5, -0.14, -15.5), Vector3(11, 0.28, 13), "wood")
	_block(Vector3(9.5, 3.74, -15.5), Vector3(11, 0.28, 13), "cream")
	_block(Vector3(9.5, 1.8, -9), Vector3(11, 3.6, 0.3), "cream")
	_block(Vector3(9.5, 0.48, -22), Vector3(11, 0.96, 0.3), "teal")
	_block(Vector3(9.5, 3.24, -22), Vector3(11, 0.72, 0.3), "cream")
	_block(Vector3(9.5, 1.94, -22), Vector3(11, 1.96, 0.10), "clear_glass")
	_block(Vector3(15, 1.8, -15.5), Vector3(0.30, 3.6, 13), "cream")
	for x in [4.3, 6.5, 8.7, 10.9, 13.1, 14.7]:
		_g.box(Vector3(x, 1.94, -21.85), Vector3(0.08, 2.02, 0.17), "petrol")
	_g.box(Vector3(9.5, 0.96, -21.72), Vector3(10.7, 0.10, 0.45), "cream")
	_g.box(Vector3(9.5, 2.72, -21.82), Vector3(10.7, 0.06, 0.10), "cream")
	_window_view()
	for z in [-9.25, -21.75]:
		_g.box(Vector3(9.5, 0.13, z), Vector3(10.5, 0.24, 0.06), "petrol")
		_g.box(Vector3(9.5, 3.45, z), Vector3(10.5, 0.10, 0.08), "wood")
	_g.box(Vector3(14.79, 0.13, -15.5), Vector3(0.06, 0.24, 12.4), "petrol")
	_g.box(Vector3(14.79, 3.45, -15.5), Vector3(0.08, 0.10, 12.4), "wood")
	for x in [5.1, 14.15]:
		_g.box(Vector3(x, 1.89, -21.63), Vector3(0.72, 2.1, 0.18), "mustard")
		for rib in range(7):
			_g.box(Vector3(x - 0.3 + rib * 0.1, 1.89, -21.5), Vector3(0.04, 2.1, 0.06), "cream")
	for x in range(5, 15):
		_g.box(Vector3(x, 0.001, -15.5), Vector3(0.025, 0.002, 12.6), "cream")
	_g.box(Vector3(10, 3.44, -16), Vector3(2.7, 0.13, 1.1), "petrol")
	_g.box(Vector3(10, 3.35, -16), Vector3(2.5, 0.04, 0.9), "white")
	_desk(Vector3(10, 0, -19.25))
	_chair(Vector3(10, 0, -17.1), 0)
	_computer()
	_coat_rack(Vector3(13.7, 0, -10.4))
	_planter(Vector3(5.2, 0, -20.3), 0.55)
	# Low sideboard: drawers, pulls, paper trays, and a physical desk clock.
	_block(Vector3(13.85, 0.45, -15), Vector3(1.65, 0.9, 2.5), "wood")
	_g.box(Vector3(13.85, 0.94, -15), Vector3(1.8, 0.08, 2.65), "cream")
	for z in [-15.8, -15.0, -14.2]:
		_g.box(Vector3(12.995, 0.48, z), Vector3(0.045, 0.72, 0.72), "teal")
		_g.box(Vector3(12.94, 0.62, z), Vector3(0.07, 0.035, 0.27), "mustard")
	for y in [1.04, 1.11, 1.18]:
		_g.box(Vector3(13.8, y, -15.7), Vector3(0.5, 0.035, 0.7), "petrol")
		_g.box(Vector3(13.8, y + 0.025, -15.7), Vector3(0.43, 0.015, 0.62), "cream")
	# The complete clock shares one frame; its dial faces -X into the room.
	var clock = Geometry.new()
	clock.name = "OfficeDeskClock"
	clock.position = Vector3(13.8, 1.25, -14.3)
	clock.rotation.y = -PI / 2
	add_child(clock)
	clock.cylinder(Vector3.ZERO, 0.25, 0.12, "mustard", Vector3(PI / 2, 0, 0))
	clock.cylinder(Vector3(0, 0, 0.074), 0.21, 0.02, "cream", Vector3(PI / 2, 0, 0))
	clock.box(Vector3(0, 0.068, 0.096), Vector3(0.015, 0.145, 0.012), "petrol")
	clock.box(Vector3(0.064, 0, 0.096), Vector3(0.14, 0.015, 0.012), "petrol")
	clock.cylinder(Vector3(0, 0, 0.101), 0.023, 0.012, "petrol", Vector3(PI / 2, 0, 0))
	clock.box(Vector3(0, -0.27, 0), Vector3(0.34, 0.08, 0.20), "petrol")
	clock.flush()
	# The south wall is a furnished waiting area, not a second interaction task.
	_sofa(Vector3(9.5, 0, -10.05), 0, "teal")
	_wall_art(Vector3(9.5, 2.4, -9.20), PI, 2.3)
	_bookcase(Vector3(14.1, 0, -18.9), -PI / 2)
	_g.box(Vector3(10, 0.008, -17.2), Vector3(4.3, 0.012, 3.3), "concrete")
	for x in [8.05, 11.95]:
		_g.box(Vector3(x, 0.016, -17.2), Vector3(0.045, 0.004, 2.95), "cream")

func _wall_art(p: Vector3, angle: float, width: float) -> void:
	var b := Basis(Vector3.UP, angle)
	_g.box(p, Vector3(width, 1.45, 0.08), "wood", Vector3(0, angle, 0))
	_g.box(p + b * Vector3(0, 0, 0.055), Vector3(width - 0.14, 1.31, 0.03), "white", Vector3(0, angle, 0))
	_g.cylinder(p + b * Vector3(width * 0.23, 0.28, 0.082), 0.23, 0.025, "mustard", Vector3(PI / 2, angle, 0))
	for i in 5:
		var height := 0.30 + float((i * 3) % 5) * 0.13
		_g.box(p + b * Vector3((float(i) - 2.0) * width * 0.15, -0.51 + height * 0.5, 0.085), Vector3(width * 0.13, height, 0.025), "teal" if i % 2 == 0 else "brick", Vector3(0, angle, 0))

func _bookcase(p: Vector3, angle: float) -> void:
	var b := Basis(Vector3.UP, angle)
	_g.box(p + b * Vector3(0, 1.05, -0.16), Vector3(1.8, 2.1, 0.08), "wood", Vector3(0, angle, 0))
	for x in [-0.84, 0.84]:
		_g.box(p + b * Vector3(x, 1.05, 0.08), Vector3(0.12, 2.1, 0.48), "wood", Vector3(0, angle, 0))
	for y in [0.08, 2.06]:
		_g.box(p + b * Vector3(0, y, 0.08), Vector3(1.8, 0.10, 0.48), "wood", Vector3(0, angle, 0))
	for row in 3:
		var y := 0.18 + float(row) * 0.62
		_g.box(p + b * Vector3(0, y + 0.24, -0.105), Vector3(1.58, 0.52, 0.025), "petrol", Vector3(0, angle, 0))
		_g.box(p + b * Vector3(0, y - 0.035, 0.18), Vector3(1.75, 0.07, 0.30), "cream", Vector3(0, angle, 0))
		for book in 8:
			var height := 0.32 + float((book + row) % 3) * 0.05
			var local_p := Vector3(-0.66 + book * 0.18, y + height * 0.5, 0.29)
			_g.box(p + b * local_p, Vector3(0.13, height, 0.19), ["cream", "teal", "brick", "mustard"][(book + row) % 4], Vector3(0, angle, 0))
			_g.box(p + b * (local_p + Vector3(0, height * 0.22, 0.10)), Vector3(0.085, 0.025, 0.015), "white", Vector3(0, angle, 0))
	_g.solid(p + Vector3(0, 1.05, 0), Vector3(0.75, 2.1, 1.8))

func _office_hinged_door() -> void:
	office_door = Node3D.new()
	office_door.name = "Office1406Hinge"
	office_door.position = Vector3(4, 0, -15)
	add_child(office_door)
	var door_geometry = Geometry.new()
	office_door.add_child(door_geometry)
	# Leave clearance at both jambs and under the lintel.
	door_geometry.box(Vector3(0, 1.335, 1), Vector3(0.11, 2.65, 1.94), "wood")
	for z in [0.16, 1.84]:
		door_geometry.box(Vector3(-0.065, 1.35, z), Vector3(0.025, 2.4, 0.045), "cream")
	for y in [0.14, 2.55]:
		door_geometry.box(Vector3(-0.065, y, 1), Vector3(0.025, 0.045, 1.7), "cream")
	door_geometry.box(Vector3(-0.07, 2.14, 1), Vector3(0.035, 0.3, 0.70), "petrol")
	door_geometry.label("1406", Vector3(-0.095, 2.14, 1), 40, "cream", Vector3(0, -PI / 2, 0), 0.005)
	for side in [-1.0, 1.0]:
		door_geometry.box(Vector3(side * 0.09, 1.08, 1.7), Vector3(0.035, 0.18, 0.11), "petrol")
		door_geometry.box(Vector3(side * 0.14, 1.12, 1.61), Vector3(0.12, 0.05, 0.25), "mustard")
	for y in [0.25, 1.35, 2.45]:
		door_geometry.cylinder(Vector3(0, y, 0), 0.06, 0.17, "mustard")
	# Moving the hinge carries the complete collision shape, never a stale wall.
	var body := AnimatableBody3D.new()
	body.name = "DoorCollision"
	body.sync_to_physics = false
	body.position = Vector3(0, 1.335, 1)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.11, 2.65, 1.94)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	office_door.add_child(body)
	door_geometry.flush()
	# Both face casings stand clear of the wall; jamb end faces no
	# longer coincide with the cream wall's ends at z=-15 and z=-13.
	for x in [3.815, 4.195]:
		for z in [-15.08, -12.92]:
			_g.box(Vector3(x, 1.35, z), Vector3(0.05, 2.70, 0.20), "petrol")
		_g.box(Vector3(x, 2.78, -14), Vector3(0.05, 0.16, 2.36), "petrol")
	# Thin reveals close the wall thickness without sharing a wall plane.
	for z in [-14.995, -13.005]:
		_g.box(Vector3(4.005, 1.34, z), Vector3(0.30, 2.68, 0.02), "petrol")
	_g.box(Vector3(4.005, 2.687, -14), Vector3(0.30, 0.014, 1.972), "petrol")
	_g.label("СОБЕСЕДОВАНИЕ", Vector3(3.80, 3.13, -14), 30, "petrol", Vector3(0, -PI / 2, 0), 0.004)

func _desk(p: Vector3) -> void:
	_block(p + Vector3(0, 0.8, 0), Vector3(3.15, 0.14, 1.65), "wood")
	_g.box(p + Vector3(0, 0.88, 0), Vector3(3.08, 0.025, 1.59), "cream")
	for x in [-1.22, 1.22]:
		_g.prism(p + Vector3(x, 0, 0), DESK_END, 0.13, "petrol", Vector3(0, PI / 2, 0))
		_g.box(p + Vector3(x, 0.055, 0), Vector3(0.27, 0.11, 1.12), "dark")
		_g.solid(p + Vector3(x, 0.37, 0), Vector3(0.16, 0.74, 0.8))
	_g.box(p + Vector3(0, 0.56, -0.54), Vector3(2.4, 0.08, 0.09), "petrol")
	_block(p + Vector3(-0.91, 0.43, 0), Vector3(0.60, 0.60, 1.24), "wood")
	for y in [0.25, 0.45, 0.65]:
		_g.box(p + Vector3(-0.91, y, 0.635), Vector3(0.54, 0.17, 0.035), "teal")
		_g.box(p + Vector3(-0.91, y + 0.02, 0.675), Vector3(0.22, 0.03, 0.055), "petrol")
	_g.box(p + Vector3(1.02, 0.93, -0.15), Vector3(0.45, 0.06, 0.55), "brick")
	_g.box(p + Vector3(1.02, 0.97, -0.15), Vector3(0.40, 0.02, 0.49), "cream")
	_g.cylinder(p + Vector3(-1.0, 1.0, -0.47), 0.09, 0.22, "mustard")
	_rod(p + Vector3(-0.91, 0.98, -0.47), p + Vector3(-0.83, 1.04, -0.47), 0.025, "mustard")
	_rod(p + Vector3(-0.83, 1.04, -0.47), p + Vector3(-0.91, 1.10, -0.47), 0.025, "mustard")
	# Rounded worktop edge, cable tray, and articulated reading lamp.
	_g.cylinder(p + Vector3(0, 0.81, 0.815), 0.07, 3.12, "wood", Vector3(0, 0, PI / 2))
	_g.box(p + Vector3(0.2, 0.69, -0.60), Vector3(1.5, 0.09, 0.26), "petrol")
	_g.cylinder(p + Vector3(-1.23, 0.925, -0.56), 0.16, 0.045, "petrol")
	_rod(p + Vector3(-1.23, 0.95, -0.56), p + Vector3(-1.38, 1.37, -0.48), 0.019, "petrol")
	_rod(p + Vector3(-1.38, 1.37, -0.48), p + Vector3(-1.07, 1.58, -0.35), 0.019, "petrol")
	_g.cone(p + Vector3(-1.07, 1.54, -0.35), 0.16, 0.19, "cream")
	_g.cylinder(p + Vector3(-1.07, 1.437, -0.35), 0.12, 0.012, "white")

func _chair(p: Vector3, angle: float) -> void:
	var b := Basis(Vector3.UP, angle)
	_g.cylinder(p + Vector3(0, 0.29, 0), 0.075, 0.42, "petrol")
	_g.cylinder(p + Vector3(0, 0.40, 0), 0.048, 0.24, "concrete")
	for i in range(5):
		var a := angle + float(i) * TAU / 5.0
		var end := Vector3(cos(a) * 0.39, 0.12, sin(a) * 0.39)
		_rod(p + Vector3(0, 0.17, 0), p + end, 0.038, "petrol")
		_g.cylinder(p + end + Vector3(0, -0.03, 0), 0.075, 0.055, "dark", Vector3(PI / 2, a, 0))
		_g.cylinder(p + end + Vector3(0, 0.04, 0), 0.025, 0.1, "concrete")
	_g.prism(p + Vector3(0, 0.51, 0), CHAMFERED_SEAT, 0.10, "petrol", Vector3(PI / 2, angle, 0))
	_g.prism(p + Vector3(0, 0.575, 0), CHAMFERED_SEAT, 0.10, "teal", Vector3(PI / 2, angle, 0))
	for i in range(9):
		var a := (float(i) - 4.0) * 0.16
		var local_p := Vector3(sin(a) * 0.52, 0.68, 0.08 + cos(a) * 0.27)
		_g.prism(p + b * local_p, BACK_PANEL, 0.09, "teal", Vector3(0, angle + a, 0))
	for x in [-0.22, 0.22]:
		_rod(p + b * Vector3(x, 0.49, 0.21), p + b * Vector3(x, 0.94, 0.34), 0.025, "petrol")
	for x in [-0.39, 0.39]:
		_rod(p + b * Vector3(x, 0.51, 0.17), p + b * Vector3(x, 0.80, 0.17), 0.025, "petrol")
		_rod(p + b * Vector3(x, 0.80, 0.17), p + b * Vector3(x, 0.80, -0.21), 0.025, "petrol")
		_g.box(p + b * Vector3(x, 0.82, -0.02), Vector3(0.09, 0.06, 0.46), "dark", Vector3(0, angle, 0))
	_g.solid(p + Vector3(0, 0.57, 0), Vector3(0.82, 1.14, 0.82))

func _computer() -> void:
	_g.box(Vector3(10, 0.925, -19), Vector3(0.56, 0.055, 0.36), "petrol")
	_g.cylinder(Vector3(10, 1.02, -19.05), 0.045, 0.20, "concrete")
	_g.box(Vector3(10, 1.30, -19), Vector3(1.56, 0.82, 0.12), "dark")
	_g.box(Vector3(10, 1.30, -18.925), Vector3(1.43, 0.70, 0.025), "cream")
	_g.box(Vector3(10, 1.55, -18.905), Vector3(1.40, 0.18, 0.018), "petrol")
	_g.label("LATENT SYSTEMS", Vector3(10, 1.55, -18.889), 36, "cream", Vector3.ZERO, 0.0032, 1.24, 0.13)
	_g.label("Система собеседований", Vector3(10, 1.36, -18.889), 30, "petrol", Vector3.ZERO, 0.0028, 1.23, 0.11)
	_g.label("1406 / ГОТОВО К НАЧАЛУ", Vector3(10, 1.23, -18.889), 22, "petrol", Vector3.ZERO, 0.0025, 1.18, 0.08)
	_g.box(Vector3(10, 1.07, -18.90), Vector3(0.73, 0.15, 0.025), "petrol")
	_g.label("Начать", Vector3(10, 1.07, -18.879), 34, "cream", Vector3.ZERO, 0.003, 0.60, 0.12)
	_g.ellipsoid(Vector3(10.67, 0.935, -18.92), Vector3(0.024, 0.024, 0.017), "teal")
	# A distinct webcam body, mount, glass lens, and privacy slider.
	_g.box(Vector3(10, 1.75, -19.01), Vector3(0.22, 0.08, 0.09), "petrol")
	_g.box(Vector3(10, 1.70, -19.06), Vector3(0.10, 0.07, 0.12), "petrol")
	_g.cylinder(Vector3(10, 1.75, -18.948), 0.033, 0.027, "concrete", Vector3(PI / 2, 0, 0))
	_g.cylinder(Vector3(10, 1.75, -18.927), 0.022, 0.014, "dark", Vector3(PI / 2, 0, 0))
	_g.cylinder(Vector3(10, 1.75, -18.914), 0.014, 0.008, "glass", Vector3(PI / 2, 0, 0))
	_g.box(Vector3(10.077, 1.75, -18.945), Vector3(0.04, 0.043, 0.012), "concrete")
	for x in [9.67, 9.79, 9.91]:
		_g.box(Vector3(x, 1.02, -19.075), Vector3(0.06, 0.02, 0.014), "concrete")
	# Separate keycaps, navigation bank, space bar, and mouse buttons.
	_g.box(Vector3(10, 0.93, -18.66), Vector3(0.84, 0.055, 0.27), "petrol")
	for row in range(4):
		for col in range(12):
			_g.box(Vector3(9.635 + col * 0.060, 0.968, -18.755 + row * 0.057), Vector3(0.048, 0.026, 0.043), "cream")
	_g.box(Vector3(10, 0.97, -18.54), Vector3(0.30, 0.024, 0.04), "cream")
	_g.box(Vector3(10.70, 0.91, -18.64), Vector3(0.40, 0.024, 0.36), "teal")
	_g.ellipsoid(Vector3(10.70, 0.96, -18.65), Vector3(0.12, 0.08, 0.21), "cream")
	_g.box(Vector3(10.70, 0.998, -18.69), Vector3(0.012, 0.01, 0.10), "petrol")
	_g.cylinder(Vector3(10.70, 1.008, -18.68), 0.013, 0.026, "dark", Vector3(0, 0, PI / 2))
	# Tower, fan grille, optical drive, and recessed physical sockets.
	_g.box(Vector3(11.07, 0.43, -19.16), Vector3(0.29, 0.64, 0.49), "petrol")
	_g.box(Vector3(11.07, 0.65, -18.907), Vector3(0.21, 0.05, 0.018), "dark")
	for y in [0.27, 0.31, 0.35, 0.39, 0.43]:
		_g.box(Vector3(11.07, y, -18.91), Vector3(0.19, 0.014, 0.018), "dark")
	for x in [11.01, 11.11]:
		_g.box(Vector3(x, 0.55, -18.91), Vector3(0.04, 0.017, 0.02), "concrete")
	_g.cylinder(Vector3(11.07, 0.71, -18.91), 0.018, 0.015, "mustard", Vector3(PI / 2, 0, 0))
	_rod(Vector3(10, 1.04, -19.1), Vector3(10, 0.70, -19.8), 0.012, "dark")
	_rod(Vector3(10, 0.70, -19.8), Vector3(11.1, 0.35, -19.43), 0.012, "dark")

func _coat_rack(p: Vector3) -> void:
	_g.cylinder(p + Vector3(0, 0.05, 0), 0.36, 0.10, "petrol")
	_g.cylinder(p + Vector3(0, 1.05, 0), 0.04, 2.0, "wood")
	_g.ellipsoid(p + Vector3(0, 2.08, 0), Vector3(0.13, 0.13, 0.13), "mustard")
	for i in range(6):
		var a := float(i) * TAU / 6.0
		var tip := p + Vector3(cos(a) * 0.3, 1.85, sin(a) * 0.3)
		_rod(p + Vector3(0, 1.7, 0), tip, 0.025, "petrol")
		_g.ellipsoid(tip, Vector3(0.075, 0.075, 0.075), "mustard")
		if i % 2 == 0:
			_rod(p + Vector3(0, 0.10, 0), p + Vector3(cos(a) * 0.32, 0.07, sin(a) * 0.32), 0.035, "petrol")
	_g.prism(p + Vector3(0.20, 0.85, 0.17), PackedVector2Array([
		Vector2(-0.21, 0), Vector2(0.21, 0), Vector2(0.31, 0.55),
		Vector2(0.16, 0.82), Vector2(-0.16, 0.82), Vector2(-0.31, 0.55)
	]), 0.10, "brick")
	_g.box(p + Vector3(0.2, 1.27, 0.23), Vector3(0.025, 0.7, 0.025), "cream")
	_g.solid(p + Vector3(0, 0.95, 0), Vector3(0.7, 1.9, 0.7))

func _rod(a: Vector3, b: Vector3, radius: float, color: String) -> void:
	var delta := b - a
	var orientation := Basis(Quaternion(Vector3.UP, delta.normalized())).get_euler()
	_g.cylinder((a + b) * 0.5, radius, delta.length(), color, orientation)
