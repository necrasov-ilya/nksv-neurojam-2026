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
	workshop.name = "Calibration"
	workshop.position = Vector3(150, 0, 0)
	add_child(workshop)
	_roots = {"lab": lab, "home": home, "service": service, "calibration": workshop}
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
	ui.modal_changed.connect(_sync_input)
	ui.speaker_changed.connect(_face_speaker)
	bridge = Bridge.new()
	add_child(bridge)
	bridge.finished.connect(_world_finished)
	bridge.failed.connect(_world_failed)
	_use_ray.exclude = [player.get_rid()]
	lab_info.nika.visible = GameRun.day != 3
	lab_info.artem.visible = GameRun.day >= 2
	_gate_event = GameRun.gate_event_started
	Rooms.set_gate_open(lab_info.gate, not _gate_event or GameRun.gate_repaired)
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
	elif GameRun.incident_started:
		_set_stage("service", Vector3(0, 0.03, 5), 0)
		_start_emergency()
	else:
		_set_stage("lab", Vector3(2.6, 0.03, 4.5), 0)
		if not GameRun.day_briefed:
			_brief_day.call_deferred()
	if not GameRun.ending.is_empty():
		_show_ending(GameRun.ending)
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
	player.sprint_available = stage not in ["dream", "bus", "calibration"]
	for key in _roots:
		_roots[key].visible = key == stage
	if stage in ["evening", "bus", "dream", "home", "lab"]:
		GameRun.location = stage
	if stage == "lab":
		lab_info.nika.visible = GameRun.day != 3
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
	player.enabled = free and not _manual_hold
	for root in _roots.values():
		root.process_mode = Node.PROCESS_MODE_INHERIT if root == _root_for(_stage) and free else Node.PROCESS_MODE_DISABLED
	workshop.cube.freeze = workshop.carried or not free or _stage != "calibration"
	_weight.freeze = _holding_weight or not free or _stage != "service"
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
		_talk(["elena_day2_01", "nika_day2_01", "hero_day2_01", "elena_day2_02"])
	else:
		_talk(["elena_day3_01", "artem_day3_01", "nika_day3_01"])

func _process(delta: float) -> void:
	if ui == null or _busy or _paused or not _focused or ui.mode != "none" or bridge.active:
		return
	if GameSettings.sound_enabled and _stage == "lab" and not _music.playing:
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
	if _stage == "calibration":
		var result: Dictionary = workshop.actions.duplicate()
		result.cube = workshop.cube.position
		return result
	if _stage == "service":
		var result: Dictionary = service_info.actions.duplicate()
		result.weight = _weight.position
		return result
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
	names.merge({"cafe_sit": "присесть и посмотреть на закат", "cafe_leave": "встать и пройти к автобусу", "bus_board": "сесть в автобус №18", "bus_exit": "выйти на своей остановке"})
	if action == "exit" and GameRun.shift_released:
		return "выйти в город"
	return names.get(action, action)

