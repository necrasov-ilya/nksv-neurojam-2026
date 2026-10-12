extends Node

const MAIN_SCENE_PATH := "res://scenes/prologue.tscn"
const ACCENT := Color("5b4cff")
const HOVER := Color("ac2954")
const INK := Color("242139")
const MUTED := Color("78738d")
const PAPER := Color("f5f3fb")
const FONT := preload("res://assets/fonts/OpenRunde-Semibold.woff2")
const UIStyle := preload("res://scripts/ui/hud_style.gd")
const SettingsUI := preload("res://scripts/ui/settings_panel.gd")
const ICON_PATH := "res://assets/ui/icons/lucide/"

@onready var orientation_guard: OrientationGuard = $OrientationGuard

var _stage: Control
var _photo: TextureRect
var _plane: Polygon2D
var _title: Label
var _subtitle: Label
var _about_button: Button
var _start_button: MenuSliceButton
var _menu_buttons: Array[MenuSliceButton] = []
var _blob: MenuBlob
var _drawer_root: Control
var _drawer: Panel
var _scrim: Button
var _settings_body: SettingsUI
var _about_body: Control
var _about_info: RichTextLabel
var _about_copy: String
var _close_button: Button
var _drawer_title: Label
var _drawer_tween: Tween
var _drawer_open := false
var _drawer_width := 560.0
var _previous_focus: Control
var _music: AudioStreamPlayer

func _process(_delta: float) -> void:
	if _music:
		_music.stream_paused = not GameSettings.sound_enabled or not get_window().has_focus()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	orientation_guard.landscape_changed.connect(_on_landscape_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_on_landscape_changed(orientation_guard.is_landscape())
	_music = AudioStreamPlayer.new()
	var track: AudioStreamOggVorbis = preload("res://assets/audio/campaign/menu_epilogue.ogg").duplicate()
	track.loop = true
	_music.stream = track
	_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_music.volume_db = -35
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -16.0, 1.4)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuUI"
	layer.layer = 10
	add_child(layer)
	_stage = Control.new()
	_stage.name = "Menu"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_stage)
	_photo = TextureRect.new()
	_photo.texture = preload("res://assets/textures/menu_city.jpg")
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.modulate = Color(0.53, 0.48, 0.69)
	_stage.add_child(_photo)
	var tint := ColorRect.new()
	tint.color = Color(0.08, 0.06, 0.19, 0.23)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(tint)
	_plane = Polygon2D.new()
	_plane.color = PAPER
	_stage.add_child(_plane)
	_title = _label("LATENTPUNK", 64, INK, _stage)
	_title.add_theme_font_override("font", FONT)
	_subtitle = _label("TEST SUBJECT 0", 25, ACCENT, _stage)
	var continuing := GameRun.campaign_started and GameRun.ending.is_empty()
	_start_button = _menu_button("Продолжить" if continuing else "Играть", "play", true, _on_start_pressed)
	_menu_button("Настройки", "sliders-horizontal", false, func(): _show_drawer(false))
	_menu_button("Выход", "log-out", false, _on_exit_pressed)
	_about_button = UIStyle.small_button("Об игре", "info", func(): _show_drawer(true))
	_stage.add_child(_about_button)
	_blob = MenuBlob.new()
	_blob.name = "LiquidSubject"
	_stage.add_child(_blob)
	_build_drawer()


func _menu_button(caption: String, icon_name: String, primary: bool, callback: Callable) -> MenuSliceButton:
	var button := MenuSliceButton.new()
	button.caption = caption
	button.symbol = load(ICON_PATH + icon_name + ".svg")
	button.primary = primary
	button.pressed.connect(callback)
	_stage.add_child(button)
	_menu_buttons.append(button)
	return button


