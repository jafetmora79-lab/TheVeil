extends SceneTree
## The Colossus' stomps: a landing leaves a footprint, fells trees in the forest, and is skipped on a building; the landing comes when the foot touches down.
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c: fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)"); quit(1))
func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var sc = load("res://game/world/scatter.gd").new()
	sc.name = "Scatter"
	stage.add_child(sc)
	var house := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(12, 8, 10)
	cs.shape = bs
	house.add_child(cs)
	stage.add_child(house)
	await process_frame
	var tc = VeilTripodColossus.new()
	stage.add_child(tc)
	tc.build(40.0, 0.15)
	tc.global_position = Vector3(222, 0.15, 330)
	tc.set_walking(true, 1.0)
	var st = tc.enable_stomps()
	ok("scatter_found", st.scatter == sc)
	house.position = Vector3(232.5, 4.15, 294)
	var landed := []
	st.stomped.connect(func(p, r): landed.append(p))
	var feet_low := true
	for i in 60 * 24:
		await physics_frame
		tc.global_position += Vector3(0, 0, -1) * tc.ground_speed() / 60.0
	ok("prints_left", st.count >= 4, "count %d" % st.count)
	ok("trees_felled", st.felled >= 1, "felled %d" % st.felled)
	ok("blocked_on_house", st.blocked_count >= 1, "blocked %d" % st.blocked_count)
	ok("prints_in_scene", st.prints.size() == st.count)
	# every landing within 24 s of walking: about 3 per 8 s cycle at speed 1
	ok("about_nine_landings", st.count + st.blocked_count >= 7 and st.count + st.blocked_count <= 11, "%d" % (st.count + st.blocked_count))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
