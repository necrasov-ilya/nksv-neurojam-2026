class_name MenuSliceButton
extends Button

const ACCENT := Color("5b4cff")
const HOVER := Color("ac2954")
const INK := Color("242139")

var primary := false
var caption := ""
var symbol: Texture2D
var _progress := 0.0
var _motion: Tween
var _label: Label
var _icon: TextureRect
var _arrow: TextureRect


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_label = Label.new()
	_label.text = caption
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_font_override("font", preload("res://assets/fonts/OpenRunde-Semibold.woff2"))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_icon = _image(symbol)
	_arrow = _image(preload("res://assets/ui/icons/lucide/arrow-up-right.svg"))
	mouse_entered.connect(_sync_hover)
	mouse_exited.connect(_sync_hover)
	focus_entered.connect(_sync_hover)
	focus_exited.connect(_sync_hover)
	resized.connect(_layout)
	_layout()
	set_process(false)


func _image(texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image


func _sync_hover() -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	var target := 1.0 if not disabled and (is_hovered() or has_focus()) else 0.0
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_method(_set_progress, _progress, target, 0.18)


func _set_progress(value: float) -> void:
	_progress = value
	_layout()
	queue_redraw()


func _layout() -> void:
	if not is_instance_valid(_label):
		return
	var color := Color.WHITE if primary else INK
	color = color.lerp(Color.WHITE, _progress)
	if disabled:
		color.a = 0.35
	_label.add_theme_color_override("font_color", color)
	_label.position = Vector2(78 + _progress * 8, (size.y - _label.get_minimum_size().y) * 0.5)
	_icon.position = Vector2(30 + _progress * 4, (size.y - 28) * 0.5)
	_icon.size = Vector2(28, 28)
	_icon.modulate = color
	_arrow.size = Vector2(26, 26)
	_arrow.position = Vector2(size.x - 80 + _progress * 8, (size.y - 26) * 0.5)
	_arrow.modulate = color
	queue_redraw()


func _draw() -> void:
	var color := ACCENT if primary else Color("e7e4f3")
	color = color.lerp(HOVER, _progress)
	if button_pressed:
		color = color.darkened(0.12)
	if disabled:
		color = Color("dedbe8")
	draw_colored_polygon(_shape(), color)


func _shape() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x - 36, size.y), Vector2(0, size.y)])


func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _shape())
