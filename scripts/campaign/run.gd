extends Node

signal changed

const CATALOG_PATH := "res://assets/campaign/module_catalog.json"
const REVIEW_CHOICES := ["Принять", "Нужна доработка", "Независимая проверка", "Недостаточно данных"]
var day := 1
var location := "lab"
var campaign_started := false
var reports: Array[Dictionary] = []
var catalog: Array = []
var calibration_done := false
var gate_repaired := false
var gate_event_started := false
var shared_notes := false
var day_briefed := false
var incident_started := false
var ending := ""
var last_module := ""
var home_evening := true
var messages: Array[Dictionary] = []

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		catalog = parsed.get("modules", [])
		# JSON numbers are floats; Array membership distinguishes them from ints.
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
	calibration_done = false
	gate_repaired = false
	gate_event_started = false
	shared_notes = false
	day_briefed = false
	incident_started = false
	ending = ""
	last_module = ""
	home_evening = true
	messages.clear()
	changed.emit()

func module_info(id: String) -> Dictionary:
	for entry: Dictionary in catalog:
		if entry.id == id:
			return entry
	return {}

func available(id: String) -> bool:
	var info := module_info(id)
	return not info.is_empty() and day in info.days and not incident_started

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
	var ids := completed_ids()
	if day == 1:
		return "calibration" in ids and "terrarium" in ids
	if day == 2:
		var choices := 0
		for id in ["drift", "tidebloom", "tidebreak", "hanafubuki", "pagoda"]:
			if id in ids:
				choices += 1
		return "dustfall" in ids and choices >= 2
	var other := false
	for report in day_reports():
		if report.module in ["fogline", "trenchcam", "voidbound", "voidrunner"]:
			other = true
		elif report.module != "deadparade":
			for old in reports:
				if old.day < 3 and old.module == report.module and old.recommendation != 0:
					other = true
	return "deadparade" in ids and other

func quota_text() -> String:
	var ids := completed_ids()
	if day == 1:
		return "Практическая проба + Terrarium · %d/2" % int(int("calibration" in ids) + int("terrarium" in ids))
	if day == 2:
		var count := 0
		for id in ["drift", "tidebloom", "tidebreak", "hanafubuki", "pagoda"]:
			count += int(id in ids)
		return "DUSTFALL: %s · свободная выборка: %d/2" % ["готово" if "dustfall" in ids else "ожидается", mini(count, 2)]
	return "DEAD PARADE + другой боевой стенд / повтор замечания"

func save_report(module_id: String, checked: String, observation: String, recommendation: int, sample: Dictionary) -> Dictionary:
	var info := module_info(module_id)
	if not available(module_id) or info.is_empty() or checked.is_empty() or observation.is_empty() or recommendation < 0 or recommendation >= REVIEW_CHOICES.size():
		return {}
	var report := {"number": reports.size() + 1, "day": day, "module": module_id, "title": info.title, "checked": checked, "observation": observation, "recommendation": recommendation, "sample": sample.duplicate(true), "reviewed": recommendation == 2, "status": "Запрошено независимое мнение" if recommendation == 2 else "Зарегистрировано"}
	reports.append(report)
	last_module = module_id
	if module_id == "calibration":
		calibration_done = true
	if recommendation == 2:
		messages.append({"sender": "Ника Орлова", "subject": "Повтор · " + str(info.title), "body": "Возьму независимую проверку. Твой отчёт останется отдельным документом; результаты не объединяем. В служебном секторе буду после обеда."})
	elif recommendation == 1 or recommendation == 3:
		messages.append({"sender": "Елена Бессонова", "subject": "Принято к рассмотрению · " + str(info.title), "body": "Вывод сохранён без изменений. Производственный допуск подписываю отдельно; ответственность за выпуск — моя. Укажи воспроизводимое действие, если вернёшься к этому стенду."})
	changed.emit()
	return report

func has_contact() -> bool:
	if shared_notes:
		return true
	for report in reports:
		if report.reviewed:
			return true
	return false

func sign_release() -> void:
	for report in day_reports():
		if report.recommendation == 0:
			report.status = "Контрольная выборка принята · подпись Е. Бессоновой"
		else:
			report.status = "Замечание сохранено · выпуск с отдельной подписью Е. Бессоновой"
	messages.append({"sender": "Артём Королёв", "subject": "Проход на испытательный этаж", "body": "Небольшой сбой: контроллер считает шлюз закрытым даже после команды открытия. Если выход не откроется, найди местный привод у стеклянной перегородки. Сетевую индикацию не используй как единственную проверку."})
	changed.emit()

func go_home() -> void:
	location = "home"
	home_evening = true
	changed.emit()

func sleep() -> void:
	if location != "home" or not home_evening or day >= 3:
		return
	day += 1
	home_evening = false
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
	messages.append({"sender": "Ника Орлова", "subject": "Копия получена", "body": "Спасибо. Сохранила отдельно от выпуска. У меня есть доступ к технической части этажа: если понадобится независимое подтверждение, пиши напрямую."})
	changed.emit()

func start_incident() -> void:
	incident_started = true
	location = "service"
	changed.emit()

func complete(id: String) -> void:
	ending = id
	changed.emit()
