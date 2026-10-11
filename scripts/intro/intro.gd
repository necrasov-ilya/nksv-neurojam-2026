extends Node3D
## The interview overlays this instance so the office and its state survive.
const InterviewScene := preload("res://scenes/interview.tscn")
const City = preload("res://scripts/intro/city.gd")
const Interiors = preload("res://scripts/intro/interiors.gd")
const Pedestrians = preload("res://scripts/intro/pedestrians.gd")
const Ambience = preload("res://scripts/intro/ambience.gd")
const Player = preload("res://scripts/intro/player.gd")
const Geometry = preload("res://scripts/intro/geometry.gd")
const TapeShader = preload("res://assets/shaders/intro_tape.gdshader")
const StreetExtras = preload("res://scripts/intro/street_extras.gd")
const Voices := preload("res://scripts/core/dialogue_voices.gd")
const CampaignInterface := preload("res://scripts/campaign/ui.gd")
const UIStyle := preload("res://scripts/ui/hud_style.gd")
const PauseUI := preload("res://scripts/ui/pause_drawer.gd")
const FLOOR_COUNT := 22
const RECEPTION_LINES := [
	{"speaker":"Вы","text":"Здравствуйте. Я на собеседование."},
	{"speaker":"Администратор","text":"Доброе утро. Поднимитесь на четырнадцатый этаж. Кабинет 1406, направо по коридору."}
]
var city: Node3D
var lobby: Node3D
var office: Node3D
var player: CharacterBody3D
var audio: Node
var location := "street"
var door_open := false
var _transitioning := false
var _paused := false
var _focus_lost := false
var _current_action := ""
var _environment: Environment
var _objective: Label
var _prompt: Label
var _pause_panel: PauseUI
var _floor_panel: PanelContainer
var _fade: ColorRect
var _lift_panels: Array[Node3D] = []
var _lift_open := false
var reception_done := false
var _dialogue_index := -1
var _subtitle_panel: PanelContainer
var _subtitle_label: Label
var _objective_card: PanelContainer
var _prompt_card: PanelContainer
var _subtitle_remaining := 0.0
var _voice_player: AudioStreamPlayer
var _interaction_points: Dictionary = {}
var street_extras: Node
var _street_use_ray := PhysicsRayQueryParameters3D.new()
var _interview_layer: CanvasLayer
var _interview_completed := false
var _interview_viewport_3d_was_disabled := false
var _staff: Node3D
var _campaign_ui: CanvasLayer

# Set before adding this scene to the tree; direct launches retain normal behavior.
var opening_prepared := false
var _opening_bus := ""
var _opening_audio: Dictionary = {}
var _game_ui: Control
var _city_tape_layer: CanvasLayer

func set_opening_mix(level: float) -> void:
	if not _opening_bus.is_empty():
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(_opening_bus), linear_to_db(maxf(level, 0.0001)))

func set_opening_paused(value: bool) -> void:
	if not opening_prepared:
		return
	city.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	audio.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	for sound: Node in _opening_audio:
		sound.stream_paused = value

func finish_opening() -> void:
	if not opening_prepared:
		return
	set_opening_paused(false)
	opening_prepared = false
	# Live Web samples must retain their bus until these players leave the tree.
	set_opening_mix(1.0)
	_game_ui.show()
	_city_tape_layer.show()
	# Reparenting can interrupt audio playback; restore the existing location
	# without resetting its already-faded bed levels.
	audio.set_muted(not GameSettings.sound_enabled)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.enabled = true
	player.camera.make_current()
	set_process(true)
	set_process_unhandled_input(true)
	player.capture_mouse()

func _prepare_opening() -> void:
	_opening_bus = "OpeningCity_%d" % get_instance_id()
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, _opening_bus)
	AudioServer.set_bus_send(bus_index, "Master")
	AudioServer.set_bus_volume_db(bus_index, -80.0)
	_route_opening_audio(self)
	player.enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_game_ui.hide()
	_city_tape_layer.hide()
	set_process(false)
	set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.set_muted(not GameSettings.sound_enabled)

func _route_opening_audio(root: Node) -> void:
	for child in root.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			_opening_audio[child] = child.bus
			child.bus = _opening_bus
		_route_opening_audio(child)

func _release_opening_bus() -> void:
	if _opening_bus.is_empty():
		return
	for sound: Node in _opening_audio:
		if is_instance_valid(sound):
			sound.stop()
			sound.bus = _opening_audio[sound]
	_opening_audio.clear()
	AudioServer.remove_bus(AudioServer.get_bus_index(_opening_bus))
	_opening_bus = ""

