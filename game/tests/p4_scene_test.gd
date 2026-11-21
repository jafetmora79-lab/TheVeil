extends SceneTree
## Chapter 4/5 shelter scenes: the bedding piles disappear once taken; the breaker is a real box (door, lever, switch) and the lights only come back after it is shut;
## Marcus hands over the town map as soon as the morning talks are done; companions at the doors open them; the shelter menu is closed while the story still needs a talk.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/p4_scene_test.gd
const DEV := preload("res://game/chapters/setups/dev_chapter5.gd")
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
	create_timer(150.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(200)
	var p4 = w.phase4
	game.flags.erase("c5_talked_both")
	p4.chapter5._refresh_prompts()
	var sd = w.expedition.story_door()
	ok("exit_blocked_until_talks_done", sd != null and String(sd.own_prompt()).begins_with("NOT YET - TALK") and not w.expedition.scavenge_available(), str(sd.own_prompt() if sd else "-"))
	# the bedding piles: gone when taken
	game.flags.erase("p4_bed_card")
	game.flags.erase("p4_bed_soft")
	game.flags.erase("p4_slept")
	game.flags["p4_threat_done"] = true
	p4._bed_state()
	var card: Node3D = p4.its["bed_card"].get_parent()
	var soft: Node3D = p4.its["bed_soft"].get_parent()
	ok("piles_visible_before", card.visible and soft.visible)
	p4._take_bedding("card")
	p4._take_bedding("soft")
	ok("piles_gone_after", not card.visible and not soft.visible)
	# the breaker box
	game.flags.erase("p4_breaker")
	ok("breaker_box_built", p4._bx != null and p4._bx_door != null and p4._bx_lever != null and p4._bx_switch != null)
	p4._bx_lever.rotation.x = deg_to_rad(-70.0)
	p4._bx_switch.rotation.x = deg_to_rad(-45.0)
	var door_max := 0.0
	var lights_when_door_open := false
	p4._throw_breaker(null)
	for i in 60 * 6:
		await physics_frame
		door_max = maxf(door_max, absf(p4._bx_door.rotation.y))
		if absf(p4._bx_door.rotation.y) > 0.5 and game.has_flag("p4_breaker"):
			lights_when_door_open = true
	ok("breaker_door_opened", door_max > deg_to_rad(90.0), "%.0f deg" % rad_to_deg(door_max))
	ok("breaker_lever_thrown", p4._bx_lever.rotation.x > 0.0 and p4._bx_switch.rotation.x > 0.0)
	ok("breaker_door_shut_again", absf(p4._bx_door.rotation.y) < 0.05)
	ok("lights_only_after_closing", game.has_flag("p4_breaker") and not lights_when_door_open)
	ok("controls_back", w.player.controls_enabled)
	# Marcus gives the map after the morning talks
	game.flags.erase("map_acquired")
	game.flags.erase("c5_talked_both")
	game.flags["c5_eddie_talked"] = true
	game.flags["c5_marcus_talked"] = true
	var c5 = p4.chapter5
	c5._after_talk()
	var t := 0
	while not game.has_flag("map_acquired") and t < 60 * 40:
		await physics_frame
		t += 1
	ok("marcus_gives_map", game.has_flag("map_acquired") and game.has_flag("c5_talked_both"), "%.1f s" % (t / 60.0))
	# a follower at the doors opens them
	c5._set_doors(false)
	var m: Node3D = w.market
	var spot: Vector3 = m.to_global(Vector3(0.0, 0.0, -1.0))
	var eddie: Node3D = w.eddie
	eddie.global_position = spot
	c5.eddie_follow.active = true
	ok("follower_near_doors_seen", c5._followers_near_doors())
	w.expedition.story_departure = true
	await frames(40)
	ok("follower_opens_doors", c5._doors_open)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
