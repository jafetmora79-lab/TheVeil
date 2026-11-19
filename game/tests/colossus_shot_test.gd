extends SceneTree
## THE VEIL - the Colossus cinematic's view is kept clear: a townsperson standing right in front of the camera
## (Frank on the shop sidewalk) is moved out of the shot, stays out while it plays, and is back to normal after.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/colossus_shot_test.gd

var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	game.new_game()
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 120:
		await physics_frame
	var lt = w.living
	var cam: Camera3D = w.player.camera
	var fwd := -cam.global_basis.z * Vector3(1, 0, 1)
	fwd = fwd.normalized()
	var frank: Node3D = lt.people["Frank"]["body"]
	frank.global_position = lt._ground(cam.global_position + fwd * 2.5)
	var moved: Array = lt.clear_shot(cam.global_position, [fwd])
	var to := (frank.global_position - cam.global_position) * Vector3(1, 0, 1)
	var out_of_view: bool = not frank.visible or fwd.dot(to.normalized()) < cos(deg_to_rad(55.0))
	ok("frank_moved_out", moved.has("Frank") and out_of_view, "%s, dot %.2f" % [str(moved), fwd.dot(to.normalized())])
	var at := frank.global_position
	for i in 180:
		await physics_frame
	ok("frank_stays_out", frank.global_position.distance_to(at) < 0.3)
	lt.restore_after_shot()
	ok("frank_back_to_routine", String(lt.people["Frank"]["state"]) == "routine" and frank.visible)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
