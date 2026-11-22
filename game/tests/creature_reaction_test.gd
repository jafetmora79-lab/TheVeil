extends SceneTree
## Review notes #39 / #40: shots scare a Hound after one hit, a Skitter after two, only sting a Shellcrawler; noises (shots, thrown things) send creatures to search the spot and
## they come for the player after 20 s.
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	game.flags["intro_seen"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await process_frame
	var ex = w.get("expedition")
	var at: Vector3 = w.player.global_position + Vector3(25, 0, 0)
	var sk = ex.make_hunter("skitter", at, [at], 60.0)
	var cr = ex.make_hunter("crab", at + Vector3(0, 0, 10), [at], 60.0)
	var ho = ex.make_hunter("skitter", at + Vector3(0, 0, -10), [at], 60.0)
	ho.sound_kind = "hound"
	for i in 20: await process_frame
	sk.shot()
	ok("skitter_first_shot_flinch", sk.state == "RECOVER" and not sk.flee, sk.state)
	sk.state = "PATROL"
	sk.shot()
	ok("skitter_second_shot_scares", sk.flee and sk.state == "RECOVER" and sk._recover_mode == "flee", sk.state)
	ho.shot()
	ok("hound_one_shot_scares", ho.flee and ho._recover_mode == "flee")
	cr.shot()
	cr.state = "PATROL"
	cr.shot()
	cr.state = "PATROL"
	cr.shot()
	ok("crab_never_scared", not cr.flee and cr.shots_taken == 3)
	# a noise: it goes to the spot, searches, then hunts
	var s2 = ex.make_hunter("skitter", at + Vector3(0, 0, 20), [at], 80.0)
	for i in 10: await process_frame
	var spot: Vector3 = at + Vector3(0, 0, 22)
	ok("investigate_accepts", s2.investigate(spot, 6.0, 20.0))
	ok("investigating", s2.state == "INVESTIGATE")
	s2._inv_search = 19.9                                   # (the search has nearly run its 20 s)
	s2.body.global_position = spot
	for i in 90: await process_frame
	ok("hunts_after_search", s2.state in ["CHASE", "SUSPICIOUS"] or s2.chases > 0, s2.state)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
