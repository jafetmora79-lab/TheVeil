extends SceneTree
## THE VEIL - Meshy Sarah prototype, second pass (headless, Godot 4.3 Compatibility):
## the planted-foot walk does not slide, the new clips exist and move the right bones, the face decals toggle without touching the
## skeleton, and body animation + blinking + talking + expressions all run together.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/sarah_meshy_face_anim_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := VeilSarahMeshyProto.instantiate()
	root.add_child(n)
	await process_frame
	var sk := VeilSarahMeshyProto.skeleton(n)
	var ap := VeilSarahMeshyProto.anim_player(n)
	var face := VeilSarahMeshyProto.face(n)
	var names := ap.get_animation_list()
	for a in ["idle", "walk", "head_turn", "nervous_idle", "injured_idle", "scared_reaction"]:
		ok("clip_" + a, a in names)
	ok("nervous_and_injured_idles_loop", ap.get_animation("nervous_idle").loop_mode != Animation.LOOP_NONE and ap.get_animation("injured_idle").loop_mode != Animation.LOOP_NONE)
	ok("scared_reaction_one_shot", ap.get_animation("scared_reaction").loop_mode == Animation.LOOP_NONE)
	ok("scared_reaction_is_quick", ap.get_animation("scared_reaction").length < 2.0, "%.2f s" % ap.get_animation("scared_reaction").length)

	# ---- the walk does not slide: planted ankles move backwards at exactly walk_speed()
	var v := VeilSarahMeshyProto.walk_speed()
	ok("walk_speed_sidecar", v > 0.3 and v < 1.5, "%.3f m/s" % v)
	var anim := ap.get_animation("walk")
	var dt := 1.0 / 24.0
	var worst := 0.0
	var planted := 0
	for foot in ["LeftFoot", "RightFoot"]:
		var bi := sk.find_bone(foot)
		var prev := Vector3.ZERO
		var have := false
		var h_min := 99.0
		var samples := []
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
			if a.y < h_min + 0.008 and b.y < h_min + 0.008:                   # both samples with the foot on the ground
				planted += 1
				# the body moves forward (-Z) at v, so a planted foot must move +Z by v*dt relative to the body
				worst = maxf(worst, absf((b.z - a.z) - v * dt))
	ok("feet_are_planted_for_a_good_part_of_the_cycle", planted >= 20, str(planted))
	ok("planted_foot_slide_under_5mm_per_frame", worst < 0.005, "worst %.4f m/frame (%.1f mm)" % [worst, worst * 1000.0])

	# ---- the new clips move the right bones the right way
	var spine := sk.find_bone("Spine")
	ap.play("injured_idle")
	ap.seek(1.0, true)
	ap.pause()
	sk.force_update_all_bone_transforms()
	var lean := sk.get_bone_pose_rotation(spine).get_euler().x
	ok("injured_idle_hunches_forward", absf(lean) > 0.12, "%.2f rad" % lean)
	var chest_pos: Vector3 = sk.get_bone_global_pose(sk.find_bone("Chest")).origin
	var lhand: Vector3 = sk.get_bone_global_pose(sk.find_bone("LeftHand")).origin
	ok("injured_left_hand_is_up_near_the_ribs", lhand.y > 1.0 and lhand.y < 1.3 and absf(lhand.x) < 0.33, "%s" % str(lhand))
	var head := sk.find_bone("Head")
	ap.play("nervous_idle")
	ap.seek(1.2, true)
	ap.pause()
	var glance1 := sk.get_bone_pose_rotation(head).get_euler().y
	ap.seek(3.2, true)
	var glance2 := sk.get_bone_pose_rotation(head).get_euler().y
	ok("nervous_idle_glances_both_ways", glance1 * glance2 < 0.0 and absf(glance1) > 0.2 and absf(glance2) > 0.2, "%.2f %.2f" % [glance1, glance2])
	ap.play("scared_reaction")
	ap.seek(0.0, true)
	var hy0 := sk.get_bone_pose_rotation(head).get_euler().y
	var hips := sk.find_bone("Hips")
	var hp0 := sk.get_bone_pose_position(hips)
	ap.seek(0.14, true)
	var hy1 := sk.get_bone_pose_rotation(head).get_euler().y
	var hp1 := sk.get_bone_pose_position(hips)
	ok("scared_head_snaps_quickly", absf(hy1 - hy0) > 0.3, "%.2f -> %.2f" % [hy0, hy1])
	ok("scared_body_recoils_backwards", (hp1 - hp0).length() > 0.04, "%.3f m" % (hp1 - hp0).length())

	# ---- elbows and wrists bend FORWARD in every clip (a regression test: an earlier pass had the arm signs reversed)
	var ang_fwd := func(v: Vector3) -> float:
		return rad_to_deg(atan2(-v.z, -v.y))                       # from straight down, toward the front (-Z in Godot) positive
	var worst_elbow := 99.0
	var worst_wrist := 0.0
	var arm_clips := ["idle", "walk", "nervous_idle", "injured_idle", "scared_reaction", "head_turn"]
	for clip in arm_clips:
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
				var palm: Vector3 = sk.get_bone_global_pose(sk.find_bone(side + "MiddleProximal")).origin
				var e_ := (ang_fwd.call(wrist - elbow) as float) - (ang_fwd.call(elbow - shoulder) as float)
				worst_elbow = minf(worst_elbow, e_)
				var w_ := (ang_fwd.call(palm - wrist) as float) - (ang_fwd.call(wrist - elbow) as float)
				worst_wrist = maxf(worst_wrist, absf(w_))
	ok("elbows_never_bend_backwards_in_any_clip", worst_elbow > -4.0, "most backward %.1f degrees (rest pose is about -2)" % worst_elbow)
	ok("wrists_stay_within_a_natural_range", worst_wrist < 35.0, "%.1f degrees" % worst_wrist)

	# ---- the face decals
	ok("face_controller_with_decals", face != null and face.has_decals())
	var decals := n.find_children("Face_*", "MeshInstance3D", true, false)
	ok("eight_decal_meshes", decals.size() == 8, str(decals.size()))
	var head_pos: Vector3 = sk.global_transform * sk.get_bone_global_rest(head).origin
	var near_face := true
	for d in decals:
		var box: AABB = (d as MeshInstance3D).global_transform * (d as MeshInstance3D).get_aabb()
		near_face = near_face and box.get_center().distance_to(head_pos) < 0.2 and box.get_center().z < head_pos.z + 0.02        # in front of the head (-Z)
		ok("decal_nearest_filter_" + String(d.name), ((d as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D).texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	ok("decals_sit_on_the_front_of_the_face", near_face)
	# every decal faces the front (-Z in Godot): with back-face culling a reversed one would simply never show
	var facing_ok := true
	for d in decals:
		var arr: Array = ((d as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var sum_z := 0.0
		for t3 in range(0, ix.size(), 3):
			var nrm := (vs[ix[t3 + 1]] - vs[ix[t3]]).cross(vs[ix[t3 + 2]] - vs[ix[t3]])
			sum_z += nrm.z
		# (Godot front faces are clockwise: a face looking toward -Z has a normal computed this way pointing toward +Z)
		facing_ok = facing_ok and sum_z > 0.0
		if sum_z <= 0.0:
			print("   reversed decal ", d.name, " ", sum_z)
	ok("decals_face_the_front_not_culled", facing_ok)
	face.auto_blink = false
	face.expression = "neutral"
	var visible_count := func() -> int:
		var c := 0
		for d in decals:
			if (d as MeshInstance3D).visible:
				c += 1
		return c
	ok("neutral_shows_no_decal", visible_count.call() == 0)
	face.blink()
	ok("blink_closes_the_eyes", face.eyes_state == "closed" and visible_count.call() == 1)
	for i in 12:
		await process_frame
	ok("blink_ends", face.eyes_state == "open")
	face.expression = "scared"
	ok("scared_face", face.eyes_state == "wide" and face.mouth_state == "scared" and face.brows_state == "normal" and visible_count.call() == 2)
	face.expression = "angry"
	ok("angry_face", face.eyes_state == "narrow" and face.mouth_state == "angry" and face.brows_state == "angry" and visible_count.call() == 3)
	face.expression = "neutral"
	face.talking = true
	var seen := {}
	for i in 90:
		await process_frame
		seen[face.mouth_state] = true
	ok("talking_cycles_the_mouth", seen.has("small") and seen.has("wide") and seen.has("rest"), str(seen.keys()))
	face.talking = false
	ok("talking_stops", face.mouth_state == "rest")

	# ---- body animation and face together: the skeleton follows the clip, the decals follow the face, neither disturbs the other
	face.auto_blink = true
	face.expression = "scared"
	face.talking = true
	ap.play("walk")
	var rot_a := sk.get_bone_pose_rotation(sk.find_bone("LeftUpperLeg"))
	var states := {}
	var changed := false
	for i in 120:
		await process_frame
		states[face.mouth_state + "/" + face.eyes_state] = true
		var r := sk.get_bone_pose_rotation(sk.find_bone("LeftUpperLeg"))
		if r.angle_to(rot_a) > 0.2:
			changed = true
	ok("walk_runs_while_the_face_talks_and_blinks", changed and states.size() >= 3 and ap.is_playing(), str(states.keys()))
	ok("face_decals_still_in_the_scene_after_body_animation", visible_count.call() >= 1)
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
