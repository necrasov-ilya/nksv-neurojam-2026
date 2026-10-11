extends Node3D

const Rooms := preload("res://scripts/campaign/rooms.gd")
const Workshop := preload("res://scripts/campaign/workshop.gd")
const Player := preload("res://scripts/intro/player.gd")
const Ambience := preload("res://scripts/intro/ambience.gd")
const Interface := preload("res://scripts/campaign/ui.gd")
const Bridge := preload("res://scripts/campaign/browser_bridge.gd")
const MUSIC := preload("res://assets/audio/campaign/shift_change.ogg")
const Interludes := preload("res://scripts/campaign/interludes.gd")
const DREAM_MUSIC := preload("res://assets/audio/campaign/dream_ossuary.ogg")
const Dialogue := preload("res://scripts/campaign/dialogue.gd")
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
var _use_ray := PhysicsRayQueryParameters3D.new()
var _hud_clock := 0.0
var _roots: Dictionary = {}
var _interludes: Dictionary = {}
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _scene_seconds := 0.0
var _cafe_seated := false
var _bus_arrived := false
var _dream_music: AudioStreamPlayer
var _camera_turn: Tween
var _transition_sound: AudioStreamPlayer

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
	workshop.name = "LocalTestStand"
	workshop.position = Vector3(150, 0, 0)
	add_child(workshop)
	_roots = {"lab": lab, "home": home, "service": service, "stand": workshop}
	for stage in ["evening", "bus", "dream"]:
		var root := Node3D.new()
		root.name = stage.to_pascal_case()
		root.position.x = 220 + _interludes.size() * 110
		add_child(root)
		_roots[stage] = root
		match stage:
			"evening": _interludes[stage] = Interludes.evening(root)
			"bus": _interludes[stage] = Interludes.bus(root)
			"dream": _interludes[stage] = Interludes.dream(root)
	player = Player.new()
	player.name = "CampaignPlayer"
	player.sprint_available = true
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
	_dream_music = AudioStreamPlayer.new()
	_dream_music.stream = DREAM_MUSIC
	_dream_music.volume_db = -15
	add_child(_dream_music)
	_transition_sound = AudioStreamPlayer.new()
	_transition_sound.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_transition_sound)
	var tape_layer := CanvasLayer.new()
	tape_layer.layer = 0
	add_child(tape_layer)
	var tape := ColorRect.new()
	tape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tape_material := ShaderMaterial.new()
	tape_material.shader = preload("res://assets/shaders/intro_tape.gdshader")
	tape_material.set_shader_parameter("noise_texture", preload("res://assets/textures/intro/tape_noise.png"))
	tape.material = tape_material
	tape_layer.add_child(tape)
	ui = Interface.new()
	add_child(ui)
	workshop.notified.connect(ui.say)
	workshop.peer_completed.connect(func(result: Dictionary): GameRun.record_peer_result("environment_memory", result))
	ui.modal_changed.connect(_sync_input)
	ui.speaker_changed.connect(_face_speaker)
	bridge = Bridge.new()
	add_child(bridge)
	bridge.finished.connect(_world_finished)
	bridge.failed.connect(_world_failed)
	_use_ray.exclude = [player.get_rid()]
	lab_info.nika.visible = true
	lab_info.artem.visible = GameRun.day >= 2
	Rooms.set_gate_open(lab_info.gate, true)
	Rooms.set_gate_open(service_info.gate, true)
	Rooms.set_gate_open(service_info.exit_gate, true)
	service_info.nika.hide()
	service_info.artem.hide()
	service_info.occupancy.text = "СЕРВИСНЫЙ РЕЖИМ / МЕСТНОЕ УПРАВЛЕНИЕ"
	if GameRun.location == "evening":
		_set_stage("evening", Vector3(8, 0.03, 22), 0)
		if GameRun.tour_pending:
			_arrival_tour()
	elif GameRun.location == "bus":
		_set_stage("bus", Vector3(0.85, -0.35, 1.75), PI / 2)
	elif GameRun.location == "dream":
		_set_stage("dream", Vector3(0, 0.03, 3), 0)
	elif GameRun.location == "home":
		_set_stage("home", Vector3(-1.5, 0.03, 4.2), 0)
	elif GameRun.location == "stand" and not GameRun.active_case.is_empty():
		_module = GameRun.active_case
		workshop.begin(int(GameRun.module_info(_module).case_day), GameRun.case_sessions.get(_module, {}))
		_set_stage("stand", Vector3(0, 0.03, 4.5), 0)
	else:
		_set_stage("lab", Vector3(2.6, 0.03, 4.5), 0)
		if not GameRun.day_briefed:
			_brief_day.call_deferred()
	if not GameRun.ending.is_empty():
		_show_ending()
	_sync_input()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color("929bc5")
	_sky.sky_horizon_color = Color("e5d9d7")
	_sky.ground_bottom_color = Color("282637")
	_sky.ground_horizon_color = Color("e5d9d7")
	sky.sky_material = _sky
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("b9b6d6")
	_environment.ambient_light_energy = 0.38
	world.environment = _environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-28, -25, 0)
	_sun.light_energy = 0.9
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 80
	add_child(_sun)

