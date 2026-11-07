extends SceneTree
## THE VEIL - death cinematic check (headless): outdoors on Main St during the Veil, then indoors (vignette).
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/death_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _one(game, outdoors: bool) -> void:
	game.new_game()
	for f in ["fridge_checked", "has_keys", "left_house", "entered_car", "reached_town", "parked", "groceries_done", "game_bought", "p3_mist", "phase2_done"]:
		game.flags[f] = true
	var ps: PackedScene = load("res://game/scenes/World.tscn")
	var w = ps.instantiate()
	root.add_child(w)
	await frames(30)
	var player = w.player
	player.global_position = (w.market.global_transform * Vector3(-4.0, 0.3, -24.0)) if outdoors else ((w.home.get_node("Markers/Spawn_WakeUp") as Node3D).global_position + Vector3(0, 0.2, 0))
	await frames(10)
	player.set_survival(true)
	var flags0: Dictionary = game.flags.duplicate()
	var inv0: Array = game.inventory.duplicate()
	player.damage(500.0, player.global_position + Vector3(1, 0, 0))
	await frames(2)
	var d = w.death
	ok("death_starts_%s" % outdoors, d != null and d.running and not player.controls_enabled and root.get_viewport().get_camera_3d() == d.cam)
	var hp_before: float = player.health
	player.damage(50.0, player.global_position)
	await frames(2)
	ok("death_once_%s" % outdoors, w.death == d and player.health == hp_before)
	var max_jump := 0.0
	var prev: Vector3 = d.cam.global_position
	var t := 0
	while not d.report.get("fade", false) and t < 60 * 14:
		await physics_frame
		t += 1
		if is_instance_valid(d.cam):
			var step: float = d.cam.global_position.distance_to(prev)
			if step < 5.0:                                 # the indoor cut to the vignette happens under black
				max_jump = maxf(max_jump, step)
			prev = d.cam.global_position
	var r: Dictionary = d.report
	ok("death_stages_%s" % outdoors, r.get("sky", false) and r.get("creatures_shown", false) and r.get("fade", false), str(r))
	ok("death_duration_%s" % outdoors, t > 60 * 7 and t < 60 * 11, "%.1f s" % (t / 60.0))
	ok("death_camera_smooth_%s" % outdoors, max_jump < 0.12, "%.3f m/frame" % max_jump)
	ok("death_cam_above_ground_%s" % outdoors, r.get("min_cam_clearance", 0.0) > 0.15, "%.2f m" % r.get("min_cam_clearance", -1.0))
	ok("death_colossus_veil_%s" % outdoors, r.get("veil_surfaces", 0) >= 3 and r.get("hound_veil_surfaces", 0) >= 3)
	ok("death_vignette_%s" % outdoors, r.get("vignette", true) == (not outdoors))
	ok("death_creatures_%s" % outdoors, r.get("creatures", 0) == 4 and absf(r.get("colossus_root_y", 9.0) + 0.34) < 0.05, str(r.get("colossus_root_y", -1)))
	await frames(20)
	ok("death_creatures_freed_%s" % outdoors, d.get_children().filter(func(c): return c is Node3D and c != d.cam and not c.is_queued_for_deletion()).is_empty())
	ok("death_panel_%s" % outdoors, d.has_node("DeathPanel") and d.get_node("DeathPanel").is_open())
	ok("death_flags_untouched_%s" % outdoors, game.inventory == inv0 and flags0.keys().all(func(k): return game.flags.has(k)))
	ok("death_audio_unmuffled_%s" % outdoors, AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Master")) == 0)
	w.queue_free()
	await frames(5)


func _run() -> void:
	var game = root.get_node("Game")
	await _one(game, true)
	await _one(game, false)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
