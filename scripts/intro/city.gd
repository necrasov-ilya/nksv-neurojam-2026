extends Node3D
## A walkable, inhabited district. Local ground top is y = 0.
const Geometry = preload("res://scripts/intro/geometry.gd")
const CAR_BODY := [Vector2(-2.35, 0.62), Vector2(2.35, 0.62), Vector2(2.23, 0.9), Vector2(1.48, 1.04), Vector2(-1.64, 1.04), Vector2(-2.23, 0.88)]
const CAR_CABIN := [Vector2(-1.43, 1.0), Vector2(1.34, 1.0), Vector2(0.69, 1.71), Vector2(-0.83, 1.71)]
const WAGON_CABIN := [Vector2(-1.83, 1.0), Vector2(1.34, 1.0), Vector2(0.69, 1.77), Vector2(-1.54, 1.77)]
const ROOF_PROFILE := [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.5, 0.12), Vector2(0.36, 1.0), Vector2(-0.36, 1.0), Vector2(-0.5, 0.12)]
const CANOPY_PROFILE := [Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(1.6, 0.18), Vector2(1.0, 0.42), Vector2(-1.0, 0.42), Vector2(-1.6, 0.18)]
var pedestrian_routes: Array = []
var _g
var _traffic: Array = []
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	_g = Geometry.new()
	_g.name = "DistrictGeometry"
	add_child(_g)
	_ground_and_streets()
	_buildings()
	_tower()
	_edge_blocks()
	_street_life()
	_stop(Vector3(18.1, 0, 108))
	_plaza()
	_routes()
	_g.flush()
	_background_traffic()

func _p(o: Vector3, r: float, p: Vector3) -> Vector3:
	return o + p.rotated(Vector3.UP, r)

func _b(o: Vector3, r: float, p: Vector3, size: Vector3, color: String, g = null) -> void:
	var target = _g if g == null else g
	target.box(_p(o, r, p), size, color, Vector3(0, r, 0))

func _c(o: Vector3, r: float, p: Vector3, radius: float, height: float, color: String, rotation_value := Vector3.ZERO, g = null) -> void:
	var target = _g if g == null else g
	# Keep the cylinder's tilted axis in the model's coordinate frame.
	var euler := (Basis(Vector3.UP, r) * Basis.from_euler(rotation_value)).get_euler()
	target.cylinder(_p(o, r, p), radius, height, color, euler)

func _rod(o: Vector3, r: float, a: Vector3, b: Vector3, radius: float, color: String, g = null) -> void:
	var delta := b - a
	var orientation := Basis(Quaternion(Vector3.UP, delta.normalized())).get_euler()
	_c(o, r, (a + b) * 0.5, radius, delta.length(), color, orientation, g)

func _ring(o: Vector3, r: float, p: Vector3, inner_radius: float, outer_radius: float, color: String) -> void:
	var orientation := (Basis(Vector3.UP, r) * Basis(Vector3.RIGHT, PI / 2)).get_euler()
	_g.torus(_p(o, r, p), inner_radius, outer_radius, color, orientation)

func _s(o: Vector3, r: float, p: Vector3, size: Vector3) -> void:
	var body = _g.solid(_p(o, r, p), size)
	body.rotation.y = r

func _sign(o: Vector3, r: float, p: Vector3, text: String, font_size := 42, color := "cream", pixel_size := 0.013, max_width := 4.0, max_height := 0.5, node_name := "ShopSignText") -> void:
	var text_node: Label3D = _g.label(text, _p(o, r, p), font_size, color, Vector3(0, r, 0), pixel_size, max_width, max_height)
	text_node.name = node_name

func _ground_and_streets() -> void:
	_g.box(Vector3(40, -0.44, -30), Vector3(560, 0.8, 540), "leaf")
	_g.solid(Vector3(40, -0.5, -30), Vector3(560, 1, 540))
	# Tile the crossing once: coplanar overlapping avenue/sidewalk slabs flicker.
	for segment in [Vector2(-155,130), Vector2(50,240)]:
		_g.box(Vector3(0,-0.03,segment.x),Vector3(20,0.06,segment.y),"road")
		for x in [-15.0,15.0]:
			_g.box(Vector3(x,-0.055,segment.x),Vector3(10,0.11,segment.y),"concrete")
	_g.box(Vector3(42,-0.03,-80),Vector3(386,0.06,20),"road")
	for segment in [Vector2(-85.5,131),Vector2(127.5,215)]:
		for z in [-95.0,-65.0]:
			_g.box(Vector3(segment.x,-0.055,z),Vector3(segment.y,0.11,10),"concrete")
	# Flat, inset curbstones preserve the entire accessible crossing surface.
	for z in range(-218, 172, 3):
		if z > -92 and z < -68:
			continue
		for x in [-10.0, 10.0, -20.0, 20.0]:
			_g.box(Vector3(x, 0.015, z), Vector3(0.22, 0.03, 2.85), "cream")
	for x in range(-148, 234, 3):
		if abs(x) < 21:
			continue
		for z in [-90.0, -70.0, -100.0, -60.0]:
			_g.box(Vector3(x, 0.015, z), Vector3(2.85, 0.03, 0.22), "cream")
	for z in range(-214, 170, 9):
		if z > -97 and z < -64:
			continue
		_g.box(Vector3(0, 0.005, z), Vector3(0.14, 0.02, 3.8), "cream")
	for x in range(-146, 233, 9):
		if abs(x) < 26:
			continue
		_g.box(Vector3(x, 0.008, -80), Vector3(3.8, 0.02, 0.14), "cream")
	for v in range(-8, 9, 2):
		for z in [-96.0, -64.0]:
			_g.box(Vector3(v, 0.015, z), Vector3(1.0, 0.025, 4.5), "white")
		for x in [-26.0, 26.0]:
			_g.box(Vector3(x, 0.015, -80 + v), Vector3(4.5, 0.025, 1.0), "white")
	# Footpaths extend through the side streets and courtyards, not into fences.
	for z in [-179.0, -137.0, -27.0, 57.0, 99.0, 153.0]:
		for side in [-1, 1]:
			_g.box(Vector3(side * 73.0, -0.025, z), Vector3(106, 0.05, 6), "concrete")
	for z in range(-204, 164, 12):
		if abs(z + 80) < 25:
			continue
		for x in [-17.0, 17.0]:
			_g.box(Vector3(x, 0.003, z), Vector3(0.025, 0.008, 9), "cream")
	_direction_sign(Vector3(17.5, 0, 97), false)
	_direction_sign(Vector3(17.5, 0, -54), true)
	_g.box(Vector3(32, 4.5, -59.35), Vector3(13, 1.0, 0.24), "cream")
	for x in [27.0, 37.0]:
		_g.box(Vector3(x, 2.25, -59.18), Vector3(0.12, 4.5, 0.12), "petrol")
	# The walking approach is north of this board, along z = -66.
	_sign(Vector3(32, 0, -59.35), PI, Vector3(0, 4.5, 0.15), "ЦЕНТРАЛЬНЫЙ ПРОСПЕКТ", 34, "petrol", 0.013, 12.3, 0.65, "AvenueSignText")

func _buildings() -> void:
	var names := ["КНИГИ И БУМАГА", "КОФЕ / ХЛЕБ", "АТЕЛЬЕ", "ЗЕЛЁНАЯ ЛАВКА", "РАДИО / МАСТЕРСКАЯ", "ПОЧТА", "МУЗЫКА"]
	var heights := [5, 6, 8, 4, 7, 9, 6]
	var centers := [120.0, 78.0, 36.0, -6.0, -48.0, -116.0, -158.0]
	for side in [-1, 1]:
		for i in centers.size():
			var kind: int = (i + (1 if side < 0 else 0)) % 4
			var center := Vector3(side * 36.0, 0, centers[i])
			# Set back the eastern cafe to open a diagonal skyline view of the tower.
			if side > 0 and i == 1:
				center = Vector3(66, 0, 94)
			_building(center, -side * PI / 2.0, 28.0, 24.0, heights[i], kind, names[(i + (2 if side < 0 else 0)) % names.size()])
	for i in 3:
		var x := 73.0 + i * 38.0
		_building(Vector3(x, 0, -116), 0, 28, 26, 5 + i, (i + 1) % 4, ["ГОРОДСКАЯ БИБЛИОТЕКА", "ДИЗАЙН / ПЕЧАТЬ", "ЦВЕТЫ"][i])
		_building(Vector3(x, 0, -44), PI, 28, 26, 6 + i, i % 4, ["КАФЕ ПЛАТФОРМА", "ТОВАРЫ ДЛЯ ДОМА", "ВЕЛОСЕРВИС"][i])
	for i in 2:
		for side in [-1, 1]:
			_building(Vector3(-76.0 - i * 42, 0, -80 + side * 37), 0 if side < 0 else PI, 30, 26, 5 + i * 3, (i + 2) % 4, "МАСТЕРСКИЕ" if side < 0 else "ПРОДУКТЫ")
	# A second row of lower-detail, fully solid blocks closes long street vistas.
	for side in [-1, 1]:
		for i in 5:
			_distant_block(Vector3(side * 104.0, 0, [144.0, 93.0, 42.0, -155.0, -194.0][i]), -side * PI / 2, 34, 27, 21 + (i % 3) * 5, i)

