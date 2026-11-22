extends Node
class_name NpcAnimator
## THE VEIL - procedural body animation for the Pack 06 cast (no animation clips exist yet).
## Works on the shared humanoid rig (Hips / Spine / Chest / UpperChest / Neck / Head / *Shoulder / *UpperArm /
## *LowerArm / *Hand / *UpperLeg / *LowerLeg / *Foot / *Toes) without assuming bone-axis conventions:
## every motion is defined in skeleton space (up, the character's real forward measured from foot -> toes, right),
## then converted into each bone's local frame.
##   - rest pose: arms brought down to the sides, a small elbow bend
##   - idle: breathing, slow weight shift, small arm sway, occasional glances
##   - look-at: head + neck track the player camera; the body turns to face them when they are talked to
##   - talk(seconds): hand gestures, head nods (the face itself is VeilFace)
##   - mood "calm" / "scared": scared = hunched, faster breathing, arms drawn in
##   - walk_to(points): procedural walk cycle along waypoints (parent-local), then `arrived`

signal arrived

@export var look_range := 6.0
@export var turn_to_face := true
@export var max_pitch := 0.45                ## look-at pitch limit (radians); cinematics raise it
var mood := "calm"
var look_target: Node3D            ## defaults to the active camera
var walk_speed := 1.25
## Collision movement (VeilSurvivorBody move_and_slide, physics rate) only while a companion follows the player.
## Scripted walks (cinematics, regroups, retreats) follow their planned paths every frame without collision: they
## are routed around the world already, and colliding with each other / the player got them stuck or pushed out.
var physical := false

var skel: Skeleton3D
var root: Node3D                   ## the character node that is moved / turned
var F := Vector3(0, 0, -1)          ## skeleton-space forward, up, right
var U := Vector3.UP
var R := Vector3.RIGHT
var _b := {}                        ## bone name -> index
var _rest := {}                     ## bone index -> rest local Basis (after the arms are lowered)
var _pinv := {}                     ## bone index -> inverse of the parent's rest global basis
var _prest := {}                    ## bone index -> parent's rest global basis
var _t := 0.0
var _seed := 0.0
var _talk_left := 0.0
var _gest := {"la": 0.0, "lf": 0.0, "ra": 0.0, "rf": 0.0, "nod": 0.0, "tilt": 0.0}
var _gest_to := {"la": 0.0, "lf": 0.0, "ra": 0.0, "rf": 0.0, "nod": 0.0, "tilt": 0.0}
var _gest_timer := 0.0
var _look := Vector2.ZERO           ## smoothed (yaw, pitch)
var _prev_look := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_timer := 2.0
var _scare := 0.0
var _path: Array = []
var _walk := 0.0                    ## 0..1 blend into the walk cycle
var _run := 0.0                     ## 0..1 blend from walking into running (by actual speed)
var _speed := 0.0
var _step_i := 0
var _phase := 0.0
var _turn_goal = null               ## world-space direction the body should turn towards (or null)
## Distance-driven gait (game/animation/gait_pose.gd): one pose function of the real ground speed, planted feet.
const Gait = preload("res://game/animation/gait_pose.gd")
var _gait := {}                     ## sampled rotations (+ "_y" pelvis offset), reused every frame
var _gait_rig := {}
var _mx_rest := {}                  ## the rig's rest limb directions for the retargeted Mixamo run (empty: the procedural run only)
var _mx_pose := {}
var use_mixamo_run := true          ## the run is the retargeted Mixamo clip (res://game/animation/mixamo_gait.json), blended in by _run
var _gprof := {}
var _gait_base_guard := 0.0
var _gw := 0.0                      ## 0..1 weight of the gait over idle (0 standing, 1 moving)
var _cyc := 1.3                     ## metres per cycle, smoothed
var _was_moving := false
var _next_right := false            ## the foot that leads the next start (alternates)

## A runner keeps his eyes on where he is running and his hands low. A scared runner now and then reacts, briefly: one palm comes up and the head
## glances to the side (react() starts one; with chase_reactions on they also happen by themselves every 5-9 s while running scared).
var chase_reactions := true
var _react_in := -1.0
var _react_dur := 0.0
var _react_t := 0.0
var _react_side := 1.0
var _react_w := 0.0
var _react_q := {}
var react_twist_deg := -120.0       ## forearm twist of the raised hand (mirrored for the left hand): -120 shows an open palm out in front of the shoulder, clear of the face (picked from renders)
var _palm_n := {}                   ## per hand: the palm normal at rest
var _fore_dir := {}                 ## per hand: the forearm direction at rest (skeleton space)
var _finger_axis := {}              ## per hand: the knuckle axis that curls the fingers toward the palm (measured from the rig)


func react(seconds := 0.8, side := 0.0) -> void:
	_react_dur = maxf(seconds, 0.3)
	_react_t = 0.0
	_react_side = side if side != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	var hand := "Right" if _react_side > 0.0 else "Left"
	# the arm swings a little outward, then lifts forward (the hand ends in front of and beside the shoulder, clear of the face) ...
	var out := signf(_gp(hand + "UpperArm").origin.dot(R))
	var abduct := _q(F, 35.0)
	if (abduct * -U).dot(R * out) < 0.0:
		abduct = _q(F, -35.0)
	var q_up := _q(R, 50.0) * abduct
	var q_low := _q(R, 105.0)
	# ... and the forearm turns about its own axis so the open palm faces forward (angle measured on the rig: tests/run_pose_test.gd)
	if _fore_dir.has(hand):
		var total := q_up * q_low
		var tw := Quaternion((total * (_fore_dir[hand] as Vector3)).normalized(), deg_to_rad(react_twist_deg * (1.0 if hand == "Right" else -1.0)))
		q_low = q_up.inverse() * tw * q_up * q_low
	_react_q = {hand + "UpperArm": q_up, hand + "LowerArm": q_low}


func _running_now() -> bool:
	return _run > 0.5 and _walk > 0.5 and not _path.is_empty()


