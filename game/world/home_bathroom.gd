extends Node
class_name VeilHomeBathroom
## THE VEIL - the player home's bathroom (Pack 03 Player_Home, room BATH: x -1.0..1.4, z 9.5..11.6, floor 0.6).
## 1. Layout: the towel rack hung on the door wall right in front of the doorway (floating in front of the door) and
##    the mirror cabinet sat on the far wall over the toilet. The rack goes onto the side wall by the tub; the mirror
##    cabinet goes on the wall straight above the pedestal sink at eye height.
## 2. A working mirror: the cabinet's glass shows a low-res camera view of the room (flipped like a mirror), only
##    rendered while the player is near the bathroom.
## 3. First day, after waking up: a short first-person cinematic - to the bathroom, wash the face at the sink, look up
##    into the mirror (the protagonist's reflection), then control (and the "something to eat" hint) comes back.
## All positions are in the home's frame.

## Room walls (home frame): x -1.0 (left as you come in: the side the door swings to; hinge x -0.19) .. 1.4,
## z 9.5 (door wall) .. 11.6 (back wall), floor 0.6.
const WALL_L := -1.0
const WALL_R := 1.4
const WALL_BACK := 11.6
const FLOOR := 0.6
const SINK_Z := 11.0                                  # the right wall (the back wall has the window)
const SINK_STAND := Vector3(0.6, 0.6, 11.0)           # in front of the sink, facing the mirror (+x)
const TOWEL_RACK := Vector3(1.288, 1.8, 10.1)         # right wall above the toilet, facing -x
const ROUTE := [Vector3(-0.4, 0.6, 7.5), Vector3(-1.6, 0.6, 7.5), Vector3(-1.7, 0.6, 8.95), Vector3(-0.6, 0.6, 8.95),
	Vector3(0.25, 0.6, 9.1), Vector3(0.35, 0.6, 10.1), Vector3(0.5, 0.6, 10.7), SINK_STAND]
const EYE := 1.62
const PROTAG := "res://THE_VEIL_ASSETS_V2/06_Characters/Protagonist/CHR_Protagonist.glb"
const PROTAG_FACE := "res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Protagonist.png"

var world: Node
var home: Node3D
var mirror_vp: SubViewport
var mirror_cam: Camera3D
var mirror_quad: MeshInstance3D
var report := {}


func setup(w: Node, h: Node3D) -> void:
	world = w
	home = h
	var furn := home.get_node_or_null("Furniture")
	if furn == null:
		return
	var rack := furn.get_node_or_null("TowelRack_01") as Node3D
	if rack:
		rack.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), TOWEL_RACK)
		_flush(rack, "x+", WALL_R)                     # flat against the wall, not floating off it
	# the tub along the left wall (its back to the wall), from the back wall forwards
	var tub := furn.get_node_or_null("Bathtub_01") as Node3D
	if tub:
		tub.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(WALL_L + 0.5, FLOOR, 10.6))
		_flush(tub, "x-", WALL_L)
		_flush(tub, "z+", WALL_BACK)
	# the sink and the mirror cabinet on the right wall (no window behind it), facing into the room (-x)
	var sink := furn.get_node_or_null("BathSink_Pedestal_01") as Node3D
	if sink:
		sink.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(WALL_R - 0.3, FLOOR, SINK_Z))
		_flush(sink, "x+", WALL_R)
		_center_z(sink, SINK_Z)
	var cab := furn.get_node_or_null("MedicineCabinet_01") as Node3D
	if cab:
		cab.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(WALL_R - 0.13, FLOOR + 1.3, SINK_Z))
		_flush(cab, "x+", WALL_R)
		_center_z(cab, SINK_Z)
		var lb := _local_box(cab)                       # its glass from 1.3 m above the floor: eye level inside it
		cab.position.y += (FLOOR + 1.3) - lb.position.y
		_make_mirror(cab)
	report["sink_on_back_wall"] = sink != null
	report["tub_on_left_wall"] = tub != null
	report["layout_fixed"] = rack != null and cab != null and tub != null and sink != null


## The piece's bounding box in the home's frame.
func _local_box(n: Node3D) -> AABB:
	# aabb_of is in the node's own frame: bring it into the home's frame
	return (home.global_transform.affine_inverse() * n.global_transform) * Interactable.aabb_of(n)


## Slide a piece so the given side of its box touches a wall ("x-": its min x on x; "z+": its max z on z).
func _flush(n: Node3D, side: String, at: float) -> void:
	var b := _local_box(n)
	match side:
		"x-":
			n.position.x += (at + 0.005) - b.position.x
		"x+":
			n.position.x += (at - 0.005) - b.end.x
		"z+":
			n.position.z += (at - 0.005) - b.end.z
		"z-":
			n.position.z += (at + 0.005) - b.position.z


