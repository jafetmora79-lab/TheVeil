extends SceneTree
var failures := 0
func check(label: String, passed: bool) -> void:
	print("TEST ", label, " ", "PASS" if passed else "FAIL")
	if not passed: failures += 1
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var g := root.get_node("Game")
	g.new_game("  Jafet  ")
	check("name_trimmed", g.player_name == "Jafet")
	check("controls_removed", g.clean_player_name("Ja\nfet\t") == "Jafet")
	check("name_limited", g.clean_player_name("a".repeat(50)).length() == 24)
	check("blank_fallback", g.clean_player_name("   ") == "YOU")
	check("unicode_name", g.clean_player_name("José") == "José")
	g.flags["washed_face"] = true
	g.inventory = [{"id": "car_keys", "qty": 1}]
	check("save_success", g.save_game())
	g.new_game()
	check("load_success", g.load_game())
	check("identity_restored", g.player_name == "Jafet")
	check("story_preserved", g.has_flag("washed_face"))
	var f := FileAccess.open(g.SAVE_PATH, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d.erase("player_name")
	f = FileAccess.open(g.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check("legacy_load", g.load_game() and g.player_name == "YOU" and g.has_flag("washed_face"))
	g.new_game("Finn")
	g.save_game(g.checkpoint_path("name_test"))
	g.player_name = "Other"
	check("checkpoint_identity", g.load_checkpoint("name_test") and g.player_name == "Finn")
	var menu = load("res://game/scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	menu._new_game()
	check("name_prompt_visible", menu.name_dialog.visible and menu.name_input.max_length == 24)
	menu.name_dialog.hide()
	check("cancel_keeps_game", g.player_name == "Finn")
	var hud = load("res://game/ui/hud.gd").new()
	root.add_child(hud)
	root.get_node("Dialogue").line_started.emit("", "Test", 1.0)
	check("subtitle_uses_name", hud.speaker_l.text == "FINN")
	root.get_node("Dialogue").line_started.emit("Eddie", "Test", 1.0)
	check("npc_names_unchanged", hud.speaker_l.text == "EDDIE")
	hud.free()
	menu.name_input.text = "Jafet"
	menu.name_dialog.confirmed.emit()
	for i in 6: await process_frame
	check("confirmed_name_starts_world", current_scene != null and current_scene.scene_file_path == "res://game/scenes/World.tscn" and g.player_name == "Jafet")
	check("new_game_resets_story_only", not g.has_flag("washed_face"))
	menu.free()
	print("RESULT ", failures, " failures")
	quit(1 if failures else 0)
