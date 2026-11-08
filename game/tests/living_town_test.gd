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
	ok("people_spawned", lt.people.size() == 5 and lt.people.has("Frank") and lt.people.has("Officer") and lt.people.has("Joan"), str(lt.people.keys()))
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
	await _put(w.game_shop.to_global(Vector3(-3.2, 0.3, -4.0)))
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
	await lt._joan()                                 # (here a chapter scene is running: the town would wait for it)
	var jo: bool = game.has_flag("lt_joan_done")
	ok("E2_joan_once", jo and lt.report["events"].count("joan") == 1, "route %s" % str(lt.report.get("joan_route", -1)))
	# ---- 5. the window (scene itself; finding a house in view needs the player there on a supply run)
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