func _center_z(n: Node3D, z: float) -> void:
	var b := _local_box(n)
	n.position.z += z - b.get_center().z


func _center_x(n: Node3D, x: float) -> void:
	var b := _local_box(n)
	n.position.x += x - b.get_center().x


func _make_mirror(cab: Node3D) -> void:
	var lb := _local_box(cab)                            # the cabinet on the back wall, facing -z (into the room)
	if lb.size.length() < 0.01:
		return
	mirror_vp = SubViewport.new()
	mirror_vp.name = "BathMirror_View"
	mirror_vp.size = Vector2i(192, 256)
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mirror_vp)                                 # no own world: it renders the game world
	mirror_cam = Camera3D.new()
	mirror_cam.fov = 62.0
	mirror_cam.near = 0.05
	mirror_cam.far = 30.0
	mirror_vp.add_child(mirror_cam)
	mirror_quad = MeshInstance3D.new()
	mirror_quad.name = "BathMirror_Glass"
	var qm := QuadMesh.new()
	qm.size = Vector2(lb.size.z * 0.78, lb.size.y * 0.78)
	mirror_quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = mirror_vp.get_texture()
	mat.uv1_scale = Vector3(-1, 1, 1)                  # mirrored left-right
	mat.uv1_offset = Vector3(1, 0, 0)
	mirror_quad.material_override = mat
	mirror_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	home.add_child(mirror_quad)
	var c := lb.get_center()
	var normal := (home.global_basis * Vector3(-1, 0, 0)).normalized()
	var front := home.to_global(Vector3(lb.position.x, c.y, c.z))
	mirror_quad.global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP), front + normal * 0.004)
	mirror_cam.global_transform = Transform3D(Basis(), mirror_quad.global_position + normal * 0.03).looking_at(
		mirror_quad.global_position + normal * 5.0, Vector3.UP)
	report["mirror"] = true


func _process(_delta: float) -> void:
	if mirror_vp == null or world == null:
		return
	var p: Node3D = world.get("player")
	var cam := get_viewport().get_camera_3d()
	var near := false
	for n in [p, cam]:
		if n and is_instance_valid(n) and (n as Node3D).global_position.distance_to(mirror_quad.global_position) < 4.0:
			near = true
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if near else SubViewport.UPDATE_DISABLED
	_update_reflection(p, cam, near and p != null and p.visible)


# ------------------------------------------------------------------ the protagonist's reflection
## The player has no visible body, so a stand-in of the protagonist stands where the player stands and turns the way
## the view looks, on visual layer 2: the player's cameras do not draw layer 2, only the mirror's camera does. It
## looks at the mirror, so the reflection looks back.
var refl: Node3D
var refl_anim: Node


func _update_reflection(p: Node3D, cam: Camera3D, on: bool) -> void:
	if on and refl == null:
		refl = world.call("_spawn_npc", load(PROTAG), load(PROTAG_FACE), home, home.to_local(p.global_position), 0.0, "Reflection")
		if refl == null:
			return
		world.call("_cine_double", refl, p.global_position)
		for vi in refl.find_children("*", "VisualInstance3D", true, false):
			(vi as VisualInstance3D).layers = 2
		refl_anim = world.get("animators").get("Reflection")
		if refl_anim:
			refl_anim.turn_to_face = false
			refl_anim.look_target = mirror_quad
		var pc: Camera3D = p.get("camera")
		if pc:
			pc.cull_mask = pc.cull_mask & ~2
		report["reflection"] = true
	if refl == null:
		return
	refl.visible = on
	if not on:
		return
	refl.global_position = Vector3(p.global_position.x, p.global_position.y, p.global_position.z)
	if cam and refl_anim:
		var f := -cam.global_basis.z
		f.y = 0.0
		if f.length() > 0.01:
			refl.rotate_y(refl_anim.world_forward().signed_angle_to(f.normalized(), Vector3.UP))