func _light_stage() -> void:
	var evening := _stage in ["evening", "bus"] or (_stage == "home" and GameRun.home_evening)
	var dark := _stage in ["service", "dream"] or (_stage == "home" and evening)
	_sky.sky_top_color = Color("403953") if dark else Color("8c82b0") if evening else Color("929bc5")
	_sky.sky_horizon_color = Color("ce927f") if evening else Color("e5d9d7")
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sun.rotation_degrees = Vector3(-9 if evening else -28, -58 if evening else -25, 0)
	_sun.light_color = Color("ffd0a0") if evening else Color("ffedda")
	_sun.light_energy = 0.15 if dark else 1.1 if evening else 0.85
	_environment.ambient_light_energy = 0.23 if dark else 0.40
	_environment.ambient_light_color = Color("a5a3ce") if dark else Color("c5bbd5")
	_environment.fog_enabled = _stage == "dream"
	_environment.fog_light_color = Color("eeecff")
	_environment.fog_density = 0.025 if _stage == "dream" else 0.0

func _root_for(stage: String) -> Node3D:
	return _roots[stage]

func _set_stage(stage: String, p: Vector3, yaw: float) -> void:
	_stage = stage
	_scene_seconds = 0.0
	_cafe_seated = false
	_bus_arrived = false
	player.seated = stage == "bus"
	player.sprint_available = stage not in ["dream", "bus", "stand"]
	for key in _roots:
		_roots[key].visible = key == stage
	if stage in ["evening", "bus", "dream", "home", "lab", "stand"]:
		GameRun.location = stage
	if stage == "lab":
		lab_info.nika.visible = true
		lab_info.artem.visible = GameRun.day >= 2
		lab_info.elena.visible = GameRun.day >= 2
		Rooms.dress_shift(lab_info, GameRun.day, GameRun.interview_answers)
		lab_info.nika.position = Vector3(0.4, 0, 1.0)
		lab_info.actions.nika = lab_info.nika.position + Vector3.UP * 1.3
	elif stage == "home":
		Rooms.dress_shift(home_info, GameRun.day, GameRun.interview_answers, true, GameRun.home_evening)
	player.place(_root_for(stage).to_global(p), yaw)
	_audio.set_location("street" if stage == "evening" else "lobby" if stage in ["home", "bus"] else "office")
	_audio.volume_db = -16.0 if stage == "dream" else -5.0
	_light_stage()
	_update_hud()
	_sync_input()
	if stage == "dream":
		_dream_music.play()
	else:
		_dream_music.stop()
	for key in ["nika", "artem", "elena"]:
		if stage == "lab":
			_face_actor(lab_info[key])

func _face_actor(actor: Node3D) -> void:
	actor.get_child(0).face_toward(player.global_position)

func _play_transition_event(event_name: String) -> void:
	var spec: Array = Ambience.EVENTS[event_name]
	_transition_sound.stream = spec[0]
	_transition_sound.volume_db = spec[1]
	_transition_sound.play()
	_transition_sound.stream_paused = not GameSettings.sound_enabled or not _focused or _paused

func _face_speaker(id: String) -> void:
	ui.speaker_context = ""
	var speaker: String = Dialogue.line(id)[2]
	if speaker == "hero":
		return
	var info := lab_info if _stage == "lab" else service_info if _stage == "service" else {}
	if not info.has(speaker) or not info[speaker].visible:
		ui.speaker_context = "по внутренней связи"
		return
	var actor: Node3D = info[speaker]
	_face_actor(actor)
	var direction := actor.global_position - player.global_position
	if direction.length() > 9.0:
		ui.speaker_context = "по внутренней связи"
		return
	if _camera_turn and _camera_turn.is_valid():
		_camera_turn.kill()
	_camera_turn = create_tween()
	var yaw := atan2(-direction.x, -direction.z)
	yaw = player.rotation.y + wrapf(yaw - player.rotation.y, -PI, PI)
	_camera_turn.tween_property(player, "rotation:y", yaw, 0.45)