func _update_react(delta: float) -> void:
	var target := 0.0
	if _react_dur > 0.0:
		_react_t += delta
		var k := _react_t / _react_dur
		if k >= 1.0:
			_react_dur = 0.0
		else:
			target = sin(PI * k)                        # up, hold, down: one brief reaction
	elif chase_reactions and mood == "scared" and _running_now():
		if _react_in < 0.0:
			_react_in = randf_range(2.5, 5.0)
		_react_in -= delta
		if _react_in <= 0.0:
			react(0.8)
			_react_in = randf_range(5.0, 9.0)
	_react_w = lerpf(_react_w, target, minf(delta * 10.0, 1.0))
	if _react_w < 0.002 and _react_dur <= 0.0:
		_react_w = 0.0


func _ready() -> void:
	root = get_parent() as Node3D
	var found := root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		set_process(false)
		return
	skel = found[0]
	_seed = float(hash(root.name) % 1000) * 0.37
	for i in skel.get_bone_count():
		_b[skel.get_bone_name(i)] = i
	if not _b.has("Hips") and _b.has("mixamorig_Hips"):
		_setup_native()
	_measure_frame()
	_build_rest()
	if not _native and bone("LeftUpperLeg") >= 0 and bone("LeftFoot") >= 0 and bone("RightFoot") >= 0:
		_gait_rig = Gait.measure(skel, F)
		_gprof = Gait.profile_for(String(root.name))
		_gait_base_guard = float(_gprof.get("guard", 0.0))
		if MixamoGait.available("running") and MixamoGait.available("walking"):
			_mx_rest = MixamoGait.rest_dirs(skel)
	_measure_fingers()


## The curl axis of each hand: across the knuckles (index -> little), signed so that the fingertips move toward the palm (the side facing the body).
func _measure_fingers() -> void:
	for side in ["Left", "Right"]:
		var names := [side + "IndexProximal", side + "LittleProximal", side + "MiddleProximal", side + "MiddleDistal", side + "Hand"]
		var ok := true
		for n in names:
			if bone(n) < 0:
				ok = false
		if not ok:
			continue
		var a := (_gp(side + "LittleProximal").origin - _gp(side + "IndexProximal").origin).normalized()
		var d := (_gp(side + "MiddleDistal").origin - _gp(side + "MiddleProximal").origin).normalized()
		var hand := _gp(side + "Hand").origin
		var medial := -R * signf(hand.dot(R))
		var sgn := 1.0 if a.cross(d).dot(medial) >= 0.0 else -1.0
		_finger_axis[side] = a * sgn * FINGER_FLIP
		_palm_n[side] = a.cross(d).normalized() * sgn                 # the palm normal at rest (faces the body)
		_fore_dir[side] = _dir(side + "LowerArm", side + "Hand")


func bone(n: String) -> int:
	return _b.get(n, -1)


func _gp(n: String) -> Transform3D:
	return skel.get_bone_global_pose(bone(n))


## Forward from the feet (toes are in front of the ankles), right = forward x up.
func _measure_frame() -> void:
	if bone("LeftToes") >= 0 and bone("LeftFoot") >= 0:
		var f := (_gp("LeftToes").origin - _gp("LeftFoot").origin) + (_gp("RightToes").origin - _gp("RightFoot").origin)
		f.y = 0.0
		if f.length() > 0.001:
			F = f.normalized()
	R = F.cross(U).normalized()


## Rotate bone `i` by the skeleton-space rotation `q` about its own origin, on top of its current local pose.
func _apply_global(i: int, q: Quaternion) -> void:
	var p := skel.get_bone_parent(i)
	var pb := skel.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
	var lb := Basis(skel.get_bone_pose_rotation(i))
	skel.set_bone_pose_rotation(i, (pb.inverse() * Basis(q) * pb * lb).get_rotation_quaternion())


func _dir(a: String, b: String) -> Vector3:
	return (_gp(b).origin - _gp(a).origin).normalized()


func _build_rest() -> void:
	# arms down to the sides (a touch out and forward), elbows slightly bent
	for side in ["Left", "Right"]:
		var ua := bone(side + "UpperArm")
		var la := bone(side + "LowerArm")
		if ua < 0 or la < 0:
			continue
		var out := signf(_gp(side + "UpperArm").origin.dot(R))
		if out == 0.0:
			out = -1.0 if side == "Left" else 1.0
		var want := (-U * cos(deg_to_rad(9.0)) + R * out * sin(deg_to_rad(9.0)) + F * 0.04).normalized()
		_apply_global(ua, Quaternion(_dir(side + "UpperArm", side + "LowerArm"), want))
		var want2 := (-U * cos(deg_to_rad(12.0)) + F * sin(deg_to_rad(12.0)) + R * out * 0.03).normalized()
		_apply_global(la, Quaternion(_dir(side + "LowerArm", side + "Hand"), want2))
	for i in skel.get_bone_count():
		_rest[i] = Basis(skel.get_bone_pose_rotation(i))
		var p := skel.get_bone_parent(i)
		var pb := skel.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
		_prest[i] = pb
		_pinv[i] = pb.inverse()


func arm_angle_from_down(side: String) -> float:
	return rad_to_deg(_dir(side + "UpperArm", side + "LowerArm").angle_to(-U))


# ------------------------------------------------------------------ public API
func talk(seconds: float) -> void:
	_talk_left = maxf(_talk_left, seconds)


## Seated pose (no clip needed): thighs forward, knees bent, hips lowered so the pelvis rests at seat_y (metres
## above the character's floor). Blended in / out over ~0.6 s. The caller places the root on the seat.
var seated := false
var hold_facing := false               ## riding in the car: the body keeps facing the way it was placed
var seat_y := 0.48
var _sit := 0.0
var _hip_h := -1.0
const FINGER_FLIP := 1.0              ## 1 / -1: flips every curl if the measured palm side proved wrong on a rig
const SIT_THIGH := 86.0
const SIT_KNEE := 88.0


func set_seated(on: bool, seat_height := 0.48) -> void:
	seated = on
	seat_y = seat_height
	if on:
		walk_to([])


