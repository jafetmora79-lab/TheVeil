extends CharacterBody3D
class_name VeilPlayer
## THE VEIL - first-person player: walk / sprint / crouch, mouse look, head bob, gravity, slopes and ramps
## (Pack 03 stairs and porch steps collide as smooth ramps), raycast interaction.
## Built in code so the scene file stays minimal.

signal prompt_changed(text: String)

const WALK := 2.4
const SPRINT := 4.3
const CROUCH := 1.3
const ACCEL := 10.0
const DECEL := 12.0
const GRAVITY := 14.0
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
var _pitch := 0.0
var _bob_t := 0.0
var _eye := EYE
var _focus: Node = null
var _prompt := ""
var _last_step := 0
var _step_smooth := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4            # world + vehicles
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
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


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# crouch (stand up only if there is head room)
	var want_crouch := controls_enabled and Input.is_action_pressed("crouch")
	if want_crouch != crouching:
		if want_crouch or _can_stand():
			crouching = want_crouch
			capsule.height = HEIGHT_CROUCH if crouching else HEIGHT
			shape.position.y = capsule.height / 2.0
	var sprinting := controls_enabled and Input.is_action_pressed("sprint") and not crouching and input.y < 0.0
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
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	if is_on_floor() and hv.length() > 0.05:
		_step_up(hv, delta)
	move_and_slide()
	# eye height + head bob
	_eye = move_toward(_eye, EYE_CROUCH if crouching else EYE, delta * 3.5)
	var moving := hv.length() > 0.4 and is_on_floor()
	if moving and Game.settings.get("head_bob", true):
		_bob_t += delta * hv.length() * 2.3
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 6.0)
	if moving and int(_bob_t / PI) != _last_step:
		_last_step = int(_bob_t / PI)
		Sfx.play("step_soft" if crouching else "step", global_position, -10.0 if crouching else -6.0, randf_range(0.9, 1.1))
	var amp := 0.028 if sprinting else 0.016
	_step_smooth = move_toward(_step_smooth, 0.0, delta * 1.6)
	head.position.y = _eye + sin(_bob_t * 2.0) * amp - _step_smooth
	_kick = _kick.lerp(Vector2.ZERO, minf(delta * 7.0, 1.0))
	head.rotation.x = _pitch + _kick.x
	head.rotation.z = _kick.y
	head.position.x = cos(_bob_t) * amp * 0.6
	_update_focus()


## Stair-step: when the way ahead is blocked by a low vertical face (a curb, a door sill), lift the capsule onto it.
## Probe: up STEP, forward (at least 8 cm so slow walking still finds the edge), then back down onto a walkable floor.
func _step_up(hv: Vector3, delta: float) -> void:
	# probe a full capsule radius ahead: the rounded bottom touches a curb edge about RADIUS before the face
	var fwd := hv.normalized() * maxf(hv.length() * delta, RADIUS + 0.06)
	var t := global_transform
	var col := KinematicCollision3D.new()
	if not test_move(t, fwd, col):
		return
	if col.get_normal().y > 0.7:            # a slope we can already walk up
		return
	var up := Vector3(0, STEP, 0)
	if test_move(t, up):                     # no head room
		return
	var t_up := t.translated(up)
	if test_move(t_up, fwd):                 # still blocked up there: it is a wall, not a step
		return
	var t_fwd := t_up.translated(fwd)
	var down := KinematicCollision3D.new()
	if not test_move(t_fwd, Vector3(0, -STEP - 0.05, 0), down):
		return
	if down.get_normal().y < 0.7:
		return
	var rise := STEP - down.get_travel().length()
	if rise < 0.01:
		return
	global_position = t_fwd.origin + down.get_travel() + Vector3(0, 0.002, 0)
	_step_smooth += rise                       # the camera eases up instead of popping


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
		if a and (f == null or a.container == f):
			f = a
	if f != _focus:
		if _focus and is_instance_valid(_focus) and _focus.has_method("set_focus"):
			_focus.set_focus(false)
		if f and f.has_method("set_focus"):
			f.set_focus(true)
	_focus = f
	_set_prompt(f.get_prompt() if f else "")


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
		var hit_own := ray_hit is CollisionObject3D and (ray_hit as CollisionObject3D).get_rid() in own
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
		try_interact()


# ------------------------------------------------------------------ waking up (Friday, 6:42 PM)
## Camera starts low and tilted (lying on the bed), then sits up and stands. Controls return at the end.
func play_wake_up(duration := 4.2) -> void:
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
		controls_enabled = true
		look_enabled = true)
	await tw.finished