func _building(o: Vector3, r: float, w: float, d: float, floors: int, kind: int, shop: String) -> void:
	var h := 4.4 + floors * 3.15
	var facade: String = ["cream", "masonry", "teal", "concrete"][kind]
	var f := d * 0.5
	# The ground floor is a genuinely recessed arcade, not a painted frontage.
	_b(o, r, Vector3(0, (h + 4.2) / 2, 0), Vector3(w, h - 4.2, d), facade)
	_s(o, r, Vector3(0, (h + 4.2) / 2, 0), Vector3(w, h - 4.2, d))
	_b(o, r, Vector3(0, 2.1, -2.0), Vector3(w, 4.2, d - 4), "petrol")
	_s(o, r, Vector3(0, 2.1, -2.0), Vector3(w, 4.2, d - 4))
	for x in [-w / 2 + 0.3, w / 2 - 0.3]:
		_b(o, r, Vector3(x, 2.1, f - 2), Vector3(0.6, 4.2, 4), facade)
		_s(o, r, Vector3(x, 2.1, f - 2), Vector3(0.6, 4.2, 4))
	for x in [-w / 2 + 1.0, -w / 6, w / 6, w / 2 - 1.0]:
		_b(o, r, Vector3(x, 2.0, f - 0.1), Vector3(0.32, 4.0, 0.48), "cream")
		_b(o, r, Vector3(x, 0.24, f - 0.1), Vector3(0.6, 0.48, 0.7), "concrete")
		_s(o, r, Vector3(x, 2, f - 0.1), Vector3(0.38, 4, 0.55))
	_b(o, r, Vector3(0, 4.08, f + 0.05), Vector3(w + 0.9, 0.32, 1.35), "cream")
	# Mount the fascia ahead of the arcade columns so no letters hide behind them.
	var fascia_color := "accent_magenta" if kind == 1 else ("accent_violet" if kind == 3 else "petrol")
	_b(o, r, Vector3(0, 3.57, f + 0.31), Vector3(w - 2.0, 0.66, 0.26), fascia_color)
	_sign(o, r, Vector3(0, 3.57, f + 0.47), shop, 38, "cream", 0.016, w - 2.7, 0.48)
	var display_kind := _shop_display_kind(shop)
	for bay in [-1, 1]:
		_shop_window(o, r, Vector3(bay * w * 0.275, 0, f - 2.7), w * 0.32, display_kind)
	# Central deep-framed doorway has a flush threshold and an illuminated fanlight.
	_b(o, r, Vector3(0, 1.55, f - 3.91), Vector3(2.2, 3.1, 0.18), "wood")
	_b(o, r, Vector3(0, 1.72, f - 3.79), Vector3(1.86, 2.38, 0.09), "glass")
	_b(o, r, Vector3(0, 1.72, f - 3.71), Vector3(0.08, 2.48, 0.09), "cream")
	_b(o, r, Vector3(0, 0.28, f - 3.70), Vector3(1.91, 0.45, 0.09), "wood")
	_b(o, r, Vector3(0, 3.27, f - 3.78), Vector3(2.14, 0.35, 0.12), "glass")
	for x in [-1.22, 1.22]:
		_b(o, r, Vector3(x, 1.77, f - 3.70), Vector3(0.18, 3.54, 0.28), "cream")
	_c(o, r, Vector3(0.65, 1.25, f - 3.61), 0.035, 0.42, "mustard")
	_entry_canopy(o, r, Vector3(0, 3.1, f - 2.5), kind)
	for bay in [-1, 1]:
		_awning(o, r, Vector3(bay * w * 0.275, 3.0, f - 1.6), w * 0.30, kind)
	_b(o, r, Vector3(0, 0.035, f - 3.15), Vector3(2.4, 0.07, 1.6), "stone")
	# Small fittings stay inside the arcade, clear of the public walking corridor.
	var address := 2 + posmod(roundi(abs(o.x) + abs(o.z)), 48)
	_b(o, r, Vector3(1.78, 2.35, f - 3.82), Vector3(0.68, 0.54, 0.16), "cream")
	_sign(o, r, Vector3(1.78, 2.35, f - 3.71), str(address), 30, "petrol", 0.012, 0.48, 0.34, "BuildingNumberText")
	for side in [-1, 1]:
		_b(o, r, Vector3(side * (w * 0.5 - 2.2), 2.72, f - 3.64), Vector3(0.38, 0.64, 0.24), "petrol")
		_b(o, r, Vector3(side * (w * 0.5 - 2.2), 2.72, f - 3.49), Vector3(0.25, 0.43, 0.08), "cream")
	for floor_index in floors:
		var y := 5.75 + floor_index * 3.15
		if kind == 0 or kind == 2:
			_b(o, r, Vector3(0, y - 1.38, f + 0.14), Vector3(w + 0.18, 0.17, 0.35), "cream")
		elif kind == 1:
			_b(o, r, Vector3(0, y - 1.39, f + 0.07), Vector3(w - 0.8, 0.11, 0.16), "wood")
		for column in 7:
			var x := -w / 2 + 2.0 + column * (w - 4.0) / 6.0
			_window(o, r, Vector3(x, y, f), kind, floor_index, column)
			if kind == 1 and floor_index % 2 == 0 and column % 2 == 1:
				_balcony(o, r, Vector3(x, y - 1.0, f + 0.82))
			if kind == 3:
				_b(o, r, Vector3(x + 1.45, y, f + 0.25), Vector3(0.22, 3.15, 0.7), "cream")
		# Side windows ensure corner views show a finished building, not a blank slab.
		for side in [-1, 1]:
			for j in 4:
				var side_origin := _p(o, r, Vector3(side * w / 2, 0, -d / 2 + 3.0 + j * (d - 6.0) / 3.0))
				_window(side_origin, r + side * PI / 2.0, Vector3(0, y, 0), kind, floor_index, j)
	# Three-stepped cornice and parapet silhouette.
	for i in 3:
		_b(o, r, Vector3(0, h - 0.25 + i * 0.24, 0), Vector3(w + 0.35 + i * 0.34, 0.24, d + 0.35 + i * 0.34), "cream")
	_b(o, r, Vector3(0, h + 0.8, -d / 2 + 0.2), Vector3(w, 1.2, 0.4), facade)
	for side in [-1, 1]:
		_b(o, r, Vector3(side * (w / 2 - 0.2), h + 0.8, 0), Vector3(0.4, 1.2, d), facade)
	if kind == 0:
		# Front-to-back mansard slope leaves the projecting dormer faces exposed.
		_g.prism(_p(o, r, Vector3(0, h + 0.45, 0)), PackedVector2Array(ROOF_PROFILE), w - 1.2, "petrol", Vector3(0, r + PI / 2, 0), Vector2(d + 0.3, 3.5))
		for x in [-6.0, 6.0]:
			_b(o, r, Vector3(x, h + 2.6, f - 2.4), Vector3(2.7, 1.8, 2.5), "cream")
			_b(o, r, Vector3(x, h + 2.8, f - 1.09), Vector3(1.8, 1.1, 0.14), "glass")
			_b(o, r, Vector3(x, h + 3.57, f - 2.3), Vector3(3.05, 0.18, 2.8), "petrol")
			_b(o, r, Vector3(x, h + 2.8, f - 1.0), Vector3(0.07, 1.15, 0.09), "cream")
			_b(o, r, Vector3(x, h + 2.2, f - 1.0), Vector3(2.1, 0.12, 0.3), "cream")
	else:
		_b(o, r, Vector3(0, h + 0.55, f - 0.2), Vector3(w, 0.75, 0.4), facade)
	if kind != 0:
		_roof_plant(o, r, Vector3(-5, h + 0.55, -3))
		_b(o, r, Vector3(6, h + 1.4, -5), Vector3(3.0, 2.3, 3.3), "cream")
		_c(o, r, Vector3(6, h + 3.4, -5), 0.36, 2.0, "petrol")
	else:
		_b(o, r, Vector3(7.8, h + 3.1, -5), Vector3(0.9, 3.0, 1.0), "masonry")
		_b(o, r, Vector3(7.8, h + 4.65, -5), Vector3(1.2, 0.16, 1.3), "stone")
	for side in [-1, 1]:
		_b(o, r, Vector3(side * (w / 2 - 0.55), h / 2 + 2, f + 0.16), Vector3(0.45, h - 4, 0.44), "cream")
		# Downpipes make the side elevations read as occupied, maintained buildings.
		_c(o, r, Vector3(side * (w / 2 - 0.95), (h + 4.4) * 0.5, f + 0.38), 0.07, h - 4.4, "petrol")
	if kind == 1:
		for x in [-8.0, 0.0, 8.0]:
			_b(o, r, Vector3(x, h + 1.2, f - 0.2), Vector3(2.4, 0.75, 0.55), "masonry")
			_b(o, r, Vector3(x, h + 1.61, f - 0.2), Vector3(2.7, 0.12, 0.72), "cream")
	elif kind == 2:
		_b(o, r, Vector3(0, h + 1.45, f - 0.2), Vector3(5.8, 1.1, 0.6), "teal")
		_b(o, r, Vector3(0, h + 2.03, f - 0.2), Vector3(6.3, 0.16, 0.8), "cream")
		_c(o, r, Vector3(0, h + 1.48, f + 0.15), 0.34, 0.12, "cream", Vector3(PI / 2, 0, 0))
	# Articulated corner plinths continue the facade around the side streets.
	for side in [-1, 1]:
		_b(o, r, Vector3(side * (w * 0.5 + 0.06), 0.48, -2), Vector3(0.24, 0.96, d - 4), "stone")
		for level in range(4, int(h), 3):
			_b(o, r, Vector3(side * (w * 0.5 + 0.08), level + 0.18, f - 0.7), Vector3(0.28, 0.48, 1.35), "cream")
	if kind == 3:
		for x in [-w * 0.35, w * 0.35]:
			_b(o, r, Vector3(x, h + 1.6, -d * 0.22), Vector3(3.4, 1.6, 4.2), "petrol")
			_b(o, r, Vector3(x, h + 2.45, -d * 0.22), Vector3(3.7, 0.15, 4.5), "steel")

