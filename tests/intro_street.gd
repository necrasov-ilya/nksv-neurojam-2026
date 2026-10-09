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
	game.player.position.x += 12.0
	extras.tick(0.1, game.player.position, true, false)
	_expect(extras.current_speech.is_empty() and not game._subtitle_panel.visible, "Distant speech follows the player")
	_look_at_action(game, "street_cafe")
	game._perform_action("street_cafe")
	line = game._subtitle_label.text
	extras.tick(4.5, game.player.position, true, false)
	_expect(game._subtitle_label.text != line, "Cafe conversation never advances to the other patron")
	extras.cancel()
	# Button replies saturate, then reset for a later visit; holding E cannot cycle them.
	_look_at_action(game, "street_crossing")
	var idle: String = game.city.street_crossing_display.text
	var replies: Array[String] = []
	for i in 4:
		game._perform_action("street_crossing")
		replies.append(game.city.street_crossing_display.text)
		extras.tick(0.5, game.player.position, true, false)
	_expect(replies[0] != idle and replies[0] != replies[1] and replies[1] != replies[2], "Repeated pedestrian-button presses lack distinct responses")
	_expect(replies[2] == replies[3], "Button reply does not saturate")
	extras.tick(13.0, game.player.position, true, false)
	_expect(game.city.street_crossing_display.text == idle, "Button never resets for a later visit")
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
	line = game._subtitle_label.text
	extras.tick(30.0, game.player.position, false, false)
	_expect(game._subtitle_label.text == line and game._dialogue_panel.visible, "Old street speech overwrites reception")
	game._on_sound_toggled(original_sound)
	game._on_subtitles_toggled(original_subtitles)
	game.free()
	if _failed:
		quit(1)
	else:
		print("INTRO_STREET_PASS: local reach, pause, replay protection, distance cancellation, button reset, ad cycle, settings and reception ownership")
		quit(0)

func _look_at_action(game, action: String) -> void:
	var point: Vector3 = game._interaction_points["street"][action]
	var view := point + Vector3(1.8 if action == "street_bus" else -1.8, 0, 0)
	game.player.place(Vector3(view.x, 0.03, view.z), 0)
	game.player.camera.look_at(point)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
