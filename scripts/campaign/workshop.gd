extends Node3D

signal notified(text: String)
signal peer_completed(result: Dictionary)

const Rooms := preload("res://scripts/campaign/rooms.gd")
const TITLES := ["Сохранность предмета", "Память среды", "Приёмка исправления"]
const VERSIONS := ["1.1", "2.0", "1.2"]
const OBJECT_NAMES := ["Куб", "Шар", "Цилиндр"]
const STARTS := [Vector3(-1.8, 0.35, 2.0), Vector3(0, 0.35, 2.0), Vector3(1.8, 0.35, 2.0)]
const GAUGE := Vector3(-3.8, 0, -2.3)
var objects: Array[RigidBody3D] = []
var selected := 0
var carried := false
var case_day := 1
var control_mode := true
var blue_light := false
var marked := false
var damaged := false
var peer_running := false
var instruction_seen := false
var seconds := 0.0
var journal: Array[Dictionary] = []
var snapshots: Array[String] = []
var peer_result: Dictionary = {}
var exercises: Dictionary = {}
var _sizes: Array[int] = [1, 1, 1]
var _heavy: Array[bool] = [false, false, false]
var _elastic: Array[bool] = [false, false, false]
var _flying: Array[bool] = [false, false, false]
var _bounce_pending: Array[bool] = [false, false, false]
var _active := true
var _targets := {"mode": Vector3(-6.1, 1.2, -5), "reset": Vector3(-6.1, 1.2, -2), "size_up": Vector3(-6.1, 1.2, 1), "size_down": Vector3(-6.1, 1.2, 4), "reconnect": Vector3(6.1, 1.2, -5), "weight": Vector3(6.1, 1.2, -2), "elastic": Vector3(6.1, 1.2, 1), "throw": Vector3(6.1, 1.2, 4), "case_notes": Vector3(-3, 1.2, 5.4), "finish_case": Vector3(3, 1.2, 5.4), "measure": Vector3(-3.8, 1.1, -0.8), "light": Vector3(0, 1.2, -6.1)}
var _run := 1
var _status: Label3D
var _title: Label3D
var _lamp: OmniLight3D
var _panel: Node3D
var _mark: Node3D
var _damage: Node3D
var _target_body: StaticBody3D
var _peer: Node3D
var _person: Node3D
var _peer_step := 0
var _peer_wait := 0.0
var _peer_arrived := false
var _peer_reset_mark := false

