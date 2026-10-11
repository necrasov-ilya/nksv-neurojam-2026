extends CanvasLayer

signal modal_changed
signal speaker_changed(id: String)
const Dialogue := preload("res://scripts/campaign/dialogue.gd")
const UIStyle := preload("res://scripts/ui/hud_style.gd")
const PauseUI := preload("res://scripts/ui/pause_drawer.gd")
const INK := UIStyle.INK
const MUTED := UIStyle.MUTED
const ACCENT := UIStyle.ACCENT
const DIALOGUE_GAP := 0.3
var mode := "none"
var hud: Control
var objective: Label
var prompt: Label
var subtitle: Label
var fade: ColorRect
var _page_root: Control
var _page_body: VBoxContainer
var _voice: AudioStreamPlayer
var _suspended_root: Control
var _suspended_body: VBoxContainer
var _suspended_mode := "none"
var _page_suspended := false
var _focused := true
var _dialogue_ids: Array = []
var _dialogue_index := 0
var _dialogue_done: Callable
var _dialogue_remaining := 0.0
var _objective_plate: PanelContainer
var _prompt_plate: PanelContainer
var _subtitle_plate: PanelContainer
var _page_navigation: HBoxContainer
var _page_footer: HBoxContainer
var _remark_remaining := 0.0
var _transition_card: Control
var speaker_context := ""

func transition_card(text: String) -> void:
	if is_instance_valid(_transition_card):
		_transition_card.queue_free()
	_transition_card = Control.new()
	_full(_transition_card, self)
	_transition_card.z_index = -1
	_transition_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color.BLACK
	_full(black, _transition_card)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := label("LATENT SYSTEMS", 32, Color.WHITE)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position -= Vector2(220, 60)
	title.size = Vector2(440, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_card.add_child(title)
	var caption := label(text, 18, Color("b9b2cc"))
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caption.position -= Vector2(320, 0)
	caption.size = Vector2(640, 70)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_card.add_child(caption)
	_objective_plate.hide()
	_prompt_plate.hide()

func clear_transition() -> void:
	if is_instance_valid(_transition_card):
		_transition_card.queue_free()
	_objective_plate.show()
	_prompt_plate.show()

func _ready() -> void:
	layer = 20
	hud = Control.new()
	_full(hud, self)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UIStyle.theme()
	var margins := MarginContainer.new()
	_full(margins, hud)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 22)
	margins.add_theme_constant_override("margin_top", 20)
	margins.add_theme_constant_override("margin_bottom", 24)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margins.add_child(column)
	_objective_plate = _hud_plate(UIStyle.PAPER)
	_objective_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_objective_plate)
	var objective_row := HBoxContainer.new()
	objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_row.add_theme_constant_override("separation", 8)
	_objective_plate.add_child(objective_row)
	var marker := UIStyle.icon("map-pin", 18)
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	objective_row.add_child(marker)
	var objectives := VBoxContainer.new()
	objectives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objectives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objectives.add_theme_constant_override("separation", 8)
	objective_row.add_child(objectives)
	objective = label("", 14)
	objectives.add_child(objective)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	_subtitle_plate = _hud_plate(UIStyle.PAPER)
	_subtitle_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_subtitle_plate)
	subtitle = label("", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_plate.add_child(subtitle)
	_prompt_plate = _hud_plate(ACCENT)
	_prompt_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_prompt_plate)
	var interaction := HBoxContainer.new()
	interaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction.add_theme_constant_override("separation", 8)
	_prompt_plate.add_child(interaction)
	interaction.add_child(UIStyle.icon("hand", 18, Color.WHITE))
	prompt = label("", 14, Color.WHITE)
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	interaction.add_child(prompt)
	var crosshair := Panel.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_theme_stylebox_override("panel", UIStyle.flat(ACCENT, 3))
	hud.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -3
	crosshair.offset_right = 3
	crosshair.offset_top = -3
	crosshair.offset_bottom = 3
	hud.resized.connect(_layout_hud)
	_layout_hud()
	_sync_hud_plates()
	_voice = AudioStreamPlayer.new()
	_voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_voice)
	_voice.finished.connect(_on_voice_finished)
	fade = ColorRect.new()
	_full(fade, self)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 100

func _hud_plate(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UIStyle.plate(color, 9, 10))
	return panel

func _layout_hud() -> void:
	var available := maxf(1, hud.size.x - 44)
	_objective_plate.custom_minimum_size.x = minf(340, available)
	_subtitle_plate.custom_minimum_size.x = minf(560, available)

