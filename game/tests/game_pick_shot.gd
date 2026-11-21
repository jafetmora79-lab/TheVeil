extends SceneTree
## Review note #10: a picture of the Hollow Hill pickup scene at the zoomed moment.  godot --path . --resolution 960x540 --script res://game/tests/game_pick_shot.gd -- out=<png>
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var out := "C:/Users/Themo/AppData/Local/Temp/game_pick.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	var game = root.get_node("Game")
	game.new_game()
	game.flags["intro_seen"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 90: await process_frame
	w.player.global_position = Vector3(12.9, 0.3, 10.9)
	w.player.set_yaw_pitch(-PI * 0.5, -0.2)
	w._game_pick_scene()
	await create_timer(1.55).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	var done_ok := false
	for i in 600:
		await process_frame
		if not w._game_pick_busy:
			done_ok = true
			break
	print("PICK scene finished: ", done_ok, " controls back: ", w.player.controls_enabled, " fov ", w.player.camera.fov)
	quit()
