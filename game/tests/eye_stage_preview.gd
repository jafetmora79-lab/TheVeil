extends SceneTree
## A small stage for the searchlight eye: the tripod (scale 1, 12 m) facing a wall with crates and a street's worth of fog, a camera on the wall (the light sweeping across it) and
## a camera on the eye (the pupil and iris turning in the socket). Search sweeps for `search` seconds, then the target becomes a camera: alert (a sweep past the target and back),
## then lock. Needs a window.
##   godot --path . --fixed-fps 60 --resolution 640x360 --script res://game/tests/eye_stage_preview.gd -- <out_dir> [search=7] [lock=4] [every=2] [fog=0.012]
var vp_wall: SubViewport
var vp_eye: SubViewport
var cam_wall: Camera3D
var cam_eye: Camera3D
var tc: VeilTripodColossus
var scan: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _box(parent: Node, pos: Vector3, size: Vector3, col: Color) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	parent.add_child(sb)
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mi.material_override = mat
	sb.add_child(mi)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var search_s := 7.0
	var lock_s := 4.0
	var every := 2
	var fog := 0.012
	for e in a:
		var s := String(e)
		if s.begins_with("search="):
			search_s = float(s.substr(7))
		if s.begins_with("lock="):
			lock_s = float(s.substr(5))
		if s.begins_with("every="):
			every = int(s.substr(6))
		if s.begins_with("fog="):
			fog = float(s.substr(4))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.1, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.16, 0.17, 0.2)
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.13, 0.16)
	e.fog_density = fog
	env.environment = e
	root.add_child(env)
	_box(root, Vector3(0, -0.5, -10), Vector3(120, 1, 120), Color(0.16, 0.16, 0.17))            # the street
	_box(root, Vector3(0, 8, -30), Vector3(60, 16, 1), Color(0.34, 0.3, 0.27))                   # the wall
	_box(root, Vector3(-9, 1.2, -27), Vector3(2.4, 2.4, 2.4), Color(0.4, 0.33, 0.22))            # crates in front of it
	_box(root, Vector3(-5.5, 0.9, -27.5), Vector3(1.8, 1.8, 1.8), Color(0.36, 0.3, 0.2))
	_box(root, Vector3(7, 1.5, -26), Vector3(3.0, 3.0, 3.0), Color(0.38, 0.32, 0.22))
	_box(root, Vector3(11, 2.5, -28), Vector3(2.0, 5.0, 2.0), Color(0.3, 0.3, 0.32))              # a post
	tc = VeilTripodColossus.new()
	root.add_child(tc)
	tc.build(12.0, 0.0)
	tc.set_walking(false)
	tc.eye.search_on = true
	tc.eye.max_angle = 1.35
	scan = Node3D.new()
	root.add_child(scan)
	scan.global_position = Vector3(0, 4, -29)
	tc.eye.target = scan
	# the two cameras, each in its own viewport onto this world
	vp_wall = SubViewport.new()
	vp_wall.size = Vector2i(640, 360)
	vp_wall.world_3d = root.world_3d
	vp_wall.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp_wall)
	cam_wall = Camera3D.new()
	cam_wall.fov = 62.0
	cam_wall.far = 400.0
	vp_wall.add_child(cam_wall)
	cam_wall.fov = 72.0
	cam_wall.global_position = Vector3(15, 5.0, -10.0)
	cam_wall.look_at(Vector3(-1, 4.5, -30), Vector3.UP)
	vp_eye = SubViewport.new()
	vp_eye.size = Vector2i(640, 360)
	vp_eye.world_3d = root.world_3d
	vp_eye.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp_eye)
	cam_eye = Camera3D.new()
	cam_eye.fov = 28.0
	cam_eye.far = 400.0
	vp_eye.add_child(cam_eye)
	var eye: VeilTripodEye = tc.eye
	for i in 4:
		await process_frame
	cam_eye.global_position = eye.ball.global_position + Vector3(2.2, 0.35, -4.6)
	cam_eye.look_at(eye.ball.global_position, Vector3.UP)
	var lockcam := Camera3D.new()                                                                          # what it will notice: a camera just beside the one on its eye
	root.add_child(lockcam)
	lockcam.global_position = cam_eye.global_position + Vector3(1.4, 0.2, 0.0)
	var t := 0.0
	var n := 0
	var f := 0
	var locked := false
	var beam_off := false
	var total := search_s + lock_s
	while t < total:
		await process_frame
		t += 1.0 / 60.0
		f += 1
		if t < search_s:
			var k := t / search_s
			scan.global_position = Vector3(lerpf(-14.0, 14.0, k), 4.0 + 1.2 * sin(t * 1.3), -29.0)        # the point the search is built around, drifting along the wall
		elif not locked:
			locked = true
			eye.target = lockcam                                                                                  # it has seen a camera: alert, then lock
		elif locked and not beam_off and t > search_s + 2.6:
			beam_off = true
			eye.search_on = false                                                                                 # the light off: the eyeball alone, locked on, close up
		if f % every == 0:
			await RenderingServer.frame_post_draw
			vp_wall.get_texture().get_image().save_png("%s/wall_%04d.png" % [out, n])
			vp_eye.get_texture().get_image().save_png("%s/eye_%04d.png" % [out, n])
			print("STAGE n %d t %.2f stage %d gaze_deg_from_pod %.1f beam_len %.1f hot %.2f" % [n, t, eye.stage, rad_to_deg(eye._gaze.angle_to(eye._pod)), float(eye.report.get("beam_len", 0.0)), eye._hot])
			n += 1
	print("STAGE report ", eye.report)
	print("RESULT captured ", n)
	quit(0)