func _process(delta: float) -> void:
	_voice.stream_paused = not _focused or _page_suspended or mode == "pause" or not GameSettings.sound_enabled
	_sync_hud_plates()
	if mode == "none" and _focused and not _page_suspended and _remark_remaining > 0:
		_remark_remaining = maxf(0, _remark_remaining - delta)
		if _remark_remaining == 0:
			subtitle.text = ""
	if mode != "dialogue" or not _focused or _page_suspended:
		return
	_dialogue_remaining = maxf(0.0, _dialogue_remaining - delta)
	if _dialogue_remaining <= 0.0 and (not GameSettings.sound_enabled or not _voice.playing):
		_advance_dialogue()

func _sync_hud_plates() -> void:
	objective.visible = not objective.text.is_empty()
	_objective_plate.visible = objective.visible and not is_instance_valid(_transition_card)
	_prompt_plate.visible = not prompt.text.is_empty() and not is_instance_valid(_transition_card)
	_subtitle_plate.visible = _focused and not _page_suspended and (GameSettings.subtitles_enabled or _voice.stream == null) and not subtitle.text.is_empty()

func say(text: String) -> void:
	if mode != "none":
		return
	subtitle.text = text
	_remark_remaining = maxf(3.0, text.length() / 19.0)
	_sync_hud_plates()

func _full(control: Control, parent: Node) -> void:
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func label(text: String, size := 20, color := INK) -> Label:
	return UIStyle.label(text, size, color)

func plate(color := UIStyle.PAPER, padding := 18) -> StyleBoxFlat:
	return UIStyle.plate(color, padding, 16)

func button(parent: Node, text: String, action: Callable, primary := false) -> Button:
	var node := Button.new()
	node.text = text
	UIStyle.apply_button(node, primary)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func close_page() -> void:
	if is_instance_valid(_page_root):
		_page_root.queue_free()
		_page_root.hide()
	_page_root = null
	_page_body = null
	if is_instance_valid(_suspended_root):
		_suspended_root.queue_free()
	_suspended_root = null
	_suspended_body = null
	_suspended_mode = "none"
	_page_suspended = false
	_dialogue_ids = []
	_dialogue_remaining = 0.0
	_dialogue_done = Callable()
	_voice.stop()
	_voice.stream = null
	subtitle.text = ""
	_sync_hud_plates()
	mode = "none"
	hud.show()
	modal_changed.emit()

func suspend_page() -> void:
	_page_suspended = true
	_sync_hud_plates()
	_suspended_root = _page_root
	_suspended_body = _page_body
	_suspended_mode = mode
	if is_instance_valid(_suspended_root):
		_suspended_root.hide()
	_page_root = null
	_page_body = null
	_voice.stream_paused = true

func restore_page() -> void:
	if is_instance_valid(_page_root):
		_page_root.queue_free()
		_page_root.hide()
	_page_root = _suspended_root
	_page_body = _suspended_body
	mode = _suspended_mode
	_suspended_root = null
	_suspended_body = null
	_suspended_mode = "none"
	_page_suspended = false
	if is_instance_valid(_page_root):
		_page_root.show()
		hud.hide()
	else:
		hud.show()
	_voice.stream_paused = not _focused or not GameSettings.sound_enabled
	_sync_hud_plates()
	modal_changed.emit()

func set_focused(value: bool) -> void:
	_focused = value
	_voice.stream_paused = not value or _page_suspended or not GameSettings.sound_enabled or mode == "pause"
	_sync_hud_plates()


