extends Node3D
## Scene boundary: the interview itself is intentionally a separate deliverable.
signal interview_requested
const City = preload("res://scripts/intro/city.gd")
const Interiors = preload("res://scripts/intro/interiors.gd")
const Pedestrians = preload("res://scripts/intro/pedestrians.gd")
const Ambience = preload("res://scripts/intro/ambience.gd")
const Player = preload("res://scripts/intro/player.gd")
const Geometry = preload("res://scripts/intro/geometry.gd")
const TapeShader = preload("res://assets/shaders/intro_tape.gdshader")
const FLOOR_COUNT := 22
const RECEPTION_LINES := [
	{"speaker":"Вы","text":"Здравствуйте. Я на собеседование."},
	{"speaker":"Администратор","text":"Доброе утро. Поднимитесь на четырнадцатый этаж. Кабинет 1406, направо по коридору."}
]
@export var reception_voice: AudioStream
var city: Node3D
var lobby: Node3D
var office: Node3D
var player: CharacterBody3D
var audio: Node
var location := "street"
var door_open := false
var _transitioning := false
var _paused := false
var _current_action := ""
var _environment: Environment
var _objective: Label
var _prompt: Label
var _help: Label
var _pause_panel: PanelContainer
var _floor_panel: PanelContainer
var _fade: ColorRect
var _hint_time := 16.0
var _lift_panels: Array[Node3D] = []
var _lift_open := false
var reception_done := false
var _dialogue_index := -1
var _dialogue_panel: PanelContainer
var _subtitle_panel: PanelContainer
var _subtitle_label: Label
var _subtitle_remaining := 0.0
var _voice_player: AudioStreamPlayer
var _interaction_points: Dictionary = {}

func _ready() -> void:
	_build_environment()
	city = City.new()
	city.name = "City"
	add_child(city)
	city.build()
	lobby = Interiors.new()
	lobby.name = "Lobby"
	lobby.position = Vector3(0,0,400)
	add_child(lobby)
	lobby.build_lobby()
	_build_lift_doors()
	office = Interiors.new()
	office.name = "Floor14"
	office.position = Vector3(100,50,400)
	add_child(office)
	office.build_office()
	_interaction_points = {
		"street": {},
		"lobby": {
			"reception": lobby.to_global(lobby.anchors["reception"]),
			"lift": lobby.to_global(lobby.anchors["lift"]),
			"floor14": lobby.to_global(lobby.anchors["floor14"]),
		},
		"office": {
			"door": office.to_global(office.anchors["office_door"]),
			"computer": office.to_global(office.anchors["computer"]),
			"return": office.to_global(office.anchors["lift_return"]),
		},
	}
	_add_people(city, 64)
	_add_people(lobby, 18)
	_add_people(office, 6)
	var receptionist := Pedestrians.new()
	receptionist.name = "Receptionist"
	lobby.add_child(receptionist)
	receptionist.populate_stationary(Vector3(-8,0,-6.4),PI,17)
	player = Player.new()
	add_child(player)
	audio = Ambience.new()
	add_child(audio)
	_voice_player = AudioStreamPlayer.new()
	add_child(_voice_player)
	audio.set_muted(not GameSettings.sound_enabled)
	audio.attach_city(city)
	player.stepped.connect(audio.footstep)
	_build_ui()
	_set_location("street", Vector3(14,0.03,110), 0)
	player.capture_mouse()

func _build_lift_doors() -> void:
	for side in [-1.0, 1.0]:
		var panel := Geometry.new()
		lobby.add_child(panel)
		panel.position = Vector3(side * 0.55, 0, -11.94)
		panel.box(Vector3(0,1.55,0), Vector3(1.08,3.1,0.12), "concrete")
		panel.box(Vector3(0,1.55,0.075), Vector3(0.88,2.85,0.025), "teal")
		panel.box(Vector3(-side*0.42,1.55,0.09), Vector3(0.025,3,0.025), "petrol")
		panel.solid(Vector3(0,1.55,0), Vector3(1.08,3.1,0.12))
		panel.flush()
		_lift_panels.append(panel)

func _call_lift() -> void:
	if _lift_open:
		return
	_transitioning = true
	audio.play_event("lift_ding")
	audio.play_event("lift_doors")
	var tween := create_tween().set_parallel()
	for i in _lift_panels.size():
		tween.tween_property(_lift_panels[i], "position:x", -1.65 if i == 0 else 1.65, 0.7)
	await tween.finished
	_lift_open = true
	_objective.text = "Лифт открыт  ·  Войдите внутрь и выберите этаж"
	_transitioning = false

