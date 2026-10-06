class_name OrientationGuard
extends CanvasLayer

signal landscape_changed(is_landscape: bool)

const PORTRAIT_TITLE := "Нужна горизонтальная раскладка"
const PORTRAIT_MESSAGE := "Игра работает только в горизонтальном окне.\nСделайте окно шире, чем высоким, или поверните устройство."

var _overlay_root: Control
var _last_landscape := true


func _ready() -> void:
	layer = 20
	_overlay_root = _build_overlay()
	add_child(_overlay_root)
	_last_landscape = is_landscape()
	_sync_overlay()


func _process(_delta: float) -> void:
	var current := is_landscape()
	if current != _last_landscape:
		_last_landscape = current
		_sync_overlay()
		landscape_changed.emit(current)


func is_landscape() -> bool:
	var size := get_viewport().get_visible_rect().size
	return size.x > size.y


func _sync_overlay() -> void:
	_overlay_root.visible = not _last_landscape


func _build_overlay() -> Control:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.visible = false
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.92)
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
	panel_style.border_color = Color(0.98, 0.72, 0.18)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = PORTRAIT_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.72, 0.18))
	box.add_child(title)
	var message := Label.new()
	message.text = PORTRAIT_MESSAGE
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 18)
	box.add_child(message)
	return root