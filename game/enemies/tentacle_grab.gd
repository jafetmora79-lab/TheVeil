class_name VeilTentacleGrab
extends Node
## THE VEIL - a Mist Tentacle's grab, built bone by bone on the T_01 .. T_10 chain through its VeilTentaclePoser (no clip, no stretching: every bone keeps its length,
## only the bends change). One controller owns the poser while it runs: the poser's other writers (a whole-rig tilt, the scenes' lean tweens, the writhe layer) are held off.
##
## Phases (each a 0..1 parameter that a scene eases, so the silhouette changes clearly through each):
##   load     the upper half comes into a tight curl, the tip tucked inward; the base leans only enough to aim, the middle holds the tension
##   open     the curl opens joint by joint from the middle outward; the limb extends toward the target and looks longer because the curl opens; the tip stays slightly hooked
##   wrap     the tip is guided past the target's side and curls in first; the upper-middle joints then bring the chain round in a broad C that tightens (the squeeze) until
##            the tip has travelled right round the target's silhouette
##   pull     the tip and the upper chain stay wrapped while the lower and middle joints bend back toward the opening (an S): the closed curl is drawn in
##   release  the tip peels away first, the rest of the curl loosens in sequence (a miss is just a wrap around empty space and a recoil toward the opening)
## The plane of the bends is the tentacle's own horizontal plane (about its local Z, the way the poser's `curl` turns), so the C lies flat around a standing target.

var tentacle: Node3D
var poser: VeilTentaclePoser
var target_fn: Callable = Callable()          ## () -> Vector3: where the grab is aimed (world), read every frame
var radius := 0.35                             ## the target's silhouette radius (world metres)
var side := 1.0                                ## +1 / -1: which way the C turns (set by begin() from where the target is when `side` is 0)
var active := false
var load_k := 0.0
var open_k := 0.0
var wrap_k := 0.0
var squeeze := 0.0
var pull_k := 0.0
var release_k := 0.0
var report := {}
var _seg := PackedFloat32Array()               ## model-space length of each segment, joint i -> joint i+1 (9 of them), then the tip's own
var _o0 := Vector3.ZERO                        ## where the first joint (T_01) sits in the Root bone's frame
var _total := 0.0
var _wiggle: Node
var _wiggle_intensity := 0.0
var _was_straight := false
const LOAD_FROM := 3                           ## the curl of the load starts at this segment (T_04 up): the upper half
const LOAD_ANGLE := 0.62                       ## radians per segment of the loaded curl (about 35 degrees each)
const HOOK := 0.12                             ## radians per tip segment: the tip stays slightly hooked at full reach
const WRAP_MAX := 4.6                          ## radians of arc around the target at full wrap (about 265 degrees)


static func attach(t: Node3D, p: VeilTentaclePoser) -> VeilTentacleGrab:
	var g := VeilTentacleGrab.new()
	g.name = "Grab"
	g.tentacle = t
	g.poser = p
	t.add_child(g)
	g.process_priority = 85                    # before the poser (90) applies its arrays, long before the writhe layer (100)
	g._measure()
	return g


func _measure() -> void:
	var sk := poser.sk
	_seg.clear()
	for i in poser.bones.size():
		var o := sk.get_bone_rest(poser.bones[i]).origin
		if i == 0:
			_o0 = o
		else:
			_seg.append(o.length())
	if _seg.is_empty():
		return
	var tail := _seg[_seg.size() - 1]
	_seg.append(tail)                          # the last bone's own length (the tip's mesh)
	_total = 0.0
	for s in _seg:
		_total += s
	report["segments"] = _seg.size()
	report["chain_length_model"] = _total + _o0.length()


## Takes the poser: the chain starts straight and the writhe layer is held off.
func begin(target: Callable, r := 0.35, wrap_side := 0.0) -> void:
	target_fn = target
	radius = r
	active = true
	load_k = 0.0
	open_k = 0.0
	wrap_k = 0.0
	squeeze = 0.0
	pull_k = 0.0
	release_k = 0.0
	_was_straight = poser.straight
	poser.straight = true
	poser.weight = 1.0
	_wiggle = tentacle.get_node_or_null("Wiggle")
	if _wiggle != null:
		_wiggle_intensity = float(_wiggle.get("intensity"))
		_wiggle.set("intensity", 0.0)
	var p := _local(target.call())
	side = wrap_side if wrap_side != 0.0 else (1.0 if p.x < 0.0 else -1.0)      # curl toward the side the target is on
	_compose()


func end() -> void:
	active = false
	poser.straight = _was_straight
	if _wiggle != null and is_instance_valid(_wiggle):
		_wiggle.set("intensity", _wiggle_intensity)


