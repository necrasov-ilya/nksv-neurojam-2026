extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var start_scene := load("res://scenes/start.tscn") as PackedScene
	if start_scene == null:
		_fail("Стартовая сцена не загружена")
		return
	var start := start_scene.instantiate()
	root.add_child(start)
	await process_frame
	if start.get_script() == null:
		_fail("Скрипт стартового экрана не загрузился")
		return
	var guard := start.get_node("OrientationGuard") as OrientationGuard
	if guard == null or not guard.is_landscape():
		_fail("Стартовый экран не определил горизонтальную раскладку")
		return
	start.queue_free()
	await process_frame
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Главная сцена не загружена")
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	if game.get_script() == null:
		_fail("Скрипт главной сцены не загрузился")
		return
	var session := game.get_node("SessionState") as SessionState
	if session.phase != SessionState.Phase.RUNNING:
		_fail("Игра не запустилась автоматически из горизонтального окна")
		return
	var world := game.get_node("World") as WorldManager
	var pool := game.get_node("EffectPool") as ObjectPool
	if world.markers.multimesh.instance_count != 60:
		_fail("Неверное число диагностических маркеров")
		return
	var first := ProceduralLayout.scatter(42, 8, 10.0)
	var second := ProceduralLayout.scatter(42, 8, 10.0)
	if first != second:
		_fail("Генерация не повторяется для одного зерна")
		return
	session.start()
	if session.phase != SessionState.Phase.RUNNING:
		_fail("Состояние не перешло в игру")
		return
	session.pause()
	if session.phase != SessionState.Phase.PAUSED:
		_fail("Пауза не сработала")
		return
	var first_instance := pool.acquire()
	pool.release(first_instance)
	var reused_instance := pool.acquire()
	if first_instance != reused_instance:
		_fail("Пул не переиспользовал объект")
		return
	world.regenerate(99)
	if world.seed_value != 99:
		_fail("Зерно не обновилось")
		return
	print("SMOKE_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