func _window(o: Vector3, r: float, p: Vector3, kind: int, floor_index: int, column: int) -> void:
	_b(o, r, p + Vector3(0, 0, 0.06), Vector3(2.28, 2.22, 0.19), "petrol")
	_b(o, r, p + Vector3(0, 0, 0.17), Vector3(1.92, 1.9, 0.12), "glass")
	var curtain := posmod(floor_index * 3 + column + kind, 5)
	if curtain < 3:
		var curtain_color := "mustard" if curtain == 0 else "cream"
		_b(o, r, p + Vector3(-0.63 if curtain != 2 else 0.63, 0, 0.245), Vector3(0.46, 1.72, 0.04), curtain_color)
	if kind == 3 and floor_index % 3 == 1:
		_b(o, r, p + Vector3(0, 0.74, 0.25), Vector3(1.88, 0.30, 0.04), "teal")
	_b(o, r, p + Vector3(0, 0, 0.27), Vector3(0.075, 1.98, 0.10), "cream")
	_b(o, r, p + Vector3(0, 0.28, 0.27), Vector3(1.98, 0.075, 0.10), "cream")
	_b(o, r, p + Vector3(0, -1.13, 0.31), Vector3(2.6, 0.16, 0.64), "cream")
	if kind == 0:
		_b(o, r, p + Vector3(0, 1.15, 0.23), Vector3(2.6, 0.18, 0.48), "cream")
	if kind == 2 and (column + floor_index) % 3 != 0:
		for side in [-1, 1]:
			_b(o, r, p + Vector3(side * 1.43, 0, 0.28), Vector3(0.48, 1.95, 0.16), "petrol")
			for slat in 5:
				_b(o, r, p + Vector3(side * 1.43, -0.72 + slat * 0.36, 0.39), Vector3(0.40, 0.07, 0.08), "teal")
	if (floor_index + column * 2 + kind) % 7 == 0:
		_flower_box(o, r, p + Vector3(0, -1.03, 0.58), 1.8)

func _balcony(o: Vector3, r: float, p: Vector3) -> void:
	_b(o, r, p, Vector3(3.0, 0.22, 1.75), "concrete")
	_b(o, r, p + Vector3(0, 1.0, 0.77), Vector3(3.0, 0.09, 0.09), "petrol")
	for i in 8:
		_b(o, r, p + Vector3(-1.38 + i * 0.395, 0.52, 0.77), Vector3(0.055, 0.97, 0.055), "petrol")
	for x in [-1.42, 1.42]:
		_b(o, r, p + Vector3(x, 1.0, 0), Vector3(0.09, 0.09, 1.65), "petrol")
		_b(o, r, p + Vector3(x, -0.36, -0.4), Vector3(0.14, 0.6, 0.45), "cream")
	_b(o, r, p + Vector3(0.6, 0.26, 0.46), Vector3(0.8, 0.3, 0.32), "brick")
	_g.ellipsoid(_p(o, r, p + Vector3(0.6, 0.6, 0.46)), Vector3(1.0, 0.55, 0.65), "leaf")

func _shop_display_kind(shop: String) -> int:
	if shop.contains("КОФЕ") or shop.contains("КАФЕ") or shop.contains("ПРОДУКТЫ"):
		return 1
	if shop.contains("ЦВЕТЫ") or shop.contains("ЗЕЛЁНАЯ"):
		return 2
	if shop.contains("РАДИО") or shop.contains("МАСТЕРСК") or shop.contains("ВЕЛО"):
		return 3
	if shop.contains("АТЕЛЬЕ"):
		return 4
	if shop.contains("МУЗЫКА"):
		return 5
	if shop.contains("ДОМА"):
		return 6
	return 0

func _shop_window(o: Vector3, r: float, p: Vector3, width: float, kind: int) -> void:
	_b(o, r, p + Vector3(0, 1.65, -0.12), Vector3(width, 2.9, 0.18), "glass")
	for x in [-width / 2, width / 2]:
		_b(o, r, p + Vector3(x, 1.65, 0.04), Vector3(0.13, 3.0, 0.3), "cream")
	_b(o, r, p + Vector3(0, 0.43, 0.68), Vector3(width - 0.3, 0.75, 1.35), "wood")
	_s(o, r, p + Vector3(0, 0.43, 0.68), Vector3(width - 0.3, 0.75, 1.35))
	for shelf in 2:
		_b(o, r, p + Vector3(0, 0.95 + shelf * 0.82, 0.23), Vector3(width - 0.3, 0.12, 0.7), "cream")
		for n in 7:
			var x := -width / 2 + 0.65 + n * (width - 1.3) / 6.0
			var y := 1.1 + shelf * 0.82
			if kind == 0:
				_b(o, r, p + Vector3(x, y + 0.18, 0.25), Vector3(0.24, 0.42, 0.38), ["brick", "teal", "mustard"][n % 3])
				_b(o, r, p + Vector3(x + 0.11, y + 0.18, 0.25), Vector3(0.025, 0.32, 0.34), "cream")
			elif kind == 1:
				_g.ellipsoid(_p(o, r, p + Vector3(x, y + 0.12, 0.33)), Vector3(0.62, 0.28, 0.38), "mustard")
			elif kind == 2:
				_c(o, r, p + Vector3(x, y + 0.15, 0.25), 0.17, 0.32, "brick")
				_g.ellipsoid(_p(o, r, p + Vector3(x, y + 0.52, 0.25)), Vector3(0.65, 0.6, 0.5), "leaf")
			elif kind == 3:
				_b(o, r, p + Vector3(x, y + 0.2, 0.28), Vector3(0.55, 0.42, 0.42), "teal")
				_c(o, r, p + Vector3(x, y + 0.22, 0.51), 0.1, 0.05, "dark", Vector3(PI / 2, 0, 0))
			elif kind == 4:
				for fold in 3:
					_b(o, r, p + Vector3(x, y + fold * 0.12, 0.28), Vector3(0.65, 0.1, 0.46), ["cream", "teal", "brick"][(n + fold) % 3])
			elif kind == 5:
				_b(o, r, p + Vector3(x, y + 0.23, 0.27), Vector3(0.58, 0.58, 0.08), ["cream", "mustard", "teal"][n % 3])
				_c(o, r, p + Vector3(x, y + 0.23, 0.33), 0.19, 0.04, "petrol", Vector3(PI / 2, 0, 0))
				_c(o, r, p + Vector3(x, y + 0.23, 0.36), 0.055, 0.025, "brick", Vector3(PI / 2, 0, 0))
			else:
				_c(o, r, p + Vector3(x, y + 0.14, 0.28), 0.23, 0.28, "cream" if n % 2 == 0 else "brick")
				_c(o, r, p + Vector3(x, y + 0.31, 0.28), 0.26, 0.06, "mustard")

func _roof_plant(o: Vector3, r: float, p: Vector3) -> void:
	_b(o, r, p + Vector3(0, 0.8, 0), Vector3(4.6, 1.6, 3), "concrete")
	for i in 5:
		_b(o, r, p + Vector3(-1.8 + i * 0.9, 1.65, 0), Vector3(0.28, 0.12, 2.6), "petrol")
	for x in [-1.1, 1.1]:
		_c(o, r, p + Vector3(x, 1.85, 0), 0.64, 0.3, "dark")
	_b(o, r, p + Vector3(3.5, 0.4, 0), Vector3(2.5, 0.65, 0.8), "petrol")

func _distant_block(o: Vector3, r: float, w: float, d: float, h: float, kind: int) -> void:
	var color: String = ["cream", "teal", "masonry"][kind % 3]
	_b(o, r, Vector3(0, h / 2, 0), Vector3(w, h, d), color)
	_s(o, r, Vector3(0, h / 2, 0), Vector3(w, h, d))
	_b(o, r, Vector3(0, h, 0), Vector3(w + 1, 0.55, d + 1), "cream")
	# A restrained ground-floor rhythm keeps the outer street walls inhabited.
	_b(o, r, Vector3(0, 0.42, d / 2 + 0.05), Vector3(w, 0.84, 0.18), "concrete")
	_b(o, r, Vector3(0, 3.8, d / 2 + 0.16), Vector3(w + 0.25, 0.22, 0.45), "cream")
	for x in [-w * 0.29, 0.0, w * 0.29]:
		_b(o, r, Vector3(x, 1.8, d / 2 + 0.13), Vector3(2.8, 2.8, 0.18), "petrol")
		_b(o, r, Vector3(x, 2.0, d / 2 + 0.25), Vector3(2.35, 2.0, 0.08), "glass")
		_b(o, r, Vector3(x, 2.0, d / 2 + 0.32), Vector3(0.09, 2.1, 0.08), "cream")
	for y in range(5, int(h) - 1, 3):
		for x in range(-int(w / 2) + 3, int(w / 2) - 1, 4):
			_b(o, r, Vector3(x, y, d / 2 + 0.08), Vector3(1.9, 1.85, 0.15), "glass")
			_b(o, r, Vector3(x, y - 1, d / 2 + 0.18), Vector3(2.2, 0.15, 0.4), "cream")
	_roof_plant(o, r, Vector3(0, h + 0.3, 0))

func _edge_blocks() -> void:
	# Continuous occupied outer blocks close side passages with real architecture.
	# The player can explore the arcades and courtyards, but cannot leave the city.
	for side in [-1, 1]:
		var x := -168.0 if side < 0 else 245.0
		for i in 11:
			_distant_block(Vector3(x,0,-200 + i*38), -side*PI/2, 38,30,22+(i%3)*4,i)
	for z in [-231.0,188.0]:
		for i in 10:
			# End at the inner faces of the side rows; corner buildings never overlap.
			_distant_block(Vector3(-133.85+i*38.3,0,z), 0 if z < 0 else PI,38.3,26,23+(i%3)*3,i)

