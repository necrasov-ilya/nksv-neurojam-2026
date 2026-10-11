extends Node3D

signal notified(text: String)
signal peer_completed(result: Dictionary)

const Rooms := preload("res://scripts/campaign/rooms.gd")
const TITLES := ["Сохранность предмета", "Память среды", "Приёмка исправления"]
const VERSIONS := ["1.1", "2.0", "1.2"]
var cube: RigidBody3D
var carried := false
var case_day := 1
var control_mode := true
var blue_light := false
var gate_open := false
var marked := false
var damaged := false
var peer_running := false
var instruction_seen := false
var seconds := 0.0
var journal: Array[Dictionary] = []
var snapshots: Array[String] = []
var peer_result: Dictionary = {}
var _targets := {"cube": Vector3.ZERO, "mode": Vector3(-3.6, 1.2, 0), "light": Vector3(3.6, 1.2, 0), "reset": Vector3(-3.6, 1.2, -3), "reconnect": Vector3(3.6, 1.2, -3), "case_notes": Vector3(-3.6, 1.2, 3), "finish_case": Vector3(3.6, 1.2, 3)}
var _run := 1
var _pressure: Area3D
var _gate: Node3D
var _status: Label3D
var _title: Label3D
var _lamp: OmniLight3D
var _panel: Node3D
var _mark: Node3D
var _damage: Node3D
var _peer: Node3D
var _person: Node3D
var _peer_step := 0
var _peer_wait := 0.0
var _peer_arrived := false
var _peer_reset_mark := false
var _loaded := false
var _load_time := 0.0
var _seen_loaded := false
var _went_hidden := false
var _occlusion_fault := false
var _cached_open := false
var _replaying := false
var _light_trial := false
var _ray := PhysicsRayQueryParameters3D.new()

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
	for x in [-4.6, 4.6]:
		g.box(Vector3(x, 1.65, -1), Vector3(0.25, 3.3, 8), "petrol")
		for z in [-4, -2, 0, 2]:
			g.box(Vector3(x * 0.97, 1.6, z), Vector3(0.08, 2.8, 0.10), "steel")
	for z in [-4.4, 3.2]:
		g.box(Vector3(0, 3.1, z), Vector3(9.2, 0.16, 0.25), "petrol")
	g.box(Vector3(0, 0.012, -0.5), Vector3(4, 0.025, 5.8), "petrol")
	for x in [-2.1, 2.1]:
		g.box(Vector3(x, 0.03, -0.5), Vector3(0.055, 0.025, 6), "mustard")
	Rooms.lamp(self, g, Vector3(0, 3.05, -1.1), false, 1.4)
	_title = Rooms.plaque(g, "ЛОКАЛЬНЫЙ ИСПЫТАТЕЛЬНЫЙ СТЕНД", Vector3(0, 2.6, -5.55), 4.8)
	# Walking around this opaque screen really removes the cube from the camera ray.
	Rooms.block(g, Vector3(-1.3, 1.5, -0.6), Vector3(0.18, 3.0, 3.4), "cream")
	Rooms.plaque(g, "МАРШРУТ ЗА ПЕРЕГОРОДКОЙ", Vector3(-3.2, 1.9, -2.9), 2.4)
	g.box(Vector3(-3.2, 0.02, -0.8), Vector3(1.1, 0.03, 1.5), "mustard")
	for spec in [[-3.6, 0.0, "РЕЖИМ", "accent_magenta"], [3.6, 0.0, "СВЕТ", "mustard"], [-3.6, -3.0, "СБРОС / R", "accent_violet"], [3.6, -3.0, "ПЕРЕПОДКЛЮЧИТЬ", "accent_magenta"], [-3.6, 3.0, "ЗАДАНИЕ / ЗАПИСИ", "accent_violet"], [3.6, 3.0, "В ОТЧЁТ", "cross_green"]]:
		var p := Vector3(spec[0], 0, spec[1])
		Rooms.block(g, p + Vector3(0, 0.70, 0), Vector3(0.7, 1.4, 0.50), "cream")
		g.box(p + Vector3(0, 1.25, 0.27), Vector3(0.4, 0.25, 0.03), spec[3])
		g.box(p + Vector3(0, 0.35, 0.26), Vector3(0.5, 0.36, 0.025), "steel")
		Rooms.plaque(g, spec[2], p + Vector3(0, 1.8, 0.2), 1.8)
	Rooms.block(g, Vector3(1.6, 0.08, -2.1), Vector3(1.0, 0.16, 1.0), "mustard")
	_status = Rooms.plaque(g, "ПРИВОД / 0 КГ", Vector3(2.6, 2.35, -2.6), 2.2)
	for x in [-2.95, 2.95]:
		g.box(Vector3(x, 1.5, -4.25), Vector3(3.6, 3.0, 0.08), "clear_glass")
		g.solid(Vector3(x, 1.5, -4.25), Vector3(3.6, 3.0, 0.08))
	_gate = Rooms.sliding_gate(self, Vector3(0, 0, -4.25))
	Rooms.plaque(g, "КОНТРОЛЛЕР / ПОСЛЕДНЯЯ КОМАНДА", Vector3(0, 2.8, -4.12), 3.0)
	Rooms.block(g, Vector3(0.65, 0.9, -3.65), Vector3(0.35, 0.6, 0.2), "petrol")
	Rooms.plaque(g, "ПОВТОР КОМАНДЫ", Vector3(0.65, 1.5, -3.52), 1.5)
	Rooms.plaque(g, "ОБРАТНАЯ СТОРОНА / ОСМОТР", Vector3(0, 1.5, -5.45), 2.7)
	_pressure = Area3D.new()
	_pressure.position = Vector3(1.6, 0.45, -2.1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.65, 1.0)
	shape.shape = box
	_pressure.add_child(shape)
	add_child(_pressure)
	g.flush()
	cube = make_cube(self, Vector3(2.4, 0.32, 1.4), 1.5, Color("f2c750"))
	cube.name = "TestWeight"
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 2.8, 0)
	_lamp.omni_range = 9.0
	add_child(_lamp)
	_panel = Node3D.new()
	_panel.position = Vector3(0, 1.5, -2.8)
	add_child(_panel)
	var panel_g := Rooms.geometry(_panel)
	panel_g.box(Vector3.ZERO, Vector3(1.6, 1.0, 0.12), "cream")
	panel_g.box(Vector3(0, -0.65, 0), Vector3(1.8, 0.15, 0.4), "steel")
	Rooms.plaque(panel_g, "E / МЕТКА", Vector3(-0.4, 0.72, 0.1), 0.85)
	Rooms.plaque(panel_g, "E / ПОВРЕЖДЕНИЕ", Vector3(0.4, 0.54, 0.1), 1.25)
	panel_g.flush()
	_mark = Node3D.new()
	_panel.add_child(_mark)
	var mark_g := Rooms.geometry(_mark)
	mark_g.torus(Vector3(-0.4, 0.15, 0.09), 0.09, 0.13, "accent_magenta", Vector3(PI / 2, 0, 0))
	Rooms.plaque(mark_g, "А-01", Vector3(-0.4, -0.15, 0.1), 0.7)
	mark_g.flush()
	_damage = Node3D.new()
	_panel.add_child(_damage)
	var damage_g := Rooms.geometry(_damage)
	for n in 4:
		damage_g.box(Vector3(0.1 + n * 0.13, 0.3 - n * 0.2, 0.09), Vector3(0.32, 0.025, 0.01), "petrol")
	damage_g.flush()
	_peer = Rooms.actor(self, "artem", Vector3(-3.1, 0, 4.3), 1)
	_person = _peer.get_child(0)
	_person.reached_destination.connect(func(): _peer_arrived = true)
	begin(1)

