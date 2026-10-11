extends SceneTree

const CampaignRun = preload("res://scripts/campaign/run.gd")
var GameRun: CampaignRun

var _failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _report(id: String, recommendation: int = 0) -> void:
	_expect(not GameRun.save_report(id, "Проверенное действие", "Наблюдение", recommendation, {}).is_empty(), "Available world rejects report: " + id)

func _check() -> void:
	GameRun = CampaignRun.new()
	root.add_child(GameRun)
	GameRun.new_run()
	_expect(GameRun.available("calibration") and GameRun.available("terrarium"), "First-day stands unavailable after JSON catalog load")
	_expect(not GameRun.available("dustfall"), "Second-day stand unlocked before second day")
	_expect(GameRun.save_report("dustfall", "Проверка", "Наблюдение", 0, {}).is_empty(), "Locked stand accepts report")
	_report("calibration")
	_expect(not GameRun.quota_ready(), "Calibration alone finishes first shift")
	_report("terrarium")
	_expect(GameRun.quota_ready(), "Complete first-day sample cannot finish shift")
	GameRun.sleep()
	_expect(GameRun.day == 1, "Sleeping outside apartment advances day")
	GameRun.go_home()
	GameRun.sleep()
	GameRun.sleep()
	_expect(GameRun.day == 2 and not GameRun.home_evening, "Repeated sleep skips a working day")
	GameRun.go_to_work()
	_report("dustfall")
	_report("drift", 1)
	_report("drift", 1)
	_expect(not GameRun.quota_ready(), "Duplicate world fulfills two distinct optional samples")
	_report("tidebloom", 2)
	_expect(GameRun.quota_ready() and GameRun.has_contact(), "Independent review does not open peer contact")
	var original_recommendation: int = GameRun.reports[3].recommendation
	GameRun.sign_release()
	_expect(GameRun.reports[3].recommendation == original_recommendation, "Supervisor signature overwrites player's recommendation")
	GameRun.go_home()
	GameRun.sleep()
	GameRun.go_to_work()
	_report("deadparade")
	_report("calibration")
	_expect(not GameRun.quota_ready(), "Accepted old stand counts as follow-up on a reported problem")
	_report("drift")
	_expect(GameRun.quota_ready(), "Repeat of earlier flagged stand cannot fulfill third-day follow-up")
	var count := GameRun.reports.size()
	GameRun.start_incident()
	_expect(not GameRun.available("deadparade"), "Campaign test selection remains open during incident")
	_expect(GameRun.save_report("deadparade", "Проверка", "Наблюдение", 0, {}).is_empty(), "Incident accepts a new work report")
	_expect(GameRun.reports.size() == count, "Rejected report changes history")
	GameRun.new_run()
	_expect(not GameRun.has_contact(), "New run inherits peer contact")
	GameRun.share_notes()
	_expect(GameRun.has_contact(), "Personal copy does not establish direct contact")
	GameRun.new_run()
	_expect(GameRun.day == 1 and GameRun.reports.is_empty() and not GameRun.shared_notes and not GameRun.incident_started and GameRun.ending.is_empty(), "New game inherits earlier campaign state")
	print("Campaign access, sample boundaries and report precedence: ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)
