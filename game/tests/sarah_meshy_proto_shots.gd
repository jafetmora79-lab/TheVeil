extends SceneTree
## dev tool: the Meshy Sarah prototype in Godot 4.3 (Compatibility) - idle, two walk poses, head turned both ways (needs a window)
##   godot --path . --script res://game/tests/sarah_meshy_proto_shots.gd -- <out_dir>
var out := ""


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	_run.call_deferred()


func _run() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.21, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 145, 0)      # from in front of her (she faces -Z)
	sun.light_energy = 1.1
	root.add_child(sun)
	var n := VeilSarahMeshyProto.instantiate()
	root.add_child(n)
	n.rotation_degrees.y = 25                        # a little turned, a three-quarter view
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 30.0
	cam.position = Vector3(0, 0.95, -4.5)             # she faces -Z: the camera in front of her, looking toward +Z
	cam.look_at(Vector3(0, 0.88, 0))
	var ap := VeilSarahMeshyProto.anim_player(n)
	var shots := [["idle", 1.0, "idle"], ["walk", 0.25, "walk_a"], ["walk", 0.75, "walk_b"], ["head_turn", 0.8, "head_left"], ["head_turn", 2.3, "head_right"]]
	for s in shots:
		ap.play(s[0])
		ap.seek(s[1], true)
		ap.pause()
		await frames(4)
		root.get_texture().get_image().save_png("%s/godot_%s.png" % [out, s[2]])
	# hand close-ups: her left hand from outside, five poses
	cam.fov = 9.0
	cam.position = Vector3(-2.2, 0.86, -0.02)
	cam.look_at(Vector3(-0.40, 0.86, -0.01))
	n.rotation_degrees.y = 0
	for pose in ["relaxed", "open", "fist", "grip", "point"]:
		ap.play("hand_" + pose)
		ap.seek(0.0, true)
		ap.pause()
		await frames(4)
		root.get_texture().get_image().save_png("%s/godot_hand_%s.png" % [out, pose])
	quit(0)
