extends Control

signal finished

const Questions := preload("res://scripts/interview/questions.gd")
const Progress := preload("res://scripts/interview/progress.gd")
const CRT := preload("res://assets/shaders/interview_crt.gdshader")
const Assessment := preload("res://scripts/interview/assessment.gd")
const Voices := preload("res://scripts/core/dialogue_voices.gd")
const PIXEL_FONT := preload("res://assets/interview/fonts/Galmuri11-Subset.ttf")
const UI_FONT := preload("res://assets/fonts/OpenRunde-Regular.woff2")
const CARRIAGE := preload("res://assets/audio/interview/carriage_return.wav")
const MUSIC := preload("res://assets/audio/interview/long_note_one.ogg")
const ROOM := preload("res://assets/audio/intro/office_bed.ogg")
const CREAM := Color("e9e5d4")
const ACK_SECONDS := 0.18
const FADE_SECONDS := 0.20
const REVEAL_SECONDS := 0.45
const END_SECONDS := 2.8
const VOICE_TAIL_SECONDS := 0.15

enum Phase { REVEAL, QUESTION, ACKNOWLEDGE, RECORDED, FADE_OUT, ENDING, COMPLETE, ASSESSMENT, ASSESSMENT_RECORDED }

# Ten independent Inspector slots; repeated slots share the same texture resource.
@export var backgrounds: Array[Texture2D] = []
@export var presence_center := Vector2(0.765, 0.31)

# Answers belong to this screen instance; nothing is read from or written to disk.
var progress: RefCounted
var _phase := Phase.REVEAL
var _index := 0
var _phase_clock := 0.0
var _clock := 0.0
var _paused := false
var _focused := true
var _accept_held := false
var _wait_release := false
var _leaving := false
var _music_started := false
var _music_level := 0.0
var _selected_focus := 0
var _background: TextureRect
var _window: PanelContainer
var _scroll: ScrollContainer
var _column: VBoxContainer
var _question: Label
var _answers: Array[Button] = []
var _status: Label
var _error: Label
var _hint: Label
var _material: ShaderMaterial
var _pause_root: Control
var _pause_body: VBoxContainer
var _credits_body: VBoxContainer
var _continue_button: Button
var _credits_back: Button
var _return_button: Button
var _carriage: AudioStreamPlayer
var _music: AudioStreamPlayer
var _room: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _voice_remaining := 0.0
var _voice_hold := 0.0
var _assessment: Control
var _assessment_id := ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	progress = Progress.new()
	_build_ui()
	_build_audio()
	resized.connect(_layout)
	_show_question()
	_layout.call_deferred()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background = TextureRect.new()
	_background.name = "Photograph"
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_full_rect(_background, self)
	_window = PanelContainer.new()
	_window.name = "QuestionWindow"
	_window.add_theme_stylebox_override("panel", _plate(Color(0.035, 0.037, 0.032, 0.88), 22))
	add_child(_window)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_window.add_child(_scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 18)
	_scroll.add_child(_column)
	_question = _label("", 28, PIXEL_FONT)
	_question.name = "Question"
	_column.add_child(_question)
	var choices := VBoxContainer.new()
	choices.name = "Answers"
	choices.add_theme_constant_override("separation", 7)
	_column.add_child(choices)
	for index in 3:
		var button := _button("", _answer.bind(index), PIXEL_FONT)
		button.name = "Answer%d" % index
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choices.add_child(button)
		_answers.append(button)
		button.focus_entered.connect(func(): _selected_focus = index)
	_set_focus_chain(_answers)
	_status = _label("", 28, PIXEL_FONT)
	_status.name = "Acknowledgement"
	_status.hide()
	_column.add_child(_status)
	_error = _label("", 17, UI_FONT)
	_error.add_theme_color_override("font_color", Color("eed2a0"))
	_error.hide()
	_column.add_child(_error)
	_return_button = _button("В главное меню", _return)
	_return_button.hide()
	_column.add_child(_return_button)
	_hint = _label("Tab — выбор · Enter — ответ · Esc — пауза", 13, UI_FONT)
	_hint.add_theme_color_override("font_color", Color(CREAM, 0.65))
	add_child(_hint)
	var filter := ColorRect.new()
	filter.name = "CRT"
	_material = ShaderMaterial.new()
	_material.shader = CRT
	_material.set_shader_parameter("presence_center", presence_center)
	filter.material = _material
	_full_rect(filter, self)
	_build_pause()
	_column.minimum_size_changed.connect(_layout.call_deferred)


