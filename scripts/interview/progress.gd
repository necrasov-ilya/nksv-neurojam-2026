extends RefCounted

const Questions := preload("res://scripts/interview/questions.gd")
const ASSESSMENTS := [
	{"id": "frames", "after": 2},
	{"id": "alignment", "after": 6},
]

var answers := PackedInt32Array()
var assessments: Dictionary = {}
var completed := false


func record_answer(choice: int) -> Error:
	if completed or answers.size() >= Questions.ITEMS.size() or not pending_assessment().is_empty():
		return ERR_UNAVAILABLE
	if choice < 0 or choice >= Questions.ITEMS[answers.size()].answers.size():
		return ERR_INVALID_PARAMETER
	answers.append(choice)
	return OK


func pending_assessment() -> String:
	for task in ASSESSMENTS:
		if answers.size() >= task.after and not assessments.has(task.id):
			return task.id
	return ""


func record_assessment(id: String, result: String) -> Error:
	if id != pending_assessment() or result not in ["completed", "skipped"]:
		return ERR_INVALID_PARAMETER
	assessments[id] = result
	return OK


func finish() -> Error:
	if answers.size() != Questions.ITEMS.size() or not pending_assessment().is_empty():
		return ERR_UNAVAILABLE
	completed = true
	return OK


func restart() -> void:
	answers.clear()
	assessments.clear()
	completed = false

