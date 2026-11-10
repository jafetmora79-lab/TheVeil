extends SceneTree
## THE VEIL - Chapter 8: the Hound bites Sarah, the click rescue, the barricade; the loading-door pallet sound.
## Short and headless (numbers / flags / control only; how it looks is for the playtest).
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/sarah_rescue_test.gd

const DEV := preload("res://game/chapters/setups/dev_chapter8.gd")
var fails := 0
var w: Node
var game: Node


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
	create_timer(400.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _click() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	Input.parse_input_event(e)


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(120)
	var p4 = w.phase4
	# ---- 1. the pallets: heavy drag + thud, not the old electronic scrape
	ok("S1_pallet_sounds", p4._streams.has("drag") and p4._streams.has("thud"))
	var src: String = FileAccess.get_file_as_string("res://game/world/phase4.gd")
	var fn := src.substr(src.find("func _push_pallet"), 2600)
	ok("S1_no_interference_on_pallets", not fn.contains("\"scrape\"") and fn.contains("\"drag\"") and fn.contains("\"thud\""))
	# ---- 2. the rescue mode itself: no clicks = fails in its window; clicks = succeeds
	var sg = w.get_node_or_null("Struggle")
	if sg == null:
		sg = load("res://game/encounters/struggle.gd").new()
		sg.name = "Struggle"
		w.add_child(sg)
		sg.setup(w)
	var lost: bool = await sg.rescue("T", "T", 1.0)
	ok("S2_fail_path", lost == false and not sg.active and not sg._ui.visible)
	# ---- 3. the chapter scene
	var c8 = p4.get("chapter8")
	if c8 == null:
		for n in w.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("chapter8.gd"):
				c8 = n
	ok("S3_chapter8_live", c8 != null)
	if c8 == null:
		print("RESULT FAIL fails=%d" % (fails + 1))
		quit(1)
		return
	for f in ["ch8_power_restored"]:
		game.flags[f] = true
	w.player.global_position = c8.ml(Vector3(0.0, 0.1, 9.0))
	w.player.controls_enabled = true
	c8._run_attack()
	var bit := await wait_until(func(): return c8.bite_report.get("started", false), 40.0)
	ok("S3_victim_is_sarah", bit and game.has_flag("ch8_temp_survivor_died") and c8.sarah != null)
	var rescuing := await wait_until(func(): return sg.active, 20.0)
	ok("S3_bite_then_rescue_prompt", rescuing and game.has_flag("ch8_sarah_bitten") and String(sg._title.text).contains("GET THE HOUND OFF"), String(sg._title.text))
	ok("S3_jaws_on_arm", float(c8.bite_report.get("jaw_to_arm_m", 9.0)) < 0.35, "%.2f m" % float(c8.bite_report.get("jaw_to_arm_m", 9.0)))
	ok("S3_controls_held", not w.player.controls_enabled)
	var cps := 0
	while sg.active and cps < 400:
		_click()
		await frames(28)                               # ~2 clicks a second: no frantic clicking needed
		cps += 1
	ok("S3_rescue_won", c8.bite_report.get("won", false), "%d clicks, peak %.2f, t left %.2f" % [int(sg.rescue_clicks), float(sg.rescue_peak), float(sg._t)])
	var done := await wait_until(func(): return c8.bite_report.get("done", false), 40.0)
	ok("S3_barricade", done and game.has_flag("ch8_entrance_secured") and c8._secure_pallet.position.distance_to(c8.SECURE_BLOCK) < 0.05)
	ok("S3_hound_gone_out", c8.hound == null)
	await wait_until(func(): return w.player.controls_enabled, 10.0)
	ok("S3_control_back", w.player.controls_enabled and w.player.camera.current)
	ok("S3_sarah_injured_kept", game.has_flag("ch8_sarah_injured") and String(c8.st().get("injured", "")) == "sarah")
	ok("S3_objective_moves_on", String(game.current_step().get("id", "")) != "c8_secure", String(game.current_step().get("id", "")))
	# ---- 4. once only; a save / load keeps it done
	var n0: int = int(c8.report.get("impacts", 0))
	c8._sarah_bite()
	await frames(30)
	ok("S4_once", not sg.active and int(c8.report.get("impacts", 0)) == n0)
	game.save_game()
	game.load_game()
	ok("S4_saved", game.has_flag("ch8_sarah_bitten") and game.has_flag("ch8_entrance_secured"))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
