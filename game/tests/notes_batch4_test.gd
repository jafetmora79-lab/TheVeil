extends SceneTree
## Review notes #50 (the stock cannot be taken after the Veil; examining it says why) and #58 (the houses that cannot be searched answer the door with the reason).
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
	game.flags["p3_mist"] = true
	game.flags["groceries_done"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 120: await process_frame
	var mm = w.market_merch
	ok("veil_blocked", mm.veil_blocked())
	var g0: Dictionary = mm.groups["water_bottle"]
	var n0: int = game.inventory.size()
	(g0["it"] as Interactable).interact(w.player)
	await process_frame
	ok("nothing_taken_after_veil", game.inventory.size() == n0, str(game.inventory.size()))
	ok("prompt_is_check", String((g0["it"] as Interactable).prompt_text).begins_with("[E] Check"), String((g0["it"] as Interactable).prompt_text))
	var dlg = root.get_node("Dialogue")
	ok("refusal_spoken", dlg.is_active() or dlg.is_busy(), "")
	# the houses
	var doors := 0
	var reasons := {}
	for h in w.get_node("Residential/Houses").get_children():
		var d = h.find_child("INT_Door_Front", true, false)
		if d and d.get_node_or_null("Interact") and d.get_node("Interact").has_meta("why"):
			doors += 1
			reasons[d.get_node("Interact").get_meta("why")] = true
	ok("blocked_house_doors", doors > 20, str(doors))
	ok("reasons_used", reasons.size() >= 2, str(reasons.keys()))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
