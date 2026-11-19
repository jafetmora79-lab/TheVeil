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
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
