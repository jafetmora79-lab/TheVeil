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

const SINK := Vector3(-0.6, 0.6, 9.805)
const SINK_STAND := Vector3(-0.55, 0.6, 10.45)
const MIRROR_CAB := Vector3(-0.6, 2.0, 9.632)          # on the door wall (z 9.5), above the sink, facing +z
const TOWEL_RACK := Vector3(-0.888, 1.8, 10.9)         # side wall (x -1.0), facing +x, above the tub end
const ROUTE := [Vector3(-0.4, 0.6, 7.5), Vector3(-1.6, 0.6, 7.5), Vector3(-1.7, 0.6, 8.95), Vector3(-0.6, 0.6, 8.95),
	Vector3(0.2, 0.6, 9.1), Vector3(0.2, 0.6, 9.95), SINK_STAND]
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
		rack.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), TOWEL_RACK)
	var cab := furn.get_node_or_null("MedicineCabinet_01") as Node3D
	if cab:
		cab.transform = Transform3D(Basis(), MIRROR_CAB)
		_make_mirror(cab)
	report["layout_fixed"] = rack != null and cab != null


func _make_mirror(cab: Node3D) -> void:
	var box := Interactable.aabb_of(cab)                 # world AABB of the cabinet (axis-aligned: it faces +z)
	if box.size.length() < 0.01:
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
	qm.size = Vector2(box.size.x * 0.78, box.size.y * 0.78)
	mirror_quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = mirror_vp.get_texture()
	mat.uv1_scale = Vector3(-1, 1, 1)                  # mirrored left-right
	mat.uv1_offset = Vector3(1, 0, 0)
	mirror_quad.material_override = mat
	mirror_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	home.add_child(mirror_quad)
	var c := box.get_center()
	var normal := home.global_basis * Vector3(0, 0, 1)
	mirror_quad.global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP), Vector3(c.x, c.y, box.end.z) + normal * 0.004)
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
	# at the sink: look down at the basin, the tap runs, two splashes
	var basin := home.to_global(SINK + Vector3(0, 0.85, 0))
	await _look(cam, basin, 0.6)
	Sfx.play("water_run", basin, -6.0)
	var base_pos := cam.global_position
	for k in 2:
		var tw := create_tween()
		tw.tween_property(cam, "global_position", base_pos + Vector3(0, -0.22, 0) + (basin - base_pos).normalized() * 0.12, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(cam, "global_position", base_pos, 0.45).set_trans(Tween.TRANS_SINE)
		await tw.finished
		Sfx.play("splash", basin, -4.0)
	await get_tree().create_timer(0.3).timeout
	# look up into the mirror: the reflection (a stand-in on visual layer 2, where the protagonist stands)
	var me: Node3D = world.call("_spawn_npc", load(PROTAG), load(PROTAG_FACE), home, SINK_STAND, 0.0, "Protagonist")
	if me:
		world.call("_cine_double", me, home.to_global(SINK_STAND))
		for mi in me.find_children("*", "VisualInstance3D", true, false):
			(mi as VisualInstance3D).layers = 2
		var a = world.get("animators").get("Protagonist")
		if a:
			a.turn_to_face = false
			a.face_towards(mirror_quad.global_position if mirror_quad else basin)
	report["reflection"] = me != null
	if mirror_vp:
		mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await _look(cam, (mirror_quad.global_position if mirror_quad else basin + Vector3(0, 0.6, 0)), 0.9)
	await get_tree().create_timer(2.2).timeout
	# back to the player, turned towards the bathroom door
	if me:
		world.get("animators").erase("Protagonist")
		world.get("faces").erase("Protagonist")
		me.queue_free()
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
