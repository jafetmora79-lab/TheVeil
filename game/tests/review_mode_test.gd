extends SceneTree
## Review mode (F2 sticky notes): what is pointed at is described, notes are written with everything Claude needs, and reload from the file.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/review_mode_test.gd
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c: fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)"); quit(1))
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await process_frame
	var rv = w.get_node_or_null("ReviewMode")
	ok("review_node_in_world", rv != null)
	rv.notes_path = "user://veil_notes_TEST.json"
	rv.shot_dir = "user://review_TEST"
	rv.notes = []
	rv.capture_screenshots = false
	# F2 toggles it
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F2
	ev.pressed = true
	rv._input(ev)
	ok("f2_turns_on", rv.active)
	# point straight down at the ground, and up at the sky
	var from: Vector3 = w.player.global_position + Vector3(0, 1.6, 0)
	var t: Dictionary = rv.point_at(from, Vector3(0, -1, 0))
	ok("points_at_something_solid", t.get("kind", "") == "collider" and t.has("hit_position") and t.has("path"), str(t.get("name", "")))
	var t2: Dictionary = rv.point_at(from + Vector3(0, 400, 0), Vector3(0, 1, 0))
	ok("air_is_described", t2.get("kind", "") == "air")
	# a note
	var note: Dictionary = rv.add_note("asset", "  the wall looks wrong  ", {"target": t, "camera": {"position": [1.0, 2.0, 3.0]}, "player": {"position": [0.0, 0.0, 0.0]}})
	ok("note_has_id_type_text", int(note["id"]) == 1 and note["type"] == "asset" and note["text"] == "the wall looks wrong" and note["status"] == "open")
	ok("note_has_chapter_and_objective", note["chapter"]["number"] == game.chapter_number() and note.has("objective") and note["flags"] is Array)
	ok("note_keeps_target", note["target"].has("hit_position"))
	var n2: Dictionary = rv.add_note("bug", "second", {})
	ok("ids_increase", int(n2["id"]) == 2)
	# the file is there and loads back
	ok("file_written", FileAccess.file_exists("user://veil_notes_TEST.json"))
	var back = load("res://game/review/review_mode.gd").new()
	back.notes_path = "user://veil_notes_TEST.json"
	back._load()
	ok("notes_reload_from_file", back.notes.size() == 2 and int(back.notes[1]["id"]) == 2 and back.open_count() == 2)
	back.free()
	rv._input(ev)
	ok("f2_turns_off", not rv.active)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://veil_notes_TEST.json"))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
