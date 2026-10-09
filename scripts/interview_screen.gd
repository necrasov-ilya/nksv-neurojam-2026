extends Control
## Local registration at the office terminal; no network or story interview.

const FONT_REGULAR := preload("res://assets/fonts/OpenRunde-Regular.woff2")
const FONT_SEMIBOLD := preload("res://assets/fonts/OpenRunde-Semibold.woff2")
const FONT_PIXEL := preload("res://assets/interview/fonts/Galmuri11-Subset.ttf")
const CLICK := preload("res://assets/audio/intro/ui_click.wav")
const WRONG := preload("res://assets/audio/intro/ui_wrong.wav")
const SAVE_PATH := "user://interview_registration.cfg"
const ROLES: Array[String] = ["Разработка", "Дизайн", "Исследования", "Аналитика", "Пока выбираю"]
const EXPERIENCE: Array[String] = ["Первый опыт", "Меньше года", "1–3 года", "Больше 3 лет"]
const INK := Color("243e43")
const MUTED := Color("526769")
const TEAL := Color("326b66")
const PAPER := Color("f4f0dc")

var _scroll: ScrollContainer
var _panel: PanelContainer
var _form: VBoxContainer
var _confirmation: VBoxContainer
var _name_input: LineEdit
var _role: OptionButton
var _experience: OptionButton
var _error: Label
var _saved_notice: Label
var _summary: Label
var _edit_button: Button
var _sound: CheckButton
var _audio: AudioStreamPlayer
var _form_focus: Array[Control] = []
var _confirmation_focus: Array[Control] = []
var _leaving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -16.0
	add_child(_audio)
	_build_ui()
	_load_registration()
	resized.connect(_resize_layout)
	_resize_layout()
	_set_focus_chain(_form_focus)
	_name_input.grab_focus.call_deferred()


