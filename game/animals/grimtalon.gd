extends Node3D
class_name VeilGrimtalon
## THE VEIL - the Grimtalon: a bat-owl, wingspan ~6 m, that comes with the Colossus. They fly in flocks above the mist, circle the tripod, and take people.
## The Meshy model (game/prototypes/animals/MON_grimtalon.glb) is rigged (61 bones) but came without clips: its flight is posed here, bone by bone:
## the wings beat from the shoulder (a slow lift with the fingers trailing, a fast down-stroke that whips the tips through), the legs tuck back (or hang out
## to hold a catch), the tail steers, the head leads, the body bobs against the beat and banks into the turn.
##   var g := VeilGrimtalon.spawn(parent, position)
##   g.fly_circle(centre, radius, height, speed, follow_node)        a circling flight round a point (or round a node that moves)
##   g.scripted()                                                   the caller moves it (swoops, carrying); the wings still beat (flap_rate / amp)
##   g.grip_point()                                                 where its talons close (world)
##   VeilGrimtalon.flock(parent, 9, centre, follow, ...)            a swarm: every bird its own radius, height, speed and phase, so they weave through each other
## The model faces +Z (like the raven's).

const GLB := "res://game/prototypes/animals/MON_grimtalon.glb"
const SCALE := 1.5
## [bone, degrees it adds to the beat at full amplitude]: the joints' angles add along the chain (shoulder, elbow, wrist, then the two finger chains), ~65 deg at the tip
const WING_R := [["Bone_041", 28.0], ["Bone_040", 12.0], ["Bone_039", 8.0], ["Bone_038", 5.0], ["Bone_049", 4.0], ["Bone_048", 4.0], ["Bone_047", 3.0], ["Bone_046", 2.0],
	["Bone_053", 4.0], ["Bone_052", 4.0], ["Bone_051", 3.0], ["Bone_050", 2.0]]
const WING_L := [["Bone_045", 28.0], ["Bone_044", 12.0], ["Bone_043", 8.0], ["Bone_042", 5.0], ["Bone_057", 4.0], ["Bone_056", 4.0], ["Bone_055", 3.0], ["Bone_054", 2.0],
	["Bone_061", 4.0], ["Bone_060", 4.0], ["Bone_059", 3.0], ["Bone_058", 2.0]]
const LEG_R := ["Bone_005", "Bone_004", "Bone_003"]
const LEG_L := ["Bone_009", "Bone_008", "Bone_007"]
const TAIL := ["Bone_016", "Bone_015", "Bone_014"]
const NECK := ["Bone_037", "Bone_036"]
const TOES := ["Bone_017", "Bone_020", "Bone_023", "Bone_026", "Bone_029", "Bone_032"]
const SCREECH := "colossus_call"

var model: Node3D
var skel: Skeleton3D
var flap_rate := 2.3                      ## beats per second
var amp := 1.0                            ## 1 = full beats, 0 = wings held out (a glide)
var carrying := false                     ## the legs hang down and forward to hold a catch (otherwise they tuck back)
var bank_angle := 0.0                     ## extra roll (set by the caller when scripted)
var pitch_angle := 0.0                    ## extra nose-up (+) / nose-down (-) (set by the caller when scripted)
var manual_pose := false                  ## the caller poses it itself, once a frame, after it has moved it (so what it holds follows exactly)
var mode := "idle"                        ## idle / circle / scripted / retire
var _t := 0.0
var _rest_g: Array = []
var _parent_of: Array = []
var _idx := {}
var _tail_dir := 0.0
# circle
var _centre := Vector3.ZERO
var _follow: Node3D
var _radius := 40.0
var _height := 40.0
var _speed := 10.0
var _ang := 0.0
var _last := Vector3.ZERO
var _lag := 0               ## frames since the pose was last written (distant birds are posed less often)
var _retire_dir := Vector3.ZERO
var _retire_t := 0.0
var _screech_t := 0.0
var _ph := 0.0
var _vel := Vector3.ZERO
var _vprev := Vector3.INF


