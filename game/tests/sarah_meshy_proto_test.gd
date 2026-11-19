extends SceneTree
## THE VEIL - the Meshy Sarah prototype imports into Godot 4.3 (Compatibility) with a usable skeleton and animations (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/sarah_meshy_proto_test.gd
## Touches nothing in the game: the prototype lives in game/prototypes/sarah_meshy and is loaded only here.
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var n := VeilSarahMeshyProto.instantiate()
	ok("glb_loads", n != null)
	if n == null:
		quit(1)
		return
	root.add_child(n)
	await process_frame
	var sk := VeilSarahMeshyProto.skeleton(n)
	ok("skeleton", sk != null and sk.get_bone_count() == 51, str(sk.get_bone_count() if sk else 0))
	for b in ["Hips", "Spine", "Chest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
			"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]:
		ok("bone_" + b, sk != null and sk.find_bone(b) >= 0)
	for side in ["Left", "Right"]:
		for f in ["Thumb", "Index", "Middle", "Ring", "Little"]:
			for part in (["Metacarpal", "Proximal", "Distal"] if f == "Thumb" else ["Proximal", "Intermediate", "Distal"]):
				ok("finger_%s%s%s" % [side, f, part], sk != null and sk.find_bone(side + f + part) >= 0)
	var mesh: MeshInstance3D = n.find_child("Sarah_Meshy_Body", true, false) as MeshInstance3D
	ok("mesh_skinned", mesh.skin != null and mesh.skeleton != NodePath(""))
	var box := mesh.get_aabb()
	var h := box.size.y * mesh.global_transform.basis.get_scale().y
	ok("height_about_1_66m", absf(box.size.y - 1.659) < 0.02, "%.3f" % box.size.y)
	ok("feet_on_the_ground", absf(box.position.y) < 0.02, "%.3f" % box.position.y)
	# she faces -Z (Godot forward): the toes lie in front (-Z) of the ankle
	var foot := sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin
	var toes := sk.get_bone_global_rest(sk.find_bone("LeftToes")).origin
	ok("faces_minus_z", toes.z < foot.z - 0.02, "foot z %.3f toes z %.3f" % [foot.z, toes.z])
	ok("psx_nearest_filter", (mesh.get_surface_override_material(0) as BaseMaterial3D).texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	var ap := VeilSarahMeshyProto.anim_player(n)
	ok("animation_player", ap != null)
	if ap:
		var names := ap.get_animation_list()
		ok("animations_present", "idle" in names and "walk" in names and "head_turn" in names, str(names))
		ok("hand_pose_animations", "hand_relaxed" in names and "hand_open" in names and "hand_fist" in names and "hand_grip" in names and "hand_point" in names, str(names))
		ok("idle_is_long_and_walk_is_a_stride", absf(ap.get_animation("idle").length - 6.0) < 0.2 and absf(ap.get_animation("walk").length - 1.5) < 0.1,
			"%.2f %.2f" % [ap.get_animation("idle").length, ap.get_animation("walk").length])
		# hand poses really curl the fingers (fist: knuckle ~80 degrees, open: none)
		var ip := sk.find_bone("LeftIndexProximal")
		ap.play("hand_open")
		ap.seek(0.0, true)
		var open_ang := sk.get_bone_pose_rotation(ip).get_angle()
		ap.play("hand_fist")
		ap.seek(0.0, true)
		var fist_ang := sk.get_bone_pose_rotation(ip).get_angle()
		ok("fist_curls_the_index", fist_ang > open_ang + 1.0, "%.2f vs %.2f" % [fist_ang, open_ang])
		var rip := sk.find_bone("RightIndexProximal")
		ok("fist_curls_the_right_hand_too", sk.get_bone_pose_rotation(rip).get_angle() > 1.0)
		for an in ["idle", "walk"]:
			ok(an + "_loops", ap.get_animation(an).loop_mode != Animation.LOOP_NONE)
		ok("head_turn_one_shot", ap.get_animation("head_turn").loop_mode == Animation.LOOP_NONE)
		# the poses really change over time
		var head := sk.find_bone("Head")
		var lleg := sk.find_bone("LeftUpperLeg")
		ap.play("head_turn")
		ap.seek(0.0, true)
		var y0 := sk.get_bone_pose_rotation(head).get_euler().y
		ap.seek(0.8, true)
		var y1 := sk.get_bone_pose_rotation(head).get_euler().y
		ap.seek(2.3, true)
		var y2 := sk.get_bone_pose_rotation(head).get_euler().y
		ok("head_turns_both_ways", y1 * y2 < 0.0 and absf(y1) > 0.3 and absf(y2) > 0.3, "%.2f %.2f %.2f" % [y0, y1, y2])
		ap.play("walk")
		ap.seek(0.075, true)
		var a0 := sk.get_bone_pose_rotation(lleg).get_euler().x
		ap.seek(0.825, true)
		var a1 := sk.get_bone_pose_rotation(lleg).get_euler().x
		ok("walk_swings_the_legs", absf(a0 - a1) > 0.3, "%.2f %.2f" % [a0, a1])
		ap.play("idle")
		ap.seek(0.0, true)
		var c0 := sk.get_bone_pose_rotation(sk.find_bone("Chest"))
		ap.seek(1.0, true)
		var c1 := sk.get_bone_pose_rotation(sk.find_bone("Chest"))
		ok("idle_breathes", c0.angle_to(c1) > 0.005, "%.4f" % c0.angle_to(c1))
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
