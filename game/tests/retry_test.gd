extends SceneTree
## THE VEIL - the loading-door tentacle: fail it, RETRY, three times over (real scene reloads, as in the game), then
## save / load once more. Passes when every retry brings back a working world (player in control, the encounter
## ready again) and nothing errors. Headless, --fixed-fps 60.
const DEV := preload("res://game/tools/dev_chapter7.gd")

var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	change_scene_to_file("res://game/scenes/World.tscn")
	await _frames(200)
	for round_i in 3:
		var w = current_scene
		# back to the moment before the loading door (the flashlight in hand)
		for f in ["p4_garage_done", "p4_loading_down", "p4_loading_secured"]:
			game.flags.erase(f)
		game.flags["p4_flashlight"] = true
		w.phase4._apply()
		var g = w.phase4.garage
		g.running = false
		g.closing = false
		var p = w.player
		p.controls_enabled = true
		p.look_enabled = true
		p.global_position = w.market.global_transform * Vector3(18.6, 0.3, 15.9)
		await _frames(5)
		g._on_enter()
		var t := 0
		while t < 900 and not (g.running and g.time_left > 0.0):
			await physics_frame
			t += 1
		ok("round%d_encounter_started" % round_i, g.running and g.time_left > 0.0, "after %d frames" % t)
		g.time_left = 0.01                                # the door was not pulled down in time
		var panel = null
		t = 0
		while t < 900 and panel == null:
			await physics_frame
			t += 1
			panel = w.get_node_or_null("DeathPanel")
		ok("round%d_death_screen" % round_i, panel != null)
		if panel == null:
			break
		while not panel.is_open() and t < 1200:
			await physics_frame
			t += 1
		panel.pick(0)                                     # RETRY
		t = 0
		while t < 600 and (current_scene == w or current_scene == null):
			await process_frame
			t += 1
		await _frames(200)
		var w2 = current_scene
		ok("round%d_reloaded" % round_i, w2 != null and w2 != w and w2.get("player") != null, "frames %d" % t)
		if w2 == null or w2 == w:
			break
		var p2 = w2.player
		ok("round%d_player_in_control" % round_i, p2.controls_enabled and p2.look_enabled and not paused,
			"controls=%s look=%s paused=%s" % [p2.controls_enabled, p2.look_enabled, paused])
		ok("round%d_encounter_ready_again" % round_i, not w2.phase4.garage.running and not game.has_flag("p4_garage_done"))
	# carry on after the retries: save, load again
	var w3 = current_scene
	w3.save()
	ok("save_after_retries", game.load_game())
	print("RETRY fails=%d" % fails)
	quit(1 if fails > 0 else 0)
