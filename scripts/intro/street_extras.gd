extends Node

signal say_requested(speaker: String, text: String, seconds: float)
signal clear_speech_requested()
signal sound_requested(event_name: String)

const CAPTIONS := {
	"street_bus": "Поговорить с водителем",
	"street_cafe": "Послушать разговор у кафе",
	"street_crossing": "Нажать кнопку пешеходного перехода",
	"street_ad": "Переключить рекламу LATENT SYSTEMS",
}
const BUS_LINES := [
	["Вы", "Этот автобус идёт до LATENT SYSTEMS?", 2.5],
	["Водитель", "На собеседование? Тогда пешком. Мы тут тоже ждём, когда нас позовут.", 5.0],
	["Вы", "А до четырнадцатого этажа не довезёте?", 2.5],
	["Водитель", "Четырнадцатый этаж — не автобусная остановка. Дальше на лифте, без пересадок.", 4.5],
]
const CAFE_LINES := [
	[
		["Посетительница", "Нейросеть придумала мне рецепт ужина.", 2.5],
		["Посетитель", "И как?", 2.0],
		["Посетительница", "Вкусно. Теперь прошу рецепт чистой посуды.", 3.0],
		["Посетитель", "Тут, боюсь, опять ручной труд.", 2.5],
	],
	[
		["Посетительница", "Попросила нейросеть упростить рецепт.", 2.5],
		["Посетитель", "Она убрала лишние ингредиенты?", 2.5],
		["Посетительница", "Нет, добавила ещё две кастрюли.", 2.5],
		["Посетитель", "Значит, посуду моет автор запроса.", 2.5],
	],
	[
		["Посетительница", "Нейросеть назвала мой ужин экспериментальным.", 3.0],
		["Посетитель", "А кто моет посуду после эксперимента?", 2.5],
		["Посетительница", "В рецепте об этом ни слова.", 2.0],
		["Посетитель", "Понятно. Опять мы — человеческая поддержка.", 2.5],
	],
]
const CROSSING_MESSAGES := ["ЖДИТЕ", "МЫ УЖЕ ЗНАЕМ", "НАСТОЙЧИВОСТЬ\nУЧТЕНА"]
const CROSSING_IDLE := "НАЖМИТЕ"
const AD_MESSAGES := [
	"Генерируем миры.\nКофе пока варим вручную.",
	"Будущее уже здесь.\nПриложите пропуск.",
	"Генерация миров — круглосуточно.\nОбед — по расписанию.",
	"Безграничный потенциал.\nИспытательный срок: 3 месяца.",
]
const SPEECH_COOLDOWN := 4.0
const BUTTON_COOLDOWN := 0.4
const CROSSING_RESET := 12.0
const LEAVE_DISTANCE_SQUARED := 25.0
const EMPTY_LINES: Array = []

var current_speech: String = ""
var _city: Node3D
var _driver: Node3D
var _crossing_display: Label3D
var _crossing_lamp: Node3D
var _crossing_button: Node3D
var _ad_display: Label3D
var _ad_button: Node3D
var _crossing_rest := Vector3.ZERO
var _ad_rest := Vector3.ZERO
var _crossing_pixel_size := 0.012
var _ad_pixel_size := 0.012
var _crossing_tween: Tween
var _ad_tween: Tween
var _speech_lines: Array = EMPTY_LINES
var _speech_action := ""
var _speech_index := -1
var _speech_remaining := 0.0
var _speech_anchor := Vector3.ZERO
var _bus_cooldown := 0.0
var _cafe_cooldown := 0.0
var _crossing_cooldown := 0.0
var _ad_cooldown := 0.0
var _cafe_visit := 0
var _crossing_presses := 0
var _crossing_idle := 0.0
var _ad_index := 0
var _street_active := true
var _paused := false

func setup(city_root: Node3D) -> void:
	set_process(false)
	_city = city_root
	_driver = _city.get("street_driver") as Node3D
	_crossing_display = _city.get("street_crossing_display") as Label3D
	_crossing_lamp = _city.get("street_crossing_lamp") as Node3D
	_crossing_button = _city.get("street_crossing_button") as Node3D
	_ad_display = _city.get("street_ad_display") as Label3D
	_ad_button = _city.get("street_ad_button") as Node3D
	_crossing_rest = _crossing_button.position
	_ad_rest = _ad_button.position
	_crossing_pixel_size = _crossing_display.pixel_size
	_ad_pixel_size = _ad_display.pixel_size
	_crossing_lamp.visible = false
	_set_display(_crossing_display, CROSSING_IDLE, _crossing_pixel_size, 1.24, 0.54)
	_set_display(_ad_display, AD_MESSAGES[0], _ad_pixel_size, 3.00, 1.10)

