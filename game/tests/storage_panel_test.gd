extends SceneTree
## Review note #99: the supplies chest as two grids; take / put one by click.
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(90.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	game.world_state["supply_grace"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	game.add_item("canned_food")
	game.add_item("canned_food")
	game.add_item("flashlight")
	var st: Dictionary = game.shelter_stock()
	var f0: int = int(st.get("food", 0))
	w.phase4._open_supplies()
	for i in 5: await process_frame
	var pn = null
	for c in w.phase4.get_children():
		if c.has_method("_put"):
			pn = c
	ok("panel_open", pn != null and w.get_tree().paused)
	if pn:
		ok("grids_25", pn._left.get_child_count() == 25 and pn._right.get_child_count() == 25, "%d/%d" % [pn._left.get_child_count(), pn._right.get_child_count()])
		pn._put("canned_food", false)
		ok("put_one", int(game.shelter_stock().get("food", 0)) == f0 + 1 and game.inventory.count("canned_food") == 1)
		pn._take("food", false)
		ok("take_one", int(game.shelter_stock().get("food", 0)) == f0 and game.inventory.count("canned_food") == 2)
		pn._put("flashlight", false)
		ok("flashlight_refused", game.has_item("flashlight"))
		pn._close(false)
	for i in 3: await process_frame
	ok("closed_unpaused", not w.get_tree().paused)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
