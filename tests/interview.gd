extends SceneTree

const Progress := preload("res://scripts/interview/progress.gd")
const Questions := preload("res://scripts/interview/questions.gd")
const Interview := preload("res://scenes/interview.tscn")
const Assessment := preload("res://scripts/interview/assessment.gd")
const Voices := preload("res://scripts/core/dialogue_voices.gd")
const PHOTOGRAPH := preload("res://assets/textures/interview/interview-room.png")

var _failed := false
var _finishes := 0


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	_check_assessments()
	var original_sound := GameSettings.sound_enabled
	GameSettings.set_sound_enabled(true)
	var screen = Interview.instantiate()
	screen.finished.connect(func(): _finishes += 1)
	root.add_child(screen)
	screen.set_process(false)
	var progress = screen.progress
	_expect(screen._index == 0 and progress.answers.is_empty() and progress.assessments.is_empty() and not progress.completed, "New launch inherits previous interview state")
	_expect(progress.record_answer(-1) == ERR_INVALID_PARAMETER and progress.answers.is_empty(), "Invalid answer consumes a question")
	_expect(progress.finish() == ERR_UNAVAILABLE, "Partial interview is marked complete")
	screen._process(0.6)
	for index in Questions.ITEMS.size():
		_expect(screen._index == index and screen._phase == screen.Phase.QUESTION, "Question sequence skips a step")
		if index == 0:
			_expect(screen._room.volume_db < -19.0, "Background is not ducked during speech")
			_check_suspension(screen)
			var remaining: float = screen._voice_remaining
			screen._toggle_sound(false)
			screen._process(0.05)
			_expect(screen._voice.volume_db <= -80.0 and not screen._voice.stream_paused and screen._voice_remaining < remaining, "Mute suspends speech instead of advancing silently")
			screen._toggle_sound(true)
			_expect(screen._voice_remaining < remaining and screen._voice.volume_db > -80.0, "Unmute replays speech")
		elif index == 2:
			screen._answer(0)
			_expect(progress.answers.size() == index, "Held accept key selects the next question")
			var release := InputEventKey.new()
			release.keycode = KEY_ENTER
			release.pressed = false
			screen._input(release)
		# Answering is a manual skip, even while the question is still speaking.
		screen._answer(index % 3)
		screen._answer(0)
		_expect(progress.answers.size() == index + 1, "Rapid second click records a duplicate answer")
		_expect(not screen._voice.playing and screen._voice_remaining == 0.0, "Answer does not cancel the spoken question")
		screen._process(0.2)
		screen._process(Voices.TERMINAL.answer_recorded.get_length() - 0.01)
		_expect(screen._phase == screen.Phase.RECORDED, "Recorded answer is superseded before its speech finishes")
		screen._process(20.0)
		if screen._phase == screen.Phase.ASSESSMENT:
			screen._assessment.set_process(false)
			if screen._assessment_id == "frames":
				_expect(progress.record_answer(0) == ERR_UNAVAILABLE, "Required assessment can be bypassed by answering")
				_expect(progress.record_assessment("alignment", "completed") == ERR_INVALID_PARAMETER, "Out-of-order assessment is accepted")
				screen._assessment._select_frame((screen._assessment._different_frame + 1) % 6)
				var retry_length: float = Voices.TERMINAL.frames_retry.get_length()
				_expect(screen._assessment._feedback_seconds >= retry_length + 0.15, "Wrong-frame feedback is shorter than its spoken retry")
				screen._assessment._process(1.6)
				screen._process(1.6)
				_expect(not screen._assessment._feedback.text.is_empty(), "Wrong-frame feedback disappears during retry speech")
				_check_suspension(screen)
				screen._assessment._process(0.01)
				# Skip remains available before the retry clip finishes.
				screen._assessment._finish("skipped")
				_expect(progress.assessments.get("frames") == "skipped", "Assessment refusal is not preserved")
			else:
				# Solving remains available before the instruction clip finishes.
				screen._assessment._slider.value = screen._assessment._alignment_target
				screen._assessment._process(0.5)
				_expect(progress.assessments.get("alignment") == "completed", "Speech blocks manual assessment completion")
			screen._process(Voices.TERMINAL.result_recorded.get_length() - 0.01)
			_expect(screen._phase == screen.Phase.ASSESSMENT_RECORDED, "Assessment result is superseded before its speech finishes")
			screen._process(20.0)
		if index < Questions.ITEMS.size() - 1:
			if index == 1:
				screen._accept_held = true
			screen._process(0.3)
			screen._process(0.6)
	_expect(progress.completed and _finishes == 0 and screen._phase == screen.Phase.ENDING, "Final answer returns before the closing message")
	var closing_hold: float = maxf(screen.END_SECONDS, Voices.TERMINAL.complete.get_length() + 0.15)
	screen._process(closing_hold - 0.01)
	_expect(_finishes == 0, "Closing speech is cut short by the old ending delay")
	_check_suspension(screen)
	screen._toggle_sound(false)
	screen._process(0.02)
	_expect(_finishes == 1 and not screen._voice.playing, "Muted closing does not return control after its logical audio boundary")
	screen._process(20.0)
	screen._return()
	_expect(_finishes == 1 and not screen._voice.playing, "Completion signal or closing narration repeats")
	# Every new screen starts a new run, even after a completed interview.
	var fresh = Interview.instantiate()
	root.add_child(fresh)
	fresh.set_process(false)
	fresh._process(0.6)
	_expect(fresh._index == 0 and fresh._phase == fresh.Phase.QUESTION and fresh.progress.answers.is_empty() and fresh.progress.assessments.is_empty() and not fresh.progress.completed, "Completed interview leaks into a new launch")
	fresh._answer(2)
	progress.restart()
	_expect(fresh.progress.answers == PackedInt32Array([2]) and progress.answers.is_empty() and progress.assessments.is_empty() and not progress.completed, "Two interview runs share choices")
	fresh._pause()
	fresh._restart()
	fresh._process(0.6)
	_expect(fresh._index == 0 and fresh._phase == fresh.Phase.QUESTION and fresh.progress.answers.is_empty(), "Restart keeps answers or skips first question")
	root.remove_child(fresh)
	_expect(not fresh._voice.playing, "Scene exit leaves terminal speech playing")
	fresh.free()
	# Logical clocks above are accelerated; allow actual mixer voices to drain.
	screen._stop_voice()
	screen._carriage.stop()
	await create_timer(screen.CARRIAGE.get_length() + 0.15).timeout
	screen.free()
	GameSettings.set_sound_enabled(original_sound)
	await create_timer(0.1).timeout
	if _failed:
		quit(1)
	else:
		print("INTERVIEW_PASS: fresh launch, in-memory isolation, manual skips, retry feedback, pause, focus, mute, held-key boundary, full sequence, closing boundary and restart")
		quit(0)