## HURT ON THE FLOOR (not a chair pose): the whole model lies down. "side" = curled on the floor, hurt, breathing hard; "back" = on the back, struggling (being dragged). "" = up again.
var downed := ""
var _down := 0.0
var _model: Node3D
var _model_rest := Transform3D.IDENTITY
var _face_l := Vector3.ZERO
func set_downed(mode: String) -> void:
	downed = mode
	if mode != "":
		seated = false
		walk_to([])


## A limp (0..1): the character runs / walks hobbling, the body dipping and canting to one side on every stride (Sarah after the bite). Works with the native clips and the procedural gait alike.
var limp := 0.0
var _limp_phase := 0.0
func _update_limp(delta: float) -> void:
	if _model == null or downed != "" or _down > 0.001:
		return
	if limp <= 0.001 or _speed < 0.35:
		if limp <= 0.001 and _model.transform != _model_rest and _down <= 0.001 and _lying_native() == "":
			_model.transform = _model_rest
		return
	_limp_phase += delta * _speed * 1.9
	var f := _face_l if _face_l.length() > 0.5 else Vector3(0, 0, 1)
	var cant := sin(_limp_phase) * 0.11 * limp
	var dip := -absf(sin(_limp_phase)) * 0.06 * limp
	_model.transform = Transform3D(Basis(f, cant), Vector3(0, dip, 0)) * _model_rest


