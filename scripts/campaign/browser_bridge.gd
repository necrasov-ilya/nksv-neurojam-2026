extends Node

signal finished(sample: Dictionary)
signal failed(message: String)
const NativeHost := preload("res://scripts/campaign/native_host.gd")
var active := false
var _host: Variant
var _callback: Variant
var _native: NativeHost
var _module := ""
var _browser: Variant
var _browser_layer: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		if OS.get_name() == "Linux" and DisplayServer.get_name() == "X11":
			ProjectSettings.set_setting("godot_cef/advanced/custom_command_line_switches", "--ozone-platform=x11")
		_native = NativeHost.new()
		add_child(_native)
		_native.completed.connect(_on_complete)

func launch(info: Dictionary) -> void:
	if active:
		return
	_module = info.id
	active = true
	if OS.has_feature("web"):
		var bridge := Engine.get_singleton("JavaScriptBridge")
		_host = bridge.get_interface("LatentHost")
		if _host == null:
			active = false
			failed.emit("Запускатель отсутствует. Открой свежую Web-сборку с её HTML-оболочкой, а не один PCK.")
			return
		_callback = bridge.create_callback(_on_web_message)
		var launch_info := info.duplicate()
		launch_info["showInstructions"] = not GameRun.host_instruction_seen
		_host.openGame(JSON.stringify(launch_info), not GameSettings.sound_enabled, _callback)
	else:
		if not ClassDB.class_exists("CefTexture"):
			active = false
			failed.emit("Не найден встроенный Chromium. Для исходного проекта выполни python3 .github/scripts/prepare_cef.py и перезапусти Godot; готовую сборку распаковывай целиком.")
			return
		var result: Dictionary = _native.start(_module, not GameSettings.sound_enabled)
		if result.has("error"):
			active = false
			failed.emit(result.error)
			return
		_browser_layer = CanvasLayer.new()
		_browser_layer.layer = 40
		add_child(_browser_layer)
		_browser = ClassDB.instantiate("CefTexture")
		_browser.name = "EmbeddedSimulation"
		_browser.enable_accelerated_osr = false
		_browser.background_color = Color("17121f")
		_browser.focus_mode = Control.FOCUS_ALL
		_browser.mouse_filter = Control.MOUSE_FILTER_STOP
		_browser.ipc_message.connect(_on_native_message)
		_browser.load_finished.connect(_on_native_loaded)
		_browser.load_error.connect(_on_native_error)
		_browser.url = result.url
		_browser_layer.add_child(_browser)
		_browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_browser.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_web_message(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not parsed is Dictionary:
		return
	if parsed.get("event", "") == "instruction":
		GameRun.host_instruction_seen = true
		return
	if parsed.get("event", "") == "sound":
		GameSettings.set_sound_enabled(bool(parsed.get("enabled", true)))
		return
	_on_complete(parsed)

func _on_native_message(message: String) -> void:
	if not active or not is_instance_valid(_browser):
		return
	var parsed: Variant = JSON.parse_string(message)
	if not parsed is Dictionary:
		return
	if parsed.get("event", "") == "instruction":
		GameRun.host_instruction_seen = true
		return
	if parsed.get("event", "") == "sound":
		GameSettings.set_sound_enabled(bool(parsed.get("enabled", true)))
	elif parsed.get("event", "") == "pointer-lock":
		var locked := bool(parsed.get("locked", false)) and get_window().has_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if locked else Input.MOUSE_MODE_VISIBLE
		_browser.eval("window.LatentHost.pointerLockResult(%d,%s);" % [int(parsed.get("request", 0)), "true" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "false"])
	elif parsed.get("event", "") == "author-link":
		var url: String = {"nksv": "https://t.me/nksv_ilya", "alesha": "https://t.me/fuckup_files"}.get(str(parsed.get("author", "")), "")
		if not url.is_empty():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			OS.shell_open(url)

func _on_native_loaded(_url: String, status: int) -> void:
	if status >= 400:
		abort()
		failed.emit("Встроенный стенд не загрузился: HTTP %d." % status)

func _on_native_error(_url: String, code: int, text: String) -> void:
	if not active or code == -3:
		return
	abort()
	failed.emit("Встроенный стенд не загрузился: %s (%d)." % [text, code])

func _input(event: InputEvent) -> void:
	if active and is_instance_valid(_browser) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		_browser.eval("window.LatentHost.forwardMouse(%s);" % JSON.stringify([event.screen_relative.x, event.screen_relative.y]))
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and is_instance_valid(_browser):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_browser.eval("window.LatentHost && window.LatentHost.pause(true);")

func _close_browser() -> void:
	if is_instance_valid(_browser):
		_browser.set_audio_muted(true)
	if is_instance_valid(_browser_layer):
		_browser_layer.queue_free()
		_browser_layer.hide()
	_browser = null
	_browser_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_complete(sample: Dictionary) -> void:
	if not active or str(sample.get("module", "")) != _module:
		return
	active = false
	if not OS.has_feature("web"):
		_close_browser()
	GameSettings.set_sound_enabled(not bool(sample.get("muted", not GameSettings.sound_enabled)))
	finished.emit(sample)

func abort() -> void:
	if not active:
		return
	active = false
	if OS.has_feature("web") and _host != null:
		_host.closeGame()
	elif _native != null:
		_native.abort()
		_close_browser()

func set_muted(value: bool) -> void:
	if OS.has_feature("web") and _host != null:
		_host.setMuted(value)
	elif _native != null:
		_native.set_muted(value)
		if is_instance_valid(_browser):
			_browser.set_audio_muted(value)
			_browser.eval("window.LatentHost && window.LatentHost.setMuted(%s);" % ("true" if value else "false"))

func _exit_tree() -> void:
	abort()
	_callback = null
	_host = null
