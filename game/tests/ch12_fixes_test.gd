extends SceneTree
## THE VEIL - Chapter 12 "The Farm Road" from the chapter list: after the morning talk the group sets off from
## where they stand (no jump to a spot behind the player, nobody inside anybody); the campsite note, read in the
## inventory (which pauses the game), counts as read and the chapter moves on. The player's save is restored.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/ch12_fixes_test.gd

const CS := preload("res://game/chapters/chapter_select.gd")
var fails := 0
var game: Node
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(600.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	var bak = FileAccess.get_file_as_string(game.SAVE_PATH) if FileAccess.file_exists(game.SAVE_PATH) else null
	CS.prepare(game, 12)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(360)
	var c11 = w.find_child("Chapter11", true, false)
	if c11 == null:
		for n in w.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("chapter11.gd"):
				c11 = n
	ok("chapter12_running", c11 != null and game.has_flag("ch11_started"))
	if c11 == null:
		_end(bak)
		return
	# ---- the morning talk, then everyone sets off
	var names: Array = c11.group()
	await c11._talk(null)
	await frames(2)
	ok("talk_done", game.has_flag("ch11_talk_done"))
	var far: Array = []
	for k in names:
		var d: float = (c11._node(k) as Node3D).global_position.distance_to(w.player.global_position)
		if d > 4.5:
			far.append("%s %.1f m" % [k, d])
	ok("group_set_off_with_player", far.is_empty(), str(far))
	ok("nobody_inside_anybody_at_start", _overlaps(c11, names).is_empty(), str(_overlaps(c11, names)))
	await frames(120)
	ok("nobody_inside_anybody", _overlaps(c11, names).is_empty(), str(_overlaps(c11, names)))
	# ---- the campsite note: picked up, read in the (pausing) inventory
	game.add_item("campsite_note")
	c11._got_note()
	var inv = w.hud.inv_panel
	inv.open()
	await frames(2)
	var idx: int = (inv.get("_ids") as Array).find("campsite_note")
	inv.select(idx)
	ok("inventory_pauses_game", paused)
	for i in 150:                                  # 2.5 s with the note on screen (the game is paused meanwhile)
		await process_frame
	inv.close()
	await frames(30)
	ok("note_counts_as_read", game.has_flag("ch11_note_read"), "seen %.2f s" % inv.seen_for("campsite_note"))
	var moved_on := false
	for i in 900:
		await process_frame
		if not w.hud.hint.text.contains("read the note") and game.current_step().get("flag", "") != "ch11_note_read":
			moved_on = true
			break
	ok("chapter_moves_on", moved_on, "step '%s' hint '%s'" % [game.current_step().get("text", ""), w.hud.hint.text])
	_end(bak)


func _overlaps(c11, names: Array) -> Array:
	var close: Array = []
	var pts: Array = names.map(func(k): return (c11._node(k) as Node3D).global_position)
	pts.append(w.player.global_position)
	var labels: Array = names.duplicate()
	labels.append("player")
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var d := Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length()
			if d < 0.5:
				close.append("%s/%s %.2f" % [labels[i], labels[j], d])
	return close


func _end(bak) -> void:
	if bak != null:
		var f := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
		f.store_string(bak)
		f.close()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
