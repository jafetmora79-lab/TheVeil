extends SceneTree
## THE VEIL - throwing a bottle / can (G) and the film-look layer (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/throw_test.gd
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


class FakeHound extends Node:
	var body: Node3D
	var got := []
	var state := "PATROL"
	func investigate(at: Vector3, linger: float) -> bool:
		got.append([at, linger])
		return true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	world.player.controls_enabled = true
	world.hud.fade_to(0.0, 0.01)
	var th = world.throwing
	ok("throwing_present", th != null and world.screen_fx != null)
	ok("film_look_layer_below_hud", world.screen_fx.layer < world.hud.layer, "%d < %d" % [world.screen_fx.layer, world.hud.layer])
	# nothing selected: no throw, a hint instead
	ok("no_throw_without_selection", not th.try_throw())
	# a bottle in the selected quick slot
	game.add_item("water_bottle")
	await frames(5)
	VeilQuickSlots.assign(0, "water_bottle")
	var q := root.get_tree().get_first_node_in_group("veil_quick_slots") as VeilQuickSlots
	ok("quick_slots_in_group", q != null)
	q.selected = 0
	ok("bottle_is_selected_throwable", th.selected_throwable() == "water_bottle")
	# a Hound within earshot, and one far away
	var near := FakeHound.new()
	near.body = Node3D.new()
	world.add_child(near.body)
	near.body.global_position = world.player.global_position + Vector3(6, 0, 0)
	near.add_to_group("veil_hunter")
	world.add_child(near)
	var far := FakeHound.new()
	far.body = Node3D.new()
	world.add_child(far.body)
	far.body.global_position = world.player.global_position + Vector3(400, 0, 0)
	far.add_to_group("veil_hunter")
	world.add_child(far)
	var before: bool = game.has_item("water_bottle")
	ok("throw_happens", th.try_throw())
	ok("bottle_leaves_inventory", before and not game.has_item("water_bottle"))
	for i in 60 * 5:
		if th.report["impacts"] > 0:
			break
		await process_frame
	ok("bottle_lands", th.report["impacts"] >= 1, str(th.report))
	ok("near_hound_goes_to_look", near.got.size() >= 1 and far.got.is_empty(), "%d near, %d far" % [near.got.size(), far.got.size()])
	var rb: Node = world.get_node_or_null("Thrown_water_bottle")
	ok("thrown_body_own_layer", rb != null and rb.collision_layer == (1 << 5) and rb.collision_layer & 2 == 0)
	# ---- dropping: a real body that makes a sound and can be picked up again
	game.add_item("water_bottle")
	await frames(3)
	VeilQuickSlots.assign(1, "water_bottle")
	q.selected = 1
	await frames(40)                                  # (the throw cooldown)
	ok("drop_happens", th.try_drop())
	ok("dropped_leaves_inventory", not game.has_item("water_bottle"))
	var dropped: Node = world.get_node_or_null("Dropped_water_bottle")
	ok("dropped_body_exists", dropped != null)
	for i in 60 * 4:
		if th.report["drop_impacts"] > 0:
			break
		await process_frame
	ok("drop_lands_with_a_sound", th.report["drop_impacts"] >= 1, str(th.report))
	var pick: Interactable = null
	if dropped:
		for c in dropped.get_children():
			if c is Interactable:
				pick = c
	ok("dropped_item_is_a_pickup", pick != null and pick.kind == "pickup" and pick.item_id == "water_bottle")
	if pick:
		pick.interact(world.player)
	ok("dropped_item_can_be_taken_back", game.has_item("water_bottle"))
	game.add_item("car_keys")
	await frames(3)
	VeilQuickSlots.assign(2, "car_keys")
	q.selected = 2
	await frames(40)
	ok("keys_are_never_dropped", not th.try_drop() and game.has_item("car_keys"))
	# ---- impact loudness grows with speed, pitch falls with weight
	ok("impact_louder_when_faster", th.impact_volume(8.0) > th.impact_volume(2.0))
	ok("impact_lower_when_heavier", th.impact_pitch(3.0) < th.impact_pitch(0.4))
	# ---- hold to use: a heavy pickup asks for a held key press
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	holder.add_child(mi)
	world.add_child(holder)
	holder.global_position = world.player.global_position + Vector3(0, 0, 3)
	var heavy := Interactable.attach(holder, {"kind": "pickup", "label": "Fuel", "item_id": "fuel_can"})
	ok("heavy_pickup_needs_a_hold", heavy.hold_time > 0.0 and heavy.own_prompt().contains("HOLD"), heavy.own_prompt())
	var light := Interactable.attach(holder, {"kind": "pickup", "label": "Water", "item_id": "water_bottle"})
	ok("light_pickup_is_instant", light.hold_time == 0.0)
	var pl = world.player
	var rings: Array = []
	pl.hold_progress.connect(func(r): rings.append(r))
	pl._focus = heavy
	pl._hold_target = heavy
	pl._hold_t = 0.0
	Input.action_press("interact")
	var had: bool = game.has_item("fuel_can")
	for i in 20:
		pl._focus = heavy
		pl._update_hold(0.016)
	ok("hold_not_done_early", not game.has_item("fuel_can") and rings.size() > 0 and rings.back() < 1.0)
	for i in 40:
		pl._focus = heavy
		pl._update_hold(0.016)
	ok("hold_completes_the_pickup", game.has_item("fuel_can") and not had, str(rings.back()))
	Input.action_release("interact")
	# releasing early cancels
	pl._focus = light
	pl._hold_target = heavy
	pl._hold_t = 0.3
	pl._update_hold(0.016)
	ok("hold_cancels_when_looking_away", pl._hold_target == null and rings.back() == 0.0)
	# ---- the rim on every kind of interactable
	var door := Node3D.new()
	var dm := MeshInstance3D.new()
	dm.mesh = BoxMesh.new()
	door.add_child(dm)
	world.add_child(door)
	var hinge := Interactable.attach(door, {"kind": "hinge", "label": "Door"})
	hinge.set_focus(true)
	ok("door_gets_the_rim", dm.material_overlay != null)
	hinge.set_focus(false)
	ok("door_rim_clears", dm.material_overlay == null)
	var big := Node3D.new()
	var bm := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(20, 6, 20)
	bm.mesh = bx
	big.add_child(bm)
	world.add_child(big)
	var obs := Interactable.attach(big, {"kind": "observe", "label": "Building"})
	obs.set_focus(true)
	ok("huge_objects_get_no_rim", bm.material_overlay == null)
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
