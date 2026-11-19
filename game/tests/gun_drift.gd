extends SceneTree
## dev tool: walk forward with the gun drawn on open ground; log player and gun-view motion
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	world.player.controls_enabled = true
	world.hud.fade_to(0.0, 0.01)
	var sa = world.sidearm
	var space = world.get_world_3d().direct_space_state
	var c0: Vector3 = world.player.global_position
	var spot := Vector3.ZERO
	var found := false
	for gx in range(-80, 81, 8):
		for gz in range(-80, 81, 8):
			var top := c0 + Vector3(gx, 8.0, gz)
			var qd := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -30, 0), 1, [world.player.get_rid()])
			var hd = space.intersect_ray(qd)
			if hd.is_empty() or hd["position"].y > c0.y + 1.0 or hd["position"].y < c0.y - 1.0:
				continue
			var p: Vector3 = hd["position"] + Vector3(0, 1.0, 0)
			var ok := true
			for k in 16:
				var a := k * TAU / 16.0
				var q := PhysicsRayQueryParameters3D.create(p, p + Vector3(sin(a), 0, cos(a)) * 9.0, 1, [world.player.get_rid()])
				if not space.intersect_ray(q).is_empty():
					ok = false
					break
			if ok:
				spot = hd["position"]
				found = true
				break
		if found:
			break
	print("DRIFT open spot ", found, " ", spot, " start ", c0)
	if not found:
		quit(1)
		return
	world.player.global_position = spot + Vector3(0, 0.2, 0)
	await frames(30)
	game.add_item("handgun")
	await frames(10)
	sa.set_drawn(true)
	await frames(40)
	var fwd: Vector3 = -world.player.global_transform.basis.z
	var p0: Vector3 = world.player.global_position
	Input.action_press("move_forward")
	for i in 14:
		await frames(15)
		var d: Vector3 = world.player.global_position - p0
		print("DRIFT t=", i, " along ", snappedf(d.dot(fwd), 0.01), " vel ", world.player.velocity.snapped(Vector3(0.01, 0.01, 0.01)), " gun ", sa._view.position.snapped(Vector3(0.001, 0.001, 0.001)), " wall ", snappedf(sa._wall, 0.01))
	Input.action_release("move_forward")
	await frames(30)
	sa.set_drawn(false)
	await frames(30)
	p0 = world.player.global_position
	Input.action_press("move_forward")
	await frames(120)
	Input.action_release("move_forward")
	print("DRIFT holstered 2s along ", snappedf((world.player.global_position - p0).dot(fwd), 0.01))
	quit(0)
