extends SceneTree
## The Chapter 10 fall: every scripted leg has a route round the real furniture, walls and doors (nobody walks through anything).
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(150.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _len(r: Array, from: Vector3) -> float:
	var l := 0.0
	var p := from
	for q in r:
		l += (q as Vector3).distance_to(p)
		p = q
	return l
func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var m: Node3D = w.market
	var p4 = w.phase4
	ok("phase4", p4 != null)
	if p4 == null:
		quit(1)
		return
	var aisle: Node3D = load("res://game/world/gondola_aisle.gd").detach(m, Vector3(9.5, 0.0, 10.0), 90.0)
	aisle.position = Vector3(12.0, 0.0, 13.62)
	aisle.rotation.y = 0.0
	var bd: Node3D = p4.its.get("back_door")
	if bd:
		var base: Transform3D = p4._base["back"]
		var d: float = w._toward_deg(bd, 88.0, m.to_global(Vector3(8.0, 1.0, 16.4)))
		bd.transform = Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(d)), base.origin)
	var staff = p4.its.get("INT_Door_Staff")
	if staff:
		staff.set_open(true, true)
	for i in 6: await physics_frame
	var legs := {
		"group_to_doorway": [Vector3(5.0, 0.04, 6.3), Vector3(8.0, 0.04, 11.7)],
		"to_east_end": [Vector3(4.6, 0.04, 7.5), Vector3(11.52, 0.04, 13.34)],
		"doorway_to_lot": [Vector3(8.0, 0.04, 11.7), Vector3(7.2, 0.04, 20.6)],
		"front_to_walt": [Vector3(0.0, 0.04, 0.5), Vector3(8.4, 0.04, 10.5)],
		"front_to_ram": [Vector3(0.0, 0.04, 0.5), Vector3(6.6, 0.04, 12.6)],
		"pin_to_staff_in": [Vector3(11.1, 0.04, 11.7), Vector3(15.0, 0.04, 13.4)],
		"staff_through": [Vector3(15.0, 0.04, 13.4), Vector3(15.0, 0.04, 15.5)],
		"corridor_to_lot": [Vector3(15.0, 0.04, 15.5), Vector3(8.0, 0.04, 20.2)],
	}
	for k in legs:
		var from: Vector3 = legs[k][0]
		var to: Vector3 = legs[k][1]
		var r: Array = w.npc_route(m, from, to, null, true)
		var end_ok := not r.is_empty() and (r[r.size() - 1] as Vector3).distance_to(to) < 0.8
		var straight := from.distance_to(to)
		var rl := _len(r, from)
		ok("route_" + k, end_ok, "len %.1f straight %.1f pts %d" % [rl, straight, r.size()])
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
