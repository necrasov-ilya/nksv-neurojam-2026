extends Node3D

const Rooms := preload("res://scripts/campaign/rooms.gd")
const Workshop := preload("res://scripts/campaign/workshop.gd")
const Player := preload("res://scripts/intro/player.gd")
const Ambience := preload("res://scripts/intro/ambience.gd")
const Interface := preload("res://scripts/campaign/ui.gd")
const Bridge := preload("res://scripts/campaign/browser_bridge.gd")
const MUSIC := preload("res://assets/audio/campaign/shift_change.ogg")
var player: Player
var ui: Interface
var bridge: Bridge
var workshop: Workshop
var lab: Node3D
var home: Node3D
var service: Node3D
var lab_info: Dictionary
var home_info: Dictionary
var service_info: Dictionary
var _audio: Ambience
var _music: AudioStreamPlayer
var _stage := "lab"
var _busy := false
var _paused := false
var _focused := true
var _module := ""
var _sample: Dictionary = {}
var _probe_seconds := 0.0
var _gate_event := false
var _authorized := false
var _isolated := false
var _manual_hold := false
var _holding_weight := false
var _cube_on_pad := false
var _gate_open := false
var _evac_started := false
var _evac_count := 0
var _evac_prompted := false
var _timer := 90.0
var _weight: RigidBody3D
var _pad: Area3D
var _use_ray := PhysicsRayQueryParameters3D.new()
var _hud_clock := 0.0

func _ready() -> void:
	GameRun.campaign_started = true
	_build_environment()
	lab = Node3D.new()
	lab.name = "TestingFloor"
	add_child(lab)
	lab_info = Rooms.build_lab(lab)
	home = Node3D.new()
	home.name = "Apartment"
	home.position = Vector3(50, 0, 0)
	add_child(home)
	home_info = Rooms.build_home(home)
	service = Node3D.new()
	service.name = "ServiceSector"
	service.position = Vector3(100, 0, 0)
	add_child(service)
	service_info = Rooms.build_service(service)
	workshop = Workshop.new()
	workshop.name = "Calibration"
	workshop.position = Vector3(150, 0, 0)
	add_child(workshop)
	_weight = Workshop.make_cube(service, Vector3(-3.4, 0.35, -0.2), 8.0, Color("e9e5d4"))
	_weight.name = "CeramicWeight"
	_pad = Area3D.new()
	_pad.position = Vector3(0, 0.34, 1.3)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.75, 1.1)
	shape.shape = box
	_pad.add_child(shape)
	service.add_child(_pad)
	_pad.body_entered.connect(func(body: Node3D):
		if body == _weight:
			_cube_on_pad = true
	)
	_pad.body_exited.connect(func(body: Node3D):
		if body == _weight:
			_cube_on_pad = false
	)
	player = Player.new()
	player.name = "CampaignPlayer"
	add_child(player)
	_audio = Ambience.new()
	_audio.volume_db = -5.0
	add_child(_audio)
	player.stepped.connect(_audio.footstep)
	_music = AudioStreamPlayer.new()
	var track: AudioStreamOggVorbis = MUSIC
	track.loop = true
	_music.stream = track
	_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_music.volume_db = -16
	add_child(_music)
	ui = Interface.new()
	add_child(ui)
	ui.modal_changed.connect(_sync_input)
	bridge = Bridge.new()
	add_child(bridge)
	bridge.finished.connect(_world_finished)
	bridge.failed.connect(_world_failed)
	_use_ray.exclude = [player.get_rid()]
	lab_info.nika.visible = GameRun.day != 3
	lab_info.artem.visible = GameRun.day >= 2
	_gate_event = GameRun.gate_event_started
	Rooms.set_gate_open(lab_info.gate, not _gate_event or GameRun.gate_repaired)
	if GameRun.location == "home":
		_set_stage("home", Vector3(0, 0.03, 4.2), 0)
	elif GameRun.incident_started:
		_set_stage("service", Vector3(0, 0.03, 5), 0)
		_start_emergency()
	else:
		_set_stage("lab", Vector3(0, 0.03, 7.5), 0)
		if not GameRun.day_briefed:
			_brief_day.call_deferred()
	if not GameRun.ending.is_empty():
		_show_ending(GameRun.ending)
	_sync_input()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("aaa1ff")
	material.sky_horizon_color = Color("f5f2ff")
	material.ground_bottom_color = Color("8175c5")
	material.ground_horizon_color = Color("f5f2ff")
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6cbff")
	environment.ambient_light_energy = 0.8
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.6
	add_child(sun)
	for position in [Vector3(0, 2.9, 0), Vector3(50, 2.8, 0), Vector3(100, 2.9, 0), Vector3(150, 2.8, 0)]:
		var light := OmniLight3D.new()
		light.position = position
		light.omni_range = 18
		light.light_energy = 0.9
		light.light_color = Color("ffd3c3") if position.x == 50 else Color("ded4ff")
		add_child(light)

