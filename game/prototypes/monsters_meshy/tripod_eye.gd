class_name VeilTripodEye
extends Node3D
## THE VEIL - the tripod creature's eye: a living searchlight. Add it as a child of the MON_tripod model (rig: Body, Eye, Leg_B / Leg_L / Leg_R).
##
## The pod (the "Eye" bone) is the socket. Inside it sits a real eyeball (a low-poly sphere with a painted sclera, iris and a white-hot pupil) that turns to
## look: the iris and pupil move in the socket. The beam is attached to the eyeball: a shadowed SpotLight3D (the pool of light that crosses walls, pavement and props)
## is its child, so it points exactly where the pupil points, and a soft tapered cone (a shader, for the Compatibility renderer: a bright narrow core, soft edges, fading
## with distance, ending at the first solid thing in its way) shows the beam in the mist.
##
## Three stages:
##   SEARCH  hold a direction, a quick small correction, a sweep across a wider angle, uneven pauses; the beam's brightness stays steady.
##   ALERT   (the target becomes the player's camera) the eye gets there first, sweeps slightly past, stops, snaps back; the pod (the neck) follows a beat later,
##           the torso a beat after that when the turn is large.
##   LOCK    the bright centre is held on the target with small tracking corrections; the body goes unusually still for a beat so the player can tell it has seen them.
## The scenes drive it as before: `target`, `search_on`, `beam_on`, `level`, `max_angle`, `ground_y` (aim_direct is kept for them; the light always follows the gaze now).
enum Stage { SEARCH, ALERT, LOCK }

var target: Node3D:
	set(v):
		if v == target:
			return
		target = v
		_on_target_changed()