func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT_REGULAR
	ui_theme.default_font_size = 18
	ui_theme.set_color("font_color", "Label", INK)
	theme = ui_theme
	_scroll = ScrollContainer.new()
	_scroll.name = "RegistrationScroll"
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	_scroll.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _plate(PAPER, TEAL, 3, 24))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)
	var brand := _label("LATENT SYSTEMS", 22, TEAL)
	brand.add_theme_font_override("font", FONT_PIXEL)
	column.add_child(brand)
	column.add_child(_label("ТЕРМИНАЛ 04  /  ОТДЕЛ КАДРОВ", 12, MUTED))
	column.add_child(HSeparator.new())

	_form = VBoxContainer.new()
	_form.name = "RegistrationForm"
	_form.add_theme_constant_override("separation", 10)
	column.add_child(_form)
	_form.add_child(_label("Перед собеседованием", 28))
	_form.add_child(_label("Устройтесь поудобнее. Укажите, как к вам обращаться, и выберите направление.", 17, MUTED))
	_saved_notice = _label("", 15, TEAL)
	_saved_notice.visible = false
	_form.add_child(_saved_notice)
	_form.add_child(_label("Ваше имя", 16))
	_name_input = LineEdit.new()
	_name_input.name = "CandidateName"
	_name_input.placeholder_text = "Как к вам обращаться?"
	_name_input.max_length = 64
	_name_input.custom_minimum_size.y = 48
	_name_input.add_theme_color_override("font_color", INK)
	_name_input.add_theme_color_override("font_placeholder_color", MUTED)
	_name_input.add_theme_color_override("caret_color", TEAL)
	_name_input.add_theme_stylebox_override("normal", _plate(Color("fffbed"), Color("91a69a"), 2, 12))
	_name_input.add_theme_stylebox_override("focus", _focus_plate())
	_name_input.text_submitted.connect(func(_text: String): _role.grab_focus())
	_name_input.text_changed.connect(func(_text: String): _clear_error())
	_form.add_child(_name_input)
	_form.add_child(_label("Направление", 16))
	_role = _choice("Выберите направление", ROLES)
	_role.name = "CandidateRole"
	_form.add_child(_role)
	_form.add_child(_label("Опыт в этом направлении", 16))
	_experience = _choice("Выберите опыт", EXPERIENCE)
	_experience.name = "CandidateExperience"
	_form.add_child(_experience)
	_form.add_child(_label("Анкета сохраняется только на этом устройстве. В браузере — в данных этого сайта. Ничего не отправляется по сети.", 14, MUTED))
	_error = _label("", 16, Color("a23e35"))
	_error.name = "ValidationMessage"
	_error.visible = false
	_form.add_child(_error)
	var submit := _button("Сохранить анкету", _submit, true)
	submit.name = "SubmitRegistration"
	_form.add_child(submit)
	_form_focus = [_name_input, _role, _experience, submit]

	_confirmation = VBoxContainer.new()
	_confirmation.name = "RegistrationConfirmation"
	_confirmation.add_theme_constant_override("separation", 16)
	_confirmation.visible = false
	column.add_child(_confirmation)
	_confirmation.add_child(_label("Анкета сохранена", 28, TEAL))
	_confirmation.add_child(_label("Спасибо! Ваши данные записаны на этом устройстве.", 18))
	var summary_panel := PanelContainer.new()
	summary_panel.add_theme_stylebox_override("panel", _plate(Color("e2e8d7"), Color("9bac94"), 2, 16))
	_confirmation.add_child(summary_panel)
	_summary = _label("", 20)
	_summary.name = "SubmittedValues"
	summary_panel.add_child(_summary)
	_confirmation.add_child(_label("Регистрация завершена. Это локальная анкета перед собеседованием, а не начало интервью. Вы можете изменить данные или снова пройти вступление.", 16, MUTED))
	_edit_button = _button("Изменить анкету", _edit_registration, true)
	_edit_button.name = "EditRegistration"
	_confirmation.add_child(_edit_button)
	_confirmation_focus = [_edit_button]

	column.add_child(HSeparator.new())
	var restart := _button("Заново во вступление", _navigate.bind("res://scenes/intro.tscn"))
	restart.name = "RestartIntro"
	column.add_child(restart)
	var menu := _button("В главное меню", _navigate.bind("res://scenes/start.tscn"))
	menu.name = "ReturnToMenu"
	column.add_child(menu)
	_sound = CheckButton.new()
	_sound.text = "Звук интерфейса"
	_sound.button_pressed = GameSettings.sound_enabled
	_sound.custom_minimum_size.y = 44
	_sound.add_theme_color_override("font_color", INK)
	_sound.add_theme_color_override("font_hover_color", TEAL)
	_sound.add_theme_color_override("font_pressed_color", TEAL)
	_sound.add_theme_stylebox_override("focus", _focus_plate())
	_sound.toggled.connect(_toggle_sound)
	column.add_child(_sound)
	column.add_child(_label("Tab — выбор поля · Enter — действие\nEsc — к редактированию сохранённой анкеты", 12, MUTED))
	_form_focus.append_array([restart, menu, _sound])
	_confirmation_focus.append_array([restart, menu, _sound])


func _label(text_value: String, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 24:
		label.add_theme_font_override("font", FONT_SEMIBOLD)
	return label


func _plate(color: Color, border: Color, width: int, padding: int) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = color
	plate.border_color = border
	plate.set_border_width_all(width)
	plate.content_margin_left = padding
	plate.content_margin_right = padding
	plate.content_margin_top = padding
	plate.content_margin_bottom = padding
	return plate


func _focus_plate() -> StyleBoxFlat:
	var plate := _plate(Color.TRANSPARENT, Color("bd782c"), 3, 0)
	plate.draw_center = false
	return plate


func _button(text_value: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", FONT_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 17)
	var foreground := PAPER if primary else INK
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, foreground)
	button.add_theme_stylebox_override("normal", _plate(TEAL if primary else Color("e3e5d3"), TEAL, 2, 10))
	button.add_theme_stylebox_override("hover", _plate(Color("437d72") if primary else Color("d2dec8"), TEAL, 2, 10))
	button.add_theme_stylebox_override("pressed", _plate(Color("254f4e") if primary else Color("bfd0b8"), INK, 2, 10))
	button.add_theme_stylebox_override("focus", _focus_plate())
	button.pressed.connect(callback)
	return button


func _choice(placeholder: String, items: Array[String]) -> OptionButton:
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 48
	choice.fit_to_longest_item = false
	choice.clip_text = true
	choice.add_item(placeholder)
	choice.set_item_disabled(0, true)
	for item in items:
		choice.add_item(item)
	choice.select(0)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		choice.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed"]:
		choice.add_theme_stylebox_override(state, _plate(Color("fffbed"), Color("91a69a"), 2, 12))
	choice.add_theme_stylebox_override("focus", _focus_plate())
	var popup := choice.get_popup()
	popup.add_theme_font_override("font", FONT_REGULAR)
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_constant_override("v_separation", 16)
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", PAPER)
	popup.add_theme_stylebox_override("panel", _plate(PAPER, TEAL, 2, 10))
	popup.add_theme_stylebox_override("hover", _plate(TEAL, TEAL, 0, 4))
	choice.item_selected.connect(func(_index: int):
		_clear_error()
		_play_sound()
	)
	return choice


func _resize_layout() -> void:
	_panel.custom_minimum_size.x = minf(620.0, maxf(240.0, size.x - 64.0))
	queue_redraw()


func _set_focus_chain(controls: Array[Control]) -> void:
	for index in controls.size():
		var control := controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[(index + controls.size() - 1) % controls.size()])