func _add_people(root: Node3D, count_value: int) -> void:
	var people := Pedestrians.new()
	root.add_child(people)
	people.populate(root.pedestrian_routes, count_value, 72 + count_value)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("83b9d2")
	sky_mat.sky_horizon_color = Color("d4dedf")
	sky_mat.ground_bottom_color = Color("829398")
	sky_mat.ground_horizon_color = Color("d4dedf")
	sky.sky_material = sky_mat
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("d6e2ec")
	_environment.ambient_light_energy = 0.30
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("c3d1cc")
	_environment.fog_density = 0.0017
	world.environment = _environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-34,0)
	sun.light_color = Color("fff0db")
	sun.name = "MorningSun"
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 240.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)

func _build_ui() -> void:
	var tape_layer := CanvasLayer.new()
	tape_layer.layer = 0
	add_child(tape_layer)
	var tape := ColorRect.new()
	tape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tape_material := ShaderMaterial.new()
	tape_material.shader = TapeShader
	tape.material = tape_material
	tape_layer.add_child(tape)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	_objective = _label(ui, Vector2(28,24), 21)
	_objective.anchor_right = 1.0
	_objective.offset_right = -28
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_theme_color_override("font_color", Color("eee9d7"))
	_help = _label(ui, Vector2(28,94), 16)
	_help.anchor_right = 1.0
	_help.offset_right = -28
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.text = "WASD — идти  ·  мышь — обзор  ·  E — взаимодействие  ·  Esc — пауза"
	var crosshair := Label.new()
	crosshair.text = "·"
	crosshair.add_theme_font_size_override("font_size", 30)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-4,-20)
	ui.add_child(crosshair)
	_prompt = Label.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_left = 28
	_prompt.offset_right = -28
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.offset_top = -94
	_prompt.offset_bottom = -40
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 21)
	ui.add_child(_prompt)
	_pause_panel = _panel(ui, "Пауза", ["Продолжить", "Начать заново", "В меню"], [_resume, _restart, _menu])
	_add_settings(_pause_panel.get_node("Body"))
	_pause_panel.offset_top = -210
	_pause_panel.offset_bottom = 210
	_floor_panel = _build_floor_panel(ui)
	_dialogue_panel = _panel(ui,"Ресепшен · LATENT SYSTEMS",["Продолжить · E"],[_advance_dialogue])
	_dialogue_panel.offset_top = -60
	_dialogue_panel.offset_bottom = 60
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_panel.anchor_left = 0.12
	_subtitle_panel.anchor_right = 0.88
	_subtitle_panel.offset_top = -110
	_subtitle_panel.offset_bottom = -34
	var subtitle_style := StyleBoxFlat.new()
	subtitle_style.bg_color = Color(0.1,0.19,0.2,0.92)
	subtitle_style.content_margin_left = 20
	subtitle_style.content_margin_right = 20
	subtitle_style.content_margin_top = 10
	subtitle_style.content_margin_bottom = 10
	_subtitle_panel.add_theme_stylebox_override("panel",subtitle_style)
	ui.add_child(_subtitle_panel)
	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size",20)
	_subtitle_panel.add_child(_subtitle_label)
	_subtitle_panel.hide()
	_fade = ColorRect.new()
	_fade.color = Color(0.12,0.19,0.19,0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)

func _label(parent: Control, p: Vector2, size_value: int) -> Label:
	var label := Label.new()
	label.position = p
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_shadow_color", Color(0.12,0.2,0.2,0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _panel(parent: Control, title: String, texts: Array, callbacks: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -140
	panel.offset_bottom = 140
	var style := StyleBoxFlat.new()
	style.bg_color = Color("304e4f")
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Body"
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",24)
	column.add_child(heading)
	for i in texts.size():
		var button := Button.new()
		button.text = texts[i]
		button.custom_minimum_size.y = 46
		button.pressed.connect(callbacks[i])
		column.add_child(button)
	panel.hide()
	return panel

func _add_settings(column: VBoxContainer) -> void:
	var divider := HSeparator.new()
	column.add_child(divider)
	var sound := CheckButton.new()
	sound.name = "Sound"
	sound.text = "Звук"
	sound.button_pressed = GameSettings.sound_enabled
	sound.toggled.connect(_on_sound_toggled)
	column.add_child(sound)
	var subtitles := CheckButton.new()
	subtitles.name = "Subtitles"
	subtitles.text = "Субтитры"
	subtitles.button_pressed = GameSettings.subtitles_enabled
	subtitles.toggled.connect(_on_subtitles_toggled)
	column.add_child(subtitles)

