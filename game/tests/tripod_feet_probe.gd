extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var m = load("res://game/prototypes/monsters_meshy/MON_tripod.glb").instantiate()
	root.add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("Walk_Heavy")
	ap.speed_scale = 1.0
	var feet := [4, 7, 10]
	for s in 33:
		ap.seek(s * 0.25, true)
		var line := "t=%.2f " % (s * 0.25)
		for f in feet:
			var p: Vector3 = sk.get_bone_global_pose(f).origin
			line += " %s(x%.1f y%.2f z%.1f)" % [sk.get_bone_name(f).substr(4, 1), p.x, p.y, p.z]
		print("F ", line)
	quit()
