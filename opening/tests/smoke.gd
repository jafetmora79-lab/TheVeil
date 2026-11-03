extends SceneTree

var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://opening/opening.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	check(scene.targets.size() > 20, "Interaction metadata did not resolve")
	check(not scene.progress.can_leave(), "Departure must be locked initially")
	var front: Dictionary
	var fridge: Dictionary
	var keys: Dictionary
	for entry in scene.targets:
		if entry.node == "INT_Door_Front": front = entry
		if entry.node.contains("CarKeys"): keys = entry
		if entry.node.contains("ApplianceDoor_Fridge"): fridge = entry
	check(not front.is_empty() and not fridge.is_empty() and not keys.is_empty(), "Required targets absent")
	if failed:
		quit(1)
		return
	# Verify contextual selection at reachable interaction positions.
	scene.player.global_position = scene.home.to_global(Vector3(-4.6, 0.6, 7.5))
	scene.player.camera.look_at(scene.home.to_global(Vector3(-5.725, 1.51, 7.63)))
	scene._focus()
	check(not scene.focused.is_empty() and scene.focused.node == fridge.node, "Fridge cannot be targeted from kitchen")
	scene.player.global_position = scene.home.to_global(Vector3(-1.8, 0.6, 3.2))
	scene.player.camera.look_at(scene.home.to_global(Vector3(-1.155, 2.17, 2.417)))
	scene._focus()
	check(not scene.focused.is_empty() and scene.focused.node == keys.node, "Keys cannot be targeted from entry")
	scene.player.camera.rotation = Vector3.ZERO
	scene.player.global_transform = scene.home.get_node("Markers/Spawn_WakeUp").global_transform
	scene._interact(front)
	check(not scene.progress.departed, "Front door bypassed groceries/keys gate")
	scene._interact(keys)
	check(scene.progress.has_keys and not scene.progress.can_leave(), "Early key pickup must work without bypassing fridge")
	scene._interact(fridge)
	check(scene.progress.can_leave(), "Fridge and keys should unlock departure")
	scene._interact(front)
	check(scene.progress.departed, "Departure did not advance")
	await create_timer(0.6).timeout
	check(front.open and fridge.open, "Hinges did not retain state")
	# Walk the authored bed-to-door path with the real capsule and collisions.
	scene.player.enabled = false
	for entry in scene.targets:
		if entry.node == "INT_Door_Bedroom" and not entry.open:
			scene._interact(entry)
	await create_timer(0.6).timeout
	var markers = scene.home.get_node("Markers/WakePath").get_children()
	for marker in markers:
		var reached := false
		for step in range(600):
			var offset: Vector3 = marker.global_position - scene.player.global_position
			offset.y = 0
			if offset.length() < 0.16:
				reached = true
				break
			scene.player.velocity = offset.normalized() * 2.0
			scene.player.velocity.y = -2.0
			scene.player.move_and_slide()
			await physics_frame
		check(reached, "Capsule blocked on wake path at " + marker.name)
		if not reached: break
	# Traverse the kitchen branch with the same collision body, not teleports.
	scene.player.global_transform = scene.home.get_node("Markers/Spawn_WakeUp").global_transform
	var kitchen_path := [Vector3(-0.45, 0.6, 7.5), Vector3(-1.55, 0.6, 7.5), Vector3(-1.8, 0.6, 6.05), Vector3(-3.55, 0.6, 5.95), Vector3(-3.65, 0.6, 5.85), Vector3(-4.5, 0.6, 5.85), Vector3(-4.5, 0.6, 7.5)]
	for point in kitchen_path:
		var reached := false
		for step in range(500):
			var offset: Vector3 = scene.home.to_global(point) - scene.player.global_position
			offset.y = 0
			if offset.length() < 0.16:
				reached = true
				break
			scene.player.velocity = offset.normalized() * 2.0
			scene.player.velocity.y = -2.0
			scene.player.move_and_slide()
			await physics_frame
		check(reached, "Capsule blocked on kitchen route at " + str(point))
		if not reached: break
	# Drive using the actual W input and update loop, not a direct completion flag.
	scene._begin_drive()
	var parked: Vector3 = scene.drive_camera.global_position
	for step in range(30): scene._drive(1.0 / 60.0)
	check(scene.drive_camera.global_position.is_equal_approx(parked), "Car moved without throttle")
	Input.action_press("forward")
	for step in range(60): scene._drive(1.0 / 60.0)
	Input.action_release("forward")
	Input.action_press("back")
	for step in range(60): scene._drive(1.0 / 60.0)
	check(scene.drive_speed == 0, "Brake did not stop car")
	Input.action_release("back")
	Input.action_press("forward")
	for step in range(4000):
		scene._drive(1.0 / 60.0)
		if scene.progress.complete: break
	Input.action_release("forward")
	check(scene.progress.complete, "Drive never reached supermarket parking")
	check(scene.drive_camera.global_position.distance_to(scene.route[-1] + Vector3.UP * 1.2) < 0.1, "Arrival position incorrect")
	print("OPENING_SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
