class_name PauseDrawer
extends Control

signal close_requested

const UIStyle := preload("res://scripts/ui/hud_style.gd")
const SettingsUI := preload("res://scripts/ui/settings_panel.gd")

var body: VBoxContainer
var settings_body: VBoxContainer
var _sheet: Panel
var _scrim: Button
var _heading: Label
var _back: Button
var _scroll: ScrollContainer
var _pages: Dictionary = {}
var _titles: Dictionary = {}
var _view := "main"
var _motion: Tween
var _closing := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	_scrim = Button.new()
	_scrim.focus_mode = Control.FOCUS_NONE
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		_scrim.add_theme_stylebox_override(state, UIStyle.flat(Color(0.06, 0.04, 0.15, 0.45)))
	_scrim.pressed.connect(_back_or_close)
	add_child(_scrim)
	_sheet = Panel.new()
	var paper := UIStyle.flat(UIStyle.PAPER)
	paper.corner_radius_top_right = 48
	paper.corner_radius_bottom_right = 48
	_sheet.add_theme_stylebox_override("panel", paper)
	add_child(_sheet)
	_heading = UIStyle.label("Пауза", 36)
	_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_heading.offset_left = 48
	_heading.offset_right = -108
	_heading.offset_top = 46
	_heading.offset_bottom = 98
	_sheet.add_child(_heading)
	_back = UIStyle.small_button("", "x", _back_or_close)
	_back.size = Vector2(44, 44)
	_sheet.add_child(_back)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 48
	_scroll.offset_right = -48
	_scroll.offset_top = 126
	_scroll.offset_bottom = -36
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_sheet.add_child(_scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(stack)
	body = _add_page(stack, "main", "Пауза")
	settings_body = _add_page(stack, "settings", "Настройки")
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	_layout()
	show_page("main")


func _add_page(stack: VBoxContainer, id: String, title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = id.capitalize()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	stack.add_child(page)
	_pages[id] = page
	_titles[id] = title
	page.visible = id == _view
	return page


func add_page(id: String, title: String) -> VBoxContainer:
	return _add_page(body.get_parent(), id, title)


func show_page(id: String) -> void:
	_view = id
	for page_id in _pages:
		_pages[page_id].visible = page_id == id
	_heading.text = _titles[id]
	_back.tooltip_text = "Продолжить · Esc" if id == "main" else "Закрыть страницу · Esc"
	_scroll.scroll_vertical = 0
	if is_visible_in_tree():
		_focus_first.call_deferred()


func show_settings() -> void:
	show_page("settings")


func add_settings(sound_callback: Callable, subtitles_callback: Callable = Callable()) -> void:
	settings_body.add_child(SettingsUI.new(sound_callback, subtitles_callback))


func _focus_first() -> void:
	if not is_visible_in_tree():
		return
	for button: BaseButton in _pages[_view].find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return
	_back.grab_focus()


func _layout() -> void:
	if _sheet == null:
		return
	_sheet.size = Vector2(minf(560.0, maxf(320.0, size.x - 24.0)), size.y)
	_back.position = Vector2(_sheet.size.x - 96, 50)
	if not visible:
		_sheet.position.x = -_sheet.size.x - 8
	elif not _closing:
		_sheet.position.x = 0


func _on_visibility_changed() -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	_closing = false
	if not visible:
		return
	show_page("main")
	_sheet.position.x = -_sheet.size.x - 8
	_scrim.modulate.a = 0.0
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_sheet, "position:x", 0.0, 0.35)
	_motion.tween_property(_scrim, "modulate:a", 1.0, 0.25)


func request_close() -> void:
	if _closing or not visible:
		return
	_closing = true
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(_sheet, "position:x", -_sheet.size.x - 8, 0.25)
	_motion.tween_property(_scrim, "modulate:a", 0.0, 0.25)
	_motion.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	hide()
	close_requested.emit()


func _back_or_close() -> void:
	if _view == "main":
		request_close()
	else:
		show_page("main")


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		if event is InputEventKey and event.echo:
			return
		_back_or_close()
		get_viewport().set_input_as_handled()
