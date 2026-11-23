extends SceneTree
## The new rendezvous (displayed Chapter 10 -> 11): a house on the way the group goes NEXT. From the store's rear lot there is a real route to its porch, the hall has four free places reachable from the
## door, and a survivor walks from the porch through the door line to its place (measured), nobody placed.
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(170.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var mv = load("res://game/world/scene_mover.gd").new()
	root.add_child(mv)
	mv.setup(w, w.player)
	var C9 = load("res://game/world/chapter9.gd")
	var c9 = C9.new()
	root.add_child(c9)
	c9.world = w
	c9.mover = mv
	c9.rv_house = w.get_node("Residential/Houses/" + C9.RV_HOUSE)
	w.clear_story_glass(c9.rv_house)
	var fd := c9.rv_house.find_child("INT_Door_Front", true, false) as Node3D
	var dl: Vector3 = c9.rv_house.to_local(fd.global_position)
	var inside: Vector3 = c9.rv_house.to_global(Vector3(dl.x, 1.4, dl.z + 1.8))
	var door := Interactable.attach(fd, {"kind": "hinge", "label": "Front Door", "open_deg": w._toward_deg(fd, 95.0, inside), "hinge_axis": Vector3.UP, "state_key": "test/rv_door"})
	door.set_open(true, true)
	for i in 8: await physics_frame
	# it lies on the way west: the store's rear lot is east of it, the next route anchor (4, -47) is north-west of it
	var porch: Vector3 = c9._rv_porch()
	var rear := Vector3(25.0, 0.15, -46.6)
	ok("house_is_near_the_rear_lot", Vector2(porch.x - rear.x, porch.z - rear.z).length() < 25.0, str(porch))
	var out_pt: Vector3 = c9.rv_house.to_global(Vector3(dl.x, 0.0, dl.z - 2.5))
	out_pt.y = mv.floor_at(out_pt.x, out_pt.z, 0.2)
	var r: Array = mv.route(rear, out_pt, 0.28, [0.5, 1.3], 20.0)
	ok("route_rear_lot_to_the_door", not r.is_empty(), "pts %d y %s" % [r.size(), str(out_pt.y)])
	var spots: Dictionary = c9._rv_spots()
	ok("four_hall_places", spots.has("Eddie") and spots.has("Ruth") and spots.has("Sarah") and spots.has("Marcus"), str(spots.keys()))
	for k in spots:
		ok("place_free_" + k, mv.free_at(spots[k], 0.28, [0.5, 1.3]))
	var keys: Array = ["Eddie", "Ruth", "Sarah", "Marcus"]
	var worst := 99.0
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			worst = minf(worst, (spots[keys[i]] as Vector3).distance_to(spots[keys[j]]))
	ok("places_apart", worst >= 1.0, "%.2f" % worst)
	ok("the_player_has_a_living_room_place", spots.has("Player"))
	if spots.has("Player"):
		var pw: Vector3 = spots["Player"]
		ok("player_place_free", mv.free_at(pw, 0.28, [0.5, 1.3]))
		var far := 99.0
		for k in ["Eddie", "Ruth", "Sarah", "Marcus"]:
			far = minf(far, pw.distance_to(spots[k]))
		ok("player_place_clear_of_the_others", far >= 1.2, "%.2f" % far)
		var door_w: Vector3 = c9.rv_house.to_global(Vector3(dl.x, 0.0, dl.z))
		ok("player_place_away_from_the_door", Vector2(pw.x - door_w.x, pw.z - door_w.z).length() >= 2.0)
	ok("spots_for_everyone", spots.size() >= 4)
	# a survivor walks in from the porch: over the door line, to its place
	var eddie: Node3D = w.eddie
	eddie.global_position = out_pt
	var ea: Dictionary = mv.actor(eddie, w.animators.get("Eddie"), "person")
	var res := [false, false]
	var runner := func():
		res[0] = await mv.move(ea, spots["Eddie"], 3.0)
		res[1] = true
	runner.call()
	var crossed := false
	var g := 0
	while not res[1] and g < 1500:
		await process_frame
		g += 1
		var l: Vector3 = c9.rv_house.to_local(eddie.global_position)
		if l.z > dl.z + 0.5 and absf(l.x - dl.x) < 2.6:
			crossed = true
	if spots.has("Player"):
		var pres := [false, false]
		var pa: Dictionary = mv.actor(w.player, null, "player")
		w.player.global_position = out_pt
		var prunner := func():
			pres[0] = await mv.move(pa, spots["Player"], 3.6)
			pres[1] = true
		prunner.call()
		var pg := 0
		while not pres[1] and pg < 1500:
			await process_frame
			pg += 1
		ok("player_walks_into_the_living_room", pres[1] and pres[0], "frames %d fails %s" % [pg, str(mv.failures.slice(-1))])
		eddie.global_position = out_pt
	ok("walker_goes_in_over_the_door_line", res[1] and res[0] and crossed, "frames %d fails %s" % [g, str(mv.failures.slice(-2))])
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
