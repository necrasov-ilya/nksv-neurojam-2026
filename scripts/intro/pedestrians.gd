extends Node3D
## Ordinary commuters: tailored articulated models, six shared instanced draws.
## Coordinates and motion stay local to this root, including elevated interiors.
const Geometry = preload("res://scripts/intro/geometry.gd")
const TICK := 1.0 / 20.0
const DRAW_DISTANCE := 125.0
const UPPER_LEG := 0.44
const LOWER_LEG := 0.44
const ANKLE_HEIGHT := 0.085
const SKIN := [Color("f1d6bd"), Color("eac9ac"), Color("efd0b8"), Color("e7c2a5"), Color("f3ddc9")]
const HAIR := [Color("302b29"), Color("594133"), Color("8c6741"), Color("b7a176"), Color("aba99e")]
enum Shape { BOX, ROUND, COLUMN, TORSO, SKIRT, HAT, COUNT }
enum Joint { ROOT, BODY, HEAD, LEFT_ARM, LEFT_FOREARM, RIGHT_ARM, RIGHT_FOREARM, LEFT_THIGH, LEFT_CALF, RIGHT_THIGH, RIGHT_CALF, LEFT_FOOT, RIGHT_FOOT, COUNT }

const CLEARANCE := 0.80
const BODY_RADIUS := 0.44
const MAX_LANE := 0.50
const STRIDE_LENGTH := 2.0 / 3.0
const SIDES := [-1, 1]
const CLOTHES := ["teal", "petrol", "mustard", "brick", "cream", "leaf", "concrete"]
const TROUSERS := ["dark", "petrol", "wood", "concrete"]
const TORSO_CENTER := Vector3(0, 1.255, 0)
const TORSO_SIZE := Vector3(0.445, 0.51, 0.27)
const TORSO_RINGS := [
	Vector3(-0.5, 0.88, 0.89), Vector3(-0.32, 0.88, 0.91),
	Vector3(0.18, 1.0, 1.0), Vector3(0.37, 0.99, 0.94),
	Vector3(0.5, 0.73, 0.79)
]
class Obstacle:
	var bounds: AABB
	var inverse: Transform3D
	var expanded: AABB

class Part:
	var shape: int
	var index: int
	var joint: int
	var local: Transform3D
	var color: Color

class Walker:
	var route: PackedVector3Array
	var target := 1
	var direction := 1
	var position := Vector3.ZERO
	var yaw := 0.0
	var speed := 1.0
	var phase := 0.0
	var wait := 0.0
	var height_scale := 1.0
	var width_scale := 1.0
	var looping := false
	var drawn := true
	var moving := false
	var parts: Array[Part] = []
	var joints: Array[Transform3D] = []
	var id := 0
	var stationary := false
	var route_position := Vector3.ZERO
	var lane := 0.38
	var lane_offset := Vector3.ZERO
	var desired_center := Vector3.ZERO
	var desired_offset := Vector3.ZERO
	var desired_position := Vector3.ZERO
	var heading := Vector3.FORWARD
	var desired_velocity := Vector3.ZERO
	var blocked := 0.0
	var bypass_remaining := 0.0
	var retreat_remaining := 0.0
	var bypass := 0.0
	var gait_weight := 0.0
	var idle_time := 0.0
	var has_case := false
	var previous_position := Vector3.ZERO
	var previous_yaw := 0.0
	var previous_phase := 0.0
	var previous_gait_weight := 0.0
	var previous_idle_time := 0.0
	var stride_scale := 1.0
	var posture := 0.0
	var idle_style := 0
	var left_plant := Vector3.ZERO
	var right_plant := Vector3.ZERO
	var left_cycle := -1.0
	var right_cycle := -1.0
	var planted := false
	var turning := false
	var failed_bypass := 0.0
	var bypass_cooldown := 0.0
	var gait_direction := 1.0

var _walkers: Array[Walker] = []
var _obstacles: Array[Obstacle] = []
var _batches: Array[MultiMesh] = []
var _batch_nodes: Array[MultiMeshInstance3D] = []
var _parts: Array[Array] = []
var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var population := 0

func _reset(seed_value: int) -> void:
	for node in _batch_nodes:
		node.queue_free()
	_batch_nodes.clear()
	_batches.clear()
	_walkers.clear()
	_parts.clear()
	population = 0
	_elapsed = 0.0
	_rng.seed = seed_value
	_obstacles.clear()
	for shape in Shape.COUNT:
		_parts.append([])

func _new_walker(index: int) -> Walker:
	var walker := Walker.new()
	walker.id = index
	walker.speed = _rng.randf_range(0.78, 1.16)
	walker.phase = _rng.randf_range(0.0, TAU)
	walker.idle_time = _rng.randf_range(0.0, 20.0)
	walker.stride_scale = _rng.randf_range(0.90, 1.10)
	walker.posture = _rng.randf_range(-0.018, 0.026)
	walker.idle_style = index % 4
	var model_height := 1.796
	if index % 6 == 0:
		model_height = 1.90
	elif index % 6 == 3:
		model_height = 1.841
	walker.height_scale = _rng.randf_range(1.66, 1.89) / model_height
	walker.width_scale = _rng.randf_range(0.90, 1.10)
	walker.lane = _rng.randf_range(0.43, 0.47)
	walker.joints.resize(Joint.COUNT)
	return walker

