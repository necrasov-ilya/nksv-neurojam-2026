extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var original_sound := GameSettings.sound_enabled
	var original_subtitles := GameSettings.subtitles_enabled
	GameSettings.set_sound_enabled(true)
	GameSettings.set_subtitles_enabled(true)
	var game = load("res://scenes/intro.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await _check_pause_physics(game)
	game.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	var extras = game.street_extras
	# Physical reach and gaze matter; optional props must not be remote hotkeys.
	for action in game.city.street_anchors:
		_look_at_action(game, action)
		_expect(game._find_action() == action, "Reachable street interaction missing: " + action)
		game.player.position.x += 8.0
		_expect(game._find_action() != action, "Street action is usable from too far away: " + action)
	_look_at_action(game, "street_bus")
	game._perform_action("street_bus")
	_expect(game.player.enabled and not game._dialogue_panel.visible, "Driver conversation locks movement")
	_expect(game._subtitle_panel.visible, "Driver speech is not visible with subtitles enabled")
	extras.tick(0.5, game.player.position, true, false)
	var line: String = game._subtitle_label.text
	extras.tick(30.0, game.player.position, true, true)
	_expect(game._subtitle_label.text == line, "Pause advances the street conversation")
	game._perform_action("street_bus")
	_expect(game._subtitle_label.text == line, "Repeated E restarts or skips active speech")
	extras.tick(extras._speech_remaining, game.player.position, true, false)
	var driver_line: String = extras.current_speech
	var voice_length: float = game._voice_player.stream.get_length()
	_expect(game._voice_player.playing, "Driver voice never starts")
	game._on_sound_toggled(false)
	var remaining: float = extras._speech_remaining
	game._process(0.25)
	_expect(extras._speech_remaining < remaining and not game._voice_player.stream_paused, "Muting freezes the street voice timeline")
	game._on_sound_toggled(true)
	var pause_event := InputEventAction.new()
	pause_event.action = "ui_cancel"
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	remaining = extras._speech_remaining
	var subtitle_remaining: float = game._subtitle_remaining
	game._process(20.0)
	_expect(extras._speech_remaining == remaining and game._subtitle_remaining == subtitle_remaining and game._voice_player.stream_paused, "Pause does not freeze both speech clocks and voice")
	game._resume()
	_expect(not game._voice_player.stream_paused and extras.current_speech == driver_line, "Resume restarts or loses the driver line")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._process(20.0)
	_expect(extras._speech_remaining == remaining and game._subtitle_remaining == subtitle_remaining and game._voice_player.stream_paused, "Focus loss does not freeze speech clocks and voice")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(not game._voice_player.stream_paused and extras.current_speech == driver_line, "Focus return loses the current voice")
	# Elapsed game time is still before the clip ends, even when its old text
	# duration would have advanced the queue.
	extras.tick(maxf(0.0, voice_length - 0.35), game.player.position, true, false)
	_expect(extras.current_speech == driver_line, "Driver line advances before its generated voice ends")
	extras.tick(0.3, game.player.position, true, false)
	_expect(extras.current_speech != driver_line, "Driver conversation fails to advance after the full voice hold")
	game.player.position.x += 12.0
	extras.tick(0.1, game.player.position, true, false)
	_expect(extras.current_speech.is_empty() and not game._subtitle_panel.visible, "Distant speech follows the player")
	_expect(not game._voice_player.playing, "Distance cancellation leaves a stale street voice")
	_look_at_action(game, "street_cafe")
	game._perform_action("street_cafe")
	line = game._subtitle_label.text
	extras.tick(extras._speech_remaining + 0.01, game.player.position, true, false)
	_expect(game._subtitle_label.text != line, "Cafe conversation never advances to the other patron")
	extras.cancel()
	# Button replies saturate, then reset for a later visit; holding E cannot cycle them.
	_look_at_action(game, "street_crossing")
	var near_control: Dictionary = game.city.street_crossings["street_crossing"]
	var far_control: Dictionary = game.city.street_crossings["street_crossing_far"]
	var idle: String = near_control["display"].text
	var replies: Array[String] = []
	for i in 4:
		game._perform_action("street_crossing")
		replies.append(near_control["display"].text)
		extras.tick(0.5, game.player.position, true, false)
	_expect(replies[0] != idle and replies[0] != replies[1] and replies[1] != replies[2], "Repeated pedestrian-button presses lack distinct responses")
	_expect(replies[2] == replies[3], "Button reply does not saturate")
	extras.tick(13.0, game.player.position, true, false)
	_expect(near_control["display"].text == idle, "Button never resets for a later visit")
	# Both approaches share the request, but only the pressed button moves.
	_look_at_action(game, "street_crossing_far")
	game._perform_action("street_crossing_far")
	_expect(far_control["display"].text != idle and near_control["display"].text == far_control["display"].text, "Opposite approach does not share the crossing request")
	_expect(near_control["lamp"].visible and far_control["lamp"].visible, "Crossing request is not indicated on both approaches")
	extras.tick(0.05, game.player.position, true, false)
	_expect(far_control["button"].position.z < far_control["rest"].z and near_control["button"].position == near_control["rest"], "Press moves the wrong approach's button")
	var pressed_position: Vector3 = far_control["button"].position
	extras.tick(2.0, game.player.position, true, true)
	_expect(far_control["button"].position == pressed_position, "Pause advances the opposite button animation")
	extras.tick(13.0, game.player.position, true, false)
	_expect(far_control["display"].text == idle and near_control["display"].text == idle and not far_control["lamp"].visible and not near_control["lamp"].visible, "Paired crossing request does not reset together")
	# World displays keep working with sound and subtitles independently disabled.
	game._on_sound_toggled(false)
	game._on_subtitles_toggled(false)
	_look_at_action(game, "street_ad")
	var original_ad: String = game.city.street_ad_display.text
	for i in 4:
		var previous_ad: String = game.city.street_ad_display.text
		game._perform_action("street_ad")
		var selected_ad: String = game.city.street_ad_display.text
		game._perform_action("street_ad")
		_expect(game.city.street_ad_display.text == selected_ad, "Rapid E skips multiple advertisement pages")
		await create_timer(0.4).timeout
		extras.tick(0.5, game.player.position, true, false)
		_expect(game.city.street_ad_display.text != previous_ad, "Advertising button does not change the physical display")
	_expect(game.city.street_ad_display.text == original_ad, "Ad sequence does not return to its first page")
	_expect(not game._subtitle_panel.visible, "Street interaction ignores disabled subtitles")
	for effect in game.audio._effects:
		_expect(not effect.playing, "Street button ignores the sound-off setting")
	game.player.position.x += 3.6
	game.player.camera.look_at(game._interaction_points["street"]["street_ad"])
	_expect(game._find_action() != "street_ad", "Advertisement activates through its backing")
	# A street queue cannot overwrite the mandatory receptionist after entering the lobby.
	game._on_subtitles_toggled(true)
	_look_at_action(game, "street_cafe")
	game._perform_action("street_cafe")
	game._set_location("lobby", game.lobby.to_global(Vector3(0, 0.03, 11)), 0)
	game._start_dialogue()
	_expect(extras.current_speech.is_empty() and game._voice_player.playing, "Reception ownership loses the hero voice or retains a street queue")
	line = game._subtitle_label.text
	extras.tick(30.0, game.player.position, false, false)
	_expect(game._subtitle_label.text == line and game._dialogue_panel.visible, "Old street speech overwrites reception")
	game._advance_dialogue()
	_expect(game._voice_player.playing, "Reception voice does not play")
	game._advance_dialogue()
	_expect(not game._voice_player.playing and not game._dialogue_panel.visible, "Reception skip leaves its voice playing")
	await _check_office_entry(game)
	game._on_sound_toggled(original_sound)
	game._on_subtitles_toggled(original_subtitles)
	game.audio.set_muted(true)
	game.free()
	# Let the audio mixer release the stopped streams before process shutdown.
	await create_timer(0.15).timeout
	if _failed:
		quit(1)
	else:
		print("INTRO_STREET_PASS: pause freezes player physics, resume restores grounded movement, local reach, replay protection, distance cancellation, paired crossing request/reset, ad cycle, reception ownership and closed-door interview entry")
		quit(0)

func _check_pause_physics(game) -> void:
	for tick in 20:
		await physics_frame
	var standing_position: Vector3 = game.player.global_position
	var standing_velocity: Vector3 = game.player.velocity
	var pause_event := InputEventAction.new()
	pause_event.action = "ui_cancel"
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	Input.action_press("intro_forward")
	# Returning focus must not resume physics while the settings menu is open.
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._on_sound_toggled(false)
	game._on_subtitles_toggled(false)
	for tick in 60:
		await physics_frame
	Input.action_release("intro_forward")
	_expect(game.player.global_position == standing_position and game.player.velocity == standing_velocity, "ESC settings or returning focus move the paused player")
	game._unhandled_input(pause_event)
	Input.action_press("intro_forward")
	for tick in 12:
		await physics_frame
	Input.action_release("intro_forward")
	_expect(game.player.is_on_floor() and game.player.global_position.distance_to(standing_position) > 0.25 and absf(game.player.global_position.y - standing_position.y) < 0.01, "Closing ESC menu does not restore grounded movement")
	game.player.place(standing_position, 0)
	game._on_sound_toggled(true)
	game._on_subtitles_toggled(true)

func _check_office_entry(game) -> void:
	game._set_location("office", game.office.to_global(Vector3(5.5, 0.03, -14)), 0)
	game.door_open = true
	game.office.office_door.rotation.y = PI / 2
	game._perform_action("door")
	var computer: Vector3 = game._interaction_points["office"]["computer"]
	game.player.camera.look_at(computer)
	_expect(game._find_action() != "computer", "Computer is usable from the office entrance")
	game.player.place(game.office.to_global(Vector3(10, 0.03, -16.5)), 0)
	game.player.camera.look_at(game.player.camera.global_position + Vector3.BACK)
	_expect(game._find_action() != "computer", "Computer activates while looking away")
	game.player.camera.look_at(computer)
	game._process(0.0)
	_expect(game._find_action() == "computer" and game._prompt.visible, "Closing the office door hides computer interaction")
	if game._find_action() != "computer":
		return
	var use := InputEventAction.new()
	use.action = "intro_use"
	use.pressed = true
	game._unhandled_input(use)
	await create_timer(0.75).timeout
	_expect(game._interview_layer != null, "E at the computer does not open the interview")
	if game._interview_layer == null:
		return
	var screen = game._interview_layer.get_child(0)
	screen.set_process(false)
	screen._process(0.6)
	_expect(screen._answers[0].visible and not screen._answers[0].disabled, "Interview entry leaves answer controls unavailable")
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept.pressed = false
	Input.parse_input_event(accept)
	await process_frame
	_expect(screen.progress.answers.size() == 1, "Interview opened from a closed office cannot accept an answer")

func _look_at_action(game, action: String) -> void:
	var point: Vector3 = game._interaction_points["street"][action]
	var offset := Vector3(1.8 if action == "street_bus" else -1.8, 0, 0)
	if game.city.street_crossings.has(action):
		offset = (game.city.street_crossings[action]["button"] as Node3D).global_basis.z * 1.8
	var view := point + offset
	game.player.place(Vector3(view.x, 0.03, view.z), 0)
	game.player.camera.look_at(point)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
