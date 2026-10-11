extends SceneTree

const CampaignRun = preload("res://scripts/campaign/run.gd")
var run: CampaignRun
var failed := false

func _initialize() -> void:
	check.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func no_data(case_day: int) -> Dictionary:
	return {"internal": true, "case_day": case_day, "seconds": 0, "events": [], "repeat": "Не проверено"}

func check() -> void:
	run = CampaignRun.new()
	root.add_child(run)
	run.remember_interview(PackedInt32Array([0, 1, 2, 0, 1, 1, 2, 0, 0, 2]), {"frames": "completed", "alignment": "skipped"})
	run.begin_interview_evening()
	expect(run.day == 0 and not run.quota_ready() and not run.available("object_state"), "Interview evening consumes a work shift")
	run.go_home()
	run.sleep()
	run.sleep()
	expect(run.day == 1 and not run.home_evening, "First night advances more than one shift")
	expect(run.interview_line("isolation") == "nika_together" and run.interview_line("communication") == "artem_reserve", "Interview consequences disappear across the commute")
	expect(not run.available("environment_memory") and not run.available("release_review"), "Later cases are available on the first day")
	expect(run.save_report("terrarium", "Свет", "Наблюдение", 0, {"seconds":14.999}).is_empty(), "External report bypasses the active 15-second boundary")
	var extra := run.save_report("terrarium", "Свет", "Наблюдение", 0, {"seconds":15})
	expect(extra.number == 1 and not run.quota_ready(), "Optional game replaces the mandatory case")
	expect(run.save_report("object_state", "Не проверял", "Нет данных", 0, no_data(1)).is_empty(), "No observations can be submitted as acceptance")
	expect(run.save_report("object_state", "Не проверял", "Нет данных", 3, no_data(2)).is_empty(), "Sample from another case fulfills the assignment")
	var own := run.save_report("object_state", "Не приступал", "Недостаточно наблюдений", 3, no_data(1))
	expect(own.number == 2 and run.quota_ready(), "Zero-second honest insufficient-data report cannot finish the local case")
	expect(not run.complete(), "First-day report opens the ending")
	expect(run.finish_shift() and not run.finish_shift(), "Shift can be signed twice")
	expect(own.recommendation == 3 and run.release_history[0].report_number == own.number, "Signature changes the player's recommendation or refers to another report")
	expect(not run.available("object_state") and run.save_report("terrarium", "Свет", "Наблюдение", 0, {"seconds":20}).is_empty(), "Closed work access accepts more reports")
	run.go_home()
	run.sleep()
	run.sleep()
	expect(run.day == 2 and not run.home_evening, "Repeated sleep skips a working day")
	run.go_to_work()
	expect(not run.finish_shift(), "Second shift closes without its own report")
	var sample := no_data(2)
	sample.events = [{"kind":"comparison", "condition":"Обычный сброс", "result":"Метка осталась", "author":"Игрок", "version":"2.0", "run":1}]
	sample.repeat = "Воспроизведено"
	var second := run.save_report("environment_memory", "Сброс", "Метка осталась", 2, sample)
	expect(second.peer.is_empty(), "Independent request invents a completed colleague result")
	sample.events[0].result = "Изменено снаружи"
	expect(second.sample.events[0].result == "Метка осталась", "Caller mutation rewrites saved evidence")
	expect(run.finish_shift(), "A request for independent review blocks the shift")
	run.go_home()
	run.sleep()
	run.go_to_work()
	run.save_report("object_state", "Не приступал", "Нет данных", 3, no_data(1))
	expect(not run.quota_ready() and not run.complete(), "Repeating an earlier case fulfills the third-day assignment")
	var third := run.save_report("release_review", "Не приступал", "Нет данных", 3, no_data(3))
	expect(third.number > second.number and run.quota_ready() and not run.complete(), "Ending opens before closing third-day work access")
	expect(run.finish_shift() and run.complete() and run.ending == "demo", "Honest insufficient-data route cannot reach the quiet ending")
	run.case_sessions.object_state = {"marked":true}
	run.peer_results.environment_memory = {"retained_after_reset":true}
	run.new_run()
	expect(run.day == 1 and run.reports.is_empty() and run.case_sessions.is_empty() and run.peer_results.is_empty() and run.release_history.is_empty() and run.interview_answers.is_empty() and run.ending.is_empty(), "New run inherits prior evidence, relationships or completion")
	run.queue_free()
	await process_frame
	print("CAMPAIGN_CASE_BOUNDARIES: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