func _arrival_tour() -> void:
	GameRun.tour_pending = false
	_busy = true
	ui.transition_card("Главный офис → испытательный корпус\nПозже в тот же день")
	_talk(["hero_office_tour"], func():
		ui.clear_transition()
		_busy = false
		_sync_input()
	)

func _sync_input() -> void:
	if ui == null or player == null:
		return
	var free := not _busy and not _paused and _focused and ui.mode == "none" and not bridge.active
	player.enabled = free
	for root in _roots.values():
		root.process_mode = Node.PROCESS_MODE_INHERIT if root == _root_for(_stage) and free else Node.PROCESS_MODE_DISABLED
	workshop.cube.freeze = workshop.carried or not free or _stage != "stand"
	get_viewport().disable_3d = bridge.active
	_audio.set_muted(not GameSettings.sound_enabled or not free or _stage == "bus")
	_music.stream_paused = not GameSettings.sound_enabled or not free or _stage != "lab"
	_dream_music.stream_paused = not GameSettings.sound_enabled or not free or _stage != "dream"
	_transition_sound.stream_paused = not GameSettings.sound_enabled or not _focused or _paused
	for stage in ["evening", "bus"]:
		var sound: Node = _interludes[stage].audio
		if _stage == stage and not sound.playing:
			sound.play()
		sound.stream_paused = not GameSettings.sound_enabled or not free or _stage != stage
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
		var lines: Array = ["nika_day1_01"]
		var personal := GameRun.interview_line("isolation")
		if not personal.is_empty():
			lines.append(personal)
		lines.append_array(["nika_day1_02", "hero_day1_01", "nika_day1_03"])
		_talk(lines)
	elif GameRun.day == 2:
		var lines: Array = ["elena_day2_01", "nika_day2_01", "hero_day2_01", "elena_day2_02"]
		var personal := GameRun.interview_line("communication")
		if not personal.is_empty():
			lines.append(personal)
		_talk(lines)
	else:
		_talk(["elena_day3_01", "artem_day3_01", "nika_day3_01"])

func _process(delta: float) -> void:
	if ui == null or _busy or _paused or not _focused or ui.mode != "none" or bridge.active:
		return
	if GameSettings.sound_enabled and _stage == "lab" and not _music.playing:
		_music.play()
	if _stage == "stand":
		workshop.carry(player.camera)
		workshop.observe(player.camera, player.get_rid())
	elif _stage in ["evening", "bus", "dream"]:
		_update_interlude(delta)
		if _busy:
			return
	_hud_clock -= delta
	if _hud_clock <= 0:
		_hud_clock = 0.1
		_update_hud()
	var action := _find_action()
	ui.prompt.text = "E · " + _action_label(action) if not action.is_empty() else ""
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		ui.prompt.text = "ЛКМ · включить обзор" + ("     " + ui.prompt.text if not ui.prompt.text.is_empty() else "")

func _actions() -> Dictionary:
	if _interludes.has(_stage):
		return _interludes[_stage].actions
	if _stage == "stand":
		return workshop.targets()
	if _stage == "service":
		return {"escape": service_info.actions.escape, "sector_window": service_info.actions.sector_window}
	return home_info.actions if _stage == "home" else lab_info.actions

func _update_interlude(delta: float) -> void:
	_scene_seconds += delta
	if _stage == "bus":
		var speed := 5.0 * minf(_scene_seconds / 4.0, 1.0) * clampf((26.0 - _scene_seconds) / 5.0, 0, 1)
		for chunk: Node3D in _interludes.bus.scenery:
			chunk.position.z += delta * speed
			if chunk.position.z > 45:
				chunk.position.z -= 90
		if _scene_seconds >= 26 and not _bus_arrived:
			_bus_arrived = true
			_audio.play_event("entrance_door")
			ui.say("Остановка «Парковая». Приехали.")
	elif _stage == "dream":
		var stretch := 1.0 + minf(_scene_seconds, 22.0) * 0.085
		var frames: Array = _interludes.dream.frames
		for index in frames.size():
			frames[index].position.z = -index * 5.0 * stretch
		_interludes.dream.exit.position.z = -62 * stretch
		_interludes.dream.light.position.z = player.position.z - _root_for("dream").position.z - 8
		ui.fade.color = Color(1, 1, 1, clampf((_scene_seconds - 24.0) / 6.0, 0, 1))
		if _scene_seconds >= 30:
			_wake_from_dream()

