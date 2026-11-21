extends SceneTree
## The woodland animals: the deer / rabbit clips play and the feet stay on the ground, the raven flies and beats its wings, and the deer on the road crosses
## in front of a moving car and misses it by a couple of metres.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/wildlife_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()
	create_timer(100.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	game.new_game()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 30:
		await process_frame
	ok("wildlife_exists", w.wildlife != null and w.wildlife.is_inside_tree())
	var Animal = load("res://game/animals/veil_animal.gd")
	# the plain ground out in the woods road area
	var base := Vector3(58.0, 0.15, 300.0)
	var deer = Animal.spawn(w, "deer", base, 0.0)
	var rab = Animal.spawn(w, "rabbit", base + Vector3(5, 0, 0), 0.0)
	var rav = Animal.spawn(w, "raven", base + Vector3(-5, 0, 0), 0.0)
	rav.fly_circle(base, 20.0, 18.0, 8.0)
	for i in 30:
		await process_frame
	ok("deer_idle_clip", deer.ap != null and deer.ap.is_playing() and String(deer.ap.current_animation) == "fawn_idle04", str(deer.ap.current_animation))
	ok("rabbit_idle_clip", rab.ap.is_playing() and String(rab.ap.current_animation).contains("Idle"))
	# walk and run: they move, the right clip plays, the feet are on the ground
	var p0: Vector3 = deer.global_position
	deer.run_to(p0 + Vector3(30, 0, 0))
	rab.walk_to(rab.global_position + Vector3(0, 0, 10))
	for i in 60:
		await process_frame
	ok("deer_runs", deer.global_position.distance_to(p0) > 6.0 and String(deer.ap.current_animation) == "fawn_run01", "%.1f m" % deer.global_position.distance_to(p0))
	ok("deer_faces_travel", absf(deer.global_transform.basis.z.dot(Vector3.RIGHT)) > 0.9)
	ok("rabbit_walks", String(rab.ap.current_animation).contains("Walk"))
	var low := 1e9
	for i in deer._toes:
		low = minf(low, deer.skel.get_bone_global_pose(i).origin.y)
	ok("deer_feet_on_ground", absf(deer.model.position.y + low * deer.model.scale.y) < 0.1, "toe %.3f" % (deer.model.position.y + low * deer.model.scale.y))
	# the raven: it moves round its circle, the wings are out and beating, the legs tucked
	var q0: Vector3 = rav.global_position
	var wing_min := 9.0
	var wing_max := -9.0
	var travelled := 0.0
	var last: Vector3 = rav.global_position
	for i in 120:
		await process_frame
		travelled += rav.global_position.distance_to(last)
		last = rav.global_position
		var bi: int = rav._bone_of["Bone_017"]
		var wy: float = (rav.skel.get_bone_global_pose(bi).basis * Vector3.DOWN).x       # the shoulder bone's direction
		wing_min = minf(wing_min, wy)
		wing_max = maxf(wing_max, wy)
	ok("raven_flies", travelled > 8.0, "%.1f m in 2 s" % travelled)
	ok("raven_wings_beat", wing_max - wing_min > 0.3, "range %.2f" % (wing_max - wing_min))
	var tip: Vector3 = rav.skel.get_bone_global_pose(rav._bone_of["Bone_016"]).origin
	ok("raven_wing_spread", tip.x > 0.5 and rav.global_position.y > 10.0, "right tip x %.2f (model units), y %.1f" % [tip.x, rav.global_position.y])
	deer.queue_free()
	rab.queue_free()
	rav.queue_free()
	# the deer on the road: a car at 14 m/s heading north (-z); the deer must cross its line ahead of it and clear it by 1.5-6 m
	var car: Node3D = w.sedan
	car.global_position = Vector3(184.0, 0.15, 250.0)
	car.global_transform.basis = Basis.IDENTITY
	car.speed = 14.0
	w.in_car = true
	car.driven = true
	for i in 75:
		await process_frame
	var d = w.wildlife._scare             # (started by the drive itself: out in the woods, heading to town, at speed)
	ok("scare_deer", d != null)
	var min_d := 1e9
	var min_speed := 99.0
	for i in 600:
		await process_frame
		if is_instance_valid(d):
			min_d = minf(min_d, d.global_position.distance_to(car.global_position))
	var stop_m: float = float(w.wildlife.report.get("scare_stop_m", -1.0))
	print("TEST scare_numbers INFO deer stopped %.2f m from the car's centre, closest %.2f m, car speed now %.1f" % [stop_m, min_d, car.speed])
	ok("scare_deer_stops_at_bumper", stop_m > 4.5 and stop_m < 7.5, "%.2f m" % stop_m)
	ok("scare_never_hits", min_d > 4.5, "%.2f m" % min_d)
	ok("scare_cinematic_done", w.wildlife.report.get("scare_done", false) and not car.drive_script.is_valid())
	ok("scare_once", w.wildlife.report["scare"] and game.has_flag("deer_scare_done"))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
