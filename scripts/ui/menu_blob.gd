class_name MenuBlob
extends Control

## A damped liquid skin and spring-mounted mass; grabs stretch a local surface patch.
## Call release_grab() before showing another input layer, such as the settings drawer.

const POINT_COUNT := 128
const STEP := 1.0 / 120.0
const MIN_RADIUS := 0.38
const MAX_RADIUS := 3.4

var _body: Polygon2D
var _outline := PackedVector2Array()
var _directions := PackedVector2Array()
var _angles := PackedFloat32Array()
var _radii := PackedFloat32Array()
var _velocities := PackedFloat32Array()
var _targets := PackedFloat32Array()
var _center := Vector2.ZERO
var _base_center := Vector2.ZERO
var _center_offset := Vector2.ZERO
var _center_velocity := Vector2.ZERO
var _radius := 1.0
var _time := 0.0
var _grab_active := false
var _touch_index := -1
var _pointer := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _grab_origin := Vector2.UP
var _grab_angle := -PI / 2.0
var _pull_angle := -PI / 2.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	clip_contents = false


func _ready() -> void:
	_outline.resize(POINT_COUNT)
	_directions.resize(POINT_COUNT)
	_angles.resize(POINT_COUNT)
	_radii.resize(POINT_COUNT)
	_velocities.resize(POINT_COUNT)
	_targets.resize(POINT_COUNT)
	for i in range(POINT_COUNT):
		_angles[i] = TAU * float(i) / float(POINT_COUNT)
		_directions[i] = Vector2.from_angle(_angles[i])
		_radii[i] = _rest_radius(_angles[i])
	_body = Polygon2D.new()
	_body.name = "LiquidSurface"
	_body.antialiased = true
	_body.color = Color("ac2954")
	add_child(_body)
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	focus_exited.connect(release_grab)
	focus_entered.connect(_pulse)
	set_process_input(false)
	_on_resized()


func release_grab() -> void:
	# Keep the skin's momentum: releasing returns through a damped wobble, not a snap.
	_grab_active = false
	_touch_index = -1
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process_input(false)