static func spawn(parent: Node, at: Vector3, yaw := 0.0, scale := SCALE) -> VeilGrimtalon:
	var g := VeilGrimtalon.new()
	g.name = "Grimtalon"
	parent.add_child(g)
	g.global_position = at
	g.rotation.y = yaw
	g._build(scale)
	return g


func _build(scale: float) -> void:
	var ps := load(GLB) as PackedScene
	model = ps.instantiate() as Node3D
	VeilSarahMeshyProto.psx_look(model)
	model.scale = Vector3.ONE * scale
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in skel.get_bone_count():
		_rest_g.append(skel.get_bone_global_rest(i).basis)
		_parent_of.append(skel.get_bone_parent(i))
		_idx[skel.get_bone_name(i)] = i
	_ph = randf() * TAU
	_t = randf() * 10.0
	_screech_t = randf_range(4.0, 14.0)
	_pose()


## Circle round `centre` (or round `follow`, whatever it does): `radius` m out, `height` m above the ground there, `speed` m/s along the circle.
func fly_circle(centre: Vector3, radius: float, height: float, speed: float, follow: Node3D = null) -> void:
	mode = "circle"
	_centre = centre
	_follow = follow
	_radius = radius
	_height = height
	_speed = speed
	_ang = randf() * TAU


func scripted() -> void:
	mode = "scripted"


## Leave: climb away along `dir` (flat) and free itself after `seconds`.
func retire(dir: Vector3, seconds := 16.0) -> void:
	mode = "retire"
	_retire_dir = Vector3(dir.x, 0, dir.z).normalized()
	_retire_t = seconds


func grip_point() -> Vector3:
	var p := Vector3.ZERO
	var n := 0
	for tn in TOES:
		var i: int = _idx.get(tn, -1)
		if i >= 0:
			p += skel.get_bone_global_pose(i).origin
			n += 1
	return skel.global_transform * (p / maxf(n, 1))


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	match mode:
		"circle":
			_fly(delta)
		"retire":
			_retire_t -= delta
			var v := _retire_dir * 16.0 + Vector3.UP * 6.0
			global_position += v * delta
			_look_along(v, 0.0)
			if _retire_t <= 0.0:
				queue_free()
				return
	if manual_pose:
		return
	# distant birds are drawn from far off: pose them every few frames
	var far := cam != null and cam.global_position.distance_to(global_position) > 140.0
	_lag += 1
	if far and mode != "scripted" and _lag < 4:
		return
	_lag = 0
	if cam != null and mode != "scripted" and cam.global_position.distance_to(global_position) > 420.0:
		return
	_pose()
	if mode != "scripted":
		_screech_t -= delta
		if _screech_t <= 0.0 and cam != null and cam.global_position.distance_to(global_position) < 160.0:
			_screech_t = randf_range(9.0, 22.0)
			Sfx.play(SCREECH, global_position, -9.0, randf_range(1.7, 2.1))
		elif _screech_t <= 0.0:
			_screech_t = 8.0


func _fly(delta: float) -> void:
	var c := _centre
	if _follow != null and is_instance_valid(_follow):
		c = _follow.global_position
		_centre = c
	var w := _speed / maxf(_radius, 1.0)
	_ang += w * delta
	var gy := c.y
	var p := Vector3(c.x + cos(_ang) * _radius, gy + _height + sin(_ang * 1.7 + _ph) * 3.0, c.z + sin(_ang) * _radius)
	var vel := p - global_position
	if _last != Vector3.ZERO and vel.length() > 0.001:
		var v := vel / maxf(delta, 0.0001)
		_look_along(v, clampf(w * 2.0, 0.0, 0.5))
	global_position = p
	_last = p


func _look_along(v: Vector3, bank: float) -> void:
	if v.length() < 0.01:
		return
	var dir := v.normalized()
	var b := Basis.looking_at(-dir, Vector3.UP)                           # (the model faces +Z)
	b = b * Basis(Vector3.BACK, -bank)
	global_basis = b


