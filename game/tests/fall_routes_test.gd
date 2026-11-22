extends SceneTree
## The Chapter 10 evacuation (game/world/evacuation.gd): every marker is free for the actor that uses it, every directed leg has a route that is SWEPT clear with the actor's own radius (a path
## that merely exists proves nothing), a route through a blocked opening must FAIL, the camera targets are actually visible, the doors have passable angles, and the phase table is complete.
var EVAC: GDScript
var fails := 0
var ev: Node
var w: Node
var m: Node3D
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(170.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _swept(r: Array, from: Vector3, radius: float, heights: Array) -> bool:
	var p := from
	for q in r:
		if not ev._step_clear(p, q, radius, heights):
			return false
		p = q
	return true
func _leg(name: String, from: Vector3, to: Vector3, radius: float, heights: Array) -> void:
	var r: Array = ev._route(from, to, radius, heights)
	var good: bool = not r.is_empty() and (r[r.size() - 1] as Vector3).distance_to(to) < 0.05 and _swept(r, from, radius, heights)
	ok("route_" + name, good, "pts %d" % r.size())
func _run() -> void:
	EVAC = load("res://game/world/evacuation.gd")
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	m = w.market
	var p4 = w.phase4
	ev = EVAC.new()
	root.add_child(ev)
	ev.world = w
	ev.market = m
	ev.player = w.player
	ev.p4 = p4
	var aisle: Node3D = load("res://game/world/gondola_aisle.gd").detach(m, Vector3(9.5, 0.0, 10.0), 90.0)
	# the phase table covers every phase
	var missing := 0
	for k in EVAC.Phase.values():
		if k != EVAC.Phase.IDLE and k != EVAC.Phase.DONE and not EVAC.PHASES.has(k):
			missing += 1
	ok("phase_table_complete", missing == 0, str(missing))
	var defined := true
	for k in EVAC.PHASES:
		var d: Dictionary = EVAC.PHASES[k]
		if not (d.has("actors") and d.has("doors") and d.has("input") and d.has("camera") and d.has("advance")):
			defined = false
	ok("phase_entries_defined", defined)
	# the shelf OPEN, doors as in the sequence
	aisle.position = Vector3(EVAC.AISLE_OPEN_X, 0.0, EVAC.AISLE_Z)
	aisle.rotation.y = 0.0
	var bd: Node3D = p4.its.get("back_door")
	var base: Transform3D = p4._base["back"]
	var dgr: float = w._toward_deg(bd, 88.0, m.to_global(Vector3(8.0, 1.0, 16.4)))
	bd.transform = Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(dgr)), base.origin)
	var staff = p4.its.get("INT_Door_Staff")
	staff.set_open(true, true)
	var pal: Node3D = p4._pallets.get("back")
	pal.position = Vector3(5.6, 0.04, 15.5)
	pal.rotation.y = 0.9
	p4.chapter5._set_doors(true)
	for i in 90: await physics_frame
	ok("rear_passable", Quaternion(base.basis).angle_to(Quaternion(bd.transform.basis)) > deg_to_rad(70.0))
	ok("staff_passable", Quaternion(staff._base.basis).angle_to(Quaternion(staff.target.transform.basis)) > deg_to_rad(staff.open_deg) * 0.8)
	# markers free for the body that uses them
	var person_marks := {"Q_EDDIE": EVAC.Q_EDDIE, "Q_RUTH": EVAC.Q_RUTH, "Q_SARAH": EVAC.Q_SARAH, "WALT_FREEZE": EVAC.WALT_FREEZE, "PLAYER_OPEN": EVAC.PLAYER_OPEN, "MARCUS_OPEN": EVAC.MARCUS_OPEN,
		"MARCUS_DOWN": EVAC.MARCUS_DOWN, "PLAYER_RESCUE": EVAC.PLAYER_RESCUE, "STAFF_APPROACH": EVAC.STAFF_APPROACH, "STAFF_CLEAR": EVAC.STAFF_CLEAR, "REAR_INSIDE": EVAC.REAR_INSIDE,
		"REAR_CLOSE_POS": EVAC.REAR_CLOSE_POS, "PLAYER_REGROUP": EVAC.PLAYER_REGROUP, "MARCUS_OUTSIDE": EVAC.MARCUS_OUTSIDE, "OPENING_APPROACH": EVAC.OPENING_APPROACH,
		"OPENING_CLEAR": EVAC.OPENING_CLEAR, "VIEW_1": EVAC.VIEW_ROUTE[0], "VIEW_2": EVAC.VIEW_ROUTE[1], "MARCUS_VIEW": EVAC.MARCUS_VIEW}
	for k in person_marks:
		ok("marker_free_" + k, ev._free_at(person_marks[k], EVAC.PERSON_R, EVAC.HEIGHTS_PERSON))
	var out_wait := [Vector3(7.2, 0.04, 20.6), Vector3(8.8, 0.04, 21.2), Vector3(7.8, 0.04, 22.2)]
	for i in 3:
		ok("marker_free_out_wait_%d" % i, ev._free_at(out_wait[i], EVAC.PERSON_R, EVAC.HEIGHTS_PERSON))
	var hound_marks := {"HOUND_B_POST": EVAC.HOUND_B_POST, "HOUND_C_LURK": EVAC.HOUND_C_LURK, "HOUND_A_POST": EVAC.HOUND_A_POST}
	for k in hound_marks:
		ok("marker_free_hound_" + k, ev._free_at(hound_marks[k], EVAC.HOUND_R, EVAC.HEIGHTS_HOUND))
	ok("pullers_separated", absf(EVAC.PLAYER_CLOSED.z - EVAC.MARCUS_CLOSED.z) >= 0.64, str(EVAC.PLAYER_CLOSED.z - EVAC.MARCUS_CLOSED.z))
	# directed legs: person size, swept
	_leg("group_to_queue", Vector3(4.6, 0.04, 7.5), EVAC.Q_SARAH, EVAC.PERSON_R, EVAC.HEIGHTS_PERSON)
	aisle.position = Vector3(EVAC.AISLE_CLOSED_X, 0.0, EVAC.AISLE_Z)
	for i in 6: await physics_frame
	_leg("player_to_closed_end", Vector3(4.0, 0.04, 6.8), EVAC.PLAYER_CLOSED, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("marcus_to_closed_end", Vector3(4.6, 0.04, 7.5), EVAC.MARCUS_CLOSED, EVAC.PERSON_R, EVAC.HEIGHTS_PERSON)
	aisle.position = Vector3(EVAC.AISLE_OPEN_X, 0.0, EVAC.AISLE_Z)
	for i in 6: await physics_frame
	_leg("queue_through_opening", EVAC.Q_EDDIE, out_wait[0], EVAC.PERSON_R, EVAC.HEIGHTS_PERSON)
	_leg("view_route_1", EVAC.PLAYER_OPEN, EVAC.VIEW_ROUTE[0], EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("view_route_2", EVAC.VIEW_ROUTE[0], EVAC.VIEW_ROUTE[1], EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("return_to_push", EVAC.VIEW_ROUTE[1], EVAC.PLAYER_OPEN, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("rescue", EVAC.PLAYER_OPEN, EVAC.PLAYER_RESCUE, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("to_staff_door", EVAC.PLAYER_RESCUE, EVAC.STAFF_APPROACH, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("through_staff_door", EVAC.STAFF_APPROACH, EVAC.STAFF_CLEAR, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("corridor_to_rear", EVAC.STAFF_CLEAR, EVAC.REAR_CLOSE_POS, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	_leg("marcus_outside", EVAC.REAR_INSIDE, EVAC.MARCUS_OUTSIDE, EVAC.PERSON_R, EVAC.HEIGHTS_PERSON)
	# hounds: their own (larger) body
	_leg("hound_front_to_A", EVAC.FRONT_SPAWNS[0] + Vector3(0, 0.04, 0), EVAC.HOUND_A_POST, EVAC.HOUND_R, EVAC.HEIGHTS_HOUND)
	_leg("hound_front_to_B", EVAC.FRONT_SPAWNS[1] + Vector3(0, 0.04, 0), EVAC.HOUND_B_POST, EVAC.HOUND_R, EVAC.HEIGHTS_HOUND)
	_leg("hound_front_to_C", EVAC.FRONT_SPAWNS[2] + Vector3(0, 0.04, 0), EVAC.HOUND_C_LURK, EVAC.HOUND_R, EVAC.HEIGHTS_HOUND)
	_leg("hound_C_to_Marcus", EVAC.HOUND_C_LURK, Vector3(13.3, 0.04, 11.6), EVAC.HOUND_R, EVAC.HEIGHTS_HOUND)
	# an intentionally blocked route must FAIL: the shelf closed across the opening leaves no way through it
	aisle.position = Vector3(EVAC.AISLE_CLOSED_X, 0.0, EVAC.AISLE_Z)
	for i in 6: await physics_frame
	var blocked: Array = ev._route(Vector3(8.4, 0.04, 11.0), Vector3(8.4, 0.04, 15.0), EVAC.PERSON_R, EVAC.HEIGHTS_PERSON)
	var via_staff: Array = ev._route(Vector3(8.4, 0.04, 11.0), Vector3(15.0, 0.04, 15.5), EVAC.PERSON_R, EVAC.HEIGHTS_PERSON)
	ok("blocked_route_fails", blocked.is_empty(), "pts %d" % blocked.size())
	ok("closed_shelf_still_leaves_the_staff_door", not via_staff.is_empty(), "pts %d" % via_staff.size())
	ok("hound_radius_is_larger", EVAC.HOUND_R > EVAC.PERSON_R)
	# camera targets: Walt and hound A from the viewing point, Marcus pinned from the half-push position
	aisle.position = Vector3(EVAC.AISLE_OPEN_X, 0.0, EVAC.AISLE_Z)
	for i in 6: await physics_frame
	var eye := m.to_global(EVAC.VIEW_ROUTE[1] + Vector3(0, 1.62, 0))
	ok("los_viewpoint_to_walt", ev._line_clear(eye, m.to_global(EVAC.WALT_FREEZE + Vector3(0, 1.1, 0))))
	ok("los_viewpoint_to_hound_A", ev._line_clear(eye, m.to_global(EVAC.HOUND_A_POST + Vector3(0, 0.7, 0))))
	var half := Vector3(10.4, 0.0, EVAC.AISLE_Z)
	aisle.position = half
	for i in 6: await physics_frame
	var eye3 := m.to_global(Vector3(EVAC.RECOIL.x, 1.62, EVAC.RECOIL.z))
	ok("los_recoil_to_marcus_down", ev._line_clear(eye3, m.to_global(EVAC.MARCUS_DOWN + Vector3(0, 0.5, 0))))
	ok("recoil_marker_free", ev._free_at(EVAC.RECOIL, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON))
	_leg("recoil_step", Vector3(13.12, 0.04, 13.78), EVAC.RECOIL, EVAC.PLAYER_R, EVAC.HEIGHTS_PERSON)
	# the mover itself: an actor really walks the directed route (swept every frame), and a blocked doorway stops it instead of being walked through
	var gs := GDScript.new()
	gs.source_code = "extends Node
var report := {}
"
	gs.reload()
	var stub: Node = gs.new()
	ev.c9 = stub
	ev.running = true
	var eddie: Node3D = w.eddie
	var ea: Dictionary = ev._actor(eddie, "person")
	aisle.position = Vector3(EVAC.AISLE_OPEN_X, 0.0, EVAC.AISLE_Z)
	for i in 6: await physics_frame
	var start_l: Vector3 = m.to_local(eddie.global_position)
	var arrived: bool = false
	var t0 := Time.get_ticks_msec()
	var walk_state := [false, false]
	var runner := func():
		walk_state[0] = await ev._move(ea, EVAC.Q_EDDIE, 6.0)
		walk_state[1] = true
	runner.call()
	var guard := 0
	while not walk_state[1] and guard < 900:
		await process_frame
		guard += 1
	ok("mover_arrives", walk_state[1] and walk_state[0], "state %s after %d frames" % [str(walk_state), guard])
	ok("mover_stands_on_marker", Vector2(eddie.position.x - EVAC.Q_EDDIE.x, eddie.position.z - EVAC.Q_EDDIE.z).length() < 0.15, str(eddie.position))
	aisle.position = Vector3(EVAC.AISLE_CLOSED_X, 0.0, EVAC.AISLE_Z)
	for i in 6: await physics_frame
	var walk2 := [false, false]
	var runner2 := func():
		walk2[0] = await ev._move(ea, EVAC.OPENING_CLEAR, 6.0)
		walk2[1] = true
	runner2.call()
	guard = 0
	while not walk2[1] and guard < 900:
		await process_frame
		guard += 1
	ok("mover_refuses_the_blocked_doorway", walk2[1] and not walk2[0] and eddie.position.z < 13.2, "state %s z %.2f" % [str(walk2), eddie.position.z])
	ok("failure_is_reported", (stub.report.get("failures", []) as Array).size() > 0)
	ev.running = false
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