func _exit_tree() -> void:
	if _voice_player != null:
		_voice_player.stop()
	_release_opening_bus()
	if _interview_layer != null:
		get_viewport().disable_3d = _interview_viewport_3d_was_disabled

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
	for action in city.street_anchors:
		_interaction_points["street"][action] = city.to_global(city.street_anchors[action])
	_add_cafe_people(city, 64)
	_add_people(lobby, 18)
	_add_people(office, 6)
	var receptionist := Pedestrians.new()
	receptionist.name = "Receptionist"
	lobby.add_child(receptionist)
	receptionist.populate_stationary(Vector3(-8,0,-6.4),PI,17)
	player = Player.new()
	add_child(player)
	_street_use_ray.exclude = [player.get_rid()]
	audio = Ambience.new()
	add_child(audio)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "DialogueVoice"
	_voice_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_voice_player.volume_db = 0.0 if GameSettings.sound_enabled else -80.0
	add_child(_voice_player)
	audio.set_muted(opening_prepared or not GameSettings.sound_enabled)
	audio.attach_city(city)
	player.stepped.connect(audio.footstep)
	_build_ui()
	street_extras = StreetExtras.new()
	add_child(street_extras)
	street_extras.setup(city)
	street_extras.say_requested.connect(_say)
	street_extras.clear_speech_requested.connect(_clear_street_speech)
	street_extras.sound_requested.connect(audio.play_event)
	_set_location("street", Vector3(14,0.03,110), 0)
	if opening_prepared:
		_prepare_opening()
	else:
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

func _add_cafe_people(root: Node3D, count_value: int) -> void:
	var people := Pedestrians.new()
	root.add_child(people)
	people.populate_cafe(root.pedestrian_routes, count_value, root.cafe_seats, root.cafe_staff_routes, root.cafe_staff_stops, 72 + count_value)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("c9bfff")
	sky_mat.sky_horizon_color = Color("f5f2ff")
	sky_mat.ground_bottom_color = Color("8175c5")
	sky_mat.ground_horizon_color = Color("f5f2ff")
	sky.sky_material = sky_mat
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("aaa1ff")
	_environment.ambient_light_energy = 0.45
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("ece8ff")
	_environment.fog_density = 0.0008
	world.environment = _environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-34,0)
	sun.light_color = Color.WHITE
	sun.name = "MorningSun"
	sun.light_energy = 0.95
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
	_city_tape_layer = tape_layer
	var tape := ColorRect.new()
	tape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tape_material := ShaderMaterial.new()
	tape_material.shader = TapeShader
	tape_material.set_shader_parameter("noise_texture", preload("res://assets/textures/intro/tape_noise.png"))
	tape.material = tape_material
	tape_layer.add_child(tape)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	_game_ui = ui
	ui.theme = UIStyle.theme()
	var objectives := VBoxContainer.new()
	objectives.offset_left = 16
	objectives.offset_top = 16
	objectives.offset_right = 436
	objectives.add_theme_constant_override("separation", 10)
	objectives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(objectives)
	_objective_card = _hud_card(objectives)
	var objective_row := HBoxContainer.new()
	objective_row.add_theme_constant_override("separation", 8)
	objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_card.add_child(objective_row)
	var marker := UIStyle.icon("map-pin", 18)
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	objective_row.add_child(marker)
	_objective = UIStyle.label("", 13)
	_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_row.add_child(_objective)
	_objective_card.hide()
	var crosshair := Panel.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -2
	crosshair.offset_right = 2
	crosshair.offset_top = -2
	crosshair.offset_bottom = 2
	crosshair.add_theme_stylebox_override("panel", UIStyle.flat(UIStyle.ACCENT, 2))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(crosshair)
	var captions := VBoxContainer.new()
	captions.anchor_left = 0.5
	captions.anchor_right = 0.5
	captions.offset_left = -280
	captions.offset_right = 280
	captions.anchor_top = 1.0
	captions.anchor_bottom = 1.0
	captions.offset_top = -20
	captions.offset_bottom = -20
	captions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	captions.add_theme_constant_override("separation", 12)
	captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(captions)
	var fit_captions := func():
		captions.offset_top = -20 - captions.get_combined_minimum_size().y
		captions.offset_bottom = -20
	captions.minimum_size_changed.connect(func(): fit_captions.call_deferred())
	_subtitle_panel = _hud_card(captions)
	_subtitle_label = UIStyle.label("", 14)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_panel.add_child(_subtitle_label)
	_subtitle_panel.hide()
	_prompt_card = _hud_card(captions, UIStyle.ACCENT)
	_prompt_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 8)
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_card.add_child(prompt_row)
	var use_badge := _hud_card(prompt_row)
	use_badge.add_theme_stylebox_override("panel", UIStyle.plate(UIStyle.PAPER, 6, 8))
	var use_key := UIStyle.label("E", 13, UIStyle.ACCENT)
	use_key.autowrap_mode = TextServer.AUTOWRAP_OFF
	use_badge.add_child(use_key)
	prompt_row.add_child(UIStyle.icon("hand", 18, Color.WHITE))
	_prompt = UIStyle.label("", 14, Color.WHITE)
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_row.add_child(_prompt)
	_prompt_card.hide()
	_pause_panel = PauseUI.new()
	ui.add_child(_pause_panel)
	_pause_panel.close_requested.connect(_resume)
	var pause_actions := [
		["Продолжить", _pause_panel.request_close],
		["Настройки", _pause_panel.show_settings],
		["Начать заново", _restart],
		["В меню", _menu],
	]
	for i in pause_actions.size():
		var button := Button.new()
		button.text = pause_actions[i][0]
		UIStyle.apply_button(button, i == 0)
		button.pressed.connect(pause_actions[i][1])
		_pause_panel.body.add_child(button)
	_pause_panel.add_settings(_on_sound_toggled, _on_subtitles_toggled)
	_floor_panel = _build_floor_panel(ui)
	_fade = ColorRect.new()
	_fade.color = Color(0.12,0.19,0.19,0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)