func populate(routes: Array, count: int, seed_value: int = 42) -> void:
	_reset(seed_value)
	var usable: Array[PackedVector3Array] = []
	for source in routes:
		var route := PackedVector3Array()
		for point in source:
			if point is Vector3 and (route.is_empty() or route[-1].distance_squared_to(point) > 0.0001):
				route.append(point)
		if route.size() >= 2:
			usable.append(route)
	if usable.is_empty() or count <= 0:
		set_process(false)
		return
	_collect_obstacles(get_parent(), usable)
	for index in count:
		var walker := _new_walker(index)
		walker.route = usable[index % usable.size()]
		walker.looping = walker.route[0].distance_squared_to(walker.route[-1]) < 0.0001
		walker.direction = -1 if not walker.looping and index % 2 == 1 else 1
		var length := 0.0
		for segment in range(1, walker.route.size()):
			length += walker.route[segment - 1].distance_to(walker.route[segment])
		# Reject occupied starting slots, including intersections between routes.
		# This runs only at population time, never in the animation tick.
		var placed := false
		for attempt in 160:
			var fraction := fmod(float(index) / float(count) + float(attempt) * 0.61803398875, 1.0)
			var distance := length * fraction
			for segment in range(1, walker.route.size()):
				var segment_length := walker.route[segment - 1].distance_to(walker.route[segment])
				if distance <= segment_length or segment == walker.route.size() - 1:
					walker.route_position = walker.route[segment - 1].lerp(walker.route[segment], clampf(distance / segment_length, 0.0, 1.0))
					walker.target = segment if walker.direction > 0 else segment - 1
					walker.heading = (walker.route[segment] - walker.route[segment - 1]).normalized() * walker.direction
					break
				distance -= segment_length
			walker.lane_offset = walker.heading.cross(Vector3.UP).normalized() * walker.lane
			walker.position = walker.route_position + walker.lane_offset
			var occupied := not _path_clear(walker.position, walker.position)
			for other in _walkers:
				if walker.position.distance_squared_to(other.position) < CLEARANCE * CLEARANCE:
					occupied = true
					break
			if not occupied:
				placed = true
				break
		if not placed:
			continue
		walker.yaw = atan2(-walker.heading.x, -walker.heading.z)
		_build_person(walker, index)
		_walkers.append(walker)
	_finish_population()

## One fixed civilian on a separate root; yaw PI faces +Z, like the receptionist.
func populate_stationary(p: Vector3, yaw: float = 0.0, appearance_id: int = 0) -> void:
	var appearance := maxi(0, appearance_id)
	_reset(42 + appearance)
	var walker := _new_walker(appearance)
	walker.stationary = true
	walker.position = p
	walker.route_position = p
	walker.yaw = yaw
	walker.heading = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	_build_person(walker, appearance)
	_walkers.append(walker)
	_finish_population()

func _finish_population() -> void:
	_build_batches()
	population = _walkers.size()
	for walker in _walkers:
		_snapshot(walker)
		_pose(walker, 1.0)
		_draw(walker)
	set_process(true)

func _collect_obstacles(node: Node, routes: Array[PackedVector3Array]) -> void:
	if node is CollisionShape3D and not node.disabled and node.shape is BoxShape3D:
		var obstacle := Obstacle.new()
		var transform_value: Transform3D = global_transform.affine_inverse() * node.global_transform
		obstacle.inverse = transform_value.affine_inverse()
		var size: Vector3 = node.shape.size
		# The torso envelope clears the floor but also catches low furniture.
		var padding := Vector3(BODY_RADIUS, 0.84, BODY_RADIUS)
		obstacle.expanded = AABB(-size * 0.5 - padding, size + padding * 2.0)
		obstacle.bounds = transform_value * obstacle.expanded
		# Keep only solids beside an authored segment; the ground, skyline and
		# remote furnishings must not be scanned for every pedestrian tick.
		var relevant := false
		for route in routes:
			for segment in range(1, route.size()):
				var start := route[segment - 1] + Vector3.UP * 0.92
				var finish := route[segment] + Vector3.UP * 0.92
				var corridor := AABB(start.min(finish), (finish - start).abs())
				corridor.position -= Vector3(MAX_LANE, 0.01, MAX_LANE)
				corridor.size += Vector3(MAX_LANE * 2.0, 0.02, MAX_LANE * 2.0)
				if obstacle.bounds.intersects(corridor):
					relevant = true
					break
			if relevant:
				break
		if relevant:
			_obstacles.append(obstacle)
	for child in node.get_children():
		if child != self:
			_collect_obstacles(child, routes)

func _path_clear(from: Vector3, to: Vector3) -> bool:
	var start := from + Vector3.UP * 0.92
	var finish := to + Vector3.UP * 0.92
	for obstacle in _obstacles:
		if not obstacle.bounds.has_point(start) and not obstacle.bounds.has_point(finish) and obstacle.bounds.intersects_segment(start, finish) == null:
			continue
		var local_start := obstacle.inverse * start
		var local_finish := obstacle.inverse * finish
		if obstacle.expanded.has_point(local_start) or obstacle.expanded.has_point(local_finish) or obstacle.expanded.intersects_segment(local_start, local_finish) != null:
			return false
	return true

func _material_color(name: String) -> Color:
	return Geometry.COLORS[name]

func _part(w: Walker, shape: int, joint: int, p: Vector3, size: Vector3, color: Color, rotation_value := Vector3.ZERO) -> void:
	var part := Part.new()
	part.shape = shape
	part.index = _parts[shape].size()
	part.joint = joint
	part.local = Transform3D(Basis.from_euler(rotation_value).scaled_local(size), p)
	part.color = color
	_parts[shape].append(part)
	w.parts.append(part)

func _shirt_front(height: float) -> float:
	var y := (height - TORSO_CENTER.y) / TORSO_SIZE.y
	for i in range(1, TORSO_RINGS.size()):
		var lower: Vector3 = TORSO_RINGS[i - 1]
		var upper: Vector3 = TORSO_RINGS[i]
		if y <= upper.x:
			var weight := clampf((y - lower.x) / (upper.x - lower.x), 0.0, 1.0)
			return -0.5 * TORSO_SIZE.z * lerpf(lower.z, upper.z, weight)
	return -0.5 * TORSO_SIZE.z * TORSO_RINGS[-1].z

func _shirt_detail(w: Walker, center: Vector2, size: Vector2, color: Color, angle := 0.0, thickness := 0.01, layer := 0.001) -> void:
	# These panels stay inside the flat front and follow its tapered profile.
	# Separate front layers; the backs remain embedded in the torso.
	var count := maxi(1, ceili(size.y / 0.045))
	var height := size.y / count
	for i in count:
		var along := -size.y * 0.5 + (i + 0.5) * height
		var point := center + Vector2(-sin(angle), cos(angle)) * along
		var half_height := height * cos(angle) * 0.5
		var top := _shirt_front(point.y + half_height)
		var bottom := _shirt_front(point.y - half_height)
		var slope := (top - bottom) / (height * cos(angle))
		_part(w, Shape.BOX, Joint.BODY,
			Vector3(point.x, point.y, (top + bottom) * 0.5 + thickness * 0.5 - layer),
			Vector3(size.x, height + 0.001, thickness), color,
			Vector3(atan(slope), 0, angle))

