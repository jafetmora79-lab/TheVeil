extends SceneTree
## The Grimtalons: the model loads and flies (wings beat, legs tuck / hang), the flock weaves, the abduction swoops down, takes a man by the shoulders and climbs away with him.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/grimtalon_test.gd
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
	var G = load("res://game/animals/grimtalon.gd")
	var holder := Node3D.new()
	root.add_child(holder)
	var g = G.spawn(holder, Vector3(0, 40, 0))
	g.fly_circle(Vector3.ZERO, 30.0, 40.0, 10.0)
	var tipi: int = g._idx["Bone_046"]
	var lo := 1e9
	var hi := -1e9
	var moved := 0.0
	var last: Vector3 = g.global_position
	for i in 180:
		await process_frame
		var y: float = g.skel.get_bone_global_pose(tipi).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		moved += g.global_position.distance_to(last)
		last = g.global_position
	ok("flies_circle", moved > 20.0, "%.1f m in 3 s" % moved)
	ok("wingtip_beats", hi - lo > 0.4, "right wingtip y range %.2f (model units)" % (hi - lo))
	var span: float = absf(g.skel.get_bone_global_pose(g._idx["Bone_046"]).origin.x - g.skel.get_bone_global_pose(g._idx["Bone_054"]).origin.x)
	ok("wings_spread", span > 1.2, "tip to tip %.2f" % span)
	var toe: Vector3 = g.skel.get_bone_global_pose(g._idx["Bone_017"]).origin
	var hip: Vector3 = g.skel.get_bone_global_pose(g._idx["Bone_000"]).origin
	ok("legs_tucked_back", toe.z < hip.z + 0.1, "toe z %.2f hip z %.2f" % [toe.z, hip.z])
	# a flock
	var birds: Array = G.flock(holder, 9, Vector3.ZERO, null, Vector2(30, 80), Vector2(30, 70), Vector2(8, 12))
	for i in 60:
		await process_frame
	var radii := {}
	for b in birds:
		radii[snappedf(Vector2(b.global_position.x, b.global_position.z).length(), 5.0)] = true
	ok("flock_spread", birds.size() == 9 and radii.size() >= 4, "%d birds, %d different radii" % [birds.size(), radii.size()])
	for b in birds:
		b.queue_free()
	g.queue_free()
	# the abduction
	var man := Node3D.new()
	holder.add_child(man)
	man.global_position = Vector3(100, 0, 50)
	var b2 = G.spawn(holder, Vector3(0, 60, 0))
	var states := []
	var closest := 1e9
	var grip_err := 0.0
	var h0 := 0.0
	var cb := func(s: String): states.append(s)
	var fin := [false]
	var run := func():
		await b2.abduct(man, Vector3(-1, 0, 0.3), cb, Vector3(0.7, 0, 0.7))
		fin[0] = true
	run.call()
	var t := 0
	while not fin[0] and t < 60 * 20:
		await process_frame
		t += 1
		if "grab" in states and not "carry" in states:
			closest = minf(closest, b2.grip_point().distance_to(man.global_position + Vector3(0, 1.45, 0)))
		if "carry" in states and t % 10 == 0:
			grip_err = maxf(grip_err, b2.grip_point().distance_to(man.global_position + Vector3(0, 1.45, 0)))
	ok("abduct_states", states == ["dive", "grab", "carry", "gone"], str(states))
	ok("abduct_carries_up", man.global_position.y > 40.0, "man at y %.1f after %.1f s" % [man.global_position.y, t / 60.0])
	ok("abduct_holds_shoulders", grip_err < 0.2, "max grip error %.3f" % grip_err)
	ok("abduct_finishes", fin[0] and t < 60 * 15)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
