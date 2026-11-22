extends SceneTree
## The hurt-on-the-floor pose (NpcAnimator.set_downed): the model lies down (side / back) and gets up again.
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _head_h(a) -> float:
	var i: int = a.skel.find_bone("mixamorig_Head")
	if i < 0:
		return 9.0
	return (a.skel.global_transform * a.skel.get_bone_global_pose(i)).origin.y - a.root.global_position.y


func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var a = w.animators.get("Eddie")
	ok("animator", a != null)
	if a == null:
		quit(1)
		return
	for i in 10: await process_frame
	var up: Vector3 = a.skel.global_transform.basis.y
	a.set_downed("side")
	for i in 90: await process_frame
	var side_head: float = _head_h(a)
	ok("side_lies", side_head < 0.6, str(side_head))
	var low := INF
	for i in a.skel.get_bone_count():
		low = minf(low, (a.skel.global_transform * a.skel.get_bone_global_pose(i)).origin.y)
	var rel: float = low - a.root.global_position.y
	ok("side_on_floor", rel > 0.0 and rel < 0.2, str(rel))
	ok("side_clip_playing", a._ap != null and a._ap.current_animation == "SideLying_Reach_Help", str(a._ap.current_animation if a._ap else "no player"))
	a.set_downed("back")
	for i in 90: await process_frame
	var back_head: float = _head_h(a)
	ok("back_lies", back_head < 0.6, str(back_head))
	a.set_downed("")
	for i in 120: await process_frame
	var again: Vector3 = a.skel.global_transform.basis.y
	ok("gets_up", again.y > 0.95 and up.y > 0.95, str(again))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
