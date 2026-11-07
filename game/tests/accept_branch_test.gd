extends SceneTree
## THE VEIL - Chapter 4 ACCEPT branch ("we can't leave Noah"): the rooftop Skitter ambush, measured end to end.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/accept_branch_test.gd
## Starts from the Chapter 5 dev state with the night not yet played (overwrites user://veil_save.json).

const DEV5 := preload("res://game/tools/dev_chapter5.gd")
var fails := 0
var skitter_seen := false


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var game := root.get_node("Game")
	DEV5.prepare(game)
	# back to the night: the choice was "we can't leave Noah", the threat has not happened yet
	for f in ["p4_threat_done", "p4_slept", "p4_night_banging", "p4_choice_wait", "p4_hound_charged", "c5_started"]:
		game.flags.erase(f)
	game.flags["p4_choice_noah"] = true
	game.world_state["day"] = "friday"
	game.player_state = {"in_vehicle": false, "pos": [31.5, 0.2, -33.0], "yaw": 0.0}   # by Eddie, in the store
	game.save_game()
	game.load_game()
	game.load_requested = true
	change_scene_to_file("res://game/scenes/World.tscn")
	await frames(30)
	var world: Node = current_scene
	ok("accept_phase4_running", await wait_until(func(): return world.phase4 != null, 60 * 10))
	var p4: Node = world.phase4
	ok("accept_skitter_spawned", await wait_until(func(): return p4.charge_report.get("spawned", false), 60 * 15))
	ok("accept_threat_done", await wait_until(func(): return game.has_flag("p4_threat_done"), 60 * 60))
	var cr: Dictionary = p4.charge_report
	print("REPORT ", cr)
	ok("p4_skitter_starts_on_roof", cr.get("start", "") == "roof" and absf(cr.get("roof_feet_gap_m", 9.0)) < 0.06
		and not cr.has("roof_error"), str(cr.get("roof_feet_gap_m", cr.get("roof_error", "?"))))
	ok("p4_skitter_roof_zoom_sees_it", cr.get("roof_in_view", false) and cr.get("roof_line_of_sight", false)
		and cr.get("zoom_fov", 99.0) < 60.0, "fov %.1f dist %.1f m" % [cr.get("zoom_fov", -1.0), cr.get("roof_distance_m", -1.0)])
	ok("p4_skitter_jump_lands_on_street", cr.get("landed", false) and cr.get("air_max_dip_m", 9.0) < 0.05
		and absf(cr.get("landing_gap_m", 9.0)) < 0.05, "dip %.3f gap %.3f" % [cr.get("air_max_dip_m", -1.0), cr.get("landing_gap_m", -1.0)])
	ok("p4_skitter_paths_clear", cr.get("landing_found", false) and cr.get("run_clear", false) and cr.get("exit_clear", false))
	ok("p4_skitter_hits_shut_doors", cr.get("closed_before_hit", false) and cr.get("inside_at_hit", false)
		and absf(cr.get("hit_gap_m", 9.0)) < 0.25)
	ok("p4_skitter_runs_off", cr.get("left_into_fog", false) and world.find_children("P4_Skitter_Charge", "", true, false).is_empty())
	ok("p4_controls_back", world.player.controls_enabled)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
