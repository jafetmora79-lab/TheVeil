extends SceneTree
## The finale's people stand at clear, spaced places: in the station's refuge, at the chamber's entrance, in the passage corridor and by the tunnel mouth.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/finale_npcs_test.gd
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c: fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)"); quit(1))
func min_gap(pts: Array) -> float:
	var m := 1e9
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			m = minf(m, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	return m
func clear_at(world, player, w: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.4
	q.shape = cap
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), w + Vector3(0, 0.95, 0))
	for h in world.get_world_3d().direct_space_state.intersect_shape(q, 6):
		if not (h["collider"] is VeilSurvivorBody) and h["collider"] != player:
			return false
	return true
func _run() -> void:
	var game = root.get_node("Game")
	var DEV = load("res://game/chapters/setups/dev_chapter15.gd")
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	for i in 120: await process_frame
	var c5 = world.phase4.chapter5; var c10 = c5.chapter6.chapter7.chapter8.chapter9.chapter10
	var c13 = c10.chapter11.chapter12.chapter13
	var c15 = c13.chapter14.chapter15
	var player = world.player
	# the refuge
	var names: Array = c15.present()
	var pts: Array = []
	for k in names:
		pts.append(c15._node(k).global_position)
	ok("refuge_people", names.size() >= 3, str(names))
	ok("refuge_spaced", min_gap(pts) >= 1.1, "min gap %.2f m" % min_gap(pts))
	var all_clear := true
	for k in names:
		var n: Node3D = c15._node(k)
		if not clear_at(world, player, n.global_position):
			all_clear = false
	ok("refuge_clear_floor", all_clear)
	ok("refuge_spots_counted", int(c15.report.get("refuge_spots", 0)) >= names.size(), str(c15.report.get("refuge_spots", 0)))
	# the chamber entrance, the corridor, the tunnel mouth: the helper on their anchors
	var tests := {"chamber": [c15.GREAT + Vector3(-2.4, 0, -12.5), 1.6, 1.3], "corridor": [c13.U_ENTRY + Vector3(-0.5, 0, 2.4), 0.9, 0.95], "tunnel": [Vector3(26.5, 0, 66.0), 1.5, 1.4]}
	for key in tests:
		var base: Vector3 = tests[key][0]
		var step: float = tests[key][1]
		var an := {}
		var nm: Array = []
		for i in 4:
			nm.append("N%d" % i)
			an["N%d" % i] = base + Vector3(step * (i % 2 if key == "corridor" else i), 0, -0.9 * (i / 2) if key == "corridor" else 0.0)
		await physics_frame
		var sp: Dictionary = c15._free_spots(nm, an, c15.UL, [], float(tests[key][2]), 2.4)
		var plist: Array = []
		var near := true
		var clr := true
		for k in nm:
			plist.append(sp[k])
			if Vector2(sp[k].x - an[k].x, sp[k].z - an[k].z).length() > 2.6:
				near = false
			if not clear_at(world, player, c15.UL(sp[k])):
				clr = false
		ok("%s_spaced" % key, min_gap(plist) >= float(tests[key][2]) - 0.01, "min gap %.2f" % min_gap(plist))
		ok("%s_near_anchors" % key, near)
		ok("%s_clear" % key, clr)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
