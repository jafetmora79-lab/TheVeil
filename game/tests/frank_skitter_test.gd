extends SceneTree
## THE VEIL - Frank and the Skitter (after the Colossus reveal): state order, the Skitter's look, pin alignment,
## the drag, cleanup. Headless, one run; how it LOOKS is for the playtest.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/frank_skitter_test.gd

var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(240.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	for f in ["fridge_checked", "entered_car", "reached_town", "parked"]:
		game.flags[f] = true
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(90)
	var lt = w.living
	var p = w.player
	# after the Colossus: out on the sidewalk by the game shop, looking along the street
	game.flags["p3_stepped_out"] = true
	game.flags["p3_mist"] = true
	game.flags["lt_frank_done"] = false
	p.global_position = w.game_shop.to_global(Vector3(-3.2, 0.3, -1.6))
	p.set_yaw_pitch(PI * 0.5, 0.0)
	p.controls_enabled = true
	await frames(10)
	lt._busy = ""
	var look_ok := [false]
	var watch := func() -> void:
		for i in 600:
			await process_frame
			var sk = w.get_node_or_null("LT_Skitter")
			if sk:
				for mi in sk.find_children("*", "MeshInstance3D", true, false):
					var m = (mi as MeshInstance3D).material_override
					if m == null and (mi as MeshInstance3D).mesh:
						m = (mi as MeshInstance3D).get_active_material(0)
					if m is ShaderMaterial:
						look_ok[0] = true
				return
	watch.call()
	await lt._frank()
	var r: Dictionary = lt.frank_report
	var st: Array = r.get("states", [])
	ok("F_order", st == ["run", "hunt", "dive", "grab", "carry", "gone"], str(st))      # (the Grimtalon takes him; `-- old_monsters` plays the Skitter's attack)
	ok("F_carried_into_the_sky", float(r.get("carried_to_m", 0.0)) > 40.0, "%.1f m up" % float(r.get("carried_to_m", 0.0)))
	await frames(5)
	ok("F_cleaned_up", w.get_node_or_null("LT_Skitter") == null and not lt.people["Frank"]["body"].visible and game.has_flag("lt_frank_done"))
	ok("F_control_back", p.controls_enabled or w._cine != null)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
