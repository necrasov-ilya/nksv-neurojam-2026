extends RefCounted

# Participant recordings and generated voices; playback uses normalized Ogg files.
const SPEAKERS := {
	"Вы": {
		"Этот автобус идёт до LATENT SYSTEMS?": preload("res://assets/audio/dialogue/hero/hero_bus_01.ogg"),
		"А до четырнадцатого этажа не довезёте?": preload("res://assets/audio/dialogue/hero/hero_bus_02.ogg"),
		"Здравствуйте. Я на собеседование.": preload("res://assets/audio/dialogue/hero/hero_reception_01.ogg"),
		"Сначала нужно обратиться к администратору.": preload("res://assets/audio/dialogue/hero/hero_lift_before_reception.ogg"),
		"Не, вроде как не сюда": preload("res://assets/audio/dialogue/hero/hero_wrong_floor.ogg"),
	},
	"Водитель": {
		"На собеседование? Тогда пешком. Мы тут тоже ждём, когда нас позовут.": preload("res://assets/audio/dialogue/driver/driver_01.ogg"),
		"Четырнадцатый этаж — не автобусная остановка. Дальше на лифте, без пересадок.": preload("res://assets/audio/dialogue/driver/driver_02.ogg"),
	},
	"Посетительница": {
		"Нейросеть придумала мне рецепт ужина.": preload("res://assets/audio/dialogue/cafe_female/cafe_female_01.ogg"),
		"Вкусно. Теперь прошу рецепт чистой посуды.": preload("res://assets/audio/dialogue/cafe_female/cafe_female_02.ogg"),
		"Попросила нейросеть упростить рецепт.": preload("res://assets/audio/dialogue/cafe_female/cafe_female_03.ogg"),
		"Нет, добавила ещё две кастрюли.": preload("res://assets/audio/dialogue/cafe_female/cafe_female_04.ogg"),
		"Нейросеть назвала мой ужин экспериментальным.": preload("res://assets/audio/dialogue/cafe_female/cafe_female_05.ogg"),
		"В рецепте об этом ни слова.": preload("res://assets/audio/dialogue/cafe_female/cafe_female_06.ogg"),
	},
	"Посетитель": {
		"И как?": preload("res://assets/audio/dialogue/cafe_male/cafe_male_01.ogg"),
		"Тут, боюсь, опять ручной труд.": preload("res://assets/audio/dialogue/cafe_male/cafe_male_02.ogg"),
		"Она убрала лишние ингредиенты?": preload("res://assets/audio/dialogue/cafe_male/cafe_male_03.ogg"),
		"Значит, посуду моет автор запроса.": preload("res://assets/audio/dialogue/cafe_male/cafe_male_04.ogg"),
		"А кто моет посуду после эксперимента?": preload("res://assets/audio/dialogue/cafe_male/cafe_male_05.ogg"),
		"Понятно. Опять мы — человеческая поддержка.": preload("res://assets/audio/dialogue/cafe_male/cafe_male_06.ogg"),
	},
	"Администратор": {
		"Доброе утро. Поднимитесь на четырнадцатый этаж. Кабинет 1406, направо по коридору.": preload("res://assets/audio/dialogue/receptionist/receptionist_01.ogg"),
	},
}

const TERMINAL := {
	"question_motivation": preload("res://assets/audio/dialogue/terminal/terminal_question_motivation.ogg"),
	"question_verification": preload("res://assets/audio/dialogue/terminal/terminal_question_verification.ogg"),
	"question_isolation": preload("res://assets/audio/dialogue/terminal/terminal_question_isolation.ogg"),
	"question_observation": preload("res://assets/audio/dialogue/terminal/terminal_question_observation.ogg"),
	"question_confidentiality": preload("res://assets/audio/dialogue/terminal/terminal_question_confidentiality.ogg"),
	"question_communication": preload("res://assets/audio/dialogue/terminal/terminal_question_communication.ogg"),
	"question_colleague": preload("res://assets/audio/dialogue/terminal/terminal_question_colleague.ogg"),
	"question_responsibility": preload("res://assets/audio/dialogue/terminal/terminal_question_responsibility.ogg"),
	"question_sacrifice": preload("res://assets/audio/dialogue/terminal/terminal_question_sacrifice.ogg"),
	"question_absence": preload("res://assets/audio/dialogue/terminal/terminal_question_absence.ogg"),
	"frames": preload("res://assets/audio/dialogue/terminal/terminal_frames.ogg"),
	"alignment": preload("res://assets/audio/dialogue/terminal/terminal_alignment.ogg"),
	"frames_retry": preload("res://assets/audio/dialogue/terminal/terminal_frames_retry.ogg"),
	"answer_recorded": preload("res://assets/audio/dialogue/terminal/terminal_answer_recorded.ogg"),
	"result_recorded": preload("res://assets/audio/dialogue/terminal/terminal_result_recorded.ogg"),
	"complete": preload("res://assets/audio/dialogue/terminal/terminal_complete.ogg"),
}

static func line(speaker: String, text: String) -> AudioStream:
	if not SPEAKERS.has(speaker):
		return null
	return SPEAKERS[speaker].get(text)