var stage: int = Stage.SEARCH
var beam_on := false                   ## the lock's full brightness (the pupil and the beam flare)
var level := 1.0                       ## 0..2: how awake / bright the eye is
var max_angle := 1.15                  ## radians the POD may turn from straight ahead (the eyeball has its own, smaller range inside the socket)
var skel: Skeleton3D
var eye := -1                          ## the "Eye" bone: the pod
var body := -1
var mesh: MeshInstance3D
var search_on := false                 ## the searchlight (spot + cone) is on
var aim_direct := false                ## (kept for the scenes: the light always points where the eyeball looks)
var ground_y := 0.0
var ball: Node3D                       ## the eyeball: turns to look; the spot light is its child
var ball_mesh: MeshInstance3D
var glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var aim_point: Marker3D                ## in front of the pupil: rotates with the eyeball
var spot: SpotLight3D
var cone: MeshInstance3D
var core: MeshInstance3D
var omni: OmniLight3D
var report := {"overshoot": 0.0, "stage_log": []}
var _ball_mat: ShaderMaterial
var _cone_mat: ShaderMaterial
var _core_mat: ShaderMaterial
var _gaze := Vector3(0, 0, -1)         ## where the eyeball looks (world, unit)
var _gz := Vector3(0, 0, -1)           ## the spring state behind it
var _gv := Vector3.ZERO
var _pod := Vector3(0, 0, -1)          ## where the pod faces (world, unit); follows the gaze a beat later
var _t := 0.0
var _stage_t := 0.0
var _search_k := 0.0
var _hot := 0.0                        ## 0..1 lock brightness
var _still := 0.0                      ## seconds left of the "unusually still" beat
var _rng := RandomNumberGenerator.new()
# search behaviour
var _off := Vector2.ZERO               ## the gaze's offset (yaw, pitch) from the search point, radians
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _mv_t := 0.0
var _mv_len := 0.0
var _wait := 0.5
var _step := 0                         ## where in hold / correct / hold / sweep the search is
var _last_sweep := 1.0
var _micro := Vector2.ZERO
var _micro_t := 0.0
var _body_base := Quaternion.IDENTITY
var _body_written := Quaternion.IDENTITY
var _body_yaw := 0.0
var _ball_r := 0.45
var _ball_local := Vector3.ZERO
var _prev_ap_scale := 1.0
var _held := false
var _inited := false
var _ap: AnimationPlayer
var _spot_deg := 5.0
const BALL_RANGE := 0.2                ## how far the (invisible) eyeball can turn inside the pod (radians): the beam goes where the POD faces, with only a little play
var show_ball := false                 ## the separate eyeball is not drawn: the light comes out of the model's own eye (the glowing patch of the pod)
var _front := 0.5                      ## from the eye patch to the front of the pod's bulb (model units): the beam starts there
var _patch_mat: StandardMaterial3D
const RANGE_M := 170.0
const BALL_SHADER := """shader_type spatial;
render_mode unshaded;
uniform float k = 1.0;
uniform float hot = 0.0;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { lp = normalize(VERTEX); }
void fragment() {
	float c = -lp.z;                                           // 1 at the middle of the pupil (the gaze axis), down to -1 at the back
	float a = atan(lp.y, lp.x);
	float streak = 0.5 + 0.5 * sin(a * 24.0 + hash(vec2(floor(a * 4.0), 1.0)) * 6.0) * (0.6 + 0.4 * sin(a * 7.0));
	vec3 sclera = vec3(0.30, 0.11, 0.07) + 0.10 * vec3(1.0, 0.3, 0.2) * hash(floor(vec2(a * 6.0, c * 9.0)));   // veined, dull red-brown
	vec3 iris = mix(vec3(0.62, 0.20, 0.04), vec3(1.0, 0.66, 0.16), streak * smoothstep(0.55, 0.85, c));   // amber with dark streaks, brighter toward the pupil
	iris *= 0.45 + 0.55 * smoothstep(0.62, 0.72, c);           // a dark limbal ring where the iris meets the sclera
	vec3 col = sclera;
	col = mix(col, iris, smoothstep(0.62, 0.68, c));
	float pup = smoothstep(0.90, 0.94, c);                     // the pupil: orange at its rim, white-hot in the middle
	vec3 hotc = mix(vec3(1.0, 0.58, 0.14), vec3(1.0, 0.98, 0.9), smoothstep(0.94, 0.985, c));
	col = mix(col, hotc, pup);
	col *= k;
	col = mix(col, col + vec3(0.30, 0.22, 0.12) * pup, hot);
	ALBEDO = clamp(col, 0.0, 1.0);
}
"""
const GLOW_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float k = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float g = exp(-5.0 * r * r) * 0.9 + exp(-22.0 * r * r) * 0.5;
	ALBEDO = vec3(1.0, 0.72, 0.38) * g * k;
	ALPHA = 1.0;
}
"""
const CONE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 p0 = vec3(0.0);
uniform vec3 axis = vec3(0.0, 0.0, -1.0);
uniform float r0 = 0.3;
uniform float tan_a = 0.08;
uniform float len = 100.0;
uniform float k = 1.0;
uniform float sharp = 3.0;
uniform vec3 tint = vec3(1.0, 0.76, 0.42);
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = normalize(wp - cam);
	vec3 n = cross(ray, axis);
	float nl = length(n);
	float d = nl > 0.03 ? abs(dot(n, p0 - cam)) / nl : length(cross(p0 - cam, ray));     // how far this view ray passes from the beam's axis
	float t = clamp(dot(wp - p0, axis), 0.0, len);
	float R = r0 + t * tan_a;
	float u = d / max(R, 0.001);
	float fall = exp(-sharp * u * u);                             // bright narrow centre, soft edges
	float along = pow(1.0 - t / len, 1.25) * smoothstep(0.0, 0.03 * len + 1.0, t + 0.5);
	ALBEDO = tint * fall * along * k;
	ALPHA = 1.0;
}
"""


func _ready() -> void:
	_rng.randomize()
	var m := get_parent()
	skel = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	eye = skel.find_bone("Eye")
	body = skel.find_bone("Body")
	for n in m.find_children("*", "MeshInstance3D", true, false):
		mesh = n as MeshInstance3D
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_ap = aps[0] as AnimationPlayer
	_build_ball()
	_build_light()


