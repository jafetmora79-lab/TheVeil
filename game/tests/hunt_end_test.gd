extends SceneTree
## Review notes #102 / #104 / #105 / #26: the hunt ends by asking when you come back in (doors shut behind you, a summary), doors shut again on the hunt when nobody is at them, and creatures never spawn in the player's gaze.
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0


func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(200.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game = root.get_node("Game")
	game.no_save = true
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	game.world_state["supply_grace"] = true
	game.flags["fridge_checked"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(60)
	var ex = w.expedition
	var c5 = w.phase4.chapter5
	var p4 = w.phase4
	w.sidearm.st()["given"] = true                                  # (the gun handover is its own scene)
	ex.start("scavenge", false)
	var d0: bool = c5._doors_open
	c5._set_doors(true)
	await frames(10)
	ok("trip_active_doors_open", ex.active() and c5._doors_open, "active=%s open_now=%s imm=%s instore=%s hp=%s pos=%s" % [ex.active(), c5._doors_open, d0, ex.in_store(), w.sidearm.handover_pending(), w.market.to_local(w.player.global_position)])
	# out, away from the doors: the doors shut by themselves after a while (#102)
	w.player.global_position = w.market.to_global(Vector3(0.3, 0.2, -14.0))
	await frames(60 * 6)
	ok("doors_shut_on_hunt", not c5._doors_open, str(c5._doors_open))
	# back in: the question (#105)
	w.player.global_position = w.market.to_global(Vector3(2.0, 0.2, 8.0))
	await frames(60)
	ok("end_question", p4.choice.is_open() and "END THE SCAVENGING HUNT" in p4.choice._title.text)
	p4.choice.pick(0)
	await frames(30)
	ok("hunt_secured", not ex.active() and ex.summary_shown and not c5._doors_open)
	# spawn rule (#26): no spawn point within 55 degrees of where the camera looks
	var cam: Camera3D = w.get_viewport().get_camera_3d()
	var bad := 0
	var tried := 0
	for i in 20:
		var at: Vector3 = ex.find_spawn(32.0, 60.0, w.player.global_position)
		if at.is_finite():
			tried += 1
			var look := -cam.global_basis.z
			look.y = 0.0
			var to := at - cam.global_position
			to.y = 0.0
			if look.normalized().angle_to(to.normalized()) < deg_to_rad(55.0):
				bad += 1
	ok("spawns_not_in_gaze", bad == 0, "%d of %d inside the gaze" % [bad, tried])
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