func version() -> String:
	return ("2.0-C" if case_day == 2 else "1.0") if control_mode else VERSIONS[case_day - 1]

func task() -> String:
	return ["Проверь, что груз удерживает шлюз. Сравни контроль и испытываемую версию: поставь куб на жёлтый привод, обойди непрозрачную перегородку и вернись. Можно проверить сохранённую команду и обратную сторону контроллера.", "Поставь метку А-01 и измени панель. Сравни обычный сброс с переподключением, затем контроль с испытываемой версией. По желанию пригласи Артёма выполнить отдельную проверку.", "Открой записи первого дня. В версии 1.2 повтори прежний маршрут с грузом, затем проверь дополнительное условие — другое освещение. Не утверждай принятие, если не проверил необходимое."][case_day - 1]

func begin(day: int, session: Dictionary = {}) -> void:
	case_day = day
	control_mode = bool(session.get("control_mode", day == 1))
	seconds = float(session.get("seconds", 0.0))
	journal.assign(session.get("events", []))
	snapshots.assign(session.get("snapshots", []))
	peer_result = session.get("peer_result", {}).duplicate(true)
	instruction_seen = bool(session.get("instruction_seen", false))
	_run = int(session.get("run", 1))
	peer_running = false
	_peer.visible = false
	_person.set_process(false)
	_reset_world()
	marked = bool(session.get("marked", false))
	damaged = bool(session.get("damaged", false))
	blue_light = bool(session.get("blue_light", false))
	cube.position = session.get("cube_position", Vector3(2.4, 0.32, 1.4))
	cube.rotation = session.get("cube_rotation", Vector3.ZERO)
	_occlusion_fault = bool(session.get("occlusion_fault", false))
	_cached_open = bool(session.get("cached_open", false))
	_seen_loaded = bool(session.get("seen_loaded", false))
	_went_hidden = bool(session.get("went_hidden", false))
	_replaying = bool(session.get("replaying", false))
	_sync_panel()
	_sync_light()
	_refresh_labels()
	for key in ["mark", "impact", "replay", "inspect"]:
		_targets.erase(key)
	if case_day == 2:
		_targets.merge({"mark": Vector3(-0.4, 1.65, -2.65), "impact": Vector3(0.4, 1.5, -2.65)})
	else:
		_targets.merge({"replay": Vector3(0.65, 1.2, -3.52), "inspect": Vector3(0, 1.5, -5.4)})
	if journal.is_empty():
		_record("Подключение", "Локальная версия " + version(), "action")

