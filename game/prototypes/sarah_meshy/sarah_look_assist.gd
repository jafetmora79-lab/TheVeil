extends Node
class_name VeilSarahLookAssist
## THE VEIL - Sarah-only add-on for the clerk test: makes her turn toward the player the way a person turns their head.
## The game's NpcAnimator only turns the head (+-69 deg) and moves the body when the player is within 2 m or she talks.
## This node runs after it each frame and (1) turns her body gently toward the player once they are >30 deg off her front
## (within look_range), (2) adds a torso twist so the turn starts in the shoulders, (3) extends the head turn to ~100 deg.
## Nothing in game/npc is changed.

var animator: Node
var root: Node3D
var enabled := true
var body_threshold := deg_to_rad(30.0)
var _twist := 0.0                          ## smoothed extra yaw shared by chest / neck / head (radians)


func setup(a: Node, r: Node3D) -> void:
	animator = a
	root = r
	process_priority = 100                 # after the animator has posed her


func _target() -> Variant:
	if animator.look_target and is_instance_valid(animator.look_target):
		return animator.look_target.global_position
	var cam := root.get_viewport().get_camera_3d()
	return cam.global_position if cam else null


## yaw of the player relative to her body front, radians (positive = toward her left in the animator's convention)
func raw_yaw() -> float:
	var tp = _target()
	if tp == null:
		return 0.0
	var to: Vector3 = tp - root.global_position
	to.y = 0.0
	if to.length() > animator.look_range or to.length() < 0.2:
		return 0.0
	var f: Vector3 = animator.world_forward()
	f.y = 0.0
	return -f.normalized().signed_angle_to(to.normalized(), Vector3.UP) * -1.0


func _twist_bone(n: String, yaw: float) -> void:
	var i: int = animator.bone(n)
	if i < 0 or absf(yaw) < 0.0001:
		return
	var p: Basis = animator._pinv[i]
	var qe := Quaternion((animator.U as Vector3), yaw)
	var cur: Quaternion = animator.skel.get_bone_pose_rotation(i)
	animator.skel.set_bone_pose_rotation(i, (p * Basis(qe) * p.inverse()).get_rotation_quaternion() * cur)


func _process(delta: float) -> void:
	if not enabled or animator == null or animator.skel == null or not root.is_visible_in_tree():
		return
	var tp = _target()
	var yaw := 0.0
	if tp != null:
		var to: Vector3 = tp - root.global_position
		to.y = 0.0
		if to.length() < animator.look_range and to.length() > 0.2 and animator._path.is_empty() and not animator.hold_facing:
			var ang: float = animator.world_forward().signed_angle_to(to.normalized(), Vector3.UP)   # + = player to her left (CCW seen from above)
			# the body follows once the player is well off her front, slowly, keeping a part of the turn in the head
			if absf(ang) > body_threshold:
				var over := absf(ang) - body_threshold * 0.7
				root.rotate_y(clampf(ang, -1.0, 1.0) * minf(over * 1.1 * delta, absf(ang)) / maxf(absf(ang), 0.001))
				ang = animator.world_forward().signed_angle_to(to.normalized(), Vector3.UP)
			# animator's own look yaw is clamped to +-1.2; its sign convention is opposite to signed_angle_to
			yaw = -ang
	var animator_yaw: float = animator._look.x
	var extra_total := clampf(yaw, -1.75, 1.75) - clampf(yaw, -1.2, 1.2)               # what the animator could not reach
	var want := extra_total + animator_yaw * 0.0
	_twist = lerpf(_twist, want, minf(delta * 4.0, 1.0))
	# the shoulders lead: a share of the animator's yaw moves into the chest, taken off the head so the gaze stays on target
	var share := animator_yaw * 0.22
	_twist_bone("Chest", share + _twist * 0.3)
	_twist_bone("Neck", _twist * 0.3 - share * 0.35)
	_twist_bone("Head", _twist * 0.4 - share * 0.65)