func _build_pause() -> void:
	_pause_root = Control.new()
	_pause_root.name = "InterviewPause"
	_full_rect(_pause_root, self)
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.02, 0.018, 0.82)
	_full_rect(veil, _pause_root)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	_full_rect(center, _pause_root)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 340
	panel.add_theme_stylebox_override("panel", _plate(Color("171d1a"), 24))
	center.add_child(panel)
	_pause_body = VBoxContainer.new()
	_pause_body.add_theme_constant_override("separation", 12)
	panel.add_child(_pause_body)
	_pause_body.add_child(_label("Пауза", 28, UI_FONT))
	_continue_button = _button("Продолжить", _resume)
	_pause_body.add_child(_continue_button)
	_pause_body.add_child(_button("Собеседование заново", _restart))
	var sound := CheckButton.new()
	sound.text = "Звук"
	sound.button_pressed = GameSettings.sound_enabled
	sound.add_theme_font_override("font", UI_FONT)
	sound.add_theme_font_size_override("font_size", 20)
	sound.add_theme_color_override("font_color", CREAM)
	sound.toggled.connect(_toggle_sound)
	_pause_body.add_child(sound)
	_pause_body.add_child(_button("Авторство", _show_credits))
	_pause_body.add_child(_button("В главное меню", _menu))
	_credits_body = VBoxContainer.new()
	_credits_body.add_theme_constant_override("separation", 14)
	panel.add_child(_credits_body)
	_credits_body.add_child(_label("Музыка и звук", 25, UI_FONT))
	var credits := RichTextLabel.new()
	credits.bbcode_enabled = true
	credits.fit_content = true
	credits.scroll_active = false
	credits.custom_minimum_size.x = 320
	credits.add_theme_font_override("normal_font", UI_FONT)
	credits.add_theme_font_size_override("normal_font_size", 16)
	credits.add_theme_color_override("default_color", CREAM)
	credits.text = "Long note One — Kevin MacLeod\n[url=https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100418]incompetech.com[/url] · [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url]\nНормализация и конвертация в Ogg.\n\nTypewriter bell & carriage reset — knufds\n[url=https://freesound.org/people/knufds/sounds/345955/]freesound.org[/url] · [url=https://creativecommons.org/publicdomain/zero/1.0/]CC0[/url]\nВыделение каретки, EQ, компрессия и фейды.\n\nОзвучка терминала — [url=https://fish.audio/]Fish Audio[/url] (Fish Speech).\n\nФон предоставлен участником проекта."
	credits.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	_credits_body.add_child(credits)
	_credits_back = _button("Назад", _hide_credits)
	_credits_body.add_child(_credits_back)
	_credits_body.hide()
	_pause_root.hide()


func _build_audio() -> void:
	_carriage = _audio_player("CarriageReturn", CARRIAGE)
	_music = _audio_player("InterviewMusic", MUSIC)
	_room = _audio_player("RoomTone", ROOM)
	_voice = _audio_player("DialogueVoice", null)
	_room.stream.loop = true
	_sync_audio()
	_room.play()