func _hud_card(parent: Control, color: Color = UIStyle.PAPER) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.plate(color, 9, 10))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	return card

func _sync_hud_cards() -> void:
	_objective_card.visible = _objective.visible and not _objective.text.is_empty()
	_prompt_card.visible = _prompt.visible and not _prompt.text.is_empty()

func _panel(parent: Control, title: String, texts: Array, callbacks: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 0
	panel.offset_bottom = 0
	panel.add_theme_stylebox_override("panel", UIStyle.plate(UIStyle.PAPER, 16, 16))
	var fit_width := func():
		var half_width := minf(220.0, (parent.size.x - 32.0) * 0.5)
		panel.offset_left = -half_width
		panel.offset_right = half_width
	parent.resized.connect(fit_width)
	fit_width.call()
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Body"
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := UIStyle.label(title, 22)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	for i in texts.size():
		var button := Button.new()
		button.text = texts[i]
		UIStyle.apply_button(button, i == 0)
		button.custom_minimum_size.y = 40
		button.add_theme_font_size_override("font_size", 16)
		for state in ["normal", "hover", "pressed", "focus"]:
			var color := UIStyle.ACCENT if i == 0 else UIStyle.SURFACE
			button.add_theme_stylebox_override(state, UIStyle.plate(color if state == "normal" else UIStyle.HOVER, 8, 12))
		button.pressed.connect(callbacks[i])
		column.add_child(button)
	panel.hide()
	return panel

func _build_floor_panel(ui: Control) -> PanelContainer:
	var panel := _panel(ui,"LATENT SYSTEMS · лифт",[],[])
	panel.name = "FloorSelector"
	var body: VBoxContainer = panel.get_node("Body")
	var destination := UIStyle.label("Собеседования · этаж 14", 16, UIStyle.ACCENT)
	destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(destination)
	var grid := GridContainer.new()
	grid.name = "Floors"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for floor_number in range(FLOOR_COUNT,0,-1):
		var button := Button.new()
		button.name = "Floor%d" % floor_number
		button.text = str(floor_number) + (" · HR" if floor_number == 14 else "")
		UIStyle.apply_button(button, floor_number == 14)
		button.custom_minimum_size = Vector2(88, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_choose_floor.bind(floor_number))
		grid.add_child(button)
	var close := Button.new()
	close.text = "Закрыть"
	UIStyle.apply_button(close)
	close.custom_minimum_size.y = 40
	close.pressed.connect(_close_floor)
	body.add_child(close)
	return panel

func _on_sound_toggled(value: bool) -> void:
	GameSettings.set_sound_enabled(value)
	audio.set_muted(not value)
	_voice_player.volume_db = 0.0 if value else -80.0

func _on_subtitles_toggled(value: bool) -> void:
	GameSettings.set_subtitles_enabled(value)
	_sync_speech_state()

func _say(speaker: String, text: String, seconds: float = 4.0) -> void:
	_voice_player.stop()
	_voice_player.stream = Voices.line(speaker, text)
	if _voice_player.stream != null:
		_voice_player.play()
		_voice_player.stream_paused = _paused or _focus_lost
		seconds = maxf(seconds, _voice_player.stream.get_length() + 0.15)
	_subtitle_label.text = speaker + ": " + text
	_subtitle_remaining = seconds
	_sync_speech_state()

func _clear_street_speech() -> void:
	# Reception owns its own dialogue; a street cancellation must never erase it.
	if _dialogue_index < 0:
		_voice_player.stop()
		_subtitle_remaining = 0.0
		_subtitle_panel.hide()

func _start_dialogue() -> void:
	street_extras.cancel()
	_dialogue_index = 1 if reception_done else 0
	player.enabled = false
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	var line: Dictionary = RECEPTION_LINES[_dialogue_index]
	var text: String = line["text"]
	var reading_seconds := maxf(2.5, float(text.length()) / 15.0 + 0.5)
	_say(line["speaker"], text, reading_seconds)

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
	_subtitle_remaining = 0
	_subtitle_panel.hide()
	_objective.text = "Собеседование · 14-й этаж, кабинет 1406\nПодойдите к лифту"
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
	if _subtitle_remaining > 0 and not _paused and not _focus_lost and not _transitioning:
		_subtitle_remaining = maxf(0.0, _subtitle_remaining - delta)
		if _subtitle_remaining <= 0.0:
			if _voice_player.playing:
				_subtitle_remaining = 0.15
			elif _dialogue_index >= 0:
				_advance_dialogue()
	_sync_speech_state()
	street_extras.tick(delta, player.global_position, location == "street", _paused or _focus_lost or _transitioning)
	if _transitioning or _paused or _focus_lost or _floor_panel.visible or _dialogue_index >= 0 or is_instance_valid(_campaign_ui):
		_prompt.text = ""
		_sync_hud_cards()
		return
	_current_action = _find_action()
	var captions := {"reception":"Поговорить с администратором", "lift":"Вызвать лифт" if reception_done else "Сначала обратитесь к администратору", "floor14":"Выбрать этаж", "return":"Вернуться в холл", "door":"Открыть кабинет 1406" if not door_open else "Закрыть кабинет 1406", "computer":"Начать собеседование", "staff":"Поговорить с Никой · практическая часть"}
	var caption: String = captions.get(_current_action, StreetExtras.CAPTIONS.get(_current_action, ""))
	_prompt.text = caption
	_prompt.visible = not _subtitle_panel.visible
	_check_doorways()
	if location == "street":
		if player.position.z > -58:
			_objective.text = "LATENT SYSTEMS  ·  Центральный проспект, 18\nПройдите до перекрёстка и поверните направо"
		else:
			_objective.text = "LATENT SYSTEMS  ·  Вход через площадь →"
	_sync_hud_cards()

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
		if key == "computer" and _interview_completed:
			continue
		if key == "lift" and _lift_open:
			continue
		if key == "floor14" and (not reception_done or not _lift_open or not _inside_lift()):
			continue
		var offset: Vector3 = anchors[key] - player.camera.global_position
		var distance := offset.length()
		if distance < best and offset.normalized().dot(-player.camera.global_basis.z) > 0.45:
			if location == "street":
				_street_use_ray.from = player.camera.global_position
				_street_use_ray.to = anchors[key]
				if not player.get_world_3d().direct_space_state.intersect_ray(_street_use_ray).is_empty():
					continue
			best = distance
			action = key
	return action

func _inside_lift() -> bool:
	var local := lobby.to_local(player.global_position)
	return location == "lobby" and absf(local.x) < 1.65 and local.z < -12.0 and local.z > -17.8

func _unhandled_input(event: InputEvent) -> void:
	if _focus_lost:
		return
	if event.is_action_pressed("ui_cancel") and not _transitioning:
		if _floor_panel.visible:
			_close_floor()
		elif _paused:
			_pause_panel.request_close()
		else:
			_paused = true
			_voice_player.stream_paused = true
			city.process_mode = Node.PROCESS_MODE_DISABLED
			_pause_panel.show()
			if is_instance_valid(_campaign_ui):
				_game_ui.show()
			_sync_speech_state()
			player.enabled = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_campaign_ui):
		return
	elif event.is_action_pressed("intro_use") and not event.is_echo() and not _paused and not _transitioning and not _floor_panel.visible and _dialogue_index < 0:
		_perform_action(_find_action())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _paused and not _floor_panel.visible and _dialogue_index < 0 and not _transitioning:
		player.capture_mouse()