func _clear_error() -> void:
	_error.visible = false


func _reject(message: String, field: Control) -> void:
	_error.text = message
	_error.visible = true
	field.grab_focus()
	_scroll.ensure_control_visible.call_deferred(_error)
	_play_sound(true)


func _has_visible_name(value: String) -> bool:
	# Include non-ASCII spaces that can be pasted into a browser text field.
	const SPACES := " \t\n\r\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u200b\u2028\u2029\u202f\u205f\u3000\ufeff"
	for character in value:
		if character.unicode_at(0) > 32 and not SPACES.contains(character):
			return true
	return false


func _submit() -> void:
	var candidate_name := _name_input.text.strip_edges()
	if not _has_visible_name(candidate_name):
		_reject("Введите имя: одних пробелов недостаточно.", _name_input)
		return
	if _role.selected <= 0:
		_reject("Выберите направление.", _role)
		return
	if _experience.selected <= 0:
		_reject("Выберите ваш опыт.", _experience)
		return
	var registration := ConfigFile.new()
	registration.set_value("candidate", "name", candidate_name)
	registration.set_value("candidate", "role", ROLES[_role.selected - 1])
	registration.set_value("candidate", "experience", EXPERIENCE[_experience.selected - 1])
	if registration.save(SAVE_PATH) != OK:
		_reject("Не удалось сохранить анкету на устройстве. Проверьте доступ к хранилищу и попробуйте ещё раз.", _name_input)
		return
	_name_input.text = candidate_name
	_summary.text = "Имя\n%s\n\nНаправление\n%s\n\nОпыт\n%s" % [candidate_name, ROLES[_role.selected - 1], EXPERIENCE[_experience.selected - 1]]
	_form.visible = false
	_confirmation.visible = true
	_set_focus_chain(_confirmation_focus)
	_edit_button.grab_focus()
	_scroll.set_deferred("scroll_vertical", 0)
	_play_sound()


func _load_registration() -> void:
	var registration := ConfigFile.new()
	if registration.load(SAVE_PATH) != OK:
		return
	var candidate_name := str(registration.get_value("candidate", "name", "")).strip_edges()
	var role_index := ROLES.find(str(registration.get_value("candidate", "role", "")))
	var experience_index := EXPERIENCE.find(str(registration.get_value("candidate", "experience", "")))
	if not _has_visible_name(candidate_name) or role_index < 0 or experience_index < 0:
		return
	_name_input.text = candidate_name
	_role.select(role_index + 1)
	_experience.select(experience_index + 1)
	_saved_notice.text = "Загружена ваша сохранённая анкета. Изменения запишутся после нажатия «Сохранить анкету»."
	_saved_notice.visible = true


func _edit_registration() -> void:
	_confirmation.visible = false
	_form.visible = true
	_saved_notice.text = "Предыдущая анкета сохранена. Изменения запишутся только после повторного сохранения."
	_saved_notice.visible = true
	_clear_error()
	_set_focus_chain(_form_focus)
	_name_input.grab_focus()
	_scroll.set_deferred("scroll_vertical", 0)
	_play_sound()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _confirmation.visible:
		_edit_registration()
		get_viewport().set_input_as_handled()


func _toggle_sound(enabled: bool) -> void:
	GameSettings.set_sound_enabled(enabled)
	if enabled:
		_play_sound()
	else:
		_audio.stop()


func _play_sound(error: bool = false) -> void:
	if not GameSettings.sound_enabled:
		return
	_audio.stream = WRONG if error else CLICK
	_audio.play()