var _lift := 0.15
func _update_downed(delta: float) -> void:
	_down = move_toward(_down, 1.0 if downed != "" else 0.0, delta * 2.2)
	if _model == null:
		if skel == null:
			return
		_model = skel
		while _model.get_parent() != root and _model.get_parent() != null:
			_model = _model.get_parent() as Node3D
		_model_rest = _model.transform
	if _lying_native() != "":
		_model.transform = _model_rest                       # the clip lies the body down itself
		return
	if _down <= 0.001 and _model.transform == _model_rest:
		_face_l = (root.global_transform.basis.inverse() * world_forward()).normalized()      # measured while upright (lying down changes the skeleton's own facing)
		return
	if _down <= 0.001:
		_model.transform = _model_rest
		return
	var f := _face_l if _face_l.length() > 0.5 else Vector3(0, 0, 1)                     # the way the face looks, in the character's own frame
	var k := smoothstep(0.0, 1.0, _down)
	var mode := downed if downed != "" else "side"
	var basis_l := Basis.IDENTITY
	if mode == "back":
		var axis := f.cross(Vector3.UP).normalized()
		basis_l = Basis(axis, PI * 0.5 * k)                                   # face to the ceiling
		basis_l = Basis(Vector3.UP, sin(_t * 8.0) * 0.16 * k) * basis_l     # twisting, fighting it
		basis_l = Basis(f, sin(_t * 6.0 + 1.3) * 0.12 * k) * basis_l
	else:
		basis_l = Basis(f, PI * 0.5 * k) * Basis(Vector3.UP, 0.0)             # on the side
		basis_l = Basis(Vector3.RIGHT.cross(f).normalized() if absf(f.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP, sin(_t * 2.2) * 0.04 * k) * basis_l   # the breathing
	# rest it ON the floor: measure the lowest bone of the lying body and lift the model until that bone is 9 cm above the floor (bones run through the middle of the limbs)
	var low := INF
	var sk_xf := skel.global_transform
	for i in skel.get_bone_count():
		low = minf(low, (sk_xf * skel.get_bone_global_pose(i)).origin.y)
	if low < INF:
		_lift = clampf(_lift + (root.global_position.y + 0.09 - low) * minf(1.0, 14.0 * delta), 0.0, 1.2)
	_model.transform = Transform3D(basis_l, Vector3(0, _lift * k, 0)) * _model_rest


func set_mood(m: String) -> void:
	mood = m


## A hop / vault: wind-up crouch (20 %), flight (60 %) with arms thrown up and knees tucked, landing absorb (20 %).
## Only the body pose and the skeleton's height move (the physical body is driven by whoever calls this).
var _jump_t := -1.0
var _jump_dur := 0.75
var _jump_h := 0.5
func jump(height := 0.5, duration := 0.75) -> void:
	_jump_h = height
	_jump_dur = maxf(duration, 0.3)
	_jump_t = 0.0


func is_jumping() -> bool:
	return _jump_t >= 0.0


func walk_to(points: Array, speed := 1.25) -> void:
	_path = points.duplicate()
	walk_speed = speed


func is_walking() -> bool:
	return not _path.is_empty()


func face_towards(world_pos: Vector3) -> void:
	var d := world_pos - root.global_position
	d.y = 0.0
	if d.length() > 0.01:
		_turn_goal = d.normalized()


func world_forward() -> Vector3:
	var f := skel.global_transform.basis * F
	f.y = 0.0
	return f.normalized()


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	_npc_steps(delta)
	if skel == null or not root.is_visible_in_tree():
		return
	_t += delta
	_talk_left = maxf(_talk_left - delta, 0.0)
	_scare = move_toward(_scare, 1.0 if mood == "scared" else 0.0, delta * 0.8)
	if not _uses_physics():
		_update_walk(delta)
	_update_turn(delta)
	_update_gestures(delta)
	_update_react(delta)
	_update_downed(delta)
	_update_limp(delta)
	_update_look(delta)
	_sit = move_toward(_sit, 1.0 if seated else 0.0, delta * 1.7)
	if _jump_t >= 0.0:
		_jump_t += delta
		if _jump_t >= _jump_dur:
			_jump_t = -1.0
	if _native:
		_native_step()
		if _clip_on:
			return
	_pose()


# ------------------------------------------------------------------ a Mixamo-rigged model plays its own clips while it moves
var _native := false                ## the model is the Mixamo-rigged one (CHR_bomber_Mixamo.glb): "Walking" / "Running" play as authored, this animator poses everything else
var _clip_on := false
var _clip := ""
var _ap: AnimationPlayer
var _rest_pos := {}
const NATIVE_SPEED := {"Walking": 1.3, "Running": 2.8}     ## ground speed (m/s) each clip covers at its authored pace


func _setup_native() -> void:
	_native = true
	var base := {"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck", "Head": "Head"}
	for k in base:
		_b[k] = _b.get("mixamorig_" + base[k], -1)
	var fingers := {"Thumb": "HandThumb", "Index": "HandIndex", "Middle": "HandMiddle", "Ring": "HandRing", "Little": "HandPinky"}
	for side in ["Left", "Right"]:
		for k in {"Shoulder": "Shoulder", "UpperArm": "Arm", "LowerArm": "ForeArm", "Hand": "Hand", "UpperLeg": "UpLeg", "LowerLeg": "Leg", "Foot": "Foot", "Toes": "ToeBase"}:
			var m: String = {"Shoulder": "Shoulder", "UpperArm": "Arm", "LowerArm": "ForeArm", "Hand": "Hand", "UpperLeg": "UpLeg", "LowerLeg": "Leg", "Foot": "Foot", "Toes": "ToeBase"}[k]
			_b[side + k] = _b.get("mixamorig_" + side + m, -1)
		for f in fingers:
			for j in 3:
				_b[side + f + ["Proximal", "Intermediate", "Distal"][j]] = _b.get("mixamorig_" + side + fingers[f] + str(j + 1), -1)
	for i in skel.get_bone_count():
		_rest_pos[i] = skel.get_bone_pose_position(i)
	var aps := root.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_ap = aps[0] as AnimationPlayer
		var own := AnimationLibrary.new()                  # a library of its own: the imported one is SHARED by every instance of the model, and replacing a clip in it freed
		for c in ["Walking", "Running", "Jump", "Chair_Sit_Idle_M"]:         # the clip another instance was playing (a native crash on the GPU driver)
			if _ap.has_animation(c):
				var an := _ap.get_animation(c).duplicate() as Animation
				an.loop_mode = Animation.LOOP_NONE if c == "Jump" else Animation.LOOP_LINEAR
				for t in an.get_track_count():               # in place: the character's own travel comes from the game, not from the clip
					if an.track_get_type(t) == Animation.TYPE_POSITION_3D and String(an.track_get_path(t)).ends_with("mixamorig_Hips"):
						var x0: Vector3 = an.track_get_key_value(t, 0)
						for k in an.track_get_key_count(t):
							var v: Vector3 = an.track_get_key_value(t, k)
							an.track_set_key_value(t, k, Vector3(x0.x, v.y, x0.z))
				own.add_animation(c, an)
		for c in LYING_CLIPS.values():                       # hurt on the floor: the two lying clips that came with the Meshy police officer (same Mixamo skeleton, so they play on every Mixamo model)
			var la := _lying_clip_source(String(c))
			if la != null:
				own.add_animation(c, la.duplicate() as Animation)
		_ap.stop()
		for ln in _ap.get_animation_library_list():
			_ap.remove_animation_library(ln)
		_ap.add_animation_library("", own)


const LYING_CLIPS := {"side": "SideLying_Reach_Help", "back": "Prone_Reach_Help"}
const LYING_SOURCES := {"SideLying_Reach_Help": "res://game/prototypes/npc_meshy/CHR_police_redhair_SideLying.glb", "Prone_Reach_Help": "res://game/prototypes/npc_meshy/CHR_police_redhair_Prone.glb"}
static var _lying_cache := {}


## The lying clip (hips fixed over the character's own spot, looping), cut once from the Meshy glb that carries it.
static func _lying_clip_source(clip: String) -> Animation:
	if _lying_cache.has(clip):
		return _lying_cache[clip]
	var out: Animation = null
	var ps := load(String(LYING_SOURCES.get(clip, ""))) as PackedScene if ResourceLoader.exists(String(LYING_SOURCES.get(clip, ""))) else null
	if ps != null:
		var n := ps.instantiate()
		for ap in n.find_children("*", "AnimationPlayer", true, false):
			if (ap as AnimationPlayer).has_animation(clip):
				out = (ap as AnimationPlayer).get_animation(clip).duplicate() as Animation
		n.free()
	if out != null:
		out.loop_mode = Animation.LOOP_LINEAR
		for t in out.get_track_count():
			if out.track_get_type(t) == Animation.TYPE_POSITION_3D and String(out.track_get_path(t)).ends_with("mixamorig_Hips"):
				var x0: Vector3 = out.track_get_key_value(t, 0)
				for k in out.track_get_key_count(t):
					var v: Vector3 = out.track_get_key_value(t, k)
					out.track_set_key_value(t, k, Vector3(x0.x, v.y, x0.z))
	_lying_cache[clip] = out
	return out


## The native clip for the current downed mode, or "" (not a Mixamo model / no clip: the procedural lie-down is used).
func _lying_native() -> String:
	if not _native or _ap == null or downed == "":
		return ""
	var c := String(LYING_CLIPS.get(downed, ""))
	return c if c != "" and _ap.has_animation(c) else ""


func _play_native(clip: String, speed: float, y: float) -> void:
	if clip != _clip or not _ap.is_playing():
		_clip = clip
		_ap.play(clip, 0.2)
	_ap.speed_scale = speed
	_clip_on = true
	skel.position.y = y


## The sit clip's pelvis is at its own chair height: the skeleton is moved so the pelvis sits where this NPC's seat is.
func _seat_offset() -> float:
	var an := _ap.get_animation("Chair_Sit_Idle_M")
	var hips_y := 0.5
	for t in an.get_track_count():
		if an.track_get_type(t) == Animation.TYPE_POSITION_3D and String(an.track_get_path(t)).ends_with("mixamorig_Hips"):
			hips_y = (an.track_get_key_value(t, 0) as Vector3).y
	return (seat_y + 0.12) - hips_y


func _native_step() -> void:
	if _ap == null:
		return
	var want := ""
	var lc := _lying_native()
	if lc != "":
		_play_native(lc, 1.0, 0.0)
		return
	if _jump_t >= 0.0 and _ap.has_animation("Jump"):
		_play_native("Jump", _ap.get_animation("Jump").length / maxf(_jump_dur, 0.3), 0.0)
		return
	if _sit > 0.5 and _ap.has_animation("Chair_Sit_Idle_M"):
		_play_native("Chair_Sit_Idle_M", 1.0, _seat_offset())
		return
	if _gw > 0.15 and _sit < 0.3 and _jump_t < 0.0 and _speed > 0.25:
		want = "Running" if _run > 0.5 else "Walking"
	if want != "":
		_play_native(want, clampf(_speed / float(NATIVE_SPEED[want]), 0.7, 1.4), 0.0)
	elif _clip_on:
		_ap.stop()
		_clip = ""
		_clip_on = false
		for i in skel.get_bone_count():                       # back to the animator's own rest pose (arms down) for everything the clip touched
			skel.set_bone_pose_rotation(i, _rest[i].get_rotation_quaternion())
			skel.set_bone_pose_position(i, _rest_pos[i])


func _physics_process(delta: float) -> void:
	if _uses_physics() and skel != null and root.is_visible_in_tree():
		_update_walk(delta)


## Every walk of a survivor body collides with the world (walls, props, doors, other people) and follows the floor, not only a
## companion's. A scripted walk that is jammed for ~1.6 s (a shut door it could not open, a prop on the path) falls back to the
## old unconstrained walk for a moment so a scene never waits forever on `arrived`; that leg still follows the floor height.
var _jam_t := 0.0
var _vcmd := 0.0                                ## the ground speed actually used this frame (walk_speed reached by acceleration)
var _gap_t := 0.0                               ## seconds without a path (short gaps between two paths keep the speed)
var _rerouted := false
var _ghost_left := 0.0
var jams := 0                                   ## tests: how many walks had to be forced through


## An authored scene that walks someone out of a doorway or through geometry on purpose (it routes the path itself) sets this: the
## walk is then the old unconstrained one, but still follows the floor height.
var free_walk := false


func _uses_physics() -> bool:
	if physical:
		return true
	if free_walk:
		return false
	return root is VeilSurvivorBody and root.is_inside_tree() and _ghost_left <= 0.0


## A shut door the walker is heading for opens (the same rule as a companion's: not a locked one).
func _open_door_ahead(heading: Vector3) -> void:
	if root == null or not root.is_inside_tree():
		return
	for d in root.get_tree().get_nodes_in_group("veil_door"):
		var door := d as Interactable
		if door == null or door.is_open or not door.is_inside_tree() or door.collision_layer == 0:
			continue
		if door.lock_check.is_valid() and String(door.lock_check.call()) != "":
			continue
		var to: Vector3 = (door.global_position - root.global_position) * Vector3(1, 0, 1)
		if to.length() < 1.6 and (to.length() < 0.05 or to.normalized().dot(heading) > 0.2):
			door.set_open(true)


func _snap_to_floor() -> void:
	var from := root.global_position + Vector3(0, 0.8, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -1.6, 0), 1)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.7 and not (hit["collider"] as Node).is_in_group("veil_furniture"):
		root.global_position.y = (hit["position"] as Vector3).y


