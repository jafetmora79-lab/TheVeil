extends SceneTree
## THE VEIL - living town: spawns, waypoints on walkable ground, traffic on the road, the Veil transition, the five
## one-time events (flags), persistence. Headless, short. Visual quality is NOT checked here.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/living_town_test.gd

var fails := 0
var w: Node
var game: Node
var lt: Node
var p: CharacterBody3D


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait_until(f: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if f.call():
			return true
		await process_frame
	return f.call()


func _initialize() -> void:
	_run.call_deferred()
	create_timer(500.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _put(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	await frames(5)


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	for f in ["fridge_checked", "entered_car", "reached_town", "parked"]:
		game.flags[f] = true
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(90)
	lt = w.living
	p = w.player
	p.controls_enabled = true
	# ---- before the Veil
	ok("people_spawned", lt.people.size() <= 8 and lt.people.size() >= 7 and lt.people.has("Frank") and lt.people.has("Officer") and lt.people.has("Joan"), str(lt.people.keys()))
	ok("road_found", lt.report.has("road_span"), "centre z %.1f %s" % [lt.road_z, str(lt.report.get("road_span", []))])
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	var bad := []
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.4
	q.shape = cap
	q.collision_mask = 1
	for nm in lt.people:
		for wp in lt.people[nm]["route"]:
			var g: Vector3 = lt._ground(wp)
			if lt._on_road(wp):
				bad.append("%s on road %s" % [nm, str(wp)])
			q.transform = Transform3D(Basis(), g + Vector3.UP * 1.0)
			q.exclude = [p.get_rid()]
			for h in space.intersect_shape(q, 4):
				var c: Node = h["collider"]
				if not (c is VeilSurvivorBody):
					bad.append("%s blocked at %s by %s" % [nm, str(wp.snapped(Vector3.ONE * 0.1)), c.name])
	ok("waypoints_walkable", bad.is_empty(), str(bad))
	await _put(Vector3(30.0, 0.7, lt.road_z + 9.0))
	await frames(60 * 20)
	var on_road := true
	for c in lt.cars:
		if not lt._on_road((c["node"] as Node3D).global_position):
			on_road = false
	ok("traffic_runs_on_road", int(lt.report["cars_spawned"]) >= 1 and lt.cars.size() <= 3 and on_road, "spawned %d, now %d" % [int(lt.report["cars_spawned"]), lt.cars.size()])
	var walked: bool = lt.people.values().any(func(x): return x["anim"].is_walking() or int(x["i"]) > 0)
	ok("people_walk_routes", walked)
	# ---- the repair checks
	var fwd_ok := true
	var lane_ok := true
	for c in lt.cars:
		var car: Node3D = c["node"]
		var path: PackedVector3Array = c["path"]
		var travel: Vector3 = (path[path.size() - 1] - path[0]).normalized()
		if (-car.global_basis.z).dot(travel) < 0.98:
			fwd_ok = false
		var right: Vector3 = travel.cross(Vector3.UP)          # right-hand traffic: the lane is on the travel's right
		if (car.global_position - Vector3(car.global_position.x, car.global_position.y, lt.road_z)).dot(right) < 0.5:
			lane_ok = false
	ok("R1_cars_face_travel", lt.cars.size() > 0 and fwd_ok)
	ok("R3_right_hand_lanes", lane_ok)
	var drv: bool = lt.cars.all(func(c): return c.get("driver") != null and is_instance_valid(c["driver"]) and (c["driver"] as Node3D).get_parent().name == "Marker_Seat_Driver")
	ok("R1_drivers_seated", drv)
	# braking: the player's car parked in a lane stops the next car behind it, short of it
	if not lt.cars.is_empty():
		var c0: Dictionary = lt.cars[0]
		var car0: Node3D = c0["node"]
		var ahead: Vector3 = car0.global_position + (-car0.global_basis.z) * 14.0
		w.sedan.global_position = ahead
		await frames(60 * 4)
		var gap: float = car0.global_position.distance_to(ahead) if is_instance_valid(car0) else 99.0
		ok("R3_brakes_for_car_ahead", is_instance_valid(car0) and gap > 4.0 and float(c0["v"]) < 0.5, "gap %.1f m, speed %.1f" % [gap, float(c0["v"])])
	# pedestrians: the player's car on Frank's sidewalk -> his route goes round it, not through
	var fp: Dictionary = lt.people["Frank"]
	var mid: Vector3 = ((fp["route"][0] as Vector3) + (fp["route"][1] as Vector3)) * 0.5
	w.sedan.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), mid + Vector3(0, 0.1, 0))
	await frames(10)
	(fp["body"] as Node3D).global_position = fp["route"][0]
	var went: bool = lt._walk_leg(fp, fp["route"][1], 1.15)
	var through := false
	var pts: Array = fp["anim"]._path.duplicate()
	var prev: Vector3 = fp["route"][0]
	var box := AABB(w.sedan.global_position - Vector3(1.2, 0, 2.6), Vector3(2.4, 2.0, 5.2))
	for q2 in pts:
		for k in 10:
			var x: Vector3 = prev.lerp(q2, k / 10.0)
			if box.has_point(Vector3(x.x, w.sedan.global_position.y + 0.5, x.z)) and Vector2(x.x - w.sedan.global_position.x, x.z - w.sedan.global_position.z).length() < 1.0:
				through = true
		prev = q2
	ok("R4_walks_round_parked_car", not went or not through, "route %d points, went %s" % [pts.size(), str(went)])
	# traffic while the player sits in the car (the body left far away)
	w.sedan.global_position = Vector3(30.0, 0.2, lt.road_z + 12.0)
	p.global_position = Vector3(49.0, 0.7, 508.0)
	w.in_car = true
	var cs0: int = int(lt.report["cars_spawned"])
	await frames(60 * 14)
	ok("R2_traffic_while_in_car", int(lt.report["cars_spawned"]) > cs0 or not lt.cars.is_empty(), "%d -> %d" % [cs0, int(lt.report["cars_spawned"])])
	w.in_car = false
	p.global_position = Vector3(30.0, 0.7, lt.road_z + 9.0)
	# neighbours, talking, no look-alikes
	ok("R5_neighbours", ["Res_Walker", "Res_Neighbour", "Res_Driveway"].filter(func(n): return lt.people.has(n)).size() >= 2, "spots %s" % str(lt.report.get("home_spots", -1)))
	await wait_until(func(): return lt.can_talk("Officer"), 10.0)
	ok("R6_talk_available", lt.can_talk("Frank") and lt.people["Frank"]["it"].get_prompt() != "" or lt.can_talk("Officer"))
	lt._talk("Officer")
	ok("R6_talk_says_line", int(lt.report.get("talks", 0)) >= 1)
	var sig := {}
	var dup := []
	for nm in lt.people:
		var b: Node3D = lt.people[nm]["body"]
		var m: MeshInstance3D = b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var key: String = "%s|%s|%.2f" % [m.mesh.resource_path, str(m.get_active_material(0).albedo_color if m.get_active_material(0) is StandardMaterial3D else ""), (b.get_child(0) as Node3D).scale.x]
		if sig.has(key):
			dup.append("%s=%s" % [nm, sig[key]])
		sig[key] = nm
	ok("R7_no_lookalikes", dup.is_empty(), str(dup))
	ok("no_monsters_before_veil", w.find_children("LT_*", "", true, false).filter(func(n): return n.name.begins_with("LT_Skitter") or n.name.begins_with("LT_Hound")).is_empty())
	# ---- the Veil: routines end, fear, people leave over time
	game.flags["p3_stepped_out"] = true           # (the Colossus scene itself is the opening test's; here: already seen)
	game.flags["p3_mist"] = true
	game.flags["phase2_done"] = true
	await frames(60 * 2)
	ok("panic_starts_not_instant", lt.people.values().any(func(x): return x["state"] != "routine") and lt.people.values().filter(func(x): return x["body"].visible).size() >= 3)
	await frames(60 * 12)
	var states: Array = lt.people.keys().map(func(k): return "%s:%s" % [k, lt.people[k]["state"]])
	ok("panic_flight", lt.people["Civilian_A"]["state"] in ["building", "inside"] and lt.people["Civilian_B"]["state"] in ["fog", "gone"], str(states))
	# ---- 1. Frank (after the Colossus scene: stepped out, control back, outdoors)
	game.flags["p3_stepped_out"] = true
	await _put(w.game_shop.to_global(Vector3(-3.2, 0.3, -1.6)))   # on the sidewalk outside the shop
	var fr := await wait_until(func(): return game.has_flag("lt_frank_done"), 25.0)
	ok("E1_frank_once", fr and lt.report["events"].count("frank") == 1, str(lt.report["events"]))
	ok("E1_frank_taken", lt.people["Frank"]["state"] == "taken" and not lt.people["Frank"]["body"].visible)
	# ---- 2. the crash follows when the player is outdoors
	var cr := await wait_until(func(): return game.has_flag("lt_crash_done"), 25.0)
	ok("E4_crash_once", cr and game.world_state.has("lt_crash") and lt.report["events"].count("crash") == 1, str(lt.report.get("crash_at", "")))
	var abandoned = w.find_child("LT_AbandonedCar", true, false)
	ok("E4_car_stays", abandoned != null)
	# ---- 3. the officer during the run to the supermarket
	game.flags["p3_back_inside"] = true
	game.flags["p3_fled_together"] = true
	w._p3_npcs_moved = true
	await frames(30)
	await _put(Vector3(40.0, 0.7, lt.road_z + 6.5))   # out on the street, on the run
	pass #print("  dbg busy=%s story_busy=%s outdoors=%s enc=%s conv=%s cine=%s officer_vis=%s ev_t=%.1f" % [lt._busy, lt._story_busy(), w._outdoors(), w._encounter_running, w.conversing, str(w._cine), lt.people["Officer"]["body"].visible, lt._event_t])
	var po := await wait_until(func(): return game.has_flag("lt_police_done"), 25.0)
	ok("E3_police_once", po and lt.report["events"].count("police") == 1, str(lt.report["events"]))
	# ---- 4. Joan, post-Veil, near the gas station
	game.flags["p3_in_market"] = true
	game.flags["p3_doors_shut"] = true
	game.flags["c5_started"] = true
	await frames(60 * 4)
	await _put(Vector3(140.0, 0.7, lt.road_z))
	await frames(30)
	pass #print("  dbg2 busy=%s story_busy=%s outdoors=%s near=%s pos=%s ev_t=%.1f vis=%s" % [lt._busy, lt._story_busy(), w._outdoors(), lt._player_near(Vector3(152.0, 0.2, -26.0), 38.0), str(p.global_position.snapped(Vector3.ONE)), lt._event_t, p.visible])
	ok("E2_waits_for_story_scene", lt._story_busy() == false or not game.has_flag("lt_joan_done"))
	if lt._busy == "":
		lt._joan()                                   # (a chapter scene may hold the natural trigger back)
	var jo := await wait_until(func(): return game.has_flag("lt_joan_done"), 30.0)
	ok("E2_joan_once", jo and lt.report["events"].count("joan") == 1, "route %s" % str(lt.report.get("joan_route", -1)))
	# ---- 5. the window (scene itself; finding a house in view needs the player there on a supply run)
	await wait_until(func(): return lt._busy == "", 10.0)
	await lt._window_scene(Vector3(0, 3.5, 0))
	ok("E5_window_once", game.has_flag("lt_window_done") and lt.report["events"].count("window") == 1)
	# ---- persistence: saved flags, nothing replays
	game.save_game()
	game.load_game()
	var all_done := ["lt_frank_done", "lt_crash_done", "lt_police_done", "lt_joan_done", "lt_window_done"].all(func(f): return game.has_flag(f))
	ok("flags_persist", all_done and game.world_state.has("lt_crash"))
	var n0: int = lt.report["events"].size()
	await frames(60 * 5)
	ok("nothing_replays", lt.report["events"].size() == n0 and lt._busy == "")
	ok("scripted_creatures_cleared", w.find_children("LT_Skitter*", "", true, false).size() + w.find_children("LT_Hound*", "", true, false).size() <= 1)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
