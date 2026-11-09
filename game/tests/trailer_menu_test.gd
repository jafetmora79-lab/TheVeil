extends SceneTree
## THE VEIL - trailer mode from the main menu: with --trailer the menu shows PLAY TRAILER and it starts the trailer;
## in trailer mode the T key starts it too (no F-key needed). Run with the argument:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/trailer_menu_test.gd -- --trailer

var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func until(f: Callable, s: float) -> bool:
	for i in int(s * 60.0):
		if f.call():
			return true
		await process_frame
	return f.call()


func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	game.set_meta("trailer_test", true)
	ok("trailer_arg_seen", load("res://game/trailer/trailer_mode.gd").wanted())
	change_scene_to_file("res://game/scenes/MainMenu.tscn")
	await until(func(): return current_scene != null and current_scene.name != "", 5.0)
	for i in 10:
		await process_frame
	var btn: Button = null
	for b in current_scene.find_children("*", "Button", true, false):
		if (b as Button).text.contains("PLAY TRAILER"):
			btn = b
	ok("menu_has_play_trailer", btn != null)
	ok("trailer_mode_on_in_menu", root.get_node_or_null("TrailerMode") != null)
	if btn:
		btn.pressed.emit()
	ok("button_starts_trailer", await until(func(): return root.get_node_or_null("TrailerDirector") != null and game.has_meta("trailer_run"), 5.0))
	var d = root.get_node_or_null("TrailerDirector")
	await until(func(): return d.get("cam") != null, 20.0)
	ok("trailer_camera_running", d.get("cam") != null and int(d.report["shots"]) >= 1 or await until(func(): return int(d.report["shots"]) >= 1, 20.0))
	# stop it, then T starts it again
	d.aborted = true
	await until(func(): return not game.has_meta("trailer_run"), 15.0)
	d.queue_free()
	await process_frame
	var ev := InputEventKey.new()
	ev.keycode = KEY_T
	ev.physical_keycode = KEY_T
	ev.pressed = true
	Input.parse_input_event(ev)
	ok("t_key_starts_trailer", await until(func(): return root.get_node_or_null("TrailerDirector") != null and game.has_meta("trailer_run"), 5.0))
	var d2 = root.get_node_or_null("TrailerDirector")
	if d2:
		d2.aborted = true
		await until(func(): return not game.has_meta("trailer_run"), 15.0)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
