extends Node

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const GAME_TITLE := "Шаблон"

const BRIGHT_COLOR := Color(1.0, 0.72, 0.14)
const BRIGHT_HOVER := Color(1.0, 0.8, 0.28)
const BRIGHT_PRESSED := Color(0.88, 0.6, 0.1)
const PLATE_COLOR := Color(0.13, 0.16, 0.21)
const PLATE_HOVER := Color(0.19, 0.23, 0.3)
const PLATE_PRESSED := Color(0.09, 0.11, 0.14)
const TEXT_COLOR := Color(0.88, 0.9, 0.94)
const DISABLED_TEXT := Color(0.4, 0.42, 0.46)
const DISABLED_PLATE := Color(0.08, 0.09, 0.12)

@export var background_texture: Texture2D

@onready var orientation_guard: OrientationGuard = $OrientationGuard

var _ui_layer: CanvasLayer
var _start_button: Button
var _settings_panel: Control
var _about_panel: Control
var _sound_check: CheckButton


func _ready() -> void:
	_build_ui()
	orientation_guard.landscape_changed.connect(_on_landscape_changed)
	_on_landscape_changed(orientation_guard.is_landscape())


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "Ui"
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var background := TextureRect.new()
	background.texture = background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	_ui_layer.add_child(background)

	var tint := ColorRect.new()
	tint.color = Color(0, 0, 0, 0.45)
	tint.anchor_right = 1.0
	tint.anchor_bottom = 1.0
	_ui_layer.add_child(tint)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_ui_layer.add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(380, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(title)

	_start_button = _styled_button("Начать игру", 26, BRIGHT_COLOR, BRIGHT_HOVER, BRIGHT_PRESSED)
	_start_button.pressed.connect(_on_start_pressed)
	column.add_child(_start_button)
	column.add_child(_styled_button("Настройки", 20, PLATE_COLOR, PLATE_HOVER, PLATE_PRESSED, _show_settings))
	column.add_child(_styled_button("Об игре", 20, PLATE_COLOR, PLATE_HOVER, PLATE_PRESSED, _show_about))
	column.add_child(_styled_button("Выход", 20, PLATE_COLOR, PLATE_HOVER, PLATE_PRESSED, _on_exit_pressed))

	var settings_parts := _make_dialog("Настройки")
	_settings_panel = settings_parts[0]
	var settings_body: VBoxContainer = settings_parts[1]
	_sound_check = CheckButton.new()
	_sound_check.text = "Звук"
	_sound_check.button_pressed = GameSettings.sound_enabled
	_sound_check.add_theme_font_size_override("font_size", 18)
	_sound_check.toggled.connect(_on_sound_toggled)
	settings_body.add_child(_sound_check)
	settings_body.add_child(_styled_button("Готово", 18, PLATE_COLOR, PLATE_HOVER, PLATE_PRESSED, _hide_settings))

	var about_parts := _make_dialog("Об игре")
	_about_panel = about_parts[0]
	var about_body: VBoxContainer = about_parts[1]
	var info := Label.new()
	info.text = "«Шаблон» — игра для 72-часового геймджема.\nGodot 4.7.2 · GDScript · Compatibility renderer.\nОкно должно быть горизонтальным: шире, чем высоким."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	about_body.add_child(info)
	about_body.add_child(_styled_button("Готово", 18, PLATE_COLOR, PLATE_HOVER, PLATE_PRESSED, _hide_about))


func _on_start_pressed() -> void:
	if not orientation_guard.is_landscape():
		return
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _show_settings() -> void:
	_settings_panel.visible = true


func _hide_settings() -> void:
	_settings_panel.visible = false


func _show_about() -> void:
	_about_panel.visible = true


func _hide_about() -> void:
	_about_panel.visible = false


func _on_sound_toggled(value: bool) -> void:
	GameSettings.set_sound_enabled(value)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_landscape_changed(is_landscape: bool) -> void:
	_start_button.disabled = not is_landscape


func _styled_button(
	text_value: String,
	font_size: int,
	normal_color: Color,
	hover_color: Color,
	pressed_color: Color,
	callback: Callable = Callable()
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(360, 54)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	button.add_theme_stylebox_override("normal", _flat(normal_color))
	button.add_theme_stylebox_override("hover", _flat(hover_color))
	button.add_theme_stylebox_override("pressed", _flat(pressed_color))
	button.add_theme_stylebox_override("disabled", _flat(DISABLED_PLATE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _make_dialog(title_text: String) -> Array:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.visible = false
	_ui_layer.add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.78)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.11, 0.15)
	panel_style.border_color = Color(0.4, 0.45, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	body.add_child(title)
	return [root, body]


func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(12)
	return box