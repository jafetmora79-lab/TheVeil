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
	_measure_frame()
	_build_rest()


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
var seat_y := 0.48
var _sit := 0.0
var _hip_h := -1.0
const SIT_THIGH := 86.0
const SIT_KNEE := 88.0


func set_seated(on: bool, seat_height := 0.48) -> void:
	seated = on
	seat_y = seat_height
	if on:
		walk_to([])


func set_mood(m: String) -> void:
	mood = m


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
	if skel == null or not root.is_visible_in_tree():
		return
	_t += delta
	_talk_left = maxf(_talk_left - delta, 0.0)
	_scare = move_toward(_scare, 1.0 if mood == "scared" else 0.0, delta * 0.8)
	if not physical:
		_update_walk(delta)
	_update_turn(delta)
	_update_gestures(delta)
	_update_look(delta)
	_sit = move_toward(_sit, 1.0 if seated else 0.0, delta * 1.7)
	_pose()


func _physics_process(delta: float) -> void:
	if physical and skel != null and root.is_visible_in_tree():
		_update_walk(delta)


func _update_walk(delta: float) -> void:
	if _path.is_empty():
		_walk = move_toward(_walk, 0.0, delta * 3.0)
		return
	var target: Vector3 = _path[0]
	var here := root.position
	var d := target - here
	d.y = 0.0
	if d.length() < 0.08:
		_path.pop_front()
		if _path.is_empty():
			arrived.emit()
		return
	_walk = move_toward(_walk, 1.0, delta * 3.0)
	var step := minf(walk_speed * _walk * delta, d.length())
	var body := root as VeilSurvivorBody if physical else null
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
			if body.is_on_wall():
				var probe := motion.normalized() * minf(d.length(), VeilSurvivorBody.RADIUS + 0.06)
				body.step_target = VeilSurvivorBody.step_landing(body, probe, 0.35)
	else:
		root.position += d.normalized() * step
	var moved := before.distance_to(root.global_position)
	if moved < 0.001:
		_walk = move_toward(_walk, 0.0, delta * 3.0)
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), minf(delta * 6.0, 1.0))
	_run = move_toward(_run, clampf((_speed - 2.4) / 1.8, 0.0, 1.0), delta * 2.5)
	_phase += moved / lerpf(0.62, 0.98, _run) * PI   # one stride ~1.24 m walking, ~1.96 m running
	var si := int(_phase / PI)
	if si != _step_i:                                # a footstep on each foot strike (quiet)
		_step_i = si
		if moved > 0.0005:
			Sfx.play("step", root.global_position, lerpf(-16.0, -11.0, _run), randf_range(0.9, 1.1))
	var parent := root.get_parent_node_3d()
	_turn_goal = (parent.global_transform.basis * d.normalized()) if parent else d.normalized()


func _update_turn(delta: float) -> void:
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


func _update_gestures(delta: float) -> void:
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
	var want := Vector2.ZERO
	var tp = _target_pos()
	if tp != null and bone("Head") >= 0:
		var head_w := skel.global_transform * _gp("Head").origin
		var to: Vector3 = tp - head_w
		if to.length() < look_range or look_target != null:
			var local := skel.global_transform.basis.inverse() * to
			var yaw := atan2(-local.dot(R), local.dot(F))
			var pitch := atan2(local.dot(U), Vector2(local.dot(F), local.dot(R)).length())
			if absf(yaw) < deg_to_rad(110.0):
				want = Vector2(clampf(yaw, -1.2, 1.2), clampf(pitch, -0.5, max_pitch))
	if want == Vector2.ZERO:
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			_glance_timer = randf_range(2.0, 5.0)
			_glance = Vector2(randf_range(-0.5, 0.5), randf_range(-0.1, 0.12)) * (1.6 if mood == "scared" else 1.0)
		want = _glance
	_look = _look.lerp(want, minf(delta * 4.0, 1.0))


func _q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))


## Set bone `n` = rest, rotated by skeleton-space rotation q (relative to the parent's rest frame).
func _pose_bone(n: String, q: Quaternion) -> void:
	var i := bone(n)
	if i < 0:
		return
	var pb: Basis = _prest[i]
	skel.set_bone_pose_rotation(i, (_pinv[i] * Basis(q) * pb * _rest[i]).get_rotation_quaternion())


func _pose() -> void:
	var t := _t + _seed
	var s := _scare
	var breath_rate := lerpf(0.26, 0.55, s)            # breaths per second
	var br := sin(t * TAU * breath_rate)
	var sway := sin(t * 0.37) * (1.0 - _walk)
	var w := _walk
	var ph := _phase
	# --- torso: breathing, weight shift, scared hunch, walk counter-rotation, nods on speech
	_pose_bone("Hips", _q(F, sway * 1.4) * _q(U, sin(ph) * 4.0 * w))
	var rn := _run
	_pose_bone("Spine", _q(R, -br * 0.7 - s * 4.0 - 9.0 * rn) * _q(U, -sin(ph) * (2.5 + 3.0 * rn) * w))
	_pose_bone("Chest", _q(R, -br * 1.4 - s * 5.0 - 4.0 * rn) * _q(F, -sway * 0.8))
	_pose_bone("UpperChest", _q(R, -br * 0.8 - s * 3.0) * _q(U, -sin(ph) * 3.0 * w))
	# --- head / neck: look-at + nods + tilt
	var nod: float = _gest["nod"] * 4.0 + sin(t * 2.3) * 1.5 * minf(_talk_left, 1.0)
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
		var swing := sin(ph) * opp * (22.0 + 26.0 * _run) * w
		var idle := sin(t * 0.9 + out) * 1.5 * (1.0 - w)
		var g_up: float = _gest[k + "a"] * 28.0
		var g_fore: float = _gest[k + "f"] * 55.0
		_pose_bone(side + "UpperArm", _q(R, swing + idle + g_up + s * 14.0) * _q(F, -out * (g_up * 0.25 + s * 4.0)))
		_pose_bone(side + "LowerArm", _q(R, g_fore + s * 34.0 + maxf(swing, 0.0) * 0.6 + 4.0 * w + 72.0 * _run * w))
	# --- legs: walk cycle (thigh swing, knee bend on the back swing)
	for side in ["Left", "Right"]:
		var sg := 1.0 if side == "Left" else -1.0
		var c := sin(ph) * sg
		var sit_out := (-1.0 if side == "Left" else 1.0) * 6.0 * _sit          # knees slightly apart
		_pose_bone(side + "UpperLeg", _q(R, c * (24.0 + 14.0 * _run) * w + maxf(c, 0.0) * 12.0 * _run * w + s * 2.0 + SIT_THIGH * _sit) * _q(F, sit_out))
		_pose_bone(side + "LowerLeg", _q(R, -maxf(-cos(ph) * sg, 0.0) * (38.0 + 50.0 * _run) * w - maxf(c, 0.0) * 8.0 * w - s * 3.0 - SIT_KNEE * _sit))
		_pose_bone(side + "Foot", _q(R, -c * 10.0 * w))
	# a small bounce while walking (on the skeleton node, not the character root); seated: pelvis down to the seat
	if _hip_h < 0.0:
		var hi := bone("Hips")
		_hip_h = (skel.get_bone_global_rest(hi).origin * skel.global_transform.basis.get_scale()).y if hi >= 0 else 0.95
	skel.position.y = absf(sin(ph)) * (0.025 + 0.035 * _run) * w - 0.03 * _run * w - maxf(_hip_h - seat_y - 0.06, 0.0) * _sit
