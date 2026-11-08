extends SceneTree
## THE VEIL - the inventory screen fills the window and its panel sits centred (it was stuck top-left on a 0x0
## rect). Headless, short; how it looks is for the playtest.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/inventory_layout_test.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60:
		await process_frame
	for id in ["flashlight", "batteries", "water_bottle"]:
		if not (id in game.inventory):
			game.inventory.append(id)
	var inv: Control = get_first_node_in_group("veil_inventory_panel")
	inv.open()
	for i in 10:
		await process_frame
	var vp := inv.get_viewport_rect().size
	var m: Control = inv._main
	var mid := m.global_position + m.size * 0.5
	var fills := inv.size.is_equal_approx(vp)
	var centred := mid.distance_to(vp * 0.5) < 4.0
	print("TEST fills_window %s %s" % ["PASS" if fills else "FAIL", inv.size])
	print("TEST panel_centred %s %s" % ["PASS" if centred else "FAIL", mid])
	var ok := fills and centred
	print("RESULT %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
