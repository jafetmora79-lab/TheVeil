extends SceneTree
## Walk / run gait (game/animation/gait_pose.gd via NpcAnimator): planted-foot slip, floor contact, loop seam, start/stop pops.
## Run: godot --headless --path . --fixed-fps 60 --script res://game/tests/gait_test.gd
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
const Gait := preload("res://game/animation/gait_pose.gd")
const SPEEDS := [1.25, 2.4, 4.3]
var fails := 0

func check(n: String, ok: bool, info := "") -> void:
	print("  %s %s %s" % ["ok  " if ok else "FAIL", n, info])
	if not ok: fails += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cast := ["Protagonist", "Eddie", "Marcus", "Ruth", "Sarah"]
	if not OS.get_cmdline_user_args().is_empty():
		cast = Array(OS.get_cmdline_user_args())
	for sp in cast:
		for v in SPEEDS:
			await measure(sp, v)
	# loop seam: the pose at phase and phase + TAU is identical
	var h := Node3D.new(); root.add_child(h)
	var m := VeilMeshyNpcs.model_for("Eddie"); h.add_child(m)
	var a: Node = NPC_ANIM.new(); h.add_child(a)
	await process_frame
	await process_frame
	var o1 := {}
	var o2 := {}
	var seam := 0.0
	for v in SPEEDS:
		Gait.sample(0.7, v, {}, a._gait_rig, Gait.BONES, a.F, a.U, a.R, o1)
		Gait.sample(0.7 + TAU, v, {}, a._gait_rig, Gait.BONES, a.F, a.U, a.R, o2)
		for k in Gait.BONES:
			seam = maxf(seam, (o1[k] as Quaternion).angle_to(o2[k]))
	check("loop seam", seam < 0.002, str(seam))
	# start / stop: no frame-to-frame joint pop, gait fades out, body returns to rest height
	var sk: Skeleton3D = a.skel
	var bones := ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftUpperArm", "Hips", "Spine"]
	var prev := {}
	var worst := 0.0
	a.walk_to([Vector3(0, 0, -3.0)], 2.4)
	for i in 240:
		await process_frame
		for b in bones:
			var q := sk.get_bone_pose_rotation(sk.find_bone(b))
			if prev.has(b):
				var dd := rad_to_deg((prev[b] as Quaternion).angle_to(q))
				if dd > worst:
					worst = dd
					print("   pop %s frame %d %.1f" % [b, i, dd])
			prev[b] = q
	check("no joint pop at start / arrival (peak deg per frame; includes real knee swing speed)", worst < 20.0, "%.1f" % worst)
	check("arrived and settled", not a.is_walking() and a._gw < 0.01 and absf(sk.position.y) < 0.02, "gw %.3f y %.3f" % [a._gw, sk.position.y])
	print("RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)

func measure(sp: String, v: float) -> void:
	var holder := Node3D.new(); holder.name = sp
	root.add_child(holder)
	var model := VeilMeshyNpcs.model_for(sp)
	holder.add_child(model)
	var anim: Node = NPC_ANIM.new()
	holder.add_child(anim)
	await process_frame
	await process_frame
	var sk: Skeleton3D = anim.skel
	var ids := {}
	var rest_y := {}
	for n in ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
		ids[n] = sk.find_bone(n)
		rest_y[n] = (sk.global_transform * sk.get_bone_global_pose(ids[n]).origin).y
	anim.walk_to([Vector3(0, 0, -400)], v)
	for i in 90:                                    # reach steady speed
		await process_frame
	var runs := {"LeftFoot": [], "RightFoot": []}
	var cur := {"LeftFoot": [], "RightFoot": []}
	var min_toe := 9.0
	var max_clear := 0.0
	var steps := 0
	var last_phase_step := int(anim._phase / PI)
	var frames := 240
	for i in frames:
		await process_frame
		for n in ["LeftFoot", "RightFoot"]:
			var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(ids[n]).origin
			var y: float = p.y - rest_y[n]
			max_clear = maxf(max_clear, y)
			if y < 0.004:
				cur[n].append(p.z)
			elif not cur[n].is_empty():
				runs[n].append(cur[n]); cur[n] = []
		for n in ["LeftToes", "RightToes"]:
			min_toe = minf(min_toe, (sk.global_transform * sk.get_bone_global_pose(ids[n]).origin).y - rest_y[n])
		if int(anim._phase / PI) != last_phase_step:
			last_phase_step = int(anim._phase / PI); steps += 1
	var slip := 0.0
	var n_runs := 0
	for n in runs:
		for r in runs[n]:
			if r.size() < 8: continue
			n_runs += 1
			var core: Array = r.slice(2, r.size() - 2)
			slip = maxf(slip, (core.max() - core.min()))
	var rg: Dictionary = anim._gait_rig
	print("   rig: leg %.3f (thigh %.3f shin %.3f) hip-ankle %.3f hipw %.3f toe %.3f cycle %.2f" % [rg["leg"], rg["thigh"], rg["shin"], rg["height"], rg["hipw"], rg["toe_len"], anim._cyc])
	var secs := frames / 60.0
	var step_len := v * secs / maxf(steps, 1)
	print("[%s %.2f m/s] step %.2f m, %.0f steps/min, planted-foot slip %.1f mm (%d contacts), toe min %.1f mm, max foot lift %.0f mm, pelvis y %.0f mm" % [sp, v, step_len, steps / secs * 60.0, slip * 1000.0, n_runs, min_toe * 1000.0, max_clear * 1000.0, sk.position.y * 1000.0])
	check("%s %.2f slip <= 20 mm" % [sp, v], slip <= 0.02 and n_runs >= 2)
	check("%s %.2f toes above floor (>= -15 mm)" % [sp, v], min_toe >= -0.015)
	holder.queue_free()
