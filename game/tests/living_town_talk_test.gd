extends SceneTree
## The ambient townspeople: three different lines each (before the Veil), and the woman who paced the car park shops inside the supermarket.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/living_town_talk_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	var dlg := root.get_node("Dialogue")
	game.new_game()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 30:
		await process_frame
	var lt = w.living
	for nm in ["Frank", "Joan", "Officer", "Civilian_A", "Civilian_B", "Res_Walker", "Res_Neighbour", "Res_Driveway"]:
		if not nm.begins_with("Res_"):                      # (the neighbours are placed on the real ground and may come a moment later)
			ok("person_" + nm, lt.people.has(nm))
		var texts := {}
		for k in 3:
			var id := "lt_talk_%s_pre_%d" % [nm.to_lower(), k + 1]
			ok("line_" + id, dlg.data.has(id))
			if dlg.data.has(id):
				texts[String(dlg.data[id]["lines"][0]["text"])] = true
		ok("three_different_" + nm, texts.size() == 3)
	# every line of every person is different from every other person's
	var all := {}
	var n := 0
	for id in dlg.data:
		if String(id).begins_with("lt_talk_") and (String(id).ends_with("_1") or String(id).ends_with("_2") or String(id).ends_with("_3")):
			all[String(dlg.data[id]["lines"][0]["text"])] = true
			n += 1
	ok("all_unique", all.size() == n, "%d of %d" % [all.size(), n])
	# the shopper is inside the supermarket
	var b: Node3D = lt.people["Civilian_B"]["body"]
	var local: Vector3 = w.market.to_local(b.global_position)
	ok("shopper_in_market", local.x > -6.0 and local.x < 4.0 and local.z > 6.5 and local.z < 13.5 and absf(local.y - 0.04) < 0.3, str(local))
	ok("shopper_has_route", (lt.people["Civilian_B"]["route"] as Array).size() >= 3)
	# she walks the aisles for a while and never leaves the shop
	w.player.global_position = w.market.to_global(Vector3(-4.0, 1.0, 3.0))          # (people only walk while the player is near)
	await process_frame
	var start := b.global_position
	var inside := true
	var far := 0.0
	for i in 2400:
		await process_frame
		var l: Vector3 = w.market.to_local(b.global_position)
		if l.x < -11.0 or l.x > 7.0 or l.z < 3.0 or l.z > 14.0:
			inside = false
		far = maxf(far, b.global_position.distance_to(start))
	ok("shopper_walks_aisles_inside", inside and far > 4.0, "max %.1f m from the start" % far)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
