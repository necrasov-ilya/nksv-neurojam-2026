extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Главная сцена не загружена")
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var session := game.get_node("SessionState") as SessionState
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