## Ease one parameter (load_k, open_k, wrap_k, squeeze, pull_k, release_k) to `v` over `secs`.
func ease_to(param: String, v: float, secs: float, trans := Tween.TRANS_SINE, ease_t := Tween.EASE_IN_OUT) -> void:
	var from: float = get(param)
	var tw := create_tween().set_trans(trans).set_ease(ease_t)
	tw.tween_method(func(k: float): set(param, k), from, v, maxf(secs, 0.001))
	await tw.finished


## The target in the Root bone's frame, in model units (the world scale is undone: the maths uses the bone lengths as authored; the chain runs along +Y when straight).
func _local(world_p: Vector3) -> Vector3:
	var sk := poser.sk
	var rb := sk.get_bone_parent(poser.bones[0])
	var rp := sk.get_bone_global_pose(rb) if rb >= 0 else Transform3D.IDENTITY
	return rp.affine_inverse() * (sk.global_transform.affine_inverse() * world_p)


func _scale() -> float:
	return maxf(poser.sk.global_transform.basis.get_scale().x, 0.001)


func _process(_d: float) -> void:
	if active:
		_compose()


func _ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The headings (radians from the chain's +Y, positive toward -X) of every segment for: a straight lead-in at heading `psi0` that may buckle into an S of amplitude `beta`
## (so the reach can be shorter than the lead-in), then an arc of radius `R` turning `phi` radians toward `w`. The arc is made of the LAST bones only.
func _headings(psi0: float, beta: float, s_t: float, R: float, phi: float, w: float) -> PackedFloat32Array:
	var n := _seg.size()
	var psi := PackedFloat32Array()
	psi.resize(n)
	var s := 0.0
	for i in n:
		var mid := s + _seg[i] * 0.5
		var a := psi0
		if mid <= s_t:
			if beta > 0.0001:
				a += (-w * beta) if mid < s_t * 0.5 else (w * beta)             # the lead-in buckles into an S that returns to its heading: a shorter reach
		else:
			a += w * minf((mid - s_t) / maxf(R, 0.001), phi)
		psi[i] = a
		s += _seg[i]
	return psi


## Joint positions (the Root bone's plane) for a set of segment headings: from the first joint.
func _polyline(psi: PackedFloat32Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := Vector2(_o0.x, _o0.y)
	pts.append(p)
	for i in psi.size():
		p += Vector2(-sin(psi[i]), cos(psi[i])) * _seg[i]
		pts.append(p)
	return pts


## Where the C's centre ends up for (psi0, beta): the end of the lead-in plus R along the normal toward the turn side.
func _center(psi0: float, beta: float, s_t: float, R: float, w: float) -> Vector2:
	var psi := _headings(psi0, beta, s_t, R, 0.0, w)
	var pts := _polyline(psi)
	# the lead-in's end: the point at arclength s_t along the polyline
	var s := 0.0
	var e := pts[0]
	for i in _seg.size():
		if s + _seg[i] >= s_t:
			e = pts[i].lerp(pts[i + 1], (s_t - s) / maxf(_seg[i], 0.0001))
			break
		s += _seg[i]
		e = pts[i + 1]
	var heading := psi0
	return e + w * R * Vector2(-cos(heading), -sin(heading))


func _wrap_plan(p: Vector3, r_model: float, wk: float, sq: float, w: float, beta_min: float) -> PackedFloat32Array:
	var q := Vector2(p.x - _o0.x, p.y - _o0.y)
	var d := maxf(q.length(), 0.05)
	var psi_t := atan2(-q.x, q.y)
	var r_close := r_model * (1.0 - 0.12 * sq)
	var r_open := r_model * 2.4
	var R := minf(lerpf(r_open, r_close, _ss(wk)), d * 0.9)
	# the arc is made of the short upper bones: it starts after the long link (the rig has one far-off joint: see the test)
	var s_lock := 0.0
	var med := _seg[0]
	var sorted := Array(_seg)
	sorted.sort()
	med = sorted[sorted.size() / 2]
	var acc := 0.0
	for i in _seg.size():
		acc += _seg[i]
		if _seg[i] > med * 2.2:
			s_lock = acc
	var phi_goal := WRAP_MAX * _ss(wk)
	var arc_max := maxf(_total - s_lock, 0.0)
	var A := minf(phi_goal * R, arc_max)
	var phi := A / maxf(R, 0.001)
	var s_t := _total - A
	# the C's centre must sit on the target. Turning the whole lead-in about the first joint turns the centre with it exactly, so only the S-bend decides how far the
	# centre is from the base (bisection on the S amplitude); the aim then follows from the angle.
	var o0 := Vector2(_o0.x, _o0.y)
	var tvec := Vector2(q.x, q.y)
	var d_t := tvec.length()
	var lo := beta_min
	var hi := 2.4
	var c_lo := _center(0.0, lo, s_t, R, w) - o0
	var beta := lo
	if c_lo.length() > d_t:                                   # the target is nearer than the straight reach: buckle the lead-in until the centre is on it
		var c_hi := _center(0.0, hi, s_t, R, w) - o0
		if c_hi.length() < d_t:
			for it in 24:
				var mid := (lo + hi) * 0.5
				if (_center(0.0, mid, s_t, R, w) - o0).length() > d_t:
					lo = mid
				else:
					hi = mid
			beta = hi
		else:
			beta = hi                                          # nearer than even the most buckled lead-in reaches
	var c0 := _center(0.0, beta, s_t, R, w) - o0
	var psi0 := atan2(tvec.y, tvec.x) - atan2(c0.y, c0.x)       # the aim that turns that centre onto the target
	report["wrap_radius_model"] = R
	report["wrap_turn"] = phi
	report["s_t"] = s_t
	report["beta"] = beta
	report["center_error"] = (_center(psi0, beta, s_t, R, w) - Vector2(q.x + _o0.x, q.y + _o0.y)).length()
	return _headings(psi0, beta, s_t, R, phi, w)


func _compose() -> void:
	if _seg.is_empty() or not target_fn.is_valid():
		return
	var n := poser.bones.size()
	var world_t: Vector3 = target_fn.call()
	var p := _local(world_t)
	var r_model := radius / _scale()
	var q := Vector2(p.x - _o0.x, p.y - _o0.y)
	var d := maxf(q.length(), 0.05)
	var psi_t := atan2(-q.x, q.y)
	var w := side
	var ns := _seg.size()
	# ---- 1. the loaded / opening curl of the upper half (a flat curl in the tentacle's bend plane), aimed a little at the target
	var psi := PackedFloat32Array()
	psi.resize(ns)
	var aim := clampf(psi_t, -0.9, 0.9) * (0.25 * load_k * (1.0 - open_k) + open_k)         # the base leans only enough to aim; it aims fully as the limb reaches
	var acc := 0.0
	for i in ns:
		var turn := 0.0
		if i >= LOAD_FROM:
			var order := float(i - LOAD_FROM) / float(maxi(ns - 1 - LOAD_FROM, 1))        # 0 at the middle, 1 at the tip
			var opened := _ss((open_k * 1.5 - order * 0.5) / 1.0)                         # the middle opens first, the tip last
			var keep := 1.0 - opened
			if i >= ns - 3 and open_k > 0.0:
				keep = maxf(keep, HOOK / LOAD_ANGLE)                                       # the tip stays slightly hooked
			turn = w * LOAD_ANGLE * load_k * keep
			if i == ns - 1 or i == ns - 2:
				turn += w * 0.22 * load_k * (1.0 - open_k)                                 # tucked inward: the last joints curl in hardest
		acc += turn
		psi[i] = aim + acc
	# ---- 2. the wrap: from the open limb to the C around the target
	if wrap_k > 0.0:
		var plan := _wrap_plan(p, r_model, wrap_k, squeeze, w, 0.55 * pull_k)
		var k := _ss(wrap_k * 1.4)                                                         # the aim comes first, the curl follows
		for i in ns:
			var wk_i := clampf(k * 1.0 - (1.0 - float(i) / float(ns - 1)) * 0.0, 0.0, 1.0)
			psi[i] = lerpf(psi[i], plan[i], wk_i)
	# ---- 3. the release: the tip peels away first, the rest of the curl loosens in sequence toward the base
	if release_k > 0.0:
		var orig := psi.duplicate()
		var keep_acc := 0.0
		for i in ns:
			var turn_i: float = orig[i] - (orig[i - 1] if i > 0 else 0.0)
			var order_r := float(ns - 1 - i) / float(ns - 1)                                # 0 at the tip: it goes first
			var gone := _ss((release_k * 1.6 - order_r * 0.6) / 1.0)
			if i >= LOAD_FROM:
				turn_i *= (1.0 - gone)
			keep_acc += turn_i
			psi[i] = keep_acc
	# ---- 4. the pull is part of the wrap's plan above (the lower and middle joints buckle back into an S as the target comes nearer the opening, the C stays closed)
	# ---- 5. segment directions -> the poser's per-bone curl (each bone turns by the change of heading), lean only to aim at the target's height
	var lean_aim := clampf(atan2(p.z, d), -0.45, 0.45) * clampf(load_k * 0.3 + open_k, 0.0, 1.0)
	for j in n:
		var prev_dir := 0.0 if j == 0 else (psi[j - 1] if j - 1 < ns else psi[ns - 1])
		var cur := psi[j] if j < ns else psi[ns - 1]
		poser.curl[j] = cur - prev_dir
		poser.lean[j] = lean_aim / 3.0 if j < 3 else 0.0
	poser.apply()


## The model-space joint positions of the chain as posed now (for tests and for placing things): the root, then each bone's origin.
func joints_world() -> PackedVector3Array:
	var out := PackedVector3Array()
	poser.sk.force_update_all_bone_transforms()
	for b in poser.bones:
		out.append(poser.sk.global_transform * poser.sk.get_bone_global_pose(b).origin)
	return out
