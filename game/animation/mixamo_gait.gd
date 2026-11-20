class_name MixamoGait
extends RefCounted
## A Mixamo clip (baked by game/tools/bake_mixamo_gait.gd into mixamo_gait.json) retargeted onto any of our rigs, in the same form Gait.sample() writes: a skeleton-space
## Quaternion per bone, relative to the parent's rest frame (NpcAnimator._pose_bone), plus "_y" (pelvis offset in metres).
## Torso, neck, head: the clip's world rotation delta. Arms, legs, feet: the clip's world bone directions (swing from the rig's own rest direction), so a T-pose source
## drives our arms-down rest. Phase 0 is the left foot's touchdown, like Gait.
const DATA := "res://game/animation/mixamo_gait.json"
const CHAIN := ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]
const LIMBS := ["UpperArm", "LowerArm", "UpperLeg", "LowerLeg", "Foot"]
static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_data = j
	return _data


static func available(clip: String) -> bool:
	return data().has(clip)


## Rest directions the limbs are swung from: {"LeftUpperArm": unit vector, ...} in skeleton space (measured once the rig's rest pose is built).
static func rest_dirs(skel: Skeleton3D) -> Dictionary:
	var out := {}
	var pairs := {"UpperArm": ["UpperArm", "LowerArm"], "LowerArm": ["LowerArm", "Hand"], "UpperLeg": ["UpperLeg", "LowerLeg"], "LowerLeg": ["LowerLeg", "Foot"], "Foot": ["Foot", "Toes"]}
	for side in ["Left", "Right"]:
		for k in pairs:
			var a := skel.find_bone(side + pairs[k][0])
			var b := skel.find_bone(side + pairs[k][1])
			if a < 0 or b < 0:
				return {}
			out[side + k] = (skel.get_bone_global_pose(b).origin - skel.get_bone_global_pose(a).origin).normalized()
	return out


## Metres per full cycle (two steps) and the clip's time scale for a ground speed: the clip is a jog (its own speed in m/s is leg * legs-per-second); faster ground
## speeds play it up to 1.12x quicker and take longer strides.
static func cycle(clip: String, v: float, leg: float) -> float:
	var info: Dictionary = data()[clip]["info"]
	var natural := float(info["speed_legs_per_s"]) * leg
	var k := clampf(v / maxf(natural, 0.1), 0.8, 1.12)
	return maxf(v, 0.3) * float(info["period"]) / k


static func _frame(arr: Array, u: float) -> Array:
	var n := arr.size()
	var x := fposmod(u, 1.0) * n
	var i := int(floor(x)) % n
	return [i, (i + 1) % n, x - floor(x)]


static func _vec(arr: Array, fr: Array) -> Vector3:
	var a: Array = arr[fr[0]]
	var b: Array = arr[fr[1]]
	return Vector3(lerpf(a[0], b[0], fr[2]), lerpf(a[1], b[1], fr[2]), lerpf(a[2], b[2], fr[2])).normalized()


static func _stride(d: Vector3, s: float) -> Vector3:
	return Vector3(d.x, d.y, d.z * s).normalized()


static func _quat(a: Array) -> Quaternion:
	return Quaternion(a[0], a[1], a[2], a[3]).normalized()


## phase in radians (0 = left touchdown); writes into `out` for the names in Gait.BONES (those the clip does not drive are identity) and "_y".
static func sample(clip: String, phase: float, forward: Vector3, up: Vector3, right: Vector3, rest: Dictionary, rig: Dictionary, out: Dictionary, v := 0.0) -> void:
	var c: Dictionary = data()[clip]
	var info: Dictionary = c["info"]
	var stride := 1.0
	if v > 0.0:
		var natural := float(info["speed_legs_per_s"]) * float(rig["leg"])
		var kk := clampf(v / maxf(natural, 0.1), 0.8, 1.12)
		stride = clampf(v / (maxf(natural, 0.1) * kk), 0.7, 1.45)
	var bn := Basis(right, up, right.cross(up))
	var bi := bn.inverse()
	var u := fposmod(phase / TAU + float(info["touchdown_left"]), 1.0)
	var fr: Array = _frame(c["hips_y"], u)
	var dw := {}
	for name in CHAIN:
		var arr: Array = c["torso"][name]
		var q := _quat(arr[fr[0]]).slerp(_quat(arr[fr[1]]), fr[2])
		dw[name] = (bn * Basis(q) * bi).get_rotation_quaternion()
	out["Hips"] = dw["Hips"]
	for i in range(1, CHAIN.size()):
		out[CHAIN[i]] = (dw[CHAIN[i - 1]].inverse() * dw[CHAIN[i]]).normalized()
	out["_y"] = 0.0
	var drop := -99.0
	for side in ["Left", "Right"]:
		var swing := {}
		for k in LIMBS:
			var key: String = side + k
			var arr: Array = c["limbs"][key]
			var a: Array = arr[fr[0]]
			var b: Array = arr[fr[1]]
			var d := Vector3(lerpf(a[0], b[0], fr[2]), lerpf(a[1], b[1], fr[2]), lerpf(a[2], b[2], fr[2])).normalized()
			if k == "UpperLeg" or k == "LowerLeg":
				d = Vector3(d.x, d.y, d.z * stride).normalized()     # the stance foot has to cover the ground the character really covers
			swing[k] = Quaternion(rest[key], bn * d)
		out[side + "UpperArm"] = (dw["UpperChest"].inverse() * swing["UpperArm"]).normalized()
		out[side + "LowerArm"] = (swing["UpperArm"].inverse() * swing["LowerArm"]).normalized()
		out[side + "UpperLeg"] = (dw["Hips"].inverse() * swing["UpperLeg"]).normalized()
		out[side + "LowerLeg"] = (swing["UpperLeg"].inverse() * swing["LowerLeg"]).normalized()
		out[side + "Foot"] = (swing["LowerLeg"].inverse() * swing["Foot"]).normalized()
		# how far this ankle hangs below the hip joint (thigh and shin along the clip's own directions)
		var da: float = -(float(rig["thigh"]) * (bn * _stride(_vec(c["limbs"][side + "UpperLeg"], fr), stride)).dot(up) + float(rig["shin"]) * (bn * _stride(_vec(c["limbs"][side + "LowerLeg"], fr), stride)).dot(up))
		var td: float = float(rig.get("toe_drop", 0.0))
		var ltoe := sqrt(float(rig["toe_len"]) * float(rig["toe_len"]) + td * td)
		var dt: float = da - ltoe * (bn * _vec(c["limbs"][side + "Foot"], fr)).dot(up)
		var dr := maxf(da + td, dt)             # the lowest point of this foot: the heel (ankle above its sole) or the toes
		drop = maxf(drop, dr)
	# the pelvis puts the lower foot exactly on the floor, and rises by the clip's own foot clearance (flight)
	var cl: Array = c["clear"]
	out["_y"] = drop - float(rig["height"]) - float(rig.get("toe_drop", 0.0)) + lerpf(float(cl[fr[0]]), float(cl[fr[1]]), fr[2]) * float(rig["leg"])
