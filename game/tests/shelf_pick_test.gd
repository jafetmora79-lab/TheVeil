extends SceneTree
## Review note #8: any product on the supermarket shelves can be taken (the pooled picker follows the crosshair), mapped to the game's item ids; the three errands accept any snack, candy and drink.
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
	for i in 90: await process_frame
	var mm = w.market_merch
	ok("models_swapped", mm.meshes["can_soup"].get_surface_count() >= 2 and mm.meshes["bottle_cola"].get_surface_count() >= 2)
	# model sizes match the pack's own (so the shelf layout still fits)
	var dims = JSON.parse_string(FileAccess.get_file_as_string("res://game/prototypes/food/dims.json"))
	var bad := []
	for v in dims:
		var a: AABB = mm.meshes[v].get_aabb()
		var d: Array = dims[v]
		if absf(a.size.x - d[0]) > 0.03 or absf(a.size.y - d[1]) > 0.03 or absf(a.size.z - d[2]) > 0.03:
			bad.append("%s %s vs %s" % [v, a.size, d])
	ok("model_sizes_match", bad.is_empty(), str(bad.slice(0, 5)))
	ok("item_map", mm.item_of("bag_chips_a") == "energy_snack" and mm.item_of("choc_b") == "chocolate_bar" and mm.item_of("bottle_cola") == "cola_bottle" and mm.item_of("box_pasta_a") == "canned_food")
	# aim at one chips bag and take it
	var ps: PackedVector3Array = mm._pos["bag_chips_a"]
	var target: Vector3 = mm.to_global(ps[0] + Vector3(0, 0.14, 0))
	var out: Vector3 = (w.market.global_transform.basis * Vector3(0, 0, 1)).normalized()
	var eye := target + out * 1.0
	var hit: Dictionary = mm.find_product(eye, (target - eye).normalized())
	ok("find_product", hit.get("variant", "") == "bag_chips_a" and hit.get("i", -1) == 0, str(hit))
	var n0: int = game.inventory.count("energy_snack")
	var got: String = mm.take_product("bag_chips_a", 0)
	ok("take_gives_item", got == "energy_snack" and game.inventory.count("energy_snack") == n0 + 1)
	ok("taken_not_offered_again", mm.find_product(eye, (target - eye).normalized()).get("i", -1) != 0 or mm.find_product(eye, (target - eye).normalized()).get("variant", "") != "bag_chips_a")
	ok("take_twice_refused", mm.take_product("bag_chips_a", 0) == "")
	ok("saved", "bag_chips_a:0" in game.world_state.get("merch/supermarket/_free", []))
	var unp: Array = w.unpaid("market")
	ok("unpaid_noted", "energy_snack" in unp, str(unp))
	# errands: any snack + any candy + any drink
	for i in ["energy_snack", "chocolate_bar", "water_bottle", "cola_bottle", "canned_food"]:
		while game.has_item(i):
			game.remove_item(i)
	game.add_item("energy_snack")
	game.add_item("chocolate_bar")
	ok("list_needs_drink", not w._have_grocery("drink"))
	game.add_item("cola_bottle")
	ok("cola_counts_as_drink", w._have_grocery("snack") and w._have_grocery("candy") and w._have_grocery("drink"))
	# the raid does not bring a taken product back
	mm.loot()
	ok("raid_skips_taken", mm._gone.has("bag_chips_a:0"))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
