class_name GameSettings
extends RefCounted

# Настройки текущего запуска; сохраняются при переходах между сценами.
static var sound_enabled := true
static var subtitles_enabled := true
static var gamma := 1.0
static var _gamma_overlay: ColorRect


static func set_sound_enabled(value: bool) -> void:
	if sound_enabled == value:
		return
	sound_enabled = value


static func set_subtitles_enabled(value: bool) -> void:
	subtitles_enabled = value


static func set_gamma(value: float) -> void:
	gamma = clampf(value, 0.6, 1.6)
	_apply_gamma()


# DisplaySettings registers once; updates happen only when the setting changes.
static func register_gamma_overlay(overlay: ColorRect) -> void:
	_gamma_overlay = overlay
	_apply_gamma()


static func _apply_gamma() -> void:
	if not is_instance_valid(_gamma_overlay):
		return
	var material := _gamma_overlay.material as ShaderMaterial
	material.set_shader_parameter("gamma", gamma)
	# Bypass screen sampling entirely at neutral gamma to preserve exact colors.
	_gamma_overlay.visible = gamma != 1.0