func _perform_action(action: String) -> void:
	if action.is_empty():
		return
	if location == "street" and street_extras.activate(action, player.global_position):
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
			_open_interview()
		"staff":
			_meet_staff()

func _open_interview() -> void:
	if _transitioning or _interview_layer != null or _interview_completed:
		return
	_transitioning = true
	street_extras.cancel()
	_voice_player.stop()
	player.enabled = false
	audio.play_event("computer_start")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.6).timeout
	_game_ui.hide()
	_city_tape_layer.hide()
	office.process_mode = Node.PROCESS_MODE_DISABLED
	audio.set_muted(true)
	set_process(false)
	set_process_unhandled_input(false)
	_interview_viewport_3d_was_disabled = get_viewport().disable_3d
	get_viewport().disable_3d = true
	_interview_layer = CanvasLayer.new()
	_interview_layer.name = "InterviewLayer"
	_interview_layer.layer = 20
	var interview := InterviewScene.instantiate()
	interview.finished.connect(_close_interview)
	add_child(_interview_layer)
	_interview_layer.add_child(interview)

func _close_interview() -> void:
	_transitioning = true
	var curtain_layer := CanvasLayer.new()
	curtain_layer.layer = 30
	add_child(curtain_layer)
	var curtain := ColorRect.new()
	curtain_layer.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color(0, 0, 0, 0)
	var darken := create_tween()
	darken.tween_property(curtain, "color:a", 1.0, 0.35)
	await darken.finished
	_interview_layer.queue_free()
	_interview_layer = null
	_interview_completed = true
	await get_tree().create_timer(2.5).timeout
	get_viewport().disable_3d = _interview_viewport_3d_was_disabled
	office.process_mode = Node.PROCESS_MODE_INHERIT
	if not door_open:
		_perform_action("door")
	_staff = Node3D.new()
	_staff.name = "InterviewGuide"
	_staff.position = Vector3(3.4, 0, -12.4)
	office.add_child(_staff)
	var person := Pedestrians.new()
	_staff.add_child(person)
	person.populate_stationary(Vector3.ZERO, 0, 2)
	person.walk_to(Vector3(0, 0, -2.9), 1.25)
	_interaction_points["office"]["staff"] = office.to_global(Vector3(3.4, 1.35, -15.3))
	audio.set_muted(not GameSettings.sound_enabled)
	_game_ui.show()
	_city_tape_layer.show()
	_objective.text = "За вами пришла Ника. Подойдите к двери кабинета и поговорите с ней.\nE — перейти к практической части"
	var reveal := create_tween()
	reveal.tween_property(curtain, "color:a", 0.0, 0.45)
	await reveal.finished
	curtain_layer.queue_free()
	_transitioning = false
	player.enabled = true
	set_process(true)
	set_process_unhandled_input(true)
	# Pointer lock follows a fresh user gesture, never an awaited callback.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _meet_staff() -> void:
	if not _interview_completed or _transitioning:
		return
	_transitioning = true
	player.enabled = false
	_game_ui.hide()
	_campaign_ui = CampaignInterface.new()
	add_child(_campaign_ui)
	_campaign_ui.dialogue(["nika_arrival_01", "hero_arrival_01", "nika_arrival_02"], func():
		GameRun.campaign_started = true
		get_viewport().disable_3d = false
		get_tree().change_scene_to_file("res://scenes/campaign.tscn")
	)

