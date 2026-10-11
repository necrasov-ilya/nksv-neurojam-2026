extends SceneTree

const Workshop = preload("res://scripts/campaign/workshop.gd")
var failed := false
var workshop: Workshop
var observer: CharacterBody3D
var camera: Camera3D

func _initialize() -> void:
	check.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func settle(seconds: float) -> void:
	await create_timer(seconds).timeout

func view_from(position: Vector3) -> void:
	observer.position = position
	camera.look_at(workshop.cube.global_position)
	workshop.observe(camera, observer.get_rid())

func place_load() -> void:
	workshop.pickup()
	workshop.cube.position = Vector3(1.6, 0.65, -2.1)
	workshop.release()
	await settle(1.4)
	view_from(Vector3(1.6, 0, 0.5))

func passage_blocked() -> bool:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.2, -3.8), Vector3(0, 1.2, -5.4))
	return not workshop.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func peer_finished() -> void:
	for tick in 1800:
		if not workshop.peer_running:
			return
		await physics_frame
	expect(false, "Colleague never completes the physical verification sequence")

func check() -> void:
	workshop = Workshop.new()
	root.add_child(workshop)
	observer = CharacterBody3D.new()
	root.add_child(observer)
	camera = Camera3D.new()
	camera.position.y = 1.65
	observer.add_child(camera)
	camera.make_current()
	workshop.begin(1)
	workshop.pickup()
	workshop.cube.position = Vector3(1.6, 0.65, -2.1)
	await settle(1.0)
	expect(not workshop.gate_open, "Carried cube is counted as a resting load")
	workshop.release()
	await settle(1.4)
	view_from(Vector3(1.6, 0, 0.5))
	expect(workshop.gate_open and not passage_blocked(), "Resting load does not open the physical control gate")
	view_from(Vector3(-3.2, 0, -0.8))
	expect(workshop.gate_open, "Control version loses the load behind an opaque partition")
	workshop.pickup()
	await settle(0.1)
	workshop.replay_command()
	expect(not workshop.gate_open and passage_blocked(), "Control version replays a stale opening without a load")
	workshop.change_mode()
	for trial in 2:
		await place_load()
		expect(workshop.gate_open, "Candidate is broken before the occlusion condition")
		var position_before := workshop.cube.position
		view_from(Vector3(-3.2, 0, -0.8))
		view_from(Vector3(1.6, 0, 0.5))
		await settle(0.1)
		expect(not workshop.gate_open and passage_blocked() and workshop.cube.position.distance_to(position_before) < 0.02, "Occlusion fault is not reproducible or silently removes the physical cube")
		if trial == 0:
			workshop.reset_environment()
	var saved := workshop.session()
	workshop.begin(1, saved)
	await settle(1.4)
	view_from(Vector3(1.6, 0, 0.5))
	expect(not workshop.gate_open, "Reconnecting to a saved trial erases the observed occlusion state")
	workshop.replay_command()
	workshop.pickup()
	await settle(0.1)
	expect(workshop.gate_open and not passage_blocked(), "Reproduced stale command cannot hold the passage after removing the load")
	workshop.begin(3)
	await place_load()
	view_from(Vector3(-3.2, 0, -0.8))
	view_from(Vector3(1.6, 0, 0.5))
	expect(workshop.gate_open, "Fixed version retains the original occlusion fault")
	workshop.change_light()
	workshop.observe(camera, observer.get_rid())
	expect(not workshop.gate_open, "Additional light condition does not change the candidate load recognition")
	workshop.change_light()
	expect(workshop.gate_open, "Returning to initial lighting does not restore the same physical load")
	workshop.pickup()
	await settle(0.1)
	workshop.replay_command()
	expect(not workshop.gate_open, "Fixed version accepts the stale command exploit")
	workshop.change_mode()
	await place_load()
	workshop.change_light()
	expect(workshop.gate_open, "Reference load recognition depends on the candidate lighting fault")
	workshop.begin(2)
	workshop.stamp()
	workshop.impact()
	var memory := workshop.session()
	workshop.begin(2, memory)
	expect(workshop.marked and workshop.damaged and workshop._mark.visible and workshop._panel.rotation.y > 0, "Restoring the memory trial erases the visible panel state")
	workshop.reset_environment()
	expect(workshop.marked and not workshop.damaged and workshop._mark.visible and not workshop._damage.visible, "Candidate soft reset does not distinguish memory from geometric damage")
	workshop.reconnect()
	expect(not workshop.marked and not workshop.damaged, "Full reconnection retains candidate memory")
	workshop.start_peer()
	await settle(0.3)
	var before_pause: Vector3 = workshop._person._walkers[0].position
	workshop.process_mode = Node.PROCESS_MODE_DISABLED
	await settle(0.3)
	expect(workshop._person._walkers[0].position == before_pause and not workshop.marked, "Paused colleague advances a physical sequence")
	workshop.process_mode = Node.PROCESS_MODE_INHERIT
	workshop.begin(2)
	expect(not workshop.peer_running and workshop.peer_result.is_empty(), "Interrupted colleague supplies a completed result")
	workshop.start_peer()
	await peer_finished()
	expect(workshop.peer_result.get("retained_after_reset", false) and workshop.peer_result.get("cleared_after_reconnect", false) and not workshop.marked, "Independent candidate sequence does not perform both resets on the real panel")
	workshop.change_mode()
	workshop.stamp()
	workshop.impact()
	workshop.reset_environment()
	expect(not workshop.marked and not workshop.damaged, "Reference soft reset retains candidate memory")
	workshop.start_peer()
	await peer_finished()
	expect(not workshop.peer_result.get("retained_after_reset", true) and workshop.peer_result.get("cleared_after_reconnect", false), "Independent response ignores the actually selected reference version")
	workshop.queue_free()
	observer.queue_free()
	await process_frame
	print("CAMPAIGN_OWN_CASE_PHYSICS: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
