extends CharacterBody3D
class_name VeilPlayer
## THE VEIL - first-person player: walk / sprint / crouch, mouse look, head bob, gravity, slopes and ramps
## (Pack 03 stairs and porch steps collide as smooth ramps), raycast interaction.
## Built in code so the scene file stays minimal.

signal prompt_changed(text: String)
signal hold_progress(ratio: float)                 ## 0..1 while the interact key is held on a "hold to use" object (0 = idle)

const WALK := 2.4
const GaitPose = preload("res://game/animation/gait_pose.gd")
const SPRINT := 4.3
const CROUCH := 1.3
const ACCEL := 10.0
const DECEL := 12.0
const GRAVITY := 14.0
const JUMP_SPEED := 4.6                ## about 0.75 m up with this gravity: over a low fence, a kerb, a fallen branch
const JUMP_STAMINA := 6.0
const EYE := 1.62
const EYE_CROUCH := 1.05
const HEIGHT := 1.76
const HEIGHT_CROUCH := 1.2
const RADIUS := 0.28
const REACH := 2.1
const STEP := 0.35
## survival (off during the ordinary opening; switched on when the first supernatural encounter begins)
signal health_changed(value: float, max_value: float)
signal stamina_changed(value: float, max_value: float)
signal hurt(amount: float)
signal died
const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 8.5           ## per second of sprinting (~12 s from full)
const STAMINA_REGEN := 20.0          ## per second, after REGEN_DELAY without sprinting
const REGEN_DELAY := 0.7
const EXHAUSTED_UNTIL := 30.0        ## once empty, no sprinting until stamina is back to this
var survival_active := false
var health := MAX_HEALTH
var stamina := MAX_STAMINA
var _exhausted := false
var _regen_t := 0.0
var _stagger_t := 0.0
var _kick := Vector2.ZERO            ## camera hit reaction (pitch, roll) in radians, decays fast          ## curbs, door sills, porch steps up to this height are climbed automatically

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var shape: CollisionShape3D
var capsule: CapsuleShape3D
var controls_enabled := true
var look_enabled := true
var crouching := false
var force_crouch := false              ## a scene holds the player crouched (a low gap in a wall: review note #75)
var auto_sprint := false                ## a scene walking the player (auto_input) has them run
var _pitch := 0.0
var _bob_t := 0.0
var _eye := EYE
var _focus: Node = null
var _prompt := ""
var _last_step := 0
var _step_smooth := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | VeilSurvivorBody.LAYER            # world, vehicles and survivors
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	floor_constant_speed = true                                 # stairs at walking pace, up and down alike
	capsule = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = HEIGHT / 2.0
	add_child(shape)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 72.0
	camera.near = 0.04
	camera.far = 600.0
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collision_mask = 1 | 8        # world (occludes) + interactables
	ray.collide_with_areas = true
	ray.add_exception(self)
	camera.add_child(ray)


