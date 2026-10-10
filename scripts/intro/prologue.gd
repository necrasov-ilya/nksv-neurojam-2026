extends Node3D
## Two sequential recordings share one audio clock, one city and one handoff.

const CITY_SCENE := "res://scenes/intro.tscn"
const AUDIO_DIR := "res://assets/audio/prologue/"
const CUE_SCRIPT := "res://scripts/intro/prologue_cues.gd"
const TapeShader := preload("res://assets/shaders/intro_tape.gdshader")
const InterfaceTheme := preload("res://assets/fonts/interface_theme.tres")
const OpeningFont := preload("res://assets/fonts/OpenRunde-Regular.woff2")
const OpeningLogo := preload("res://assets/textures/nksv_logo.svg")
const CREAM := Color("eee9d7")
const LOGO_HOLD := 2.6
const HANDOFF_SECONDS := 1.3
const HOLD_SECONDS := 1.2
const HINT_IDLE_SECONDS := 4.0
const CAPTION_LINES := 4
const CAPTION_FADE_SECONDS := 0.18

enum Phase { LOGO, LOADING, READY, NARRATION, HANDOFF, CLOSED }
var _phase := Phase.LOGO
var _skip_requested := false
var _logo_clock := 0.0
var _speech_clock := 0.0
var _handoff_clock := 0.0
var _duration := 0.0
var _cues: Array = []
var _cue_index := -1
var _cue_cursor := 0
var _caption_block_start := 0.0
var _caption_first_cue := 0
var _caption_measure := TextParagraph.new()
var _hold_key := KEY_NONE
var _hold_started_msec := -1
var _hold_elapsed := 0.0
var _focused := true
var _hint_revealed := false
var _hint_idle := 0.0
var _city: Node3D
var _camera: Camera3D
var _start_view: Transform3D
var _final_view: Transform3D
var _narration: AudioStreamPlayer
var _impact: AudioStreamPlayer
var _ui: Control
var _veil: ColorRect
var _logo: TextureRect
var _caption: Label
var _hold_hint: Control
var _hold_text: Label
var _hold_ring: Control
var _tape: ColorRect
var _tape_material: ShaderMaterial
var _handoff_logo_alpha := 0.0
var _handoff_caption_alpha := 0.0
var _handoff_hint_alpha := 0.0
var _handoff_veil_alpha := 1.0
var _handoff_mix := 0.0
var _city_mix := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_narration = AudioStreamPlayer.new()
	_narration.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var speech := AudioStreamPlaylist.new()
	speech.stream_count = 2
	speech.loop = false
	speech.shuffle = false
	speech.fade_time = 0.0
	speech.set_list_stream(0, load(AUDIO_DIR + "narration.ogg") as AudioStream)
	speech.set_list_stream(1, load(AUDIO_DIR + "arrival_dry.ogg") as AudioStream)
	_narration.stream = speech
	add_child(_narration)
	_narration.finished.connect(_begin_handoff)
	var cue_resource := load(CUE_SCRIPT) as Script
	var constants: Dictionary = cue_resource.get_script_constant_map()
	_cues = constants["CUES"]
	_duration = float(constants["DURATION"])
	_impact = AudioStreamPlayer.new()
	_impact.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_impact.stream = load(AUDIO_DIR + "logo_impact.ogg") as AudioStream
	_impact.volume_db = 0.0 if GameSettings.sound_enabled else -80.0
	add_child(_impact)
	_impact.play()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _process(delta: float) -> void:
	if _phase == Phase.CLOSED:
		return
	if _phase != Phase.HANDOFF:
		_update_hold(delta)
	if _phase in [Phase.LOGO, Phase.LOADING, Phase.READY]:
		_logo_clock += delta
		_logo.modulate.a = smoothstep(0.0, 0.65, _logo_clock)
		if _phase == Phase.LOGO and _logo_clock >= 0.7:
			_load_city()
		elif _phase == Phase.READY and (_logo_clock >= LOGO_HOLD or _skip_requested):
			if _skip_requested:
				_begin_handoff()
			else:
				_start_narration()
	elif _phase == Phase.NARRATION:
		# Both clips share the playlist's absolute audio clock.
		var audio_time := _narration.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		_speech_clock = clampf(maxf(_speech_clock, audio_time), 0.0, _duration)
		_update_narration()
	elif _phase == Phase.HANDOFF:
		_handoff_clock = minf(_handoff_clock + delta, HANDOFF_SECONDS)
		var amount := smoothstep(0.0, HANDOFF_SECONDS, _handoff_clock)
		_veil.color.a = _handoff_veil_alpha * (1.0 - amount)
		_logo.modulate.a = _handoff_logo_alpha * (1.0 - amount)
		_caption.modulate.a = _handoff_caption_alpha * (1.0 - amount)
		_hold_hint.modulate.a = _handoff_hint_alpha * (1.0 - amount)
		_camera.global_transform = _start_view.interpolate_with(_final_view, amount)
		_city.set_opening_mix(lerpf(_handoff_mix, 1.0, amount))
		_narration.volume_db = linear_to_db(maxf(1.0 - amount, 0.0001)) if GameSettings.sound_enabled else -80.0
		if _handoff_clock >= HANDOFF_SECONDS:
			_finish()