func _update_hud() -> void:
	if _stage == "evening":
		ui.objective.text = "ДОРОГА ДОМОЙ\n" + ("Посиди немного. Можно осмотреться." if _cafe_seated else "Автобус №18 у кафе · Shift — бег" if GameRun.cafe_visited or GameRun.day > 0 else "Кафе впереди. Присядь перед дорогой.")
	elif _stage == "bus":
		ui.objective.text = "МАРШРУТ 18 / ПАРКОВАЯ" + ("\nТвоя остановка · можно выходить" if _bus_arrived else "\nДорога домой")
	elif _stage == "dream":
		ui.objective.text = ""
	elif _stage == "calibration":
		ui.objective.text = workshop.checklist().strip_edges()
		if _probe_seconds < 15:
			ui.objective.text += "\nНаблюдение: ещё %d с" % ceili(15 - _probe_seconds)
	elif _stage == "home":
		ui.objective.text = ("ВЕЧЕР ПОСЛЕ СОБЕСЕДОВАНИЯ" if GameRun.day == 0 else "КВАРТИРА / ВЕЧЕР" if GameRun.home_evening else "УТРО / ДЕНЬ %d" % GameRun.day)
		ui.objective.text += "\nЛичный стол · затем сон" if GameRun.home_evening else "\nКлючи у двери · выйти на работу"
	elif _stage == "service" and GameRun.incident_started:
		ui.objective.text = "АВАРИЯ / ДО ПРОДУВКИ %02d:%02d" % [int(_timer) / 60, int(_timer) % 60]
		ui.objective.text += "\nДопуск %s · Сеть %s · Привод %s\nЭвакуация %d/2" % ["✓" if _authorized else "○", "✓" if _isolated else "○", "✓" if _gate_open else "○", _evac_count]
	else:
		ui.objective.text = "LATENT / ДЕНЬ %d\n%s" % [GameRun.day, GameRun.quota_text()]
		if _gate_event and not GameRun.gate_repaired:
			ui.objective.text += "\nПроход закрыт · Найди местный привод"
		elif GameRun.shift_released:
			ui.objective.text = "СМЕНА ЗАКОНЧЕНА\nВыйди через дверь к лифту"

