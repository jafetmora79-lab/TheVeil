extends Node
class_name VeilHoundAI
## THE VEIL - Hound stealth behaviour (first used in Chapter 6). Child of a Pack 07 CRT_Hound (CharacterBody3D):
## moves the body with move_and_slide, so walls, fences and cars stop it like they stop the player.
##   PATROL     walks between patrol points
##   SUSPICIOUS heard the player / glimpsed them: stops, turns, walks to the noise
##   CHASE      sure of the player: runs at them (a little slower than the player's sprint), bites in reach
##   SEARCH     lost sight: sniffs around the last known position, then gives up
##   RETURN     walks back to its patrol (also when the player leaves its leash radius)
## Detection: sight cone + line-of-sight ray (crouching shortens the range, the fog limits it), hearing from the
## player's movement (sprint loud, walk quiet, crouch nearly silent). Awareness builds up before a chase, so the
## player gets a moment to back off. Bites knock the player back and have a cooldown; there is no instant kill.

signal noticed        # first switch to CHASE
signal lost           # CHASE / SEARCH ended without reaching the player
signal bit(damage: float)

const GRAVITY := 18.0

var body: CharacterBody3D
var player: CharacterBody3D
var anim: AnimationPlayer
var patrol: Array = []              # world points
var home := Vector3.ZERO
var leash := 34.0
var walk_speed := 1.25
var chase_speed := 3.9              # player sprint is 4.3, walk ~2.6
var sight_range := 15.0
var sight_range_crouch := 6.5
var sight_half_angle := 62.0
var bite_damage := 20.0
var bite_cooldown := 1.8
var state := "PATROL"
var awareness := 0.0                # 0..1, CHASE at 1
var chases := 0
var _pi := 0
var _target := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _unseen := 0.0
var _search_t := 0.0
var _bite_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _anim_cur := ""
var _patrol_stuck := 0.0
var _patrol_ref := Vector3.ZERO


