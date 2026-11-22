extends SceneTree
## Displayed Chapter 11 (chapter10.gd) staging: every marker is clear for the body that uses it (door, gate and trunk open), the routes over the real floors (steps, raised house floor) are swept clear,
## a closed gate must STOP a route, the companions really cross the gate and the house door line when the mover walks them, the camera targets are visible (the see-through fence ignored), the hound is
## hidden at the end of its path, and the window gives a view of the countryside.
var fails := 0
var w: Node
var c10: Node
var mv: Node
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(170.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _fl(p: Vector3) -> Vector3:
	return Vector3(p.x, c10._floor(p), p.z)
func _swept(r: Array, radius := 0.28) -> bool:
	for i in range(1, r.size()):
		if not mv.step_clear(r[i - 1], r[i], radius, [0.5, 1.3]):
			return false
	return true
func _leg(name: String, a: Vector3, b: Vector3) -> void:
	var r: Array = mv.route(a, b, 0.28, [0.5, 1.3])
	ok("route_" + name, not r.is_empty() and (r[r.size() - 1] as Vector3).distance_to(b) < 0.05 and _swept(r), "pts %d" % r.size())
func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	c10 = load("res://game/world/chapter10.gd").new()
	root.add_child(c10)
	c10.world = w
	c10.player = w.player
	c10.house = w.get_node("Residential/Houses/MILL_HOUSE")
	w.clear_story_glass(c10.house)
	mv = load("res://game/world/scene_mover.gd").new()
	root.add_child(mv)
	mv.setup(w, w.player)
	c10.mover = mv
	c10._setup_car()
	c10._setup_roadblock()
	c10._setup_fence()
	c10._setup_house()
	var C = load("res://game/world/chapter10.gd")
	c10._open_driver_door(true)
	c10._open_trunk(true)
	var gate: Interactable = c10.its["gate"]
	var door: Interactable = c10.its["door"]
	gate.set_open(true, true)
	door.set_open(true, true)
	for i in 10: await physics_frame
	# markers: free for a body of 0.28 with the door, trunk, gate and house door OPEN
	var marks := {"DRIVER_STAND": C.DRIVER_STAND, "TRUNK_STAND": C.TRUNK_STAND, "ROADBLOCK_VIEW": C.ROADBLOCK_VIEW, "GATE_APPROACH": C.GATE_APPROACH, "GATE_CLEAR": C.GATE_CLEAR, "REVEAL_AREA": C.REVEAL_AREA}
	for k in C.CAR_WAIT:
		marks["WAIT_" + k] = C.CAR_WAIT[k]
	for k in C.SARAH_POCKET:
		marks["POCKET_" + k] = C.SARAH_POCKET[k]
	for k in marks:
		var p: Vector3 = marks[k]
		ok("marker_free_" + k, mv.free_at(_fl(p), 0.28, [0.5, 1.3]))
	var hmarks := {"SPOT_Eddie": C.SPOTS["Eddie"], "SPOT_Ruth": C.SPOTS["Ruth"], "SPOT_Sarah": C.SPOTS["Sarah"], "SPOT_Marcus": C.SPOTS["Marcus"], "WAKE_POS": C.WAKE_POS, "WINDOW_VIEW": C.WINDOW_VIEW}
	for k in hmarks:
		ok("marker_free_" + k, mv.free_at(c10._hfloor(hmarks[k]), 0.28, [0.5, 1.3]))
	# the pocket and the car spots are distinct (no companion inside another)
	var worst := 99.0
	var keys: Array = C.SARAH_POCKET.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			worst = minf(worst, (C.SARAH_POCKET[keys[i]] as Vector3).distance_to(C.SARAH_POCKET[keys[j]]))
	ok("pocket_spots_apart", worst >= 0.6, "%.2f" % worst)
	# routes over the real ground
	_leg("car_wait_Eddie", _fl(Vector3(-20.0, 0.15, 0.5)), _fl(C.CAR_WAIT["Eddie"]))
	_leg("to_driver_stand", _fl(C.CAR_WAIT["Eddie"]), _fl(C.DRIVER_STAND))
	_leg("to_trunk_stand", _fl(C.DRIVER_STAND), _fl(C.TRUNK_STAND))
	_leg("block_view_to_side_route", _fl(C.ROADBLOCK_VIEW), _fl(C.SIDE_ROUTE[0]))
	_leg("through_the_gap", _fl(C.SIDE_ROUTE[0]), _fl(C.SIDE_ROUTE[1]))
	_leg("gate_open_crossing", _fl(C.GATE_APPROACH), _fl(C.GATE_CLEAR))
	_leg("gate_to_reveal_area", _fl(C.GATE_CLEAR), _fl(C.REVEAL_AREA))
	# a house entrance over the real steps: outside, porch, door, room
	var outside := Vector3(c10.hl(Vector3(0.6, 0.0, -3.0)).x, 0.0, c10.hl(Vector3(0.6, 0.0, -3.0)).z)
	outside = _fl(outside)
	for k in C.SPOTS:
		var spot: Vector3 = c10._hfloor(C.SPOTS[k])
		_leg("house_entry_" + k, outside, spot)
	# the roadblock must STOP a route and a walker (the van, the pickup and the barriers shut the road)
	var blocked: Array = mv.route(_fl(C.ROADBLOCK_VIEW), _fl(Vector3(-52.0, 0.15, 0.0)), 0.28, [0.5, 1.3])
	ok("roadblock_blocks_the_route", blocked.is_empty(), "pts %d" % blocked.size())
	var eddie: Node3D = w.eddie
	eddie.global_position = _fl(C.ROADBLOCK_VIEW)
	var ea: Dictionary = mv.actor(eddie, w.animators.get("Eddie"), "person")
	var res := [false, false]
	var r1 := func():
		res[0] = await mv.move(ea, _fl(Vector3(-52.0, 0.15, 0.0)), 5.0)
		res[1] = true
	r1.call()
	var g := 0
	while not res[1] and g < 600:
		await process_frame
		g += 1
	ok("walker_refuses_the_roadblock", res[1] and not res[0] and eddie.global_position.x > C.BLOCK_X + 0.5, "x %.2f" % eddie.global_position.x)
	ok("refusal_is_reported", mv.failures.size() > 0)
	# the open gate: the walker really crosses it (measured)
	eddie.global_position = _fl(C.GATE_APPROACH)
	var crossed := false
	var res2 := [false, false]
	var r2 := func():
		res2[0] = await mv.move(ea, _fl(C.GATE_CLEAR), 5.0)
		res2[1] = true
	r2.call()
	g = 0
	while not res2[1] and g < 600:
		await process_frame
		g += 1
		if eddie.global_position.x < C.FENCE_X - 0.5:
			crossed = true
	if not (res2[1] and res2[0]):
		var q := PhysicsShapeQueryParameters3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.32
		q.shape = sp
		q.collision_mask = 1
		for hh in [0.5, 1.3]:
			q.transform = Transform3D(Basis(), eddie.global_position + Vector3(0, hh, 0))
			for hit in w.get_world_3d().direct_space_state.intersect_shape(q, 4):
				print("DBG at h=", hh, " collides with ", (hit["collider"] as Node).get_path())
	ok("walker_crosses_the_open_gate", res2[1] and crossed and eddie.global_position.x < C.FENCE_X - 0.8, "x %.2f res %s fails %s" % [eddie.global_position.x, str(res2), str(mv.failures.slice(-2))])
	# the house door line is crossed by the walker, in order, before it stands in the room
	eddie.global_position = outside
	var spot_e: Vector3 = c10._hfloor(C.SPOTS["Eddie"])
	var res3 := [false, false]
	var r3 := func():
		res3[0] = await mv.move(ea, spot_e, 5.0)
		res3[1] = true
	r3.call()
	var line_crossed := false
	g = 0
	while not res3[1] and g < 900:
		await process_frame
		g += 1
		var l: Vector3 = c10.house.to_local(eddie.global_position)
		if l.z > C.DOOR_LINE_Z and absf(l.x - 0.6) < 2.6:
			line_crossed = true
	var el: Vector3 = c10.house.to_local(eddie.global_position)
	ok("walker_crosses_the_house_door_line", res3[1] and res3[0] and line_crossed, "frames %d res %s local %s fails %s" % [g, str(res3), str(el), str(mv.failures.slice(-2))])
	# camera targets
	var eye_block := Vector3(C.ROADBLOCK_VIEW.x, c10._floor(C.ROADBLOCK_VIEW) + 1.62, C.ROADBLOCK_VIEW.z)
	ok("view_van", c10._see_prop(eye_block, w.get_node("C10_Block_Van")))
	ok("view_pickup", c10._see_prop(eye_block, w.get_node("C10_Block_Pickup")))
	var eye_rev := Vector3(C.REVEAL_AREA.x, c10._floor(C.REVEAL_AREA) + 1.62, C.REVEAL_AREA.z)
	var visible_pts := 0
	for pt in [C.HOUND_PATH_PTS[0], C.HOUND_PATH_PTS[0].lerp(C.HOUND_PATH_PTS[1], 0.3)]:
		if c10._see(eye_rev, Vector3(pt.x, 0.8, pt.z)):
			visible_pts += 1
	ok("hound_visible_at_the_start", visible_pts >= 1, str(visible_pts))
	var end_pt: Vector3 = C.HOUND_PATH_PTS[2]
	ok("hound_hidden_at_the_end_behind_a_building", not c10._see(eye_rev, Vector3(end_pt.x, 0.8, end_pt.z)))
	# the window: a view out of it, not at a wall
	var weye: Vector3 = c10._hfloor(C.WINDOW_VIEW) + Vector3(0, 1.62, 0)
	var outv: Vector3 = c10.window_target(weye)
	ok("window_gives_a_view", c10._see(weye, outv))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