## A walk that ends inside the player, another survivor or a wall edge takes one short corrective step to the
## nearest clear spot (a single capsule query on arrival - nothing runs per frame).
func _settle_clear() -> void:
	var body := root as VeilSurvivorBody
	if body == null or not body.is_inside_tree() or body.is_clear(body.global_position):
		return
	var safe := body.nearest_safe(body.global_position, 1.2)
	var frame := body.get_parent_node_3d()
	if safe.is_finite() and frame and safe.distance_to(body.global_position) > 0.05:
		_path = [frame.to_local(safe)]


func _update_walk(delta: float) -> void:
	if _path.is_empty():
		_gap_t += delta
		if _gap_t > 0.4:
			_vcmd = move_toward(_vcmd, 0.0, 14.0 * delta)     # a gap between two paths (a follower is re-pathed every 0.25 s) keeps its speed for 0.4 s; a real stop then falls to 0
		_walk = move_toward(_walk, 0.0, delta * 3.0)
		_speed = lerpf(_speed, 0.0, minf(delta * 6.0, 1.0))      # settle: the gait fades out instead of freezing mid-stride
		_run = move_toward(_run, 0.0, delta * 2.5)
		_gw = move_toward(_gw, clampf(_speed / 0.4, 0.0, 1.0), delta * 6.0)
		if _gw < 0.02:
			_was_moving = false
		return
	_ghost_left = maxf(_ghost_left - delta, 0.0)
	var target: Vector3 = _path[0]
	var here := root.position
	var d := target - here
	d.y = 0.0
	if d.length() < 0.08:
		_path.pop_front()
		if _path.is_empty():
			_settle_clear()
			arrived.emit()
		return
	_walk = move_toward(_walk, 1.0, delta * 3.0)
	_gap_t = 0.0
	_vcmd = move_toward(_vcmd, walk_speed, (12.0 if physical else 5.0) * delta)   # ground speed ramps (5 m/s^2; 12 for a follower that keeps pace with the player): walk -> run is an acceleration, not a step
	var step := minf(_vcmd * _walk * delta, d.length())
	var body := root as VeilSurvivorBody if _uses_physics() else null
	var before := root.global_position
	if body:
		var frame := body.get_parent_node_3d()
		var motion := frame.global_basis * (d.normalized() * step)
		if body.step_target.is_finite():
			var remaining := body.step_target - before
			var advance := Vector3.UP * minf(remaining.y, 4.0 * delta) if remaining.y > 0.012 else remaining.limit_length(walk_speed * delta)
			if remaining.length() < 0.015 or body.move_and_collide(advance):
				body.step_target = Vector3.INF
		else:
			var fall := -0.5 if body.is_on_floor() else maxf(body.velocity.y - 18.0 * delta, -8.0)
			body.velocity = motion / delta + Vector3.UP * fall
			body.move_and_slide()
			if body.is_on_wall() and body.get_floor_normal().y > 0.93:
				var probe := motion.normalized() * minf(d.length(), VeilSurvivorBody.RADIUS + 0.06)
				body.step_target = VeilSurvivorBody.step_landing(body, probe, 0.35)
	else:
		root.position += d.normalized() * step
		if root is VeilSurvivorBody and root.is_inside_tree():
			_snap_to_floor()
	var moved := before.distance_to(root.global_position)
	if body != null and not physical:
		# jam detection for scripted walks only (a companion has its own stuck recovery)
		if moved < step * 0.2 and step > 0.0:
			_jam_t += delta
			if _jam_t > 0.5 and _jam_t - delta <= 0.5:
				_open_door_ahead(d.normalized())
			if _jam_t > 1.0 and not _rerouted:
				_rerouted = true                 # first a detour around whatever is in the way (the world's own A* for NPCs)
				var w := root.get_tree().get_first_node_in_group("veil_world")
				var frame := root.get_parent_node_3d()
				if w != null and frame != null and not _path.is_empty():
					var route: Array = w.npc_route(frame, root.position, _path[-1], body)
					if not route.is_empty():
						_path = route
						_jam_t = 0.0
			if _jam_t > 1.6:
				_jam_t = 0.0
				_rerouted = false
				_ghost_left = 1.2                # no way round: only now is the old unconstrained walk used, for a moment
				jams += 1
		else:
			_jam_t = 0.0
			_rerouted = false
	if moved < 0.001:
		_walk = move_toward(_walk, 0.0, delta * 3.0)
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), minf(delta * 6.0, 1.0))
	_run = move_toward(_run, clampf((_speed - 2.4) / 1.8, 0.0, 1.0), delta * 2.5)
	_gw = move_toward(_gw, clampf(_speed / 0.4, 0.0, 1.0), delta * 6.0)
	if not _gait_rig.is_empty():
		var want_cyc := Gait.cycle_for(_speed, _gprof, _gait_rig)
		if use_mixamo_run and not _mx_rest.is_empty():
			var wa := smoothstep(0.3, 0.8, _speed)
			want_cyc = lerpf(want_cyc, MixamoGait.cycle("walking", _speed, float(_gait_rig["leg"])), wa)
			want_cyc = lerpf(want_cyc, MixamoGait.cycle("running", _speed, float(_gait_rig["leg"])), _run)
		if moved > 0.0005 and not _was_moving and _gw < 0.05:
			# starting from rest: begin in the passing pose (feet together), the stance foot alternating each start
			_cyc = want_cyc
			_phase = Gait.contact_fraction(_speed) * 0.5 * TAU + (PI if _next_right else 0.0)
			_next_right = not _next_right
		else:
			_cyc = lerpf(_cyc, want_cyc, minf(delta * 3.0, 1.0))
		if moved > 0.0005:
			_was_moving = true
		_phase += moved / _cyc * TAU                  # one full cycle per _cyc metres: the planted foot stays put
	else:
		_phase += moved / lerpf(0.62, 0.98, _run) * PI
	var si := int(_phase / PI)
	if si != _step_i:
		_step_i = si
	if moved > 0.0005:
		_steps_t = 0.25                              # walking now: the recorded footsteps play (see _npc_steps)
	var parent := root.get_parent_node_3d()
	_turn_goal = (parent.global_transform.basis * d.normalized()) if parent else d.normalized()


