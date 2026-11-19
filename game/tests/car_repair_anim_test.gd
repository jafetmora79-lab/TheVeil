extends SceneTree
## THE VEIL - fitting the parts at the player's car (the player walks there; the battery, fuse box and relay box end
## up in plausible, visible places and stay after a load), riders face the windscreen, Space jumps. Headless.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/car_repair_anim_test.gd

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame
		if w and is_instance_valid(w) and w.phase4 and w.phase4.choice.is_open():
			w.phase4.choice.pick(-1)


func _initialize() -> void:
	_run.call_deferred()
	create_timer(220.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _world(game: Node) -> void:
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(200)


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	game.set_flag("vehicle_found")
	await _world(game)
	var ex = w.expedition
	var q = ex.quest
	var car: Node3D = w.sedan
	var p: CharacterBody3D = w.player
	# ---- Space jumps (on foot)
	p.global_position = car.global_transform * Vector3(-3.0, 0.2, -4.0)
	p.controls_enabled = true
	await frames(30)
	var y0 := p.global_position.y
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var top := y0
	for i in 40:
		await frames(1)
		top = maxf(top, p.global_position.y)
	await frames(60)
	ok("space_jumps", top - y0 > 0.4 and p.is_on_floor(), "%.2f m" % (top - y0))
	# ---- the fittings
	var walked := {}
	for id in ["fuel_can", "car_battery", "car_fuse", "starter_relay"]:
		game.add_item(id)
		p.global_position = car.global_transform * Vector3(2.5, 0.2, 2.5)
		await frames(5)
		var before := p.global_position
		await ex._fit(id)
		await frames(5)
		walked[id] = p.global_position.distance_to(before) > 1.0
		ok("fit_" + id, ex.installed(id))
	ok("player_walks_to_each", walked.values().all(func(v): return v), str(walked))
	var bat := car.get_node_or_null("CQ_Fitted_car_battery") as Node3D
	var bl: Vector3 = car.global_transform.affine_inverse() * bat.global_position if bat else Vector3.INF
	ok("battery_in_engine_bay", bat != null and bl.z < -1.2 and bl.z > -2.3 and bl.y > 0.2 and bl.y < 0.9, str(bl))
	var fb := car.get_node_or_null("CQ_Fitted_fuse_box") as Node3D
	var fl: Vector3 = car.global_transform.affine_inverse() * fb.global_position if fb else Vector3.INF
	ok("fuse_box_in_bay", fb != null and fl.z < -1.2 and fb.get_node("Fuse_Good").visible, str(fl))
	var rb := car.get_node_or_null("CQ_Fitted_relay_box") as Node3D
	var rl: Vector3 = car.global_transform.affine_inverse() * rb.global_position if rb else Vector3.INF
	ok("relay_box_on_bumper", rb != null and rl.z < -2.38 and rl.y > 0.15 and rl.y < 0.7 and rb.get_node("Relay").visible, str(rl))
	ok("no_can_left", car.get_node_or_null("CQ_PouringCan") == null)
	# ---- a rider faces the windscreen
	var an = w.animators["Eddie"]
	var body: Node3D = an.root
	body.global_transform = Transform3D(car.global_basis * Basis(Vector3.UP, 2.0), body.global_position)
	preload("res://game/world/survivors.gd").face_forward(body, an, car)
	var fwd: Vector3 = an.world_forward()
	var cf := -car.global_basis.z * Vector3(1, 0, 1)
	ok("rider_faces_forward", fwd.dot(cf.normalized()) > 0.97, "dot %.2f" % fwd.dot(cf.normalized()))
	# ---- after a load the parts are still fitted (once)
	game.save_game()
	w.queue_free()
	await frames(5)
	game.load_game()
	game.load_requested = true
	await _world(game)
	car = w.sedan
	ok("fitted_after_load", car.find_children("CQ_Fitted_car_battery", "", false, false).size() == 1
		and car.get_node_or_null("CQ_Fitted_fuse_box") != null and car.get_node_or_null("CQ_Fitted_relay_box") != null)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
