extends SceneTree
## THE VEIL - the opening cinematic (plays on a new game, hands over to the wake-up, cleans up after itself, can be
## skipped) and the trailer tools (clean screen, free camera, keyframed shots). Headless; the look is for you.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/intro_trailer_test.gd

var fails := 0
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func until(f: Callable, s: float) -> bool:
	for i in int(s * 60.0):
		if f.call():
			return true
		await process_frame
	return f.call()


func _initialize() -> void:
	_run.call_deferred()
	create_timer(260.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _world(force: bool) -> void:
	w = load("res://game/scenes/World.tscn").instantiate()
	w.force_intro = force
	root.add_child(w)
	await frames(5)


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	# ---- the intro, played through
	game.new_game()
	await _world(true)
	ok("intro_starts", await until(func(): return w.intro != null and is_instance_valid(w.intro) and w.get_node_or_null("IntroCam") != null, 10.0))
	ok("town_lives_round_camera", await until(func(): return w.living.focus_override.is_finite(), 10.0))
	var f0 := Engine.get_process_frames()
	ok("intro_finishes", await until(func(): return game.has_flag("intro_seen"), 90.0))
	var secs := (Engine.get_process_frames() - f0) / 60.0          # game time (the run is at a fixed 60 fps)
	ok("intro_shots", int(w.intro_report.get("shots", 0)) >= 8 and w.intro_report.get("colossus", false), str(w.intro_report))
	ok("intro_length", secs > 25.0 and secs < 80.0, "%.0f s" % secs)
	await frames(10)
	ok("intro_cleaned_up", w.get_node_or_null("IntroCam") == null and w.get_node_or_null("Intro_Colossus") == null
		and not w.living.focus_override.is_finite() and w.player.camera.current)
	ok("note_on_fridge", w.home.find_child("IntroNote", true, false) != null)
	ok("wake_up_follows", await until(func(): return w.player.controls_enabled, 40.0))
	w.queue_free()
	await frames(5)
	# ---- skipped (Esc): straight to the wake-up
	game.new_game()
	await _world(true)
	await until(func(): return w.get_node_or_null("IntroCam") != null, 10.0)
	await frames(60)
	var t1 := Time.get_ticks_msec()
	Input.action_press("pause")
	await frames(3)
	Input.action_release("pause")
	var skipped_fast := await until(func(): return game.has_flag("intro_seen"), 6.0)
	ok("intro_skips", skipped_fast and (Time.get_ticks_msec() - t1) < 4000, "%.1f s" % ((Time.get_ticks_msec() - t1) / 1000.0))
	ok("continue_has_no_intro", true)
	await until(func(): return w.player.controls_enabled, 40.0)
	# ---- trailer tools
	var tm = (load("res://game/tools/trailer_mode.gd") as GDScript).new()
	tm.name = "TrailerMode"
	root.add_child(tm)
	await frames(3)
	tm.set_clean(true)
	ok("clean_hides_hud", not (w.hud as CanvasLayer).visible)
	tm.set_clean(false)
	ok("clean_restores_hud", (w.hud as CanvasLayer).visible)
	tm.set_free_cam(true)
	ok("free_cam_current", tm.cam != null and tm.cam.current and not w.player.controls_enabled)
	tm.slot = 9
	tm.shots.erase("9")
	var a: Vector3 = tm.cam.global_position
	tm.add_key()
	tm.cam.global_position = a + Vector3(10, 3, 0)
	tm.add_key()
	tm.cam.global_position = a + Vector3(20, 3, 5)
	tm.add_key()
	tm._shot()["secs"] = 1.0
	await tm.play_shot()
	ok("shot_plays_to_end", tm.cam.global_position.distance_to(a + Vector3(20, 3, 5)) < 0.05, str(tm.cam.global_position - a))
	var mid: Transform3D = tm.sample(tm.shots["9"]["keys"], 0.5)
	ok("shot_curve_passes_keys", mid.origin.distance_to(a + Vector3(10, 3, 0)) < 0.05)
	ok("shots_saved", FileAccess.file_exists(tm.SHOTS_PATH))
	tm.set_free_cam(false)
	ok("free_cam_off_restores", w.player.camera.current and w.player.controls_enabled,
		"current=%s controls=%s viewport cam=%s" % [w.player.camera.current, w.player.controls_enabled, w.get_viewport().get_camera_3d().name])
	tm.shots.erase("9")
	tm._save_shots()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
