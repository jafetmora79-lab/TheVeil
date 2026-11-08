extends SceneTree
## THE VEIL - after the Veil: wrecks among the trees along the road home (never on it), Skitters dart past the car
## 10-20 m off while driving it (at most two), and car parts are only taken on a supply run. Headless, short.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/road_home_test.gd

const DEV := preload("res://game/tools/dev_chapter7.gd")
var fails := 0
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame
		if w and is_instance_valid(w) and w.phase4 and w.phase4.choice.is_open():
			w.phase4.choice.pick(-1)


func _initialize() -> void:
	_run.call_deferred()
	create_timer(220.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	game.set_flag("vehicle_found")
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(200)
	var rh = w.road_home
	var ex = w.expedition
	var q = ex.quest
	# ---- car parts: not on a story errand, yes on a supply run
	ex.st()["active"] = false
	var gas: Interactable = q.steps["gas/take"]
	gas.interact(w.player)
	await frames(30)
	ok("part_not_taken_off_trip", not q.acquired("fuel_can") and String(w.hud.sub.text).contains("come back"), w.hud.sub.text)
	ex.st()["active"] = true
	gas.interact(w.player)
	for i in 300:
		if q.acquired("fuel_can"):
			break
		await frames(1)
	ok("part_taken_on_trip", q.acquired("fuel_can"))
	ex.st()["active"] = false
	# ---- wrecks in the woods along the road home
	ok("road_found", rh.road.size() > 10, "%d pieces" % rh.road.size())
	ok("wrecks_placed", rh.wrecks.size() >= 4, "%d" % rh.wrecks.size())
	var nearest := INF
	for car in rh.wrecks:
		var p: Vector3 = (car as Node3D).global_position
		for r in rh.road:
			nearest = minf(nearest, Vector2(p.x - r[0].x, p.z - r[0].z).length())
	ok("wrecks_off_the_road", nearest > 7.0, "closest %.1f m from a road piece's centre" % nearest)
	# ---- driving it: Skitters in the trees
	game.flags["fridge_checked"] = true
	game.set_flag("vehicle_repaired")
	if not game.has_item("car_keys"):
		game.add_item("car_keys")
	w.sedan.survival = false
	var r0: Array = rh.road[rh.road.size() / 2]
	var r1: Array = rh.road[rh.road.size() / 2 + 1]
	var dir: Vector3 = ((r1[0] as Vector3) - (r0[0] as Vector3)) * Vector3(1, 0, 1)
	w.sedan.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), (r0[0] as Vector3) + Vector3(0, 0.6, 0))
	w.player.global_position = w.sedan.global_transform * Vector3(-1.6, 0.1, -0.3)
	await frames(10)
	w.enter_car()
	for i in 300:
		if w.in_car:
			break
		await frames(1)
	ok("driving", w.in_car)
	var most := 0
	var near_ok := true
	w.sedan.autopilot = func(_d): return Vector3(0.7, 0.0, 0.0)
	for i in 60 * 14:
		await frames(1)
		w.sedan.speed = maxf(w.sedan.speed, 7.0)
		most = maxi(most, rh.darts.size())
	w.sedan.autopilot = Callable()
	ok("skitters_dart", int(rh.report["darts"]) >= 1, "%d darts" % int(rh.report["darts"]))
	ok("at_most_two", most <= 2, "%d" % most)
	ok("dart_distance", float(rh.report.get("last_dist", 0.0)) > 8.0 and float(rh.report.get("last_dist", 99.0)) < 26.0, "%.1f m" % float(rh.report.get("last_dist", -1.0)))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