func _build_drawer() -> void:
	_drawer_root = Control.new()
	_drawer_root.name = "SettingsDrawer"
	_drawer_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_root.hide()
	_stage.add_child(_drawer_root)
	_scrim = Button.new()
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.focus_mode = Control.FOCUS_NONE
	_scrim.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_scrim.modulate.a = 0.0
	for state in ["normal", "hover", "pressed", "focus"]:
		_scrim.add_theme_stylebox_override(state, UIStyle.flat(Color(0.06, 0.04, 0.15, 0.45)))
	_scrim.pressed.connect(_hide_drawer)
	_drawer_root.add_child(_scrim)
	_drawer = Panel.new()
	_drawer.name = "Sheet"
	_drawer.add_theme_stylebox_override("panel", _drawer_style(PAPER, 48))
	_drawer_root.add_child(_drawer)
	_drawer_title = _label("Настройки", 36, INK, _drawer)
	_drawer_title.position = Vector2(48, 46)
	_close_button = UIStyle.small_button("", "x", _hide_drawer)
	_close_button.tooltip_text = "Закрыть · Esc"
	_close_button.position = Vector2(464, 50)
	_close_button.size = Vector2(40, 40)
	_drawer.add_child(_close_button)
	_settings_body = SettingsUI.new()
	_settings_body.position = Vector2(48, 134)
	_settings_body.size = Vector2(430, 480)
	_drawer.add_child(_settings_body)
	_about_body = Control.new()
	_about_body.position = Vector2(48, 134)
	_about_body.size = Vector2(430, 490)
	_drawer.add_child(_about_body)
	var about_scroll := ScrollContainer.new()
	about_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	about_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_about_body.add_child(about_scroll)
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.add_theme_font_override("normal_font", FONT)
	info.add_theme_font_size_override("normal_font_size", 19)
	info.add_theme_color_override("default_color", INK)
	info.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	about_scroll.add_child(info)
	info.text = "LATENTPUNK: TEST SUBJECT 0\n\nСобеседование · Три смены · Квартира · Финал\n\n[color=#5b4cff]АВТОРЫ И ИГРОВЫЕ СРЕДЫ[/color]\n[url=https://t.me/nksv_ilya]NKSV_ILYA · @nksv_ilya[/url]\nLATENTPUNK, калибровка, DEAD PARADE и DUSTFALL.\n\n[url=https://t.me/fuckup_files]Алёша · @fuckup_files[/url]\nОстальные внешние игры — из его проекта bench-portal.\n[url=https://github.com/alesha-pro/bench-portal]Оригинальный репозиторий · alesha-pro/bench-portal ↗[/url]\nАвторские и лицензионные уведомления включённых игр сохранены.\n\nWASD — идти · Мышь — обзор\nE — взаимодействие и постановка предмета\nЛКМ — поднять / уронить · Q — бросить\nR — сбросить калибровку\nTab — выбор · Enter — ответ\nEsc — пауза и свободный курсор\nF8 — снимок на стендах\nДиски справа снизу — Telegram авторов.\n\nМузыка Shift Change — собственная композиция\nГолоса: Built with Fish Audio · fish.audio\nИконки: Lucide Contributors · ISC / MIT\n\nGodot 4.7.2 · Compatibility\nОднопоточный Web\n\nПрогресс сохраняется только в текущем запуске."
	info.custom_minimum_size.x = 408
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text += "\n\nМузыка меню: Epilogue — Creo\ncreo-music.com/track/epilogue · CC BY-NC 4.0\nМузыка сна: Ossuary 6 - Air — Kevin MacLeod\nincompetech.com · CC BY 4.0\nИспуг Ники: Horror Sting (Deep in the Void)2 — SilverIllusionist\nfreesound.org/people/SilverIllusionist/sounds/655386/ · CC BY 4.0"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_about_info = info
	_about_copy = info.text
	if GameRun.campaign_started and GameRun.ending.is_empty():
		about_scroll.offset_bottom = -70
		var restart := UIStyle.small_button("Начать заново", "rotate-ccw", _start_new_run)
		restart.position = Vector2(0, 440)
		restart.size = Vector2(180, 42)
		_about_body.add_child(restart)


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ratio := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	_stage.scale = Vector2.ONE * ratio
	_stage.size = viewport_size / ratio
	var width := _stage.size.x
	var height := _stage.size.y
	_photo.size = _stage.size
	_plane.polygon = PackedVector2Array([Vector2.ZERO, Vector2(860, 0), Vector2(570, height), Vector2(0, height)])
	_title.position = Vector2(44, 58)
	_subtitle.position = Vector2(48, 143)
	for index in _menu_buttons.size():
		_menu_buttons[index].position = Vector2(0, height * 0.44 + index * 104)
		_menu_buttons[index].size = Vector2(660 - index * 48, 88)
	_about_button.position = Vector2(42, height - 60)
	_about_button.size = Vector2(156, 40)
	_blob.size = Vector2(490, 490)
	_blob.position = Vector2(width - 528, height * 0.5 - 240)
	_drawer.size = Vector2(_drawer_width, height)
	if not _drawer_open:
		_drawer.position.x = -_drawer_width - 40
	else:
		_drawer.position.x = 0