func _build_floor_panel(ui: Control) -> PanelContainer:
	var panel := _panel(ui,"LATENT SYSTEMS · лифт",[],[])
	panel.name = "FloorSelector"
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -255
	panel.offset_bottom = 230
	var body: VBoxContainer = panel.get_node("Body")
	var destination := Label.new()
	destination.text = "Собеседования · этаж 14"
	destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	destination.add_theme_color_override("font_color",Color("efd485"))
	body.add_child(destination)
	var grid := GridContainer.new()
	grid.name = "Floors"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	body.add_child(grid)
	for floor_number in range(FLOOR_COUNT,0,-1):
		var button := Button.new()
		button.name = "Floor%d" % floor_number
		button.text = str(floor_number) + (" · HR" if floor_number == 14 else "")
		button.custom_minimum_size = Vector2(96,44)
		if floor_number == 14:
			button.add_theme_color_override("font_color",Color("efd485"))
		button.pressed.connect(_choose_floor.bind(floor_number))
		grid.add_child(button)
	var close := Button.new()
	close.text = "Закрыть"
	close.custom_minimum_size.y = 42
	close.pressed.connect(_close_floor)
	body.add_child(close)
	return panel

func _on_sound_toggled(value: bool) -> void:
	GameSettings.set_sound_enabled(value)
	audio.set_muted(not value)
	_voice_player.stream_paused = not value

func _on_subtitles_toggled(value: bool) -> void:
	GameSettings.set_subtitles_enabled(value)
	_subtitle_panel.visible = value and _subtitle_remaining > 0

func _say(speaker: String, text: String, seconds: float = 4.0) -> void:
	_subtitle_label.text = speaker + ": " + text
	_subtitle_remaining = seconds
	_subtitle_panel.visible = GameSettings.subtitles_enabled

func _start_dialogue() -> void:
	_dialogue_index = 1 if reception_done else 0
	player.enabled = false
	_dialogue_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	var line: Dictionary = RECEPTION_LINES[_dialogue_index]
	_say(line["speaker"],line["text"],3600)
	if _dialogue_index == 1 and reception_voice != null and GameSettings.sound_enabled:
		_voice_player.stream = reception_voice
		_voice_player.play()

func _advance_dialogue() -> void:
	if _dialogue_index < 0:
		return
	_voice_player.stop()
	_dialogue_index += 1
	if _dialogue_index < RECEPTION_LINES.size():
		_show_dialogue_line()
		return
	_dialogue_index = -1
	reception_done = true
	_dialogue_panel.hide()
	_subtitle_remaining = 0
	_subtitle_panel.hide()
	_objective.text = "Собеседование · 14-й этаж, кабинет 1406\nПодойдите к лифту"
	player.enabled = true
	player.capture_mouse()

func _cancel_dialogue() -> void:
	_dialogue_index = -1
	_voice_player.stop()
	_dialogue_panel.hide()
	_subtitle_remaining = 0
	_subtitle_panel.hide()
	player.enabled = true
	player.capture_mouse()

func _choose_floor(floor_number: int) -> void:
	if not reception_done or not _floor_panel.visible or _transitioning:
		return
	audio.play_event("ui_click" if floor_number == 14 else "ui_wrong")
	if floor_number != 14:
		_say("Вы","Не, вроде как не сюда",3.5)
		return
	_select_floor()

func _process(delta: float) -> void:
	if _subtitle_remaining > 0 and not _paused:
		_subtitle_remaining = maxf(0,_subtitle_remaining-delta)
		_subtitle_panel.visible = GameSettings.subtitles_enabled and _subtitle_remaining > 0
	_hint_time -= delta
	_help.visible = _hint_time > 0 or _paused
	if _transitioning or _paused or _floor_panel.visible or _dialogue_panel.visible:
		_prompt.text = ""
		return
	_current_action = _find_action()
	var captions := {"reception":"Поговорить с администратором", "lift":"Вызвать лифт" if reception_done else "Сначала обратитесь к администратору", "floor14":"Выбрать этаж", "return":"Вернуться в холл", "door":"Открыть кабинет 1406" if not door_open else "Закрыть кабинет 1406", "computer":"Начать собеседование"}
	_prompt.text = "E  ·  " + captions[_current_action] if captions.has(_current_action) else ""
	_prompt.visible = _subtitle_remaining <= 0
	_check_doorways()
	if location == "street":
		if player.position.z > -58:
			_objective.text = "LATENT SYSTEMS  ·  Центральный проспект, 18\nПройдите до перекрёстка и поверните направо"
		else:
			_objective.text = "LATENT SYSTEMS  ·  Вход через площадь →"

## Walking through the tower portal or the lobby doors changes location; no key press.
func _check_doorways() -> void:
	if location == "street":
		var p := player.global_position
		if p.x > 172.6 and p.x < 176.0 and p.z > -81.4 and p.z < -78.6:
			audio.play_event("entrance_door")
			_travel("lobby", lobby.to_global(Vector3(0,0.03,11)), 0)
	elif location == "lobby":
		var local := lobby.to_local(player.global_position)
		if local.z > 13.6 and absf(local.x) < 2.2:
			audio.play_event("entrance_door")
			_travel("street", Vector3(169.5,0.03,-80), PI/2)