func _check_suspension(screen: Control) -> void:
	var phase_clock: float = screen._phase_clock
	var remaining: float = screen._voice_remaining
	var stream: AudioStream = screen._voice.stream
	var feedback := 0.0
	if is_instance_valid(screen._assessment):
		feedback = screen._assessment._feedback_seconds
	screen._pause()
	screen._process(20.0)
	if is_instance_valid(screen._assessment):
		screen._assessment._process(20.0)
		_expect(screen._assessment._feedback_seconds == feedback, "Pause expires spoken feedback")
	_expect(screen._phase_clock == phase_clock and screen._voice_remaining == remaining and screen._voice.stream_paused and (not screen._carriage.playing or screen._carriage.stream_paused), "Pause advances interview clocks or active speech")
	screen._resume()
	_expect(not screen._voice.stream_paused and screen._voice.stream == stream and screen._voice_remaining == remaining, "Resume replays speech")
	screen._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	screen._process(20.0)
	if is_instance_valid(screen._assessment):
		screen._assessment._process(20.0)
		_expect(screen._assessment._feedback_seconds == feedback, "Focus loss expires spoken feedback")
	_expect(screen._phase_clock == phase_clock and screen._voice_remaining == remaining and screen._voice.stream_paused, "Background window advances interview or plays speech")
	screen._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(not screen._voice.stream_paused and screen._voice.stream == stream and screen._voice_remaining == remaining, "Focus return replays speech")


func _check_assessments() -> void:
	var results: Array[String] = []
	var frames = Assessment.new()
	frames.configure("frames", PHOTOGRAPH)
	frames.resolved.connect(func(result: String): results.append(result))
	root.add_child(frames)
	frames.set_process(false)
	frames._select_frame((frames._different_frame + 1) % 6)
	_expect(results.is_empty(), "Wrong photograph finishes the assessment")
	frames.set_suspended(true)
	frames._select_frame(frames._different_frame)
	_expect(results.is_empty(), "Paused photograph accepts input")
	frames.set_suspended(false)
	frames._process(0.01)
	frames._select_frame(frames._different_frame)
	frames._finish("skipped")
	_expect(results == ["completed"], "Photograph emits repeated or incorrect result")
	frames.free()
	results.clear()
	var alignment = Assessment.new()
	alignment.configure("alignment", PHOTOGRAPH)
	alignment.resolved.connect(func(result: String): results.append(result))
	root.add_child(alignment)
	alignment.set_process(false)
	alignment._slider.value = alignment._alignment_target
	alignment._process(0.2)
	alignment.set_suspended(true)
	alignment._process(2.0)
	_expect(results.is_empty(), "Paused alignment completes its hold")
	alignment.set_suspended(false)
	alignment._process(0.01)
	alignment._slider.value = alignment._alignment_target + 2.0
	alignment._process(0.3)
	_expect(results.is_empty(), "Misaligned print passes")
	alignment._slider.value = alignment._alignment_target
	alignment._process(0.3)
	_expect(results.is_empty(), "Alignment preserves dwell across a mismatch")
	alignment._process(0.2)
	alignment._finish("skipped")
	_expect(results == ["completed"], "Aligned print fails or emits twice")
	alignment.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
