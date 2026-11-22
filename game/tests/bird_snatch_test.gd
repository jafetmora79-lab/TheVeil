extends SceneTree
## Review note #91: the Grimtalon dive. Crouch in time -> they pass; stay standing -> scratched, then taken (death).
var fails := 0


func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game = root.get_node("Game")
	game.no_save = true
	game.flags["p3_stepped_out"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var b = load("res://game/world/bird_snatch.gd").new()
	w.add_child(b)
	b.setup(w)
	w.player.global_position = Vector3(10, 1, 10)
	b.trigger()
	w.player.force_crouch = true
	for i in 260: await physics_frame
	ok("ducked", b.report["ducked"] == 1 and not b.busy or b.report["ducked"] == 1, str(b.report))
	w.player.force_crouch = false
	w.player.crouching = false
	for i in 200: await physics_frame
	var h0: float = w.player.health
	b.trigger()
	for i in 260: await physics_frame
	ok("scratched", b.report["scratched"] == 1 and w.player.health < h0, str(b.report))
	for i in 200: await physics_frame
	b.trigger()
	for i in 600: await physics_frame
	ok("snatched", b.report["snatched"] == 1, str(b.report))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