func targets() -> Dictionary:
	_targets.cube = cube.position
	return _targets

func _physics_process(delta: float) -> void:
	seconds += delta
	var was_loaded := _loaded
	_loaded = not carried and _pressure.get_overlapping_bodies().has(cube) and cube.linear_velocity.length_squared() < 0.16
	_load_time = _load_time + delta if _loaded else 0.0
	if not _loaded and (was_loaded or carried):
		_seen_loaded = false
		_went_hidden = false
		_occlusion_fault = false
	_refresh_gate()
	if peer_running:
		_update_peer(delta)
	if not carried and (cube.position.y < -4 or absf(cube.position.x) > 7 or absf(cube.position.z) > 8):
		reconnect("Стенд")

func observe(camera: Camera3D, observer: RID) -> void:
	if case_day == 2 or _load_time < 0.8:
		return
	_ray.from = camera.global_position
	_ray.to = cube.global_position
	_ray.exclude = [observer]
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	var visible_cube: bool = not hit.is_empty() and hit.collider == cube
	if visible_cube and not _seen_loaded and camera.is_position_in_frustum(cube.global_position):
		_seen_loaded = true
		_cached_open = gate_open
		_record("Груз на приводе", "Нагрузка 1,5 кг; проход " + ("открыт" if gate_open else "закрыт"), "observation")
	if _seen_loaded and not visible_cube:
		_went_hidden = true
		if case_day == 1 and not control_mode:
			_occlusion_fault = true
			_refresh_gate()
	if _went_hidden and visible_cube:
		_went_hidden = false
		_record("Возврат из-за перегородки", "Груз на месте; проход " + ("открыт" if gate_open else "закрыт"), "comparison")
	if case_day == 3 and blue_light and not _light_trial and _seen_loaded:
		_light_trial = true
		_record("Нагрузка при другом свете", "Нагрузка 1,5 кг; проход " + ("открыт" if gate_open else "закрыт"), "comparison")

func _refresh_gate() -> void:
	var opened := _replaying or (_loaded and not _occlusion_fault and not (case_day == 3 and blue_light and not control_mode))
	if opened != gate_open:
		gate_open = opened
		Rooms.set_gate_open(_gate, opened)
	var status := "ПРИВОД / %s КГ · %s" % ["1,5" if _loaded else "0", "ОТКРЫТ" if gate_open else "ЗАКРЫТ"]
	if _status.text != status:
		_status.text = status