# ------------------------------------------------------------------ the pose
func _bone_rot(name: String, r: Basis) -> void:
	var i: int = _idx.get(name, -1)
	if i < 0:
		return
	var par: int = _parent_of[i]
	var pg: Basis = _rest_g[par] if par >= 0 else Basis.IDENTITY
	var local := pg.inverse() * (r * (_rest_g[i] as Basis))
	skel.set_bone_pose_rotation(i, local.get_rotation_quaternion())


func _wing(list: Array, side: float, ph: float) -> void:
	# one beat: the stroke is an asymmetric wave (slow lift, fast down-stroke); every joint is a little behind the one before it
	for k in list.size():
		var seg: Array = list[k]
		var depth := float(k) if k < 4 else float(4 + (k - 4) % 4)
		var a := ph - depth * 0.3
		var s := sin(a)
		var shape := s * (1.0 if s < 0.0 else 0.8) + 0.2 * sin(2.0 * a)           # down-stroke (s<0) is the stronger, faster one
		var ang := deg_to_rad(float(seg[1])) * (0.1 + shape * amp)
		_bone_rot(String(seg[0]), Basis(Vector3.BACK, ang * side))


func _pose() -> void:
	var ph := _t * flap_rate * TAU + _ph
	_wing(WING_R, 1.0, ph)
	_wing(WING_L, -1.0, ph)
	# legs: tucked back for flight, hanging down and forward with the talons open to hold a catch
	var leg := deg_to_rad(-26.0) if carrying else deg_to_rad(68.0)
	var l2 := deg_to_rad(-12.0) if carrying else deg_to_rad(24.0)
	for k in 3:
		var a := leg if k == 0 else l2 * 0.5
		_bone_rot(LEG_R[k], Basis(Vector3.RIGHT, a))
		_bone_rot(LEG_L[k], Basis(Vector3.RIGHT, a))
	# tail: steers a little, lags the body
	_tail_dir = lerpf(_tail_dir, sin(_t * 0.7 + _ph) * 0.25, 0.05)
	for k in 3:
		_bone_rot(TAIL[k], Basis(Vector3.RIGHT, deg_to_rad(-14.0) * amp + sin(ph - 1.0 - k * 0.5) * 0.08) * Basis(Vector3.UP, _tail_dir))
	# the head stays level against the body's bob and looks along the flight
	for k in 2:
		_bone_rot(NECK[k], Basis(Vector3.RIGHT, deg_to_rad(8.0) - sin(ph - 0.5) * 0.06 * amp))
	model.position.y = -sin(ph - 0.4) * 0.22 * amp * model.scale.y * 0.5
	model.rotation.z = bank_angle
	model.rotation.x = pitch_angle


# ------------------------------------------------------------------ swarms
## `count` birds that all circle `centre` (or `follow`), each with its own radius, height, speed and phase: one swarm that weaves in and out of itself.
static func flock(parent: Node, count: int, centre: Vector3, follow: Node3D, radius: Vector2, height: Vector2, speed: Vector2, scale := SCALE) -> Array:
	var out: Array = []
	for i in count:
		var r := randf_range(radius.x, radius.y)
		var g := spawn(parent, centre + Vector3(r, randf_range(height.x, height.y), 0.0), randf() * TAU, scale * randf_range(0.8, 1.15))
		g.flap_rate = randf_range(1.9, 2.8)
		g.fly_circle(centre, r, randf_range(height.x, height.y), randf_range(speed.x, speed.y) * (1.0 if i % 2 == 0 else -1.0), follow)
		out.append(g)
	return out


static func retire_all(birds: Array, dir: Vector3) -> void:
	for g in birds:
		if is_instance_valid(g):
			(g as VeilGrimtalon).retire(dir.rotated(Vector3.UP, randf_range(-0.6, 0.6)), randf_range(10.0, 18.0))