func _ready() -> void:
	var g := Rooms.geometry(self)
	Rooms.shell(g, 7.0, 7.0)
	for x in [-6.7, 6.7]:
		for z in [-5, -2, 1, 4]:
			g.box(Vector3(x, 1.8, z), Vector3(0.12, 3.2, 0.15), "steel")
	for z in [-4.5, 3.5]:
		Rooms.lamp(self, g, Vector3(0, 3.1, z), false, 1.1)
	_title = Rooms.plaque(g, "ПРЕДМЕТНАЯ ЛАБОРАТОРИЯ", Vector3(0, 2.65, -6.65), 4.8)
	for spec in [[-6.1, -5.0, "КОНТРОЛЬ / ВЕРСИЯ", "accent_magenta"], [-6.1, -2.0, "СБРОС / R", "accent_violet"], [-6.1, 1.0, "РАЗМЕР +", "mustard"], [-6.1, 4.0, "РАЗМЕР −", "mustard"], [6.1, -5.0, "ПЕРЕПОДКЛЮЧИТЬ", "accent_magenta"], [6.1, -2.0, "ВЕС / 1,5 ↔ 6 КГ", "petrol"], [6.1, 1.0, "УПРУГОСТЬ", "cross_green"], [6.1, 4.0, "БРОСОК", "accent_violet"], [-3.0, 5.4, "ЗАДАНИЕ / ЗАПИСИ", "accent_violet"], [3.0, 5.4, "В ОТЧЁТ", "cross_green"], [0.0, -6.1, "ОСВЕЩЕНИЕ", "mustard"]]:
		var p := Vector3(spec[0], 0, spec[1])
		Rooms.block(g, p + Vector3(0, 0.55, 0), Vector3(0.65, 1.1, 0.45), "cream")
		g.box(p + Vector3(0, 1.15, 0.25), Vector3(0.45, 0.2, 0.05), spec[3])
		Rooms.plaque(g, spec[2], p + Vector3(0, 1.7, 0.2), 1.7)
	# Fixed measuring cradle: a small object fits; a correctly enlarged one rests on the rails.
	Rooms.block(g, GAUGE + Vector3(0, 0.09, 0), Vector3(1.7, 0.18, 1.8), "steel")
	for x in [-0.55, 0.55]:
		Rooms.block(g, GAUGE + Vector3(x, 0.65, 0), Vector3(0.3, 0.94, 1.8), "mustard")
	Rooms.plaque(g, "ШАБЛОН / ПРОСВЕТ 0,8 М", GAUGE + Vector3(0, 1.9, -0.95), 2.5)
	Rooms.plaque(g, "E / ИЗМЕРИТЬ ПОСАДКУ", Vector3(-3.8, 1.1, -0.8), 2.0)
	# An open throwing lane, distance marks, impact target and a separate bounce pad.
	g.box(Vector3(3.8, 0.02, -1.7), Vector3(2.8, 0.03, 7.4), "petrol")
	for z in [-4, -2, 0, 2]:
		g.box(Vector3(3.8, 0.05, z), Vector3(2.65, 0.025, 0.04), "mustard")
		Rooms.plaque(g, "%d М" % (2 - z), Vector3(5.25, 0.35, z), 0.65)
	g.box(Vector3(3.8, 1.25, -5.7), Vector3(2.4, 2.5, 0.18), "cream")
	_target_body = g.solid(Vector3(3.8, 1.25, -5.7), Vector3(2.4, 2.5, 0.18))
	g.torus(Vector3(3.8, 1.25, -5.58), 0.35, 0.44, "accent_magenta", Vector3(PI / 2, 0, 0))
	g.box(Vector3(3.8, 1.25, -5.56), Vector3(0.06, 1.3, 0.025), "accent_magenta")
	g.box(Vector3(3.8, 1.25, -5.56), Vector3(1.3, 0.06, 0.025), "accent_magenta")
	Rooms.plaque(g, "БРОСОК / ОДИН ИМПУЛЬС", Vector3(3.8, 2.9, -5.7), 2.6)
	g.box(Vector3(0, 0.024, -1.2), Vector3(2.3, 0.025, 2.3), "cross_green")
	Rooms.plaque(g, "ОТСКОК / ТВЁРДЫЙ ПОЛ", Vector3(0, 0.3, -2.5), 2.4)
	_status = Rooms.plaque(g, "ВЫБРАН КУБ", Vector3(0, 2.2, -6.65), 3.8)
	for index in 3:
		var p: Vector3 = STARTS[index]
		g.box(Vector3(p.x, 0.02, p.z), Vector3(1.4, 0.025, 1.4), "teal")
		Rooms.plaque(g, OBJECT_NAMES[index].to_upper(), Vector3(p.x, 0.35, 2.85), 1.25)
		_create_object(index)
	g.flush()
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 2.8, 0)
	_lamp.omni_range = 12.0
	add_child(_lamp)
	_build_memory_panel()
	_peer = Rooms.actor(self, "artem", Vector3(-3.1, 0, 4.3), 1)
	_person = _peer.get_child(0)
	_person.reached_destination.connect(func(): _peer_arrived = true)
	begin(1)

func _create_object(index: int) -> void:
	var body := RigidBody3D.new()
	body.name = ["TestCube", "TestSphere", "TestCylinder"][index]
	body.position = STARTS[index]
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.7
	var mesh := MeshInstance3D.new()
	var shape := CollisionShape3D.new()
	match index:
		0:
			var box := BoxMesh.new()
			box.size = Vector3.ONE * 0.55
			mesh.mesh = box
			var collision := BoxShape3D.new()
			collision.size = box.size
			shape.shape = collision
		1:
			var sphere := SphereMesh.new()
			sphere.radius = 0.275
			sphere.height = 0.55
			sphere.radial_segments = 24
			sphere.rings = 12
			mesh.mesh = sphere
			var collision := SphereShape3D.new()
			collision.radius = sphere.radius
			shape.shape = collision
		2:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.275
			cylinder.bottom_radius = 0.275
			cylinder.height = 0.55
			cylinder.radial_segments = 24
			mesh.mesh = cylinder
			var collision := CylinderShape3D.new()
			collision.radius = 0.275
			collision.height = 0.55
			shape.shape = collision
	var material := StandardMaterial3D.new()
	material.albedo_color = [Color("f2c750"), Color("8175f6"), Color("38ba91")][index]
	material.roughness = 0.6
	mesh.material_override = material
	body.add_child(mesh)
	body.add_child(shape)
	add_child(body)
	objects.append(body)
	body.body_entered.connect(_contact.bind(index))