func page(title: String, kicker: String, page_mode := "page") -> VBoxContainer:
	if is_instance_valid(_page_root):
		_page_root.queue_free()
		_page_root.hide()
	mode = page_mode
	hud.hide()
	if page_mode == "pause":
		var drawer := PauseUI.new()
		add_child(drawer)
		_page_root = drawer
		_page_body = drawer.body
		drawer.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		modal_changed.emit()
		return _page_body
	_page_root = Control.new()
	_full(_page_root, self)
	_page_root.theme = UIStyle.theme()
	var scrim := ColorRect.new()
	_full(scrim, _page_root)
	scrim.color = Color(0.035, 0.025, 0.06, 0.42)
	var panel := PanelContainer.new()
	panel.name = "Tablet"
	var frame := UIStyle.plate(UIStyle.PAPER, 24, 26)
	frame.set_border_width_all(8)
	frame.border_color = Color("34303f")
	frame.shadow_color = Color(0, 0, 0, 0.3)
	frame.shadow_size = 12
	frame.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", frame)
	_page_root.add_child(panel)
	_page_root.resized.connect(_layout_page.bind(panel))
	_layout_page(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(label(kicker, 12, ACCENT))
	if not title.is_empty():
		heading.add_child(label(title, 25))
	if page_mode in ["computer", "home", "report"]:
		var leave := UIStyle.small_button("Отложить" if page_mode == "report" else "Отойти", "x", close_page)
		leave.name = "CloseTablet"
		leave.custom_minimum_size = Vector2(132, 40)
		leave.tooltip_text = "Черновик сохранён. Escape — закрыть." if page_mode == "report" else "Escape — закрыть"
		leave.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header.add_child(leave)
	_page_navigation = HBoxContainer.new()
	_page_navigation.add_theme_constant_override("separation", 8)
	column.add_child(_page_navigation)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_page_body = VBoxContainer.new()
	_page_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_page_body)
	_page_footer = HBoxContainer.new()
	_page_footer.add_theme_constant_override("separation", 12)
	column.add_child(_page_footer)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal_changed.emit()
	return _page_body

func _layout_page(panel: PanelContainer) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := Vector2(960, 720)
	panel.size = Vector2(minf(desired.x, maxf(1, viewport_size.x - 40)), minf(desired.y, maxf(1, viewport_size.y - 40)))
	panel.position = (viewport_size - panel.size) * 0.5
	for grid: GridContainer in panel.find_children("ModuleCards", "GridContainer", true, false):
		grid.columns = 2 if panel.size.x >= 780 else 1
	for grid: GridContainer in panel.find_children("ReportSnapshots*", "GridContainer", true, false):
		grid.columns = maxi(1, int((panel.size.x - 44) / 240))

func dialogue(ids: Array, done: Callable) -> void:
	close_page()
	_dialogue_ids = ids
	_dialogue_index = 0
	_dialogue_done = done
	mode = "dialogue"
	prompt.text = ""
	modal_changed.emit()
	if _dialogue_ids.is_empty():
		_advance_dialogue()
	else:
		_render_dialogue()

func _render_dialogue() -> void:
	var id: String = _dialogue_ids[_dialogue_index]
	var item := Dialogue.line(id)
	speaker_changed.emit(id)
	subtitle.text = "%s%s: %s" % [item[0], " · " + speaker_context if not speaker_context.is_empty() else "", item[1]]
	_voice.stop()
	_voice.stream = null
	_dialogue_remaining = maxf(2.5, str(item[1]).length() / 18.0) + DIALOGUE_GAP
	var path := Dialogue.audio_path(id)
	if GameSettings.sound_enabled and ResourceLoader.exists(path):
		_voice.stream = load(path)
		_dialogue_remaining = _voice.stream.get_length() + DIALOGUE_GAP
		_voice.play()
		_voice.stream_paused = not _focused or _page_suspended
	_sync_hud_plates()

func _on_voice_finished() -> void:
	if not _dialogue_ids.is_empty():
		_dialogue_remaining = maxf(_dialogue_remaining, DIALOGUE_GAP)

func _advance_dialogue() -> void:
	if mode != "dialogue":
		return
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_ids.size():
		var callback := _dialogue_done
		close_page()
		if callback.is_valid():
			callback.call()
	else:
		_render_dialogue()

func notice(title: String, text: String, done: Callable) -> void:
	var body := page(title, "LATENT / СООБЩЕНИЕ")
	body.add_child(label(text, 23))
	button(body, "Понятно", done, true)