func _show_drawer(about: bool) -> void:
	_blob.release_grab()
	_previous_focus = _stage.get_viewport().gui_get_focus_owner()
	_settings_body.visible = not about
	_about_body.visible = about
	_drawer_title.text = "Об игре" if about else "Настройки"
	_about_info.text = _about_copy
	_settings_body.refresh()
	_drawer_root.show()
	_drawer_open = true
	if _drawer_tween and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_property(_drawer, "position:x", 0.0, 0.38)
	_drawer_tween.tween_property(_scrim, "modulate:a", 1.0, 0.25)
	for button in _menu_buttons:
		button.focus_mode = Control.FOCUS_NONE
	_about_button.focus_mode = Control.FOCUS_NONE
	_blob.focus_mode = Control.FOCUS_NONE
	if about:
		_close_button.grab_focus()
	else:
		_settings_body.sound_button.grab_focus()


func _hide_drawer() -> void:
	if not _drawer_open:
		return
	_drawer_open = false
	if _drawer_tween and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_drawer_tween.tween_property(_drawer, "position:x", -_drawer_width - 40, 0.3)
	_drawer_tween.tween_property(_scrim, "modulate:a", 0.0, 0.3)
	_drawer_tween.chain().tween_callback(_drawer_root.hide)
	for button in _menu_buttons:
		button.focus_mode = Control.FOCUS_ALL
	_about_button.focus_mode = Control.FOCUS_ALL
	_blob.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(_previous_focus):
		_previous_focus.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _drawer_open:
		_hide_drawer()
		get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	if not orientation_guard.is_landscape():
		return
	if GameRun.campaign_started and GameRun.ending.is_empty():
		get_tree().change_scene_to_file("res://scenes/campaign.tscn")
	else:
		_start_new_run()


func _start_new_run() -> void:
	if not orientation_guard.is_landscape():
		return
	GameRun.new_run()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_exit_pressed() -> void:
	if OS.has_feature("web"):
		_show_drawer(true)
		_drawer_title.text = "Выход"
		_about_info.text = "Чтобы завершить сеанс, закройте вкладку.\n\nПрогресс текущего запуска не сохраняется после закрытия.\n\nEsc — вернуться в меню."
	else:
		get_tree().quit()


func _on_landscape_changed(is_landscape: bool) -> void:
	_start_button.disabled = not is_landscape
	if not is_landscape:
		_blob.release_grab()


func _label(caption: String, font_size: int, color: Color, parent: Node) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _icon(icon_name: String, parent: Node, position_value: Vector2, size_value: Vector2, color: Color) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(ICON_PATH + icon_name + ".svg")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = position_value
	image.size = size_value
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image




func _drawer_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := UIStyle.flat(color)
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	return style