func _find_action() -> String:
	if _stage == "bus":
		return "bus_exit" if _bus_arrived else ""
	if _cafe_seated:
		return "cafe_leave" if _scene_seconds >= 8 else ""
	if _stage == "stand" and workshop.carried:
		return "place_cube"
	var root := _root_for(_stage)
	var nearest := 3.1
	var action := ""
	var targets := _actions()
	for key in targets:
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
	var names := {"computer": "рабочий компьютер", "archive": "история отчётов", "nika": "поговорить с Никой", "coffee": "перерыв", "exit": "закончить смену", "service": "служебный сектор", "lab_gate": "местный привод", "home_pc": "личные записи и сообщения", "bed": "лечь спать", "home_exit": "выйти на работу", "home_coffee": "посмотреть на кухню", "cube": "поднять куб", "mode": "сменить контроль / испытываемую версию", "light": "изменить свет", "reset": "обычный сброс", "reconnect": "переподключить среду", "case_notes": "задание, журнал и собственные записи", "finish_case": "вернуться с выборкой в отчёт", "place_cube": "поставить предмет · ЛКМ — уронить", "mark": "поставить метку А-01", "impact": "изменить панель", "replay": "повтор последней команды", "inspect": "осмотреть обратную сторону", "escape": "вернуться на рабочий этаж", "sector_window": "проверить сервисный режим"}
	names.merge({"cafe_sit": "присесть и посмотреть на закат", "cafe_leave": "встать и пройти к автобусу", "bus_board": "сесть в автобус №18", "bus_exit": "выйти на своей остановке"})
	if action == "exit" and GameRun.shift_released:
		return "выйти с этажа" if GameRun.day == 3 else "выйти в город"
	return names.get(action, action)

func _update_hud() -> void:
	if _stage == "evening":
		ui.objective.text = "ДОРОГА ДОМОЙ\n" + ("Посиди немного. Можно осмотреться." if _cafe_seated else "Автобус №18 у кафе · Shift — бег" if GameRun.cafe_visited or GameRun.day > 0 else "Кафе впереди. Присядь перед дорогой.")
	elif _stage == "bus":
		ui.objective.text = "МАРШРУТ 18 / ПАРКОВАЯ" + ("\nТвоя остановка · можно выходить" if _bus_arrived else "\nДорога домой")
	elif _stage == "dream":
		ui.objective.text = ""
	elif _stage == "stand":
		ui.objective.text = workshop.checklist()
	elif _stage == "home":
		ui.objective.text = ("ВЕЧЕР ПОСЛЕ СОБЕСЕДОВАНИЯ" if GameRun.day == 0 else "КВАРТИРА / ВЕЧЕР" if GameRun.home_evening else "УТРО / ДЕНЬ %d" % GameRun.day)
		ui.objective.text += "\nЛичный стол · затем сон" if GameRun.home_evening else "\nКлючи у двери · выйти на работу"
	elif _stage == "service":
		ui.objective.text = "СЛУЖЕБНЫЙ СЕКТОР\nСервисный режим · можно вернуться на этаж"
	else:
		ui.objective.text = "LATENT / ДЕНЬ %d\n%s" % [GameRun.day, GameRun.quota_text()]
		if GameRun.shift_released:
			ui.objective.text = ("ПРОГРАММА ЗАВЕРШЕНА" if GameRun.day == 3 else "СМЕНА ЗАКОНЧЕНА") + "\nВыйди через дверь к лифту"

