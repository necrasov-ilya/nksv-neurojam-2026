class_name DebugHud
extends CanvasLayer

signal start_requested
signal pause_requested
signal seed_requested
signal pulse_requested
signal mute_requested(value: bool)

var phase_label: Label
var seed_label: Label
var start_button: Button
var pause_button: Button
var mute_button: CheckButton


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "ТЕХНИЧЕСКИЙ СТЕНД · 72 ЧАСА"
	column.add_child(title)
	phase_label = Label.new()
	column.add_child(phase_label)
	seed_label = Label.new()
	column.add_child(seed_label)
	start_button = _button(column, "Запустить", start_requested.emit)
	pause_button = _button(column, "Пауза", pause_requested.emit)
	_button(column, "Новое зерно", seed_requested.emit)
	_button(column, "Проверить пул и звук", pulse_requested.emit)
	mute_button = CheckButton.new()
	mute_button.text = "Без звука"
	mute_button.toggled.connect(mute_requested.emit)
	column.add_child(mute_button)
	var hint := Label.new()
	hint.text = "WASD / стрелки: сдвиг\nQ / E: поворот · колесо: масштаб\nПробел: тест эффекта · Esc: пауза"
	column.add_child(hint)


func set_phase(phase: SessionState.Phase) -> void:
	match phase:
		SessionState.Phase.READY:
			phase_label.text = "Состояние: готово"
			start_button.text = "Запустить"
			pause_button.disabled = true
		SessionState.Phase.RUNNING:
			phase_label.text = "Состояние: работает"
			start_button.text = "Работает"
			pause_button.text = "Пауза"
			pause_button.disabled = false
		SessionState.Phase.PAUSED:
			phase_label.text = "Состояние: пауза"
			start_button.text = "Продолжить"
			pause_button.text = "Продолжить"
			pause_button.disabled = false
	start_button.disabled = phase == SessionState.Phase.RUNNING


func set_seed(seed_value: int) -> void:
	seed_label.text = "Зерно раскладки: %d" % seed_value


func _button(parent: VBoxContainer, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
