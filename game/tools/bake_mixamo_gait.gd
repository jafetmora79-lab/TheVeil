extends SceneTree
## Bakes the Mixamo "Running" and "Walking" clips of creatures/animation_sources/mixamo_bomber_run_walk.glb into game/animation/mixamo_gait.json, in a form any rig of ours
## can use (res://game/animation/mixamo_gait.gd): world rotation deltas for the torso/head, world directions for the limbs (so a T-pose source drives our arms-down rest),
## hip height, stride speed (in leg lengths per second) and the foot-touchdown time. All in a canonical frame (right, up, right x up), so the facing of the source is irrelevant.
##   godot --headless --path . --script res://game/tools/bake_mixamo_gait.gd
const SRC := "res://creatures/animation_sources/mixamo_bomber_run_walk.glb"
const OUT := "res://game/animation/mixamo_gait.json"
const TORSO := {"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck", "Head": "Head"}
const SAMPLES := 48

var sk: Skeleton3D
var ap: AnimationPlayer
var B := Basis()


func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var path := ProjectSettings.globalize_path(SRC)
	if doc.append_from_file(path, st) != OK:
		print("cannot read ", path)
		quit(1)
		return
	var scene := doc.generate_scene(st)
	root.add_child(scene)
	sk = scene.find_child("Skeleton3D", true, false) as Skeleton3D
	ap = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	sk.reset_bone_poses()
	print("BONES ", sk.get_bone_name(0), " ", sk.get_bone_name(1), " ", sk.get_bone_name(10))
	var rest_toes := sk.get_bone_global_rest(_i("ToeBase", "Left")).origin - sk.get_bone_global_rest(_i("Foot", "Left")).origin
	rest_toes.y = 0.0
	var F := rest_toes.normalized()
	var U := Vector3.UP
	var Rr := F.cross(U).normalized()
	B = Basis(Rr, U, Rr.cross(U))
	var out := {}
	for clip in ["Running", "Walking"]:
		out[clip.to_lower()] = _bake(clip)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote ", OUT)
	quit(0)


func _i(n: String, side := "") -> int:
	return sk.find_bone("mixamorig_" + side + n)


func _round(v: float) -> float:
	return snappedf(v, 0.0001)


func _qa(q: Quaternion) -> Array:
	return [_round(q.x), _round(q.y), _round(q.z), _round(q.w)]


