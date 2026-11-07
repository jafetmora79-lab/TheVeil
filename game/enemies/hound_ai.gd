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
const VOICE := preload("res://game/enemies/creature_voice.gd")

var body: CharacterBody3D
var player: CharacterBody3D
var anim: AnimationPlayer
var patrol: Array = []              # world points
var home := Vector3.ZERO
var leash := 34.0
var walk_speed := 1.4
var chase_speed := 4.1              # player sprint is 4.3, walk ~2.6 (still outrunnable)
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
## Reuse for the other ground creatures (Skitter, Shellcrawler): their clip names, each clip's native stride speed,
## where the "jaws" sit, and a body turned sideways to its travel (the Shellcrawler crawls sideways).
var clip_map := {}
var native := {}
var jaw_offset := 1.15
var bite_range := 1.9
var face_offset := 0.0
var turn_rate := 0.18               ## per-frame turn blend (heavier creatures turn slower, never snap)
var burst := false                  ## chase in lunges (short fast bursts, then a heavy shuffle): the Shellcrawler
var _burst_t := 0.0
## A struggle may take an attack over (game/encounters/struggle.gd): return true from it to replace the bite.
var on_attack: Callable = Callable()
var _world: Node = null
var sound_kind := "hound"           ## "hound", "skitter", "crab": its sounds and its chase music
var voice: Node
const CLOSE := 4.5                  ## metres: a sideways crawler faces the player from here in
var body_half_width := 0.4
var clip_cap := 2.2                 ## fastest a stride clip may run (a heavy creature's short stride needs more)
var steer_around := false           ## look ahead and turn before reaching a wall (the wide Shellcrawler)
var _detour_t := 0.0
var _detour_dir := Vector3.ZERO
var _steer_t := 0.0
var _steer_dir := Vector3.ZERO
var hold := false                   ## a struggle holds the creature in place (its pose is driven from outside)
var _recover_t := 0.0
var _recover_len := 0.0
var _recover_mode := ""


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
	for n in ["BodyShape", "HeadShape", "ShellShape", "LegSpan", "ArmsShape"]:
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
	voice = VOICE.new()
	voice.name = "Voice"
	add_child(voice)
	voice.setup(self, sound_kind)
	add_to_group("veil_hunter")


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
	if hold:
		body.velocity = Vector3.ZERO
		return
	voice.tick(delta, state, Vector2(body.velocity.x, body.velocity.z).length() > 0.2)
	_bite_t = maxf(_bite_t - delta, 0.0)
	var to_p := _tp() - body.global_position
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
				_suspect(_tp())
			elif hears:
				_suspect(_tp())
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
				_last_seen = _tp()
			elif hears:
				_last_seen = _tp()
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
				_last_seen = _tp()
				_unseen = 0.0
			else:
				_unseen += delta
			# reach is measured from the jaws: the body origin sits ~1.2 m behind the head (CRT_Hound HeadShape)
			var jaws := body.global_position + body.global_transform.basis.z.normalized() * jaw_offset
			var jaw_d := Vector2(_tp().x - jaws.x, _tp().z - jaws.z).length()
			if (jaw_d < 0.95 or dist < bite_range) and sees:
				_idle(delta, "Attack_Bite")
				_face(to_p)
				if _bite_t <= 0.0:
					_bite_t = bite_cooldown
					var car := _car()
					if car:
						if absf(car.speed) < 7.0:
							car.monster_hit(bite_damage * 0.0025)     # at the car, not the driver
						return
					if on_attack.is_valid() and bool(on_attack.call(self)):
						return                        # a struggle took this attack over
					voice.bite()
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
				var sp := chase_speed
				if burst:
					var lap := _burst_t
					_burst_t = fmod(_burst_t + delta, 2.2)
					if _burst_t < lap:
						voice.burst()                    # the next lunge
					sp *= 1.35 if _burst_t < 0.9 else 0.55
				_move_to(_last_seen if not sees else _tp(), sp, delta, "Run")
		"RECOVER":
			# after a struggle: "back" = stagger, shake it off, then hunt again; "flee" = a fast zigzag away, then gone
			_recover_t -= delta
			var away := (body.global_position - _tp()) * Vector3(1, 0, 1)
			away = away.normalized() if away.length() > 0.01 else -body.global_transform.basis.z
			if _recover_mode == "flee":
				var zig := away.cross(Vector3.UP) * sin(_recover_t * 7.0) * 0.9
				_move_to(body.global_position + (away + zig) * 3.0, chase_speed * 1.15, delta, "Run")
				if _recover_t <= 0.0:
					state = "RETURN"
					awareness = 0.0
			else:
				# shakes it off where it stands, backs away still facing the player, gathers itself, comes again
				var t := 1.0 - _recover_t / maxf(_recover_len, 0.01)
				if t < 0.3:
					_idle(delta, "Alert")
					_face(-away)
					if sound_kind == "hound":
						body.rotation.y += sin(Time.get_ticks_msec() * 0.03) * 0.09      # the head shake
				elif t < 0.72:
					_back_off(away, walk_speed * 0.8)
				else:
					_idle(delta, "Alert")
					_face(-away)
				if _recover_t <= 0.0:
					voice.resume()
					state = "SUSPICIOUS"
					_last_seen = _tp()
					awareness = 0.99
					_start_chase()
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