func _unhandled_input(event: InputEvent) -> void:
	if not _focused or _busy or bridge.active:
		return
	if ui.mode == "dialogue" and (event.is_action_pressed("intro_use") or event.is_action_pressed("ui_accept")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _paused:
			(ui._page_root as Interface.PauseUI).request_close()
		elif ui.mode in ["computer", "home", "report", "case_notes", "program"]:
			ui.close_page()
		else:
			_pause()
		get_viewport().set_input_as_handled()
	elif ui.mode == "none" and event.is_action_pressed("intro_use") and not event.is_echo():
		_use(_find_action())
	elif ui.mode == "none" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			player.capture_mouse()
		elif _stage == "stand" and workshop.carried:
			_release_object(false)
		else:
			var action := _find_action()
			if action == "cube":
				_use(action)
	elif ui.mode == "none" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F8 and _stage == "stand":
			_capture_case()
		elif event.physical_keycode == KEY_R and _stage == "stand" and not workshop.peer_running:
			workshop.reset_environment()

func _use(action: String) -> void:
	if action.is_empty():
		return
	if _stage == "stand" and workshop.peer_running and action != "case_notes":
		ui.say("Артём выполняет свою проверку. Можно смотреть, сделать снимок или открыть записи; действия на стенде пока заняты.")
		return
	_audio.play_event("ui_click")
	match action:
		"computer": _computer()
		"archive": _computer(1)
		"nika": _talk(["nika_day1_03"] if GameRun.day == 1 else ["nika_day2_01"])
		"coffee": ui.say("Кофе ещё тёплый. За перегородкой обсуждают завтрашний выпуск.")
		"exit":
			if GameRun.shift_released:
				if GameRun.day == 3:
					_finish_outro()
				else:
					_begin_commute()
			else:
				_end_shift()
		"service":
			if GameRun.day < 3:
				ui.say("Служебный сектор. Производственный допуск выдадут после двух смен.")
			else:
				_travel("service", Vector3(0, 0.03, 5.4), 0)
		"lab_gate": ui.say("Местный привод эксплуатации. На рабочем этаже проход открыт.")
		"home_pc": _home_computer()
		"bed": _sleep()
		"home_exit":
			if GameRun.home_evening:
				ui.say("На сегодня всё. Можно просмотреть записи и лечь спать.")
			else:
				GameRun.go_to_work()
				_travel("lab", Vector3(2.6, 0.03, 4.5), 0, _brief_day)
		"home_coffee": ui.say("Тихо. Ключи на полке, будильник на восемь.")
		"cube": workshop.pickup()
		"mode": workshop.change_mode()
		"light": workshop.change_light()
		"reset": workshop.reset_environment()
		"reconnect": workshop.reconnect()
		"place_cube": _release_object(true)
		"finish_case": _finish_case()
		"case_notes": _case_notes()
		"mark": workshop.stamp()
		"impact": workshop.impact()
		"replay": workshop.replay_command()
		"inspect": workshop.inspect_back(player.global_position)
		"escape": _travel("lab", Vector3(7.5, 0.03, 9.6), PI)
		"sector_window": ui.say("Местное управление в сервисном режиме. Это оборудование здания, а не игровой стенд. Рабочую приёмку выполняют в лаборатории.")
		"cafe_sit":
			_cafe_seated = true
			player.seated = true
			_scene_seconds = 0
			player.place(_root_for("evening").to_global(_interludes.evening.seat), 0.28)
			ui.say("Можно немного посидеть. Автобус пока здесь." if GameRun.day < 2 else "Вчера здесь было светлее.")
		"cafe_leave":
			GameRun.cafe_visited = true
			_cafe_seated = false
			player.seated = false
			player.place(_root_for("evening").to_global(Vector3(4.7, 0.03, -8.7)), 0)
		"bus_board":
			if GameRun.day == 0 and not GameRun.cafe_visited:
				ui.say("До отправления есть время. Присяду в кафе.")
			else:
				_travel("bus", Vector3(0.85, -0.35, 1.75), PI / 2)
		"bus_exit": _go_home()

func _release_object(place: bool) -> void:
	var body: RigidBody3D = workshop.cube
	if place:
		_use_ray.from = player.camera.global_position
		_use_ray.to = _use_ray.from - player.camera.global_basis.z * 3.1
		var hit := get_world_3d().direct_space_state.intersect_ray(_use_ray)
		if not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > 0.6:
			body.global_position = hit.position + Vector3.UP * 0.29
	workshop.release()

func _computer(tab := 0) -> void:
	if not GameRun.report_draft.is_empty():
		_module = GameRun.report_draft.module
		_sample = GameRun.report_draft.sample
		_show_survey()
	else:
		ui.computer(_launch_module, _end_shift, tab)

func _launch_module(id: String) -> void:
	if not GameRun.available(id):
		return
	_module = id
	_sample = {}
	var info := GameRun.module_info(id)
	if info.kind == "internal":
		GameRun.active_case = id
		workshop.begin(int(info.case_day), GameRun.case_sessions.get(id, {}))
		_travel("stand", Vector3(0, 0.03, 4.5), 0, func():
			if not workshop.instruction_seen:
				workshop.instruction_seen = true
				_case_notes()
		)
		return
	var body := ui.page("Открывается стенд", "LATENT / " + str(GameRun.module_info(id).title), "browser")
	body.add_child(ui.label("Стенд открыт внутри игрового окна. Кнопка «В отчёт» в верхней пилюле доступна после 15 активных секунд. Выход без отчёта не засчитывает наблюдение.", 22))
	ui.button(body, "Вернуться без отчёта", func():
		bridge.abort()
		_computer()
	)
	bridge.launch(GameRun.module_info(id))
	_sync_input()

func _store_case() -> void:
	if _stage == "stand" and not _module.is_empty():
		GameRun.case_sessions[_module] = workshop.session()

func _finish_case() -> void:
	workshop.release()
	_store_case()
	_sample = workshop.sample()
	GameRun.active_case = ""
	_travel("lab", Vector3(2.6, 0.03, 2.7), 0, _show_survey)

func _case_notes() -> void:
	var body := ui.page(Workshop.TITLES[workshop.case_day - 1], "ЛОКАЛЬНЫЙ СТЕНД / " + workshop.version(), "case_notes")
	body.add_child(ui.label(workshop.task(), 20))
	body.add_child(ui.label("E — действие; ЛКМ — поднять или уронить; R — обычный сброс; F8 — снимок. Режим, свет и переподключение — на пультах. Можно завершить с недостатком данных: таймер не является проверкой.", 17, Interface.MUTED))
	if workshop.case_day == 2:
		var peer_button := ui.button(body, "Пригласить Артёма на отдельную проверку", func():
			ui.close_page()
			workshop.start_peer()
		, true)
		peer_button.disabled = workshop.peer_running
	if workshop.case_day == 3:
		body.add_child(ui.label("Собственные записи первого дня", 22, Interface.ACCENT))
		for report in GameRun.reports:
			if report.module == "object_state":
				body.add_child(ui.label("Условие: %s\nРезультат: %s\nПовтор: %s" % [report.checked, report.observation, report.sample.get("repeat", "Не проверено")], 18))
				ui.event_list(body, report.sample.get("events", []))
				ui.snapshot_list(body, report.sample.get("snapshots", []))
	body.add_child(ui.label("Журнал действий / не готовый диагноз", 22, Interface.ACCENT))
	ui.event_list(body, workshop.journal)
	ui.snapshot_list(body, workshop.snapshots)
	ui.button(body, "Вернуться к стенду", ui.close_page, true)

func _capture_case() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		ui.say("Этот видеорежим не выдал кадр. Наблюдение можно записать без снимка.")
		return
	if image.get_width() > 640:
		image.resize(640, int(640.0 * image.get_height() / image.get_width()), Image.INTERPOLATE_BILINEAR)
	workshop.add_snapshot("data:image/jpeg;base64," + Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.75)))

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
	if GameRun.day == 3 and _module == GameRun.case_id():
		_close_program()
	elif recommendation == 2:
		_talk(["nika_peer_01"], _computer)
	elif recommendation in [1, 3] and GameRun.day >= 2:
		_talk(["elena_review_01"], _computer)
	else:
		_computer()