func _build_memory_panel() -> void:
	_panel = Node3D.new()
	_panel.position = Vector3(0, 1.5, -4.3)
	add_child(_panel)
	var g := Rooms.geometry(_panel)
	g.box(Vector3.ZERO, Vector3(1.6, 1.0, 0.12), "cream")
	g.box(Vector3(0, -0.65, 0), Vector3(1.8, 0.15, 0.4), "steel")
	Rooms.plaque(g, "E / МЕТКА", Vector3(-0.4, 0.72, 0.1), 0.85)
	Rooms.plaque(g, "E / ПОВРЕЖДЕНИЕ", Vector3(0.4, 0.54, 0.1), 1.25)
	g.flush()
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

func selected_body() -> RigidBody3D:
	return objects[selected]

func object_radius() -> float:
	return 0.275 * _sizes[selected]

func version() -> String:
	return ("2.0-C" if case_day == 2 else "1.0") if control_mode else VERSIONS[case_day - 1]

func task() -> String:
	return ["Предметная калибровка: куб, шар и цилиндр. Подними предмет, измени размер кнопками +/−, вес и упругость; попробуй бросок в мишень. Для задания дня сравни посадку обычного и увеличенного куба в жёлтый шаблон шириной 0,8 м: контроль 1.0 и версия 1.1. Измеряй только после остановки предмета; сбрось и повтори.", "Поставь метку А-01 и измени панель. Сравни обычный сброс с переподключением, затем контроль с испытываемой версией. Артём может выполнить отдельную проверку. Предметы, размер, вес и броски остаются доступны для дополнительных опытов.", "Открой записи первого дня и повтори посадку увеличенного куба в версии 1.2. Затем проверь упругость: возьми шар, включи её кнопкой, отпусти с одинаковой высоты над зелёной площадкой и сравни с контролем. Меняй одно условие за раз, повторяй и записывай увиденное."][case_day - 1]

func begin(day: int, saved: Dictionary = {}) -> void:
	case_day = day
	control_mode = bool(saved.get("control_mode", day == 1))
	seconds = float(saved.get("seconds", 0.0))
	journal.assign(saved.get("events", []))
	snapshots.assign(saved.get("snapshots", []))
	peer_result = saved.get("peer_result", {}).duplicate(true)
	exercises = saved.get("exercises", {}).duplicate(true)
	instruction_seen = bool(saved.get("instruction_seen", false))
	_run = int(saved.get("run", 1))
	peer_running = false
	_peer.visible = false
	_person.set_process(false)
	_reset_world()
	selected = clampi(int(saved.get("selected", 0)), 0, 2)
	var states: Array = saved.get("objects", [])
	for index in mini(states.size(), objects.size()):
		var state: Dictionary = states[index]
		_sizes[index] = clampi(int(state.get("size", 1)), 1, 2)
		_heavy[index] = bool(state.get("heavy", false))
		_elastic[index] = bool(state.get("elastic", false))
		_apply_properties(index)
		objects[index].position = state.get("position", STARTS[index])
		objects[index].rotation = state.get("rotation", Vector3.ZERO)
	marked = bool(saved.get("marked", false))
	damaged = bool(saved.get("damaged", false))
	blue_light = bool(saved.get("blue_light", false))
	_sync_panel()
	_sync_light()
	_refresh_labels()
	_targets.erase("mark")
	_targets.erase("impact")
	if case_day == 2:
		_targets.merge({"mark": Vector3(-0.4, 1.65, -4.15), "impact": Vector3(0.4, 1.5, -4.15)})
	if journal.is_empty():
		_record("Подключение", "Предметная лаборатория / версия " + version(), "action")

func targets() -> Dictionary:
	for index in objects.size():
		_targets["object_%d" % index] = objects[index].position
	return _targets

func set_active(active: bool) -> void:
	_active = active
	for index in objects.size():
		objects[index].freeze = not active or (carried and index == selected)

