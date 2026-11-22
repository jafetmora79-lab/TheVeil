extends SceneTree
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(100.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _run() -> void:
	root.get_node("Game").no_save = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var sl = w.get_node("StreetLife")
	ok("signals_found", sl.report["signals"] > 0, str(sl.report))
	var sg = sl._signals[0]
	var e0: Array = sg["mats"].map(func(m): return m.emission_energy_multiplier)
	sl._t += 11.0
	for i in 3: await physics_frame
	var e1: Array = sg["mats"].map(func(m): return m.emission_energy_multiplier)
	ok("phase_changes", e0 != e1, "%s -> %s" % [e0, e1])
	w.player.global_position = Vector3(31, 1, -23)
	sl._flick_t = 0.0
	for i in 20: await physics_frame
	ok("flicker", sl.report["flickers"] >= 1, str(sl.report))
	ok("edge_dist", absf(sl.edge_distance(Vector3(-156.6, 0, -62)) - 3.4) < 0.1)
	w.player.global_position = Vector3(-156.6, 0.1, -62.0)
	sl._edge_t = 0.0
	for i in 20: await physics_frame
	ok("edge_kill_started", sl.report.get("edge_kills", 0) == 1 and w.get_node("EdgeSnatch").busy, str(sl.report))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