func set_yaw_pitch(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = pitch
	head.rotation.x = pitch


func activate(on: bool) -> void:
	visible = on
	controls_enabled = on
	look_enabled = on
	set_physics_process(on)
	shape.disabled = not on
	camera.current = on
	if not on:
		_set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var s: float = Game.settings["mouse_sensitivity"] * 0.01
		rotation.y -= event.relative.x * s
		_pitch = clampf(_pitch - event.relative.y * s, deg_to_rad(-85), deg_to_rad(85))
		head.rotation.x = _pitch


## Scripted walking for cinematics (controls held): the same movement, collision and head bob as the player's own
## input. (0, -1) = forward at walking pace. Zero = none.
var auto_input := Vector2.ZERO


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	elif auto_input != Vector2.ZERO:
		input = auto_input
	# crouch (stand up only if there is head room)
	var want_crouch := (controls_enabled and Input.is_action_pressed("crouch")) or force_crouch
	if want_crouch != crouching:
		if want_crouch or _can_stand():
			crouching = want_crouch
			capsule.height = HEIGHT_CROUCH if crouching else HEIGHT
			shape.position.y = capsule.height / 2.0
	var sprinting := (controls_enabled and Input.is_action_pressed("sprint") or auto_sprint and auto_input != Vector2.ZERO) \
		and not crouching and input.y < 0.0
	if survival_active and (_exhausted or stamina <= 0.5):
		sprinting = false
	var speed := CROUCH if crouching else (SPRINT if sprinting else WALK)
	if _stagger_t > 0.0:                         # brief stagger after a hit
		_stagger_t -= delta
		speed *= 0.45
	_update_stamina(sprinting and input.length() > 0.1, delta)
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var target := dir * speed
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(target, (ACCEL if target.length() > 0.01 else DECEL) * delta * speed)
	velocity.x = hv.x
	velocity.z = hv.z
	# Space: a jump (on foot, with control, from the ground, standing up; a little stamina when survival is on)
	var jump := controls_enabled and is_on_floor() and not crouching and InputMap.has_action("jump") 		and Input.is_action_just_pressed("jump") and (not survival_active or stamina >= JUMP_STAMINA)
	if jump:
		velocity.y = JUMP_SPEED
		if survival_active:
			stamina = maxf(stamina - JUMP_STAMINA, 0.0)
			_regen_t = REGEN_DELAY
			stamina_changed.emit(stamina, MAX_STAMINA)
	elif is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	if not jump and is_on_floor() and hv.length() > 0.05 and get_floor_normal().y > 0.93:
		_step_up(hv, delta)                      # (flat ground only: stairs are ramps, a lift there only jolts)
	move_and_slide()
	_debug_pushed_back(delta)
	_update_hold(delta)
	_fall_guard(delta)
	# eye height + head bob
	_eye = move_toward(_eye, EYE_CROUCH if crouching else EYE, delta * 3.5)
	var moving := hv.length() > 0.4 and is_on_floor()
	if moving and Game.settings.get("head_bob", true):
		_bob_t += delta * hv.length() * PI / (0.5 * GaitPose.cycle_length(hv.length()))   # one bob per footfall: the gait's step length at this speed
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 6.0)
	if moving and int(_bob_t / PI) != _last_step:
		_last_step = int(_bob_t / PI)
		pass                                        # (footsteps: the recorded walk / run loops below)
	_footsteps(moving and visible and (controls_enabled or auto_input != Vector2.ZERO), sprinting, crouching, hv.length())
	var amp := 0.028 if sprinting else 0.016
	_step_smooth = move_toward(_step_smooth, 0.0, delta * 1.6)
	head.position.y = _eye + sin(_bob_t * 2.0) * amp - _step_smooth
	_kick = _kick.lerp(Vector2.ZERO, minf(delta * 7.0, 1.0))
	head.rotation.x = _pitch + _kick.x
	head.rotation.z = _kick.y
	head.position.x = cos(_bob_t) * amp * 0.6
	_update_focus()


## Developer diagnostic (debug builds only): walking forward but being carried BACKWARDS for a moment means something is
## pushing the player (a follower, a prop, a moving body). The screen hint and the console name what touched the capsule.
var _back_t := 0.0
var _back_reported := 0.0


func _debug_pushed_back(delta: float) -> void:
	if not OS.is_debug_build():
		return
	_back_reported = maxf(_back_reported - delta, 0.0)
	var fwd := -global_transform.basis.z
	var hv := Vector3(velocity.x, 0, velocity.z)
	if controls_enabled and Input.is_action_pressed("move_forward") and not Input.is_action_pressed("move_back") and hv.dot(fwd) < -0.25:
		_back_t += delta
	else:
		_back_t = 0.0
	if _back_t > 0.25 and _back_reported <= 0.0:
		_back_reported = 3.0
		var who := "nothing in contact"
		for i in get_slide_collision_count():
			var c := get_slide_collision(i).get_collider()
			if c is Node:
				who = "%s (%s)" % [(c as Node).name, (c as Node).get_class()]
				break
		var msg := "DEV: pushed backwards by " + who
		print(msg)                                    # (console only: the on-screen "DEV: pushed backwards" line was showing in play)


## Stair-step: when the way ahead is blocked by a low vertical face (a curb, a door sill), lift the capsule onto it.
## The shared swept step check requires headroom and a walkable landing.
func _step_up(hv: Vector3, delta: float) -> void:
	var probe := hv.normalized() * maxf(hv.length() * delta, RADIUS + 0.06)
	_step_smooth += VeilSurvivorBody.step_up(self, probe, STEP)