## After a struggle: give the player a moment (mode "back": recover then chase; "flee": run off and leave).
func recoil(seconds: float, mode: String) -> void:
	hold = false
	_anim_cur = ""
	state = "RECOVER"
	_recover_t = seconds
	_recover_len = seconds
	_recover_mode = mode
	_bite_t = maxf(_bite_t, seconds + bite_cooldown)


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


## The sedan while the player is driving it (the hidden player stays where they got in), else null.
func _car() -> Node3D:
	if _world == null or not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("veil_world")
	return _world.sedan if _world and _world.in_car else null


## Where the player really is.
func _tp() -> Vector3:
	var car := _car()
	return car.global_position if car else player.global_position


func _can_see(dist: float) -> bool:
	var crouch: bool = player.get("crouching") == true
	var rng := sight_range_crouch if crouch else sight_range
	if dist > rng:
		return false
	var fwd := body.global_transform.basis.z         # the model faces +Z
	var to := (_tp() - body.global_position) * Vector3(1, 0, 1)
	if dist > 2.5 and rad_to_deg(Vector3(fwd.x, 0, fwd.z).normalized().angle_to(to.normalized())) > sight_half_angle:
		return false
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(body.global_position + Vector3(0, 0.9, 0), _tp() + Vector3(0, 0.6, 0), 1)
	q.exclude = [body.get_rid(), player.get_rid()]
	var car := _car()
	if car:
		q.exclude = [body.get_rid(), player.get_rid(), car.get_rid()]
	return space.intersect_ray(q).is_empty()


func _can_hear(dist: float) -> bool:
	if _car():
		return dist < 14.0                              # an engine carries
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
		var dir := d.normalized()
		if _detour_t > 0.0:
			_detour_t -= delta
			dir = _detour_dir
		elif steer_around:
			dir = _steer(dir, delta)
		v = dir * speed
		_face(dir)
	body.velocity = Vector3(v.x, 0.0, v.z)
	body.move_and_slide()
	_snap_floor()
	_play("Forward" if clip_map.has("Forward") and _flat(body.global_position, _tp()) < CLOSE else clip, speed)
	# wedged on a corner: commit to a way round for a moment instead of grinding into it
	var moved := _flat(body.global_position, _last_pos)
	_last_pos = body.global_position
	_stuck_t = _stuck_t + delta if moved < speed * delta * 0.25 and speed > 0.1 else 0.0
	if _stuck_t > 0.5 and d.length() > 0.05:
		_detour_dir = _free_dir(d.normalized(), 2.2, [60.0, -60.0, 100.0, -100.0, 145.0, -145.0])
		_detour_t = 1.2
		_stuck_t = 0.0


## After a struggle: steps backwards, still facing the player, the walk clip run in reverse.
func _back_off(away: Vector3, speed: float) -> void:
	body.velocity = away * speed
	body.move_and_slide()
	_snap_floor()
	_face(-away)
	_play("Forward" if clip_map.has("Forward") else "Walk", speed)
	if anim:
		anim.speed_scale = -absf(anim.speed_scale)


## A wall ahead (centre and both flanks of the body)?
func _blocked(dir: Vector3, length: float) -> bool:
	var space := body.get_world_3d().direct_space_state
	var side := dir.cross(Vector3.UP) * body_half_width
	var ex: Array[RID] = [body.get_rid(), player.get_rid()]
	for off in [Vector3.ZERO, side, -side]:
		var from: Vector3 = body.global_position + Vector3(0, 0.6, 0) + off
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * length, 1, ex)).is_empty():
			return true
	return false


## The first clear heading from dir among the given turns (degrees); straight back if there is none.
func _free_dir(dir: Vector3, length: float, turns: Array) -> Vector3:
	for a in turns:
		var t := dir.rotated(Vector3.UP, deg_to_rad(float(a)))
		if not _blocked(t, length):
			return t
	return -dir


## Looks a body length ahead a few times a second and bends the course round what is there.
func _steer(dir: Vector3, delta: float) -> Vector3:
	_steer_t -= delta
	if _steer_t <= 0.0:
		_steer_t = 0.15
		_steer_dir = dir if not _blocked(dir, 1.9) else _free_dir(dir, 1.9, [35.0, -35.0, 70.0, -70.0, 105.0, -105.0])
	return _steer_dir if _steer_dir != Vector3.ZERO else dir


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
		# (a sideways crawler turns its claws to the player for the last few metres, and to attack)
		var off := 0.0 if _flat(body.global_position, _tp()) < CLOSE else face_offset
		body.rotation.y = lerp_angle(body.rotation.y, atan2(d.x, d.z) + off, turn_rate)


func _play(clip: String, speed := 0.0) -> void:
	var real := String(clip_map.get(clip, clip))
	if anim == null or not anim.has_animation(real):
		return
	if _anim_cur != real:
		anim.play(real, 0.2)
		_anim_cur = real
	if native.has(real):
		anim.speed_scale = clampf(speed / float(native[real]), 0.5, clip_cap) if speed > 0.05 else 1.0
	elif clip == "Walk":
		anim.speed_scale = speed / maxf(float(body.get_meta("walk_speed_mps", 0.9)) * body.scale.x, 0.1)
	elif clip == "Run":
		anim.speed_scale = speed / maxf(float(body.get_meta("run_speed_mps", 5.0)) * body.scale.x, 0.1)
	else:
		anim.speed_scale = 1.0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
