extends SceneTree
## THE VEIL - the auto-played trailer ("The Change"): runs end to end in one world through all seven parts, never
## writes the save, and Esc stops it. Headless; how it looks is for the recording.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/trailer_test.gd

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
	create_timer(400.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	game.set_meta("trailer_test", true)
	var save_t := FileAccess.get_modified_time(game.SAVE_PATH) if FileAccess.file_exists(game.SAVE_PATH) else -1
	load("res://game/trailer/trailer_director.gd").start(self)
	await until(func(): return root.get_node_or_null("TrailerDirector") != null, 5.0)
	var d: Node = root.get_node_or_null("TrailerDirector")
	ok("director_running", d != null)
	ok("no_save_during", game.no_save)
	var f0 := Engine.get_process_frames()
	ok("trailer_completes", await until(func(): return d.report.get("done", false), 200.0))
	var secs := (Engine.get_process_frames() - f0) / 60.0
	ok("all_parts", (d.report["segments"] as Array) == ["ordinary", "falling", "shape", "run", "survive", "morning", "end"], str(d.report["segments"]))
	ok("shots", int(d.report["shots"]) >= 17, "%d shots, skipped %s" % [int(d.report["shots"]), str(d.report.get("skipped", []))])
	ok("length", secs > 70.0 and secs < 140.0, "%.0f s" % secs)
	await until(func(): return not game.has_meta("trailer_run"), 10.0)
	ok("save_untouched", (FileAccess.get_modified_time(game.SAVE_PATH) if FileAccess.file_exists(game.SAVE_PATH) else -1) == save_t)
	ok("saving_back_on", not game.no_save)
	if is_instance_valid(d):
		d.queue_free()
	await process_frame
	# Esc stops it
	load("res://game/trailer/trailer_director.gd").start(self)
	await until(func(): return root.get_node_or_null("TrailerDirector") != null and root.get_node("TrailerDirector").get("cam") != null, 20.0)
	var d2: Node = root.get_node_or_null("TrailerDirector")
	await until(func(): return int(d2.report["shots"]) >= 2, 30.0)
	Input.action_press("pause")
	await process_frame
	await process_frame
	Input.action_release("pause")
	ok("esc_stops", await until(func(): return not game.has_meta("trailer_run"), 15.0) and d2.aborted)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
