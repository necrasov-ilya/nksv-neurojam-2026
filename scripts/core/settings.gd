class_name GameSettings
extends RefCounted

# Настройки текущего запуска; сохраняются при переходах между сценами.
static var sound_enabled := true
static var subtitles_enabled := true


static func set_sound_enabled(value: bool) -> void:
	if sound_enabled == value:
		return
	sound_enabled = value


static func set_subtitles_enabled(value: bool) -> void:
	subtitles_enabled = value