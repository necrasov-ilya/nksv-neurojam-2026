class_name GameSettings
extends RefCounted

# Настройки, общие для всех сцен (статика переживает смену сцен).
# На веб-экспорте user:// не сохраняет данные, поэтому файл не пишем.
static var sound_enabled := true


static func set_sound_enabled(value: bool) -> void:
	if sound_enabled == value:
		return
	sound_enabled = value