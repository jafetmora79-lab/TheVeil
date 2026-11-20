extends SceneTree
## Plays the REAL Colossus encounter (supermarket street, the game's own fog) with a window and saves frames: what the player's camera sees, and a second camera from the
## side. Logs the eye's stage and where it looks, so the search twitches, the alert's overshoot and the lock can be seen in numbers as well.
##   godot --path . --fixed-fps 60 --resolution 640x360 --script res://game/tests/eye_world_capture.gd -- <out_dir> [every=6] [seconds=26]
## Needs a window (not --headless). Overwrites user://veil_save.json like the other world tests (back it up first).
var game: Node
var w: Node
var side_vp: SubViewport
var side_cam: Camera3D
var out := "."
var every := 6
var seconds := 26.0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "."
	for e in a:
		if String(e).begins_with("every="):
			every = int(String(e).substr(6))
		if String(e).begins_with("seconds="):
			seconds = float(String(e).substr(8))
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	game.new_game()
	for f in ["has_keys", "fridge_checked", "left_house", "entered_car", "game_bought"]:
		game.flags[f] = true
	if not game.has_item("car_keys"):
		game.add_item("car_keys")
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(150)
	var mk: Node3D = w.market
	w.player.global_position = mk.global_transform * Vector3(0.0, 0.2, 6.0)
	await frames(10)
	game.set_flag("groceries_done")
	for i in 600:
		if game.has_flag("p3_mist"):
			break
		await process_frame
	await frames(60 * 4)
	var door_out: Vector3 = (mk.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var door_in: Vector3 = (mk.get_node("Doorways/Entrance_Inside") as Node3D).global_position
	var nrm := ((door_out - door_in) * Vector3(1, 0, 1)).normalized()
	w.player.global_position = door_out + nrm * 1.2 + Vector3(0, 0.2, 0)
	for i in 360:
		if w._encounter_running:
			break
		await process_frame
	print("ENCOUNTER running ", w._encounter_running)
	# the side camera: its own viewport onto the same world
	side_vp = SubViewport.new()
	side_vp.size = Vector2i(640, 360)
	side_vp.world_3d = root.world_3d
	side_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(side_vp)
	side_cam = Camera3D.new()
	side_cam.far = 700.0
	side_cam.fov = 55.0
	side_vp.add_child(side_cam)
	var n := 0
	var t := 0.0
	var f := 0
	while t < seconds:
		await process_frame
		t += 1.0 / 60.0
		f += 1
		var tc: Node3D = w.get_node_or_null("Colossus_Encounter")
		if tc == null:
			continue
		var eye: VeilTripodEye = tc.eye
		if side_cam != null:
			var p: Vector3 = tc.global_position
			var base := Vector3(w.player.global_position.x, p.y, w.player.global_position.z)
			var to_p := (base - p) * Vector3(1, 0, 1)
			var perp := to_p.normalized().cross(Vector3.UP)
			side_cam.global_position = p + to_p * 0.35 + perp * 60.0 + Vector3(0, 30.0, 0)
			side_cam.look_at(p + to_p * 0.45 + Vector3(0, 28.0, 0), Vector3.UP)
		if f % every == 0:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/main_%04d.png" % [out, n])
			side_vp.get_texture().get_image().save_png("%s/side_%04d.png" % [out, n])
			var tgt := ""
			var err := -1.0
			if eye.target != null:
				tgt = eye.target.name
				err = rad_to_deg(eye._gaze.angle_to((eye.target.global_position - eye.ball.global_position).normalized()))
			print("EYE n %d t %.2f stage %d target %s gaze_err_deg %.1f beam_len %.1f still %.2f search_k %.2f hot %.2f" % [n, t, eye.stage, tgt, err, float(eye.report.get("beam_len", 0.0)), eye._still, eye._search_k, eye._hot])
			n += 1
	print("EYE report ", w.get_node_or_null("Colossus_Encounter").eye.report if w.get_node_or_null("Colossus_Encounter") else "gone")
	print("RESULT captured ", n)
	quit(0)