# ------------------------------------------------------------------ first day: wash the face
func wash_face() -> void:
	var player: Node3D = world.get("player")
	if player == null or Game.has_flag("washed_face"):
		return
	player.set("controls_enabled", false)
	player.set("velocity", Vector3.ZERO)
	var src: Camera3D = player.get("camera")
	var cam := Camera3D.new()
	cam.name = "WashFaceCam"
	world.add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.cull_mask = cam.cull_mask & ~2                  # the reflection double (layer 2) is only seen in the mirror
	cam.current = true
	# the doors on the way are opened (the bedroom and the bathroom)
	var its: Dictionary = world.get("interactables")
	for k in ["home/INT_Door_Bedroom", "home/INT_Door_Bathroom"]:
		var it = its.get(k)
		if it and it.has_method("set_open") and not it.get("is_open"):
			it.set_open(true)
	await get_tree().create_timer(0.4).timeout
	player.set_physics_process(false)
	for q in ROUTE:
		await _step_to(player, cam, home.to_global(q), 1.5)
	# at the sink: look down at the basin; the tap runs (a visible stream); his hands cup the water and bring it
	# up to his face, twice (first-person arms, posed towards hand targets; splash droplets at the face)
	var sink_box := _local_box(home.get_node("Furniture/BathSink_Pedestal_01"))
	var tap := home.to_global(Vector3(sink_box.end.x - 0.1, sink_box.end.y + 0.06, sink_box.get_center().z))
	var basin := home.to_global(Vector3(sink_box.get_center().x, sink_box.end.y - 0.05, sink_box.get_center().z))
	await _look(cam, basin, 0.6)
	var stream := _water_stream(tap, basin)
	Sfx.play("water_run", basin, -6.0)
	var arms := _fp_arms(cam)
	var base_pos := cam.global_position
	var cup := (tap + basin) * 0.5 + Vector3(0, -0.02, 0)
	for k in 2:
		# hands down under the tap
		await _arms_to(arms, cam, func(): return cup, 0.45)
		await get_tree().create_timer(0.35).timeout
		# up to the face, the head dips to meet them
		var tw := create_tween()
		tw.tween_property(cam, "global_position", base_pos + Vector3(0, -0.16, 0) + (basin - base_pos).normalized() * 0.1, 0.4).set_trans(Tween.TRANS_SINE)
		await _arms_to(arms, cam, func(): return cam.global_position - cam.global_basis.z * 0.13 - cam.global_basis.y * 0.04, 0.4)
		Sfx.play("splash", cam.global_position, -3.0)
		_splash(cam.global_position - cam.global_basis.z * 0.12)
		await get_tree().create_timer(0.25).timeout
		var tb := create_tween()
		tb.tween_property(cam, "global_position", base_pos, 0.45).set_trans(Tween.TRANS_SINE)
	await _arms_to(arms, cam, func(): return cup + Vector3(0, 0.05, 0), 0.4)
	stream.emitting = false                              # the tap is turned off
	if arms:
		arms.queue_free()
	report["hands_and_water"] = arms != null
	await get_tree().create_timer(0.3).timeout
	# look up into the mirror: his reflection (the stand-in that follows the player near the mirror)
	if mirror_vp:
		mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var face_fx = world.get("faces").get("Reflection")
	if face_fx and face_fx.has_method("set_expression"):
		face_fx.set_expression("neutral")
	await _look(cam, (mirror_quad.global_position if mirror_quad else basin + Vector3(0, 0.6, 0)), 0.9)
	await get_tree().create_timer(1.6).timeout          # his own face in the mirror, water still on it
	Dialogue.say("wash_hungry", true)
	await get_tree().create_timer(2.4).timeout
	# back to the player, turned towards the bathroom door
	player.global_position = home.to_global(SINK_STAND)
	var to_door := home.to_global(Vector3(0.2, 0.6, 9.5)) - player.global_position
	player.call("set_yaw_pitch", atan2(-to_door.x, -to_door.z), 0.0)
	var tb := create_tween()
	tb.tween_property(cam, "global_transform", src.global_transform, 0.6).set_trans(Tween.TRANS_SINE)
	await tb.finished
	player.set_physics_process(true)
	cam.queue_free()
	src.current = true
	player.set("controls_enabled", true)
	Game.set_flag("washed_face")
	report["washed"] = true


