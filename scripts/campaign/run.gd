extends Node

signal changed

const CATALOG_PATH := "res://assets/campaign/module_catalog.json"
const CASE_IDS := ["object_state", "environment_memory", "release_review"]
const REVIEW_CHOICES := ["Передать на приёмку", "Оставить на проверке", "Независимая проверка", "Недостаточно данных"]
const REPEAT_CHOICES := ["Воспроизведено", "Не воспроизведено", "Не проверено"]
var day := 1
var location := "lab"
var campaign_started := false
var reports: Array[Dictionary] = []
var catalog: Array = []
var shared_notes := false
var day_briefed := false
var ending := ""
var last_module := ""
var active_case := ""
var home_evening := true
var messages: Array[Dictionary] = []
var interview_answers: Dictionary = {}
var interview_assessments: Dictionary = {}
var dream_seen := false
var cafe_visited := false
var shift_released := false
var report_draft: Dictionary = {}
var tour_pending := false
var host_instruction_seen := false
var case_sessions: Dictionary = {}
var peer_results: Dictionary = {}
var release_history: Array[Dictionary] = []

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		catalog = parsed.get("modules", [])
		for entry: Dictionary in catalog:
			for index in entry.days.size():
				entry.days[index] = int(entry.days[index])
	else:
		push_error("Не удалось прочитать каталог кампании: " + CATALOG_PATH)
	new_run()

func new_run() -> void:
	day = 1
	location = "lab"
	campaign_started = false
	reports.clear()
	shared_notes = false
	day_briefed = false
	ending = ""
	last_module = ""
	active_case = ""
	home_evening = true
	messages.clear()
	interview_answers.clear()
	interview_assessments.clear()
	dream_seen = false
	cafe_visited = false
	shift_released = false
	report_draft.clear()
	tour_pending = false
	host_instruction_seen = false
	case_sessions.clear()
	peer_results.clear()
	release_history.clear()
	changed.emit()

func remember_interview(answers: PackedInt32Array, assessments: Dictionary) -> void:
	interview_answers.clear()
	var questions: Array = preload("res://scripts/interview/questions.gd").ITEMS
	for index in mini(answers.size(), questions.size()):
		interview_answers[questions[index].id] = answers[index]
	interview_assessments = assessments.duplicate(true)

func begin_interview_evening() -> void:
	day = 0
	location = "evening"
	campaign_started = true
	home_evening = true
	tour_pending = true
	changed.emit()

func interview_line(kind: String) -> String:
	var answer: int = interview_answers.get(kind, -1)
	if kind == "isolation":
		return ["nika_independent", "nika_online", "nika_together"][answer] if answer >= 0 and answer < 3 else ""
	if kind == "communication":
		return ["artem_stop", "artem_reserve", "artem_continue"][answer] if answer >= 0 and answer < 3 else ""
	return ""

func case_id() -> String:
	return CASE_IDS[day - 1] if day >= 1 and day <= 3 else ""

func module_info(id: String) -> Dictionary:
	for entry: Dictionary in catalog:
		if entry.id == id:
			return entry
	return {}

func available(id: String) -> bool:
	var info := module_info(id)
	return not info.is_empty() and day in info.days and not shift_released and ending.is_empty()

func day_reports() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for report in reports:
		if report.day == day:
			result.append(report)
	return result

func completed_ids() -> Array[String]:
	var result: Array[String] = []
	for report in day_reports():
		if report.module not in result:
			result.append(report.module)
	return result

func quota_ready() -> bool:
	return not case_id().is_empty() and case_id() in completed_ids()

func quota_text() -> String:
	if day == 0:
		return "Завтра в 09:00 / практическая часть"
	return "%s · отчёт %s/1" % [module_info(case_id()).get("title", ""), "1" if quota_ready() else "0"]