func _unhandled_input(event: InputEvent) -> void:
	if not _focused or _busy or bridge.active:
		return
	if ui.mode == "dialogue" and (event.is_action_pressed("intro_use") or event.is_action_pressed("ui_accept")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _paused:
			(ui._page_root as Interface.PauseUI).request_close()
		elif ui.mode in ["computer", "home", "report"]:
			ui.close_page()
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
		"coffee": ui.say("Кофе ещё тёплый. За перегородкой обсуждают завтрашний выпуск.")
		"exit":
			if GameRun.shift_released and GameRun.day < 3:
				_begin_commute()
			else:
				_end_shift()
		"service":
			if GameRun.day < 3:
				ui.say("Служебный сектор. Производственный допуск выдадут после двух смен.")
			else:
				_travel("service", Vector3(0, 0.03, 5.4), 0)
		"lab_gate": _repair_gate()
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
		"material": workshop.change_material()
		"light": workshop.change_light()
		"reset": workshop.reset_cube()
		"place_cube": _release_object(true)
		"finish_calibration": _finish_calibration()
		"permit":
			_authorized = true
			ui.say("Местный допуск получен. Теперь можно изолировать сетевой контроллер слева.")
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
		"sector_window": ui.say("Ника внутри. На экране — ноль. Прогноз не видит человека за стеклом.")
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
	if not GameRun.report_draft.is_empty():
		_module = GameRun.report_draft.module
		_sample = GameRun.report_draft.sample
		_show_survey()
	else:
		ui.computer(_launch_module, _end_shift, tab)

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
	body.add_child(ui.label("Стенд открыт внутри игрового окна. Кнопка «В отчёт» в верхней пилюле доступна после 15 активных секунд. Выход без отчёта не засчитывает наблюдение.", 22))
	ui.button(body, "Вернуться без отчёта", func():
		bridge.abort()
		_computer()
	)
	bridge.launch(GameRun.module_info(id))
	_sync_input()

func _finish_calibration() -> void:
	if not workshop.complete():
		ui.say("Остались действия в списке пробы. Проверь материалы, свет и грузовой привод, затем выполни сброс.")
		return
	if _probe_seconds < 15.0:
		ui.say("Минимальное наблюдение: ещё %d с." % ceili(15 - _probe_seconds))
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
		ui.close_page()
		ui.say("Осталась обязательная выборка: " + GameRun.quota_text())
		return
	if GameRun.shift_released:
		ui.close_page()
		ui.say("Работа закончена. Выход к лифту позади рабочих мест.")
	elif GameRun.day == 1:
		_talk(["nika_hired_01", "hero_hired_01"], _release_shift)
	elif GameRun.day == 2:
		if not GameRun.gate_repaired:
			if not _gate_event:
				_gate_event = true
				GameRun.gate_event_started = true
				GameRun.sign_release()
				Rooms.set_gate_open(lab_info.gate, false)
				var lines: Array = ["artem_gate_01"]
				var personal := GameRun.interview_line("communication")
				if not personal.is_empty():
					lines.append(personal)
				_talk(lines)
			else:
				ui.close_page()
				ui.say("Нужен жёлтый местный привод у стеклянного поста.")
		else:
			_release_shift()
	else:
		_travel("service", Vector3(0, 0.03, 4.9), 0, func(): _talk(["artem_alarm_01", "nika_alarm_01", "hero_alarm_01", "elena_alarm_01", "artem_rescue_01"], _incident_choice))

func _repair_gate() -> void:
	if not _gate_event or GameRun.gate_repaired:
		ui.say("Местный привод. Эксплуатация проверяет его перед каждой сменой.")
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

func _release_shift() -> void:
	GameRun.shift_released = true
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
	var note := "Завтра, 09:00. Ника встретит на испытательном этаже. Пока только практическая часть, не первый самостоятельный день." if GameRun.day == 0 else "Практическая часть принята. Завтра — самостоятельные проверки." if GameRun.day == 1 else "Шлюз открылся только в местном режиме. Сохраню рабочие записи отдельно."
	body.add_child(ui.label(note, 22))
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
	elif stage == "calibration":
		caption = "Локальная контрольная среда\nПодключение к калибровочному стенду"
	elif _stage == "calibration":
		caption = "Калибровочный стенд отключён\nВозвращение к рабочему столу"
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
	for light in service_info.lights:
		light.light_color = Color("ffc49e")
		light.light_energy = 1.1
	service_info.occupancy.text = "ЗАНЯТОСТЬ: 0 / ПРОДУВКА РАЗРЕШЕНА"
	ui.close_page()
	_sync_input()

func _isolate() -> void:
	if not GameRun.incident_started:
		ui.notice("Производственный контроллер", "Режим приёмки. Сетевое управление активно; местный допуск потребуется при ручном вмешательстве.", ui.close_page)
	elif not _authorized:
		ui.notice("Нужен местный допуск", "Инженер оставил допуск на правом столе. Любые прежние ответы позволяют его взять.", ui.close_page)
	elif not _isolated:
		_isolated = true
		service_info.occupancy.text = "СЕТЬ ОТКЛЮЧЕНА / МЕСТНЫЙ РЕЖИМ"
		service_info.occupancy.modulate = Color("38ba91")
		for light in service_info.lights:
			light.light_color = Color("e5e9ff")
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
			_evacuate_actor(service_info[key])
	if _evac_count == 2 and not _evac_prompted:
		_evac_prompted = true
		_talk(["nika_exit_01"], _after_evacuation)
	if _timer <= 0:
		_game_over()

func _evacuate_actor(actor: Node3D) -> void:
	var person: Node3D = actor.get_child(0)
	var local := service.to_local(actor.global_position)
	if local.z < -2:
		person.walk_to(Vector3(-local.x, 0, -3.2 - local.z), 1.6)
		await person.reached_destination
	person.walk_to(Vector3(0.25 - local.x, 0, 8.8 - local.z), 1.6)
	await person.reached_destination
	actor.hide()
	_evac_count += 1

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
	body.add_child(ui.label("Музыка меню: Epilogue — Creo · https://creo-music.com/track/epilogue · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/).\nМузыка сна: Ossuary 6 - Air — Kevin MacLeod (incompetech.com) · https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1500048 · CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).\nИспуг Ники: Horror Sting (Deep in the Void)2 — SilverIllusionist · https://freesound.org/people/SilverIllusionist/sounds/655386/ · CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).\nМузыкальные MP3 целиком перекодированы в Ogg. Звуковой preview испуга обрезан до 3,2 с, отфильтрован, ослаблен и плавно затушен.", 17, Interface.MUTED))
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
