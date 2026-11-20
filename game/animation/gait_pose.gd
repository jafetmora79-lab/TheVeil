extends RefCounted
## THE VEIL - walk / run gait driven by distance travelled (one pose function, no walk/run pose switch).
## Everything is a function of the real ground speed `v` (m/s): cycle length, stance fraction, foot lift, pelvis
## height, arm swing, lean. The caller advances `phase` by (distance / cycle_length(v)) * TAU, so a planted foot
## stays where it landed whatever the speed. Rotations are skeleton-space, relative to NpcAnimator's arms-down rest
## (same convention as running_pose.gd). Conventions: +rotation about `right` swings a down-pointing limb forward;
## toes-up is +; leaning forward is -. Step = foot to the other foot, cycle = same foot to itself (two steps).
##
## Deviation from the brief's numbers (documented in docs/animation/GAIT.md): a 1.20 m step at 2.4 m/s needs a
## ~0.6 m stance reach per leg, longer than these ~0.9 m legs allow without a deep crouch. Cadence is limited to
## a human range instead (walk ~115-165 steps/min, sprint ~175 steps/min).
const BONES = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm",
	"LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"LeftFoot", "RightFoot", "LeftToes", "RightToes"]
const REF_LEG := 0.90              ## thigh + shin of the reference rig (cycle lengths scale with the real leg)
const LAG := 0.18                  ## arms trail the legs by this many radians

## (speed, value) tables, linearly interpolated.
const T_CYCLE := [[0.0, 0.7], [0.6, 0.95], [1.25, 1.30], [2.4, 1.75], [4.3, 2.95], [5.5, 3.6]]
## Fraction of the cycle each foot is on the ground. A run is 0.30 (two brief flights of 20 % of the cycle each: both feet
## off the ground around 37 % and 87 %), a walk 0.62; smooth in between.
const T_CONTACT := [[1.25, 0.62], [1.9, 0.56], [2.6, 0.46], [3.4, 0.36], [4.3, 0.30], [5.5, 0.28]]
const T_LIFT := [[0.6, 0.035], [1.25, 0.06], [2.4, 0.10], [4.3, 0.27], [5.5, 0.30]]
const T_DIP := [[1.25, 0.02], [2.4, 0.028], [4.3, 0.05], [5.5, 0.055]]
## Arm swing (degrees from hanging). At a run the forward hand stays low (about lower-chest height, close to the ribs) while the back elbow
## drives well behind the torso, so the backswing is more than twice the forward swing.
const T_ARM_FWD := [[0.0, 3.0], [1.25, 14.0], [2.4, 20.0], [4.3, 24.0], [5.5, 27.0]]
const T_ARM_BACK := [[0.0, 3.0], [1.25, 14.0], [2.4, 20.0], [4.3, 58.0], [5.5, 64.0]]
const T_ELBOW := [[1.25, 10.0], [2.4, 26.0], [4.3, 60.0], [5.5, 63.0]]    # flexion from the arms-down rest; at a run the elbow is ~85-105 degrees (open on the backswing, closing forward)
const T_LEAN := [[1.25, 2.0], [2.4, 6.0], [4.3, 20.0], [5.5, 23.0]]   # torso pitch (degrees, spine + chest); hips-to-neck reads about 60 % of it, the neck and head counter-rotate so the eyes stay on the path ahead
const T_YAW := [[1.25, 3.0], [2.4, 4.0], [4.3, 6.0], [5.5, 7.0]]
## Pelvis roll (degrees): the hip over the supporting leg rides a little higher, the swing hip drops.
const T_ROLL := [[1.25, 1.2], [2.4, 1.8], [4.3, 3.0], [5.5, 3.4]]
const ROLL_SIGN := 1.0
## Heel lift at toe-off (degrees) and how much of the stance it takes (fraction of the stance): walking lifts the heel only at the
## very end, a run rolls onto the ball of the foot from mid-stance and finishes pushing through the toes.
const HEEL_WALK := 16.0
const HEEL_RUN := 36.0
const HEEL_SPAN_WALK := 0.12
const HEEL_SPAN_RUN := 0.5