func _navigate(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	if get_tree().change_scene_to_file(scene_path) != OK:
		_leaving = false
		if _confirmation.visible:
			_edit_registration()
		_reject("Не удалось открыть сцену. Анкета и введённые данные остаются здесь.", _name_input)


func _draw() -> void:
	# Purpose-built, static pixel office: afternoon skyline, shelving and plants.
	# Integer rectangles keep it crisp without a viewport, shaders or processing.
	var scale_factor := maxf(size.x / 480.0, size.y / 270.0)
	var offset := (size - Vector2(480, 270) * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
	_rect(0, 0, 480, 270, "a9b9a4")
	_rect(0, 0, 480, 12, "617f75")
	_rect(0, 12, 480, 3, "e6dcba")
	for x in range(8, 480, 32):
		_rect(x, 16, 1, 199, "9bab96")
	_rect(15, 30, 137, 164, "516e68")
	_rect(20, 35, 127, 151, "f0d6ab")
	_rect(23, 38, 121, 143, "b8d9d1")
	_rect(23, 100, 121, 81, "dfcba7")
	_rect(110, 51, 17, 17, "fff1be")
	_rect(106, 55, 25, 9, "fff1be")
	for building in [[25, 95, 23, 86], [50, 118, 18, 63], [72, 83, 28, 98], [106, 107, 17, 74], [126, 91, 18, 90]]:
		_rect(building[0], building[1], building[2], building[3], "829f99")
		_rect(building[0], building[1], building[2], 3, "607e79")
		for y in range(building[1] + 9, 177, 12):
			for x in range(building[0] + 4, building[0] + building[2] - 3, 8):
				_rect(x, y, 3, 5, "e7dbaa")
	_rect(79, 36, 5, 150, "f0dfb9")
	_rect(21, 108, 125, 5, "f0dfb9")
	_rect(11, 186, 146, 7, "e5d5b0")
	_rect(15, 193, 138, 4, "809384")
	_rect(339, 45, 120, 153, "627f73")
	_rect(345, 51, 108, 141, "8e9f88")
	for shelf_y in [86, 131, 177]:
		_rect(341, shelf_y, 116, 5, "e1cba2")
		_rect(345, shelf_y + 5, 108, 3, "516e65")
	for book in [[350, 60, 8, 26], [360, 56, 10, 30], [372, 62, 7, 24], [383, 58, 12, 28], [350, 104, 15, 27], [368, 109, 10, 22], [383, 102, 8, 29], [396, 108, 11, 23]]:
		_rect(book[0], book[1], book[2], book[3], "b57659")
		_rect(book[0] + 2, book[1] + 5, book[2] - 4, 2, "f0d5a1")
	_rect(414, 60, 27, 20, "e1d6b8")
	_rect(418, 64, 19, 12, "779e93")
	_rect(360, 151, 35, 26, "c4c5a1")
	_rect(370, 158, 15, 4, "6b8476")
	_rect(0, 215, 480, 55, "829689")
	_rect(0, 213, 480, 5, "576f66")
	for y in range(230, 270, 18):
		_rect(0, y, 480, 1, "74897d")
	_rect(0, 223, 149, 10, "d0a778")
	_rect(8, 233, 7, 37, "68766b")
	_rect(137, 233, 7, 37, "68766b")
	_rect(33, 211, 28, 12, "bd8361")
	_rect(36, 207, 22, 5, "ebc38c")
	_rect(68, 212, 37, 3, "efdfb8")
	_rect(72, 216, 41, 4, "5e8278")
	_plant(45, 209)
	_rect(409, 228, 29, 30, "ae7458")
	_rect(405, 224, 37, 7, "dca478")
	_plant(423, 222)
	_rect(408, 194, 12, 8, "688d69")
	_rect(430, 183, 16, 7, "739c70")
	draw_set_transform(Vector2.ZERO)


func _rect(x: float, y: float, width: float, height: float, hex: String) -> void:
	draw_rect(Rect2(x, y, width, height), Color(hex))


func _plant(x: float, y: float) -> void:
	_rect(x - 1, y - 38, 3, 39, "466e57")
	_rect(x - 15, y - 30, 14, 6, "507e5d")
	_rect(x - 19, y - 36, 13, 7, "6f996b")
	_rect(x + 1, y - 23, 17, 6, "507e5d")
	_rect(x + 10, y - 29, 13, 7, "7da575")
	_rect(x - 8, y - 44, 8, 11, "7ba675")
	_rect(x + 2, y - 42, 9, 9, "5c8963")
