extends SceneTree
## The health and stamina bars are on whenever the Veil has come, however the game was entered (Continue / chapter skip / a dev set-up).
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
	game.flags["p3_stepped_out"] = true                   # a chapter set-up / a Continue into the Veil: the encounter that used to switch the bars on never ran
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 120: await physics_frame
	ok("survival_on", w.player.survival_active)
	ok("bars_visible", w.hud.surv.visible and w.hud.surv.modulate.a > 0.9, "%s %.2f" % [w.hud.surv.visible, w.hud.surv.modulate.a])
	# hidden by the inventory, back when it closes
	w.hud.inv_panel.open()
	for i in 60: await physics_frame
	w.hud.inv_panel.close()
	for i in 120: await physics_frame
	ok("bars_back_after_inventory", w.hud.surv.visible and w.hud.surv.modulate.a > 0.9)
	# before the Veil: no bars
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
