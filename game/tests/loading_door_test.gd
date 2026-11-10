extends SceneTree
## THE VEIL - loading-door encounter: three tentacles, their materials, the beat order, closing the door, the
## barricade, cleanup. Headless, one run; how it LOOKS is for the playtest.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/loading_door_test.gd

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0


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
	create_timer(240.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(200)
	for f in ["p4_garage_done", "p4_loading_down", "p4_loading_secured"]:
		game.flags.erase(f)
	game.flags["p4_flashlight"] = true
	w.phase4._apply()
	w.phase4.garage.running = false
	w.phase4.garage.closing = false
	var p4 = w.phase4
	ok("phase4_live", p4 != null and p4.get("garage") != null)
	if p4 == null or p4.get("garage") == null:
		print("RESULT FAIL fails=%d" % fails)
		quit(1)
		return
	var g = p4.garage
	var pl = w.player
	pl.controls_enabled = true
	pl.look_enabled = true
	pl.global_position = p4.ml(Vector3(18.6, 0.1, 15.9))
	await frames(5)
	g._on_enter()
	var started := await wait_until(func(): return g.running, 10.0)
	ok("encounter_starts", started)
	var shown := await wait_until(func(): return g.report.get("revealed", false), 25.0)
	ok("three_tentacles", shown and g.trio.size() == 3, str(g.trio.keys()))
	var mats_ok := true
	var detail := []
	for k in g.trio:
		var t: Node3D = g.trio[k]["node"]
		var any_tex := false
		for mi in t.find_children("*", "MeshInstance3D", true, false):
			var m = (mi as MeshInstance3D).get_active_material(0)
			if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("albedo_tex") != null:
				any_tex = true
		if not any_tex:
			mats_ok = false
		detail.append("%s:%s" % [k, any_tex])
	ok("dark_materials_textured", mats_ok, str(detail))
	var roots_out: bool = g.trio.values().all(func(d): return (d["root"] as Vector3).x > 20.6)
	ok("roots_outside", roots_out)
	var first5: Array = g.beat_log.slice(0, 5)
	ok("beat_order", first5 == ["A:push", "A:sense", "A:sweep", "B:reach", "C:lash"], str(g.beat_log))
	ok("under_the_door", float(g.report.get("through_gap", -1.0)) > 0.05, "worst %.2f m under the door edge (gap %.2f m)" % [float(g.report.get("through_gap", -1.0)), float(g.report.get("gap_top", -1.0))])
	var zs: Array = ["A", "B", "C"].map(func(k): return float(g.trio[k]["root"].z))
	ok("left_centre_right", zs[1] < zs[0] and zs[0] < zs[2], str(zs))
	ok("no_clipping_in_bay", (g.report.get("clearance_hits", ["?"]) as Array).is_empty(), str(g.report.get("clearance_hits", [])))
	ok("control_back", await wait_until(func(): return pl.controls_enabled, 5.0))
	await frames(60 * 3)
	ok("escalates", g.beat_log.size() > 5, "%d beats" % g.beat_log.size())
	# pull the door down (the existing handle) -> survived, all three gone
	var handle: Interactable = p4.its["loading"]
	handle.interact(pl)
	var done := await wait_until(func(): return game.has_flag("p4_garage_done"), 20.0)
	ok("door_closed_survived", done and game.has_flag("p4_loading_down") and g.report.get("survived", false))
	ok("tentacles_cleaned_up", g.trio.is_empty() and w.find_children("P4_GarageTentacle_*", "", true, false).is_empty())
	# the barricade still works
	await frames(30)
	var pal: Interactable = p4.its["pallet_loading"]
	pal.interact(pl)
	ok("barricade_secured", await wait_until(func(): return game.has_flag("p4_loading_secured"), 10.0))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
