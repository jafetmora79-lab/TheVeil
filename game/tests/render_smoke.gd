extends SceneTree
## THE VEIL - Compatibility-renderer smoke run (no screenshots): main menu, then the world through the
## wake-up, the house, the yard and a stretch of driving. Prints frame timings and "RENDER OK".
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://game/tests/render_smoke.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var menu = load("res://game/scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	for i in 30:
		await process_frame
	menu.queue_free()
	root.get_node("Game").new_game()
	var t0 := Time.get_ticks_msec()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await process_frame
	print("WORLD_LOAD_MS ", Time.get_ticks_msec() - t0)
	var stats := []
	for phase in ["bedroom", "yard", "car"]:
		if phase == "yard":
			w.player.global_position = w.get_node("Trigger_LeftHouse").global_position
		elif phase == "car":
			root.get_node("Game").set_flag("fridge_checked")
			root.get_node("Game").add_item("car_keys")
			w.enter_car()
			w.sedan.autopilot = func(_d): return Vector3(0.6, 0, 0)
		var f0 := Time.get_ticks_msec()
		for i in 120:
			await process_frame
		var ms := float(Time.get_ticks_msec() - f0) / 120.0
		stats.append("%s=%.1fms/frame draw_calls=%d" % [phase, ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("FRAMES ", " ".join(stats))
	print("RENDER OK driver=", RenderingServer.get_video_adapter_name(), " api=", RenderingServer.get_video_adapter_api_version())
	quit()
