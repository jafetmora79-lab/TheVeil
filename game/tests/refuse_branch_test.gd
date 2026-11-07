extends SceneTree
## THE VEIL - Chapter 4 REFUSE branch ("wait until morning"): no Skitter, no rooftop scene, nobody goes out; the
## night banging at the back door plays; the story moves on to Chapter 5.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/refuse_branch_test.gd
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
		if current_scene and not current_scene.find_children("P4_Skitter*", "", true, false).is_empty():
			skitter_seen = true


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
	# back to the night: the choice was "wait", the threat and the sleep have not happened yet
	for f in ["p4_threat_done", "p4_slept", "p4_night_banging", "p4_choice_noah", "p4_hound_charged", "c5_started"]:
		game.flags.erase(f)
	game.world_state["day"] = "friday"
	game.save_game()
	game.load_game()
	game.load_requested = true
	change_scene_to_file("res://game/scenes/World.tscn")
	await frames(30)
	var world: Node = current_scene
	ok("refuse_phase4_running", await wait_until(func(): return world.phase4 != null, 60 * 10))
	var p4: Node = world.phase4
	ok("refuse_wait_choice", game.has_flag("p4_choice_wait") and not game.has_flag("p4_choice_noah"))
	ok("refuse_threat_resolves_inside", await wait_until(func(): return game.has_flag("p4_threat_done"), 60 * 20))
	await frames(60)
	ok("refuse_no_skitter", not skitter_seen and p4.charge_report.is_empty() and not game.has_flag("p4_hound_charged"),
		str(p4.charge_report))
	ok("refuse_stays_inside", world.market.to_local(world.player.global_position).z > 0.5)
	p4._on_slept("")
	ok("refuse_night_banging", await wait_until(func(): return game.has_flag("p4_night_banging") and p4.night_bangs == 1, 60 * 30))
	ok("refuse_story_continues", await wait_until(func(): return game.has_flag("c5_started"), 60 * 30)
		and game.world_state.get("day", "") == "saturday")
	ok("refuse_no_skitter_all_night", not skitter_seen)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
