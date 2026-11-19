extends SceneTree
## THE VEIL - the five Meshy NPCs (headless, Godot 4.3): 51 bones, the clips, height and facing, planted feet do not slide, elbows and wrists
## bend the right way in every clip, and the head, hair and jaw move as one piece with the Head bone.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/npc_meshy_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for slug in VeilNpcMeshy.SLUGS:
		await _one(slug)
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)


func _one(slug: String) -> void:
	var n := VeilNpcMeshy.instantiate(slug)
	if n == null:
		ok(slug + "_loads", false)
		return
	root.add_child(n)
	await process_frame
	var sk := VeilSarahMeshyProto.skeleton(n)
	var ap := VeilSarahMeshyProto.anim_player(n)
	ok(slug + "_51_bones", sk != null and sk.get_bone_count() == 51)
	var clips_ok := true
	for a in ["idle", "walk", "head_turn", "nervous_idle", "injured_idle", "scared_reaction"]:
		clips_ok = clips_ok and ap.has_animation(a)
	ok(slug + "_clips", clips_ok)
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var box: AABB = mi.global_transform * mi.get_aabb()
	ok(slug + "_height", absf(box.size.y - float(VeilNpcMeshy.HEIGHTS[slug])) < 0.04, "%.2f m" % box.size.y)
	var head_i := sk.find_bone("Head")
	var head_pos: Vector3 = sk.get_bone_global_rest(head_i).origin
	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var front_z := 0.0
	for v in vs:
		if v.y > head_pos.y + 0.03:
			front_z = minf(front_z, v.z - head_pos.z)
	ok(slug + "_faces_minus_z", front_z < -0.04, "%.2f" % front_z)
	# planted feet do not slide
	var v0 := VeilNpcMeshy.walk_speed(slug)
	var dt := 1.0 / 24.0
	var worst := 0.0
	var planted := 0
	for foot in ["LeftFoot", "RightFoot"]:
		var bi := sk.find_bone(foot)
		var samples := []
		var h_min := 99.0
		for i in range(0, 37):
			ap.play("walk")
			ap.seek(i * dt, true)
			ap.pause()
			sk.force_update_all_bone_transforms()
			var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(bi).origin
			samples.append(p)
			h_min = minf(h_min, p.y)
		for i in range(1, samples.size()):
			var a: Vector3 = samples[i - 1]
			var b: Vector3 = samples[i]
			if a.y < h_min + 0.008 and b.y < h_min + 0.008:
				planted += 1
				worst = maxf(worst, absf((b.z - a.z) - v0 * dt))
	ok(slug + "_feet_planted", planted >= 20, str(planted))
	ok(slug + "_no_slide_under_5mm", worst < 0.005, "%.1f mm" % (worst * 1000.0))
	# elbows and wrists
	var ang_fwd := func(v: Vector3) -> float:
		return rad_to_deg(atan2(-v.z, -v.y))
	var worst_elbow := 99.0
	var worst_wrist := 0.0
	for clip in ["idle", "walk", "nervous_idle", "injured_idle", "scared_reaction", "head_turn"]:
		var len_ := ap.get_animation(clip).length
		for k in 13:
			ap.play(clip)
			ap.seek(len_ * k / 12.0, true)
			ap.pause()
			sk.force_update_all_bone_transforms()
			for side in ["Left", "Right"]:
				var o := func(bn: String) -> Vector3:
					return sk.get_bone_global_pose(sk.find_bone(side + bn)).origin
				var shoulder: Vector3 = o.call("UpperArm")
				var elbow: Vector3 = o.call("LowerArm")
				var wrist: Vector3 = o.call("Hand")
				var palm: Vector3 = o.call("MiddleProximal")
				worst_elbow = minf(worst_elbow, (ang_fwd.call(wrist - elbow) as float) - (ang_fwd.call(elbow - shoulder) as float))
				worst_wrist = maxf(worst_wrist, absf((ang_fwd.call(palm - wrist) as float) - (ang_fwd.call(wrist - elbow) as float)))
	ok(slug + "_elbows_forward", worst_elbow > -8.0, "%.1f deg" % worst_elbow)
	ok(slug + "_wrists_natural", worst_wrist < 42.0, "%.1f deg" % worst_wrist)
	# the head is fully on the Head bone
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = mi.skin
	var head_in_skin := -1
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == "Head" or skin.get_bind_bone(i) == head_i:
			head_in_skin = i
	var top_n := 0
	var top_ok := 0
	for vi in vs.size():
		if vs[vi].y > head_pos.y + 0.02:
			top_n += 1
			var w := 0.0
			for k in 4:
				if bones[vi * 4 + k] == head_in_skin:
					w += weights[vi * 4 + k]
			if w > 0.99:
				top_ok += 1
	ok(slug + "_head_on_head_bone", top_n > 200 and top_ok == top_n, "%d of %d" % [top_ok, top_n])
	n.queue_free()
	await process_frame