func computer(launch: Callable, end_shift: Callable, tab := 0) -> void:
	var role: String = ["Кандидат", "Тестировщик", "Приёмка выпуска"][GameRun.day - 1]
	var body := page("Испытательные среды", "LATENT SYSTEMS / ДЕНЬ %d / %s" % [GameRun.day, role.to_upper()], "computer")
	var quota := label(GameRun.quota_text(), 15, ACCENT)
	quota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quota.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_page_footer.add_child(quota)
	var tabs := _page_navigation
	for index in 4:
		var selected := index
		var node := button(tabs, ["Стенды", "Отчёты", "Связь", "Выпуск"][index], func(): computer(launch, end_shift, selected))
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.disabled = index == tab
	if tab == 0:
		body.add_child(label("Не требуется победа в игре. Проверь выбранные действия и завершай наблюдение отдельной кнопкой стенда. Повторы и дополнительные среды тоже заканчиваются опросом.", 17, MUTED))
		var cards := GridContainer.new()
		cards.name = "ModuleCards"
		cards.columns = 2 if get_viewport().get_visible_rect().size.x >= 820 else 1
		cards.add_theme_constant_override("h_separation", 14)
		cards.add_theme_constant_override("v_separation", 14)
		body.add_child(cards)
		var ids := GameRun.completed_ids()
		for info: Dictionary in GameRun.catalog:
			var card := PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_theme_stylebox_override("panel", plate(UIStyle.SURFACE, 16))
			cards.add_child(card)
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", 8)
			card.add_child(column)
			if not str(info.cover).is_empty() and ResourceLoader.exists(info.cover):
				var image := TextureRect.new()
				image.texture = load(info.cover)
				image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				image.custom_minimum_size.y = 110
				column.add_child(image)
			column.add_child(label(info.title, 23))
			column.add_child(label(info.purpose, 16, MUTED))
			var unlocked: bool = GameRun.available(info.id) and (info.id == "calibration" or GameRun.calibration_done)
			var state := "Отчёт есть · можно повторить" if info.id in ids else "Доступно" if unlocked else "Доступ с дня %d" % info.days[0]
			if GameRun.day == 1 and info.id != "calibration" and not GameRun.calibration_done:
				state = "После практической пробы"
			column.add_child(label(state, 16, ACCENT))
			var module_id: String = info.id
			var run_button := button(column, "Повторить" if info.id in ids else "Открыть стенд", func(): launch.call(module_id), unlocked)
			run_button.name = "Launch_" + module_id
			run_button.disabled = not unlocked
	elif tab == 1:
		report_list(body)
	elif tab == 2:
		if GameRun.messages.is_empty():
			body.add_child(label("Ника рядом на этаже. Независимое мнение можно запросить в рекомендации отчёта.", 21))
		for message in GameRun.messages:
			body.add_child(label(message.sender + " / " + message.subject, 21, ACCENT))
			body.add_child(label(message.body, 19))
			body.add_child(HSeparator.new())
	else:
		body.add_child(label("Производственный контур ≠ контрольная игра", 24, ACCENT))
		body.add_child(label("Контрольные среды неизменны. Их отчёты сопровождают решение о выпуске модели управления зданием; сами игры не управляют настоящими дверями или оружием.", 20))
		if GameRun.day == 1:
			body.add_child(label("1.6 / обычная эксплуатация. Сегодня — практическая проба и знакомство с контрольными средами.", 22))
		elif GameRun.day == 2:
			body.add_child(label("1.7 / управление шлюзами испытательного этажа. Следующий выпуск готовится к приёмке.", 22))
		else:
			body.add_child(label("1.6 / обычная эксплуатация\n1.7 / прогноз занятости подключён к шлюзам\n1.8 / автоматическая противопожарная продувка при прогнозе «свободен»", 22))
			body.add_child(label("Подпись выпуска: Е. Бессонова. Замечания тестировщика не удаляются. При потере свежего наблюдения модель продолжает прогноз; допуск разрешает использование прогноза как подтверждения свободного сектора.", 19, MUTED))
		if GameRun.day < 3:
			body.add_child(label("Подробный производственный протокол — с допуском на третьей смене.", 17, MUTED))
	var end_button := button(_page_footer, "К приёмке" if GameRun.day == 3 else "К выходу" if GameRun.shift_released else "Закончить смену", end_shift, true)
	end_button.name = "EndShift"
	end_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	end_button.disabled = not GameRun.quota_ready()

func report_list(body: VBoxContainer) -> void:
	if GameRun.reports.is_empty():
		body.add_child(label("Отчётов пока нет. Начни с практической пробы.", 22))
	for report in GameRun.reports:
		body.add_child(label("№%02d / ДЕНЬ %d / %s" % [report.number, report.day, report.title], 21, ACCENT))
		body.add_child(label("Проверено: %s\nНаблюдение: %s\nРекомендация: %s\n%s" % [report.checked, report.observation, GameRun.REVIEW_CHOICES[report.recommendation], report.status], 19))
		var shots: Array = report.sample.get("snapshots", [])
		if not shots.is_empty():
			var row := GridContainer.new()
			row.name = "ReportSnapshots"
			row.columns = maxi(1, int((minf(1000, get_viewport().get_visible_rect().size.x - 40) - 44) / 240))
			row.add_theme_constant_override("h_separation", 12)
			row.add_theme_constant_override("v_separation", 12)
			body.add_child(row)
			for encoded: String in shots:
				var bytes := Marshalls.base64_to_raw(encoded.get_slice(",", 1))
				var image := Image.new()
				if image.load_jpg_from_buffer(bytes) == OK:
					var thumbnail := TextureRect.new()
					thumbnail.texture = ImageTexture.create_from_image(image)
					thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					thumbnail.custom_minimum_size = Vector2(220, 132)
					row.add_child(thumbnail)
		body.add_child(HSeparator.new())

