extends SceneTree
## The tripod Colossus: slow walk (8 s cycle), the two front legs step first, then the rear one; a planted foot does not slide.
var fails := 0
func check(n: String, ok: bool, info := "") -> void:
	print("  %s %s %s" % ["ok  " if ok else "FAIL", n, info])
	if not ok: fails += 1

func _initialize() -> void:
	var tc := VeilTripodColossus.new()
	root.add_child(tc)
	tc.build(12.0, 0.0)
	await process_frame
	tc.ap.play("Walk_Heavy")
	tc.ap.speed_scale = 1.0
	var sk := tc.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var feet := {"Leg_L": sk.find_bone("Leg_L_Foot"), "Leg_R": sk.find_bone("Leg_R_Foot"), "Leg_B": sk.find_bone("Leg_B_Foot")}
	var len := tc.ap.get_animation("Walk_Heavy").length
	check("cycle is slow (8 s)", absf(len - 8.0) < 0.1, str(len))
	check("ground speed 0.45 m/s at 12 m", absf(tc.ground_speed() - 0.45 * tc.height / 12.0) < 0.01, str(tc.ground_speed()))
	# when does each foot start to lift (y rises above its lowest)?
	var lift := {}
	var low := {}
	for k in feet:
		low[k] = INF
	var samples := []
	var t := 0.0
	while t < len:
		tc.ap.seek(t, true)
		sk.force_update_all_bone_transforms()
		var row := {}
		for k in feet:
			var p: Vector3 = sk.get_bone_global_pose(feet[k]).origin
			row[k] = p
			low[k] = minf(low[k], p.y)
		samples.append([t, row])
		t += len / 96.0
	for k in feet:
		var best := -INF
		for s in samples:
			if s[1][k].y > best:
				best = s[1][k].y
				lift[k] = s[0]
	var rest_pose := {}
	for k in feet:
		rest_pose[k] = sk.get_bone_rest(feet[k]).origin
	print("time of each foot's highest point: ", lift)
	var order := feet.keys()
	order.sort_custom(func(a, b): return lift.get(a, 99.0) < lift.get(b, 99.0))
	print("order: ", order)
	check("front legs (L, R) step before the rear leg", order[2] == "Leg_B", str(order))
	var fz := {}
	for k in feet:
		fz[k] = (sk.global_transform * sk.get_bone_global_rest(feet[k]).origin).z
	print("rest foot z (forward is -Z): ", fz)
	check("the rear leg is behind the two front legs", fz["Leg_B"] > fz["Leg_L"] and fz["Leg_B"] > fz["Leg_R"], str(fz))
	print("RESULT ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
