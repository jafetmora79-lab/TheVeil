extends SceneTree
## Windowed probe: plays the intro and reports every frame longer than 40 ms (with the time into the intro).
##   godot --path . --script res://game/tests/intro_hitch_probe.gd
var w: Node


func _initialize() -> void:
	_run.call_deferred()
	create_timer(150.0).timeout.connect(func():
		print("RESULT watchdog")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	game.new_game()
	w = load("res://game/scenes/World.tscn").instantiate()
	w.force_intro = true
	root.add_child(w)
	var t0 := Time.get_ticks_usec()
	var last := t0
	var n := 0
	while not game.has_flag("intro_seen") and (Time.get_ticks_usec() - t0) < 120000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		n += 1
		if ms > 40.0:
			print("HITCH %.0f ms at %.1f s" % [ms, (now - t0) / 1e6])
	print("RESULT frames=%d total=%.1f s" % [n, (Time.get_ticks_usec() - t0) / 1e6])
	quit(0)