func _find_action() -> String:
	var anchors: Dictionary = _interaction_points[location]
	var best := 3.1
	var action := ""
	for key in anchors:
		if key == "lift" and _lift_open:
			continue
		if key == "floor14" and (not reception_done or not _lift_open or not _inside_lift()):
			continue
		var offset: Vector3 = anchors[key] - player.camera.global_position
		var distance := offset.length()
		if distance < best and offset.normalized().dot(-player.camera.global_basis.z) > 0.45:
			if key == "computer" and not door_open:
				continue
			best = distance
			action = key
	return action

func _inside_lift() -> bool:
	var local := lobby.to_local(player.global_position)
	return location == "lobby" and absf(local.x) < 1.65 and local.z < -12.0 and local.z > -17.8

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _transitioning:
		if _floor_panel.visible:
			_close_floor()
		elif _dialogue_panel.visible:
			_cancel_dialogue()
		elif _paused:
			_resume()
		else:
			_paused = true
			_pause_panel.show()
			player.enabled = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("intro_use") and not _paused and not _transitioning and not _floor_panel.visible:
		if _dialogue_panel.visible:
			_advance_dialogue()
		else:
			_perform_action(_find_action())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _paused and not _floor_panel.visible and not _dialogue_panel.visible and not _transitioning:
		player.capture_mouse()

func _perform_action(action: String) -> void:
	if action.is_empty():
		return
	audio.play_event("ui_click")
	match action:
		"reception":
			_start_dialogue()
		"lift":
			if reception_done:
				_call_lift()
			else:
				_say("Вы","Сначала нужно обратиться к администратору.")
				_objective.text = "Обратитесь к администратору за стойкой слева"
		"floor14":
			if not reception_done or not _lift_open or not _inside_lift():
				return
			_floor_panel.show()
			player.enabled = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"return":
			audio.play_event("lift_doors")
			_travel("lobby", lobby.to_global(Vector3(0,0.03,-10)), PI)
		"door":
			door_open = not door_open
			audio.play_event("office_door_open" if door_open else "office_door_close")
			var tween := create_tween()
			tween.tween_property(office.office_door, "rotation:y", PI/2 if door_open else 0.0, 0.45)
		"computer":
			_transitioning = true
			player.enabled = false
			audio.play_event("computer_start")
			interview_requested.emit()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			await get_tree().create_timer(0.6).timeout
			get_tree().change_scene_to_file("res://scenes/interview_screen.tscn")

func _set_location(value: String, p: Vector3, yaw: float) -> void:
	location = value
	city.visible = value == "street"
	lobby.visible = value == "lobby"
	office.visible = value == "office"
	city.process_mode = Node.PROCESS_MODE_INHERIT if city.visible else Node.PROCESS_MODE_DISABLED
	lobby.process_mode = Node.PROCESS_MODE_INHERIT if lobby.visible else Node.PROCESS_MODE_DISABLED
	office.process_mode = Node.PROCESS_MODE_INHERIT if office.visible else Node.PROCESS_MODE_DISABLED
	_environment.fog_enabled = value == "street"
	_environment.ambient_light_energy = 0.30 if value == "street" else 0.52
	player.place(p, yaw)
	audio.set_location(value)
	var lobby_goal := "Собеседование · 14-й этаж, кабинет 1406" if reception_done else "Обратитесь к администратору за стойкой слева"
	_objective.text = {"street":"LATENT SYSTEMS · Центральный проспект, 18", "lobby":lobby_goal, "office":"14-й этаж · Кабинет 1406"}[value]
	_subtitle_remaining = 0
	_subtitle_panel.hide()

func _travel(value: String, p: Vector3, yaw: float) -> void:
	_transitioning = true
	player.enabled = false
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	await tween.finished
	_set_location(value,p,yaw)
	if value == "office":
		_objective.text = "14-й этаж  ·  Кабинет 1406"
		await get_tree().create_timer(1.0).timeout
	var reveal := create_tween()
	reveal.tween_property(_fade, "color:a", 0.0, 0.35)
	await reveal.finished
	_transitioning = false
	player.enabled = true

func _select_floor() -> void:
	if not reception_done:
		return
	_subtitle_remaining = 0
	_subtitle_panel.hide()
	_floor_panel.hide()
	player.capture_mouse()
	audio.play_event("lift_doors")
	audio.play_event("lift_travel")
	_travel("office",office.to_global(Vector3(0,0.03,8)),0)

func _close_floor() -> void:
	_floor_panel.hide()
	player.enabled = true
	player.capture_mouse()

func _resume() -> void:
	_paused = false
	_pause_panel.hide()
	player.enabled = true
	player.capture_mouse()

func _restart() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

func _menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/start.tscn")
