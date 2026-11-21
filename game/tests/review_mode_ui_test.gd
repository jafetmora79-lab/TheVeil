extends SceneTree
## Review mode with a real window: the click flow (screenshot taken, note box opens, the note is saved with its screenshot, a marker appears).
##   godot --path . --resolution 1280x720 --script res://game/tests/review_mode_ui_test.gd -- out=<png of the note box>
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c: fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)"); quit(1))
func _run() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	var game = root.get_node("Game")
	game.new_game()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 90: await process_frame
	var rv = w.get_node("ReviewMode")
	rv.notes_path = "user://veil_notes_UITEST.json"
	rv.shot_dir = "user://review_UITEST"
	rv.notes = []
	w.player.global_position = Vector3(0, 0.3, 0)
	rv._set_active(true)
	await rv._start_note()
	ok("note_box_open", rv._dialog_open and rv._panel.visible)
	ok("screenshot_taken", rv._pending.has("_image"))
	rv._text.text = "The wall by the door has a gap."
	rv._pick_type("asset")
	for i in 4: await process_frame
	if out != "":
		root.get_viewport().get_texture().get_image().save_png(out)
	rv._save_pending()
	await process_frame
	ok("note_saved", rv.notes.size() == 1 and rv.notes[0]["type"] == "asset" and rv.notes[0].get("screenshot", "") != "")
	ok("screenshot_file", FileAccess.file_exists("user://review_UITEST/" + String(rv.notes[0].get("screenshot", "x"))))
	ok("box_closed", not rv._dialog_open and not rv._panel.visible)
	ok("marker_shown", rv._markers.get_child_count() >= 1)
	ok("game_not_left_paused", not paused)
	ok("controls_back", w.player.controls_enabled or not w.hud.allow_pause)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://veil_notes_UITEST.json"))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
