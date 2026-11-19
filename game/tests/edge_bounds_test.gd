extends SceneTree
## THE VEIL - car checklist panel, no townsperson in the player's home (new game and continue), the car's paved
## limits, the world edge (warning, the grab, YOU DIED, no flags / saves touched, on foot and from the car).
## Headless, short; how it looks is for the playtest.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/edge_bounds_test.gd

var fails := 0
var w: Node
var game: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func until(f: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if f.call():
			return true
		await physics_frame
	return f.call()


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _world() -> void:
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(150)


func _free_world() -> void:
	if w and is_instance_valid(w):
		w.queue_free()
	await frames(5)
	paused = false


func _people_ok(tag: String) -> void:
	var lt = w.living
	var home: Node3D = w.home
	var hb: AABB = home.global_transform * Interactable.aabb_of(home)
	var hr := Rect2(hb.position.x, hb.position.z, hb.size.x, hb.size.z)
	var inside: Array = []
	var routes_in: Array = []
	for k in lt.people:
		var b: Node3D = lt.people[k]["body"]
		if not is_instance_valid(b) or not b.visible:
			continue
		if hr.has_point(Vector2(b.global_position.x, b.global_position.z)) or lt.in_house(b.global_position):
			inside.append(k)
		for wp in lt.people[k].get("route", []):
			if lt.in_house(wp):
				routes_in.append(k)
	ok("no_one_in_home_" + tag, inside.is_empty(), str(inside))
	ok("no_route_through_houses_" + tag, routes_in.is_empty(), str(routes_in))
	ok("not_on_player_" + tag, lt.people.values().all(func(pp): return not is_instance_valid(pp["body"]) or (pp["body"] as Node3D).global_position.distance_to(w.player.global_position) > 1.5))


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	game.new_game()
	await _world()
	# ---- 1. the checklist panel
	var cp := VeilChoicePanel.new()
	root.add_child(cp)
	await frames(2)
	var rows: Array = [[true, "Fuel canister", "installed", false], [false, "Battery", "collected", true],
		[false, "Fuse", "missing", false], [false, "Starter relay with a much longer name that has to wrap inside the panel", "missing", false],
		"Nothing to fit yet. The parts must be out in town - look around the wrecks and the gas station."]
	var box: Control = cp._checklist(rows)
	cp._box.add_child(box)
	await frames(3)
	var widest := 0.0
	var wrapped := true
	for h in box.get_children():
		widest = maxf(widest, (h as Control).get_combined_minimum_size().x)
		if h is HBoxContainer:
			var nl := h.get_child(1) as Label
			wrapped = wrapped and nl.autowrap_mode != TextServer.AUTOWRAP_OFF
	ok("checklist_compact", widest <= VeilChoicePanel.CHECK_W + 2.0, "%.0f px" % widest)
	ok("checklist_wraps", wrapped)
	ok("checklist_rows", box.get_child_count() == 5)
	cp.queue_free()
	# ---- 2. townspeople never in the home: new game, then continue
	ok("people_spawned", w.living.people.size() >= 5, str(w.living.people.keys()))
	_people_ok("new")
	ok("home_is_a_house", w.living.in_house(w.home.global_position))
	await frames(60 * 6)                                 # a few walk legs
	_people_ok("walked")
	game.save_game()
	await _free_world()
	game.load_game()
	game.load_requested = true
	await _world()
	_people_ok("continue")
	# ---- 3. the car: paved surfaces only
	var car = w.sedan
	ok("paved_driveway", car.paved(car.global_position))
	ok("paved_lot", car.paved(Vector3(15, 0.2, -20)) and car.paved(Vector3(25, 0.2, -15)))
	ok("paved_west_dirt_road", car.paved(Vector3(-108, 0.2, -16)))
	var lawn := Vector3.INF
	for p in [car.global_position + Vector3(0, 0, 4), car.global_position + Vector3(-4, 0, 0), car.global_position + Vector3(0, 0, -4)]:
		if not car.paved(p):
			lawn = p
	ok("lawn_not_paved", lawn.is_finite())
	if not game.has_item("car_keys"):
		game.add_item("car_keys")
	game.flags["fridge_checked"] = true
	w.player.global_position = car.global_transform * Vector3(-1.6, 0.1, -0.3)
	await frames(10)
	w.enter_car()
	await until(func(): return w.in_car and car.driven, 5.0)
	ok("in_car", w.in_car)
	var t0 := 0.0
	car.autopilot = func(d):
		t0 += d
		return Vector3(1.0, 0.0, 1.0 if t0 < 6.0 else -1.0)       # full throttle with a full lock, then the other way
	await frames(60 * 9)
	car.autopilot = Callable()
	car.speed = 0.0
	await frames(10)
	ok("stays_on_paving", car.paved(car.global_position), str(car.global_position))
	# ---- 4. the world edge, in the car first (a road far out is not needed: the car is put there)
	var far := _far_point(70.0)
	ok("far_point", far.is_finite(), str(far))
	var edge = w.world_edge
	ok("edge_points", edge.points.size() > 500, str(edge.points.size()))
	var flags0: Dictionary = game.flags.duplicate()
	var save_t := FileAccess.get_modified_time(game.SAVE_PATH) if FileAccess.file_exists(game.SAVE_PATH) else 0
	await until(func(): return edge.armed, 5.0)
	ok("armed_in_town", edge.armed)
	var warn := _far_point(edge.WARN_D + 6.0, edge.KILL_D - 8.0)
	car.global_position = warn + Vector3(0, 0.6, 0)
	await until(func(): return edge.state == "warned", 4.0)
	ok("warned", edge.state == "warned" and edge.report.get("warned", false), str(edge.report.get("distance", -1.0)))
	car.global_position = far + Vector3(0, 0.6, 0)
	var taken := await until(func(): return edge.report.get("death_panel", false), 15.0)
	ok("taken_from_car", taken and edge.report.get("left_car", false) and not w.in_car and not car.driven, str(edge.report))
	ok("grab_stages", edge.report.get("tentacle", false) and edge.report.get("grabbed", false) and edge.report.get("lifted", false))
	ok("no_flags_changed", game.flags == flags0)
	var save_t2 := FileAccess.get_modified_time(game.SAVE_PATH) if FileAccess.file_exists(game.SAVE_PATH) else 0
	ok("no_save_written", save_t2 == save_t)
	# ---- 5. a reload never fires it again on the spot (the save is from town)
	var panel := w.get_node_or_null("DeathPanel")
	if panel:
		panel.pick(-1)
	await _free_world()
	game.load_game()
	game.load_requested = true
	await _world()
	await frames(60 * 3)
	ok("reload_safe", w.world_edge.state == "idle" and not w.world_edge.running)
	# ---- on foot, far out from a fresh arming
	await until(func(): return w.world_edge.armed, 8.0)
	if w.in_car:
		w.sedan.speed = 0.0
		await w.exit_car()                                # (the reload put us back in the car: out, on foot)
		await frames(30)
	w.player.global_position = far + Vector3(0, 0.3, 0)
	var foot := await until(func(): return w.world_edge.report.get("death_panel", false), 15.0)
	ok("taken_on_foot", foot, str(w.world_edge.report))
	await _free_world()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


## A spot on the ground at least `dmin` (and at most `dmax`) from anything built.
func _far_point(dmin: float, dmax := INF) -> Vector3:
	var edge = w.world_edge
	var space: PhysicsDirectSpaceState3D = (w.get_world_3d() as World3D).direct_space_state
	var x := -140.0
	while x < 380.0:
		var z := -140.0
		while z < 580.0:
			var p := Vector3(x, 0, z)
			var d: float = edge.distance(p)
			if d >= dmin and d <= dmax:
				var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p - Vector3.UP * 10.0, 1))
				if h and String((h["collider"] as Node).name).begins_with("TOWN_Ground"):
					return h["position"]
			z += 6.0
		x += 6.0
	return Vector3.INF