func _root_for(stage: String) -> Node3D:
	return {"lab": lab, "home": home, "service": service, "calibration": workshop}[stage]

func _set_stage(stage: String, p: Vector3, yaw: float) -> void:
	_stage = stage
	for root in [lab, home, service, workshop]:
		root.visible = root == _root_for(stage)
	if stage == "lab":
		lab_info.nika.visible = GameRun.day != 3
		lab_info.artem.visible = GameRun.day >= 2
	player.place(_root_for(stage).to_global(p), yaw)
	_audio.set_location("lobby" if stage == "home" else "office")
	_sync_input()

func _sync_input() -> void:
	if ui == null or player == null:
		return
	var free := not _busy and not _paused and _focused and ui.mode == "none" and not bridge.active
	player.enabled = free and not _manual_hold
	for root in [lab, home, service, workshop]:
		root.process_mode = Node.PROCESS_MODE_INHERIT if root == _root_for(_stage) and free else Node.PROCESS_MODE_DISABLED
	workshop.cube.freeze = workshop.carried or not free or _stage != "calibration"
	_weight.freeze = _holding_weight or not free or _stage != "service"
	get_viewport().disable_3d = (ui.mode != "none" and ui.mode != "dialogue" and ui.mode != "pause") or bridge.active
	_audio.set_muted(not GameSettings.sound_enabled or not free)
	_music.stream_paused = not GameSettings.sound_enabled or not free
	ui.set_focused(_focused)
	if free and not OS.has_feature("web"):
		player.capture_mouse()
	elif not free and not bridge.active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _talk(ids: Array, done: Callable = Callable()) -> void:
	ui.dialogue(ids, done)
	_sync_input()

func _brief_day() -> void:
	GameRun.day_briefed = true
	if GameRun.day == 1:
		_talk(["nika_day1_01", "nika_day1_02", "hero_day1_01", "nika_day1_03"])
	elif GameRun.day == 2:
		_talk(["elena_day2_01", "nika_day2_01", "hero_day2_01", "elena_day2_02"])
	else:
		_talk(["elena_day3_01", "artem_day3_01", "nika_day3_01"])

func _process(delta: float) -> void:
	if ui == null or _busy or _paused or not _focused or ui.mode != "none" or bridge.active:
		return
	if GameSettings.sound_enabled and not _music.playing:
		_music.play()
	if _stage == "calibration":
		_probe_seconds += delta
		workshop.carry(player.camera)
	elif _stage == "service":
		if _holding_weight:
			_weight.global_position = player.camera.to_global(Vector3(0, -0.48, -1.55))
			_weight.global_rotation = Vector3(0, player.rotation.y, 0)
		if GameRun.incident_started:
			_update_emergency(delta)
	_hud_clock -= delta
	if _hud_clock <= 0:
		_hud_clock = 0.1
		_update_hud()
	var action := _find_action()
	ui.prompt.text = "E · " + _action_label(action) if not action.is_empty() else ""
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		ui.prompt.text = "ЛКМ · включить обзор" + ("     " + ui.prompt.text if not ui.prompt.text.is_empty() else "")

