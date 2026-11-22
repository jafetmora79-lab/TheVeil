extends SceneTree
## Review notes #94/#95/#96: the backpack has an OPEN action in the inventory that shows Noah's note and sets ch7_note_read (no timer: the tree is paused while the panel is open).
var fails := 0


func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()
	create_timer(60.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game = root.get_node("Game")
	game.no_save = true
	game.add_item("noahs_backpack")
	game.add_item("noahs_note")
	var p = load("res://game/ui/inventory_panel.gd").new()
	root.add_child(p)
	p.open()
	for i in 5: await process_frame
	var acts: Array = p.actions_for("noahs_backpack")
	ok("open_action", acts.size() == 1 and String(acts[0][0]).begins_with("OPEN"), str(acts.map(func(a): return a[0])))
	acts[0][1].call()
	ok("note_read_flag", game.has_flag("ch7_note_read"))
	ok("note_selected", p._ids[p._sel] == "noahs_note")
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
