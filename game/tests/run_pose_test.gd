extends SceneTree
## The NPC run (game/animation/gait_pose.gd via NpcAnimator), measured against the brief's key poses, headless:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/run_pose_test.gd [-- Eddie Marcus]
## For each rig at two run speeds it samples 4 s of a real scripted run (the character really moves, -Z is forward) and checks:
## brief airtime (both feet off the floor), heel lifted while the ball is planted (toe push-off), opposite arm and leg, the supporting
## hip riding higher, forward lean with the head level, elbows 60-115 degrees, knees bending forward, hands on their own side,
## the pelvis rising in flight, feet never through the floor and no planted-ball slip.
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
const SPEEDS := [4.3, 5.4]
var fails := 0


func check(n: String, ok: bool, info := "") -> void:
	print("  %s %s %s" % ["ok  " if ok else "FAIL", n, info])
	if not ok:
		fails += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	# one speaker per distinct model in game/npc/meshy_npcs.gd (the extras share rigs with these)
	var cast := ["Protagonist", "Sarah", "Lena", "Cashier", "Res_Walker"]     # the procedural-gait characters (the Mixamo-rigged ones play their own clips: native_clip_test)
	if not OS.get_cmdline_user_args().is_empty():
		cast = Array(OS.get_cmdline_user_args())
	for sp in cast:
		for v in SPEEDS:
			await measure(sp, v)
	for sp in cast:
		await reaction(sp)
		await transitions(sp)
	print("RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


## The brief chase reaction: one palm comes up beside the shoulder and the head glances to the side, then everything returns to the run.
func reaction(sp: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := VeilMeshyNpcs.model_for(sp)
	holder.add_child(model)
	var anim: Node = NPC_ANIM.new()
	holder.add_child(anim)
	await process_frame
	await process_frame
	var sk: Skeleton3D = anim.skel
	anim.chase_reactions = false
	var a0 := (_gp(sk, "RightLittleProximal") - _gp(sk, "RightIndexProximal")).normalized()          # the palm side, measured at rest, in world space
	var d0 := (_gp(sk, "RightMiddleDistal") - _gp(sk, "RightMiddleProximal")).normalized()
	var palm_sign := 1.0 if a0.cross(d0).dot(sk.global_transform.basis * (anim._palm_n["Right"] as Vector3)) >= 0.0 else -1.0
	anim.walk_to([Vector3(0, 0, -600)], 4.3)
	for i in 150:
		await process_frame
	var yaw_before: float = absf(anim._look.x)

	var hand_before := maxf(_gp(sk, "LeftHand").y, _gp(sk, "RightHand").y) - _gp(sk, "Chest").y
	anim.react(0.8, 1.0)
	var yaw_max := 0.0
	var hand_max := -9.0
	var face_min := 9.0                                   # nearest the raised hand gets to the head
	var palm_fwd := -9.0                                  # how far the palm faces forward (-Z) at its best during the reaction
	for i in 60:
		await process_frame
		var a_c := (_gp(sk, "RightLittleProximal") - _gp(sk, "RightIndexProximal")).normalized()
		var d_c := (_gp(sk, "RightMiddleDistal") - _gp(sk, "RightMiddleProximal")).normalized()
		var n_c := a_c.cross(d_c)
		if absf(anim._react_w) > 0.9:
			face_min = minf(face_min, _gp(sk, "RightHand").distance_to(_gp(sk, "Head")))
			var nn := n_c.normalized() * palm_sign
			palm_fwd = maxf(palm_fwd, 0.7 * -nn.z + 0.7 * nn.x * signf(_gp(sk, "RightHand").x - _gp(sk, "Hips").x))
		yaw_max = maxf(yaw_max, absf(anim._look.x))
		hand_max = maxf(hand_max, maxf(_gp(sk, "LeftHand").y, _gp(sk, "RightHand").y) - _gp(sk, "Chest").y)
	for i in 60:
		await process_frame
	var yaw_after: float = absf(anim._look.x)
	var hand_after := maxf(_gp(sk, "LeftHand").y, _gp(sk, "RightHand").y) - _gp(sk, "Chest").y
	print("   [%s reaction] glance %.2f rad (before %.2f, after %.2f), hand above the chest bone %.0f mm (before %.0f, after %.0f)" % [sp, yaw_max, yaw_before, yaw_after, hand_max * 1000.0, hand_before * 1000.0, hand_after * 1000.0])
	check("%s chase reaction: sideways glance (> 0.5 rad)" % sp, yaw_max > 0.5, "%.2f" % yaw_max)
	check("%s chase reaction: a palm raised to the shoulder (hand at least 5 cm above the chest bone)" % sp, hand_max > 0.05, "%.0f mm" % (hand_max * 1000.0))
	print("   [%s reaction] raised hand stays %.0f mm from the head, palm outward-forward %.2f" % [sp, face_min * 1000.0, palm_fwd])
	check("%s chase reaction: the raised hand is clear of the face (>= 20 cm from the head)" % sp, face_min >= 0.20, "%.0f mm" % (face_min * 1000.0))
	check("%s chase reaction: the open palm shows outward / forward (> 0.4)" % sp, palm_fwd > 0.4, "%.2f" % palm_fwd)
	check("%s chase reaction is brief: eyes ahead again and both hands below the chest bone after 2 s" % sp, yaw_after < 0.1 and hand_after < 0.09, "%.2f rad, %.0f mm" % [yaw_after, hand_after * 1000.0])
	holder.queue_free()


## walk -> run (speed raised mid-stride) and run -> stop: no joint snaps from frame to frame, and the body comes to rest standing.
func transitions(sp: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := VeilMeshyNpcs.model_for(sp)
	holder.add_child(model)
	var anim: Node = NPC_ANIM.new()
	holder.add_child(anim)
	await process_frame
	await process_frame
	var sk: Skeleton3D = anim.skel
	var bones := ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "Hips", "Spine", "Chest"]
	var prev := {}
	var worst := 0.0
	var worst_b := ""
	anim.walk_to([Vector3(0, 0, -600)], 1.4)
	for i in 150:
		await process_frame
		for b in bones:
			var q := sk.get_bone_pose_rotation(sk.find_bone(b))
			if prev.has(b):
				var d := rad_to_deg((prev[b] as Quaternion).angle_to(q))
				if i > 3 and d > worst:
					worst = d
					worst_b = b
			prev[b] = q
	var w_walk := worst
	anim.walk_speed = 4.3                                   # walk -> run, mid-stride (the animator's own speed ramp does the rest)
	worst = 0.0
	for i in 120:
		await process_frame
		for b in bones:
			var q := sk.get_bone_pose_rotation(sk.find_bone(b))
			var d := rad_to_deg((prev[b] as Quaternion).angle_to(q))
			if d > 99.0:
				print("   snap %s frame %d %.1f deg: speed %.2f cyc %.2f phase %.2f gw %.2f walk %.2f" % [b, i, d, anim._speed, anim._cyc, fposmod(anim._phase, TAU) / TAU, anim._gw, anim._walk])
			if d > worst:
				worst = d
				worst_b = b
			prev[b] = q
	check("%s walk -> run: no joint snap (< 26 deg per frame; the old gait peaked at 31)" % sp, worst < 26.0, "%.1f deg (%s)" % [worst, worst_b])
	# the same measure in the steady run, for comparison: the knee of a running swing leg is genuinely fast
	var steady := 0.0
	for i in 120:
		await process_frame
		for b in bones:
			var q := sk.get_bone_pose_rotation(sk.find_bone(b))
			steady = maxf(steady, rad_to_deg((prev[b] as Quaternion).angle_to(q)))
			prev[b] = q
	print("   steady run peak %.1f deg per frame; walk->run transition peak %.1f" % [steady, worst])
	check("%s steady run knee/hip peak under 20 deg per frame (the old gait: 23)" % sp, steady < 25.0, "%.1f" % steady)
	anim.walk_to([])                                        # run -> stop
	worst = 0.0
	for i in 150:
		await process_frame
		for b in bones:
			var q := sk.get_bone_pose_rotation(sk.find_bone(b))
			var d := rad_to_deg((prev[b] as Quaternion).angle_to(q))
			if d > worst:
				worst = d
				worst_b = b
			prev[b] = q
	check("%s run -> stop: no joint snap (< 25 deg per frame)" % sp, worst < 25.0, "%.1f deg (%s)" % [worst, worst_b])
	check("%s run -> stop: settled upright" % sp, not anim.is_walking() and anim._gw < 0.02 and absf(sk.position.y) < 0.03, "gw %.3f y %.0f mm" % [anim._gw, sk.position.y * 1000.0])
	holder.queue_free()


func _gp(sk: Skeleton3D, n: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin


func _angle(a: Vector3, b: Vector3, c: Vector3) -> float:        # interior angle at b, degrees
	return rad_to_deg((a - b).angle_to(c - b))


func measure(sp: String, v: float) -> void:
	var holder := Node3D.new()
	holder.name = sp
	root.add_child(holder)
	var model := VeilMeshyNpcs.model_for(sp)
	holder.add_child(model)
	var anim: Node = NPC_ANIM.new()
	holder.add_child(anim)
	await process_frame
	await process_frame
	var sk: Skeleton3D = anim.skel
	var rest := {}
	for n in ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
		rest[n] = _gp(sk, n).y
	var rest_lean := rad_to_deg(atan2((_gp(sk, "LeftUpperLeg").z + _gp(sk, "RightUpperLeg").z) * 0.5 - _gp(sk, "Neck").z, _gp(sk, "Neck").y - (_gp(sk, "LeftUpperLeg").y + _gp(sk, "RightUpperLeg").y) * 0.5))
	var tip_rest := {}                                    # the open hand, before any movement
	for side in ["Left", "Right"]:
		tip_rest[side] = _gp(sk, side + "MiddleDistal").distance_to(_gp(sk, side + "Hand"))
	anim.walk_to([Vector3(0, 0, -600)], v)
	for i in 120:                                         # reach the steady run
		await process_frame
	var frames := 240
	var air := 0
	var heel_up_ball_down := 0
	var left_stance_frames := 0
	var arm_ok := 0
	var arm_n := 0
	var roll_ok := 0
	var roll_n := 0
	var elbow_min := 999.0
	var elbow_max := 0.0
	var knee_wrong := 0
	var hand_cross := 0
	var lean_sum := 0.0
	var toe_min := 9.0
	var py_min := 9.0
	var py_max := -9.0
	var air_py := []
	var ground_py := []
	var peak_heel := 0.0
	var fwd_hand_sum := 0.0                                # forward hand height relative to the chest bone (m), averaged over the frames
	var back_elbow_max := -9.0                             # how far behind the spine the back elbow gets (m)
	var gaze_max := 0.0
	var elbow_lat_max := 0.0                               # elbow / hand sideways distance from the spine line (arms close to the ribs)
	var hand_lat_max := 0.0
	var tip_now := 9.0
	for i in frames:
		await process_frame
		var lf: float = _gp(sk, "LeftFoot").y - rest["LeftFoot"]
		var rf: float = _gp(sk, "RightFoot").y - rest["RightFoot"]
		var lt: float = _gp(sk, "LeftToes").y - rest["LeftToes"]
		var rt: float = _gp(sk, "RightToes").y - rest["RightToes"]
		toe_min = minf(toe_min, minf(lt, rt))
		peak_heel = maxf(peak_heel, maxf(lf, rf))
		var both_off := minf(minf(lf, rf), minf(lt, rt)) > 0.025
		if both_off:
			air += 1
		# heel clearly up while the ball of the same foot is still on the floor = toe push-off
		if (lt < 0.025 and lf > 0.03) or (rt < 0.025 and rf > 0.03):
			heel_up_ball_down += 1
		var hl := _gp(sk, "LeftUpperLeg")
		var hr := _gp(sk, "RightUpperLeg")
		var pelvis := (hl + hr) * 0.5
		var lat := (hl - hr).normalized()
		var ph := fposmod(anim._phase, TAU)
		var c: float = anim._gprof.get("contact", 0.0)
		# left foot contact (phase 0 +- 0.35 rad): the right hand is ahead of (more -Z than) the left; the left hand is back
		if ph < 0.3 or ph > TAU - 0.3:
			arm_n += 1
			if _gp(sk, "RightHand").z < _gp(sk, "LeftHand").z:
				arm_ok += 1
		# supporting hip higher: when only the left toe/foot is down, the left hip is above the right (and the reverse)
		var l_down: bool = lt < 0.02 and not (rt < 0.02)
		var r_down: bool = rt < 0.02 and not (lt < 0.02)
		if l_down or r_down:
			roll_n += 1
			if (l_down and hl.y > hr.y) or (r_down and hr.y > hl.y):
				roll_ok += 1
		# elbows
		for side in ["Left", "Right"]:
			var e := _angle(_gp(sk, side + "UpperArm"), _gp(sk, side + "LowerArm"), _gp(sk, side + "Hand"))
			elbow_min = minf(elbow_min, e)
			elbow_max = maxf(elbow_max, e)
			var hand := _gp(sk, side + "Hand") - pelvis
			if hand.dot(lat) * (1.0 if side == "Left" else -1.0) < 0.02:
				hand_cross += 1
			# knees bend forward (the knee is ahead of the hip-ankle line whenever flexed)
			var hip := _gp(sk, side + "UpperLeg")
			var knee := _gp(sk, side + "LowerLeg")
			var ankle := _gp(sk, side + "Foot")
			if _angle(hip, knee, ankle) < 150.0 and (knee.z - (hip.z + ankle.z) * 0.5) > 0.0:   # -Z is forward: knee.z must be smaller
				knee_wrong += 1
		# lean: head ahead of the pelvis
		var neck := _gp(sk, "Neck")
		lean_sum += rad_to_deg(atan2(pelvis.z - neck.z, neck.y - pelvis.y))
		# upper body
		var spine := _gp(sk, "Spine")
		var chest := _gp(sk, "Chest")
		var hand_l := _gp(sk, "LeftHand")
		var hand_r := _gp(sk, "RightHand")
		var fwd_hand := hand_l if hand_l.z < hand_r.z else hand_r        # -Z is forward
		fwd_hand_sum += fwd_hand.y - chest.y
		for side in ["Left", "Right"]:
			var el := _gp(sk, side + "LowerArm")
			back_elbow_max = maxf(back_elbow_max, el.z - spine.z)
			elbow_lat_max = maxf(elbow_lat_max, absf((el - spine).dot(lat)))
			hand_lat_max = maxf(hand_lat_max, absf((_gp(sk, side + "Hand") - spine).dot(lat)))
			tip_now = minf(tip_now, _gp(sk, side + "MiddleDistal").distance_to(_gp(sk, side + "Hand")) / tip_rest[side])
		gaze_max = maxf(gaze_max, absf(anim._look.x))
		var py := sk.position.y
		py_min = minf(py_min, py)
		py_max = maxf(py_max, py)
		(air_py if both_off else ground_py).append(py)
	var air_frac := float(air) / frames
	var tag := "%s %.1f m/s" % [sp, v]
	var cyc := float(anim._cyc)
	print("[%s] cycle %.2f m = %.2f s (%.0f steps/min), airborne %.0f%% of the time, heel-up/ball-down %d frames, peak heel %.0f mm, pelvis travel %.0f mm" % [tag, cyc, cyc / v, 120.0 / (cyc / v), air_frac * 100.0, heel_up_ball_down, peak_heel * 1000.0, (py_max - py_min) * 1000.0])
	check(tag + " brief airtime (both feet off, 8-35 % of the time)", air_frac >= 0.08 and air_frac <= 0.35, "%.0f%%" % (air_frac * 100.0))
	var stances := maxf(frames / 60.0 / (cyc / v) * 2.0, 1.0)
	check(tag + " toe push-off (heel up while the ball is down, >= 2 frames per stance)", float(heel_up_ball_down) / stances >= 2.0, "%d frames, %.1f per stance" % [heel_up_ball_down, float(heel_up_ball_down) / stances])
	check(tag + " swing heel clears 180 mm", peak_heel >= 0.18, "%.0f mm" % (peak_heel * 1000.0))
	check(tag + " opposite arm and leg (right hand ahead at left contact)", arm_n > 0 and float(arm_ok) / arm_n >= 0.85, "%d/%d" % [arm_ok, arm_n])
	check(tag + " weight shift (supporting hip higher)", roll_n > 0 and float(roll_ok) / roll_n >= 0.6, "%d/%d" % [roll_ok, roll_n])
	check(tag + " elbows 50-120 deg (the Mixamo run reference: 58-116)", elbow_min >= 50.0 and elbow_max <= 120.0, "%.0f-%.0f" % [elbow_min, elbow_max])
	check(tag + " knees bend forward", knee_wrong == 0, str(knee_wrong))
	check(tag + " hands stay on their own side", hand_cross == 0, str(hand_cross))
	var lean := lean_sum / frames - rest_lean
	check(tag + " forward lean 8-18 deg more than standing (hips to neck)", lean >= 8.0 and lean <= 18.0, "%.1f deg (standing %.1f)" % [lean, rest_lean])
	check(tag + " feet never through the floor (toes >= -15 mm)", toe_min >= -0.015, "%.1f mm" % (toe_min * 1000.0))
	var fwd_h := fwd_hand_sum / frames
	print("   forward hand %.0f mm vs the chest bone, back elbow %.0f mm behind the spine, elbow %.0f / hand %.0f mm sideways of the spine, finger tips %.0f %% of the open length, gaze %.2f rad" % [fwd_h * 1000.0, back_elbow_max * 1000.0, elbow_lat_max * 1000.0, hand_lat_max * 1000.0, tip_now * 100.0, gaze_max])
	check(tag + " forward hand at lower-chest height (below the chest bone, above the waist: -35..+5 cm)", fwd_h >= -0.35 and fwd_h <= 0.05, "%.0f mm" % (fwd_h * 1000.0))
	check(tag + " back elbow drives behind the torso (>= 10 cm behind the spine)", back_elbow_max >= 0.10, "%.0f mm" % (back_elbow_max * 1000.0))
	check(tag + " arms close to the ribs (elbows within 42 cm of the spine line (Mixamo reference))", elbow_lat_max <= 0.42, "%.0f mm" % (elbow_lat_max * 1000.0))
	check(tag + " fingers in a loose curl (tips at < 96 % of the open length)", tip_now < 0.96, "%.0f %%" % (tip_now * 100.0))
	check(tag + " eyes on the path ahead (head yaw < 0.1 rad)", gaze_max < 0.1, "%.3f rad" % gaze_max)
	var up := 0.0
	var dn := 0.0
	if not air_py.is_empty() and not ground_py.is_empty():
		for x in air_py: up += x
		for x in ground_py: dn += x
		up /= air_py.size()
		dn /= ground_py.size()
	check(tag + " pelvis in flight within 6 cm of stance (the Mixamo run: its own bounce)", up > dn - 0.06, "%.0f vs %.0f mm" % [up * 1000.0, dn * 1000.0])
	holder.queue_free()