## The socket's size and position are measured from the pod itself: every vertex the Eye bone carries (the bulb on the body and its glowing patch). The eyeball stands
## at the front of that bulb, half out of it, so it covers the bulb's old painted slit.
func _pod_centre() -> Vector3:
	var c := skel.get_bone_global_rest(eye).origin
	if mesh == null or mesh.mesh == null:
		return c
	# the pod's bulb (everything the Eye bone carries, surface 0) gives the front of the bulb; the glowing patch (surface 1, all Eye bone) is the eye itself
	var bulb_min := Vector3(1e9, 1e9, 1e9)
	var bulb_max := Vector3(-1e9, -1e9, -1e9)
	var patch_min := Vector3(1e9, 1e9, 1e9)
	var patch_max := Vector3(-1e9, -1e9, -1e9)
	var n := 0
	var np := 0
	for sidx in mesh.mesh.get_surface_count():
		var arr := mesh.mesh.surface_get_arrays(sidx)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wt: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if v.is_empty() or bn.is_empty():
			continue
		var per := bn.size() / v.size()
		for i in v.size():
			var w := 0.0
			for k in per:
				var b := bn[i * per + k]
				if mesh.skin != null and b < mesh.skin.get_bind_count():
					b = mesh.skin.get_bind_bone(b) if mesh.skin.get_bind_bone(b) >= 0 else b
				if b == eye:
					w += wt[i * per + k]
			if w > 0.5:
				if sidx == 1:
					patch_min = patch_min.min(v[i])
					patch_max = patch_max.max(v[i])
					np += 1
				else:
					bulb_min = bulb_min.min(v[i])
					bulb_max = bulb_max.max(v[i])
					n += 1
	if np > 20 and n > 20:
		c = (patch_min + patch_max) * 0.5                                            # the middle of the model's own eye
		_front = maxf(c.z - bulb_min.z, 0.0) + 0.06                                  # the bulb faces -Z: the beam leaves its front, a little outside it
		_ball_r = 0.5 * minf(patch_max.x - patch_min.x, patch_max.y - patch_min.y) * 0.8
	elif n > 20:
		c = Vector3((bulb_min.x + bulb_max.x) * 0.5, (bulb_min.y + bulb_max.y) * 0.5, bulb_min.z - 0.02)
		_ball_r = 0.5 * maxf(bulb_max.x - bulb_min.x, bulb_max.y - bulb_min.y) * 0.9
	return c


func _build_ball() -> void:
	var centre := _pod_centre()
	_ball_local = skel.get_bone_global_rest(eye).affine_inverse() * centre
	ball = Node3D.new()
	ball.name = "Eyeball"
	ball.top_level = true                                         # placed every frame from the pod's own pose, so it never lags the socket
	add_child(ball)
	ball_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = _ball_r
	sm.height = _ball_r * 2.0
	sm.radial_segments = 16
	sm.rings = 10
	ball_mesh.mesh = sm
	_ball_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BALL_SHADER
	_ball_mat.shader = sh
	ball_mesh.material_override = _ball_mat
	ball_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.add_child(ball_mesh)
	glow = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(_ball_r * 3.4, _ball_r * 3.4)
	glow.mesh = gq
	_glow_mat = ShaderMaterial.new()
	var gsh := Shader.new()
	gsh.code = GLOW_SHADER
	_glow_mat.shader = gsh
	glow.material_override = _glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.extra_cull_margin = 100.0
	ball.add_child(glow)
	glow.position = Vector3(0, 0, -_ball_r * 1.02)
	ball_mesh.visible = show_ball
	glow.visible = show_ball
	aim_point = Marker3D.new()
	aim_point.name = "AimPoint"
	ball.add_child(aim_point)
	aim_point.position = Vector3(0, 0, -_front)                  # the front of the pod's bulb: the beam starts there
	# the pod's own glowing patch IS the eye now: its texture, made emissive (the brightness follows `level` and the lock, see _process)
	if mesh and mesh.mesh and mesh.mesh.get_surface_count() > 1:
		var src := mesh.mesh.surface_get_material(1) as StandardMaterial3D
		if src != null:
			_patch_mat = src.duplicate() as StandardMaterial3D
			_patch_mat.emission_enabled = true
			_patch_mat.emission_texture = _patch_mat.albedo_texture
			_patch_mat.emission = Color(1, 1, 1)
			_patch_mat.emission_energy_multiplier = 1.0
			mesh.set_surface_override_material(1, _patch_mat)


func _build_light() -> void:
	# the pool of light: a spot that casts shadows (walls, props and pavement break it up), a child of the eyeball so it is always where the pupil points
	spot = SpotLight3D.new()
	spot.name = "SearchSpot"
	spot.light_color = Color(1.0, 0.72, 0.4)
	spot.spot_range = RANGE_M
	spot.spot_angle = _spot_deg
	spot.spot_attenuation = 0.45
	spot.light_energy = 0.0
	spot.shadow_enabled = true
	spot.shadow_bias = 0.08
	ball.add_child(spot)
	spot.position = Vector3(0, 0, -_front)
	omni = OmniLight3D.new()
	omni.light_color = Color(1.0, 0.55, 0.18)
	omni.omni_range = 16.0 * minf(maxf(skel.global_transform.basis.get_scale().x, 1.0), 4.0)
	omni.shadow_enabled = false
	add_child(omni)
	# the beam in the mist: two nested soft cones (a wide soft one, a narrow bright core), drawn from the beam's own geometry
	cone = _make_cone(false)
	core = _make_cone(true)