func save_report(module_id: String, checked: String, observation: String, recommendation: int, sample: Dictionary) -> Dictionary:
	var info := module_info(module_id)
	if not available(module_id) or checked.is_empty() or observation.is_empty() or recommendation < 0 or recommendation >= REVIEW_CHOICES.size():
		return {}
	var own: bool = info.kind == "internal"
	if own:
		if not sample.get("internal", false) or int(sample.get("case_day", 0)) != int(info.case_day) or sample.get("repeat", "") not in REPEAT_CHOICES:
			return {}
		var observed := false
		for event: Dictionary in sample.get("events", []):
			if event.get("kind", "") in ["observation", "comparison"]:
				observed = true
		if not observed and (recommendation != 3 or sample.repeat != "Не проверено"):
			return {}
	elif float(sample.get("seconds", 0)) < 15 or sample.get("status", "complete") != "complete":
		return {}
	var statuses := ["Передан на приёмку", "Оставлен на проверке", "Ожидает независимой проверки", "Недостаточно данных"]
	var report := {"number": reports.size() + 1, "day": day, "module": module_id, "title": info.title, "checked": checked, "observation": observation, "recommendation": recommendation, "sample": sample.duplicate(true), "status": statuses[recommendation], "peer": peer_results.get(module_id, {}).duplicate(true)}
	report_draft.clear()
	reports.append(report)
	last_module = module_id
	if recommendation == 2:
		messages.append({"sender": "Ника Орлова", "subject": "Отдельная проверка · " + str(info.title), "body": "Запрос зарегистрирован, не подтверждён. Для памяти среды пригласи Артёма на локальный стенд: его результат останется отдельным от твоего. Для других сред ответ ещё не получен."})
	elif recommendation in [1, 3]:
		messages.append({"sender": "Елена Бессонова", "subject": "Вывод сохранён · " + str(info.title), "body": "Твой вывод не исправляем. Замечание остаётся открытым; недостаток данных не превращаем в принятие. Решение о выпуске будет записано отдельно."})
	changed.emit()
	return report

func record_peer_result(module_id: String, result: Dictionary) -> void:
	peer_results[module_id] = result.duplicate(true)
	for report in reports:
		if report.module == module_id:
			report.peer = result.duplicate(true)
			if report.recommendation == 2:
				report.status = "Независимый результат получен · вывод игрока сохранён"
	messages.append({"sender": str(result.author), "subject": "Отдельный результат / версия " + str(result.version), "body": str(result.result)})
	changed.emit()

func finish_shift() -> bool:
	if not quota_ready() or shift_released:
		return false
	var selected: Dictionary = {}
	for report in day_reports():
		if report.module == case_id():
			selected = report
	var decision := "Передано на приёмку" if selected.recommendation == 0 else "Доработка требуется" if selected.recommendation == 1 else "Независимая проверка / решение отложено" if selected.recommendation == 2 else "Данных недостаточно / выпуск не подтверждён"
	release_history.append({"day": day, "case": case_id(), "report_number": selected.number, "decision": decision, "signature": "Е. Бессонова"})
	shift_released = true
	changed.emit()
	return true

func go_home() -> void:
	if day > 0 and not shift_released:
		return
	location = "home"
	home_evening = true
	changed.emit()

func sleep() -> void:
	if location != "home" or not home_evening or day >= 3 or (day > 0 and not shift_released):
		return
	day += 1
	home_evening = false
	shift_released = false
	cafe_visited = false
	day_briefed = false
	changed.emit()

func go_to_work() -> void:
	if location != "home" or home_evening:
		return
	location = "lab"
	changed.emit()

func share_notes() -> void:
	if shared_notes:
		return
	shared_notes = true
	messages.append({"sender": "Ника Орлова", "subject": "Копия получена", "body": "Сохранила отдельно от приёмки. Это твои наблюдения; решение руководителя не заменит исходные записи."})
	changed.emit()

func complete() -> bool:
	if day != 3 or not quota_ready() or not shift_released:
		return false
	ending = "demo"
	changed.emit()
	return true