func _build_person(w: Walker, index: int) -> void:
	var skin: Color = SKIN[_rng.randi_range(0, SKIN.size() - 1)]
	var hair: Color = HAIR[_rng.randi_range(0, HAIR.size() - 1)]
	var coat := _material_color(CLOTHES[index % CLOTHES.size()])
	var trousers := _material_color(TROUSERS[index % TROUSERS.size()])
	var cream := _material_color("cream")
	var dark := _material_color("dark")
	var skirt := index % 5 == 2
	var jacket := index % 3 != 1
	var sleeve := coat
	# The shirt ends in a sloping shoulder seam, not two detached shoulder balls.
	# The shared profile has a flat shirt front, full chest and a fitted waist.
	_part(w, Shape.TORSO, Joint.BODY, TORSO_CENTER, TORSO_SIZE, coat)
	_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 0.97, 0.008), Vector3(0.36, 0.19, 0.26), trousers)
	_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 1.018, 0), Vector3(0.405, 0.027, 0.273), dark)
	_part(w, Shape.BOX, Joint.BODY, Vector3(0.015, 1.018, -0.13), Vector3(0.029, 0.024, 0.009), _material_color("mustard"))
	_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 1.525, 0.024), Vector3(0.09, 0.075, 0.09), skin)
	# One closed oval keeps the jaw continuous instead of a flat column
	# projecting through the cheeks. Features stay shallow and inset.
	_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, 0.018, 0.003), Vector3(0.235, 0.274, 0.225), skin)
	for side in SIDES:
		_part(w, Shape.ROUND, Joint.HEAD, Vector3(side * 0.113, 0.008, 0.007), Vector3(0.030, 0.060, 0.035), skin)
		_part(w, Shape.ROUND, Joint.HEAD, Vector3(side * 0.119, 0.011, -0.005), Vector3(0.012, 0.032, 0.012), skin.darkened(0.12))
		_part(w, Shape.ROUND, Joint.HEAD, Vector3(side * 0.043, 0.041, -0.102), Vector3(0.025, 0.010, 0.009), cream.darkened(0.12))
		_part(w, Shape.ROUND, Joint.HEAD, Vector3(side * 0.043, 0.041, -0.1075), Vector3(0.008, 0.008, 0.004), hair.darkened(0.35))
		_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.043, 0.047, -0.105), Vector3(0.027, 0.003, 0.004), skin.darkened(0.16))
		_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.043, 0.065, -0.100), Vector3(0.032, 0.005, 0.007), hair, Vector3(0, 0, side * 0.06))
	_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, 0.015, -0.109), Vector3(0.016, 0.047, 0.024), skin)
	_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, -0.004, -0.116), Vector3(0.027, 0.021, 0.030), skin)
	if index % 8 == 5:
		_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, -0.070, -0.079), Vector3(0.104, 0.050, 0.043), hair.lightened(0.12))
	_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, -0.047, -0.102), Vector3(0.039, 0.005, 0.009), skin.darkened(0.20))
	_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, 0.113, 0.017), Vector3(0.25, 0.145, 0.239), hair)
	for side in SIDES:
		_part(w, Shape.COLUMN, Joint.HEAD, Vector3(side * 0.104, 0.065, 0.026), Vector3(0.033, 0.09, 0.14), hair)
	match index % 5:
		0: # Soft side part.
			_part(w, Shape.COLUMN, Joint.HEAD, Vector3(-0.073, 0.089, -0.062), Vector3(0.069, 0.042, 0.075), hair.darkened(0.06), Vector3(0, 0, 0.17))
			_part(w, Shape.ROUND, Joint.HEAD, Vector3(-0.039, 0.112, -0.07), Vector3(0.15, 0.07, 0.077), hair)
		1: # Chin-length bob follows the back of the skull.
			_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, 0.003, 0.069), Vector3(0.25, 0.255, 0.145), hair)
		2:
			_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, 0.103, 0.135), Vector3(0.115, 0.12, 0.10), hair)
			_part(w, Shape.COLUMN, Joint.HEAD, Vector3(0, 0.099, 0.136), Vector3(0.12, 0.017, 0.10), coat, Vector3(PI * 0.5, 0, 0))
		3:
			for curl in 7:
				var angle := float(curl) * TAU / 7.0
				_part(w, Shape.ROUND, Joint.HEAD, Vector3(cos(angle) * 0.082, 0.133, sin(angle) * 0.073), Vector3(0.094, 0.09, 0.09), hair)
			_part(w, Shape.ROUND, Joint.HEAD, Vector3(0.042, 0.160, -0.027), Vector3(0.14, 0.069, 0.13), hair.lightened(0.05))
		4:
			_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, 0.118, -0.048), Vector3(0.21, 0.075, 0.112), hair)
	# Tailoring: shirt inset, folded lapels, pockets, buttons and cuffs.
	if jacket:
		_shirt_detail(w, Vector2(0, 1.35), Vector2(0.10, 0.25), cream, 0.0, 0.01, 0.003)
		for side in SIDES:
			_shirt_detail(w, Vector2(side * 0.068, 1.371), Vector2(0.052, 0.19), coat.lightened(0.12), side * 0.29, 0.01, 0.011)
			_shirt_detail(w, Vector2(side * 0.108, 1.132), Vector2(0.049, 0.039), coat.darkened(0.10))
		for button in 3:
			var y := 1.22 - button * 0.073
			_part(w, Shape.ROUND, Joint.BODY, Vector3(0, y, _shirt_front(y) - 0.002), Vector3(0.012, 0.012, 0.008), dark)
		for side in SIDES:
			_shirt_detail(w, Vector2(side * 0.035, 1.463), Vector2(0.044, 0.054), cream, side * 0.35, 0.01, 0.014)
		_shirt_detail(w, Vector2(0.106, 1.335), Vector2(0.065, 0.009), coat.darkened(0.18))
	else:
		_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 1.494, 0), Vector3(0.135, 0.020, 0.12), coat.darkened(0.15))
		# A knitted hem and short rolled sleeves distinguish casual commuters.
		_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 1.042, 0), Vector3(0.39, 0.055, 0.26), coat.darkened(0.12))
		if index % 4 == 1:
			for stripe in 3:
				_shirt_detail(w, Vector2(0, 1.27 - stripe * 0.062), Vector2(0.26, 0.009), coat.lightened(0.14))
	if jacket and not skirt and index % 4 == 2:
		# Split jacket tails extend the silhouette without hiding the knees.
		for side in SIDES:
			_part(w, Shape.COLUMN, Joint.BODY, Vector3(side * 0.105, 0.945, 0.015), Vector3(0.205, 0.22, 0.275), coat)
	if index % 8 == 4:
		var pack_color := _material_color("brick").darkened(0.08)
		_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 1.25, 0.20), Vector3(0.32, 0.40, 0.17), pack_color)
		_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 1.15, 0.295), Vector3(0.25, 0.16, 0.05), pack_color.lightened(0.12))
		for side in SIDES:
			_shirt_detail(w, Vector2(side * 0.11, 1.30), Vector2(0.028, 0.34), dark, -side * 0.06, 0.018, 0.015)
	if index % 4 == 0:
		_shirt_detail(w, Vector2(0, 1.329), Vector2(0.025, 0.18), _material_color("brick"), 0.0, 0.01, 0.007)
	if index % 7 == 1:
		_part(w, Shape.COLUMN, Joint.BODY, Vector3(0, 1.52, 0), Vector3(0.16, 0.048, 0.15), _material_color("mustard"))
		_shirt_detail(w, Vector2(0.10, 1.355), Vector2(0.055, 0.28), _material_color("mustard"), 0.0, 0.025, 0.019)
	for side in SIDES:
		var arm := Joint.LEFT_ARM if side < 0 else Joint.RIGHT_ARM
		var forearm := Joint.LEFT_FOREARM if side < 0 else Joint.RIGHT_FOREARM
		var thigh := Joint.LEFT_THIGH if side < 0 else Joint.RIGHT_THIGH
		var calf := Joint.LEFT_CALF if side < 0 else Joint.RIGHT_CALF
		var foot := Joint.LEFT_FOOT if side < 0 else Joint.RIGHT_FOOT
		_part(w, Shape.COLUMN, arm, Vector3(0, -0.125, 0), Vector3(0.115, 0.29, 0.13), sleeve)
		_part(w, Shape.ROUND, arm, Vector3(0, -0.28, 0), Vector3(0.094, 0.09, 0.108), sleeve if jacket else skin)
		_part(w, Shape.COLUMN, forearm, Vector3(0, -0.115, 0), Vector3(0.094, 0.25, 0.109), sleeve if jacket else skin)
		if jacket:
			_part(w, Shape.COLUMN, forearm, Vector3(0, -0.227, 0), Vector3(0.097, 0.027, 0.112), cream)
		else:
			_part(w, Shape.COLUMN, arm, Vector3(0, -0.235, 0), Vector3(0.118, 0.04, 0.133), coat.lightened(0.13))
		_part(w, Shape.ROUND, forearm, Vector3(0, -0.273, -0.006), Vector3(0.076, 0.10, 0.069), skin)
		if side < 0 and index % 4 == 2:
			_part(w, Shape.COLUMN, forearm, Vector3(0, -0.231, 0), Vector3(0.100, 0.015, 0.115), dark)
			_part(w, Shape.BOX, forearm, Vector3(-0.053, -0.231, -0.008), Vector3(0.012, 0.024, 0.027), cream.darkened(0.12))
		# Full thigh cloth flows through a covered knee to a relaxed, straight cuff.
		_part(w, Shape.COLUMN, thigh, Vector3(0, -0.205, 0), Vector3(0.173, 0.46, 0.193), skin if skirt else trousers)
		_part(w, Shape.ROUND, calf, Vector3(0, -0.006, 0), Vector3(0.144, 0.12, 0.161), skin if skirt else trousers)
		_part(w, Shape.COLUMN, calf, Vector3(0, -0.208, 0), Vector3(0.144, 0.445, 0.158), skin if skirt else trousers)
		if not skirt:
			_part(w, Shape.BOX, thigh, Vector3(0.02 * side, -0.19, -0.090), Vector3(0.009, 0.34, 0.008), trousers.lightened(0.07))
			_part(w, Shape.COLUMN, calf, Vector3(0, -0.402, 0), Vector3(0.146, 0.028, 0.163), trousers.darkened(0.08))
		var shoe_color := dark if index % 3 != 2 else _material_color("wood").darkened(0.3)
		_part(w, Shape.COLUMN, foot, Vector3(0, -0.032, -0.031), Vector3(0.137, 0.077, 0.223), shoe_color)
		_part(w, Shape.ROUND, foot, Vector3(0, -0.039, -0.105), Vector3(0.139, 0.069, 0.135), shoe_color)
		_part(w, Shape.COLUMN, foot, Vector3(0, -0.073, -0.046), Vector3(0.145, 0.024, 0.256), dark.lightened(0.17))
		_part(w, Shape.BOX, foot, Vector3(0, -0.003, -0.046), Vector3(0.061, 0.008, 0.049), shoe_color.lightened(0.15))
	if skirt:
		_part(w, Shape.SKIRT, Joint.BODY, Vector3(0, 0.87, 0.008), Vector3(0.46, 0.36, 0.56), coat)
	if index % 6 == 0:
		_part(w, Shape.HAT, Joint.HEAD, Vector3(0, 0.23, 0.005), Vector3(0.27, 0.12, 0.26), coat)
		_part(w, Shape.COLUMN, Joint.HEAD, Vector3(0, 0.177, 0.005), Vector3(0.35, 0.017, 0.32), coat)
		_part(w, Shape.COLUMN, Joint.HEAD, Vector3(0, 0.196, 0.005), Vector3(0.273, 0.024, 0.263), dark)
	elif index % 6 == 3:
		_part(w, Shape.ROUND, Joint.HEAD, Vector3(0, 0.171, 0), Vector3(0.26, 0.12, 0.25), coat)
		_part(w, Shape.BOX, Joint.HEAD, Vector3(0, 0.158, -0.14), Vector3(0.21, 0.018, 0.092), coat)
	if index % 3 == 0: # Leather messenger bag and diagonal shoulder strap.
		var leather := _material_color("wood").darkened(0.2)
		_shirt_detail(w, Vector2(0, 1.267), Vector2(0.023, 0.47), leather, -0.38)
		_part(w, Shape.COLUMN, Joint.BODY, Vector3(-0.255, 1.005, 0.018), Vector3(0.09, 0.22, 0.245), leather)
		_part(w, Shape.BOX, Joint.BODY, Vector3(-0.26, 1.07, -0.108), Vector3(0.085, 0.075, 0.017), leather.lightened(0.12))
		_part(w, Shape.BOX, Joint.BODY, Vector3(-0.26, 1.026, -0.12), Vector3(0.022, 0.032, 0.008), cream)
	elif index % 4 == 1: # Small carried briefcase follows the hand.
		w.has_case = true
		_part(w, Shape.BOX, Joint.RIGHT_FOREARM, Vector3(0, -0.353, 0), Vector3(0.032, 0.07, 0.085), dark)
		_part(w, Shape.COLUMN, Joint.RIGHT_FOREARM, Vector3(0, -0.47, 0), Vector3(0.085, 0.20, 0.30), _material_color("wood"))
		_part(w, Shape.BOX, Joint.RIGHT_FOREARM, Vector3(0.045, -0.41, 0), Vector3(0.009, 0.014, 0.16), cream)
	if index % 9 == 0:
		for side in SIDES:
			_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.043, 0.055, -0.113), Vector3(0.046, 0.004, 0.005), dark)
			_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.043, 0.028, -0.113), Vector3(0.046, 0.004, 0.005), dark)
			for edge in SIDES:
				_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.043 + edge * 0.022, 0.042, -0.113), Vector3(0.004, 0.027, 0.005), dark)
			_part(w, Shape.BOX, Joint.HEAD, Vector3(side * 0.080, 0.054, -0.056), Vector3(0.005, 0.005, 0.11), dark, Vector3(0, side * 0.25, 0))
		_part(w, Shape.BOX, Joint.HEAD, Vector3(0, 0.048, -0.114), Vector3(0.043, 0.004, 0.005), dark)