func _update_turn(delta: float) -> void:
	if hold_facing:
		_turn_goal = null
		return
	var cam = _target_pos()
	if _turn_goal == null and turn_to_face and cam != null and _path.is_empty():
		var to := (cam as Vector3) - root.global_position
		to.y = 0.0
		if to.length() < look_range and (_talk_left > 0.0 or to.length() < 2.2):
			var ang := world_forward().signed_angle_to(to.normalized(), Vector3.UP)
			if absf(ang) > deg_to_rad(55.0):
				_turn_goal = to.normalized()
	if _turn_goal == null:
		return
	var a := world_forward().signed_angle_to(_turn_goal, Vector3.UP)
	var rate := (3.2 if not _path.is_empty() else 2.0) * delta
	if absf(a) < 0.03 or (absf(a) < deg_to_rad(12.0) and _path.is_empty()):
		if _path.is_empty():
			_turn_goal = null
		return
	root.rotate_y(clampf(a, -rate, rate))


## Standing and pondering (a shopper deciding what to buy): head bowed a little towards what they look at, one hand to the chin, the other arm across the body holding that elbow.
var pondering := false
var _pond := 0.0


func _update_gestures(delta: float) -> void:
	_pond = move_toward(_pond, 1.0 if (pondering and _walk < 0.05 and not seated and _jump_t < 0.0) else 0.0, delta * 1.2)
	_gest_timer -= delta
	if _talk_left > 0.0 and _gest_timer <= 0.0:
		_gest_timer = randf_range(0.45, 1.1)
		var hand := randi() % 3                       # 0 right, 1 left, 2 both
		var lift := randf_range(0.35, 1.0)
		_gest_to["ra"] = lift * (1.0 if hand != 1 else 0.15)
		_gest_to["rf"] = lift * randf_range(0.6, 1.0) * (1.0 if hand != 1 else 0.2)
		_gest_to["la"] = lift * (1.0 if hand != 0 else 0.15)
		_gest_to["lf"] = lift * randf_range(0.6, 1.0) * (1.0 if hand != 0 else 0.2)
		_gest_to["nod"] = randf_range(-1.0, 1.0)
		_gest_to["tilt"] = randf_range(-1.0, 1.0)
	elif _talk_left <= 0.0:
		for k in _gest_to:
			_gest_to[k] = 0.0
	for k in _gest:
		_gest[k] = lerpf(_gest[k], _gest_to[k], minf(delta * 5.0, 1.0))


func _target_pos():
	if look_target and is_instance_valid(look_target):
		return look_target.global_position
	var cam: Camera3D = root.get_viewport().get_camera_3d() if root.is_inside_tree() else null
	return cam.global_position if cam else null


