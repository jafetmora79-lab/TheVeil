extends SceneTree
## Losing the window focus pauses the game in free play, and leaves scenes that hold the player running.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await process_frame
	var hud = w.hud
	var ok := 0
	var fails := 0
	# the opening cinematic forbids pausing: a focus loss does not pause it
	hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var intro_ok: bool = not hud.is_paused() and not paused
	print("TEST focus_loss_keeps_opening_running ", "PASS" if intro_ok else "FAIL")
	if not intro_ok: fails += 1
	# held by a scene: no pause
	w.player.controls_enabled = false
	hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var held_ok: bool = not hud.is_paused() and not paused
	print("TEST focus_loss_keeps_scenes_running ", "PASS" if held_ok else "FAIL")
	if not held_ok: fails += 1
	# free play: pause
	w.set("_cine", null)
	w.conversing = false
	hud.allow_pause = true              # (the opening cinematic that a new game starts with forbids pausing)
	w.player.controls_enabled = true
	hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var free_ok: bool = hud.is_paused() and paused
	print("TEST focus_loss_pauses_free_play ", "PASS" if free_ok else "FAIL")
	if not free_ok: fails += 1
	hud.set_paused(false)
	print("TEST resume ", "PASS" if not paused else "FAIL")
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