func _bake(clip: String) -> Dictionary:
	var anim := ap.get_animation(clip)
	var period := anim.length
	var rest_hips := sk.get_bone_global_rest(_i("Hips")).origin.y
	var leg := (sk.get_bone_global_rest(_i("UpLeg", "Left")).origin - sk.get_bone_global_rest(_i("Leg", "Left")).origin).length() \
		+ (sk.get_bone_global_rest(_i("Leg", "Left")).origin - sk.get_bone_global_rest(_i("Foot", "Left")).origin).length()
	var bi := B.inverse()
	var torso := {}
	for k in TORSO:
		torso[k] = []
	var limbs := {}
	var hips_y := []
	var ankle_f := {"Left": [], "Right": []}
	var ankle_y := {"Left": [], "Right": []}
	var hips_f := []
	var clear := []                                             # height of the lowest ankle (leg lengths), before the minimum is taken off
	var drops := []                                             # vertical hip joint -> lowest ankle, in leg lengths
	for s in SAMPLES:
		var t := period * float(s) / float(SAMPLES)
		ap.play(clip)
		ap.seek(t, true)
		ap.advance(0.0)
		sk.force_update_all_bone_transforms()
		for k in TORSO:
			var i := _i(TORSO[k])
			var g := sk.get_bone_global_pose(i).basis.orthonormalized()
			var gr := sk.get_bone_global_rest(i).basis.orthonormalized()
			var d := bi * (g * gr.inverse()) * B
			torso[k].append(_qa(d.get_rotation_quaternion()))
		for side in ["Left", "Right"]:
			for pair in [["UpperArm", "Arm", "ForeArm"], ["LowerArm", "ForeArm", "Hand"], ["UpperLeg", "UpLeg", "Leg"], ["LowerLeg", "Leg", "Foot"], ["Foot", "Foot", "ToeBase"]]:
				var a := sk.get_bone_global_pose(_i(pair[1], side)).origin
				var b := sk.get_bone_global_pose(_i(pair[2], side)).origin
				var dir := bi * (b - a).normalized()
				var key: String = side + pair[0]
				if not limbs.has(key):
					limbs[key] = []
				limbs[key].append([_round(dir.x), _round(dir.y), _round(dir.z)])
		var hp := sk.get_bone_global_pose(_i("Hips")).origin
		hips_y.append(_round((hp.y - rest_hips) / leg))
		var hj := sk.get_bone_global_pose(_i("UpLeg", "Left")).origin.y
		var low := 99.0
		for side in ["Left", "Right"]:
			var ah := sk.get_bone_global_rest(_i("Foot", side)).origin.y - sk.get_bone_global_rest(_i("ToeBase", side)).origin.y
			low = minf(low, minf(sk.get_bone_global_pose(_i("Foot", side)).origin.y - ah, sk.get_bone_global_pose(_i("ToeBase", side)).origin.y))
		clear.append(low / leg)
		drops.append(hj - minf(sk.get_bone_global_pose(_i("Foot", "Left")).origin.y, sk.get_bone_global_pose(_i("Foot", "Right")).origin.y))
		var hc := bi * hp
		hips_f.append(hc.z)
		for side in ["Left", "Right"]:
			var an := sk.get_bone_global_pose(_i("Foot", side)).origin
			var ac := bi * an
			ankle_f[side].append(-(ac.z - hc.z) / leg)         # forward of the hips, in leg lengths (canonical z points backward: forward = -z)
			ankle_y[side].append((an.y - rest_hips) / leg)
	# stance: ankle low; speed = how fast the stance foot goes backward under the hips
	var speeds := []
	var touch := 0.0
	var contact := 0.0
	for side in ["Left", "Right"]:
		var ys: Array = ankle_y[side]
		var lo := 99.0
		var hi := -99.0
		for y in ys:
			lo = minf(lo, y)
			hi = maxf(hi, y)
		var thr := lo + (hi - lo) * 0.18
		var stance := []
		for s in SAMPLES:
			stance.append(ys[s] < thr)
		var n_st := 0
		for v in stance:
			if v:
				n_st += 1
		if side == "Left":
			contact = float(n_st) / float(SAMPLES)
			for s in SAMPLES:                                   # touchdown: first stance sample after a swing sample
				if stance[s] and not stance[(s - 1 + SAMPLES) % SAMPLES]:
					touch = float(s) / float(SAMPLES)
					break
		# slope of the foot's forward position over the stance samples
		var xs := []
		var ts := []
		var start := 0
		for s in SAMPLES:
			if stance[s] and not stance[(s - 1 + SAMPLES) % SAMPLES]:
				start = s
				break
		for j in SAMPLES:
			var s := (start + j) % SAMPLES
			if not stance[s]:
				break
			ts.append(float(j) / float(SAMPLES) * period)
			xs.append(ankle_f[side][s])
		if ts.size() >= 3:
			var mt := 0.0
			var mx := 0.0
			for q in ts.size():
				mt += ts[q]
				mx += xs[q]
			mt /= ts.size()
			mx /= ts.size()
			var num := 0.0
			var den := 0.0
			for q in ts.size():
				num += (ts[q] - mt) * (xs[q] - mx)
				den += (ts[q] - mt) * (ts[q] - mt)
			speeds.append(-num / maxf(den, 1e-6))
	var speed := 0.0
	for v in speeds:
		speed += v
	speed /= maxf(speeds.size(), 1)
	var dmax := -99.0
	var at := 0
	for s in SAMPLES:
		if drops[s] > dmax:
			dmax = drops[s]
			at = s
	var cmin := 99.0
	for v in clear:
		cmin = minf(cmin, v)
	for s in SAMPLES:
		clear[s] = _round(maxf(clear[s] - cmin - 0.13, 0.0))      # the two stance feet sit a few cm apart in the source: only the rise above that counts as flight
	var info := {"drop_max": _round(dmax / leg), "hips_y_at_drop_max": hips_y[at], "period": period, "samples": SAMPLES, "speed_legs_per_s": _round(speed), "contact": _round(contact), "touchdown_left": _round(touch), "leg_len_src": _round(leg)}
	print(clip, " ", info)
	return {"info": info, "torso": torso, "limbs": limbs, "hips_y": hips_y, "clear": clear}