# ------------------------------------------------------------------ water and hands
func _water_stream(tap: Vector3, basin: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "TapWater"
	p.amount = 90
	p.lifetime = maxf(sqrt(2.0 * maxf(tap.y - basin.y, 0.05) / 9.8), 0.12)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.008
	p.direction = Vector3.DOWN
	p.spread = 2.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	var qm := QuadMesh.new()
	qm.size = Vector2(0.018, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_color = Color(0.72, 0.82, 0.9, 0.55)
	qm.material = mat
	p.mesh = qm
	add_child(p)
	p.global_position = tap
	p.emitting = true
	return p


func _splash(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 40
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, -6.0, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.8, 0.88, 0.95, 0.7)
	qm.material = mat
	p.mesh = qm
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


const ARMS := "res://THE_VEIL_ASSETS_V2/06_Characters/Protagonist/CHR_Protagonist_FP_Arms.glb"
## The protagonist's first-person arms (Pack 06, T-pose rig, no animations), hung under the camera: the shoulders
## just below and behind the eyes. Posed by _pose_arms (two-bone reach towards hand targets).
func _fp_arms(cam: Camera3D) -> Node3D:
	if not ResourceLoader.exists(ARMS):
		return null
	var a := (load(ARMS) as PackedScene).instantiate() as Node3D
	cam.add_child(a)
	# the rig's shoulders are at ~1.36 m: put them 0.2 m below and 0.12 m behind the eyes; facing the view (-Z)
	a.position = Vector3(0, -1.56, 0.12)
	var sk := a.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# which way the model faces: the side its toes point to
	var toe := sk.get_bone_global_rest(sk.find_bone("LeftToes")).origin - sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin
	if toe.z > 0.0:
		a.rotation.y = PI                               # model faces +Z: turn it to face the camera's -Z
	for vi in a.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = 1
	a.set_meta("sk", sk)
	return a


func _arms_to(arms: Node3D, cam: Camera3D, target: Callable, seconds: float) -> void:
	if arms == null:
		await get_tree().create_timer(seconds).timeout
		return
	var from: Vector3 = arms.get_meta("hands", target.call())
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		var k := clampf(t / seconds, 0.0, 1.0)
		var h: Vector3 = from.lerp(target.call(), k * k * (3.0 - 2.0 * k))
		_pose_arms(arms, cam, h)
		await get_tree().process_frame
	arms.set_meta("hands", target.call())


## Two-bone reach: each arm's upper and lower bone are turned (from their rest directions) so the hand lands near
## `centre` (the two hands side by side, cupped together).
func _pose_arms(arms: Node3D, cam: Camera3D, centre: Vector3) -> void:
	var sk: Skeleton3D = arms.get_meta("sk")
	var side := cam.global_basis.x.normalized()
	for s in [["Left", -1.0], ["Right", 1.0]]:
		var u := sk.find_bone(s[0] + "UpperArm")
		var l := sk.find_bone(s[0] + "LowerArm")
		var hnd := sk.find_bone(s[0] + "Hand")
		if u < 0 or l < 0 or hnd < 0:
			continue
		var X := sk.global_transform
		var inv := X.affine_inverse()
		var shoulder := X * sk.get_bone_global_rest(u).origin
		var la := (sk.get_bone_global_rest(l).origin - sk.get_bone_global_rest(u).origin).length() * X.basis.get_scale().x
		var lb := (sk.get_bone_global_rest(hnd).origin - sk.get_bone_global_rest(l).origin).length() * X.basis.get_scale().x
		var goal: Vector3 = centre + side * float(s[1]) * 0.045
		var to_goal := goal - shoulder
		var dist := clampf(to_goal.length(), 0.05, (la + lb) * 0.999)
		var dir := to_goal.normalized()
		# elbow: bent outward and down from the shoulder-hand line
		var bend := (side * float(s[1]) - Vector3.UP * 0.6).normalized()
		bend = (bend - dir * bend.dot(dir)).normalized()
		var a := acos(clampf((la * la + dist * dist - lb * lb) / (2.0 * la * dist), -1.0, 1.0))
		var elbow := shoulder + (dir * cos(a) + bend * sin(a)) * la
		var hand := shoulder + dir * dist
		_aim_bone(sk, u, l, inv * shoulder, inv * elbow)
		_aim_bone(sk, l, hnd, inv * elbow, inv * hand)


func _aim_bone(sk: Skeleton3D, b: int, child: int, from_sk: Vector3, to_sk: Vector3) -> void:
	var rest := sk.get_bone_global_rest(b)
	var rest_dir := (sk.get_bone_global_rest(child).origin - rest.origin).normalized()
	var want := (to_sk - from_sk).normalized()
	var q := Quaternion(rest_dir, want) if rest_dir.dot(want) > -0.999 else Quaternion(Vector3.UP, PI)
	sk.set_bone_global_pose_override(b, Transform3D(Basis(q) * rest.basis, from_sk), 1.0, true)


func _step_to(player: Node3D, cam: Camera3D, target: Vector3, speed: float) -> void:
	while true:
		var d := (target - player.global_position) * Vector3(1, 0, 1)
		if d.length() < 0.05:
			return
		var dt := get_process_delta_time()
		player.global_position += d.normalized() * minf(speed * dt, d.length())
		var want := Transform3D(Basis(), cam.global_position).looking_at(cam.global_position + d.normalized() + Vector3(0, -0.08, 0), Vector3.UP).basis
		cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), minf(dt * 6.0, 1.0)))
		cam.global_position = player.global_position + Vector3(0, EYE - 0.15 + sin(Time.get_ticks_msec() * 0.011) * 0.018, 0)
		await get_tree().process_frame


func _look(cam: Camera3D, at: Vector3, seconds: float) -> void:
	var b0 := cam.global_basis.get_rotation_quaternion()
	var b1 := Transform3D(Basis(), cam.global_position).looking_at(at, Vector3.UP).basis.get_rotation_quaternion()
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		var k := clampf(t / seconds, 0.0, 1.0)
		cam.global_basis = Basis(b0.slerp(b1, k * k * (3.0 - 2.0 * k)))
		await get_tree().process_frame