func _end_shift() -> void:
	if not GameRun.quota_ready():
		ui.close_page()
		ui.say("Осталась обязательная выборка: " + GameRun.quota_text())
		return
	if GameRun.shift_released:
		ui.close_page()
		ui.say("Работа закончена. Выход к лифту позади рабочих мест.")
	elif GameRun.day == 1:
		_talk(["nika_hired_01", "hero_hired_01"], _release_shift)
	elif GameRun.day == 2:
		_talk(["artem_shift_end"], _release_shift)
	else:
		_close_program()

func _close_program() -> void:
	if not GameRun.quota_ready():
		return
	GameRun.finish_shift()
	var body := ui.page("Практическая программа завершена", "LATENT SYSTEMS / ТРЕТИЙ ДЕНЬ", "program")
	body.add_child(ui.label("Спасибо за участие. Результаты наблюдений переданы на обработку.\nО дальнейших условиях работы мы сообщим отдельно.", 23))
	body.add_child(ui.label("Рабочий доступ закрыт. Закрой планшет и выйди к лифту.", 18, Interface.MUTED))
	ui.button(body, "Закрыть планшет и уйти", ui.close_page, true)

func _finish_outro() -> void:
	_busy = true
	_talk(["hero_demo_end"], func():
		var fade_out := create_tween()
		fade_out.tween_property(ui.fade, "color:a", 1.0, 0.9)
		fade_out.finished.connect(_show_ending, CONNECT_ONE_SHOT)
	)