func _tower() -> void:
	var o := Vector3(194, 0, -80)
	var r := -PI / 2.0
	# Local +Z is the west frontage. Only the framed entrance panes are transparent.
	_b(o, r, Vector3(0, 3.5, -12), Vector3(40, 7, 16), "petrol")
	_s(o, r, Vector3(0, 3.5, -12), Vector3(40, 7, 16))
	for side in [-1, 1]:
		_b(o, r, Vector3(side * 12.2, 3.5, 8), Vector3(15.6, 7, 24), "petrol")
		_s(o, r, Vector3(side * 12.2, 3.5, 8), Vector3(15.6, 7, 24))
		# Solid stone shoulders join the podium to the portal without open slivers.
		_b(o, r, Vector3(side * 3.5, 3.5, 19.5), Vector3(1.8, 7, 1.0), "cream")
		_s(o, r, Vector3(side * 3.2, 3.5, 19.5), Vector3(1.2, 7, 1.0))
		_b(o, r, Vector3(side * 12.2, 0.35, 20.08), Vector3(15.6, 0.7, 0.16), "concrete")
		for bay in 4:
			var x: float = side * (6.35 + bay * 3.9)
			_b(o, r, Vector3(x, 3.1, 20.08), Vector3(3.3, 4.5, 0.16), "cream")
			_b(o, r, Vector3(x, 3.1, 20.19), Vector3(2.94, 4.14, 0.08), "glass")
			_b(o, r, Vector3(x, 3.1, 20.27), Vector3(0.08, 4.14, 0.08), "petrol")
			_b(o, r, Vector3(x, 2.1, 20.27), Vector3(2.94, 0.08, 0.08), "petrol")
	_b(o, r, Vector3(0, 7.6, 0), Vector3(42, 1.2, 42), "cream")
	_b(o, r, Vector3(0, 6.4, 21), Vector3(10, 0.4, 6), "petrol")
	_b(o, r, Vector3(0, 6.1, 21), Vector3(8.7, 0.12, 4.8), "mustard")
	# The lintel, sill and jambs enclose selective glazing, not a glass building mass.
	_b(o, r, Vector3(0, 5.8, 19.5), Vector3(5.2, 2.4, 1.0), "cream")
	for side in [-1, 1]:
		_b(o, r, Vector3(side * 2.0, 2.04, 20.05), Vector3(1.12, 3.88, 0.06), "clear_glass")
		_s(o, r, Vector3(side * 2.05, 2.0, 20.05), Vector3(1.3, 4.0, 0.18))
		for x in [side * 1.4, side * 2.6]:
			_b(o, r, Vector3(x, 2.0, 20.05), Vector3(0.12, 4.0, 0.22), "petrol")
		_b(o, r, Vector3(side * 2.0, 0.06, 20.05), Vector3(1.2, 0.12, 0.22), "petrol")
		# A pair of held-open leaves returns into the foyer, clear of the entry axis.
		_b(o, r, Vector3(side * 1.4, 2.0, 19.15), Vector3(0.06, 3.80, 1.5), "clear_glass")
		for z in [18.35, 19.95]:
			_b(o, r, Vector3(side * 1.4, 2.0, z), Vector3(0.12, 4.0, 0.12), "petrol")
		for y in [0.08, 3.96]:
			_b(o, r, Vector3(side * 1.4, y, 19.15), Vector3(0.12, 0.16, 1.72), "petrol")
		_b(o, r, Vector3(side * 1.30, 1.8, 18.55), Vector3(0.06, 0.65, 0.06), "mustard")
	for y in [4.04, 4.55]:
		_b(o, r, Vector3(0, y, 20.05), Vector3(5.2, 0.12, 0.22), "petrol")
	_b(o, r, Vector3(0, 4.3, 20.05), Vector3(5.08, 0.40, 0.06), "clear_glass")
	_c(o, r, Vector3(0, 5.1, 20.08), 0.36, 0.12, "mustard", Vector3(PI / 2, 0, 0))
	_b(o, r, Vector3(0, 5.5, 23.86), Vector3(9.2, 0.92, 0.3), "petrol")
	_sign(o, r, Vector3(0, 5.5, 24.04), "LATENT SYSTEMS", 60, "cream", 0.013, 8.5, 0.63, "EntranceSignText")
	_b(o, r, Vector3(6, 2.2, 20.22), Vector3(3.6, 1.35, 0.28), "petrol")
	_sign(o, r, Vector3(6, 2.2, 20.38), "ЦЕНТРАЛЬНЫЙ\nПРОСПЕКТ, 18", 32, "cream", 0.012, 3.15, 1.0, "AddressSignText")
	# Twenty-two occupied storeys above a seven-metre podium; stepped crown ~82m.
	_b(o, r, Vector3(0, 42, 0), Vector3(30, 68, 30), "petrol")
	_s(o, r, Vector3(0, 42, 0), Vector3(30, 68, 30))
	for floor_index in 22:
		var y := 9.3 + floor_index * 3.0
		for face in 4:
			var fr := r + face * PI / 2
			for col in 7:
				var x := -12.0 + col * 4
				_b(o, fr, Vector3(x, y, 15.1), Vector3(3.35, 2.5, 0.22), "glass")
				_b(o, fr, Vector3(x, y - 1.3, 15.25), Vector3(3.95, 0.18, 0.5), "teal")
			_b(o, fr, Vector3(0, y + 1.45, 15.3), Vector3(29.2, 0.18, 0.38), "cream")
	for face in 4:
		var fr := r + face * PI / 2
		for x in [-14.1, -6.0, 6.0, 14.1]:
			_b(o, fr, Vector3(x, 42, 15.45), Vector3(0.36, 68, 0.72), "cream")
		_b(o, fr, Vector3(0, 72.9, 15.65), Vector3(13.4, 2.5, 0.30), "petrol")
		_sign(o, fr, Vector3(0, 72.9, 15.83), "LATENT", 100, "cream", 0.023, 12.5, 2.0, "TowerSignText")
	_b(o, r, Vector3(0, 76.5, -1), Vector3(30.6, 1.1, 31.6), "cream")
	_b(o, r, Vector3(0, 78.4, -1), Vector3(21, 3, 22), "teal")
	_b(o, r, Vector3(0, 80.2, -1), Vector3(14, 0.65, 15), "cream")
	_roof_plant(o, r, Vector3(0, 80.6, -1))
	# Opaque returns, a ceiling and a rear wall make the open portal a real room.
	# Its clear central axis stays unobstructed through the automatic entry trigger.
	_b(o, r, Vector3(0, 0.02, 8), Vector3(8.8, 0.04, 24), "cream")
	for side in [-1, 1]:
		_b(o, r, Vector3(side * 4.2, 2.4, 8), Vector3(0.4, 4.8, 24), "cream")
		_b(o, r, Vector3(side * 3.97, 0.3, 8), Vector3(0.06, 0.6, 24), "wood")
	_b(o, r, Vector3(0, 4.75, 8), Vector3(8.8, 0.3, 24), "cream")
	_b(o, r, Vector3(0, 2.4, -3.8), Vector3(8.8, 4.8, 0.4), "wood")
	_sign(o, r, Vector3(0, 2.7, -3.56), "LATENT SYSTEMS\nДОБРО ПОЖАЛОВАТЬ", 42, "cream", 0.015, 7.5, 1.6, "FoyerSignText")
	for x in [-2.7, 2.7]:
		_b(o, r, Vector3(x, 0.4, 15), Vector3(0.9, 0.8, 0.9), "concrete")
		_g.ellipsoid(_p(o, r, Vector3(x, 1.35, 15)), Vector3(1.1, 1.4, 1.1), "leaf")