## Rounded rectangular cloth sections: flat fronts and softly rolled side seams.
## Each profile is built once and reused by every part of the six shared batches.
func _profile_mesh(torso: bool, skirt := false) -> ArrayMesh:
	var section := PackedVector2Array([
		Vector2(-0.34, -0.5), Vector2(0.34, -0.5),
		Vector2(0.46, -0.42), Vector2(0.5, -0.25),
		Vector2(0.5, 0.25), Vector2(0.38, 0.46),
		Vector2(0.18, 0.5), Vector2(-0.18, 0.5),
		Vector2(-0.38, 0.46), Vector2(-0.5, 0.25),
		Vector2(-0.5, -0.25), Vector2(-0.46, -0.42)])
	var rings: PackedVector3Array
	if torso:
		rings = PackedVector3Array(TORSO_RINGS)
	elif skirt:
		# Fitted waist stays under the shirt; the hem encloses moving thighs.
		rings = PackedVector3Array([
			Vector3(-0.5, 1.05, 1.10), Vector3(0.12, 1.0, 0.83),
			Vector3(0.5, 0.82, 0.42)])
	else:
		rings = PackedVector3Array([
			Vector3(-0.5, 0.84, 0.85), Vector3(-0.35, 0.90, 0.94),
			Vector3(0.28, 1.0, 1.0), Vector3(0.5, 0.93, 0.91)])
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var sides := section.size()
	for ring_index in rings.size():
		var ring := rings[ring_index]
		var below := rings[maxi(0, ring_index - 1)]
		var above := rings[mini(rings.size() - 1, ring_index + 1)]
		for side in sides:
			var point := section[side]
			vertices.append(Vector3(point.x * ring.y, ring.x, point.y * ring.z))
			var tangent := section[(side + 1) % sides] - section[(side + sides - 1) % sides]
			var vertical := Vector3(point.x * (above.y - below.y), above.x - below.x, point.y * (above.z - below.z))
			normals.append(vertical.cross(Vector3(tangent.x * ring.y, 0, tangent.y * ring.z)).normalized())
			if ring_index < rings.size() - 1:
				var a := ring_index * sides + side
				var b := ring_index * sides + (side + 1) % sides
				# Godot front faces are clockwise; cross-product normals stay outward.
				indices.append_array(PackedInt32Array([a, b + sides, a + sides, a, b, b + sides]))
	# Separate cap vertices keep neckline and cuffs crisp instead of domed.
	for cap in 2:
		var ring := rings[0 if cap == 0 else rings.size() - 1]
		var center := vertices.size()
		vertices.append(Vector3(0, ring.x, 0))
		normals.append(Vector3.DOWN if cap == 0 else Vector3.UP)
		for point in section:
			vertices.append(Vector3(point.x * ring.y, ring.x, point.y * ring.z))
			normals.append(Vector3.DOWN if cap == 0 else Vector3.UP)
		for side in sides:
			var a := center + 1 + side
			var b := center + 1 + (side + 1) % sides
			indices.append_array(PackedInt32Array([center, b, a] if cap == 0 else [center, a, b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_batches() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	for shape in Shape.COUNT:
		var mesh: Mesh
		if shape == Shape.BOX:
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
		elif shape == Shape.ROUND:
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 12
			sphere.rings = 6
			mesh = sphere
		elif shape == Shape.TORSO or shape == Shape.COLUMN:
			mesh = _profile_mesh(shape == Shape.TORSO)
		elif shape == Shape.SKIRT:
			mesh = _profile_mesh(false, true)
		else:
			var cylinder := CylinderMesh.new()
			cylinder.height = 1.0
			cylinder.bottom_radius = 0.5
			cylinder.top_radius = 0.5
			cylinder.radial_segments = 8
			cylinder.rings = 1
			cylinder.top_radius = 0.41
			mesh = cylinder
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = mesh
		batch.instance_count = _parts[shape].size()
		for part: Part in _parts[shape]:
			batch.set_instance_color(part.index, part.color)
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		node.material_override = material
		# Avoid six crowd-wide shadow passes; the architecture still casts shadows.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_batches.append(batch)
		_batch_nodes.append(node)

func _snapshot(w: Walker) -> void:
	w.previous_position = w.position
	w.previous_yaw = w.yaw
	w.previous_phase = w.phase
	w.previous_gait_weight = w.gait_weight
	w.previous_idle_time = w.idle_time

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# Fixed occupancy decisions, frame-rate presentation. All roots share the
	# same interpolation fraction, so checked swept separations remain valid.
	# Cap catch-up after a suspended browser tab rather than taking a huge step.
	_elapsed = minf(_elapsed + delta, TICK * 4.0)
	while _elapsed >= TICK:
		for walker in _walkers:
			_snapshot(walker)
			_prepare_step(walker, TICK)
		for walker in _walkers:
			_resolve_step(walker, TICK)
		for walker in _walkers:
			_commit_step(walker, TICK)
		_elapsed -= TICK
	var alpha := _elapsed / TICK
	var camera := get_viewport().get_camera_3d()
	var camera_position := to_local(camera.global_position) if camera != null else Vector3.ZERO
	for walker in _walkers:
		var near := camera == null or walker.position.distance_squared_to(camera_position) < DRAW_DISTANCE * DRAW_DISTANCE
		if not near:
			if walker.drawn:
				for part in walker.parts:
					_batches[part.shape].set_instance_transform(part.index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), walker.position))
			walker.drawn = false
			walker.planted = false
			continue
		walker.drawn = true
		_pose(walker, alpha)
		_draw(walker)

func _stop_step(w: Walker) -> void:
	w.desired_center = w.route_position
	w.desired_offset = w.lane_offset
	w.desired_position = w.position
	w.desired_velocity = Vector3.ZERO

func _next_target(w: Walker) -> void:
	var endpoint := w.target == 0 or w.target == w.route.size() - 1
	if endpoint:
		if w.looping:
			# The first/last route points coincide: only the cursor wraps.
			w.target = 1
		else:
			w.direction = -w.direction
			w.target += w.direction
			w.turning = true
			w.heading = (w.route[w.target] - w.route_position).normalized()
		w.wait = _rng.randf_range(0.8, 2.0)
	else:
		w.target += w.direction

func _lane_clear(w: Walker, passing: Vector3) -> bool:
	if not _path_clear(w.position, passing):
		return false
	for other in _walkers:
		if other != w and _closest_distance_squared(w.position - other.position, passing - w.position, 1.0) < CLEARANCE * CLEARANCE:
			return false
	return true

func _select_bypass(w: Walker) -> void:
	if w.blocked < 0.30 or w.bypass != 0.0 or w.retreat_remaining > 0.0:
		return
	# Route-edge furniture can obstruct one lane without obstructing the
	# walkway. Change lanes before it, using the same bounded maneuver.
	var forward := w.heading * minf(1.1, w.route_position.distance_to(w.route[w.target]))
	if not _path_clear(w.position, w.position + forward):
		var right := w.heading.cross(Vector3.UP).normalized()
		for side in SIDES:
			if w.bypass_cooldown > 0.0 and float(side) == w.failed_bypass:
				continue
			var passing: Vector3 = w.route_position + right * MAX_LANE * side
			if _lane_clear(w, passing) and _path_clear(passing, passing + forward):
				w.bypass = float(side)
				w.bypass_remaining = 2.4
				return
	for other in _walkers:
		if other == w:
			continue
		var relative := other.position - w.position
		var ahead := relative.dot(w.heading)
		if ahead < -0.15 or ahead > 1.35 or relative.length_squared() > 2.25:
			continue
		var aligned := w.heading.dot(other.heading) > 0.7
		if other.stationary or (aligned and other.speed <= w.speed) or w.id > other.id:
			var right := w.heading.cross(Vector3.UP).normalized()
			# Select a clear edge of the route corridor, never push bodies apart
			# after moving them or leave the authored corridor to pass somebody.
			for side in SIDES:
				if w.bypass_cooldown > 0.0 and float(side) == w.failed_bypass:
					continue
				var passing: Vector3 = w.route_position + right * MAX_LANE * side
				if passing.distance_squared_to(other.position) <= w.position.distance_squared_to(other.position) + 0.04:
					continue
				if _lane_clear(w, passing):
					w.bypass = float(side)
					w.bypass_remaining = 2.4
					return
			# At a congested corner the lower ID retains priority. The other
			# steps back along its current segment to release the crossing.
			if w.blocked > 1.2 and other.blocked > 0.3 and w.id > other.id:
				w.retreat_remaining = 1.1
				return

func _prepare_step(w: Walker, dt: float) -> void:
	_stop_step(w)
	w.moving = false
	w.idle_time += dt
	w.bypass_cooldown = maxf(0.0, w.bypass_cooldown - dt)
	if w.stationary:
		return
	# A passing lane is held by distance, not time: waiting in a queue cannot
	# expire it midway through a maneuver and send two bodies back together.
	if w.bypass != 0.0 and w.bypass_remaining <= 0.0:
		w.bypass = 0.0
	if w.bypass != 0.0 and w.blocked > 1.2:
		# Remember an occupied edge rather than selecting the very same failed
		# side every tick. The other edge or ID-priority retreat can now win.
		w.failed_bypass = w.bypass
		w.bypass_cooldown = 1.6
		w.bypass = 0.0
	if w.wait > 0.0:
		w.wait = maxf(0.0, w.wait - dt)
		return
	var destination := w.route[w.target]
	var distance := w.route_position.distance_to(destination)
	if distance < 0.001:
		_next_target(w)
		if w.wait > 0.0:
			return
		destination = w.route[w.target]
		distance = w.route_position.distance_to(destination)
	w.heading = (destination - w.route_position) / maxf(distance, 0.001)
	if w.turning:
		if absf(angle_difference(w.yaw, atan2(-w.heading.x, -w.heading.z))) > 0.18:
			return
		w.turning = false
	_select_bypass(w)
	if w.retreat_remaining > 0.0:
		var previous := w.route[w.target - w.direction]
		var available := w.route_position.distance_to(previous)
		if available > 0.01:
			w.desired_center = w.route_position.move_toward(previous, minf(w.speed * dt, w.retreat_remaining))
			w.desired_position = w.desired_center + w.lane_offset
			w.desired_velocity = (w.desired_position - w.position) / dt
			return
		w.retreat_remaining = 0.0
	var right := w.heading.cross(Vector3.UP).normalized()
	var lane := MAX_LANE * w.bypass if w.bypass != 0.0 else w.lane
	var offset := right * lane
	var lateral_travel := w.lane_offset.distance_to(offset)
	# A bypass first moves sideways behind the obstacle, then walks past it.
	var center_travel := minf(distance, w.speed * dt)
	if w.bypass != 0.0 and lateral_travel > 0.08:
		center_travel = 0.0
	w.desired_center = w.route_position + w.heading * center_travel
	w.desired_offset = w.lane_offset.move_toward(offset, dt * 0.70)
	var candidate := w.desired_center + w.desired_offset
	var total_travel := w.position.distance_to(candidate)
	var fraction := minf(1.0, w.speed * dt / maxf(total_travel, 0.001))
	w.desired_center = w.route_position.lerp(w.desired_center, fraction)
	w.desired_offset = w.lane_offset.lerp(w.desired_offset, fraction)
	w.desired_position = w.desired_center + w.desired_offset
	w.desired_velocity = (w.desired_position - w.position) / dt

func _closest_distance_squared(relative: Vector3, velocity: Vector3, horizon: float) -> float:
	var speed_squared := velocity.length_squared()
	var time := clampf(-relative.dot(velocity) / speed_squared, 0.0, horizon) if speed_squared > 0.00001 else 0.0
	return (relative + velocity * time).length_squared()

func _resolve_step(w: Walker, dt: float) -> void:
	if w.desired_velocity.length_squared() < 0.00001:
		return
	if not _path_clear(w.position, w.desired_position):
		# A blocked lateral maneuver may still advance on its current clear lane.
		w.desired_offset = w.lane_offset
		w.desired_position = w.desired_center + w.desired_offset
		w.desired_velocity = (w.desired_position - w.position) / dt
		if not _path_clear(w.position, w.desired_position):
			_stop_step(w)
			return
	var clearance_squared := CLEARANCE * CLEARANCE
	for other in _walkers:
		if other == w or w.position.distance_squared_to(other.position) > 9.0:
			continue
		var relative := w.position - other.position
		var other_velocity := other.desired_velocity
		var aligned := w.heading.dot(other.heading) > 0.75
		var follows := aligned and (other.position - w.position).dot(w.heading) > 0.0
		var yields := other.stationary or other.wait > 0.0 or follows or (not aligned and w.id > other.id)
		# Reserve crossing space before anyone has stepped into the junction.
		# Lateral bypasses are allowed to clear the queue, without predicting
		# their brief sideways velocity a whole second into the future.
		var horizon := dt if w.bypass != 0.0 or w.retreat_remaining > 0.0 else 0.85
		if yields and _closest_distance_squared(relative, w.desired_velocity - other_velocity, horizon) < clearance_squared:
			_stop_step(w)
			return
		# Lower indices have already been scheduled. Higher ones are treated
		# as standing here: their eventual step must respect this reservation.
		var scheduled_other := other.desired_position if other.id < w.id else other.position
		var relative_step := (w.desired_position - w.position) - (scheduled_other - other.position)
		if _closest_distance_squared(relative, relative_step, 1.0) < clearance_squared:
			_stop_step(w)
			return

func _commit_step(w: Walker, dt: float) -> void:
	var travel := w.position.distance_to(w.desired_position)
	w.moving = travel > 0.0001
	if w.moving:
		w.position = w.desired_position
		w.route_position = w.desired_center
		w.lane_offset = w.desired_offset
		w.blocked = 0.0
		# Retreat is a careful backward step, not an abrupt 180-degree spin.
		var sidestepping := w.bypass != 0.0 and absf(w.desired_velocity.dot(w.heading)) < 0.2
		var facing := w.heading if w.retreat_remaining > 0.0 or sidestepping else w.desired_velocity.normalized()
		w.gait_direction = -1.0 if w.retreat_remaining > 0.0 else 1.0
		w.yaw = lerp_angle(w.yaw, atan2(-facing.x, -facing.z), 1.0 - exp(-dt * 8.0))
		if w.bypass != 0.0:
			w.bypass_remaining -= maxf(0.0, (w.desired_velocity * dt).dot(w.heading))
		if w.retreat_remaining > 0.0:
			w.retreat_remaining = maxf(0.0, w.retreat_remaining - travel)
		# Unwrapped phase interpolates cleanly across the cycle boundary.
		w.phase += travel * TAU / (STRIDE_LENGTH * w.width_scale * w.stride_scale)
	else:
		if w.stationary or w.wait > 0.0 or w.turning:
			w.blocked = 0.0
		else:
			w.blocked += dt
		if w.turning:
			var facing_yaw := atan2(-w.heading.x, -w.heading.z)
			w.yaw += clampf(angle_difference(w.yaw, facing_yaw), -dt * 3.2, dt * 3.2)
	w.gait_weight = move_toward(w.gait_weight, 1.0 if w.moving else 0.0, dt * 4.5)

func _leg_basis(direction: Vector3) -> Basis:
	var up := -direction.normalized()
	var right := up.cross(Vector3.BACK).normalized()
	return Basis(right, up, right.cross(up))

func _pose(w: Walker, alpha: float) -> void:
	var phase := lerpf(w.previous_phase, w.phase, alpha)
	var weight := lerpf(w.previous_gait_weight, w.gait_weight, alpha)
	var time := lerpf(w.previous_idle_time, w.idle_time, alpha)
	var stride := sin(phase) * weight * w.gait_direction
	var arm_swing := cos(phase) * weight * w.gait_direction
	var idle := 1.0 - weight
	var breathing := sin(time * 1.45) * 0.0025
	var bob := -absf(sin(phase * 2.0)) * weight * 0.006
	var sway := sin(time * 0.63 + float(w.idle_style)) * idle * 0.010
	var root := Transform3D(Basis(Vector3.UP, lerp_angle(w.previous_yaw, w.yaw, alpha)).scaled_local(Vector3(w.width_scale, w.height_scale, w.width_scale)), w.previous_position.lerp(w.position, alpha))
	var inverse_root := root.affine_inverse()
	w.joints[Joint.ROOT] = root
	var body_basis := Basis.from_euler(Vector3(w.posture + weight * 0.016, stride * 0.022, stride * 0.014 + sway))
	var waist := Vector3(0, 1.0, 0)
	w.joints[Joint.BODY] = root * Transform3D(body_basis, waist - body_basis * waist + Vector3(0, breathing + bob, 0))
	# A long, quiet glance with a short rest replaces constant metronomic head
	# wagging. People independently glance, nod, or simply breathe.
	var glance := sin(time * 0.22 + float(w.idle_style) * 1.7)
	var glance_squared := glance * glance
	glance *= glance_squared * glance_squared
	var head_yaw := glance * (0.085 + idle * 0.065)
	var head_pitch := sin(time * 0.31) * 0.014
	if w.idle_style == 2:
		head_pitch += idle * 0.026
	w.joints[Joint.HEAD] = w.joints[Joint.BODY] * Transform3D(Basis.from_euler(Vector3(head_pitch, head_yaw, -sway * 0.5)), Vector3(0, 1.655, 0))
	for side in SIDES:
		var arm := Joint.LEFT_ARM if side < 0 else Joint.RIGHT_ARM
		var forearm := Joint.LEFT_FOREARM if side < 0 else Joint.RIGHT_FOREARM
		var thigh := Joint.LEFT_THIGH if side < 0 else Joint.RIGHT_THIGH
		var calf := Joint.LEFT_CALF if side < 0 else Joint.RIGHT_CALF
		var foot := Joint.LEFT_FOOT if side < 0 else Joint.RIGHT_FOOT
		# The arm counters its same-side leg, with a quieter loaded hand.
		var swing: float = -arm_swing * side * 0.22
		if side > 0 and w.has_case:
			swing *= 0.23
		var resting_elbow := 0.10 + idle * (0.035 if w.idle_style == 1 else 0.0)
		w.joints[arm] = w.joints[Joint.BODY] * Transform3D(Basis.from_euler(Vector3(-swing + w.posture, 0, side * (0.055 + idle * 0.012))), Vector3(side * 0.212, 1.443, 0))
		w.joints[forearm] = w.joints[arm] * Transform3D(Basis(Vector3.RIGHT, resting_elbow + maxf(0.0, swing) * 0.28), Vector3(0, -0.28, 0))
		var cycle := fposmod(phase / TAU + (0.0 if side < 0 else 0.5), 1.0)
		var extent := 0.20 * w.stride_scale * w.gait_direction
		var foot_z: float
		var lift := 0.0
		if cycle < 0.6:
			foot_z = lerpf(-extent, extent, cycle / 0.6)
		else:
			var t := (cycle - 0.6) / 0.4
			foot_z = lerpf(extent, -extent, t * t * (3.0 - 2.0 * t))
			var arc := sin(t * PI)
			lift = arc * arc * 0.085
		var ankle := Vector3(side * 0.103, ANKLE_HEIGHT + lift * weight, foot_z * weight)
		var previous_cycle := w.left_cycle if side < 0 else w.right_cycle
		var plant := w.left_plant if side < 0 else w.right_plant
		if not w.planted or (cycle < 0.6 and (previous_cycle >= 0.6 or cycle < previous_cycle)):
			plant = root * ankle
		if cycle < 0.6:
			# World-space stance locks also survive curved motion and lane changes.
			# Fade during start/stop to settle into a relaxed two-foot stance.
			var planted_ankle := inverse_root * plant
			ankle.x = lerpf(ankle.x, planted_ankle.x, weight * weight)
			ankle.z = lerpf(ankle.z, planted_ankle.z, weight * weight)
		else:
			# Continue from the real planted foot, not a discontinuous nominal
			# rear point after a turn. The landing target remains route-relative.
			var t := (cycle - 0.6) / 0.4
			var start := inverse_root * plant
			var blend := t * t * (3.0 - 2.0 * t)
			var swing_ankle := start.lerp(Vector3(side * 0.103, ANKLE_HEIGHT, -extent), blend)
			ankle.x = lerpf(ankle.x, swing_ankle.x, weight * weight)
			ankle.z = lerpf(ankle.z, swing_ankle.z, weight * weight)
		if side < 0:
			w.left_plant = plant
			w.left_cycle = cycle
		else:
			w.right_plant = plant
			w.right_cycle = cycle
		var hip := Vector3(side * 0.103, 0.935 + bob, 0)
		# Keep knees softly bent; unusually tight turns release an overextended
		# plant instead of stretching a leg or detaching the shoe from its calf.
		var horizontal := Vector2(ankle.x - hip.x, ankle.z)
		var vertical := hip.y - ankle.y
		var maximum_reach := UPPER_LEG + LOWER_LEG - 0.001
		var horizontal_limit := sqrt(maxf(0.0, maximum_reach * maximum_reach - vertical * vertical))
		horizontal = horizontal.limit_length(horizontal_limit)
		ankle.x = hip.x + horizontal.x
		ankle.z = horizontal.y
		var to_ankle := ankle - hip
		var reach := to_ankle.length()
		var direction := to_ankle / maxf(reach, 0.001)
		var knee_hint := (Vector3.FORWARD - direction * direction.dot(Vector3.FORWARD)).normalized()
		var along := reach * 0.5 # Equal-length thigh and calf.
		var knee := hip + direction * along + knee_hint * sqrt(maxf(0.0, UPPER_LEG * UPPER_LEG - along * along))
		w.joints[thigh] = root * Transform3D(_leg_basis(knee - hip), hip)
		w.joints[calf] = root * Transform3D(_leg_basis(ankle - knee), knee)
		w.joints[foot] = root * Transform3D(Basis.IDENTITY, ankle)
	w.planted = true

func _draw(w: Walker) -> void:
	for part in w.parts:
		_batches[part.shape].set_instance_transform(part.index, w.joints[part.joint] * part.local)