func _update_stamina(sprinting: bool, delta: float) -> void:
	if not survival_active:
		return
	var before := stamina
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		_regen_t = REGEN_DELAY
		if stamina <= 0.0:
			_exhausted = true
	else:
		_regen_t -= delta
		if _regen_t <= 0.0:
			stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
		if _exhausted and stamina >= EXHAUSTED_UNTIL:
			_exhausted = false
	if stamina != before:
		stamina_changed.emit(stamina, MAX_STAMINA)


func set_survival(on: bool) -> void:
	survival_active = on
	health_changed.emit(health, MAX_HEALTH)
	stamina_changed.emit(stamina, MAX_STAMINA)


## Damage with a short, readable reaction: camera kick, a small push away from the source, a brief stagger.
## Control is never taken away.
func damage(amount: float, from_pos: Vector3) -> void:
	if not survival_active or health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, MAX_HEALTH)
	var away := (global_position - from_pos) * Vector3(1, 0, 1)
	if away.length() > 0.01:
		velocity += away.normalized() * 5.0
	_stagger_t = 0.35
	_kick = Vector2(randf_range(0.08, 0.14), randf_range(-0.12, 0.12))
	hurt.emit(amount)
	if health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	health = minf(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var c := CapsuleShape3D.new()
	c.radius = RADIUS * 0.9
	c.height = HEIGHT
	q.shape = c
	q.transform = Transform3D(Basis(), global_position + Vector3(0, HEIGHT / 2.0 + 0.05, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# ------------------------------------------------------------------ interaction
func _update_focus() -> void:
	var f: Node = null
	var hit_d := INF
	if controls_enabled and ray.is_colliding():
		var c := ray.get_collider()
		hit_d = camera.global_position.distance_to(ray.get_collision_point())
		if c and c.has_method("get_prompt"):
			f = c
	# aim assist for small collectibles (loot in an open drawer or cabinet, items on shelves): no pixel hunting.
	# A visible pickup close to the crosshair wins over the container part / surface the ray happened to hit.
	# only when the ray found nothing to use, or found the container a loot item sits in (never over NPCs / doors)
	var container := f is Interactable and (f as Interactable).kind in ["hinge", "slide"]
	if controls_enabled and (f == null or container):
		var a := _assist_pickup(hit_d, ray.get_collider() if ray.is_colliding() else null)
		if a and (f == null or a.container == f or _same_piece(a, f)):
			f = a
	if f != _focus:
		if _focus and is_instance_valid(_focus) and _focus.has_method("set_focus"):
			_focus.set_focus(false)
		if f and f.has_method("set_focus"):
			f.set_focus(true)
	_focus = f
	_set_prompt(f.get_prompt() if f else "")


## The ray hit another door / drawer of the piece the loot sits in (e.g. the neighbouring closed cabinet door).
func _same_piece(a: Interactable, f: Node) -> bool:
	if a.container == null or not (f is Node):
		return false
	if not a.container.is_open:
		return false
	var piece: Node = a.container
	while piece and piece.get_parent() and not (String(piece.get_parent().name) in ["Furniture", "ScavengeFurniture"]):
		piece = piece.get_parent()
	return piece != null and piece.get_parent() != null and piece.is_ancestor_of(f)


const ASSIST_COS := 0.985          ## ~10 degrees around the crosshair
const ASSIST_RADIUS := 0.16        ## or within 16 cm of the view line


## Nearest-to-the-crosshair pickup within reach that the player can actually see (no walls, closed doors or
## drawers in between: closed containers switch their loot's layer off, so it is never offered).
func _assist_pickup(ray_hit_d: float, ray_hit: Object) -> Interactable:
	var eye := camera.global_position
	var fwd := -camera.global_transform.basis.z
	var best: Interactable = null
	var best_score := INF
	var space := get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("veil_pickup"):
		var it := n as Interactable
		if it == null or it.taken or (it.collision_layer & 8) == 0 or not it.monitorable or not it.is_visible_in_tree():
			continue
		var p := it.focus_point()
		var to := p - eye
		var d := to.length()
		if d > REACH + 0.3 or d < 0.05:
			continue
		var along := to.dot(fwd)
		if along <= 0.0:
			continue
		var off := (to - fwd * along).length()
		if to.normalized().dot(fwd) < ASSIST_COS and off > ASSIST_RADIUS:
			continue
		var own: Array[RID] = it.los_ignore
		var hit_own := ray_hit is CollisionObject3D and own.has((ray_hit as CollisionObject3D).get_rid())
		if ray_hit_d < d - 0.35 and not hit_own and ray_hit != it.container:
			continue                                   # something solid well in front of it on the view line
		var ex: Array[RID] = [get_rid()]
		ex.append_array(own)
		var q := PhysicsRayQueryParameters3D.create(eye, p, 1, ex)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(p) > 0.3:
			continue                                   # hidden behind something
		var score := off + d * 0.02
		if score < best_score:
			best_score = score
			best = it
	return best


func _set_prompt(t: String) -> void:
	if t != _prompt:
		_prompt = t
		prompt_changed.emit(t)


func try_interact() -> void:
	if controls_enabled and _focus and _focus.has_method("interact"):
		_focus.interact(self)
		_update_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and visible and controls_enabled:
		get_viewport().set_input_as_handled()
		if _focus and not event.is_echo() and float(_focus.get("hold_time") if _focus.get("hold_time") != null else 0.0) > 0.0:
			_hold_target = _focus                    # heavy things take a moment: hold the key, a ring fills
			_hold_t = 0.0
		elif not _hold_target:
			try_interact()


## "Hold to use": a ring fills while the key stays down with the object still under the crosshair; releasing, looking
## away or losing control cancels it; a full ring does the interaction (interact() itself is unchanged and instant).
var _hold_target: Node = null
var _hold_t := 0.0


func _update_hold(delta: float) -> void:
	if _hold_target == null:
		return
	var need := float(_hold_target.get("hold_time")) if is_instance_valid(_hold_target) else 0.0
	if need <= 0.0 or not controls_enabled or not Input.is_action_pressed("interact") or _focus != _hold_target:
		_hold_target = null
		_hold_t = 0.0
		hold_progress.emit(0.0)
		return
	_hold_t += delta
	hold_progress.emit(clampf(_hold_t / need, 0.0, 1.0))
	if _hold_t >= need:
		_hold_target = null
		_hold_t = 0.0
		hold_progress.emit(0.0)
		try_interact()


# ------------------------------------------------------------------ waking up (Friday, 6:42 PM)
## Camera starts low and tilted (lying on the bed), then sits up and stands. Controls return at the end.
func play_wake_up(duration := 4.2, give_control := true) -> void:
	controls_enabled = false
	look_enabled = false
	var y0 := head.position.y
	head.position.y = 0.55
	head.rotation = Vector3(deg_to_rad(62), deg_to_rad(-25), deg_to_rad(18))
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(head, "rotation", Vector3(deg_to_rad(20), deg_to_rad(-10), deg_to_rad(6)), duration * 0.35)
	tw.parallel().tween_property(head, "position:y", 0.95, duration * 0.35)
	tw.tween_property(head, "rotation", Vector3(deg_to_rad(-4), 0, 0), duration * 0.4)
	tw.parallel().tween_property(head, "position:y", y0, duration * 0.4)
	tw.tween_callback(func():
		_pitch = head.rotation.x
		head.rotation.y = 0.0
		head.rotation.z = 0.0
		if give_control:                          # (the opening keeps control until the first-day wash is over)
			controls_enabled = true
			look_enabled = true)
	await tw.finished


# ------------------------------------------------------------------ footsteps (game/audio, recorded loops)
const WALK_STEPS := preload("res://game/audio/the_veil_walk_footsteps.wav")
const RUN_STEPS := preload("res://game/audio/the_veil_run_footsteps.wav")
var _walk_sfx: AudioStreamPlayer
var _run_sfx: AudioStreamPlayer


## Walking: the quiet walk loop (quieter still crouched); running: the heavier run loop. Never both at once;
## silent when standing still, in the air, in the car (the player is hidden) or while control is taken.
func _footsteps(moving: bool, sprinting: bool, crouching: bool, speed := WALK) -> void:
	if _walk_sfx == null:
		_walk_sfx = AudioStreamPlayer.new()
		_walk_sfx.stream = WALK_STEPS
		_run_sfx = AudioStreamPlayer.new()
		_run_sfx.stream = RUN_STEPS
		for a in [_walk_sfx, _run_sfx]:
			add_child(a)
			a.finished.connect(a.play)                 # loop the recording
	var want_run := moving and sprinting
	var want_walk := moving and not sprinting
	_walk_sfx.volume_db = -28.0 if crouching else -22.0
	_run_sfx.volume_db = -18.0
	# the recordings' step rate follows the real ground speed (walk recorded at walking pace, run at a sprint)
	_walk_sfx.pitch_scale = clampf(speed / WALK, 0.6, 1.3)
	_run_sfx.pitch_scale = clampf(speed / SPRINT, 0.8, 1.25)
	for pair in [[_walk_sfx, want_walk], [_run_sfx, want_run]]:
		var a: AudioStreamPlayer = pair[0]
		if pair[1] and not a.playing:
			a.play(randf() * 4.0)                       # from a random point: no identical start each time
		elif not pair[1] and a.playing:
			a.stop()


# ------------------------------------------------------------------ out of the world
## The last floor the player stood on (sampled while in control). A real fall far below it - out of the built
## world - puts them back there: nothing else changes (chapter, items, puzzles). Scripted moves are teleports
## (no falling speed), so they never trigger it.
var _safe_pos := Vector3.INF
var _safe_t := 0.0
var fall_recoveries := 0              ## tests
var _air_t := 0.0


func _fall_guard(delta: float) -> void:
	_safe_t -= delta
	if is_on_floor() and controls_enabled and visible and _safe_t <= 0.0:
		_safe_t = 0.4
		_safe_pos = global_position
	if not controls_enabled or not visible:
		_air_t = 0.0                                    # a scene holds the player (or moves them): never a "fall"
		_safe_pos = Vector3.INF                         # and the next floor stood on is the new reference
		return
	_air_t = 0.0 if is_on_floor() else _air_t + delta
	# a real fall out of the world (through a floor a scripted move left the player under) puts them back on the last floor stood on
	# within a second or so (was 20 m / 1 s: long enough to see the world vanish)
	if _safe_pos.is_finite() and _air_t > 0.8 and global_position.y < _safe_pos.y - 8.0:
		global_position = _safe_pos + Vector3(0, 0.3, 0)
		velocity = Vector3.ZERO
		fall_recoveries += 1
	_unstick(delta)


## A scene's hand-typed teleport can leave the player inside a prop or a wall. Once a second, while they are in control and on
## foot, one capsule query; overlapping twice in a row, they are lifted/moved to the nearest clear spot (at most 1.5 m).
var _unstick_t := 0.0
var _overlap_seen := 0
var unsticks := 0                     ## tests


func _unstick(delta: float) -> void:
	_unstick_t -= delta
	if _unstick_t > 0.0:
		return
	_unstick_t = 1.0
	if not controls_enabled or not visible or shape.disabled:
		_overlap_seen = 0
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	q.collision_mask = 1
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, capsule.height * 0.5 + 0.02, 0))
	if space.intersect_shape(q, 1).is_empty():
		_overlap_seen = 0
		return
	_overlap_seen += 1
	if _overlap_seen < 2:
		return
	_overlap_seen = 0
	var offsets: Array = []
	for up in [0.15, 0.3, 0.5, 0.8, 1.2]:
		offsets.append(Vector3(0, up, 0))
	for ring in [0.3, 0.6, 1.0, 1.5]:
		for i in 12:
			var a := TAU * i / 12.0
			offsets.append(Vector3(cos(a) * ring, 0.05, sin(a) * ring))
	for o in offsets:
		q.transform = Transform3D(Basis.IDENTITY, global_position + o + Vector3(0, capsule.height * 0.5 + 0.02, 0))
		if space.intersect_shape(q, 1).is_empty():
			global_position += o
			velocity = Vector3.ZERO
			unsticks += 1
			return