static func _tab(t: Array, v: float) -> float:
	if v <= t[0][0]:
		return t[0][1]
	for i in range(1, t.size()):
		if v <= t[i][0]:
			var a: Array = t[i - 1]
			var b: Array = t[i]
			return lerpf(a[1], b[1], (v - a[0]) / (b[0] - a[0]))
	return t[t.size() - 1][1]


## How much of the leg length the knee may use. A walk can straighten to 98.5 %; a run never locks the knee: contact is made with the
## knee already soft (about 95 %), which also removes the snap when a fully straight swing leg first takes weight.
static func leg_reach(v: float) -> float:
	return lerpf(0.985, 0.955, run_blend(v))


## 0 = walking, 1 = running (a smooth blend across the walk-run transition).
static func run_blend(v: float) -> float:
	return smoothstep(1.8, 3.4, v)


## Metres per full cycle (two steps) at ground speed v, for a character with legs of `leg_len` and a profile scale.
static func cycle_length(v: float, leg_len := REF_LEG, scale := 1.0) -> float:
	return _tab(T_CYCLE, v) * clampf(leg_len / REF_LEG, 0.7, 1.4) * scale


## Cycle length for this character: the speed table scaled by leg length and profile, then capped so the stance leg
## never needs more than a natural knee-bend / pelvis drop (short legs take shorter, quicker steps).
static func cycle_for(v: float, prof: Dictionary, rig: Dictionary) -> float:
	var base := cycle_length(v, rig["leg"], prof.get("cycle", 1.0))
	var cap_drop := lerpf(0.06, 0.15, smoothstep(1.0, 4.0, v))
	var lmax: float = (rig["thigh"] + rig["shin"]) * leg_reach(v)
	var rm := sqrt(maxf(lmax * lmax - pow(maxf(rig["height"] - cap_drop, 0.0), 2.0), 0.0)) - absf(rig["neutral"].z)
	return clampf(minf(base, 2.0 * rm / contact_fraction(v)), 0.6, 4.0)


static func contact_fraction(v: float) -> float:
	return _tab(T_CONTACT, v)


## Ankle target relative to its neutral place: x forward, y up. In contact its speed is exactly -(cycle) per unit
## of cycle time, which cancels a root advancing `cycle` metres per cycle (planted). Swing joins with equal velocity.
static func foot_target(phase: float, cycle: float, contact: float, lift: float, skew := 0.0) -> Vector2:
	var t := fposmod(phase / TAU, 1.0)
	if t <= contact:
		return Vector2(cycle * (contact * 0.5 - t), 0.0)
	var u := (t - contact) / (1.0 - contact)
	var edge := cycle * contact * 0.5
	var tangent := -cycle * (1.0 - contact)
	var x := (2.0 * u * u * u - 3.0 * u * u + 1.0) * -edge
	x += (u * u * u - 2.0 * u * u + u) * tangent
	x += (-2.0 * u * u * u + 3.0 * u * u) * edge
	x += (u * u * u - u * u) * tangent
	return Vector2(x, lift * pow(sin(PI * pow(u, lerpf(1.0, 0.72, skew))), 2.0))     # skew > 0: the heel is highest early in the swing (behind the body)


## Pelvis height offset (<= 0, metres) for phase and speed, including the drop that keeps the stance leg reachable.
static func pelvis_offset(phase: float, v: float, prof: Dictionary, rig: Dictionary, cycle: float, contact: float) -> float:
	var r := run_blend(v)
	var ts := fposmod(phase / PI, 1.0)
	var low: float = lerpf(contact - 0.5, contact * 0.5, r)
	var dip: float = _tab(T_DIP, v) * prof.get("bounce", 1.0)
	var reach := contact * cycle * 0.5 + absf(rig["neutral"].z)
	var lmax: float = (rig["thigh"] + rig["shin"]) * leg_reach(v)
	var need: float = rig["height"] - sqrt(maxf(lmax * lmax - reach * reach, 0.0))
	return -(maxf(need, 0.012) + dip * pow(cos(PI * (ts - low)), 2.0))