func _release_shift() -> void:
	GameRun.finish_shift()
	ui.close_page()
	_update_hud()

func _begin_commute() -> void:
	GameRun.home_evening = true
	_travel("evening", Vector3(8, 0.03, 22), 0)

func _go_home() -> void:
	GameRun.go_home()
	var line := "hero_home0_01" if GameRun.day == 0 else "hero_home1_01" if GameRun.day == 1 else "hero_home2_01"
	_travel("home", Vector3(-1.5, 0.03, 4.7), 0, func(): _talk([line]))

func _home_computer() -> void:
	var body := ui.page("Личный стол", "КВАРТИРА / НЕ КОРПОРАТИВНЫЙ СТЕНД", "home")
	var note := "Завтра, 09:00. Ника встретит на испытательном этаже. Пока только практическая часть, не первый самостоятельный день." if GameRun.day == 0 else "Практическая часть принята. Завтра — проверка памяти среды." if GameRun.day == 1 else "Завтра исправленная версия. Проверю её по собственным записям."
	body.add_child(ui.label(note, 22))
	body.add_child(ui.label("Будильник: 08:00 · пропуск и ключи у двери", 19))
	ui.report_list(body)
	if GameRun.day >= 2:
		var send := ui.button(body, "Отправить Нике копию записей" if not GameRun.shared_notes else "Ника получила отдельную копию", func():
			GameRun.share_notes()
			_talk(["hero_share_01"], _home_computer)
		, true)
		send.disabled = GameRun.shared_notes
		body.add_child(ui.label("Коллега получит отдельную копию. Твои записи и решение о приёмке остаются разными документами.", 17, Interface.MUTED))
	ui.button(body, "Отойти от стола", ui.close_page)

func _sleep() -> void:
	if not GameRun.home_evening:
		ui.say("Будильник уже прозвенел. Ключи у двери; пора на работу.")
		return
	_busy = true
	ui.close_page()
	_sync_input()
	var tween := create_tween()
	tween.tween_property(ui.fade, "color:a", 1.0, 0.6)
	await tween.finished
	if GameRun.day == 1 and not GameRun.dream_seen:
		_set_stage("dream", Vector3(0, 0.03, 3), 0)
		var dream_reveal := create_tween()
		dream_reveal.tween_property(ui.fade, "color:a", 0.0, 1.2)
		await dream_reveal.finished
		_busy = false
		_sync_input()
		return
	GameRun.sleep()
	Rooms.dress_shift(home_info, GameRun.day, GameRun.interview_answers, true, false)
	player.place(home.to_global(Vector3(1.0, 0.03, 2.5)), 0)
	_light_stage()
	await get_tree().create_timer(2.0).timeout
	var reveal := create_tween()
	reveal.tween_property(ui.fade, "color:a", 0.0, 0.7)
	await reveal.finished
	_busy = false
	_talk(["hero_morning1_01"] if GameRun.day == 1 else ["hero_morning2_01"] if GameRun.day == 2 else ["hero_morning3_01"])

func _wake_from_dream() -> void:
	_busy = true
	_sync_input()
	GameRun.dream_seen = true
	GameRun.location = "home"
	GameRun.sleep()
	_set_stage("home", Vector3(1.0, 0.03, 2.5), 0)
	_audio.play_event("lift_ding")
	var reveal := create_tween()
	reveal.tween_property(ui.fade, "color:a", 0.0, 1.4)
	await reveal.finished
	ui.fade.color = Color(0, 0, 0, 0)
	_busy = false
	_talk(["hero_dream_wake", "hero_morning2_01"])

