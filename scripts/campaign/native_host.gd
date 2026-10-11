extends Node

signal completed(sample: Dictionary)
const MIME := {"html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8", "json": "application/json; charset=utf-8", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp", "svg": "image/svg+xml", "woff": "font/woff", "woff2": "font/woff2", "ttf": "font/ttf", "ogg": "audio/ogg", "mp3": "audio/mpeg", "wav": "audio/wav", "wasm": "application/wasm", "glb": "model/gltf-binary", "gltf": "model/gltf+json"}
var _server := TCPServer.new()
var _clients: Array[Dictionary] = []
var _root := ""
var _port := 0
var _token := ""
var _module := ""
var _muted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start(module_id: String, muted: bool) -> Dictionary:
	if _root.is_empty():
		var executable_dir := OS.get_executable_path().get_base_dir()
		for candidate in [ProjectSettings.globalize_path("res://build/campaign-modules"), executable_dir.path_join("campaign-modules"), executable_dir.path_join("../Resources/campaign-modules").simplify_path()]:
			if FileAccess.file_exists(str(candidate).path_join("simulation-host.html")):
				_root = candidate
				break
	if _root.is_empty():
		return {"error": "Не найден включённый каталог стендов. Для исходного проекта выполни python3 .github/scripts/prepare_modules.py; готовые сборки нужно распаковывать целиком."}
	if not _server.is_listening():
		for candidate_port in range(38270, 38302):
			if _server.listen(candidate_port, "127.0.0.1") == OK:
				_port = candidate_port
				break
		if _port == 0:
			return {"error": "Не удалось открыть локальный порт стенда на 127.0.0.1."}
	_token = Crypto.new().generate_random_bytes(24).hex_encode()
	_module = module_id
	_muted = muted
	return {"url": "http://127.0.0.1:%d/simulation-host.html?module=%s&token=%s" % [_port, module_id.uri_encode(), _token]}

func abort() -> void:
	_token = ""
	_module = ""

func set_muted(value: bool) -> void:
	_muted = value

func _process(_delta: float) -> void:
	while _server.is_connection_available() and _clients.size() < 32:
		var peer := _server.take_connection()
		peer.set_no_delay(true)
		_clients.append({"peer": peer, "input": PackedByteArray(), "output": PackedByteArray(), "offset": 0, "file": null, "responding": false, "last": Time.get_ticks_msec()})
	for index in range(_clients.size() - 1, -1, -1):
		var client := _clients[index]
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - int(client.last) > 20000:
			_drop(index)
			continue
		if client.responding:
			_send(client)
			if int(client.offset) == client.output.size() and client.file == null:
				_drop(index)
			continue
		var available := peer.get_available_bytes()
		if available > 0:
			var result := peer.get_partial_data(mini(available, 65536))
			if result[0] != OK:
				_drop(index)
				continue
			client.input.append_array(result[1])
			client.last = Time.get_ticks_msec()
			_parse(client)

func _drop(index: int) -> void:
	var client := _clients[index]
	client.peer.disconnect_from_host()
	if client.file != null:
		client.file.close()
	_clients.remove_at(index)

func _parse(client: Dictionary) -> void:
	var input: PackedByteArray = client.input
	if input.size() > 524288:
		_response(client, 413, "Слишком большой запрос")
		return
	var text := input.get_string_from_utf8()
	var end := text.find("\r\n\r\n")
	if end == -1:
		return
	var headers := text.substr(0, end).split("\r\n")
	var request := headers[0].split(" ")
	if request.size() < 2:
		_response(client, 400, "Некорректный запрос")
		return
	var length := 0
	var origin := ""
	for header in headers:
		var lower := header.to_lower()
		if lower.begins_with("content-length:"):
			length = header.get_slice(":", 1).strip_edges().to_int()
		elif lower.begins_with("origin:"):
			origin = header.substr(header.find(":") + 1).strip_edges()
	if length < 0 or length > 524288:
		_response(client, 413, "Слишком большой запрос")
		return
	var body_offset := text.substr(0, end + 4).to_utf8_buffer().size()
	if input.size() < body_offset + length:
		return
	var route: String = request[1].get_slice("?", 0)
	if request[0] == "POST" and route == "/complete":
		if not origin.is_empty() and origin != "http://127.0.0.1:%d" % _port:
			_response(client, 403, "Недопустимый источник")
			return
		var parsed: Variant = JSON.parse_string(input.slice(body_offset, body_offset + length).get_string_from_utf8())
		if not parsed is Dictionary or _token.is_empty() or str(parsed.get("token", "")) != _token or str(parsed.get("module", "")) != _module:
			_response(client, 403, "Запуск уже закрыт или ключ не совпадает")
			return
		var sample: Dictionary = parsed.get("sample", {})
		sample["module"] = _module
		sample["muted"] = bool(parsed.get("muted", _muted))
		abort()
		_response(client, 200, JSON.stringify({"ok": true}), "application/json")
		completed.emit.call_deferred(sample)
		return
	if request[0] != "GET" and request[0] != "HEAD":
		_response(client, 405, "Метод не поддерживается")
		return
	if route == "/state":
		var query: String = request[1].get_slice("?", 1)
		var key := ""
		for pair in query.split("&"):
			if pair.get_slice("=", 0) == "token":
				key = pair.get_slice("=", 1).uri_decode()
		_response(client, 200, JSON.stringify({"active": not _token.is_empty() and key == _token, "muted": _muted}), "application/json")
		return
	var path := route.uri_decode().trim_prefix("/")
	if path.is_empty():
		path = "simulation-host.html"
	if ".." in path.split("/") or path.contains("\\") or path.contains(String.chr(0)) or path.is_absolute_path():
		_response(client, 403, "Недопустимый путь")
		return
	var file_path := _root.path_join(path)
	if not FileAccess.file_exists(file_path):
		_response(client, 404, "Ресурс не найден")
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_response(client, 404, "Ресурс не читается")
		return
	var size := file.get_length()
	var mime: String = MIME.get(path.get_extension().to_lower(), "application/octet-stream")
	client.output = _headers(200, size, mime)
	client.offset = 0
	client.responding = true
	client.file = file if request[0] != "HEAD" else null
	if request[0] == "HEAD":
		file.close()

func _headers(status: int, length: int, mime: String) -> PackedByteArray:
	var names := {200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed", 413: "Payload Too Large"}
	return ("HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-cache\r\nX-Content-Type-Options: nosniff\r\n\r\n" % [status, names.get(status, "Error"), mime, length]).to_utf8_buffer()

func _response(client: Dictionary, status: int, text: String, mime := "text/plain; charset=utf-8") -> void:
	var body := text.to_utf8_buffer()
	client.output = _headers(status, body.size(), mime) + body
	client.offset = 0
	client.responding = true

func _send(client: Dictionary) -> void:
	var output: PackedByteArray = client.output
	if int(client.offset) < output.size():
		var data: PackedByteArray = output if int(client.offset) == 0 else output.slice(client.offset)
		var sent: Array = client.peer.put_partial_data(data)
		if sent[0] != OK:
			client.file = null
			client.offset = output.size()
			return
		client.offset += int(sent[1])
		if sent[1] > 0:
			client.last = Time.get_ticks_msec()
	if int(client.offset) == output.size() and client.file != null:
		var file: FileAccess = client.file
		if file.get_position() >= file.get_length():
			file.close()
			client.file = null
		else:
			client.output = file.get_buffer(65536)
			client.offset = 0

func _exit_tree() -> void:
	for index in range(_clients.size() - 1, -1, -1):
		_drop(index)
	_server.stop()
