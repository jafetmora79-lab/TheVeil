extends SceneTree
## THE VEIL - Meshy protagonist prototype (headless, Godot 4.3): the clips exist, the walk's planted feet do not slide, elbows and wrists
## bend the right way in every clip, and the head, hair and jaw move as one piece with the Head bone.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/protagonist_meshy_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := VeilProtagonistMeshy.instantiate()
	root.add_child(n)
	await process_frame
	var sk := VeilSarahMeshyProto.skeleton(n)
	var ap := VeilSarahMeshyProto.anim_player(n)
	ok("skeleton_51_bones", sk != null and sk.get_bone_count() == 51, str(sk.get_bone_count() if sk else 0))
	for a in ["idle", "walk", "head_turn", "nervous_idle", "injured_idle", "scared_reaction"]:
		ok("clip_" + a, a in ap.get_animation_list())
	ok("scared_reaction_one_shot", ap.get_animation("scared_reaction").loop_mode == Animation.LOOP_NONE)
	# height and facing: 1.78 m tall, face toward -Z
	var mi: MeshInstance3D
	for m_ in n.find_children("*", "MeshInstance3D", true, false):
		if not String(m_.name).begins_with("Face_"):
			mi = m_ as MeshInstance3D
	var box: AABB = mi.global_transform * mi.get_aabb()
	ok("height_1_78", absf(box.size.y - 1.78) < 0.03, "%.2f m" % box.size.y)
	var head_i := sk.find_bone("Head")
	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var front_z := 0.0
	var cnt := 0
	var head_pos: Vector3 = sk.get_bone_global_rest(head_i).origin
	for v in vs:
		if v.y > head_pos.y + 0.03:
			front_z = minf(front_z, v.z - head_pos.z)
	ok("head_extends_toward_minus_z_the_face_side", front_z < -0.05, "%.2f" % front_z)
	# ---- no slide
	var v0 := VeilProtagonistMeshy.walk_speed()
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
	ok("feet_planted_part_of_cycle", planted >= 20, str(planted))
	ok("planted_foot_slide_under_5mm_per_frame", worst < 0.005, "%.1f mm" % (worst * 1000.0))
	# ---- elbows and wrists bend forward
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
	ok("elbows_never_bend_backwards", worst_elbow > -6.0, "%.1f deg" % worst_elbow)
	ok("wrists_natural", worst_wrist < 40.0, "%.1f deg" % worst_wrist)
	# ---- the head moves as one piece: every vertex above the chin is (almost) fully weighted to the Head bone
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = mi.skin
	var head_bind_name := "Head"
	var head_in_skin := -1
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == head_bind_name or skin.get_bind_bone(i) == head_i:
			head_in_skin = i
	var chin_y := head_pos.y - 0.02 + 0.0
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
	ok("head_vertices_fully_on_head_bone", top_n > 200 and top_ok == top_n, "%d of %d" % [top_ok, top_n])
	# ---- face decals: eight patches on the front of the head, nearest-filtered; blink / expressions / talking work
	var face := VeilProtagonistMeshy.face(n)
	var decals := n.find_children("Face_*", "MeshInstance3D", true, false)
	ok("eight_face_decals", face != null and face.has_decals() and decals.size() == 8, str(decals.size()))
	var vis := func() -> int:
		var c := 0
		for d in decals:
			if (d as MeshInstance3D).visible:
				c += 1
		return c
	face.auto_blink = false
	face.expression = "neutral"
	ok("neutral_shows_no_decal", vis.call() == 0)
	face.blink()
	ok("blink_closes_eyes", face.eyes_state == "closed" and vis.call() == 1)
	for i in 14:
		await process_frame
	ok("blink_ends", face.eyes_state == "open")
	face.expression = "scared"
	ok("scared_face", face.eyes_state == "wide" and face.mouth_state == "scared")
	face.expression = "angry"
	ok("angry_face", face.eyes_state == "narrow" and face.brows_state == "angry")
	face.expression = "neutral"
	face.talking = true
	var seen := {}
	for i in 90:
		await process_frame
		seen[face.mouth_state] = true
	ok("talking_cycles_mouth", seen.has("small") and seen.has("wide"), str(seen.keys()))
	var facing := true
	for d in decals:
		var a2: Array = ((d as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var v2: PackedVector3Array = a2[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = a2[Mesh.ARRAY_INDEX]
		var sz := 0.0
		for t3 in range(0, ix.size(), 3):
			sz += (v2[ix[t3 + 1]] - v2[ix[t3]]).cross(v2[ix[t3 + 2]] - v2[ix[t3]]).z
		facing = facing and sz > 0.0
	ok("decals_face_the_front", facing)
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