func _street_life() -> void:
	for z in range(-194, 159, 24):
		if abs(z + 80) < 23:
			continue
		for side in [-1, 1]:
			_lamp(Vector3(side * 11.4, 0, z), side * PI / 2)
			_tree(Vector3(side * 18.2, 0, z + 9), 0.85 + posmod(roundi(float(z + 194) / 24.0) + side, 3) * 0.12)
			if posmod(z, 48) < 24 and not (side > 0 and z > 100 and z < 124):
				_bench(Vector3(side * 18.3, 0, z - 6), -side * PI / 2)
				_bin(Vector3(side * 18.3, 0, z - 9))
	for x in range(-132, 222, 24):
		if abs(x) < 32 or abs(x - 194) < 25:
			continue
		_lamp(Vector3(x, 0, -68.7), PI)
		_lamp(Vector3(x, 0, -91.3), 0)
		if x < 123:
			if x < 48 or x > 90:
				_tree(Vector3(x + 5, 0, -62), 1.0)
			_tree(Vector3(x + 5, 0, -98), 1.0)
	# Inset drainage marks sit at the road edge, away from the walking route.
	for z in [102.0, 54.0, 6.0, -42.0, -114.0]:
		for side in [-1, 1]:
			var drain := Vector3(side * 9.4, 0.025, z)
			_g.box(drain, Vector3(0.7, 0.025, 1.15), "petrol")
			for slot in 5:
				_g.box(drain + Vector3(0, 0.02, -0.43 + slot * 0.215), Vector3(0.58, 0.02, 0.06), "concrete")
	for i in 5:
		_car(Vector3(-7.1, 0, 143 - i * 48), PI / 2, ["cream", "brick", "teal"][i % 3], true)
	for i in 4:
		_car(Vector3(7.2, 0, 69 - i * 43), -PI / 2, ["mustard", "cream", "petrol"][i % 3], true)
	_car(Vector3(86, 0, -87.5), 0, "brick", true)
	_car(Vector3(111, 0, -72.3), PI, "teal", true)
	_bus(Vector3(6.9, 0, 113), -PI / 2)
	# Cafe forecourt bounds end before the occupied block at z=106.
	_g.box(Vector3(37, -0.02, 81), Vector3(34, 0.04, 38), "stone")
	for z in [63.0, 98.0]:
		_planter(Vector3(46.5, 0, z), Vector3(6, 0.65, 2))
		_tree(Vector3(46.5, 0, z), 0.9, false)
		_bench(Vector3(46.5, 0, z + (3 if z < 80 else -3)), 0 if z < 80 else PI)
	_bike_rack(Vector3(32, 0, 64), 0)
	for i in 4:
		_bicycle(Vector3(27.5 + i * 3.0, 0, 64.35), 0, i)
	for z in [73.0, 85.0, 95.0]:
		for x in [28.0, 38.0]:
			_cafe_table(Vector3(x, 0, z))
	# Platform cafe furniture stands ahead of the facade and clear of the avenue route.
	for x in [69.0, 77.0, 85.0]:
		_cafe_table(Vector3(x, 0, -62.0))
	for x in [55.0, 96.0]:
		_tree(Vector3(x, 0, -61.8), 0.85)
	_menu_board(Vector3(23.5, 0, 79.0), -PI / 2)
	_menu_board(Vector3(90.0, 0, -61.0), PI)
	_paving_patch(Vector3(33, 0, 84), 21, 31)
	_paving_patch(Vector3(77, 0, -62), 22, 5)
	for o in [Vector3(-18, 0, -64), Vector3(18, 0, -96), Vector3(27, 0, -63), Vector3(-27, 0, -98)]:
		_traffic_signal(o)
	for z in [-157.0, -5.0, 145.0]:
		for side in [-1, 1]:
			_planter(Vector3(side * 26, 0, z + 21), Vector3(6, 0.7, 2))
			_bench(Vector3(side * 26, 0, z + 18), 0)
	# A compact service kiosk and courtyard pergola add accessible side destinations.
	_kiosk(Vector3(-24, 0, 99), PI / 2)
	for x in [59.0, 86.0]:
		_tree(Vector3(x, 0, 58), 1.25)
		_bench(Vector3(x, 0, 54), 0)
	for x in [66.0, 76.0]:
		for z in [51.0, 60.0]:
			_g.box(Vector3(x, 1.8, z), Vector3(0.2, 3.6, 0.2), "wood")
			_g.solid(Vector3(x, 1.8, z), Vector3(0.22, 3.6, 0.22))
	for x in range(65, 78):
		_g.box(Vector3(x, 3.65, 55.5), Vector3(0.14, 0.22, 11), "wood")
	for z in [51.0, 60.0]:
		_g.box(Vector3(71, 3.45, z), Vector3(11.7, 0.35, 0.24), "wood")
	for x in [66.0, 76.0]:
		_g.box(Vector3(x, 3.4, 55.5), Vector3(0.24, 0.3, 10.5), "wood")
	_g.box(Vector3(71, 0.012, 55.5), Vector3(14, 0.024, 9), "stone")
	_bench(Vector3(71, 0, 52), 0)
	_planter(Vector3(71, 0, 59.5), Vector3(6.5, 0.55, 1.1))

func _lamp(o: Vector3, r: float) -> void:
	_c(o, r, Vector3(0, 0.12, 0), 0.27, 0.24, "stone")
	_c(o, r, Vector3(0, 0.52, 0), 0.14, 0.75, "petrol")
	_c(o, r, Vector3(0, 3.4, 0), 0.075, 6.4, "petrol")
	_b(o, r, Vector3(0, 6.45, 0.63), Vector3(0.12, 0.14, 1.4), "petrol")
	_rod(o, r, Vector3(0, 5.94, 0), Vector3(0, 6.45, 1.03), 0.038, "petrol")
	_b(o, r, Vector3(0, 6.38, 1.36), Vector3(0.60, 0.19, 0.86), "petrol")
	_b(o, r, Vector3(0, 6.24, 1.36), Vector3(0.46, 0.09, 0.68), "cream")
	_b(o, r, Vector3(0, 1.15, 0.087), Vector3(0.07, 0.18, 0.025), "steel")
	_s(o, r, Vector3(0, 1.6, 0), Vector3(0.22, 3.2, 0.22))

func _tree(o: Vector3, scale_value: float, grate := true) -> void:
	if grate:
		_g.box(o + Vector3(0, 0.045, 0), Vector3(2.2, 0.09, 2.2), "stone")
		_g.box(o + Vector3(0, 0.098, 0), Vector3(1.9, 0.015, 1.9), "dark")
		for i in 5:
			_g.box(o + Vector3(-0.8 + i * 0.4, 0.115, 0), Vector3(0.055, 0.02, 1.8), "steel")
	var variety := posmod(roundi(o.x * 3.0 + o.z), 3)
	var trunk_top := Vector3(0.12 if variety == 1 else -0.08, 3.5, 0.06) * scale_value
	_rod(o, 0, Vector3.ZERO, trunk_top, 0.16 * scale_value, "wood")
	_g.cone(o + Vector3(0, 0.38, 0) * scale_value, 0.26 * scale_value, 0.76 * scale_value, "wood")
	_g.solid(o + Vector3(0, 1.5 * scale_value, 0), Vector3(0.4, 3, 0.4) * scale_value)
	var reach := 1.35 if variety == 0 else (1.04 if variety == 1 else 1.52)
	for i in 5:
		var angle := i * TAU / 5 + variety * 0.41
		var branch_end := Vector3(cos(angle) * reach, 4.05 + (i % 2) * 0.42, sin(angle) * reach) * scale_value
		_rod(o, 0, trunk_top * 0.76, branch_end, 0.07 * scale_value, "wood")
		var crown := Vector3(2.75, 2.1, 2.5) if variety == 0 else (Vector3(2.1, 3.5, 2.0) if variety == 1 else Vector3(2.85, 2.55, 2.8))
		_g.ellipsoid(o + branch_end + Vector3(0, 0.6, 0) * scale_value, crown * scale_value, "leaf" if i % 3 != 0 else "leaf_light")
	_g.ellipsoid(o + Vector3(0.15, 5.65 if variety != 1 else 6.1, 0) * scale_value, Vector3(2.5, 2.3, 2.3) * scale_value, "leaf_dark")

func _bench(o: Vector3, r: float) -> void:
	for n in 4:
		_b(o, r, Vector3(0, 0.52, -0.31 + n * 0.19), Vector3(2.5, 0.08, 0.14), "wood")
	for n in 3:
		_b(o, r, Vector3(0, 0.78 + n * 0.19, -0.39), Vector3(2.5, 0.12, 0.09), "wood")
	for x in [-0.94, 0.94]:
		_b(o, r, Vector3(x, 0.3, 0), Vector3(0.12, 0.6, 0.65), "petrol")
		_b(o, r, Vector3(x, 0.8, -0.37), Vector3(0.1, 0.9, 0.1), "petrol")
		_b(o, r, Vector3(x, 0.77, 0), Vector3(0.12, 0.08, 0.6), "petrol")
	_s(o, r, Vector3(0, 0.6, -0.04), Vector3(2.5, 1.2, 0.8))

func _bin(o: Vector3) -> void:
	_g.cylinder(o + Vector3(0, 0.52, 0), 0.30, 1.04, "petrol")
	_g.cylinder(o + Vector3(0, 0.08, 0), 0.33, 0.16, "steel")
	_g.cylinder(o + Vector3(0, 1.08, 0), 0.35, 0.12, "steel")
	_g.box(o + Vector3(0, 0.88, 0.305), Vector3(0.31, 0.16, 0.04), "dark")
	for i in 8:
		var angle := i * TAU / 8
		_g.cylinder(o + Vector3(cos(angle) * 0.305, 0.48, sin(angle) * 0.305), 0.013, 0.69, "steel")
	_g.solid(o + Vector3(0, 0.55, 0), Vector3(0.66, 1.1, 0.66))

func _planter(o: Vector3, size: Vector3) -> void:
	_g.box(o + Vector3(0, size.y / 2, 0), size, "stone")
	_g.box(o + Vector3(0, size.y + 0.035, 0), Vector3(size.x + 0.12, 0.12, size.z + 0.12), "cream")
	_g.box(o + Vector3(0, size.y + 0.11, 0), Vector3(size.x - 0.28, 0.04, size.z - 0.28), "dark")
	_g.solid(o + Vector3(0, size.y / 2, 0), size)
	for x in range(-int(size.x / 2) + 1, int(size.x / 2)):
		_g.ellipsoid(o + Vector3(x, size.y + 0.46, 0), Vector3(1.35, 0.85, size.z * 0.78), "leaf")
		if posmod(x + roundi(o.z), 3) == 0:
			_g.ellipsoid(o + Vector3(x + 0.15, size.y + 0.82, 0.12), Vector3(0.25, 0.18, 0.28), "flower")

