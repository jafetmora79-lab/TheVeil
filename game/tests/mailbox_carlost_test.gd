extends SceneTree
## Review notes #133 (mailboxes) and #128 (the lost car): boxes are interactable and decided once; after the supermarket falls the car cannot be entered and skitters crawl round it outdoors.
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
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 90: await physics_frame
	var mb = w.get_node("Mailboxes")
	ok("mailboxes_attached", mb.its.size() >= 3, str(mb.its.size()))
	var key: String = mb.its.keys()[0]
	var it: Interactable = mb.its[key]
	var n: Node3D = it.get_parent() as Node3D
	var first: String = mb._roll(key)
	ok("roll_is_stable", mb._roll(key) == first)
	mb._open(n, it, key)
	ok("box_remembered", game.world_state["mailboxes"].has(key) and it.prompt_text == "")
	var inv0: int = game.inventory.size()
	mb._open(n, it, key)
	ok("never_twice", game.inventory.size() == inv0)
	# the lost car
	var cl = w.get_node("CarLost")
	game.set_flag("ch9_supermarket_lost")
	w.player.global_position = w.sedan.global_position + Vector3(6.0, 0.2, 0.0)
	var t := 0.0
	while cl._sk.is_empty() and t < 6.0:
		await process_frame
		t += 1.0 / 60.0
	ok("skitters_crawl_round_the_car", cl._sk.size() == 3, "%d after %.1f s" % [cl._sk.size(), t])
	var far: float = cl._sk[0].global_position.distance_to(w.sedan.global_position) if not cl._sk.is_empty() else 99.0
	ok("they_keep_to_the_car", far < 5.0, "%.1f m" % far)
	await w.enter_car()
	ok("cannot_enter", not w.in_car)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