func pickup() -> void:
	carried = true
	cube.freeze = true
	cube.collision_layer = 0
	cube.collision_mask = 0
	_record("Поднять груз", "Куб снят с опоры", "action")

func carry(camera: Camera3D) -> void:
	if carried:
		cube.global_position = camera.to_global(Vector3(0, -0.48, -1.55))
		cube.global_rotation = Vector3(0, camera.global_rotation.y, 0)

func release() -> void:
	if not carried:
		return
	carried = false
	cube.collision_layer = 1
	cube.collision_mask = 1
	cube.freeze = false
	cube.sleeping = false
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO
	_record("Отпустить груз", "Куб передан физике стенда", "action")

func change_mode() -> void:
	if peer_running:
		return
	control_mode = not control_mode
	reconnect()
	_refresh_labels()

func change_light() -> void:
	blue_light = not blue_light
	_light_trial = false
	_sync_light()
	_refresh_gate()
	_record("Изменить свет", "Холодный яркий" if blue_light else "Тёплый исходный", "action")

func stamp(author := "Игрок") -> void:
	marked = true
	_sync_panel()
	_record("Метка А-01", "Метка нанесена на панель", "action", author)

func impact(author := "Игрок") -> void:
	damaged = true
	_sync_panel()
	_record("Изменить панель", "Повреждение видимо на поверхности", "observation", author)

func reset_environment(author := "Игрок") -> void:
	var had_mark := marked
	var had_damage := damaged
	var retained := case_day == 2 and not control_mode and had_mark
	_reset_world()
	marked = retained
	_sync_panel()
	if case_day == 2 and (had_mark or had_damage):
		_record("Обычный сброс панели", "Метка %s; повреждение убрано" % ("осталась" if marked else "убрана"), "comparison", author)
	else:
		_record("Обычный сброс", "Предмет и свет возвращены; команда очищена", "action", author)
	_run += 1

func reconnect(author := "Игрок") -> void:
	var had_mark := marked
	_reset_world()
	_run += 1
	_sync_panel()
	_sync_light()
	_record("Переподключение", "Метка убрана; чистое состояние" if had_mark else "Чистое состояние; версия " + version(), "comparison", author)

func replay_command() -> void:
	if control_mode or case_day != 1:
		_refresh_gate()
		_record("Повтор последней команды", "Нагрузка перепроверена; проход " + ("открыт" if gate_open else "закрыт"), "comparison")
		return
	if not _cached_open or not _occlusion_fault:
		notified.emit("Нет потерянного состояния удержания. Сначала сравни нагрузку до и после ухода за перегородку.")
		return
	_replaying = true
	_refresh_gate()
	_record("Повтор последней команды", "Проход удерживается сохранённой командой", "observation")

func inspect_back(observer_position: Vector3) -> void:
	if to_local(observer_position).z >= -4.45:
		notified.emit("Осмотр выполняется с обратной стороны шлюза.")
		return
	_record("Обратная сторона контроллера", "Проход открыт без нагрузки" if gate_open and not _loaded else "Удержание привода проверено с обратной стороны", "comparison")

func _reset_world() -> void:
	carried = false
	cube.freeze = true
	cube.collision_layer = 1
	cube.collision_mask = 1
	cube.position = Vector3(2.4, 0.32, 1.4)
	cube.rotation = Vector3.ZERO
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO
	cube.freeze = false
	cube.sleeping = false
	_loaded = false
	_load_time = 0
	_seen_loaded = false
	_went_hidden = false
	_occlusion_fault = false
	_cached_open = false
	_replaying = false
	_light_trial = false
	blue_light = false
	marked = false
	damaged = false
	_refresh_gate()
	_sync_light()

func _sync_panel() -> void:
	_panel.visible = case_day == 2
	_mark.visible = marked
	_damage.visible = damaged
	_panel.rotation.y = 0.09 if damaged else 0.0