func activate(action: String, listener_position: Vector3) -> bool:
	if not CAPTIONS.has(action):
		return false
	if _city == null or not _street_active or _paused:
		return true
	match action:
		"street_bus":
			if _bus_cooldown <= 0.0 and _speech_action != action:
				_bus_cooldown = SPEECH_COOLDOWN
				var target := listener_position
				target.y = _driver.global_position.y
				if _driver.global_position.distance_squared_to(target) > 0.0001:
					_driver.look_at(target, Vector3.UP)
				_start_speech(action, BUS_LINES)
		"street_cafe":
			if _cafe_cooldown <= 0.0 and _speech_action != action:
				_cafe_cooldown = SPEECH_COOLDOWN
				_start_speech(action, CAFE_LINES[_cafe_visit % CAFE_LINES.size()])
				_cafe_visit += 1
		"street_crossing":
			if _crossing_cooldown <= 0.0:
				_crossing_cooldown = BUTTON_COOLDOWN
				_crossing_idle = CROSSING_RESET
				_crossing_presses = mini(_crossing_presses + 1, CROSSING_MESSAGES.size())
				_crossing_lamp.visible = true
				_set_display(_crossing_display, CROSSING_MESSAGES[_crossing_presses - 1], _crossing_pixel_size, 1.24, 0.54)
				_crossing_tween = _press_button(_crossing_button, _crossing_rest, _crossing_tween)
				sound_requested.emit("ui_click")
		"street_ad":
			if _ad_cooldown <= 0.0:
				_ad_cooldown = BUTTON_COOLDOWN
				_ad_index = (_ad_index + 1) % AD_MESSAGES.size()
				_set_display(_ad_display, AD_MESSAGES[_ad_index], _ad_pixel_size, 3.00, 1.10)
				_ad_tween = _press_button(_ad_button, _ad_rest, _ad_tween)
				sound_requested.emit("ui_click")
	return true

func tick(delta: float, listener_position: Vector3, street_active: bool, paused: bool) -> void:
	var was_street_active := _street_active
	_street_active = street_active
	_paused = paused
	if not street_active:
		if was_street_active:
			cancel()
		return
	if _speech_index >= 0 and listener_position.distance_squared_to(_speech_anchor) > LEAVE_DISTANCE_SQUARED:
		_clear_speech()
	if paused:
		return
	_bus_cooldown = maxf(0.0, _bus_cooldown - delta)
	_cafe_cooldown = maxf(0.0, _cafe_cooldown - delta)
	_crossing_cooldown = maxf(0.0, _crossing_cooldown - delta)
	_ad_cooldown = maxf(0.0, _ad_cooldown - delta)
	if _crossing_tween != null and not _crossing_tween.custom_step(delta):
		_crossing_tween = null
	if _ad_tween != null and not _ad_tween.custom_step(delta):
		_ad_tween = null
	if _crossing_idle > 0.0:
		_crossing_idle = maxf(0.0, _crossing_idle - delta)
		if _crossing_idle <= 0.0:
			_reset_crossing()
	if _speech_index < 0:
		return
	# Cooldown stays armed throughout the exchange and for a short interval after it.
	if _speech_action == "street_bus":
		_bus_cooldown = SPEECH_COOLDOWN
	else:
		_cafe_cooldown = SPEECH_COOLDOWN
	_speech_remaining -= delta
	while _speech_index >= 0 and _speech_remaining <= 0.0:
		_speech_index += 1
		if _speech_index >= _speech_lines.size():
			_clear_speech()
			return
		var line: Array = _speech_lines[_speech_index]
		_speech_remaining += float(line[2])
		if _speech_remaining > 0.0:
			current_speech = line[1]
			say_requested.emit(line[0], current_speech, _speech_remaining)

func cancel() -> void:
	_clear_speech()
	if _crossing_tween != null:
		_crossing_tween.kill()
		_crossing_tween = null
	if _ad_tween != null:
		_ad_tween.kill()
		_ad_tween = null
	if _crossing_button != null:
		_crossing_button.position = _crossing_rest
	if _ad_button != null:
		_ad_button.position = _ad_rest
	if _crossing_display != null and _crossing_presses > 0:
		_reset_crossing()

func _start_speech(action: String, lines: Array) -> void:
	_clear_speech()
	var anchors: Dictionary = _city.get("street_anchors")
	_speech_anchor = _city.to_global(anchors[action])
	_speech_lines = lines
	_speech_action = action
	_speech_index = 0
	var line: Array = _speech_lines[0]
	_speech_remaining = float(line[2])
	current_speech = line[1]
	say_requested.emit(line[0], current_speech, _speech_remaining)

func _clear_speech() -> void:
	var owned_speech := not current_speech.is_empty()
	current_speech = ""
	_speech_index = -1
	_speech_remaining = 0.0
	_speech_lines = EMPTY_LINES
	_speech_action = ""
	if owned_speech:
		clear_speech_requested.emit()

func _reset_crossing() -> void:
	_crossing_presses = 0
	_crossing_idle = 0.0
	_crossing_lamp.visible = false
	_set_display(_crossing_display, CROSSING_IDLE, _crossing_pixel_size, 1.24, 0.54)

func _press_button(button: Node3D, rest: Vector3, previous: Tween) -> Tween:
	if previous != null:
		previous.kill()
	button.position = rest
	# Manually stepped, so no automatic tween can advance during pause or after exit.
	var tween := create_tween()
	tween.pause()
	tween.tween_property(button, "position:z", rest.z - 0.035, 0.08)
	tween.tween_interval(0.06)
	tween.tween_property(button, "position:z", rest.z, 0.14)
	return tween

func _set_display(label: Label3D, text: String, base_pixel_size: float, max_width: float, max_height: float) -> void:
	label.text = text
	var lines := text.split("\n")
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, label.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x)
	var text_height := label.font.get_height(label.font_size) * lines.size()
	var fitted := base_pixel_size
	if widest > 0.0:
		fitted = minf(fitted, max_width / widest)
	if text_height > 0.0:
		fitted = minf(fitted, max_height / text_height)
	label.pixel_size = fitted
