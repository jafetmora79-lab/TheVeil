extends SceneTree
## THE VEIL - the game shop's stock-room door: locked (staff only) before the Colossus, an ordinary door after it,
## its state saved. Headless, short.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/stock_door_test.gd

var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(200.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _world(game: Node) -> Node:
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(60)
	return w


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	var w: Node = await _world(game)
	var it: Interactable = w.stock_door_it
	ok("door_exists", it != null and it.kind == "hinge")
	var leaf: Node3D = it.target
	var closed: Transform3D = leaf.get_meta("closed_xf")
	it.interact(w.player)
	await frames(40)
	ok("locked_before_colossus", not it.is_open and leaf.transform.basis.is_equal_approx(closed.basis))
	game.flags["p3_stepped_out"] = true
	it.interact(w.player)
	await frames(40)
	ok("opens_after_colossus", it.is_open and not leaf.transform.basis.is_equal_approx(closed.basis))
	it.interact(w.player)
	await frames(40)
	ok("closes_again", not it.is_open and leaf.transform.basis.is_equal_approx(closed.basis))
	# the scene's own door moves keep the [E] state in step
	await w._stock_door(true, 0.1)
	ok("scene_open_synced", it.is_open)
	it.interact(w.player)                          # the player can shut what the scene opened
	await frames(40)
	ok("player_closes_scene_door", not it.is_open)
	# saved open -> open after a reload (a quit mid-scene)
	await w._stock_door(true, 0.1)
	game.save_game()
	w.queue_free()
	await frames(5)
	game.load_game()
	var w2: Node = await _world(game)
	var it2: Interactable = w2.stock_door_it
	ok("open_after_reload", it2 != null and it2.is_open)
	it2.interact(w2.player)
	await frames(40)
	ok("usable_after_reload", not it2.is_open)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