func _sync_light() -> void:
	_lamp.light_color = Color("bcb4ff") if blue_light else Color("ffdbb2")
	_lamp.light_energy = 1.2 if blue_light else 0.5

func _refresh_labels() -> void:
	_title.text = TITLES[case_day - 1].to_upper() + " / " + version() + (" / КОНТРОЛЬ" if control_mode else " / ИСПЫТАНИЕ")

func _record(condition: String, result: String, kind: String, author := "Игрок") -> void:
	journal.append({"condition": condition, "result": result, "kind": kind, "author": author, "run": _run, "version": version()})
	notified.emit(condition + ": " + result)

func checklist() -> String:
	return TITLES[case_day - 1].to_upper() + " / " + version() + (" · контроль" if control_mode else " · испытание") + "\nЗадание и записи — левый пульт у входа\nЖурнал: %d · F8 — снимок" % journal.size() + ("\nАртём выполняет отдельную проверку" if peer_running else "")

func sample() -> Dictionary:
	return {"internal": true, "case_day": case_day, "version": version(), "seconds": int(seconds), "events": journal.duplicate(true), "snapshots": snapshots.duplicate(), "peer_result": peer_result.duplicate(true)}

func session() -> Dictionary:
	var result := sample()
	result.merge({"run": _run, "control_mode": control_mode, "instruction_seen": instruction_seen, "marked": marked, "damaged": damaged, "blue_light": blue_light, "cube_position": cube.position, "cube_rotation": cube.rotation, "occlusion_fault": _occlusion_fault, "cached_open": _cached_open, "seen_loaded": _seen_loaded, "went_hidden": _went_hidden, "replaying": _replaying})
	return result

func add_snapshot(encoded: String) -> void:
	if snapshots.size() == 2:
		snapshots.pop_front()
	snapshots.append(encoded)
	notified.emit("Снимок сохранён. Он приложен к выборке, но не заменяет вывод.")

func start_peer() -> void:
	if case_day != 2 or peer_running:
		return
	peer_running = true
	peer_result.clear()
	_peer.visible = true
	_peer_step = 0
	_peer_wait = 0
	_peer_walk(Vector3(-3.2, 0, -2.7))
	notified.emit("Артём: сначала очищу среду, затем повторю метку, повреждение и оба сброса.")

func _peer_walk(target: Vector3) -> void:
	_peer_arrived = false
	_person.walk_to(target - _peer.position, 1.6)

func _update_peer(delta: float) -> void:
	if _peer_step == 0 and _peer_arrived:
		_peer_walk(Vector3(0, 0, -2.7))
		_peer_step = 1
	elif _peer_step == 1 and _peer_arrived:
		_peer_walk(Vector3(0, 0, -2.1))
		_peer_step = 2
	elif _peer_step == 2 and _peer_arrived:
		reconnect("Артём")
		_person.face_toward(to_global(Vector3(0, 1.5, -3.0)))
		_peer_step = 3
		_peer_wait = 0.8
	elif _peer_step >= 3 and _peer_step <= 7:
		_peer_wait -= delta
		if _peer_wait > 0:
			return
		match _peer_step:
			3: stamp("Артём")
			4: impact("Артём")
			5:
				reset_environment("Артём")
				_peer_reset_mark = marked
			6: reconnect("Артём")
			7:
				peer_result = {"author": "Артём Королёв", "version": version(), "retained_after_reset": _peer_reset_mark, "cleared_after_reconnect": not marked, "result": "После обычного сброса метка %s. После переподключения метка %s." % ["осталась" if _peer_reset_mark else "убрана", "убрана" if not marked else "осталась"]}
				peer_completed.emit(peer_result.duplicate(true))
				notified.emit("Артём: " + str(peer_result.result))
				_peer_walk(Vector3(0, 0, -2.7))
		_peer_step += 1
		_peer_wait = 0.8
	elif _peer_step == 8 and _peer_arrived:
		_peer_walk(Vector3(-3.2, 0, -2.7))
		_peer_step = 9
	elif _peer_step == 9 and _peer_arrived:
		_peer_walk(Vector3(-3.1, 0, 4.3))
		_peer_step = 10
	elif _peer_step == 10 and _peer_arrived:
		peer_running = false
