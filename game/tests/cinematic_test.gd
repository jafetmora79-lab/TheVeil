extends SceneTree
## Headless smoke checks for both cinematic modes and the preview's menu return.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game/cinematics/Cinematic.tscn") as PackedScene
	if packed == null:
		printerr("CINEMATIC FAIL scene cannot load")
		quit(1)
		return
	var intro := packed.instantiate()
	intro.mode = "intro"
	root.add_child(intro)
	await process_frame
	var intro_ok: bool = intro.tracks.size() == 3 and intro.camera.current and intro.stage.get_node_or_null("Greyhaven_Houses/Houses/PLAYER_HOME") != null
	print("CINEMATIC intro %s" % ("PASS" if intro_ok else "FAIL"))
	intro.free()
	var preview := packed.instantiate()
	preview.mode = "preview"
	root.add_child(preview)
	await process_frame
	var set_ok: bool = preview.tracks.size() == 7 and preview.stage.get_node_or_null("Greyhaven_Commercial/GAME_SHOP") != null
	preview._next_shot()
	preview._next_shot()
	preview._next_shot()
	var creature_ok: bool = is_instance_valid(preview.creature)
	print("CINEMATIC preview %s" % ("PASS" if set_ok and creature_ok else "FAIL"))
	preview.free()
	quit(0 if intro_ok and set_ok and creature_ok else 1)
