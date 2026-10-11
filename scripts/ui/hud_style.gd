class_name HudStyle
extends RefCounted

const PAPER := Color("f5f3fb")
const SURFACE := Color("e7e4f3")
const INK := Color("242139")
const MUTED := Color("78738d")
const ACCENT := Color("5b4cff")
const HOVER := Color("ac2954")
const FONT := preload("res://assets/fonts/OpenRunde-Regular.woff2")
const STRONG_FONT := preload("res://assets/fonts/OpenRunde-Semibold.woff2")
const ICON_PATH := "res://assets/ui/icons/lucide/"


static func flat(color: Color, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 24
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	return style


static func plate(color: Color = PAPER, padding: int = 18, radius: int = 16) -> StyleBoxFlat:
	var style := flat(color, radius)
	style.set_content_margin_all(padding)
	return style


static func label(text: String, size: int = 18, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func icon(icon_name: String, pixels: int = 24, color: Color = ACCENT) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(ICON_PATH + icon_name + ".svg")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(pixels, pixels)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


static func apply_button(button: Button, primary: bool = false) -> void:
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", STRONG_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", plate(ACCENT if primary else SURFACE, 12, 12))
	button.add_theme_stylebox_override("hover", plate(HOVER, 12, 12))
	button.add_theme_stylebox_override("pressed", plate(HOVER.darkened(0.12), 12, 12))
	button.add_theme_stylebox_override("focus", plate(HOVER, 12, 12))
	button.add_theme_stylebox_override("disabled", plate(Color("eeebf4"), 12, 12))
	button.add_theme_color_override("font_color", Color.WHITE if primary else INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("icon_normal_color", Color.WHITE if primary else ACCENT)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_focus_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22)
	button.add_theme_constant_override("h_separation", 12)


static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 18
	for type_name in ["Panel", "PanelContainer", "PopupMenu"]:
		result.set_stylebox("panel", type_name, plate())
	for type_name in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		result.set_stylebox("normal", type_name, plate(SURFACE, 12, 12))
		result.set_stylebox("hover", type_name, plate(HOVER, 12, 12))
		result.set_stylebox("pressed", type_name, plate(HOVER.darkened(0.12), 12, 12))
		result.set_stylebox("focus", type_name, plate(HOVER, 12, 12))
		result.set_stylebox("disabled", type_name, plate(Color("eeebf4"), 12, 12))
		result.set_color("font_color", type_name, INK)
		result.set_color("font_hover_color", type_name, Color.WHITE)
		result.set_color("font_focus_color", type_name, Color.WHITE)
		result.set_color("font_pressed_color", type_name, Color.WHITE)
		result.set_color("font_disabled_color", type_name, MUTED)
		result.set_font("font", type_name, STRONG_FONT)
	result.set_stylebox("normal", "LineEdit", plate(SURFACE, 12, 12))
	result.set_stylebox("focus", "LineEdit", plate(Color("ddd6f5"), 12, 12))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", ACCENT)
	result.set_color("selection_color", "LineEdit", ACCENT)
	result.set_color("font_selected_color", "LineEdit", Color.WHITE)
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	result.set_stylebox("hover", "PopupMenu", plate(ACCENT, 8, 8))
	result.set_color("font_color", "Label", INK)
	result.set_color("default_color", "RichTextLabel", INK)
	result.set_color("font_color", "ScrollBar", MUTED)
	return result


static func small_button(caption: String, icon_name: String, callback: Callable) -> Button:
	var button := Button.new()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	var image := icon(icon_name, 22, MUTED)
	row.add_child(image)
	var title: Label
	if not caption.is_empty():
		title = label(caption, 16, MUTED)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.add_theme_font_override("font", preload("res://assets/fonts/OpenRunde-Semibold.woff2"))
		row.add_child(title)
	var repaint := func():
		var color := HOVER if button.is_hovered() or button.has_focus() else MUTED
		image.modulate = color
		if is_instance_valid(title):
			title.add_theme_color_override("font_color", color)
	for signal_name in ["mouse_entered", "mouse_exited", "focus_entered", "focus_exited"]:
		button.connect(signal_name, repaint)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", flat(SURFACE, 14))
	button.add_theme_stylebox_override("pressed", flat(Color("d8d1ec"), 14))
	button.add_theme_stylebox_override("focus", flat(SURFACE, 14))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button