func _load_city() -> void:
	_phase = Phase.LOADING
	# Render the real logo before blocking single-threaded Web resource loading
	# and procedural city construction. There is no simulated loading progress.
	await get_tree().process_frame
	await get_tree().process_frame
	if _phase == Phase.CLOSED:
		return
	var packed := load(CITY_SCENE) as PackedScene
	await get_tree().process_frame
	await get_tree().process_frame
	if _phase == Phase.CLOSED:
		return
	_city = packed.instantiate()
	_city.opening_prepared = true
	# An opaque opening should not spend GPU time drawing the hidden city.
	_city.visible = false
	add_child(_city)
	_camera = Camera3D.new()
	_camera.fov = _city.player.camera.fov
	_camera.near = _city.player.camera.near
	_camera.far = _city.player.camera.far
	add_child(_camera)
	_final_view = _city.player.camera.global_transform
	_start_view = _final_view
	_start_view.origin.y += 0.65
	_start_view.basis = _start_view.basis * Basis(Vector3.RIGHT, deg_to_rad(-5.0))
	_camera.global_transform = _start_view
	_camera.make_current()
	_phase = Phase.READY

func _start_narration() -> void:
	if _phase != Phase.READY:
		return
	_phase = Phase.NARRATION
	_narration.volume_db = -80.0
	_narration.play()
	_update_narration()

func _update_narration() -> void:
	_logo.modulate.a = 1.0 - smoothstep(0.0, 0.8, _speech_clock)
	var reveal_start := maxf(0.0, _duration - 17.0)
	var reveal := smoothstep(reveal_start, maxf(reveal_start + 1.0, _duration - 4.0), _speech_clock)
	if reveal > 0.0 and not _city.visible:
		_city.show()
	_veil.color.a = lerpf(1.0, 0.16, reveal)
	var settle := smoothstep(maxf(0.0, _duration - 11.0), _duration, _speech_clock)
	_camera.global_transform = _start_view.interpolate_with(_final_view, settle)
	_city_mix = reveal * 0.12
	_city.set_opening_mix(_city_mix)
	_narration.volume_db = linear_to_db(maxf(smoothstep(0.0, 0.12, _speech_clock), 0.0001)) if GameSettings.sound_enabled else -80.0
	_update_caption()

func _update_caption() -> void:
	# Consume every crossed start, including phrases whose end was passed in a
	# slow frame. Speech gaps leave the already spoken paragraph on screen.
	while _cue_cursor < _cues.size() and _speech_clock >= float(_cues[_cue_cursor]["start"]):
		var phrase := str(_cues[_cue_cursor]["text"])
		var candidate := phrase if _caption.text.is_empty() else _caption.text + " " + phrase
		if _caption.text.is_empty() or _caption_line_count(candidate) > CAPTION_LINES:
			_caption_first_cue = _cue_cursor
			_caption_block_start = float(_cues[_cue_cursor]["start"])
			_caption.text = phrase
		else:
			_caption.text = candidate
		_cue_index = _cue_cursor
		_cue_cursor += 1
	_caption.visible = GameSettings.subtitles_enabled and _cue_index >= 0
	# Fade a fresh block only; appended phrases never dim completed text.
	_caption.modulate.a = smoothstep(0.0, CAPTION_FADE_SECONDS, _speech_clock - _caption_block_start)