## rig: {thigh, shin, height (hip to ankle), neutral: Vector3(upper angle, lower-minus-upper, ankle fore offset), leg}.
## prof (all optional): cycle, arms, guard (0..1 arms drawn in), lean (deg added), bounce, lift.
## output gets a Quaternion per name in `bone_names` and "_y" (pelvis offset). Weight 1; the caller blends.
static func sample(phase: float, v: float, prof: Dictionary, rig: Dictionary, bone_names: Array,
		forward: Vector3, up: Vector3, right: Vector3, output: Dictionary) -> Dictionary:
	for b in bone_names:
		output[b] = Quaternion.IDENTITY
	var r := run_blend(v)
	var cycle := cycle_for(v, prof, rig)
	var c := contact_fraction(v)
	var lift: float = _tab(T_LIFT, v) * prof.get("lift", 1.0)
	var lean: float = _tab(T_LEAN, v) + prof.get("lean", 0.0)
	var guard: float = prof.get("guard", 0.0)
	var yaw: float = _tab(T_YAW, v)
	var cl := cos(phase)
	var roll: float = _tab(T_ROLL, v)
	var support := cos(phase - contact_fraction(v) * PI)            # +1 mid-stance of the left leg, -1 of the right
	output["Hips"] = Quaternion(up, deg_to_rad(-yaw * cl)) * Quaternion(forward, deg_to_rad(ROLL_SIGN * roll * support))
	output["Spine"] = Quaternion(right, deg_to_rad(-0.55 * lean)) * Quaternion(up, deg_to_rad(0.6 * yaw * cl)) * Quaternion(forward, deg_to_rad(-0.6 * ROLL_SIGN * roll * support))   # shoulders stay level
	output["Chest"] = Quaternion(right, deg_to_rad(-0.45 * lean))
	output["UpperChest"] = Quaternion(up, deg_to_rad(0.6 * yaw * cl))
	output["Neck"] = Quaternion(right, deg_to_rad(0.45 * lean))
	output["Head"] = Quaternion(right, deg_to_rad(0.5 * lean)) * Quaternion(up, deg_to_rad(0.3 * yaw * cl))
	var y := pelvis_offset(phase, v, prof, rig, cycle, c)
	output["_y"] = y
	var arm_scale: float = lerpf(prof.get("arms", 1.0), 1.0, 0.7 * r) * (1.0 - 0.35 * guard * (1.0 - r))     # who they are shows in the walk; a run swings the arms for everyone
	var arm_fwd: float = _tab(T_ARM_FWD, v) * arm_scale
	var arm_back: float = _tab(T_ARM_BACK, v) * arm_scale
	var flex: float = _tab(T_ELBOW, v)
	for side_index in 2:
		var names: Array = ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftUpperArm", "LeftLowerArm"] if side_index == 0 \
			else ["RightUpperLeg", "RightLowerLeg", "RightFoot", "RightUpperArm", "RightLowerArm"]
		var p := phase + float(side_index) * PI
		var target := foot_target(p, cycle, c, lift, r)
		target.x += rig["neutral"].z
		var hip_yaw := -deg_to_rad(yaw) * cl
		target.x += (1.0 if side_index == 0 else -1.0) * rig["hipw"] * sin(hip_yaw)    # pelvis yaw must not drag a planted foot
		var t := fposmod(p / TAU, 1.0)
		var pitch := 0.0
		var heel := deg_to_rad(lerpf(HEEL_WALK, HEEL_RUN, r))
		var span := lerpf(HEEL_SPAN_WALK, HEEL_SPAN_RUN, r) * c            # part of the stance spent rolling up onto the ball of the foot
		if t > c - span and t <= c:
			pitch = -heel * smoothstep(0.0, 1.0, (t - (c - span)) / span)  # heel rises, the ball stays planted, the toes push off
		elif t > c:
			var u := (t - c) / (1.0 - c)
			pitch = -heel * (1.0 - smoothstep(0.0, 0.3, u)) + deg_to_rad(7.0 + 3.0 * r) * sin(PI * smoothstep(0.4, 1.0, u))
		# the heel rises around the ankle; the ball sits `toe_len` ahead of and `toe_drop` below the ankle, so it would swing back and sink:
		# move the ankle (forward and up) by exactly as much, and the ball stays where it was planted
		var lift_p := maxf(-pitch, 0.0)
		var tl: float = rig["toe_len"]
		var td: float = rig.get("toe_drop", 0.0)
		target.y += tl * sin(lift_p) - td * (1.0 - cos(lift_p))
		target.x += tl * (1.0 - cos(lift_p)) + td * sin(lift_p)
		var height: float = rig["height"] + y - target.y
		var th: float = rig["thigh"]
		var sh: float = rig["shin"]
		var distance := minf(Vector2(target.x, height).length(), (th + sh) * lerpf(0.9999, 0.975, r))
		var hip := atan2(target.x, height) + acos(clampf((th * th + distance * distance - sh * sh) / (2.0 * th * distance), -1.0, 1.0))
		var knee := acos(clampf((th * th + sh * sh - distance * distance) / (2.0 * th * sh), -1.0, 1.0)) - PI
		var nu: float = rig["neutral"].x
		var nl: float = rig["neutral"].y
		output[names[0]] = Quaternion(right, hip - nu)
		output[names[1]] = Quaternion(right, knee - nl)
		# ankle keeps the sole flat in stance (heel rise only at the end), toes lift a little before landing
		output[names[2]] = Quaternion(right, -(hip + knee - nu - nl) + pitch)
		# arms: opposite the same-side leg, lagging it; the forward-swinging forearm folds a little more
		var swing := -cos(p - LAG)
		var fwd := maxf(swing, 0.0)
		var amp := lerpf(arm_back, arm_fwd, smoothstep(-0.3, 0.3, swing))          # a short swing forward, a long drive back (smooth through the middle)
		# (the scared "hands drawn up" guard belongs to walking and standing: a runner's hands stay low, a chase reaction raises one briefly)
		var up_arm := deg_to_rad(amp * swing - 3.0 + guard * 14.0 * (1.0 - r))
		var elbow := deg_to_rad(flex * (1.0 + 0.33 * fwd) + guard * 26.0 * (1.0 - r))
		output[names[3]] = Quaternion(right, up_arm)
		output[names[4]] = Quaternion(right, elbow)
	return output


