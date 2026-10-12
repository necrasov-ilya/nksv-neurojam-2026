extends SceneTree

const Workshop = preload("res://scripts/campaign/workshop.gd")
var failed := false
var workshop: Workshop
var camera: Camera3D

func _initialize() -> void:
	check.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func settle(seconds: float) -> void:
	await create_timer(seconds).timeout

func seat_cube() -> float:
	workshop.pickup(0)
	workshop.selected_body().position = Workshop.GAUGE + Vector3(0, 2.0, 0)
	workshop.release()
	await settle(2.0)
	workshop.measure()
	return workshop.objects[0].position.y

func throw_distance(heavy: bool) -> float:
	workshop.reset_environment()
	workshop.pickup(1)
	if heavy:
		workshop.change_weight()
	workshop.selected_body().position = Vector3(3.8, 1.3, 1.0)
	camera.position = Vector3(3.8, 1.3, 3.0)
	camera.rotation = Vector3.ZERO
	workshop.throw_object(camera)
	await settle(0.35)
	return 1.0 - workshop.objects[1].position.z

func bounce_speed(candidate: bool) -> float:
	workshop.begin(3, {"control_mode": not candidate})
	workshop.pickup(1)
	workshop.change_elasticity()
	workshop.selected_body().position = Vector3(0, 2.5, -1.2)
	workshop.release()
	var maximum := 0.0
	for tick in 100:
		await physics_frame
		maximum = maxf(maximum, workshop.objects[1].linear_velocity.y)
	return maximum

func peer_finished() -> void:
	for tick in 1800:
		if not workshop.peer_running:
			return
		await physics_frame
	expect(false, "Colleague never completes the independent panel verification")

func check() -> void:
	workshop = Workshop.new()
	root.add_child(workshop)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	workshop.begin(1)
	var normal_height: float = await seat_cube()
	workshop.resize_object(1)
	var reference_height: float = await seat_cube()
	expect(normal_height < 0.7 and reference_height > 1.2, "Real enlarged cube does not rest on the measuring rails while the original fits")
	workshop.change_mode()
	for trial in 2:
		workshop.resize_object(1)
		var candidate_height: float = await seat_cube()
		expect(candidate_height < 0.7 and reference_height - candidate_height > 0.5, "Candidate size mismatch is not reproducible in real physics")
		if trial == 0:
			workshop.reset_environment()
	var saved := workshop.session()
	workshop.begin(1, saved)
	await settle(0.3)
	expect(workshop.objects[0].position.y < 0.7, "Restored candidate silently fixes its physical size")
	workshop.begin(3)
	workshop.resize_object(1)
	var fixed_height: float = await seat_cube()
	expect(fixed_height > 1.2, "Fixed version keeps the previous size mismatch")
	var light_distance: float = await throw_distance(false)
	var heavy_distance: float = await throw_distance(true)
	expect(light_distance > heavy_distance * 2.0 and heavy_distance > 0.3, "Real throw ignores selected mass or never moves the object")
	workshop.reset_environment()
	workshop.pickup(1)
	workshop.selected_body().position = Vector3(3.8, 1.3, -3.0)
	camera.position = Vector3(3.8, 1.3, -1.0)
	camera.rotation = Vector3.ZERO
	workshop.throw_object(camera)
	await settle(0.6)
	expect(workshop.exercises.has("target"), "Hitting the actual target does not produce an observed collision")
	var reference_bounce: float = await bounce_speed(false)
	var candidate_bounce: float = await bounce_speed(true)
	expect(reference_bounce > 3.0 and candidate_bounce < reference_bounce * 0.4, "Candidate elasticity fault does not change the physical bounce")
	workshop.begin(1)
	workshop.pickup(2)
	workshop.resize_object(1)
	workshop.change_weight()
	workshop.change_elasticity()
	workshop.selected_body().position = Vector3(1, 1.5, 0)
	workshop.release()
	saved = workshop.session()
	workshop.begin(1, saved)
	var restored := workshop.selected_body()
	expect(workshop.selected == 2 and restored.mass == 6.0 and restored.position.distance_to(Vector3(1, 1.5, 0)) < 0.01, "Session restoration loses the selected cylinder, its mass or position")
	workshop.set_active(false)
	workshop.process_mode = Node.PROCESS_MODE_DISABLED
	var positions: Array[Vector3] = []
	for object in workshop.objects:
		positions.append(object.position)
	await settle(0.25)
	for index in workshop.objects.size():
		expect(workshop.objects[index].position == positions[index], "Paused laboratory advances one of its physical objects")
	workshop.process_mode = Node.PROCESS_MODE_INHERIT
	workshop.set_active(true)
	workshop.reset_environment()
	for object in workshop.objects:
		expect(object.mass == 1.5, "Reset leaves heavy mass on an unselected object")
	workshop.begin(2)
	workshop.stamp()
	workshop.impact()
	var memory := workshop.session()
	workshop.begin(2, memory)
	expect(workshop.marked and workshop.damaged and workshop._mark.visible and workshop._panel.rotation.y > 0, "Restoring the memory trial erases the visible panel state")
	workshop.reset_environment()
	expect(workshop.marked and not workshop.damaged and workshop._mark.visible and not workshop._damage.visible, "Candidate soft reset does not distinguish memory from damage")
	workshop.reconnect()
	expect(not workshop.marked and not workshop.damaged, "Full reconnection retains candidate memory")
	workshop.start_peer()
	await settle(0.3)
	var before_pause: Vector3 = workshop._person._walkers[0].position
	workshop.process_mode = Node.PROCESS_MODE_DISABLED
	await settle(0.3)
	expect(workshop._person._walkers[0].position == before_pause and not workshop.marked, "Paused colleague advances the independent sequence")
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
	expect(not workshop.peer_result.get("retained_after_reset", true) and workshop.peer_result.get("cleared_after_reconnect", false), "Independent response ignores the selected reference version")
	workshop.queue_free()
	camera.queue_free()
	await process_frame
	var run: Node = root.get_node("GameRun")
	run.new_run()
	run.day_briefed = true
	run.location = "stand"
	run.active_case = "object_state"
	var campaign: Node3D = load("res://scripts/campaign/campaign.gd").new()
	root.add_child(campaign)
	campaign.player.set_physics_process(false)
	await physics_frame
	for control in [true, false]:
		campaign.workshop.begin(1, {"control_mode": control})
		campaign.player.place(campaign.workshop.to_global(Vector3(-3.8, 0.03, -0.1)), 0)
		campaign.player.camera.look_at(campaign.workshop.to_global(Workshop.GAUGE + Vector3.UP * 0.2))
		campaign.workshop.pickup(0)
		campaign.workshop.resize_object(1)
		expect(campaign._find_action() == "place_object", "Off-axis reset button steals the held-object placement action")
		campaign._use("place_object")
		await settle(2.0)
		var seated: RigidBody3D = campaign.workshop.objects[0]
		expect(seated.position.y > 1.2 if control else seated.position.y < 0.7, "E placement forces the enlarged reference cube inside solid rails or hides the candidate defect")
	campaign.queue_free()
	await process_frame
	print("CAMPAIGN_OWN_CASE_PHYSICS: ", "FAIL" if failed else "PASS", " / seat=", reference_height, " fixed=", fixed_height, " / throw=", light_distance, "/", heavy_distance, " / bounce=", reference_bounce, "/", candidate_bounce)
	quit(1 if failed else 0)