func _set_location(value: String, p: Vector3, yaw: float) -> void:
	_voice_player.stop()
	location = value
	street_extras.cancel()
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
	street_extras.cancel()
	_voice_player.stop()
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
	_voice_player.stream_paused = _focus_lost
	city.process_mode = Node.PROCESS_MODE_INHERIT if location == "street" else Node.PROCESS_MODE_DISABLED
	_pause_panel.hide()
	_sync_speech_state()
	if is_instance_valid(_campaign_ui):
		_game_ui.hide()
	player.enabled = not _focus_lost and not _transitioning and _dialogue_index < 0 and not _floor_panel.visible and not is_instance_valid(_campaign_ui)
	if not _focus_lost:
		player.capture_mouse()

func _restart() -> void:
	_voice_player.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

func _menu() -> void:
	_voice_player.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/start.tscn")

func _notification(what: int) -> void:
	if opening_prepared or _interview_layer != null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_lost = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_lost = false
	else:
		return
	_sync_speech_state()
	if player != null and _floor_panel != null:
		player.enabled = not _focus_lost and not _paused and not _transitioning and _dialogue_index < 0 and not _floor_panel.visible and not is_instance_valid(_campaign_ui)

func _sync_speech_state() -> void:
	var focused := not _paused and not _focus_lost
	if _voice_player != null:
		_voice_player.stream_paused = not focused
	if _subtitle_panel != null:
		_subtitle_panel.visible = focused and GameSettings.subtitles_enabled and _subtitle_remaining > 0.0
	if is_instance_valid(_campaign_ui):
		_campaign_ui.set_focused(focused)
		_campaign_ui.hud.visible = focused