## Rig measurements for sample(): call once after NpcAnimator has built its rest pose.
static func measure(skel: Skeleton3D, f: Vector3) -> Dictionary:
	var hip := skel.get_bone_global_pose(skel.find_bone("LeftUpperLeg")).origin
	var knee := skel.get_bone_global_pose(skel.find_bone("LeftLowerLeg")).origin
	var ankle := skel.get_bone_global_pose(skel.find_bone("LeftFoot")).origin
	var upper := atan2((knee - hip).dot(f), hip.y - knee.y)
	var lower := atan2((ankle - knee).dot(f), knee.y - ankle.y)
	var th := hip.distance_to(knee)
	var sh := knee.distance_to(ankle)
	var hip_r := skel.get_bone_global_pose(skel.find_bone("RightUpperLeg")).origin
	var toes := skel.get_bone_global_pose(skel.find_bone("LeftToes")).origin
	var hw := Vector2(hip.x - hip_r.x, hip.z - hip_r.z).length() * 0.5
	return {"hipw": hw, "toe_len": Vector2(toes.x - ankle.x, toes.z - ankle.z).length(), "toe_drop": maxf(ankle.y - toes.y, 0.0), "thigh": th, "shin": sh, "height": hip.y - ankle.y, "leg": th + sh,
		"neutral": Vector3(upper, lower - upper, (ankle - hip).dot(f))}


## Per-character profile (who they are shows in how they move). Unknown names get the default.
static func profile_for(name: String) -> Dictionary:
	match name:
		"Eddie":
			return {"cycle": 0.92, "arms": 0.8, "guard": 0.3, "bounce": 1.0}
		"Marcus":
			return {"cycle": 1.0, "arms": 1.05, "lean": 3.0, "bounce": 1.1}
		"Ruth":
			return {"cycle": 0.85, "arms": 0.5, "bounce": 0.6, "lift": 0.8}
		"Sarah":
			return {"cycle": 0.95, "arms": 0.8, "bounce": 0.8}
	return {}
