extends SceneTree
## The handgun is a quick-slot item (auto-placed, its slot draws it, any other slot holsters it), the mouse wheel steps through the slots, and a dropped item is always visible.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/quickslot_gun_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()
	create_timer(60.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	game.new_game()
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 40:
		await process_frame
	var q: VeilQuickSlots = w.hud.quick
	var sa = w.sidearm
	game.add_item("handgun")
	game.world_state["quickslots"] = ["", "", "", "", ""]
	game.inventory_changed.emit()
	await process_frame
	var gi: int = VeilQuickSlots.slots().find("handgun")
	ok("gun_in_a_slot", gi >= 0, str(VeilQuickSlots.slots()))
	q.use(gi)
	ok("slot_draws_gun", sa.drawn())
	var other := (gi + 1) % 5
	q.use(other)
	ok("other_slot_holsters", not sa.drawn())
	q.use(gi)
	q.step(1)
	ok("wheel_moves_and_holsters", q.selected == (gi + 1) % 5 and not sa.drawn(), str(q.selected))
	q.step(-1)
	ok("wheel_back_draws_again", q.selected == gi and sa.drawn())
	for i in 5:
		q.step(1)
	ok("wheel_wraps_round", q.selected == gi)
	# a dropped item without a model of its own is a visible object
	var th = w.throwing if w.get("throwing") != null else null
	if th == null:
		for c in w.get_children():
			if c is VeilThrowing:
				th = c
	var id := ""
	for k in game.items:
		var inf: Dictionary = game.item_info(String(k))
		if String(inf.get("category", "")) in ["food", "medical", "misc"] and String(inf.get("model", "")) == "":
			id = String(k)
			break
	if th != null and id != "":
		game.add_item(id)
		var rb: RigidBody3D = th._spawn(id, Vector3.ZERO, false)
		await process_frame
		var meshes := rb.find_children("*", "MeshInstance3D", true, false)
		ok("dropped_item_visible", not meshes.is_empty(), id)
	else:
		print("TEST dropped_item_visible SKIP (no model-less droppable item found / no throwing node)")
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