func _cafe_table(o: Vector3) -> void:
	var variety := posmod(roundi(o.x + o.z), 3)
	_g.cylinder(o + Vector3(0, 0.78, 0), 0.74, 0.1, "wood")
	_g.cylinder(o + Vector3(0, 0.714, 0), 0.68, 0.035, "petrol")
	_g.cylinder(o + Vector3(0, 0.37, 0), 0.065, 0.72, "petrol")
	for leg in 3:
		var angle := leg * TAU / 3
		_rod(o, 0, Vector3(0, 0.21, 0), Vector3(cos(angle) * 0.47, 0.06, sin(angle) * 0.47), 0.035, "petrol")
	_g.solid(o + Vector3(0, 0.44, 0), Vector3(1.45, 0.88, 1.45))
	for side in [-1, 1]:
		_cafe_chair(o + Vector3(0, 0, side * 1.3), PI if side > 0 else 0, "teal" if variety != 1 else "cream")
	for x in [-0.27, 0.27]:
		_g.cylinder(o + Vector3(x, 0.843, 0), 0.12, 0.025, "cream")
		_g.cylinder(o + Vector3(x, 0.91, 0), 0.078, 0.12, "cream")
		_g.cylinder(o + Vector3(x, 0.974, 0), 0.058, 0.006, "wood")
		_g.torus(o + Vector3(x + 0.098, 0.91, 0), 0.025, 0.04, "cream", Vector3(PI / 2, 0, 0))
	_g.box(o + Vector3(0.16, 0.844, 0.31), Vector3(0.28, 0.02, 0.28), "cream")
	_g.ellipsoid(o + Vector3(0.16, 0.89, 0.31), Vector3(0.2, 0.10, 0.16), "mustard")
	_umbrella(o, variety)

func _cafe_chair(o: Vector3, r: float, color: String) -> void:
	for slat in 4:
		_b(o, r, Vector3(0, 0.47, -0.23 + slat * 0.15), Vector3(0.59, 0.07, 0.115), color)
	for side in [-1, 1]:
		_rod(o, r, Vector3(side * 0.25, 0.05, 0.29), Vector3(side * 0.25, 0.50, 0.20), 0.023, "petrol")
		_rod(o, r, Vector3(side * 0.25, 0.05, -0.3), Vector3(side * 0.25, 1.02, -0.35), 0.023, "petrol")
		_rod(o, r, Vector3(side * 0.25, 0.3, -0.29), Vector3(side * 0.25, 0.3, 0.23), 0.019, "petrol")
	for slat in 3:
		_b(o, r, Vector3(0, 0.72 + slat * 0.12, -0.34), Vector3(0.60, 0.075, 0.065), color)
	_s(o, r, Vector3(0, 0.5, -0.04), Vector3(0.66, 1, 0.7))

func _entry_canopy(o: Vector3, r: float, p: Vector3, kind: int) -> void:
	_g.prism(_p(o, r, p), PackedVector2Array(CANOPY_PROFILE), 2.0, "petrol" if kind % 2 == 0 else "mustard", Vector3(0, r, 0))
	for side in [-1, 1]:
		_b(o, r, p + Vector3(side * 1.35, -0.36, -0.6), Vector3(0.12, 0.65, 0.85), "cream")

func _awning(o: Vector3, r: float, p: Vector3, width: float, kind: int) -> void:
	var stripe_width := width / 12.0
	var accent: String = ["petrol", "brick", "teal", "mustard"][kind]
	var slope := (Basis(Vector3.UP, r) * Basis(Vector3.RIGHT, 0.16)).get_euler()
	for i in 12:
		var x := -width * 0.5 + stripe_width * (i + 0.5)
		var color := accent if i % 2 == 0 else "cream"
		_g.box(_p(o, r, p + Vector3(x, 0, 0)), Vector3(stripe_width, 0.12, 1.9), color, slope)
		_b(o, r, p + Vector3(x, -0.28, 0.95), Vector3(stripe_width, 0.30, 0.10), color)
	for side in [-1, 1]:
		_b(o, r, p + Vector3(side * (width * 0.5 - 0.1), -0.25, -0.55), Vector3(0.10, 0.50, 0.7), "petrol")

func _flower_box(o: Vector3, r: float, p: Vector3, width: float) -> void:
	_b(o, r, p, Vector3(width, 0.30, 0.42), "brick")
	_b(o, r, p + Vector3(0, 0.16, 0), Vector3(width - 0.12, 0.05, 0.30), "dark")
	for i in 3:
		var center := p + Vector3((i - 1) * width * 0.28, 0.33, 0)
		_g.ellipsoid(_p(o, r, center), Vector3(0.65, 0.40, 0.56), "leaf")
		_g.ellipsoid(_p(o, r, center + Vector3(0.1, 0.18, 0.06)), Vector3(0.19, 0.16, 0.19), "flower" if i % 2 == 0 else "mustard")

func _umbrella(o: Vector3, kind: int) -> void:
	_g.cylinder(o + Vector3(0, 0.075, 0), 0.27, 0.15, "stone")
	_g.cylinder(o + Vector3(0, 1.64, 0), 0.035, 3.25, "wood")
	var fabric := "cream" if kind == 0 else ("sand" if kind == 1 else "mint")
	_g.cone(o + Vector3(0, 2.91, 0), 1.78, 0.64, fabric)
	for rib in 9:
		var angle := rib * TAU / 9
		var next_angle := (rib + 1) * TAU / 9
		var edge := Vector3(cos(angle) * 1.78, 2.59, sin(angle) * 1.78)
		var next_edge := Vector3(cos(next_angle) * 1.78, 2.59, sin(next_angle) * 1.78)
		_rod(o, 0, Vector3(0, 3.24, 0), edge, 0.012, "cream")
		_rod(o, 0, edge, next_edge, 0.045, "brick" if kind == 0 else "petrol")
	_g.cylinder(o + Vector3(0, 3.28, 0), 0.07, 0.14, "petrol")

func _menu_board(o: Vector3, r: float) -> void:
	for side in [-1, 1]:
		_b(o, r, Vector3(side * 0.49, 0.78, 0), Vector3(0.10, 1.56, 0.65), "wood")
	_b(o, r, Vector3(0, 0.98, 0.25), Vector3(1.12, 1.28, 0.16), "wood")
	_b(o, r, Vector3(0, 0.98, 0.35), Vector3(0.95, 1.10, 0.08), "petrol")
	_sign(o, r, Vector3(0, 0.98, 0.41), "КОФЕ\nХЛЕБ\nЗАВТРАК", 28, "cream", 0.01, 0.78, 0.87, "CafeMenuText")
	_s(o, r, Vector3(0, 0.75, 0), Vector3(1.2, 1.5, 0.75))

func _paving_patch(o: Vector3, columns: int, rows: int) -> void:
	# Raised by only millimetres above the courtyard slab, never coplanar.
	for row in rows:
		for column in columns:
			var p := o + Vector3((column - (columns - 1) * 0.5) * 0.86, 0.025, (row - (rows - 1) * 0.5) * 0.86)
			_g.box(p, Vector3(0.82, 0.02, 0.82), "cream" if (column + row) % 4 == 0 else "concrete")

func _direction_sign(o: Vector3, turn: bool) -> void:
	_g.cylinder(o + Vector3(0, 2.1, 0), 0.065, 4.2, "petrol", Vector3.ZERO)
	_g.box(o + Vector3(0, 3.5, 0), Vector3(3.9, 1.05, 0.24), "cream")
	for side in [-1, 1]:
		_g.box(o + Vector3(0, 3.5, side * 0.16), Vector3(3.72, 0.89, 0.08), "petrol")
	var text := "Центральный проспект, 18\nLATENT SYSTEMS   →" if turn else "LATENT SYSTEMS\nЦентральный проспект, 18   ↑"
	var reverse_text := "Центральный проспект, 18\n←   LATENT SYSTEMS" if turn else "LATENT SYSTEMS\n↓   Центральный проспект, 18"
	_sign(o, 0, Vector3(0, 3.5, 0.23), text, 30, "cream", 0.01, 3.30, 0.68, "DirectionSignText")
	_sign(o, PI, Vector3(0, 3.5, 0.23), reverse_text, 30, "cream", 0.01, 3.30, 0.68, "DirectionSignBackText")
	_g.solid(o + Vector3(0, 1.2, 0), Vector3(0.18, 2.4, 0.18))

func _traffic_signal(o: Vector3) -> void:
	_g.cylinder(o + Vector3(0, 1.8, 0), 0.07, 3.6, "petrol", Vector3.ZERO)
	_g.box(o + Vector3(0, 3.2, 0), Vector3(0.4, 0.9, 0.3), "dark")
	for n in 3:
		_g.cylinder(o + Vector3(0, 3.47 - n * 0.27, 0.18), 0.105, 0.06, ["brick", "mustard", "leaf"][n], Vector3(PI / 2, 0, 0))
	_g.solid(o + Vector3(0, 1.5, 0), Vector3(0.18, 3, 0.18))

func _stop(o: Vector3) -> void:
	var r := -PI / 2
	for x in [-3.5, 3.5]:
		for z in [-0.95, 0.95]:
			_b(o, r, Vector3(x, 1.4, z), Vector3(0.12, 2.8, 0.12), "petrol")
			_s(o, r, Vector3(x, 1.4, z), Vector3(0.15, 2.8, 0.15))
	_b(o, r, Vector3(0, 1.45, -0.98), Vector3(7, 2.5, 0.12), "glass")
	_s(o, r, Vector3(0, 1.45, -0.98), Vector3(7, 2.5, 0.12))
	_g.prism(_p(o, r, Vector3(0, 2.8, 0)), PackedVector2Array(CANOPY_PROFILE), 7.6, "cream", Vector3(0, r + PI / 2, 0))
	_b(o, r, Vector3(0, 3.08, 1.03), Vector3(7.3, 0.5, 0.16), "petrol")
	_sign(o, r, Vector3(0, 3.1, 1.13), "ПАРКОВАЯ  /  04 · 18 · 27", 32, "cream", 0.012, 6.85, 0.34, "StopSignText")
	_bench(_p(o, r, Vector3(-0.9, 0, -0.4)), r)
	_b(o, r, Vector3(2.6, 1.65, -0.85), Vector3(1.05, 1.35, 0.12), "cream")
	_sign(o, r, Vector3(2.6, 1.85, -0.76), "МАРШРУТ 18\n08:12  08:24\n08:36  08:48", 22, "petrol", 0.012, 0.86, 0.75, "TimetableText")
	# Route diagram below the timetable; it must not cross the bottom text row.
	_b(o, r, Vector3(2.6, 1.21, -0.76), Vector3(0.70, 0.025, 0.03), "teal")
	for i in 4:
		_c(o, r, Vector3(2.30 + i * 0.20, 1.21, -0.73), 0.035, 0.025, "petrol", Vector3(PI / 2, 0, 0))
	_bin(_p(o, r, Vector3(4.4, 0, 0)))
	_c(o, r, Vector3(-4.3, 1.8, 0.9), 0.07, 3.6, "petrol")
	_b(o, r, Vector3(-4.3, 3.5, 0.9), Vector3(0.85, 0.85, 0.2), "mustard")
	_sign(o, r, Vector3(-4.3, 3.5, 1.02), "18", 52, "petrol", 0.012, 0.62, 0.62, "StopNumberText")