func _caption_line_count(text_value: String) -> int:
	_caption_measure.clear()
	_caption_measure.width = _caption.size.x
	_caption_measure.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	_caption_measure.add_string(text_value, OpeningFont, _caption.get_theme_font_size("font_size"))
	return _caption_measure.get_line_count()

func _update_hold(delta: float) -> void:
	if _hold_key != KEY_NONE:
		if not _focused or not Input.is_key_pressed(_hold_key):
			_reset_hold()
		else:
			_hold_elapsed = minf(float(Time.get_ticks_msec() - _hold_started_msec) / 1000.0, HOLD_SECONDS)
			_hint_idle = 0.0
			if _hold_elapsed >= HOLD_SECONDS:
				_request_skip()
	if _phase == Phase.HANDOFF:
		return
	if _hint_revealed:
		_hint_idle += delta if _hold_key == KEY_NONE else 0.0
		var target := 0.7 if _hint_idle < HINT_IDLE_SECONDS or _hold_key != KEY_NONE else 0.0
		_hold_hint.modulate.a = move_toward(_hold_hint.modulate.a, target, delta * 2.5)
		_hold_hint.visible = _hold_hint.modulate.a > 0.0
	_hold_ring.queue_redraw()

func _reset_hold() -> void:
	_hold_key = KEY_NONE
	_hold_started_msec = -1
	_hold_elapsed = 0.0
	if is_instance_valid(_hold_ring):
		_hold_ring.queue_redraw()

func _reveal_hint() -> void:
	_hint_revealed = true
	_hint_idle = 0.0
	_hold_hint.show()

func _request_skip() -> void:
	# No button, Enter tap, gamepad accept, or other instant-skip path.
	if _hold_elapsed < HOLD_SECONDS or not _focused or _phase in [Phase.HANDOFF, Phase.CLOSED]:
		return
	_skip_requested = true
	if _phase in [Phase.NARRATION, Phase.READY]:
		_begin_handoff()

func _begin_handoff() -> void:
	if _phase in [Phase.HANDOFF, Phase.CLOSED] or _city == null:
		return
	_phase = Phase.HANDOFF
	_city.show()
	_start_view = _camera.global_transform
	_handoff_logo_alpha = _logo.modulate.a
	_handoff_caption_alpha = _caption.modulate.a
	_handoff_hint_alpha = _hold_hint.modulate.a
	_handoff_veil_alpha = _veil.color.a
	_handoff_mix = _city_mix
	_reset_hold()

func _finish() -> void:
	if _phase != Phase.HANDOFF:
		return
	_phase = Phase.CLOSED
	_reset_hold()
	_narration.stop()
	# Keep the built PackedScene instance, including its scene_file_path. A
	# subsequent city restart reloads the city directly, not this opening.
	_city.reparent(get_tree().root)
	get_tree().current_scene = _city
	_city.finish_opening()
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_reset_hold()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true

func _input(event: InputEvent) -> void:
	if _phase == Phase.CLOSED:
		return
	if event is InputEventKey:
		# Repeats neither restart a hold nor refresh hint inactivity.
		if not event.echo:
			if event.pressed and _phase != Phase.HANDOFF and _focused:
				_reveal_hint()
				if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _hold_key == KEY_NONE:
					_hold_key = event.keycode
					_hold_started_msec = Time.get_ticks_msec()
					_hold_elapsed = 0.0
			elif not event.pressed and event.keycode == _hold_key:
				_reset_hold()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch:
		if event.is_pressed() and _phase != Phase.HANDOFF and _focused:
			_reveal_hint()
		get_viewport().set_input_as_handled()