func survey(module_id: String, sample: Dictionary, save: Callable) -> void:
	var info := GameRun.module_info(module_id)
	if GameRun.report_draft.is_empty():
		GameRun.report_draft = {"module": module_id, "sample": sample.duplicate(true), "checked": -1, "observation": -1, "recommendation": -1, "note": ""}
	var draft: Dictionary = GameRun.report_draft
	var body := page("Отчёт / " + str(info.title), "НАБЛЮДЕНИЕ ЗАВЕРШЕНО · ДЕНЬ %d" % GameRun.day, "report")
	body.add_child(label("Отчёт относится к тому, что ты сам проверил. Стенд не передаёт нам внутреннюю победу или статистику игры.", 17, MUTED))
	body.add_child(label("1 / Что проверял?", 22, ACCENT))
	var checked := OptionButton.new()
	checked.custom_minimum_size.y = 44
	for choice: String in info.checks:
		checked.add_item(choice)
	UIStyle.apply_button(checked)
	checked.select(-1)
	checked.text = "Выбери проверенное действие"
	body.add_child(checked)
	body.add_child(label("2 / Что наблюдал?", 22, ACCENT))
	var observation := OptionButton.new()
	observation.custom_minimum_size.y = 44
	for choice in ["В проверенных действиях проблем не заметил", "Обнаружил несоответствие", "Поведение не удалось устойчиво повторить", "Не успел проверить / недостаточно наблюдений"]:
		observation.add_item(choice)
	UIStyle.apply_button(observation)
	observation.select(-1)
	observation.text = "Выбери наблюдение"
	body.add_child(observation)
	var note := LineEdit.new()
	note.placeholder_text = "Необязательно: конкретный момент или действие"
	note.max_length = 500
	note.custom_minimum_size.y = 44
	body.add_child(note)
	body.add_child(label("3 / Твоя рекомендация", 22, ACCENT))
	var recommendation := OptionButton.new()
	recommendation.custom_minimum_size.y = 44
	for choice: String in GameRun.REVIEW_CHOICES:
		recommendation.add_item(choice)
	UIStyle.apply_button(recommendation)
	recommendation.select(-1)
	recommendation.text = "Выбери рекомендацию"
	body.add_child(recommendation)
	body.add_child(label("«Независимая проверка» создаёт контакт с Никой; замечания открывают повтор в приёмке. Принятие не удаляет историю. Ни один ответ не закрывает помощь людям.", 17, MUTED))
	var submit := button(_page_footer, "Сохранить отчёт", func():
		var observed := observation.get_item_text(observation.selected)
		if not note.text.strip_edges().is_empty():
			observed += " · " + note.text.strip_edges()
		save.call(checked.get_item_text(checked.selected), observed, recommendation.selected, sample)
	, true)
	submit.name = "SaveReport"
	for pair in [[checked, "checked"], [observation, "observation"], [recommendation, "recommendation"]]:
		var field: OptionButton = pair[0]
		if int(draft[pair[1]]) >= 0:
			field.select(int(draft[pair[1]]))
	note.text = str(draft.note)
	var update := func(_index: int):
		draft.checked = checked.selected
		draft.observation = observation.selected
		draft.recommendation = recommendation.selected
		submit.disabled = checked.selected < 0 or observation.selected < 0 or recommendation.selected < 0
	checked.item_selected.connect(update)
	observation.item_selected.connect(update)
	recommendation.item_selected.connect(update)
	note.text_changed.connect(func(value: String): draft.note = value)
	update.call(0)
	submit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var draft_hint := label("Черновик хранится до отправки.\nEscape — отложить.", 13, MUTED)
	draft_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_page_footer.add_child(draft_hint)

func _exit_tree() -> void:
	if is_instance_valid(_voice):
		_voice.stop()
	_dialogue_done = Callable()