func _has_point(point: Vector2) -> bool:
	return (
		is_visible_in_tree()
		and _outline.size() == POINT_COUNT
		and Geometry2D.is_point_in_polygon(point, _outline)
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _grab_active:
			_begin_grab(event.position, -1)
			if _grab_active:
				accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled and not _grab_active:
			_begin_grab(event.position, event.index)
			if _grab_active:
				accept_event()
	elif event is InputEventKey:
		if (
			focus_mode != Control.FOCUS_NONE
			and has_focus()
			and event.pressed
			and not event.echo
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		):
			_pulse()
			accept_event()


func _input(event: InputEvent) -> void:
	# GUI hit testing starts capture, but global routing finishes it outside our rectangle.
	if not _grab_active:
		return
	var captured := false
	if _touch_index >= 0:
		if event is InputEventScreenDrag and event.index == _touch_index:
			_set_pointer(get_global_transform_with_canvas().affine_inverse() * event.position)
			captured = true
		elif event is InputEventScreenTouch and event.index == _touch_index:
			if not event.pressed or event.canceled:
				release_grab()
			# Let the GUI observe release and clear its own touch-focus bookkeeping.
			return
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_set_pointer(get_global_transform_with_canvas().affine_inverse() * event.position)
		captured = true
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			release_grab()
			# Handling release here would leave the Viewport's mouse capture stuck.
			return
	if captured:
		get_viewport().set_input_as_handled()


func _begin_grab(point: Vector2, touch_index: int) -> void:
	if not point.is_finite() or not _has_point(point):
		return
	grab_focus()
	var relative := point - _center
	_grab_angle = relative.angle() if relative.length_squared() > 1.0 else -PI / 2.0
	_pull_angle = _grab_angle
	var sample := wrapf(_grab_angle, 0.0, TAU) * float(POINT_COUNT) / TAU
	var index := int(sample) % POINT_COUNT
	var surface_radius := lerpf(_radii[index], _radii[(index + 1) % POINT_COUNT], sample - floorf(sample))
	_grab_origin = Vector2.from_angle(_grab_angle) * surface_radius
	_grab_offset = _center + _grab_origin * _radius - point
	_pointer = point
	_touch_index = touch_index
	_grab_active = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	set_process_input(true)
	for i in range(POINT_COUNT):
		var distance := angle_difference(_grab_angle, _angles[i])
		_velocities[i] -= 0.28 * exp(-distance * distance / 0.13)


func _set_pointer(point: Vector2) -> void:
	if point.is_finite():
		# Bound values before doing length/normalization arithmetic during extreme drags.
		_pointer = _center + (point - _center).clamp(Vector2.ONE * -_radius * 12.0, Vector2.ONE * _radius * 12.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _body == null:
		return
	if _grab_active and _touch_index < 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		release_grab()
	var elapsed := clampf(delta, 0.0, 0.05)
	_time += elapsed
	var pull_amount := 0.0
	var shear_amount := 0.0
	var strain := 0.0
	var desired_offset := Vector2.ZERO
	if _grab_active:
		var displacement := (_pointer + _grab_offset - _center) / _radius - _grab_origin
		var distance := displacement.length()
		# Soft saturation makes every extra pixel produce less stretch, without a hard wall.
		var resisted := Vector2.ZERO
		if distance > 0.0001:
			resisted = displacement / (1.0 + distance / 4.0)
		var tip := _grab_origin + resisted
		var tip_angle := tip.angle() if tip.length_squared() > 0.04 else _grab_angle
		_pull_angle = lerp_angle(_pull_angle, tip_angle, 1.0 - exp(-elapsed * 22.0))
		var extension := tip.length() - _grab_origin.length()
		pull_amount = clampf(extension, -0.62, 2.4)
		shear_amount = 0.28 * tanh(absf(angle_difference(_grab_angle, _pull_angle)) / 0.6)
		strain = smoothstep(1.3, 3.8, distance)
		desired_offset = (resisted * _radius * 0.22).limit_length(_radius * 0.65)
	for i in range(POINT_COUNT):
		var angle := _angles[i]
		var deformation := 0.0
		if _grab_active:
			var distance := angle_difference(_pull_angle, angle)
			var old_distance := angle_difference(_grab_angle, angle)
			var width := 0.30 + absf(pull_amount) * 0.10
			var patch := exp(-distance * distance / width)
			var old_patch := exp(-old_distance * old_distance / width)
			deformation = pull_amount * patch + shear_amount * (patch - old_patch)
			# A small moving recoil at high strain is the only refusal signal.
			deformation += strain * 0.04 * sin(_time * 22.0 + distance * 5.0) * patch
			# The unstretched side contracts as the pulled lobe gains volume.
			deformation -= maxf(pull_amount, 0.0) * 0.16 * (1.0 - patch)
		_targets[i] = clampf(_rest_radius(angle) + deformation, MIN_RADIUS, MAX_RADIUS)
	# Semi-implicit integration with bounded substeps remains stable after browser stalls.
	var steps := maxi(1, int(ceil(elapsed / STEP)))
	var dt := elapsed / float(steps)
	for _step in range(steps):
		_center_velocity += ((desired_offset - _center_offset) * 55.0 - _center_velocity * 4.2) * dt
		_center_velocity = _center_velocity.limit_length(_radius * 7.0)
		_center_offset = (_center_offset + _center_velocity * dt).limit_length(_radius * 0.9)
		for i in range(POINT_COUNT):
			var previous := (i + POINT_COUNT - 1) % POINT_COUNT
			var next := (i + 1) % POINT_COUNT
			var coupling := (_radii[previous] + _radii[next] - 2.0 * _radii[i]) * 180.0
			var acceleration := (_targets[i] - _radii[i]) * 125.0 + coupling - _velocities[i] * 3.8
			_velocities[i] = clampf(_velocities[i] + acceleration * dt, -8.0, 8.0)
		for i in range(POINT_COUNT):
			var radius := _radii[i] + _velocities[i] * dt
			_radii[i] = clampf(radius, MIN_RADIUS, MAX_RADIUS)
			if radius != _radii[i]:
				_velocities[i] *= -0.18
	_center = _base_center + _center_offset
	_update_geometry()


func _rest_radius(angle: float) -> float:
	return (
		1.0
		+ 0.070 * sin(angle * 3.0 + _time * 0.47)
		+ 0.038 * cos(angle * 2.0 - _time * 0.36)
		+ 0.012 * sin(_time * 0.85)
	)


func _update_geometry() -> void:
	# Strictly ordered rays and positive radii guarantee a non-self-crossing silhouette.
	for i in range(POINT_COUNT):
		_outline[i] = _center + _directions[i] * _radii[i] * _radius
	_body.polygon = _outline


func _on_resized() -> void:
	release_grab()
	if _body == null:
		return
	_base_center = size * 0.5
	_center_offset = Vector2.ZERO
	_center_velocity = Vector2.ZERO
	_center = _base_center
	# The skin may stretch beyond this Control; only its actual silhouette captures input.
	_radius = maxf(0.01, minf(size.x, size.y) * 0.295)
	_update_geometry()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		release_grab()
		# A hidden menu must not reopen with old, suspended deformation.
		for i in range(_radii.size()):
			_radii[i] = _rest_radius(_angles[i])
			_velocities[i] = 0.0
		_center_offset = Vector2.ZERO
		_center_velocity = Vector2.ZERO
		_center = _base_center
		if _body != null:
			_update_geometry()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_grab()
	elif what == NOTIFICATION_EXIT_TREE:
		release_grab()


func _pulse() -> void:
	if not _grab_active:
		for i in range(_velocities.size()):
			_velocities[i] = clampf(_velocities[i] + 0.72 * (1.0 + 0.2 * sin(_angles[i] * 3.0)), -2.8, 2.8)
