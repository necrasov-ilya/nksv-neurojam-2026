class_name SettingsPanel
extends Control

const UIStyle := preload("res://scripts/ui/hud_style.gd")
const FONT := preload("res://assets/fonts/OpenRunde-Semibold.woff2")

var sound_button: Button
var subtitles_button: Button
var gamma_slider: HSlider
var gamma_title: Label
var reset_button: Button
var _gamma_card: Panel
var _gamma_value: Label
var _preview: HBoxContainer
var _sound_callback: Callable
var _subtitles_callback: Callable


func _init(sound_callback: Callable = Callable(), subtitles_callback: Callable = Callable()) -> void:
	_sound_callback = sound_callback if sound_callback.is_valid() else GameSettings.set_sound_enabled
	_subtitles_callback = subtitles_callback if subtitles_callback.is_valid() else GameSettings.set_subtitles_enabled
	custom_minimum_size = Vector2(430, 480)
	size = custom_minimum_size


func _ready() -> void:
	sound_button = _toggle_row("Sound", "Звук", "volume-2", 0, func():
		_sound_callback.call(not GameSettings.sound_enabled)
		refresh()
	)
	subtitles_button = _toggle_row("Subtitles", "Субтитры", "captions", 72, func():
		_subtitles_callback.call(not GameSettings.subtitles_enabled)
		refresh()
	)
	_gamma_card = Panel.new()
	_gamma_card.name = "GammaCard"
	_gamma_card.position = Vector2(0, 144)
	_gamma_card.size = Vector2(430, 156)
	_gamma_card.add_theme_stylebox_override("panel", UIStyle.flat(UIStyle.SURFACE, 16))
	add_child(_gamma_card)
	_icon("sun", _gamma_card, Vector2(20, 18), UIStyle.INK)
	gamma_title = _label("Гамма", 20, UIStyle.INK, _gamma_card, Vector2(60, 16))
	_gamma_value = _label("", 19, UIStyle.ACCENT, _gamma_card, Vector2(350, 18))
	gamma_slider = HSlider.new()
	gamma_slider.name = "Gamma"
	gamma_slider.min_value = 0.6
	gamma_slider.max_value = 1.6
	gamma_slider.step = 0.05
	gamma_slider.position = Vector2(24, 70)
	gamma_slider.size = Vector2(382, 32)
	gamma_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["slider", "grabber_area", "grabber_area_highlight"]:
		var color := Color("d0c9e9") if state == "slider" else (UIStyle.HOVER if state == "grabber_area_highlight" else UIStyle.ACCENT)
		var track := UIStyle.flat(color, 4)
		track.content_margin_top = 4
		track.content_margin_bottom = 4
		gamma_slider.add_theme_stylebox_override(state, track)
	gamma_slider.add_theme_icon_override("grabber", preload("res://assets/ui/gamma_grabber.svg"))
	gamma_slider.add_theme_icon_override("grabber_highlight", preload("res://assets/ui/gamma_grabber_hover.svg"))
	gamma_slider.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	gamma_slider.value_changed.connect(func(value: float):
		GameSettings.set_gamma(value)
		_gamma_value.text = "%.2f" % GameSettings.gamma
	)
	_gamma_card.add_child(gamma_slider)
	_label("Темнее", 14, UIStyle.MUTED, _gamma_card, Vector2(24, 116))
	var light := _label("Светлее", 14, UIStyle.MUTED, _gamma_card, Vector2(342, 116))
	light.name = "Light"
	reset_button = UIStyle.small_button("Сбросить", "rotate-ccw", func(): gamma_slider.value = 1.0)
	reset_button.position = Vector2(146, 110)
	reset_button.size = Vector2(138, 34)
	_gamma_card.add_child(reset_button)
	_preview = HBoxContainer.new()
	_preview.position = Vector2(0, 318)
	_preview.size = Vector2(430, 28)
	_preview.add_theme_constant_override("separation", 8)
	add_child(_preview)
	for color in [Color.BLACK, Color("36333f"), Color("817b91"), Color("bdb6cc"), Color.WHITE]:
		var patch := ColorRect.new()
		patch.color = color
		patch.custom_minimum_size = Vector2(0, 28)
		patch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview.add_child(patch)
	_label("Чёрный остаётся чёрным. Средние тона меняются.", 12, UIStyle.MUTED, self, Vector2(0, 360))
	_label("Настройки действуют до закрытия игры.", 12, UIStyle.MUTED, self, Vector2(0, 434))
	resized.connect(_layout)
	visibility_changed.connect(refresh)
	_layout()
	refresh()


func _toggle_row(id: String, caption: String, icon_name: String, y: float, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.position = Vector2(0, y)
	button.size = Vector2(430, 60)
	for state in ["normal", "hover", "pressed", "focus"]:
		var color := UIStyle.SURFACE if state == "normal" else (UIStyle.HOVER.darkened(0.1) if state == "pressed" else UIStyle.HOVER)
		button.add_theme_stylebox_override(state, UIStyle.flat(color, 16))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	add_child(button)
	var image := _icon(icon_name, button, Vector2(20, 18), UIStyle.INK)
	var title := _label(caption, 20, UIStyle.INK, button, Vector2(60, 16))
	var status := _label("", 16, UIStyle.ACCENT, button, Vector2(350, 20))
	status.name = "Status"
	var repaint := func():
		var active := button.is_hovered() or button.has_focus()
		image.modulate = Color.WHITE if active else UIStyle.INK
		title.add_theme_color_override("font_color", Color.WHITE if active else UIStyle.INK)
		status.add_theme_color_override("font_color", Color.WHITE if active else UIStyle.ACCENT)
	for signal_name in ["mouse_entered", "mouse_exited", "focus_entered", "focus_exited"]:
		button.connect(signal_name, repaint)
	return button


func _label(text: String, pixels: int, color: Color, parent: Control, position: Vector2) -> Label:
	var result := UIStyle.label(text, pixels, color)
	result.autowrap_mode = TextServer.AUTOWRAP_OFF
	result.add_theme_font_override("font", FONT)
	result.position = position
	parent.add_child(result)
	return result


func _icon(name: String, parent: Control, position: Vector2, color: Color) -> TextureRect:
	var image := UIStyle.icon(name, 24, color)
	image.position = position
	image.size = Vector2(24, 24)
	parent.add_child(image)
	return image


func refresh() -> void:
	if not is_node_ready():
		return
	sound_button.get_node("Status").text = "Вкл." if GameSettings.sound_enabled else "Выкл."
	subtitles_button.get_node("Status").text = "Вкл." if GameSettings.subtitles_enabled else "Выкл."
	(sound_button.get_child(0) as TextureRect).texture = load(UIStyle.ICON_PATH + ("volume-2.svg" if GameSettings.sound_enabled else "volume-x.svg"))
	gamma_slider.set_value_no_signal(GameSettings.gamma)
	_gamma_value.text = "%.2f" % GameSettings.gamma


func _layout() -> void:
	if _gamma_card == null:
		return
	for button in [sound_button, subtitles_button]:
		button.size.x = size.x
		button.get_node("Status").position.x = size.x - 80
	_gamma_card.size.x = size.x
	_gamma_value.position.x = size.x - 80
	gamma_slider.size.x = size.x - 48
	_gamma_card.get_node("Light").position.x = size.x - 88
	reset_button.position.x = (size.x - reset_button.size.x) / 2.0
	_preview.size.x = size.x