func _travel(stage: String, p: Vector3, yaw: float, done: Callable = Callable()) -> void:
	_busy = true
	ui.close_page()
	_sync_input()
	_play_transition_event("lift_doors" if stage in ["lab", "evening", "service"] else "entrance_door")
	ui.fade.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	tween.tween_property(ui.fade, "color:a", 1.0, 0.55)
	await tween.finished
	var caption := ""
	if _stage == "bus" and stage == "home":
		caption = "Остановка «Парковая»\nНесколько минут пешком до квартиры"
	elif stage == "stand":
		caption = "Локальная контрольная среда\n" + str(GameRun.module_info(_module).title) + " · версия " + workshop.version()
	elif _stage == "stand":
		caption = "Испытательный стенд отключён\nВыборка сохранена · возвращение к рабочему столу"
	elif stage == "lab" and _stage == "home":
		caption = "Утренний автобус №18\nИспытательный корпус · рабочий этаж"
	elif stage == "evening":
		caption = "Лифт · первый этаж\nВыход из испытательного корпуса"
	elif stage == "bus":
		caption = "Маршрут №18\nСледующая остановка: «Парковая»"
	else:
		caption = "Лифт · служебный этаж" if stage == "service" else "Возвращение на испытательный этаж"
	_set_stage(stage, p, yaw)
	ui.transition_card(caption)
	ui.fade.color.a = 0
	await get_tree().create_timer(2.0).timeout
	ui.fade.color.a = 1
	ui.clear_transition()
	if stage == "home":
		_play_transition_event("office_door_close")
	var reveal := create_tween()
	reveal.tween_property(ui.fade, "color:a", 0.0, 0.6)
	await reveal.finished
	_busy = false
	_sync_input()
	if done.is_valid():
		done.call()

func _show_ending() -> void:
	if not GameRun.complete():
		return
	_busy = false
	ui.fade.z_index = -1
	ui.fade.color = Color.BLACK
	var body := ui.page("КОНЕЦ ДЕМОВЕРСИИ", "LATENTPUNK: TEST SUBJECT 0", "ending")
	body.add_child(ui.label("Три рабочих дня завершены. Наблюдения сохранены.", 23))
	ui.button(body, "Титры", _credits, true)
	ui.button(body, "Начать заново", _new_game)
	ui.button(body, "Главное меню", _menu)

func _credits() -> void:
	var body := ui.page("Титры", "LATENTPUNK: TEST SUBJECT 0 / МЫ ТЕСТИРУЕМ РЕАЛЬНОСТЬ")
	body.add_child(ui.label("Главный участник — концепция, режиссура, решения о механиках, озвучивание главного героя.\nAI-ассистенты — программирование, постановка и подготовка ресурсов под руководством участника.\nМузыка: Shift Change — собственная композиция проекта, без чужих семплов.\nДвижок: Godot 4.7.2 Standard.\nШрифт интерфейса: OpenRunde.\nЗвуки и существующие голоса: происхождение, авторство и условия в assets/SOURCES.md и включённых notices.", 21))
	body.add_child(ui.label("Собственные проверки: сохранность предмета, память среды, приёмка исправления.\nДополнительные среды: DUSTFALL и DEAD PARADE — проекты участника; выбранные игры bench-portal — с разрешения владельцев. Исходные manifests, авторство и лицензии сохранены рядом со сборками.\nМодели и версии каждой внешней среды указаны в её game.json. Готовые игры не названы собственными исходниками и не переписаны ради переходов.", 19, Interface.MUTED))
	body.add_child(ui.label("Музыка меню: Epilogue — Creo · https://creo-music.com/track/epilogue · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/).\nМузыка сна: Ossuary 6 - Air — Kevin MacLeod (incompetech.com) · https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1500048 · CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).\nИспуг Ники: Horror Sting (Deep in the Void)2 — SilverIllusionist · https://freesound.org/people/SilverIllusionist/sounds/655386/ · CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).\nМузыкальные MP3 целиком перекодированы в Ogg. Звуковой preview испуга обрезан до 3,2 с, отфильтрован, ослаблен и плавно затушен.", 17, Interface.MUTED))
	ui.button(body, "К финалу", _show_ending, true)
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
	if _stage == "stand":
		ui.button(body, "Вернуться к компьютеру без отчёта", func():
			_paused = false
			workshop.release()
			_store_case()
			GameRun.active_case = ""
			_travel("lab", Vector3(2.6, 0.03, 2.7), 0, _computer)
		)
	ui.button(body, "Главное меню", _menu)
	_sync_input()

func _resume() -> void:
	_paused = false
	ui.restore_page()
	_sync_input()

func _menu() -> void:
	if _stage == "stand":
		workshop.release()
		_store_case()
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
