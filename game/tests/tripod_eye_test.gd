extends SceneTree
## The tripod Colossus's searchlight eye (game/prototypes/monsters_meshy/tripod_eye.gd), headless:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/tripod_eye_test.gd
## The beam is exactly where the eyeball points; the stages come in order (search with twitches and sweeps and uneven pauses, alert with a sweep past the target and a snap
## back while the neck lags the eye, lock tight and still); the beam's brightness is steady through the twitches; the visible beam never goes through a solid.
var fails := 0
var tc: VeilTripodColossus
var eye: VeilTripodEye
var scan: Node3D


func check(n: String, ok: bool, info := "") -> void:
	print("  %s %s %s" % ["ok  " if ok else "FAIL", n, info])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()
	create_timer(240.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _box(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	root.add_child(sb)
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)


func _ray_len(from: Vector3, dir: Vector3) -> float:
	var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 170.0, 1))
	return (hit["position"] as Vector3).distance_to(from) if not hit.is_empty() else 170.0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	_box(Vector3(0, -0.5, -10), Vector3(120, 1, 120))                 # the ground
	_box(Vector3(0, 8, -30), Vector3(60, 16, 1))                      # a wall
	_box(Vector3(8, 2, -18), Vector3(1.0, 4.0, 1.0))                  # a post in the way of some sweeps
	tc = VeilTripodColossus.new()
	root.add_child(tc)
	tc.build(12.0, 0.0)
	tc.set_walking(false)
	eye = tc.eye
	eye.search_on = true
	eye.max_angle = 1.35
	scan = Node3D.new()
	root.add_child(scan)
	scan.global_position = Vector3(0, 4, -29)
	eye.target = scan
	await frames(90)
	check("the rig is the three-legged one (Body, Eye, Leg_B / Leg_L / Leg_R)", eye.skel.find_bone("Eye") >= 0 and eye.skel.find_bone("Leg_B_Up") >= 0 and eye.skel.find_bone("Leg_L_Up") >= 0 and eye.skel.find_bone("Leg_R_Up") >= 0)
	check("starts searching", eye.stage == VeilTripodEye.Stage.SEARCH)
	check("an eyeball, a spot light that casts shadows, a beam cone and its core", eye.ball != null and eye.spot != null and eye.spot.shadow_enabled and eye.cone != null and eye.core != null)
	# ------------------------------------------------ the light is exactly where the eyeball points, through fast eye movement too
	var worst_spot := 0.0
	var worst_aim := 0.0
	var worst_cone := 0.0
	var e_min := 1e9
	var e_max := 0.0
	var big := 0
	var small := 0
	var prev_off := eye._off
	var pauses: Array = []
	var still_since := 0
	var seg := 0.0
	var beam_over_solid := 0
	for f in 900:
		scan.global_position = Vector3(lerpf(-14.0, 14.0, float(f) / 900.0), 4.0, -29.0)
		await physics_frame
		var look := -eye.ball.global_basis.z.normalized()
		worst_spot = maxf(worst_spot, rad_to_deg(look.angle_to(-eye.spot.global_basis.z.normalized())))
		worst_aim = maxf(worst_aim, rad_to_deg(look.angle_to((eye.aim_point.global_position - eye.ball.global_position).normalized())))
		var cone_dir := -eye.cone.global_basis.y.normalized()
		cone_dir = (eye.cone.global_basis.y * -1.0).normalized()
		worst_cone = maxf(worst_cone, rad_to_deg(minf(look.angle_to(cone_dir), look.angle_to(-cone_dir))))
		e_min = minf(e_min, eye.spot.light_energy)
		e_max = maxf(e_max, eye.spot.light_energy)
		var d := eye._off - prev_off
		if d.length() > 0.0008:
			seg += d.length()                          # a movement of the gaze: add up its length until it stops
			if still_since > 6:
				pauses.append(still_since / 60.0)
			still_since = 0
		else:
			still_since += 1
			if still_since == 3 and seg > 0.0:
				if seg > 0.2:
					big += 1                           # a sweep across a wider angle
				elif seg > 0.01:
					small += 1                         # a quick, small correction
				seg = 0.0
		prev_off = eye._off
		# the visible beam stops at the first solid thing in its way
		var rl := _ray_len(eye.aim_point.global_position, look)
		if float(eye.report.get("beam_len", 0.0)) > rl + 1.0:
			beam_over_solid += 1
	check("the spot light points exactly where the eyeball looks (worst %.3f deg, also while it sweeps)" % worst_spot, worst_spot < 0.05)
	check("the aim point turns with the eyeball (worst %.3f deg)" % worst_aim, worst_aim < 0.05)
	check("the visible cone is aligned with the pupil (worst %.3f deg)" % worst_cone, worst_cone < 0.3)
	check("the beam's brightness stays steady through the twitches (%.2f .. %.2f)" % [e_min, e_max], e_max > 0.0 and (e_max - e_min) / e_max < 0.05)
	check("search: quick small corrections AND wider sweeps happen (%d small steps, %d sweep steps)" % [small, big], small >= 1 and big >= 1)
	var mean := 0.0
	for p in pauses:
		mean += p
	mean /= maxf(pauses.size(), 1)
	var sd := 0.0
	for p in pauses:
		sd += (p - mean) * (p - mean)
	sd = sqrt(sd / maxf(pauses.size(), 1))
	check("the pauses are uneven (%d pauses, mean %.2f s, spread %.2f s)" % [pauses.size(), mean, sd], pauses.size() >= 4 and sd > 0.15)
	check("the visible beam never goes through a solid (%d frames over)" % beam_over_solid, beam_over_solid == 0)
	check("it ends at the wall / ground (length %.1f m)" % float(eye.report.get("beam_len", 0.0)), float(eye.report.get("beam_len", 0.0)) < 80.0)
	# ------------------------------------------------ alert: the eye gets there first, sweeps slightly past, snaps back; the neck follows a beat later
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(10, 3, -6)
	var t0 := eye.ball.global_position
	eye.target = cam
	var tdir := (cam.global_position - t0).normalized()
	var stages := []
	var gaze_err_03 := 0.0
	var pod_err_03 := 0.0
	var max_err_after := 0.0
	var crossed := false
	var still_scale := 9.0
	var lock_f := -1
	for f in 150:
		await physics_frame
		if eye.stage == VeilTripodEye.Stage.LOCK and lock_f < 0:
			lock_f = f
		if lock_f >= 0 and f == lock_f + 30:
			still_scale = tc.ap.speed_scale                     # half a second into the lock
		var td := (cam.global_position - eye.ball.global_position).normalized()
		var ge := rad_to_deg(eye._gaze.angle_to(td))
		var pe := rad_to_deg(eye._pod.angle_to(td))
		if f == 12:
			gaze_err_03 = ge
			pod_err_03 = pe
		if ge < 2.0:
			crossed = true
		if crossed and f > 14:
			max_err_after = maxf(max_err_after, ge)
		if stages.is_empty() or stages[stages.size() - 1] != eye.stage:
			stages.append(eye.stage)
	check("the target becoming the camera starts the alert, then the lock (stages %s)" % str(stages), stages == [VeilTripodEye.Stage.ALERT, VeilTripodEye.Stage.LOCK])
	check("the eye gets there before the neck (0.2 s in: eye %.1f deg off, pod %.1f deg off)" % [gaze_err_03, pod_err_03], gaze_err_03 < pod_err_03)
	check("the eye sweeps slightly past the target and comes back (overshoot %.2f deg after first arriving)" % max_err_after, max_err_after > 0.5 and max_err_after < 10.0)
	check("overshoot recorded in its own report (%.3f)" % float(eye.report.get("overshoot", 0.0)), float(eye.report.get("overshoot", 0.0)) > 0.005)
	# ------------------------------------------------ lock: the bright centre stays on the target with small corrections, the body goes unusually still for a beat
	await frames(40)
	var tdl := (cam.global_position - eye.ball.global_position).normalized()
	var lock_err := rad_to_deg(eye._gaze.angle_to(tdl))
	check("locked: the pupil stays on the target (%.2f deg)" % lock_err, eye.stage == VeilTripodEye.Stage.LOCK and lock_err < 1.0)
	check("locked: the pupil is white-hot (hot %.2f)" % eye._hot, eye._hot > 0.9)
	check("locked: the body is unusually still for a beat (animation speed %.2f half a second in)" % still_scale, still_scale < 0.2)
	await frames(120)
	check("...and then it moves again (animation speed %.2f)" % tc.ap.speed_scale, tc.ap.speed_scale > 0.9)
	# ------------------------------------------------ the beam still stops at an obstacle placed in its way
	_box(Vector3(5, 3, -16), Vector3(4, 6, 0.4))
	await frames(20)
	var dirl := -eye.ball.global_basis.z.normalized()
	var rl2 := _ray_len(eye.aim_point.global_position, dirl)
	check("an obstacle placed in the beam ends it (beam %.1f m, ray %.1f m)" % [float(eye.report.get("beam_len", 0.0)), rl2], float(eye.report.get("beam_len", 0.0)) <= rl2 + 1.0)
	# ------------------------------------------------ back to searching when the target is not a camera
	eye.target = scan
	await frames(10)
	check("a target that is not the camera sends it back to searching", eye.stage == VeilTripodEye.Stage.SEARCH)
	print("RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