func _make_cone(is_core: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 5.0
	cm.height = 10.0
	cm.radial_segments = 14
	cm.rings = 1
	mi.mesh = cm
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CONE_SHADER
	mat.shader = sh
	mat.set_shader_parameter("sharp", 14.0 if is_core else 3.2)
	mat.set_shader_parameter("tint", Vector3(1.0, 0.95, 0.8) if is_core else Vector3(1.0, 0.7, 0.36))
	mi.material_override = mat
	mi.top_level = true
	mi.visible = false
	mi.extra_cull_margin = 2000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if is_core:
		_core_mat = mat
	else:
		_cone_mat = mat
	return mi


func eye_world_pos() -> Vector3:
	return ball.global_position if ball else skel.global_transform * skel.get_bone_global_pose(eye).origin


func _model_scale() -> float:
	return maxf(skel.global_transform.basis.get_scale().x, 1.0)


# ------------------------------------------------------------------ stages
func _on_target_changed() -> void:
	if target is Camera3D:
		if stage == Stage.SEARCH:
			_enter(Stage.ALERT)
	else:
		if stage != Stage.SEARCH:
			_enter(Stage.SEARCH)


func _enter(s: int) -> void:
	stage = s
	_stage_t = 0.0
	(report["stage_log"] as Array).append([s, snappedf(_t, 0.01)])
	if s == Stage.ALERT:
		_gv = Vector3.ZERO
		report["overshoot"] = 0.0
	elif s == Stage.LOCK:
		_still = 1.4                                      # the body is unusually still for a beat: it has seen them
	elif s == Stage.SEARCH:
		_step = 0
		_wait = 0.4


func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _begin_move(to: Vector2, length: float) -> void:
	_from = _off
	_to = to
	_mv_t = 0.0
	_mv_len = length


## Search: hold a direction, a quick small correction, hold a moment, then a sweep across a wider angle; the pauses are uneven.
func _search_step(dt: float) -> void:
	if _mv_len > 0.0:
		_mv_t += dt
		_off = _from.lerp(_to, _smooth(_mv_t / _mv_len))
		if _mv_t >= _mv_len:
			_mv_len = 0.0
		return
	_wait -= dt
	if _wait > 0.0:
		return
	match _step:
		0:                                                # the quick, small correction
			_begin_move(_off + Vector2(_rng.randf_range(-0.07, 0.07), _rng.randf_range(-0.035, 0.035)), 0.09)
			_wait = _rng.randf_range(0.35, 1.1)
			_step = 1
		1:                                                # the wider sweep, never the same way twice
			_last_sweep = -signf(_last_sweep) if _rng.randf() < 0.7 else signf(_last_sweep)
			_begin_move(Vector2(_last_sweep * _rng.randf_range(0.3, 0.55), _rng.randf_range(-0.09, 0.09)), _rng.randf_range(0.9, 1.5))
			_wait = _rng.randf_range(0.5, 2.0)
			_step = 2
		_:
			_wait = _rng.randf_range(0.2, 0.9)            # a hold, then round again
			_step = 0


func _dir_to(p: Vector3, from: Vector3) -> Vector3:
	var d := p - from
	return d.normalized() if d.length() > 0.001 else _gaze


func _rotate_dir(d: Vector3, off: Vector2) -> Vector3:
	var right := d.cross(Vector3.UP)
	if right.length() < 0.05:
		right = Vector3.RIGHT
	right = right.normalized()
	return d.rotated(Vector3.UP, off.x).rotated(right, off.y).normalized()


func _process(delta: float) -> void:
	if skel == null or eye < 0 or ball == null:
		return
	_t += delta
	_stage_t += delta
	if not _inited:
		_inited = true
		var f0 := _rest_forward()
		_gz = f0
		_gaze = f0
		_pod = f0
	skel.force_update_all_bone_transforms()
	var sc0 := _model_scale()
	ball.global_position = skel.global_transform * (skel.get_bone_global_pose(eye) * _ball_local)
	var pos := ball.global_position
	# ---- where it wants to look
	var want := _gaze
	if target != null:
		var tdir := _dir_to(target.global_position, pos)
		match stage:
			Stage.SEARCH:
				_search_step(delta)
				want = _rotate_dir(tdir, _off)
				_gz = _gz.lerp(want, 1.0 - exp(-30.0 * delta))        # saccades are quick
				_gv = Vector3.ZERO
			Stage.ALERT:
				# an under-damped spring on the direction: the eye reaches the target first, sweeps slightly past it, stops, and snaps back
				var w := 9.0
				var z := 0.5
				var acc := (tdir - _gz) * w * w - _gv * 2.0 * z * w
				_gv += acc * delta
				_gz += _gv * delta
				want = _gz.normalized()
				if _stage_t > 0.2 and _gv.dot(tdir - _gz) > 0.0 and (want - tdir).length() > float(report["overshoot"]):
					report["overshoot"] = (want - tdir).length()                    # the farthest it swept past the target (chord length ~ radians)
				if _stage_t > 1.0 and (want - tdir).length() < 0.02 and _gv.length() < 0.6:
					_enter(Stage.LOCK)
			Stage.LOCK:
				# the bright centre stays on the target, with small tracking corrections
				_micro_t -= delta
				if _micro_t <= 0.0:
					_micro_t = _rng.randf_range(0.25, 0.6)
					_micro = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * deg_to_rad(0.35)
				want = _rotate_dir(tdir, _micro)
				_gz = _gz.lerp(want, 1.0 - exp(-14.0 * delta))
				_gv = Vector3.ZERO
	else:
		var fwd0 := _pod_forward()
		_gz = _gz.lerp(fwd0, 1.0 - exp(-3.0 * delta))
	_gaze = _gz.normalized()
	# ---- the pod (the neck) follows a beat later; the eyeball turns inside it
	var pod_goal := _gaze
	var f_rest := _rest_forward()
	var ang := f_rest.angle_to(pod_goal)
	if ang > max_angle:
		pod_goal = f_rest.slerp(pod_goal, max_angle / ang)
	var lag := 0.45 if stage != Stage.SEARCH else 0.9
	_pod = _pod.slerp(pod_goal, 1.0 - exp(-delta / lag)).normalized()
	_apply_pod(f_rest)
	# the eyeball: exactly where it looks, within its range inside the socket
	var pod_fwd := _pod
	var ball_goal := _gaze
	var rel := pod_fwd.angle_to(ball_goal)
	if rel > BALL_RANGE:
		ball_goal = pod_fwd.slerp(ball_goal, BALL_RANGE / rel)
	var up := Vector3.UP if absf(ball_goal.y) < 0.95 else Vector3.RIGHT
	skel.force_update_all_bone_transforms()
	ball.global_position = skel.global_transform * (skel.get_bone_global_pose(eye) * _ball_local)
	ball.global_basis = Basis.looking_at(ball_goal, up).scaled(Vector3.ONE * sc0)
	pos = ball.global_position
	# ---- the torso follows a beat after the neck, a little, when the turn is large; the body holds still for a beat at the lock
	_apply_body(delta, ang)
	# ---- light and glow
	var pulse := 0.9 + 0.06 * sin(_t * 2.4) + 0.03 * sin(_t * 9.7)
	_hot = move_toward(_hot, 1.0 if (stage == Stage.LOCK or beam_on) else 0.0, delta * 3.0)
	_search_k = move_toward(_search_k, 1.0 if search_on else 0.0, delta * 2.5)
	_ball_mat.set_shader_parameter("k", (0.75 + 0.5 * _hot) * pulse * clampf(level, 0.0, 2.0) * 0.8 + 0.2)
	_ball_mat.set_shader_parameter("hot", _hot)
	_glow_mat.set_shader_parameter("k", (0.35 + 0.6 * _hot) * pulse * clampf(level, 0.0, 2.0) * 0.8)
	if _patch_mat != null:
		_patch_mat.emission_energy_multiplier = (0.5 + 1.8 * maxf(_search_k * 0.5, _hot)) * pulse * clampf(level, 0.0, 2.0)
	omni.global_position = pos + ball_goal * _ball_r * 2.0
	omni.light_energy = (0.5 + 2.2 * _hot) * pulse * level
	# the spot: steady while it searches (its brightness does not follow the twitching), brighter once locked
	var sc := _model_scale()
	spot.light_energy = (7.0 + 5.0 * _hot) * _search_k * clampf(level, 0.3, 2.0)
	if _search_k > 0.01 or _hot > 0.01:
		_update_cone(pos, ball_goal, sc)
	else:
		cone.visible = false
		core.visible = false


func _rest_forward() -> Vector3:
	var b := skel.get_bone_parent(eye)
	var pg := skel.get_bone_global_pose(b)
	var base := pg.basis * skel.get_bone_rest(eye).basis
	return (skel.global_transform.basis * (base * (skel.get_bone_global_rest(eye).basis.inverse() * Vector3(0, 0, -1)))).normalized()


func _pod_forward() -> Vector3:
	return _pod


## The pod turns toward `_pod` (relative to the bone's own parent), a beat after the eyeball.
func _apply_pod(f_rest: Vector3) -> void:
	var b := skel.get_bone_parent(eye)
	var pgb := skel.get_bone_global_pose(b).basis
	var rest_local := skel.get_bone_rest(eye).basis
	var gb := skel.global_transform.basis
	var f_rest_sk := (gb.inverse() * f_rest).normalized()
	var want_sk := (gb.inverse() * _pod).normalized()
	var q := Quaternion(f_rest_sk, want_sk)
	# the pod turns by q in the skeleton's frame, from its REST orientation (the bone's pose is its whole local rotation, rest included)
	skel.set_bone_pose_rotation(eye, (pgb.inverse() * Basis(q) * pgb * rest_local).get_rotation_quaternion())


func _apply_body(delta: float, pod_angle: float) -> void:
	if body < 0:
		return
	var want := 0.0
	if _still <= 0.0 and pod_angle > 0.7:
		want = clampf((pod_angle - 0.7) * 0.4, 0.0, 0.14) * signf(_pod.cross(_rest_forward()).y)
	_body_yaw = lerpf(_body_yaw, want, 1.0 - exp(-delta / 0.8))
	var cur := skel.get_bone_pose_rotation(body)
	var base := _body_base if cur.is_equal_approx(_body_written) else cur
	_body_base = base
	var q := (Quaternion(Vector3.UP, _body_yaw) * base).normalized()
	skel.set_bone_pose_rotation(body, q)
	_body_written = q
	# the unusually still beat: the idle sway all but stops for a moment, then goes back to whatever speed the scene had
	if _ap:
		if _still > 0.0:
			if not _held:
				_held = true
				_prev_ap_scale = _ap.speed_scale
			_ap.speed_scale = 0.12
			_still -= delta
		elif _held:
			_held = false
			if is_equal_approx(_ap.speed_scale, 0.12):
				_ap.speed_scale = _prev_ap_scale


func _update_cone(pos: Vector3, fwd: Vector3, sc: float) -> void:
	var p0: Vector3 = aim_point.global_position
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p0, p0 + fwd * RANGE_M, 1)
	var hit := space.intersect_ray(q)
	var length := RANGE_M
	if not hit.is_empty():
		length = (hit["position"] as Vector3).distance_to(p0) + 0.4          # the visible beam ends where the light lands
	elif fwd.y < -0.02:
		length = minf(RANGE_M, (p0.y - ground_y) / -fwd.y)
	length = maxf(length, 1.0)
	var tan_a := tan(deg_to_rad(_spot_deg)) * 0.95
	var r0 := _ball_r * 0.55 * sc
	for pair in [[cone, _cone_mat, 1.0], [core, _core_mat, 0.55]]:
		var mi: MeshInstance3D = pair[0]
		var mat: ShaderMaterial = pair[1]
		var cm := mi.mesh as CylinderMesh
		var rr: float = (r0 + length * tan_a) * 1.05
		cm.height = length
		cm.top_radius = r0 * 1.05
		cm.bottom_radius = rr
		mi.global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN, fwd)), p0 + fwd * length * 0.5)
		mat.set_shader_parameter("p0", p0)
		mat.set_shader_parameter("axis", fwd)
		mat.set_shader_parameter("r0", r0)
		mat.set_shader_parameter("tan_a", tan_a)
		mat.set_shader_parameter("len", length)
		mat.set_shader_parameter("k", float(pair[2]) * maxf(_search_k, _hot * 0.8) * (0.8 + 0.35 * _hot))
		mi.visible = true
	report["beam_len"] = length