func _physics_process(delta: float) -> void:
	seconds += delta
	if peer_running:
		_update_peer(delta)
	for index in objects.size():
		var body := objects[index]
		if carried and index == selected:
			continue
		if body.position.y < -4 or absf(body.position.x) > 8 or absf(body.position.z) > 8:
			_restore_object(index)
			_record("Возврат предмета", OBJECT_NAMES[index] + " вернулся на своё место", "action")
		if _bounce_pending[index] and body.linear_velocity.y > 0.5:
			_bounce_pending[index] = false
			exercises["bounce"] = true
			_record("Отскок", "%s движется вверх: %.2f м/с" % [OBJECT_NAMES[index], body.linear_velocity.y], "observation")
		elif _bounce_pending[index] and body.sleeping:
			_bounce_pending[index] = false

func _apply_properties(index: int) -> void:
	var body := objects[index]
	var size := float(_sizes[index])
	var physical_size := 1.0 if case_day == 1 and not control_mode else size
	var mesh: MeshInstance3D = body.get_child(0)
	mesh.scale = Vector3.ONE * size
	var collision: CollisionShape3D = body.get_child(1)
	match index:
		0: (collision.shape as BoxShape3D).size = Vector3.ONE * 0.55 * physical_size
		1: (collision.shape as SphereShape3D).radius = 0.275 * physical_size
		2:
			(collision.shape as CylinderShape3D).radius = 0.275 * physical_size
			(collision.shape as CylinderShape3D).height = 0.55 * physical_size
	body.mass = 6.0 if _heavy[index] else 1.5
	body.physics_material_override.bounce = 0.65 if _elastic[index] and not (case_day == 3 and not control_mode) else 0.08
	body.sleeping = false

func pickup(index: int) -> void:
	if carried or peer_running:
		return
	selected = index
	carried = true
	var body := selected_body()
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	_flying[index] = false
	_bounce_pending[index] = false
	exercises["shape_%d" % index] = true
	_refresh_labels()
	_record("Поднять предмет", OBJECT_NAMES[index], "action")

func carry(camera: Camera3D) -> void:
	if carried:
		var body := selected_body()
		body.global_position = camera.to_global(Vector3(0, -0.6, -1.1))
		body.global_rotation = Vector3(0, camera.global_rotation.y, 0)

func release() -> void:
	if not carried:
		return
	carried = false
	var body := selected_body()
	body.collision_layer = 1
	body.collision_mask = 1
	body.freeze = not _active
	body.sleeping = false
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	_flying[selected] = true
	_record("Отпустить предмет", "%s / высота центра %.2f м" % [OBJECT_NAMES[selected], body.position.y], "action")

func throw_object(camera: Camera3D) -> void:
	if not carried:
		notified.emit("Сначала подними куб, шар или цилиндр. Наведи взгляд на мишень; Q — бросок.")
		return
	release()
	var impulse := -camera.global_basis.z * 12.0 + Vector3.UP * 4.5
	selected_body().apply_central_impulse(impulse)
	exercises["throw"] = true
	_record("Бросок", "%s / один импульс / масса %.1f кг" % [OBJECT_NAMES[selected], selected_body().mass], "action")

func resize_object(direction: int) -> void:
	var next := clampi(_sizes[selected] + direction, 1, 2)
	if next == _sizes[selected]:
		notified.emit("Размер уже " + ("максимальный: 1,10 м" if next == 2 else "исходный: 0,55 м"))
		return
	_sizes[selected] = next
	_apply_properties(selected)
	if not carried:
		selected_body().position.y += 0.275 if direction > 0 else 0.0
	exercises["resize"] = true
	_refresh_labels()
	_record("Изменить размер", "%s / %.2f м" % [OBJECT_NAMES[selected], 0.55 * next], "action")

func change_weight() -> void:
	_heavy[selected] = not _heavy[selected]
	_apply_properties(selected)
	exercises["weight"] = true
	_refresh_labels()
	_record("Изменить вес", "%s / %.1f кг; бросок тем же импульсом" % [OBJECT_NAMES[selected], selected_body().mass], "action")

func change_elasticity() -> void:
	_elastic[selected] = not _elastic[selected]
	_apply_properties(selected)
	exercises["elastic"] = true
	_refresh_labels()
	_record("Упругость", OBJECT_NAMES[selected] + (" / включена на пульте" if _elastic[selected] else " / выключена на пульте"), "action")