func _kiosk(o: Vector3, r: float) -> void:
	_b(o, r, Vector3(0, 1.5, 0), Vector3(5.2, 3.0, 3.3), "cream")
	_s(o, r, Vector3(0, 1.5, 0), Vector3(5.2, 3.0, 3.3))
	_b(o, r, Vector3(0, 1.7, 1.73), Vector3(3.8, 1.6, 0.16), "glass")
	_b(o, r, Vector3(0, 0.83, 2), Vector3(4.5, 0.15, 0.75), "wood")
	for i in 6:
		_b(o, r, Vector3(-1.6 + i * 0.63, 1.3, 1.86), Vector3(0.45, 0.65, 0.08), ["mustard", "brick", "teal"][i % 3])
	_b(o, r, Vector3(0, 3.15, 0), Vector3(5.8, 0.3, 4), "petrol")
	_b(o, r, Vector3(0, 2.8, 1.81), Vector3(4.6, 0.45, 0.14), "petrol")
	_sign(o, r, Vector3(0, 2.8, 1.90), "ГАЗЕТЫ / ЖУРНАЛЫ", 28, "cream", 0.012, 4.15, 0.29, "KioskSignText")

func _plaza() -> void:
	_g.box(Vector3(148, -0.013, -80), Vector3(50, 0.05, 36), "stone")
	for x in range(125, 173, 4):
		_g.box(Vector3(x, 0.015, -80), Vector3(0.035, 0.01, 36), "concrete")
	for z in range(-96, -63, 4):
		_g.box(Vector3(148, 0.015, z), Vector3(50, 0.01, 0.035), "concrete")
	# Raised planting and seating bound the plaza while keeping both diagonal approaches open.
	for x in [132.0, 151.0, 168.0]:
		for z in [-95.0, -62.5]:
			_planter(Vector3(x, 0, z), Vector3(5.5, 0.65, 2.2))
			_tree(Vector3(x, 0, z), 1.0, false)
		_bench(Vector3(x, 0, -91.5), 0)
		_bench(Vector3(x, 0, -60), PI)
		_lamp(Vector3(x + 6, 0, -94), 0)
	_bin(Vector3(160, 0, -90))
	# Interlocking bronze-and-painted rings give the civic sculpture its "connection" theme.
	_g.cylinder(Vector3(140, 0.26, -84), 1.35, 0.52, "stone")
	_g.cylinder(Vector3(140, 0.55, -84), 0.95, 0.10, "steel")
	_g.torus(Vector3(139.6, 1.85, -84), 0.65, 0.84, "mustard", Vector3(PI / 2, 0.0, -0.18))
	_g.torus(Vector3(140.45, 2.05, -84.08), 0.65, 0.84, "accent_magenta", Vector3(PI / 2, 0.42, 0.16))
	_rod(Vector3.ZERO, 0, Vector3(139.58, 0.56, -84), Vector3(139.6, 1.19, -84), 0.055, "steel")
	_rod(Vector3.ZERO, 0, Vector3(140.43, 0.56, -84), Vector3(140.45, 1.37, -84.08), 0.055, "steel")
	_g.solid(Vector3(140, 0.8, -84), Vector3(2.7, 1.6, 2.7))
	_g.box(Vector3(140, 0.75, -82.77), Vector3(2.15, 0.65, 0.12), "cream")
	_sign(Vector3.ZERO, 0, Vector3(140, 0.75, -82.69), "СВЯЗЬ\nгородская скульптура", 22, "petrol", 0.009, 1.90, 0.47, "SculpturePlaqueText")
	for z in [-89.0, -71.0]:
		var sign_origin := Vector3(168.8, 0, z)
		# Both entrance totems face west toward the plaza, not across the approach.
		_b(sign_origin, -PI / 2, Vector3(0, 1.15, 0), Vector3(1.3, 2.3, 0.32), "petrol")
		_sign(sign_origin, -PI / 2, Vector3(0, 1.45, 0.19), "LATENT\nSYSTEMS\n18", 30, "cream", 0.01, 1.02, 1.35, "PlazaSignText")
		_s(sign_origin, -PI / 2, Vector3(0, 1.15, 0), Vector3(1.3, 2.3, 0.32))

func _car(o: Vector3, r: float, color: String, collision: bool, g = null) -> void:
	var target = _g if g == null else g
	var wagon := posmod(roundi(o.x + o.z), 3) == 1
	target.prism(_p(o, r, Vector3.ZERO), PackedVector2Array(CAR_BODY), 1.9, color, Vector3(0, r, 0))
	target.prism(_p(o, r, Vector3.ZERO), PackedVector2Array(WAGON_CABIN if wagon else CAR_CABIN), 1.56, "glass", Vector3(0, r, 0))
	var roof_y := 1.79 if wagon else 1.73
	var roof_x := -0.43 if wagon else -0.07
	_b(o, r, Vector3(roof_x, roof_y, 0), Vector3(2.3 if wagon else 1.72, 0.10, 1.68), color, target)
	_b(o, r, Vector3(0, 0.61, 0), Vector3(4.15, 0.13, 1.65), "dark", target)
	for side in [-1, 1]:
		for x in [-1.45, 1.45]:
			_c(o, r, Vector3(x, 0.45, side * 0.98), 0.43, 0.25, "dark", Vector3(PI / 2, 0, 0), target)
			_c(o, r, Vector3(x, 0.45, side * 1.12), 0.26, 0.035, "steel", Vector3(PI / 2, 0, 0), target)
			_c(o, r, Vector3(x, 0.45, side * 1.147), 0.105, 0.028, "petrol", Vector3(PI / 2, 0, 0), target)
			for bolt in 5:
				var angle := bolt * TAU / 5
				_c(o, r, Vector3(x + cos(angle) * 0.165, 0.45 + sin(angle) * 0.165, side * 1.15), 0.027, 0.015, "dark", Vector3(PI / 2, 0, 0), target)
		_b(o, r, Vector3(-0.13, 1.38, side * 0.805), Vector3(0.11, 0.66, 0.12), color, target)
		_rod(o, r, Vector3(0.71, roof_y - 0.02, side * 0.78), Vector3(1.32, 1.01, side * 0.78), 0.045, color, target)
		_rod(o, r, Vector3(-1.55 if wagon else -0.85, roof_y - 0.02, side * 0.78), Vector3(-1.82 if wagon else -1.4, 1.01, side * 0.78), 0.045, color, target)
		_b(o, r, Vector3(0, 1.04, side * 0.82), Vector3(2.85, 0.065, 0.11), "steel", target)
		_b(o, r, Vector3(0.86, 1.17, side * 1.0), Vector3(0.31, 0.16, 0.27), color, target)
		_b(o, r, Vector3(0.86, 1.17, side * 1.146), Vector3(0.25, 0.11, 0.025), "steel", target)
		for x in [-0.89, 0.38]:
			_b(o, r, Vector3(x, 0.95, side * 0.973), Vector3(0.26, 0.055, 0.045), "steel", target)
		_b(o, r, Vector3(-0.22, 0.82, side * 0.966), Vector3(0.018, 0.27, 0.018), "petrol", target)
		_b(o, r, Vector3(0, 0.66, side * 0.974), Vector3(4.0, 0.045, 0.028), "petrol", target)
		if wagon:
			_b(o, r, Vector3(-0.47, roof_y + 0.12, side * 0.61), Vector3(2.15, 0.075, 0.07), "steel", target)
	for x in [-2.31, 2.31]:
		_b(o, r, Vector3(x, 0.59, 0), Vector3(0.13, 0.17, 1.97), "steel", target)
		for z in [-0.62, 0.62]:
			_b(o, r, Vector3(x, 0.80, z), Vector3(0.075, 0.19, 0.39), "cream" if x > 0 else "red", target)
		_b(o, r, Vector3(x * 1.032, 0.61, 0), Vector3(0.035, 0.13, 0.48), "white", target)
	_b(o, r, Vector3(2.35, 0.79, 0), Vector3(0.045, 0.19, 0.65), "petrol", target)
	for z in [-0.22, 0.0, 0.22]:
		_b(o, r, Vector3(2.38, 0.79, z), Vector3(0.025, 0.13, 0.025), "steel", target)
	_rod(o, r, Vector3(1.18, 1.11, -0.40), Vector3(0.95, 1.35, -0.03), 0.016, "petrol", target)
	_rod(o, r, Vector3(1.18, 1.11, 0.36), Vector3(0.95, 1.35, 0.62), 0.016, "petrol", target)
	if collision:
		_s(o, r, Vector3(0, 0.85, 0), Vector3(4.75, 1.7, 2.25))

