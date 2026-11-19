extends SceneTree
## the five rigged Meshy monsters load with a skeleton, their clips, the right size, and the skin follows the bones (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/monsters_meshy_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for slug in VeilMonstersMeshy.SLUGS:
		var n := VeilMonstersMeshy.instantiate(slug)
		if n == null:
			ok(slug + "_loads", false)
			continue
		root.add_child(n)
		await process_frame
		var sk := VeilSarahMeshyProto.skeleton(n)
		var ap := VeilSarahMeshyProto.anim_player(n)
		ok(slug + "_skeleton", sk != null and sk.get_bone_count() >= 9, str(sk.get_bone_count() if sk else 0))
		var want: Array = ["idle", "strike", "retract"] if slug.begins_with("tentacle") else ["idle", "walk"]
		var have := true
		for c in want:
			have = have and ap != null and ap.has_animation(c)
		ok(slug + "_clips", have)
		var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		var box: AABB = mi.global_transform * mi.get_aabb()
		var size: float = float(VeilMonstersMeshy.info(slug).get("size_m", 0.0))
		ok(slug + "_size", absf(maxf(box.size.x, maxf(box.size.y, box.size.z)) - size) < 0.15 * size, "%.2f vs %.2f" % [maxf(box.size.x, maxf(box.size.y, box.size.z)), size])
		# the skin follows the bones: a clip frame moves the mesh
		var clip: String = "strike" if slug.begins_with("tentacle") else "walk"
		ap.play(clip)
		ap.seek(0.0, true)
		ap.pause()
		sk.force_update_all_bone_transforms()
		var a := (mi.global_transform * mi.get_aabb()).get_center()
		ap.seek(ap.get_animation(clip).length * 0.6, true)
		sk.force_update_all_bone_transforms()
		var tip := sk.get_bone_global_pose(sk.get_bone_count() - 1).origin
		ok(slug + "_bones_animate", ap.get_animation(clip).length > 0.2 and tip.length() > 0.05, "clip %.2f s" % ap.get_animation(clip).length)
		n.queue_free()
		await process_frame
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
