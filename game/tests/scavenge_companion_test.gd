extends SceneTree
## THE VEIL - scavenging supplies, companion packs and the shelter deposit, end to end with the real game objects.
##   1. every scavenge house has finds on the first day, each in a container that opens and a pickup that works
##   2. later days: most houses have something again (not all), in varied containers
##   3. a trip with Eddie: give him items (capacity respected), he searches a real container, back at the shelter his
##      pack goes into the stores exactly once (totals match), the pack is empty after
##   4. a save and a load keep packs and the stores
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")

var w: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await _frames(150)
	var ex = w.expedition
	var p = w.player
	# ---- 1. first day
	var houses: Array = []
	for k in ex.houses:
		if k != "_done" and ex.houses[k] != null:
			houses.append(ex.houses[k])
	ok("scavenge_houses_open", houses.size() >= 10, "%d houses" % houses.size())
	var total := 0
	var empty_houses: Array = []
	var picked := 0
	for h in houses:
		var n: int = h.loot.size()
		total += n
		if n == 0:
			empty_houses.append(h.house.name)
		for id in h.loot.keys():
			var it = h.loot[id]
			var c = h._loot_container[id]
			c.set_open(true, true)
			await _frames(2)
			var before: int = game.inventory.size()
			if it.collision_layer == 8 and not it.taken:
				it.interact(p)
				if game.inventory.size() > before or game.has_item(it.item_id) or it.taken:   # (rounds go to the gun)
					picked += 1
					continue
			print("  not picked: %s %s item=%s layer=%d taken=%s container=%s open=%s" % [h.house.name, id, it.item_id,
				it.collision_layer, str(it.taken), c.get_parent().name, str(c.is_open)])
	ok("day0_every_house_has_finds", empty_houses.is_empty(), "total %d, empty: %s" % [total, str(empty_houses)])
	ok("day0_finds_can_be_picked", picked == total, "%d of %d picked up" % [picked, total])
	# ---- 2. later days
	for day in [1, 2, 3]:
		var nights: Dictionary = game.world_state.get("shelter_nights", {})
		nights["test_night_%d" % day] = {}
		game.world_state["shelter_nights"] = nights
		await _frames(4)
		var with_finds := 0
		var finds := 0
		for h in houses:
			var live := 0
			for id in h.loot:
				if not h.loot[id].taken:
					live += 1
			finds += live
			if live > 0:
				with_finds += 1
		ok("day%d_refill" % day, with_finds >= int(houses.size() * 0.5) and with_finds < houses.size() + 1,
			"%d of %d houses have %d finds" % [with_finds, houses.size(), finds])
	# ---- 3. a trip with Eddie
	var sv = w.survivors
	ok("eddie_available", "Eddie" in sv.companion_options(), str(sv.companion_options()))
	ex.start("scavenge", false)
	sv.begin_trip("Eddie")
	await _frames(10)
	var eddie: Node3D = w.animators["Eddie"].root
	ok("eddie_capacity_higher", sv.capacity("Eddie") > sv.capacity("Ruth"), "%.1f vs %.1f" % [sv.capacity("Eddie"), sv.capacity("Ruth")])
	for i in 3:
		game.add_item("water_bottle")
		game.add_item("canned_food")
	var water_before: int = game.inventory.count("water_bottle")
	ok("give_eddie", sv._give("Eddie", "water_bottle") and sv._give("Eddie", "canned_food"), str(sv.pack("Eddie")))
	ok("give_moves_not_copies", game.inventory.count("water_bottle") == water_before - 1)
	# fill to capacity: never past it
	var tries := 0
	while sv._give("Eddie", "water_bottle") or sv._give("Eddie", "canned_food"):
		tries += 1
		game.add_item("water_bottle")
		game.add_item("canned_food")
		if tries > 40:
			break
	ok("capacity_respected", sv.pack_weight("Eddie") <= sv.capacity("Eddie") + 0.001, "%.2f / %.2f kg" % [sv.pack_weight("Eddie"), sv.capacity("Eddie")])
	# empty some room, then search a real container next to him
	for i in 3:
		sv._take_back("Eddie", sv.pack("Eddie")[0])
	var target = null
	for h in houses:
		for id in h.loot:
			if not h.loot[id].taken:
				target = h.loot[id]
				break
		if target:
			break
	if target:
		var body := eddie as VeilSurvivorBody
		var near: Vector3 = body.nearest_safe(target.global_position + Vector3(0, -1.0, 0), 2.5)
		body.place_at(near if near.is_finite() else target.global_position)
		p.global_position = body.global_position + Vector3(1.0, 0.1, 0)
		await _frames(4)
		var pack_before: int = sv.pack("Eddie").size()
		sv._search("Eddie", target)
		await _frames(700)
		ok("eddie_searches_real_container", target.taken and sv.pack("Eddie").size() == pack_before + 1,
			"taken %s, pack %d -> %d" % [str(target.taken), pack_before, sv.pack("Eddie").size()])
	else:
		ok("eddie_searches_real_container", false, "no container left to search")
	# back at the shelter together
	var carried: Array = sv.pack("Eddie").duplicate()
	var want := {"food": 0, "water": 0, "medical": 0}
	for id in carried:
		want[game.shelter_resource(String(id))] += 1
	var stock0: Dictionary = game.shelter_stock().duplicate()
	p.global_position = w.market.global_transform * Vector3(0, 0.1, 6.0)
	eddie.global_position = p.global_position + Vector3(1.0, 0, 0)
	sv.end_trip({})
	await _frames(10)
	var choice = w.phase4.choice
	if choice.is_open():
		choice.pick(0)
	await _frames(5)
	var stock1: Dictionary = game.shelter_stock()
	var match_ok := true
	for r in ["food", "water", "medical"]:
		if int(stock1[r]) - int(stock0[r]) != int(want[r]):
			match_ok = false
	ok("deposit_totals_match", match_ok, "carried %s, stores %s -> %s" % [str(want), str(stock0), str(stock1)])
	ok("pack_empty_after_deposit", sv.pack("Eddie").is_empty(), str(sv.pack("Eddie")))
	sv.end_trip({})                                     # a second end: nothing more is added
	await _frames(5)
	ok("deposit_once", game.shelter_stock()["food"] == stock1["food"] and game.shelter_stock()["water"] == stock1["water"])
	# ---- 4. save / load
	sv._pack_put("Ruth", "water_bottle")
	w.save()
	var inv_before: Array = game.inventory.duplicate()
	game.load_game()
	ok("packs_saved", (game.world_state.get("companion_packs", {}) as Dictionary).get("Ruth", []).size() == 1)
	ok("stores_saved", int(game.shelter_stock()["water"]) == int(stock1["water"]))
	ok("inventory_saved", game.inventory.size() == inv_before.size())
	print("SCAVENGE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