func _actions() -> Dictionary:
	if _stage == "calibration":
		var result: Dictionary = workshop.actions.duplicate()
		result.cube = workshop.cube.position
		return result
	if _stage == "service":
		var result: Dictionary = service_info.actions.duplicate()
		result.weight = _weight.position
		return result
	return home_info.actions if _stage == "home" else lab_info.actions

func _find_action() -> String:
	if _manual_hold:
		return "release_valve"
	if (_stage == "calibration" and workshop.carried) or (_stage == "service" and _holding_weight):
		return "place_cube"
	var root := _root_for(_stage)
	var nearest := 3.1
	var action := ""
	var targets := _actions()
	for key in targets:
		if key == "nika" and GameRun.day == 3:
			continue
		var target: Vector3 = root.to_global(targets[key])
		var offset := target - player.camera.global_position
		if offset.length() >= nearest or offset.normalized().dot(-player.camera.global_basis.z) < 0.5:
			continue
		_use_ray.from = player.camera.global_position
		_use_ray.to = target
		var hit := get_world_3d().direct_space_state.intersect_ray(_use_ray)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(target) > 0.7:
			continue
		nearest = offset.length()
		action = key
	return action

func _action_label(action: String) -> String:
	var names := {"computer": "рабочий компьютер", "archive": "история отчётов", "nika": "поговорить с Никой", "coffee": "перерыв", "exit": "закончить смену", "service": "служебный сектор", "lab_gate": "местный привод", "home_pc": "личные записи и сообщения", "bed": "лечь спать", "home_exit": "выйти на работу", "home_coffee": "посмотреть на кухню", "cube": "поднять куб", "material": "изменить материал", "light": "изменить свет", "reset": "сбросить состояние", "finish_calibration": "завершить практическую пробу", "place_cube": "поставить предмет · ЛКМ — уронить", "isolate": "изолировать сетевое управление", "permit": "взять местный допуск", "valve": "удерживать привод", "weight": "поднять керамический груз", "escape": "выйти из сектора", "sector_window": "проверить занятость", "release_valve": "отпустить привод"}
	return names.get(action, action)

func _update_hud() -> void:
	if _stage == "calibration":
		ui.objective.text = workshop.checklist().strip_edges()
	elif _stage == "home":
		ui.objective.text = "КВАРТИРА / " + ("ВЕЧЕР ПОСЛЕ СМЕНЫ %d" % GameRun.day if GameRun.home_evening else "УТРО / ДЕНЬ %d" % GameRun.day)
	elif _stage == "service" and GameRun.incident_started:
		ui.objective.text = "АВАРИЯ / ДО ПРОДУВКИ %02d:%02d" % [int(_timer) / 60, int(_timer) % 60]
		ui.objective.text += "\nДопуск %s · Сеть %s · Привод %s\nЭвакуация %d/2" % ["✓" if _authorized else "○", "✓" if _isolated else "○", "✓" if _gate_open else "○", _evac_count]
	else:
		ui.objective.text = "LATENT / ДЕНЬ %d\n%s" % [GameRun.day, GameRun.quota_text()]
		if _gate_event and not GameRun.gate_repaired:
			ui.objective.text += "\nПроход закрыт · Найди местный привод"

