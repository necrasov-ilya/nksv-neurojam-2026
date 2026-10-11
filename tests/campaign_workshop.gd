extends SceneTree

const Workshop = preload("res://scripts/campaign/workshop.gd")
var failed := false

func _initialize() -> void:
	check.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func settle(seconds: float) -> void:
	await create_timer(seconds).timeout

func check() -> void:
	var workshop := Workshop.new()
	root.add_child(workshop)
	workshop.begin()
	workshop.pickup()
	workshop.cube.position = Vector3(2, 1.8, 1)
	workshop.release()
	await settle(1.3)
	expect(workshop.dropped, "Released physical cube does not settle on the floor")
	workshop.pickup()
	workshop.cube.position = Vector3(0, 1.08, -1.1)
	workshop.release()
	await settle(1.0)
	expect(workshop.placed, "High platform does not register a stable physical placement")
	workshop.change_material()
	workshop.reset_cube()
	expect(not workshop.complete(), "Material alone bypasses lighting and load checks")
	workshop.change_light()
	workshop.pickup()
	workshop.cube.position = Vector3(1.6, 0.6, -2.1)
	await settle(1.0)
	expect(not workshop.load_checked, "A carried cube is accepted as a stable load")
	workshop.release()
	await settle(1.3)
	expect(workshop.load_checked and workshop._gate.position.y > 2.0, "Physical load does not open the visible gate")
	workshop.pickup()
	await settle(0.1)
	expect(workshop._gate.position.y == 0.0, "Gate stays open after the load is removed")
	workshop.reset_cube()
	expect(workshop.complete(), "Completed physical checks do not unlock the report")
	workshop.begin()
	expect(not workshop.complete() and not workshop.load_checked and not workshop.light_checked and not workshop.material_checked, "A repeated calibration inherits completed checks")
	workshop.queue_free()
	await process_frame
	print("CAMPAIGN_WORKSHOP_PHYSICS: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