func _update_look(delta: float) -> void:
	if _running_now() and look_target == null:
		# a runner looks where he is running (no turning to whoever is near); the chase reaction is the only glance
		var ahead := Vector2(_react_side * 0.8 * _react_w, 0.04 * _react_w)
		_look = _look.lerp(ahead, minf(delta * 6.0, 1.0))
		_prev_look = _look
		return
	var want := Vector2.ZERO
	var tp = _target_pos()
	if tp != null and bone("Head") >= 0:
		var head_w := skel.global_transform * _gp("Head").origin
		var to: Vector3 = tp - head_w
		if to.length() < look_range or look_target != null:
			var local := skel.global_transform.basis.inverse() * to
			var yaw := atan2(-local.dot(R), local.dot(F))
			var pitch := atan2(local.dot(U), Vector2(local.dot(F), local.dot(R)).length())
			if absf(yaw) < deg_to_rad(110.0) or look_target != null:   # a held gaze never flips to a glance (no rattle)
				want = Vector2(clampf(yaw, -1.2, 1.2), clampf(pitch, -0.5, max_pitch))
	if want == Vector2.ZERO:
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			_glance_timer = randf_range(2.0, 5.0)
			_glance = Vector2(randf_range(-0.5, 0.5), randf_range(-0.1, 0.12)) * (1.6 if mood == "scared" else 1.0)
		want = _glance
	_look = _look.lerp(want, minf(delta * 4.0, 1.0))
	if look_target != null:                            # a held gaze: steady (a capped turn rate, no frame-to-frame jitter)
		_look = _prev_look + (_look - _prev_look).limit_length(delta * 2.5)
	_prev_look = _look


func _q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))


## Set bone `n` = rest, rotated by skeleton-space rotation q (relative to the parent's rest frame).
func _pose_bone(n: String, q: Quaternion) -> void:
	var i := bone(n)
	if i < 0:
		return
	if _gait_on > 0.0 and _gait.has(n):
		if n == "Neck" or n == "Head":
			q = q * Quaternion.IDENTITY.slerp(_gait[n], _gait_on)      # the gaze (look-at, nods) stays on top of the gait
		else:
			q = q.slerp(_gait[n], _gait_on)
	if _react_w > 0.0 and _react_q.has(n):
		q = q.slerp(_react_q[n], _react_w)               # the chase reaction: a hand up beside the shoulder
	var pb: Basis = _prest[i]
	skel.set_bone_pose_rotation(i, (_pinv[i] * Basis(q) * pb * _rest[i]).get_rotation_quaternion())


var _gait_on := 0.0                 ## effective gait weight this frame (0 while seated / jumping / standing)