func _audio_player(node_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	return player


func _play_voice(key: String) -> void:
	_stop_voice()
	_voice.stream = Voices.TERMINAL[key]
	_voice_remaining = _voice.stream.get_length()
	# Logical time follows the screen, including mute, pause and accelerated callers.
	_voice_hold = _voice_remaining + VOICE_TAIL_SECONDS
	_voice.play()
	_sync_audio()


func _stop_voice() -> void:
	if _voice != null:
		_voice.stop()
	_voice_remaining = 0.0
	_voice_hold = 0.0


func _process(delta: float) -> void:
	if _paused or not _focused or _leaving:
		return
	_clock += delta
	_phase_clock += delta
	_voice_remaining = maxf(0.0, _voice_remaining - delta)
	_material.set_shader_parameter("clock", _clock)
	_hint.visible = _clock < 7.0 and _phase == Phase.QUESTION and _index == 0
	_update_music(delta)
	match _phase:
		Phase.REVEAL:
			_material.set_shader_parameter("fade", 1.0 - smoothstep(0.0, REVEAL_SECONDS, _phase_clock))
			if _phase_clock >= REVEAL_SECONDS:
				_set_phase(Phase.QUESTION)
				_update_answer_input()
				_answers[0].grab_focus()
		Phase.QUESTION:
			_update_answer_input()
		Phase.ACKNOWLEDGE:
			if _phase_clock >= ACK_SECONDS:
				_question.hide()
				for button in _answers:
					button.hide()
				_status.text = "Ответ записан."
				_status.show()
				_carriage.play()
				_set_phase(Phase.RECORDED)
				_play_voice("answer_recorded")
		Phase.RECORDED:
			var hold := float(Questions.ITEMS[_index].delay) - ACK_SECONDS - FADE_SECONDS - REVEAL_SECONDS
			if _index == Questions.ITEMS.size() - 1:
				hold = float(Questions.ITEMS[_index].delay) - ACK_SECONDS
			hold = maxf(hold, maxf(CARRIAGE.get_length() + 0.10, _voice_hold))
			if _phase_clock >= hold:
				if not progress.pending_assessment().is_empty():
					_show_assessment(progress.pending_assessment())
				elif _index == Questions.ITEMS.size() - 1:
					_begin_ending()
				else:
					_set_phase(Phase.FADE_OUT)
		Phase.ASSESSMENT_RECORDED:
			if _phase_clock >= maxf(CARRIAGE.get_length() + 0.15, _voice_hold):
				_set_phase(Phase.FADE_OUT)
		Phase.FADE_OUT:
			_material.set_shader_parameter("fade", smoothstep(0.0, FADE_SECONDS, _phase_clock))
			if _phase_clock >= FADE_SECONDS:
				_index += 1
				_show_question()
		Phase.ENDING:
			if _phase_clock >= maxf(END_SECONDS, _voice_hold):
				_stop_voice()
				_show_complete()
				if not finished.get_connections().is_empty():
					_leaving = true
					finished.emit()
	# A single late disturbance; never attach a glitch to every mechanical answer.
	var tracking := 0.0
	if _index == 8 and _phase == Phase.RECORDED:
		tracking = smoothstep(0.55, 0.75, _phase_clock) * (1.0 - smoothstep(0.95, 1.2, _phase_clock)) * 0.55
	_material.set_shader_parameter("tracking_amount", tracking)
	var presence := 0.0
	if _index == 9 and _phase == Phase.RECORDED:
		presence = smoothstep(1.10, 1.14, _phase_clock) * (1.0 - smoothstep(1.33, 1.37, _phase_clock))
	_material.set_shader_parameter("presence_amount", presence)


func _set_phase(value: Phase) -> void:
	_phase = value
	_phase_clock = 0.0


func _show_assessment(id: String) -> void:
	_assessment_id = id
	_stop_voice()
	_background.texture = backgrounds[_index]
	_question.hide()
	_status.hide()
	for button in _answers:
		button.hide()
	_assessment = Assessment.new()
	_assessment.configure(id, _background.texture)
	_assessment.resolved.connect(_assessment_resolved)
	_assessment.voice_requested.connect(_assessment_voice_requested)
	_material.set_shader_parameter("fade", 0.0)
	_set_phase(Phase.ASSESSMENT)
	_column.add_child(_assessment)
	_assessment.set_suspended(_paused or not _focused)
	_assessment.initial_focus().grab_focus()
	_layout.call_deferred()


func _assessment_voice_requested(key: String) -> void:
	_play_voice(key)
	if key == "frames_retry":
		_assessment.hold_feedback(_voice_hold)


func _assessment_resolved(result: String) -> void:
	if _phase != Phase.ASSESSMENT or _paused or not _focused:
		return
	if progress.record_assessment(_assessment_id, result) != OK:
		push_error("Invalid interview assessment result")
		return
	_column.remove_child(_assessment)
	_assessment.queue_free()
	_assessment = null
	_status.text = "Результат записан."
	_status.show()
	_carriage.play()
	_set_phase(Phase.ASSESSMENT_RECORDED)
	_play_voice("result_recorded")
	_layout.call_deferred()


func _show_question() -> void:
	_background.texture = backgrounds[_index]
	_question.text = Questions.ITEMS[_index].question
	_question.show()
	_status.hide()
	_error.hide()
	_return_button.hide()
	for index in _answers.size():
		_answers[index].text = Questions.ITEMS[_index].answers[index]
		_answers[index].show()
		_answers[index].disabled = true
	_selected_focus = 0
	_wait_release = _accept_held
	_scroll.scroll_vertical = 0
	_material.set_shader_parameter("fade", 1.0)
	_set_phase(Phase.REVEAL)
	_play_voice("question_" + str(Questions.ITEMS[_index].id))
	_layout.call_deferred()


func _answer(choice: int) -> void:
	if _phase != Phase.QUESTION or _paused or not _focused or _wait_release:
		return
	var error: Error = progress.record_answer(choice)
	if error != OK:
		push_error("Invalid interview answer")
		return
	_error.hide()
	for button in _answers:
		button.disabled = true
	_selected_focus = choice
	_stop_voice()
	_sync_audio()
	_set_phase(Phase.ACKNOWLEDGE)


func _begin_ending() -> void:
	if progress.finish() != OK:
		push_error("Interview ended before all steps were completed")
		return
	_background.texture = backgrounds[backgrounds.size() - 1]
	_question.hide()
	for button in _answers:
		button.hide()
	_status.text = "Собеседование завершено.\nОжидайте сотрудника."
	_status.show()
	_material.set_shader_parameter("fade", 0.0)
	_set_phase(Phase.ENDING)
	_play_voice("complete")
	_layout.call_deferred()


func _show_complete() -> void:
	_background.texture = backgrounds[backgrounds.size() - 1]
	_question.hide()
	for button in _answers:
		button.hide()
	_status.text = "Собеседование завершено.\nОжидайте сотрудника."
	_status.show()
	_return_button.text = "Вернуться в кабинет" if not finished.get_connections().is_empty() else "В главное меню"
	_return_button.show()
	_material.set_shader_parameter("fade", 0.0)
	_set_phase(Phase.COMPLETE)
	_layout.call_deferred()


func _return() -> void:
	if _leaving:
		return
	if not finished.get_connections().is_empty():
		_stop_voice()
		_leaving = true
		finished.emit()
	else:
		_menu()


func _show_error(message: String) -> void:
	_error.text = message
	_error.show()
	_layout.call_deferred()


func _update_music(delta: float) -> void:
	if _index >= 2 and _index < 8 and not _music_started:
		_music_started = true
		_music.play()
	var target := 0.0
	if _index >= 2 and _index < 6:
		target = 1.0
	elif _index < 8 and _index >= 6:
		target = 0.35
	_music_level = move_toward(_music_level, target, delta / 2.5)
	_sync_audio()


func _sync_audio() -> void:
	if _carriage == null:
		return
	var suspended := _paused or not _focused
	if is_instance_valid(_assessment):
		_assessment.set_suspended(suspended)
	_carriage.stream_paused = suspended
	_music.stream_paused = suspended
	_room.stream_paused = suspended
	_voice.stream_paused = suspended
	var enabled := GameSettings.sound_enabled
	_carriage.volume_db = -2.0 if enabled else -80.0
	_voice.volume_db = 0.0 if enabled else -80.0
	var speaking := enabled and not suspended and _voice.playing
	var duck := 0.3 if speaking else (0.55 if _carriage.playing else 1.0)
	_music.volume_db = linear_to_db(maxf(_music_level * duck, 0.0001)) - 16.0 if enabled else -80.0
	_room.volume_db = -26.0 if speaking else -19.0
	if not enabled:
		_room.volume_db = -80.0


func _toggle_sound(enabled: bool) -> void:
	GameSettings.set_sound_enabled(enabled)
	_sync_audio()


func _pause() -> void:
	_paused = true
	_hide_credits()
	_pause_root.show()
	for button in _answers:
		button.disabled = true
	_continue_button.grab_focus()
	_sync_audio()


func _resume() -> void:
	_paused = false
	_pause_root.hide()
	_sync_audio()
	_update_answer_input()
	if _phase == Phase.QUESTION:
		_answers[_selected_focus].grab_focus()
	elif _phase == Phase.COMPLETE and _return_button.visible:
		_return_button.grab_focus()
	elif _phase == Phase.ASSESSMENT and is_instance_valid(_assessment):
		_assessment.initial_focus().grab_focus()


func _restart() -> void:
	progress.restart()
	_stop_voice()
	_carriage.stop()
	_music.stop()
	_music_started = false
	_music_level = 0.0
	_index = 0
	if is_instance_valid(_assessment):
		_column.remove_child(_assessment)
		_assessment.queue_free()
		_assessment = null
	_clock = 0.0
	_show_question()
	_resume()


func _show_credits() -> void:
	_pause_body.hide()
	_credits_body.show()
	_credits_back.grab_focus()


func _hide_credits() -> void:
	_pause_body.show()
	_credits_body.hide()
	_continue_button.grab_focus()


func _update_answer_input() -> void:
	var disabled := _phase != Phase.QUESTION or _paused or not _focused or _wait_release
	for button in _answers:
		button.disabled = disabled


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action("ui_accept"):
		if event.echo:
			get_viewport().set_input_as_handled()
			return
		_accept_held = event.pressed
		if not event.pressed:
			_wait_release = false
		if _phase not in [Phase.QUESTION, Phase.ASSESSMENT] and not _paused and _phase != Phase.COMPLETE:
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _paused:
			if _credits_body.visible:
				_hide_credits()
			else:
				_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_accept_held = false
		_wait_release = false
		_sync_audio()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_sync_audio()


func _menu() -> void:
	if _leaving:
		return
	_leaving = true
	_stop_voice()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error := get_tree().change_scene_to_file("res://scenes/start.tscn")
	if error != OK:
		_leaving = false
		_resume()
		_show_error("Не удалось открыть главное меню.")


func _layout() -> void:
	if _window == null:
		return
	var margin := maxf(20.0, size.x * 0.075)
	var width := minf(620.0, size.x - margin * 2.0)
	var question_size := 28 if size.x >= 1000.0 else 22
	_question.add_theme_font_size_override("font_size", question_size)
	_status.add_theme_font_size_override("font_size", question_size)
	for button in _answers:
		button.add_theme_font_size_override("font_size", 20 if size.x >= 1000.0 else 18)
	_window.size.x = width
	_window.custom_minimum_size.x = width
	var height := minf(ceilf(_column.get_combined_minimum_size().y + 44.0) + 2.0, size.y * 0.78)
	_window.size.y = height
	_window.position = Vector2(margin, maxf(size.y * 0.08, size.y * 0.88 - height))
	_material.set_shader_parameter("text_rect", Vector4(_window.position.x / size.x, _window.position.y / size.y, (_window.position.x + width) / size.x, (_window.position.y + height) / size.y))
	_hint.position = Vector2(margin, size.y * 0.92)
	_hint.size.x = width
	if _background.texture != null and size.x > 0.0 and size.y > 0.0:
		var photograph_size := _background.texture.get_size()
		var cover := maxf(size.x / photograph_size.x, size.y / photograph_size.y)
		var displayed := photograph_size * cover
		_material.set_shader_parameter("presence_center", (presence_center * displayed - (displayed - size) * 0.5) / size)
		_material.set_shader_parameter("presence_scale", displayed / size)


func _label(value: String, font_size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(value: String, action: Callable, font: Font = UI_FONT) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_stylebox_override("normal", _plate(Color(0.8, 0.83, 0.75, 0.025), 12))
	button.add_theme_stylebox_override("hover", _plate(Color(0.8, 0.83, 0.75, 0.13), 12))
	button.add_theme_stylebox_override("pressed", _plate(Color(0.8, 0.83, 0.75, 0.19), 12))
	button.add_theme_stylebox_override("disabled", _plate(Color(0.8, 0.83, 0.75, 0.025), 12))
	var focus := _plate(Color.TRANSPARENT, 12)
	focus.draw_center = false
	focus.border_color = Color(CREAM, 0.7)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button


func _plate(color: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(CREAM, 0.18)
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	return style


func _full_rect(control: Control, parent: Node) -> void:
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_focus_chain(controls: Array[Button]) -> void:
	for index in controls.size():
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index + controls.size() - 1) % controls.size()])


func _exit_tree() -> void:
	for player in [_carriage, _music, _room, _voice]:
		if is_instance_valid(player):
			player.stream_paused = false
			player.stop()