func _draw_hold_ring() -> void:
	var center := _hold_ring.size * 0.5
	var radius := minf(_hold_ring.size.x, _hold_ring.size.y) * 0.5 - 2.0
	_hold_ring.draw_arc(center, radius, -PI * 0.5, PI * 1.5, 48, Color(CREAM, 0.24), 1.5, true)
	if _hold_elapsed > 0.0:
		_hold_ring.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * (_hold_elapsed / HOLD_SECONDS), 48, CREAM, 2.0, true)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	_ui = Control.new()
	_ui.theme = InterfaceTheme
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_ui)
	_veil = ColorRect.new()
	_veil.color = Color("141413")
	_full_rect(_veil, _ui)
	_logo = TextureRect.new()
	_logo.texture = OpeningLogo
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_logo)
	_logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_logo.modulate.a = 0.0
	_caption = _center_label(_ui, "", -84, 84, 30)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_shadow_color", Color(0.03, 0.03, 0.025, 0.95))
	_caption.add_theme_constant_override("shadow_offset_x", 1)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	_caption.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.025, 0.8))
	_caption.add_theme_constant_override("outline_size", 3)
	_caption.hide()
	_hold_hint = Control.new()
	_ui.add_child(_hold_hint)
	_hold_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hold_hint.modulate.a = 0.0
	_hold_hint.hide()
	_hold_text = Label.new()
	_hold_hint.add_child(_hold_text)
	_hold_text.text = "Enter — удерживайте, чтобы пропустить"
	_hold_text.add_theme_font_override("font", OpeningFont)
	_hold_text.add_theme_font_size_override("font_size", 14)
	_hold_text.add_theme_color_override("font_color", CREAM)
	_hold_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hold_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_ring = Control.new()
	_hold_hint.add_child(_hold_ring)
	_hold_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_ring.draw.connect(_draw_hold_ring)
	_tape = ColorRect.new()
	_tape_material = ShaderMaterial.new()
	_tape_material.shader = TapeShader
	_tape_material.set_shader_parameter("noise_texture", preload("res://assets/textures/intro/tape_noise.png"))
	_tape.material = _tape_material
	_full_rect(_tape, _ui)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var logo_width := minf(viewport_size.x * 0.48, 640.0)
	var logo_height := logo_width * OpeningLogo.get_height() / OpeningLogo.get_width()
	logo_height = minf(logo_height, viewport_size.y * 0.58)
	_logo.offset_left = -logo_width * 0.5
	_logo.offset_right = logo_width * 0.5
	_logo.offset_top = -logo_height * 0.5
	_logo.offset_bottom = logo_height * 0.5
	var font_size := int(clampf(viewport_size.x * 0.028, 21.0, 32.0))
	_caption.add_theme_font_size_override("font_size", font_size)
	var caption_width := minf(viewport_size.x * 0.80, 1040.0)
	var caption_height := (OpeningFont.get_height(font_size) + _caption.get_theme_constant("line_spacing")) * CAPTION_LINES + 8.0
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.offset_left = -caption_width * 0.5
	_caption.offset_right = caption_width * 0.5
	_caption.offset_top = -caption_height * 0.5
	_caption.offset_bottom = caption_height * 0.5
	# Reflow only spoken cues after resize; keep the newest fitting block.
	if not _caption.text.is_empty():
		while _caption_first_cue < _cue_index and _caption_line_count(_caption.text) > CAPTION_LINES:
			_caption_first_cue += 1
			var phrases := PackedStringArray()
			for index in range(_caption_first_cue, _cue_index + 1):
				phrases.append(str(_cues[index]["text"]))
			_caption.text = " ".join(phrases)
	var hint_size := int(clampf(viewport_size.x * 0.016, 11.0, 14.0))
	_hold_text.add_theme_font_size_override("font_size", hint_size)
	var hint_width := OpeningFont.get_string_size(_hold_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, hint_size).x + 40.0
	_hold_hint.offset_left = -hint_width * 0.5
	_hold_hint.offset_right = hint_width * 0.5
	_hold_hint.offset_top = -64.0
	_hold_hint.offset_bottom = -32.0
	_hold_ring.position = Vector2(2.0, 4.0)
	_hold_ring.size = Vector2(24.0, 24.0)
	_hold_text.position = Vector2(36.0, 0.0)
	_hold_text.size = Vector2(hint_width - 36.0, 32.0)
	_hold_ring.queue_redraw()

func _full_rect(rect: Control, parent: Control) -> void:
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _center_label(parent: Control, text_value: String, top: float, bottom: float, size: int) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.anchor_left = 0.05
	label.anchor_right = 0.95
	label.offset_left = 0
	label.offset_right = 0
	label.offset_top = top
	label.offset_bottom = bottom
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_font_override("font", OpeningFont)
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