func _pose() -> void:
	_gait_on = 0.0
	if not _gait_rig.is_empty() and _jump_t < 0.0:
		_gait_on = _gw * (1.0 - _sit)
		if _gait_on > 0.0:
			_gprof["guard"] = maxf(_gait_base_guard, _scare)
			Gait.sample(_phase, _speed, _gprof, _gait_rig, Gait.BONES, F, U, R, _gait)
			if use_mixamo_run and not _mx_rest.is_empty():
				for pair in [["walking", smoothstep(0.3, 0.8, _speed)], ["running", _run]]:
					if float(pair[1]) <= 0.0:
						continue
					MixamoGait.sample(pair[0], _phase, F, U, R, _mx_rest, _gait_rig, _mx_pose)
					for k in _mx_pose:
						_gait[k] = lerpf(float(_gait[k]), float(_mx_pose[k]), float(pair[1])) if k == "_y" else (_gait[k] as Quaternion).slerp(_mx_pose[k], float(pair[1]))
	var t := _t + _seed
	var s := _scare
	var breath_rate := lerpf(0.26, 0.55, s)            # breaths per second
	var br := sin(t * TAU * breath_rate)
	var sway := sin(t * 0.37) * (1.0 - _walk)
	var w := _walk
	var ph := _phase
	# jump envelope: cr = crouch (wind-up, landing), air = in flight, lift = height of the flight arc
	var cr := 0.0
	var air := 0.0
	var lift := 0.0
	if _jump_t >= 0.0:
		var ju := _jump_t / _jump_dur
		w = 0.0
		if ju < 0.2:
			cr = sin(ju / 0.2 * PI * 0.5)
		elif ju < 0.8:
			var u := (ju - 0.2) / 0.6
			air = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.85, 1.0, u))
			lift = 4.0 * u * (1.0 - u) * _jump_h
			cr = (1.0 - smoothstep(0.0, 0.12, u)) * 1.0
		else:
			cr = cos((ju - 0.8) / 0.2 * PI * 0.5) * 0.85
	# --- torso: breathing, weight shift, scared hunch, walk counter-rotation, nods on speech
	_pose_bone("Hips", _q(F, sway * 1.4) * _q(U, sin(ph) * (4.0 + 4.0 * _run) * w) * _q(R, -5.0 * _run * w - 14.0 * cr + 6.0 * air))
	var rn := _run
	_pose_bone("Spine", _q(R, -br * 0.7 - s * 4.0 - 9.0 * rn - 12.0 * cr + 5.0 * air) * _q(U, -sin(ph) * (2.5 + 3.0 * rn) * w))
	_pose_bone("Chest", _q(R, -br * 1.4 - s * 5.0 - 4.0 * rn) * _q(F, -sway * 0.8))
	_pose_bone("UpperChest", _q(R, -br * 0.8 - s * 3.0) * _q(U, -sin(ph) * 3.0 * w))
	# --- head / neck: look-at + nods + tilt
	var nod: float = _gest["nod"] * 4.0 + sin(t * 2.3) * 1.5 * minf(_talk_left, 1.0) - _pond * (9.0 + sin(t * 0.5) * 3.0)
	_pose_bone("Neck", _q(U, rad_to_deg(_look.x) * 0.4) * _q(R, rad_to_deg(_look.y) * 0.4 + s * 6.0))
	_pose_bone("Head", _q(U, rad_to_deg(_look.x) * 0.6) * _q(R, rad_to_deg(_look.y) * 0.6 + nod - s * 4.0) * _q(F, _gest["tilt"] * 4.0))
	# --- shoulders: scared = drawn up
	for side in ["Left", "Right"]:
		var out := -1.0 if side == "Left" else 1.0
		_pose_bone(side + "Shoulder", _q(F, -out * s * 7.0))
	# --- arms: idle sway, walk swing, talking gestures, scared = drawn in front
	for side in ["Left", "Right"]:
		var out := -1.0 if side == "Left" else 1.0
		var k := "l" if side == "Left" else "r"
		var opp := -1.0 if side == "Left" else 1.0
		var swing := sin(ph) * opp * (22.0 + 44.0 * _run) * w
		var idle := sin(t * 0.9 + out) * 1.5 * (1.0 - w)
		var g_up: float = _gest[k + "a"] * 28.0
		var g_fore: float = _gest[k + "f"] * 55.0
		var pu := _pond * (62.0 if side == "Right" else 28.0)          # the chin hand: upper arm forward / up; the other arm folded across
		var pl := _pond * (128.0 if side == "Right" else 100.0)
		_pose_bone(side + "UpperArm", _q(R, swing + idle + g_up + s * 14.0 - 40.0 * cr + 125.0 * air + pu) * _q(F, -out * (g_up * 0.25 + s * 4.0 + _pond * (-8.0 if side == "Right" else 14.0))))
		_pose_bone(side + "LowerArm", _q(R, g_fore + s * 34.0 + maxf(swing, 0.0) * 0.6 + 4.0 * w + 88.0 * _run * w + 25.0 * air - 10.0 * cr + pl))
	# --- legs: walk cycle (thigh swing, knee bend on the back swing)
	for side in ["Left", "Right"]:
		var sg := 1.0 if side == "Left" else -1.0
		var c := sin(ph) * sg
		var sit_out := (-1.0 if side == "Left" else 1.0) * 6.0 * _sit          # knees slightly apart
		_pose_bone(side + "UpperLeg", _q(R, c * (24.0 + 22.0 * _run) * w + maxf(c, 0.0) * 16.0 * _run * w + 48.0 * cr + (46.0 if side == "Left" else 22.0) * air + s * 2.0 + SIT_THIGH * _sit) * _q(F, sit_out))
		_pose_bone(side + "LowerLeg", _q(R, -maxf(-cos(ph) * sg, 0.0) * (38.0 + 60.0 * _run) * w - 80.0 * cr - 70.0 * air - maxf(c, 0.0) * 8.0 * w - s * 3.0 - SIT_KNEE * _sit))
		_pose_bone(side + "Foot", _q(R, -c * 10.0 * w + 12.0 * cr + 18.0 * air))
	# fingers: relaxed in a loose curl while moving (more at a run), open for the raised hand of a reaction
	var curl := _gw * (0.25 + 0.30 * _run) * (1.0 - _sit) * (1.0 - _react_w)
	if curl > 0.001:
		for side in _finger_axis:
			var ax: Vector3 = _finger_axis[side]
			for f in ["Index", "Middle", "Ring", "Little"]:
				_pose_bone(side + f + "Proximal", Quaternion(ax, deg_to_rad(40.0 * curl)))
				_pose_bone(side + f + "Intermediate", Quaternion(ax, deg_to_rad(55.0 * curl)))
				_pose_bone(side + f + "Distal", Quaternion(ax, deg_to_rad(30.0 * curl)))
	# a small bounce while walking (on the skeleton node, not the character root); seated: pelvis down to the seat
	if _hip_h < 0.0:
		var hi := bone("Hips")
		_hip_h = (skel.get_bone_global_rest(hi).origin * skel.global_transform.basis.get_scale()).y if hi >= 0 else 0.95
	skel.position.y = absf(sin(ph)) * (0.025 + 0.06 * _run) * w - 0.03 * _run * w + lift - 0.16 * cr - maxf(_hip_h - seat_y - 0.06, 0.0) * _sit
	if _gait_on > 0.0:
		skel.position.y = lerpf(skel.position.y, float(_gait["_y"]), _gait_on)


# ------------------------------------------------------------------ footsteps (the same recordings as the player's)
const NPC_WALK_STEPS := preload("res://game/audio/the_veil_walk_footsteps.wav")
const NPC_RUN_STEPS := preload("res://game/audio/the_veil_run_footsteps.wav")
var _steps_t := 0.0
var _walk_sfx: AudioStreamPlayer3D
var _run_sfx: AudioStreamPlayer3D


## Walking: the walk recording, running: the run recording (never both), from where the NPC is, quieter than the
## player's own, at a pace matched to their speed; silent when they stop or are hidden.
func _npc_steps(delta: float) -> void:
	_steps_t -= delta
	var moving: bool = _steps_t > 0.0 and root != null and root.is_visible_in_tree()
	if _walk_sfx == null:
		if not moving or root == null:
			return
		_walk_sfx = AudioStreamPlayer3D.new()
		_walk_sfx.stream = NPC_WALK_STEPS
		_run_sfx = AudioStreamPlayer3D.new()
		_run_sfx.stream = NPC_RUN_STEPS
		for a in [_walk_sfx, _run_sfx]:
			a.unit_size = 4.0
			a.max_distance = 30.0
			root.add_child(a)
			a.position = Vector3(0, 0.1, 0)
			a.finished.connect(a.play)                    # loop the recording
	var running: bool = moving and _run > 0.5
	var walking: bool = moving and not running
	_walk_sfx.volume_db = -14.0
	_run_sfx.volume_db = -11.0
	_walk_sfx.pitch_scale = clampf(_speed / 2.4, 0.6, 1.3)
	_run_sfx.pitch_scale = clampf(_speed / 4.3, 0.8, 1.25)
	for pair in [[_walk_sfx, walking], [_run_sfx, running]]:
		var a: AudioStreamPlayer3D = pair[0]
		if pair[1] and not a.playing:
			a.play(randf() * 4.0)
		elif not pair[1] and a.playing:
			a.stop()