func _bus(o: Vector3, r: float) -> void:
	_b(o, r, Vector3(0, 1.55, 0), Vector3(10.7, 2.5, 2.5), "cream")
	_b(o, r, Vector3(0, 0.8, 0), Vector3(10.85, 0.65, 2.55), "teal")
	_b(o, r, Vector3(0, 2.87, 0), Vector3(10.3, 0.22, 2.6), "petrol")
	for side in [-1, 1]:
		for i in 7:
			_b(o, r, Vector3(-4.35 + i * 1.4, 1.95, side * 1.29), Vector3(1.15, 1.3, 0.16), "glass")
		for x in [-3.4, 3.4]:
			_c(o, r, Vector3(x, 0.61, side * 1.23), 0.58, 0.28, "dark", Vector3(PI / 2, 0, 0))
			_c(o, r, Vector3(x, 0.61, side * 1.4), 0.3, 0.025, "cream", Vector3(PI / 2, 0, 0))
		_b(o, r, Vector3(3.8, 1.4, side * 1.39), Vector3(1.35, 2.15, 0.12), "petrol")
		for x in [3.45, 4.13]:
			_b(o, r, Vector3(x, 1.6, side * 1.47), Vector3(0.56, 1.6, 0.05), "glass")
	_b(o, r, Vector3(5.43, 1.9, 0), Vector3(0.13, 1.25, 2.25), "glass")
	_b(o, r, Vector3(5.46, 2.65, 0), Vector3(0.12, 0.35, 2.2), "dark")
	_g.label("18  ЦЕНТРАЛЬНЫЙ", _p(o, r, Vector3(5.54, 2.65, 0)), 26, "mustard", Vector3(0, r + PI / 2, 0), 0.009, 1.96, 0.25).name = "BusDestinationText"
	for z in [-0.88, 0.88]:
		_b(o, r, Vector3(5.47, 0.95, z), Vector3(0.09, 0.26, 0.3), "white")
	_b(o, r, Vector3(0, 3.05, 0), Vector3(2.8, 0.35, 1.6), "concrete")
	_s(o, r, Vector3(0, 1.5, 0), Vector3(10.9, 3, 2.8))

func _bike_rack(o: Vector3, r: float) -> void:
	for slot in 4:
		var x := -4.5 + slot * 3.0
		for side in [-1, 1]:
			_c(o, r, Vector3(x + side * 0.5, 0.37, 0), 0.04, 0.74, "steel")
			_rod(o, r, Vector3(x + side * 0.5, 0.74, 0), Vector3(x + side * 0.36, 0.88, 0), 0.04, "steel")
			_b(o, r, Vector3(x + side * 0.5, 0.035, 0), Vector3(0.22, 0.07, 0.3), "petrol")
		_rod(o, r, Vector3(x - 0.36, 0.88, 0), Vector3(x + 0.36, 0.88, 0), 0.04, "steel")
		_s(o, r, Vector3(x, 0.44, 0), Vector3(1.08, 0.88, 0.18))
	_b(o, r, Vector3(6.0, 0.73, 0), Vector3(0.07, 1.46, 0.07), "petrol")
	_b(o, r, Vector3(6.0, 1.33, 0), Vector3(0.57, 0.48, 0.08), "cream")
	_sign(o, r, Vector3(6.0, 1.33, 0.055), "ВЕЛО", 20, "petrol", 0.010, 0.44, 0.28, "BikeRackText")

func _bicycle(o: Vector3, r: float, kind: int) -> void:
	var paint: String = ["accent_magenta", "petrol", "accent_violet", "terracotta"][kind % 4]
	for x in [-0.84, 0.84]:
		var hub := Vector3(x, 0.425, 0)
		_ring(o, r, hub, 0.35, 0.415, "dark")
		_ring(o, r, hub, 0.328, 0.35, "steel")
		_c(o, r, hub, 0.052, 0.17, "steel", Vector3(PI / 2, 0, 0))
		for spoke in 12:
			var angle := spoke * TAU / 12
			var rim := hub + Vector3(cos(angle) * 0.337, sin(angle) * 0.337, 0)
			_rod(o, r, hub + Vector3(0, 0, 0.045 if spoke % 2 == 0 else -0.045), rim, 0.006, "steel")
	var seat_joint := Vector3(-0.18, 0.97, 0)
	var crank := Vector3(0.10, 0.40, 0)
	var head := Vector3(0.56, 1.02, 0)
	_rod(o, r, seat_joint, crank, 0.028, paint)
	_rod(o, r, seat_joint, head, 0.028, paint)
	_rod(o, r, head, crank, 0.028, paint)
	for side in [-1, 1]:
		var rear := Vector3(-0.84, 0.425, side * 0.075)
		_rod(o, r, seat_joint, rear, 0.02, paint)
		_rod(o, r, crank + Vector3(0, 0, side * 0.075), rear, 0.02, paint)
		_rod(o, r, head + Vector3(0, 0, side * 0.07), Vector3(0.84, 0.425, side * 0.07), 0.025, "steel")
	_rod(o, r, seat_joint, Vector3(-0.23, 1.14, 0), 0.025, "steel")
	_b(o, r, Vector3(-0.23, 1.16, 0), Vector3(0.36, 0.075, 0.23), "wood")
	_rod(o, r, head, Vector3(0.5, 1.20, 0), 0.025, "steel")
	_rod(o, r, Vector3(0.5, 1.20, -0.29), Vector3(0.5, 1.20, 0.29), 0.022, "steel")
	for side in [-1, 1]:
		_rod(o, r, Vector3(0.5, 1.20, side * 0.29), Vector3(0.38, 1.18, side * 0.29), 0.029, "petrol")
		_rod(o, r, crank + Vector3(0, 0, side * 0.12), crank + Vector3(side * 0.13, side * 0.10, side * 0.12), 0.018, "steel")
		_b(o, r, crank + Vector3(side * 0.13, side * 0.10, side * 0.19), Vector3(0.13, 0.045, 0.14), "petrol")
	_ring(o, r, crank + Vector3(0, 0, 0.10), 0.075, 0.105, "steel")
	_rod(o, r, Vector3(-0.84, 0.48, 0.10), Vector3(0.1, 0.50, 0.10), 0.009, "petrol")
	_rod(o, r, Vector3(-0.84, 0.37, 0.10), Vector3(0.1, 0.30, 0.10), 0.009, "petrol")
	_rod(o, r, crank + Vector3(0, 0, -0.08), Vector3(-0.16, 0.03, -0.21), 0.018, "steel")
	_b(o, r, Vector3(-0.82, 0.82, 0), Vector3(0.55, 0.05, 0.3), "steel")
	for side in [-1, 1]:
		_rod(o, r, Vector3(-0.84, 0.425, side * 0.075), Vector3(-1.03, 0.80, side * 0.13), 0.015, "steel")
	if kind == 1:
		_b(o, r, Vector3(-0.9, 0.97, 0.19), Vector3(0.4, 0.28, 0.16), "wood")
		_b(o, r, Vector3(-0.9, 1.12, 0.19), Vector3(0.43, 0.045, 0.18), "petrol")
	_c(o, r, Vector3(0.66, 1.05, 0), 0.048, 0.08, "cream", Vector3(0, 0, PI / 2))
	_b(o, r, Vector3(-1.04, 0.82, 0), Vector3(0.055, 0.07, 0.1), "red")
	_s(o, r, Vector3(0, 0.59, 0), Vector3(2.52, 1.18, 0.65))

func _routes() -> void:
	pedestrian_routes = [
		[Vector3(13, 0, 146), Vector3(13, 0, 83), Vector3(13, 0, 15), Vector3(13, 0, -55)],
		[Vector3(16, 0, 93), Vector3(16, 0, 32), Vector3(16, 0, -44)],
		[Vector3(-14, 0, 147), Vector3(-14, 0, 68), Vector3(-14, 0, -54)],
		[Vector3(-16, 0, -155), Vector3(-16, 0, -112), Vector3(-16, 0, -99)],
		[Vector3(14, 0, -64), Vector3(3, 0, -64), Vector3(-14, 0, -64), Vector3(-14, 0, -48)],
		[Vector3(26, 0, -65), Vector3(26, 0, -95), Vector3(72, 0, -95)],
		[Vector3(35, 0, -66), Vector3(84, 0, -66), Vector3(122, 0, -66), Vector3(153, 0, -70)],
		[Vector3(44, 0, -94), Vector3(90, 0, -94), Vector3(117, 0, -94)],
		[Vector3(128, 0, -72), Vector3(147, 0, -74), Vector3(165, 0, -80), Vector3(149, 0, -88), Vector3(129, 0, -88)],
		[Vector3(-105, 0, -66), Vector3(-59, 0, -66), Vector3(-31, 0, -66)],
		[Vector3(14, 0, -105), Vector3(14, 0, -147), Vector3(14, 0, -193)]
	]

func _background_traffic() -> void:
	for i in 2:
		var model = Geometry.new()
		model.name = "GentleTraffic%d" % i
		add_child(model)
		var r := PI / 2 if i == 0 else -PI / 2
		_car(Vector3.ZERO, r, "teal" if i == 0 else "cream", false, model)
		model.flush()
		model.position = Vector3(3.5 if i == 0 else -3.5, 0, 155 if i == 0 else -200)
		_traffic.append({"node": model, "speed": -6.0 if i == 0 else 5.5})

func _process(delta: float) -> void:
	for vehicle in _traffic:
		var node: Node3D = vehicle["node"]
		node.position.z += vehicle["speed"] * delta
		if node.position.z < -225:
			node.position.z = 180
		elif node.position.z > 180:
			node.position.z = -225
