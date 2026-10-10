extends Control

signal resolved(result: String)
signal voice_requested(key: String)

const PIXEL_FONT := preload("res://assets/interview/fonts/Galmuri11-Subset.ttf")
const CREAM := Color("e9e5d4")
const PAPER := Color("cbc6b6")
const HOLD_SECONDS := 0.45
# Each fringe is within half a reference pixel: the two outlines are ~1 px apart.
const ALIGNMENT_TOLERANCE := 0.55
const ALIGNMENT_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float displacement = 0.0;
uniform float photograph_width = 1.0;
void fragment() {
	vec2 shift = vec2(displacement / max(photograph_width, 1.0), 0.0);
	vec4 center = texture(TEXTURE, UV);
	float red = texture(TEXTURE, clamp(UV + shift, vec2(0.0), vec2(1.0))).r;
	float blue = texture(TEXTURE, clamp(UV - shift, vec2(0.0), vec2(1.0))).b;
	COLOR = vec4(red, center.g, blue, center.a);
}
"""

var _kind := ""
var _photograph: Texture2D
var _configured := false
var _suspended := false
var _finished := false
var _release_gate := false
var _different_frame := 0
var _alignment_target := 0.0
var _held_seconds := 0.0
var _feedback_seconds := 0.0
var _column: VBoxContainer
var _grid: GridContainer
var _cards: Array[Button] = []
var _slider: HSlider
var _print: PanelContainer
var _image: TextureRect
var _material: ShaderMaterial
var _feedback: Label
var _skip: Button
var _focus_controls: Array[Control] = []


func configure(kind: String, photograph: Texture2D) -> void:
	assert(not is_inside_tree() and not _configured, "Configure an assessment once, before adding it to the tree.")
	assert(kind == "frames" or kind == "alignment", "Unknown assessment kind.")
	assert(photograph != null, "An assessment needs its real photograph.")
	_kind = kind
	_photograph = photograph
	_configured = true
	if kind == "frames":
		var random := RandomNumberGenerator.new()
		# A stable draw makes this photograph's differing print deterministic.
		random.seed = (photograph.resource_path + ":frames").hash()
		_different_frame = random.randi_range(0, 5)
	else:
		var random := RandomNumberGenerator.new()
		random.randomize()
		_alignment_target = random.randf_range(-4.0, 4.0)


func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	if not value:
		# Release the key or mouse button used in the pause overlay first.
		_release_gate = true
	_sync_interaction()
	set_process(not _suspended and not _finished)


func initial_focus() -> Control:
	if _focus_controls.is_empty():
		return null
	return _focus_controls[0]


func hold_feedback(seconds: float) -> void:
	_feedback_seconds = maxf(_feedback_seconds, seconds)


func _ready() -> void:
	assert(_configured, "Call configure before adding an assessment to the tree.")
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	add_child(_column)
	_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column.minimum_size_changed.connect(_update_minimum)
	_column.resized.connect(_layout_photographs)
	if _kind == "frames":
		_build_frames()
	else:
		_build_alignment()
	_feedback = _label("", 16)
	_feedback.custom_minimum_size.y = 24
	_feedback.add_theme_color_override("font_color", Color(CREAM, 0.75))
	_column.add_child(_feedback)
	_skip = _button("Пропустить", _finish.bind("skipped"))
	_column.add_child(_skip)
	_focus_controls.append(_skip)
	for index in _focus_controls.size():
		var control := _focus_controls[index]
		control.focus_next = control.get_path_to(_focus_controls[(index + 1) % _focus_controls.size()])
		control.focus_previous = control.get_path_to(_focus_controls[(index + _focus_controls.size() - 1) % _focus_controls.size()])
	_sync_interaction()
	_update_minimum()
	set_process(not _suspended and not _finished)
	voice_requested.emit(_kind)


func _build_frames() -> void:
	_column.add_child(_label("Найдите снимок, который отличается от остальных.", 24))
	_column.add_child(_label("Выберите снимок. Tab — переход между снимками, Enter — выбор.", 17))
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_column.add_child(_grid)
	_grid.resized.connect(_layout_photographs)
	for index in 6:
		var card := _button("", _select_frame.bind(index))
		card.custom_minimum_size = Vector2(64, 120)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state in ["normal", "hover", "pressed", "disabled"]:
			var paper := _plate(PAPER, 8)
			paper.border_color = Color("aaa696")
			if state == "hover":
				paper.border_color = CREAM
			card.add_theme_stylebox_override(state, paper)
		_grid.add_child(card)
		var margin := MarginContainer.new()
		for edge in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 8)
		card.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var image := _photograph_rect()
		image.flip_h = index == _different_frame
		margin.add_child(image)
		_cards.append(card)
		_focus_controls.append(card)


func _build_alignment() -> void:
	_column.add_child(_label("Совместите отпечатки.", 24))
	_column.add_child(_label("Сдвигайте отпечаток, пока контуры не совпадут.\nСтрелки ← → — сдвиг, Tab — переход к следующему действию.", 17))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(center)
	_print = PanelContainer.new()
	_print.custom_minimum_size = Vector2(256, 151)
	_print.add_theme_stylebox_override("panel", _plate(PAPER, 8))
	center.add_child(_print)
	_image = _photograph_rect()
	_print.add_child(_image)
	var shader := Shader.new()
	shader.code = ALIGNMENT_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_image.material = _material
	_image.resized.connect(_update_alignment_shader)
	_slider = HSlider.new()
	_slider.custom_minimum_size.y = 48
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.focus_mode = Control.FOCUS_ALL
	_slider.min_value = -8.0
	_slider.max_value = 8.0
	_slider.step = 0.1
	_slider.value = -6.0 if _alignment_target >= 0.0 else 6.0
	_slider.scrollable = false
	var track := _plate(Color("302f29"), 0)
	track.set_content_margin_all(2)
	_slider.add_theme_stylebox_override("slider", track)
	_slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	_slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	var focus := _plate(Color.TRANSPARENT, 0)
	focus.draw_center = false
	focus.border_color = Color(CREAM, 0.6)
	_slider.add_theme_stylebox_override("focus", focus)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([PAPER, PAPER])
	var thumb := GradientTexture2D.new()
	thumb.gradient = gradient
	thumb.width = 12
	thumb.height = 24
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		_slider.add_theme_icon_override(icon, thumb)
	_slider.value_changed.connect(_alignment_changed)
	_column.add_child(_slider)
	_focus_controls.append(_slider)
	_update_alignment_shader()


func _process(delta: float) -> void:
	if _suspended or _finished:
		return
	if _release_gate:
		if not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_release_gate = false
			_sync_interaction()
		return
	if _feedback_seconds > 0.0:
		_feedback_seconds = maxf(0.0, _feedback_seconds - delta)
		if _feedback_seconds == 0.0:
			_feedback.text = ""
	if _kind != "alignment":
		return
	if absf(_slider.value - _alignment_target) <= ALIGNMENT_TOLERANCE:
		_held_seconds += delta
		if _held_seconds >= HOLD_SECONDS:
			_finish("completed")
	else:
		_held_seconds = 0.0


func _select_frame(index: int) -> void:
	if _suspended or _finished or _release_gate:
		return
	if index == _different_frame:
		_finish("completed")
	else:
		_feedback.text = "Это тот же снимок. Попробуйте ещё раз."
		_feedback_seconds = 1.5
		voice_requested.emit("frames_retry")


func _alignment_changed(_value: float) -> void:
	if _suspended or _finished or _release_gate:
		return
	if absf(_slider.value - _alignment_target) > ALIGNMENT_TOLERANCE:
		_held_seconds = 0.0
	_update_alignment_shader()


func _update_alignment_shader() -> void:
	if _material == null or _slider == null:
		return
	var photograph_width := minf(_image.size.x, _image.size.y * float(_photograph.get_width()) / float(_photograph.get_height()))
	_material.set_shader_parameter("photograph_width", maxf(1.0, photograph_width))
	var reference_scale := get_viewport_rect().size.x / 1280.0
	_material.set_shader_parameter("displacement", (_slider.value - _alignment_target) * reference_scale)


func _layout_photographs() -> void:
	if _grid != null:
		var card_width := maxf(64.0, (_grid.size.x - 24.0) / 3.0)
		var card_height := maxf(48.0, (card_width - 16.0) * 9.0 / 16.0 + 16.0)
		for card in _cards:
			card.custom_minimum_size.y = card_height
	if _print != null:
		var non_photo_height := _column.get_combined_minimum_size().y - _print.get_combined_minimum_size().y
		var available_height := maxf(100.0, get_viewport_rect().size.y * 0.78 - 70.0 - non_photo_height)
		var width_for_height := (available_height - 16.0) * 16.0 / 9.0 + 16.0
		var print_width := maxf(64.0, minf(minf(_column.size.x, 560.0), width_for_height))
		_print.custom_minimum_size = Vector2(print_width, (print_width - 16.0) * 9.0 / 16.0 + 16.0)
		_update_alignment_shader()


func _update_minimum() -> void:
	custom_minimum_size.y = _column.get_combined_minimum_size().y


func _sync_interaction() -> void:
	var disabled := _suspended or _finished
	for card in _cards:
		card.disabled = disabled
	if _skip != null:
		_skip.disabled = disabled
	if _slider != null:
		_slider.editable = not disabled and not _release_gate
	for control in _focus_controls:
		control.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL


func _finish(result: String) -> void:
	if _suspended or _finished or _release_gate:
		return
	_finished = true
	_feedback.text = "Результат записан."
	_sync_interaction()
	set_process(false)
	resolved.emit(result)


func _photograph_rect() -> TextureRect:
	var image := TextureRect.new()
	image.texture = _photograph
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, CREAM)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := Color("262720") if state == "hover" else Color("1c1d18")
		button.add_theme_stylebox_override(state, _plate(color, 12))
	var focus := _plate(Color.TRANSPARENT, 0)
	focus.draw_center = false
	focus.border_color = CREAM
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button


func _plate(color: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(CREAM, 0.2)
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	return style