func measure() -> void:
	var body := selected_body()
	if carried or Vector2(body.position.x - GAUGE.x, body.position.z - GAUGE.z).length() > 0.7:
		notified.emit("Поставь выбранный предмет в жёлтый шаблон. E — поставить; затем измерь посадку.")
		return
	if body.linear_velocity.length_squared() > 0.04:
		notified.emit("Предмет ещё движется. Дождись остановки и повтори измерение.")
		return
	exercises["measure"] = true
	_record("Посадка в шаблон", "%s / заявленный размер %.2f м / высота центра %.2f м" % [OBJECT_NAMES[selected], 0.55 * _sizes[selected], body.position.y], "observation")

func _contact(body: Node, index: int) -> void:
	if not _active or not _flying[index]:
		return
	_flying[index] = false
	_bounce_pending[index] = _elastic[index]
	if body == _target_body:
		exercises["target"] = true
	_record("Попадание в мишень" if body == _target_body else "Контакт с поверхностью", OBJECT_NAMES[index] + " / физическое столкновение", "observation")

func change_mode() -> void:
	if peer_running:
		return
	control_mode = not control_mode
	reconnect()
	_refresh_labels()

func change_light() -> void:
	blue_light = not blue_light
	_sync_light()
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
		_record("Обычный сброс", "Все три предмета, их параметры и свет возвращены", "action", author)
	_run += 1

func reconnect(author := "Игрок") -> void:
	var had_mark := marked
	_reset_world()
	_run += 1
	_sync_panel()
	_sync_light()
	_record("Переподключение", "Метка убрана; чистое состояние" if had_mark else "Чистое состояние; версия " + version(), "comparison", author)

func _restore_object(index: int) -> void:
	var body := objects[index]
	body.freeze = true
	body.collision_layer = 1
	body.collision_mask = 1
	_sizes[index] = 1
	_heavy[index] = false
	_elastic[index] = false
	_flying[index] = false
	_bounce_pending[index] = false
	_apply_properties(index)
	body.position = STARTS[index]
	body.rotation = Vector3.ZERO
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = not _active
	body.sleeping = false

func _reset_world() -> void:
	carried = false
	for index in objects.size():
		_restore_object(index)
	blue_light = false
	marked = false
	damaged = false
	_sync_light()
	_refresh_labels()

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
	_status.text = "%s · %.2f М · %.1f КГ · %s" % [OBJECT_NAMES[selected].to_upper(), 0.55 * _sizes[selected], selected_body().mass, "УПРУГИЙ" if _elastic[selected] else "ОБЫЧНЫЙ"]

func _record(condition: String, result: String, kind: String, author := "Игрок") -> void:
	journal.append({"condition": condition, "result": result, "kind": kind, "author": author, "run": _run, "version": version()})
	notified.emit(condition + ": " + result)

func checklist() -> String:
	return TITLES[case_day - 1].to_upper() + " / " + version() + (" · контроль" if control_mode else " · испытание") + "\nКуб · шар · цилиндр / E — взять и поставить\nQ — бросок · R — сброс · F8 — снимок" + ("\nАртём выполняет отдельную проверку" if peer_running else "\nЗадание и записи — пульт у входа")

func sample() -> Dictionary:
	return {"internal": true, "case_day": case_day, "version": version(), "seconds": int(seconds), "events": journal.duplicate(true), "snapshots": snapshots.duplicate(), "peer_result": peer_result.duplicate(true), "exercises": exercises.duplicate(true)}

func session() -> Dictionary:
	var result := sample()
	var states: Array[Dictionary] = []
	for index in objects.size():
		states.append({"size": _sizes[index], "heavy": _heavy[index], "elastic": _elastic[index], "position": objects[index].position, "rotation": objects[index].rotation})
	result.merge({"run": _run, "control_mode": control_mode, "instruction_seen": instruction_seen, "marked": marked, "damaged": damaged, "blue_light": blue_light, "selected": selected, "objects": states})
	return result

func add_snapshot(encoded: String) -> void:
	if snapshots.size() == 2:
		snapshots.pop_front()
	snapshots.append(encoded)
	notified.emit("Снимок сохранён. Он приложен к выборке, но не заменяет вывод.")

func start_peer() -> void:
	if case_day != 2 or peer_running:
		return
	release()
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
		_peer_walk(Vector3(0, 0, -3.6))
		_peer_step = 2
	elif _peer_step == 2 and _peer_arrived:
		reconnect("Артём")
		_person.face_toward(to_global(Vector3(0, 1.5, -4.3)))
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