# ------------------------------------------------------------------ taking someone
## Swoops out of the sky onto `victim` (a standing person at `victim.global_position`), takes him by the shoulders and climbs away with him, away from `exit_dir`'s
## opposite, until he is a speck in the mist. `on_state(s)` is called with "dive" / "grab" / "carry" / "gone". The person keeps the pose he has (the caller
## sets his mood), hanging a little and swaying. Returns when it is gone.
func abduct(victim: Node3D, exit_dir: Vector3, on_state := Callable(), approach := Vector3.ZERO, dive_scale := 1.0) -> void:
	scripted()
	manual_pose = true
	carrying = true
	amp = 0.35
	flap_rate = 1.6
	var shoulder := 1.36
	var exit_flat := Vector3(exit_dir.x, 0.0, exit_dir.z).normalized()
	var target: Vector3 = victim.global_position + Vector3(0, shoulder, 0)
	var from_dir := Vector3(approach.x, 0.0, approach.z).normalized() if approach.length() > 0.1 else -exit_flat
	var start := target + from_dir * 75.0 * dive_scale + Vector3(0, 48.0 * dive_scale, 0)
	global_position = start
	if on_state.is_valid():
		on_state.call("dive")
	# the dive: accelerating along a curve that arrives level, about to rise, with its talons reaching down onto his shoulders
	var T := 1.0 + 1.7 * dive_scale
	var t := 0.0
	var grip_off := Vector3.ZERO
	while t < T:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / T, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var from := start
		if is_instance_valid(victim):                                    # a running man: it aims where he will be
			var vnow: Vector3 = victim.global_position + Vector3(0, shoulder, 0)
			_vel = _vel.lerp((vnow - _vprev) / maxf(dt, 0.0001), 0.2) if _vprev != Vector3.INF else Vector3.ZERO
			_vprev = vnow
			target = vnow + _vel * maxf(T - t, 0.0)
		var ctrl := start.lerp(target, 0.55) + Vector3(0, -6.0, 0)
		var p := from.lerp(ctrl, e).lerp(ctrl.lerp(target + Vector3(0, 1.0, 0), e), e)
		var prev := global_position
		global_position = p
		_look_along(p - prev if (p - prev).length() > 0.001 else exit_flat, 0.0)
		pitch_angle = lerpf(-0.55, 0.15, e)
		amp = lerpf(0.2, 1.0, smoothstep(0.7, 1.0, k))                       # the wings come up and flare at the end
		flap_rate = lerpf(1.2, 3.4, smoothstep(0.6, 1.0, k))
		_pose()
	# grab: the talons close on his shoulders; from here the person hangs from them
	if on_state.is_valid():
		on_state.call("grab")
	var up_v := 3.0
	var fw_v := 0.0
	var s := 0.0
	var gone := false
	while not gone:
		await get_tree().process_frame
		var dt2 := get_process_delta_time()
		s += dt2
		up_v = minf(up_v + 9.0 * dt2, 17.0)
		fw_v = minf(fw_v + 5.0 * dt2, 11.0)
		global_position += (Vector3.UP * up_v + exit_flat * fw_v) * dt2
		_look_along(Vector3.UP * up_v * 0.5 + exit_flat * fw_v, 0.0)
		pitch_angle = lerpf(0.15, 0.55, clampf(s / 1.5, 0.0, 1.0))
		amp = 1.0
		flap_rate = 3.3
		_pose()
		if is_instance_valid(victim):
			var g := grip_point()
			victim.global_position = g - Vector3(0, shoulder, 0)
			victim.rotation.z = sin(s * 9.0) * 0.34                          # he thrashes in its grip
			victim.rotation.x = sin(s * 7.0 + 1.0) * 0.26
		if s > 0.6 and on_state.is_valid() and not has_meta("carry_sent"):
			set_meta("carry_sent", true)
			on_state.call("carry")
		if s > 9.0 or global_position.y > 95.0:
			gone = true
	if on_state.is_valid():
		on_state.call("gone")