func setup(p_body: CharacterBody3D, p_player: CharacterBody3D, points: Array) -> void:
	body = p_body
	player = p_player
	patrol = points
	home = points[0] if points.size() > 0 else body.global_position
	anim = body.get_node_or_null(String(body.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	body.collision_layer = 1
	body.collision_mask = 1
	# the scene's long body box + forward head box swing into fences when the Hound turns and wedge it there;
	# an upright capsule (rotation-invariant) keeps the same footprint for walls without ever turning into them
	for n in ["BodyShape", "HeadShape"]:
		var cs := body.get_node_or_null(n) as CollisionShape3D
		if cs:
			cs.disabled = true
	var cap := CollisionShape3D.new()
	cap.name = "AIShape"
	var c := CapsuleShape3D.new()
	c.radius = 0.36
	c.height = 0.95
	cap.shape = c
	cap.position = Vector3(0, 0.78, 0.3)
	body.add_child(cap)
	body.floor_snap_length = 0.4
	_last_pos = body.global_position
	_target = patrol[0] if patrol.size() > 0 else home
	_play("Walk")


func reset_to_patrol(far_from: Vector3) -> void:
	# loads / checkpoints: back on patrol, unaware, at the nearest patrol point that is still a safe distance
	# (>= 12 m) from the player, so the encounter goes on instead of counting as escaped
	var best := Vector3.INF
	var far := home
	for p in patrol:
		var d := (p as Vector3).distance_to(far_from)
		if d > far.distance_to(far_from):
			far = p
		if d >= 12.0 and (best == Vector3.INF or d < best.distance_to(far_from)):
			best = p
	if best == Vector3.INF:
		best = far
	body.global_position = best
	body.velocity = Vector3.ZERO
	_snap_floor()
	state = "PATROL"
	awareness = 0.0
	_unseen = 0.0


func _physics_process(delta: float) -> void:
	if body == null or player == null or not body.is_inside_tree():
		return
	_bite_t = maxf(_bite_t - delta, 0.0)
	var to_p := player.global_position - body.global_position
	var dist := Vector2(to_p.x, to_p.z).length()
	var sees := _can_see(dist)
	var hears := _can_hear(dist)
	var far_home := Vector2(body.global_position.x - home.x, body.global_position.z - home.z).length() > leash
	match state:
		"PATROL", "RETURN":
			if far_home:
				sees = false                          # beyond its leash it ignores the player and heads home
				hears = false
			if sees:
				awareness = minf(awareness + delta * lerpf(1.6, 0.45, clampf(dist / sight_range, 0.0, 1.0)), 1.0)
				_suspect(player.global_position)
			elif hears:
				_suspect(player.global_position)
			else:
				awareness = maxf(awareness - delta * 0.25, 0.0)
				if state == "RETURN" and _flat(body.global_position, home) < 1.5:
					state = "PATROL"
			if state == "PATROL" or state == "RETURN":
				var goal: Vector3 = home if state == "RETURN" else _target
				# real progress check: under 0.5 m in 3 s means the patrol point is not reachable from here
				_patrol_stuck += delta
				if _patrol_stuck > 3.0:
					var blocked := _flat(body.global_position, _patrol_ref) < 0.5
					_patrol_ref = body.global_position
					_patrol_stuck = 0.0
					if blocked and state == "PATROL" and patrol.size() > 0:
						_pi = (_pi + 1) % patrol.size()
						_target = patrol[_pi]
				if state == "PATROL" and _flat(body.global_position, _target) < 1.3 and patrol.size() > 0:
					_pi = (_pi + 1) % patrol.size()
					_target = patrol[_pi]
				_move_to(goal, walk_speed, delta, "Walk")
		"SUSPICIOUS":
			if far_home:
				state = "RETURN"                      # never investigates beyond its leash
				awareness = 0.0
				return
			if sees:
				awareness = minf(awareness + delta * lerpf(2.2, 0.7, clampf(dist / sight_range, 0.0, 1.0)), 1.0)
				_last_seen = player.global_position
			elif hears:
				_last_seen = player.global_position
				awareness = minf(awareness + delta * 0.35, 1.0)
			else:
				awareness = maxf(awareness - delta * 0.18, 0.0)
			if awareness >= 1.0:
				_start_chase()
			elif awareness <= 0.0:
				state = "RETURN"
			elif _flat(body.global_position, _last_seen) > 1.2:
				_move_to(_last_seen, walk_speed * 1.4, delta, "Walk")
			else:
				_idle(delta, "Alert")
		"CHASE":
			if sees:
				_last_seen = player.global_position
				_unseen = 0.0
			else:
				_unseen += delta
			# reach is measured from the jaws: the body origin sits ~1.2 m behind the head (CRT_Hound HeadShape)
			var jaws := body.global_position + body.global_transform.basis.z.normalized() * 1.15
			var jaw_d := Vector2(player.global_position.x - jaws.x, player.global_position.z - jaws.z).length()
			if (jaw_d < 0.95 or dist < 1.9) and sees:
				_idle(delta, "Attack_Bite")
				_face(to_p)
				if _bite_t <= 0.0:
					_bite_t = bite_cooldown
					bit.emit(bite_damage)
					if player.has_method("damage"):
						# never a killing bite: the chapter's checkpoint takes over at low health
						var hp = player.get("health")
						var dmg := bite_damage if hp == null else minf(bite_damage, maxf(float(hp) - 5.0, 0.0))
						player.damage(dmg, body.global_position)
			elif _unseen > 3.2 or dist > 24.0 or far_home:
				state = "SEARCH"
				_search_t = 4.5
			else:
				_move_to(_last_seen if not sees else player.global_position, chase_speed, delta, "Run")
		"SEARCH":
			_search_t -= delta
			if sees and dist < sight_range * 0.8 and not far_home:
				_start_chase()
			elif _search_t <= 0.0 or far_home:          # past its leash it gives up at once: no chase across the map
				state = "RETURN"
				awareness = 0.0
				lost.emit()
			elif _flat(body.global_position, _last_seen) > 1.0:
				_move_to(_last_seen, walk_speed * 1.6, delta, "Walk")
			else:
				_idle(delta, "Alert")


func _suspect(at: Vector3) -> void:
	_last_seen = at
	if state != "SUSPICIOUS":
		state = "SUSPICIOUS"
	if awareness >= 1.0:
		_start_chase()


func _start_chase() -> void:
	if state == "CHASE":
		return
	state = "CHASE"
	_unseen = 0.0
	awareness = 1.0
	chases += 1
	if chases == 1:
		noticed.emit()


func _can_see(dist: float) -> bool:
	var crouch: bool = player.get("crouching") == true
	var rng := sight_range_crouch if crouch else sight_range
	if dist > rng:
		return false
	var fwd := body.global_transform.basis.z         # the model faces +Z
	var to := (player.global_position - body.global_position) * Vector3(1, 0, 1)
	if dist > 2.5 and rad_to_deg(Vector3(fwd.x, 0, fwd.z).normalized().angle_to(to.normalized())) > sight_half_angle:
		return false
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(body.global_position + Vector3(0, 0.9, 0), player.global_position + Vector3(0, 0.6, 0), 1)
	q.exclude = [body.get_rid(), player.get_rid()]
	return space.intersect_ray(q).is_empty()


func _can_hear(dist: float) -> bool:
	var v := Vector2(player.velocity.x, player.velocity.z).length()
	if v < 0.3:
		return false
	var crouch: bool = player.get("crouching") == true
	var r := 1.8 if crouch else (11.0 if v > 3.6 else 4.5)
	return dist < r


func _move_to(goal: Vector3, speed: float, delta: float, clip: String) -> void:
	var d := (goal - body.global_position) * Vector3(1, 0, 1)
	var v := Vector3.ZERO
	if d.length() > 0.05:
		v = d.normalized() * speed
		_face(d)
	body.velocity = Vector3(v.x, 0.0, v.z)
	body.move_and_slide()
	_snap_floor()
	_play(clip, speed)
	# wedged on a corner: sidestep along the wall instead of grinding into it
	var moved := _flat(body.global_position, _last_pos)
	_last_pos = body.global_position
	_stuck_t = _stuck_t + delta if moved < speed * delta * 0.25 and speed > 0.1 else 0.0
	if _stuck_t > 0.6:
		var side := d.normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		body.velocity = side * speed
		body.move_and_slide()
		_stuck_t = 0.0


func _idle(delta: float, clip: String) -> void:
	body.velocity = Vector3.ZERO
	_snap_floor()
	_play(clip)


## The Hound's collision boxes start ~0.4 m above its paws (CRT_Hound BodyShape), so gravity would sink the legs
## into the ground: instead the paws are kept on the floor under it (curbs, yards, kerbs) with a ray.
func _snap_floor() -> void:
	var p := body.global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, -2.0, 0), 1)
	q.exclude = [body.get_rid(), player.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		body.global_position.y = move_toward(p.y, (hit["position"] as Vector3).y, 0.08)


func _face(d: Vector3) -> void:
	d.y = 0.0
	if d.length() > 0.01:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(d.x, d.z), 0.18)


func _play(clip: String, speed := 0.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if _anim_cur != clip:
		anim.play(clip, 0.2)
		_anim_cur = clip
	if clip == "Walk":
		anim.speed_scale = speed / maxf(float(body.get_meta("walk_speed_mps", 0.9)) * body.scale.x, 0.1)
	elif clip == "Run":
		anim.speed_scale = speed / maxf(float(body.get_meta("run_speed_mps", 5.0)) * body.scale.x, 0.1)
	else:
		anim.speed_scale = 1.0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