func _unhandled_input(event: InputEvent) -> void:
	if not _focused or _busy or bridge.active:
		return
	if ui.mode == "dialogue" and (event.is_action_pressed("intro_use") or event.is_action_pressed("ui_accept")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _paused:
			(ui._page_root as Interface.PauseUI).request_close()
		else:
			_pause()
		get_viewport().set_input_as_handled()
	elif ui.mode == "none" and event.is_action_pressed("intro_use") and not event.is_echo():
		_use(_find_action())
	elif ui.mode == "none" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			player.capture_mouse()
		elif workshop.carried or _holding_weight:
			_release_object(false)
		else:
			var action := _find_action()
			if action in ["cube", "weight"]:
				_use(action)
	elif ui.mode == "none" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		if _manual_hold:
			_manual_hold = false
			_sync_input()
		elif _stage == "calibration":
			workshop.reset_cube()
		elif _holding_weight:
			_release_object(false)

func _use(action: String) -> void:
	if action.is_empty():
		return
	_audio.play_event("ui_click")
	match action:
		"computer": _computer()
		"archive": _computer(1)
		"nika": _talk(["nika_day1_03"] if GameRun.day == 1 else ["nika_day2_01"])
		"coffee": ui.notice("Перерыв", "Коллеги обсуждают завтрашний выпуск. Смена заканчивается по выборке, а не по времени в играх.", ui.close_page)
		"exit": _end_shift()
		"service":
			if GameRun.day < 3:
				ui.notice("Служебный сектор", "Для технической части нужен производственный допуск. Его выдадут на приёмке, после двух смен.", ui.close_page)
			else:
				_travel("service", Vector3(0, 0.03, 5.4), 0)
		"lab_gate": _repair_gate()
		"home_pc": _home_computer()
		"bed": _sleep()
		"home_exit":
			if GameRun.home_evening:
				ui.notice("Вечер дома", "Смена завершена. Утром — следующий рабочий день; сейчас можно просмотреть записи и лечь спать.", ui.close_page)
			else:
				GameRun.go_to_work()
				_travel("lab", Vector3(0, 0.03, 7.5), 0, _brief_day)
		"home_coffee": ui.notice("Кухня", "Ключи на месте. Пропуск рядом с дверью. В квартире тихо; рабочие сообщения лежат на личном компьютере.", ui.close_page)
		"cube": workshop.pickup()
		"material": workshop.change_material()
		"light": workshop.change_light()
		"reset": workshop.reset_cube()
		"place_cube": _release_object(true)
		"finish_calibration": _finish_calibration()
		"permit":
			_authorized = true
			ui.notice("Допуск инженера", "Местный допуск получен. Он разрешает изоляцию сетевого контроллера, независимо от рекомендаций в отчётах.", ui.close_page)
		"isolate": _isolate()
		"valve": _hold_valve()
		"release_valve":
			_manual_hold = false
			_sync_input()
		"weight":
			_holding_weight = true
			_weight.freeze = true
			_weight.collision_layer = 0
			_weight.collision_mask = 0
		"escape": _escape()
		"sector_window": ui.notice("Прямое наблюдение", "Ника находится внутри. На сетевом экране занятость — ноль. Это прогноз без свежего подтверждения, а не измерение присутствия.", ui.close_page)

func _release_object(place: bool) -> void:
	var body: RigidBody3D = workshop.cube if _stage == "calibration" else _weight
	if place:
		_use_ray.from = player.camera.global_position
		_use_ray.to = _use_ray.from - player.camera.global_basis.z * 3.1
		var hit := get_world_3d().direct_space_state.intersect_ray(_use_ray)
		if not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > 0.6:
			body.global_position = hit.position + Vector3.UP * 0.29
	if _stage == "calibration":
		workshop.release()
	else:
		_holding_weight = false
		_weight.collision_layer = 1
		_weight.collision_mask = 1
		_weight.freeze = false
		_weight.sleeping = false
		_weight.linear_velocity = Vector3.ZERO
		_weight.angular_velocity = Vector3.ZERO

func _computer(tab := 0) -> void:
	ui.computer(_launch_module, ui.close_page, _end_shift, tab)

func _launch_module(id: String) -> void:
	if not GameRun.available(id) or (id != "calibration" and not GameRun.calibration_done):
		return
	_module = id
	_sample = {}
	if id == "calibration":
		ui.close_page()
		_probe_seconds = 0
		workshop.begin()
		_travel("calibration", Vector3(0, 0.03, 4.5), 0)
		return
	var body := ui.page("Открывается стенд", "LATENT / " + str(GameRun.module_info(id).title), "browser")
	body.add_child(ui.label("Стенд открыт внутри игрового окна. После кнопки «Завершить тестирование» здесь появится опрос. Закрытие без отчёта не засчитывает наблюдение.", 22))
	ui.button(body, "Вернуться без отчёта", func():
		bridge.abort()
		_computer()
	)
	bridge.launch(GameRun.module_info(id))
	_sync_input()

func _finish_calibration() -> void:
	if not workshop.complete():
		ui.notice("Проба ещё не завершена", "Нужно выполнить все действия в списке. Сброс считается после подъёма, размещения, падения и изменения света или материала.", ui.close_page)
		return
	_sample = {"seconds": int(_probe_seconds), "snapshots": [], "internal": true}
	workshop.release()
	_travel("lab", Vector3(2.6, 0.03, 2.7), 0, func(): _talk(["hero_calibration_01"], _show_survey))

func _world_finished(sample: Dictionary) -> void:
	if sample.get("status", "complete") != "complete":
		_computer()
		return
	_sample = sample
	_show_survey()

func _world_failed(message: String) -> void:
	ui.notice("Стенд не открылся", message, _computer)

func _show_survey() -> void:
	ui.survey(_module, _sample, _save_report)

func _save_report(checked: String, observed: String, recommendation: int, sample: Dictionary) -> void:
	var report: Dictionary = GameRun.save_report(_module, checked, observed, recommendation, sample)
	if report.is_empty():
		return
	if recommendation == 2:
		_talk(["nika_peer_01"], _computer)
	elif recommendation in [1, 3] and GameRun.day >= 2:
		_talk(["elena_review_01"], _computer)
	else:
		_computer()

func _end_shift() -> void:
	if not GameRun.quota_ready():
		ui.notice("Смена ещё не закончена", "Осталась обязательная выборка: " + GameRun.quota_text(), ui.close_page)
		return
	if GameRun.day == 1:
		_talk(["nika_hired_01", "hero_hired_01"], _go_home)
	elif GameRun.day == 2:
		if not GameRun.gate_repaired:
			if not _gate_event:
				_gate_event = true
				GameRun.gate_event_started = true
				GameRun.sign_release()
				Rooms.set_gate_open(lab_info.gate, false)
				_talk(["artem_gate_01"])
			else:
				ui.notice("Проход закрыт", "Нужен жёлтый местный привод у стеклянного поста.", ui.close_page)
		else:
			_go_home()
	else:
		_travel("service", Vector3(0, 0.03, 4.9), 0, func(): _talk(["artem_alarm_01", "nika_alarm_01", "hero_alarm_01", "elena_alarm_01", "artem_rescue_01"], _incident_choice))

func _repair_gate() -> void:
	if not _gate_event or GameRun.gate_repaired:
		ui.notice("Местный привод", "Ручной режим управляет настоящим проходом. Во время рабочей выборки его обслуживает эксплуатация.", ui.close_page)
		return
	Rooms.set_gate_open(lab_info.gate, true)
	_audio.play_event("office_door_open")
	_talk(["hero_gate_01", "artem_gate_02"], func():
		var person: Node3D = lab_info.artem.get_child(0)
		person.reached_destination.connect(func():
			GameRun.gate_repaired = true
			_talk(["artem_gate_03"])
		, CONNECT_ONE_SHOT)
		person.walk_to(Vector3(0, 0, 4), 1.6)
	)

func _go_home() -> void:
	GameRun.go_home()
	_travel("home", Vector3(-1.0, 0.03, 4.7), 0, func(): _talk(["hero_home1_01"] if GameRun.day == 1 else ["hero_home2_01"]))

func _home_computer() -> void:
	var body := ui.page("Личный стол", "КВАРТИРА / НЕ КОРПОРАТИВНЫЙ СТЕНД", "home")
	body.add_child(ui.label("Новая работа началась с обычной практической пробы. Завтра — больше самостоятельных решений." if GameRun.day == 1 else "Мои записи остаются отдельно от производственного допуска. На работе шлюз открылся только в местном режиме.", 22))
	body.add_child(ui.label("Будильник: 08:00 · пропуск и ключи у двери", 19))
	ui.report_list(body)
	if GameRun.day >= 2:
		var send := ui.button(body, "Отправить Нике копию записей" if not GameRun.shared_notes else "Ника получила отдельную копию", func():
			GameRun.share_notes()
			_talk(["hero_share_01"], _home_computer)
		, true)
		send.disabled = GameRun.shared_notes
		body.add_child(ui.label("Это откроет прямую помощь и подготовленный местный допуск. Сохранить только у себя тоже можно; аварийное управление остаётся доступным.", 17, Interface.MUTED))
	ui.button(body, "Отойти от стола", ui.close_page)

func _sleep() -> void:
	if not GameRun.home_evening:
		ui.notice("Утро", "Будильник уже прозвенел. Пропуск у двери; можно идти на работу.", ui.close_page)
		return
	_busy = true
	ui.close_page()
	_sync_input()
	var tween := create_tween()
	tween.tween_property(ui.fade, "color:a", 1.0, 0.6)
	await tween.finished
	GameRun.sleep()
	await get_tree().create_timer(2.0).timeout
	var reveal := create_tween()
	reveal.tween_property(ui.fade, "color:a", 0.0, 0.7)
	await reveal.finished
	_busy = false
	_talk(["hero_morning2_01"] if GameRun.day == 2 else ["hero_morning3_01"])

func _travel(stage: String, p: Vector3, yaw: float, done: Callable = Callable()) -> void:
	_busy = true
	ui.close_page()
	_sync_input()
	_audio.play_event("entrance_door")
	var tween := create_tween()
	tween.tween_property(ui.fade, "color:a", 1.0, 0.25)
	await tween.finished
	_set_stage(stage, p, yaw)
	await get_tree().create_timer(0.2).timeout
	var reveal := create_tween()
	reveal.tween_property(ui.fade, "color:a", 0.0, 0.35)
	await reveal.finished
	_busy = false
	_sync_input()
	if done.is_valid():
		done.call()

func _incident_choice() -> void:
	var body := ui.page("Сектор не пуст", "РЕАЛЬНАЯ АВАРИЯ / ТАЙМЕР ЕЩЁ НЕ ЗАПУЩЕН", "decision")
	body.add_child(ui.label("Ника внутри. Продувка разрешена прогнозом пустого сектора. Можно уйти с этажа или вмешаться через местное управление. Ранние ответы не запрещают помощь.", 23))
	ui.button(body, "Изолировать управление и открыть шлюз", func(): _talk(["hero_rescue_01", "nika_contact_01" if GameRun.has_contact() else "artem_local_01"], _start_emergency), true)
	ui.button(body, "Уйти с этажа", func(): _talk(["hero_leave_01"], func(): _show_ending("leave")))

func _start_emergency() -> void:
	GameRun.start_incident()
	_timer = 90
	_authorized = _authorized or GameRun.has_contact()
	_isolated = false
	_manual_hold = false
	_holding_weight = false
	_gate_open = false
	_evac_started = false
	_evac_count = 0
	_evac_prompted = false
	Rooms.set_gate_open(service_info.gate, false)
	Rooms.set_gate_open(service_info.exit_gate, false)
	ui.close_page()
	_sync_input()

func _isolate() -> void:
	if not GameRun.incident_started:
		ui.notice("Производственный контроллер", "Режим приёмки. Сетевое управление активно; местный допуск потребуется при ручном вмешательстве.", ui.close_page)
	elif not _authorized:
		ui.notice("Нужен местный допуск", "Инженер оставил допуск на правом столе. Любые прежние ответы позволяют его взять.", ui.close_page)
	elif not _isolated:
		_isolated = true
		_talk(["hero_isolate_01"])

func _hold_valve() -> void:
	if not GameRun.incident_started or not _isolated:
		ui.notice("Привод заблокирован", "Сначала изолируй сетевое управление на левом контроллере. Для него нужен местный допуск.", ui.close_page)
		return
	_manual_hold = true
	_sync_input()
	if not _evac_started:
		_talk(["artem_valve_01"])

func _update_emergency(delta: float) -> void:
	_timer = maxf(0, _timer - delta)
	var weighted := _cube_on_pad and not _holding_weight and _weight.linear_velocity.length_squared() < 0.16
	var opened := _isolated and (_manual_hold or weighted)
	if opened != _gate_open:
		_gate_open = opened
		Rooms.set_gate_open(service_info.gate, opened)
		Rooms.set_gate_open(service_info.exit_gate, opened)
		_audio.play_event("office_door_open" if opened else "office_door_close")
		for key in ["nika", "artem"]:
			service_info[key].get_child(0).set_process(opened)
	if opened and not _evac_started:
		_evac_started = true
		for key in ["nika", "artem"]:
			var actor: Node3D = service_info[key]
			var person: Node3D = actor.get_child(0)
			person.reached_destination.connect(func():
				actor.hide()
				_evac_count += 1
			, CONNECT_ONE_SHOT)
			var local := service.to_local(actor.global_position)
			person.walk_to(Vector3(0.8 - local.x, 0, 6.25 - local.z), 1.6)
	if _evac_count == 2 and not _evac_prompted:
		_evac_prompted = true
		_talk(["nika_exit_01"], _after_evacuation)
	if _timer <= 0:
		_game_over()

func _after_evacuation() -> void:
	if not _manual_hold:
		_talk(["hero_weight_01"])
		return
	var body := ui.page("Они вышли", "ПРИВОД ДЕРЖИТ ОБА ПРОХОДА", "decision")
	body.add_child(ui.label("Если отпустить привод, твой выход тоже закроется. Можно остаться у рукояти до продувки — или отпустить её и закрепить площадку керамическим грузом, пока ещё есть время.", 23))
	ui.button(body, "Остаться у привода", func(): _talk(["hero_hold_01"], _sacrifice), true)
	ui.button(body, "Отпустить и закрепить грузом", func():
		_manual_hold = false
		ui.close_page()
		_sync_input()
	)

func _escape() -> void:
	if not GameRun.incident_started:
		_travel("lab", Vector3(7.5, 0.03, 9.6), PI)
	elif _evac_count < 2:
		ui.notice("Люди ещё внутри", "Для спасения нужно удерживать проход до выхода обоих сотрудников. Альтернативу уйти можно выбрать до вмешательства; здесь повторяется аварийный участок.", ui.close_page)
	elif not _gate_open:
		ui.notice("Выход закрыт", "Оба прохода требуют нагрузки на площадку. Керамический груз должен лежать на жёлтой площадке, не висеть в руках.", ui.close_page)
	else:
		_talk(["hero_safe_01", "nika_safe_01"], func(): _show_ending("safe"))

func _sacrifice() -> void:
	_busy = true
	_sync_input()
	await get_tree().create_timer(2.5).timeout
	_talk(["artem_last_01"], func(): _show_ending("sacrifice"))
	_busy = false

func _game_over() -> void:
	_manual_hold = false
	var body := ui.page("GAME OVER", "АВАРИЙНЫЙ УЧАСТОК / ВЫБОРКИ И ОТЧЁТЫ СОХРАНЕНЫ", "gameover")
	body.add_child(ui.label("Продувка началась до безопасного выхода. Повтор начнётся у входа в сектор: город, собеседование и смены проходить заново не нужно.", 23))
	ui.button(body, "Повторить аварийный участок", _restart_incident, true)
	ui.button(body, "Главное меню", _menu)

func _restart_incident() -> void:
	get_tree().reload_current_scene()

func _show_ending(id: String) -> void:
	GameRun.complete(id)
	_manual_hold = false
	var titles := {"safe": "ЛЮДИ ВЫШЛИ", "sacrifice": "ПРИВОД УДЕРЖАН", "leave": "СМЕНА ЗАКОНЧЕНА"}
	var texts := {"safe": "Ника и Артём вышли. Керамический груз удержал привод, и ты успел выйти следом. Сетевой контроллер изолирован. Ошибка прогноза больше не является командой для этого сектора.", "sacrifice": "Ника и Артём вышли. Ты остался у привода, чтобы проходы не закрылись во время эвакуации. После начала продувки на связь никто не ответил. Сетевой контроллер изолирован.", "leave": "Ты вышел с этажа до вмешательства. Аварийное управление осталось на прогнозе пустого сектора. Твои отчёты сохранились; производственный выпуск не отозван."}
	var body := ui.page(titles[id], "LATENTPUNK: TEST SUBJECT 0 / ФИНАЛ", "ending")
	body.add_child(ui.label(texts[id], 24))
	body.add_child(ui.label("Наблюдений сохранено: %d · Дней: %d\nОтдельная копия: %s · Прямой контакт: %s" % [GameRun.reports.size(), GameRun.day, "да" if GameRun.shared_notes else "нет", "да" if GameRun.has_contact() else "нет"], 19, Interface.MUTED))
	ui.button(body, "Титры", func(): _credits(id), true)
	ui.button(body, "Начать заново", _new_game)
	ui.button(body, "Главное меню", _menu)

func _credits(ending_id: String) -> void:
	var body := ui.page("Титры", "LATENTPUNK: TEST SUBJECT 0 / МЫ ТЕСТИРУЕМ РЕАЛЬНОСТЬ")
	body.add_child(ui.label("Главный участник — концепция, режиссура, решения о механиках, озвучивание главного героя.\nAI-ассистенты — программирование, постановка и подготовка ресурсов под руководством участника.\nМузыка: Shift Change — собственная композиция проекта, без чужих семплов.\nДвижок: Godot 4.7.2 Standard.\nШрифт интерфейса: OpenRunde.\nЗвуки и существующие голоса: происхождение, авторство и условия в assets/SOURCES.md и включённых notices.", 21))
	body.add_child(ui.label("Контрольные среды: DUSTFALL и DEAD PARADE — проекты участника; выбранные среды bench-portal — с разрешения владельцев. Исходные manifests, авторство и лицензии сохранены рядом со сборками.\nМодели и версии каждого стенда указаны в его game.json. Готовые игры не названы собственными исходниками и не переписаны ради переходов.", 19, Interface.MUTED))
	ui.button(body, "К финалу", func(): _show_ending(ending_id), true)
	ui.button(body, "Главное меню", _menu)

func _pause() -> void:
	_paused = true
	ui.suspend_page()
	var body := ui.page("Пауза", "", "pause")
	var drawer := ui._page_root as Interface.PauseUI
	drawer.close_requested.connect(_resume)
	ui.button(body, "Продолжить", drawer.request_close, true)
	ui.button(body, "Настройки", drawer.show_settings)
	drawer.add_settings(func(value: bool):
		GameSettings.set_sound_enabled(value)
		bridge.set_muted(not value)
	, GameSettings.set_subtitles_enabled)
	if _stage == "calibration":
		ui.button(body, "Вернуться к компьютеру без отчёта", func():
			_paused = false
			workshop.release()
			_travel("lab", Vector3(2.6, 0.03, 2.7), 0, _computer)
		)
	if GameRun.incident_started:
		ui.button(body, "Повторить аварийный участок", _restart_incident)
	ui.button(body, "Главное меню", _menu)
	_sync_input()

func _resume() -> void:
	_paused = false
	ui.restore_page()
	_sync_input()

func _menu() -> void:
	bridge.abort()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().disable_3d = false
	get_tree().change_scene_to_file("res://scenes/start.tscn")

func _new_game() -> void:
	GameRun.new_run()
	get_viewport().disable_3d = false
	get_tree().change_scene_to_file("res://scenes/prologue.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		_sync_input()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true
		_sync_input()

func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.set_muted(true)
	if is_instance_valid(_music):
		_music.stream_paused = false
		_music.stop()
		_music.stream = null
	get_viewport().disable_3d = false
