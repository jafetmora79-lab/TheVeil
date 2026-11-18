extends SceneTree
## Contact sheet of a creature clip from the side: godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://refine/tools/hound_sheet.gd -- <scene> <clip> <out.png> [frames]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var m: Node3D = (load(a[0]) as PackedScene).instantiate()
	root.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	print("CLIPS ", ap.get_animation_list())
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.25, 0.27, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.82, 0.9)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 30, 0); root.add_child(sun)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.33, 0.28); g.material_override = gm; root.add_child(g)
	var cam := Camera3D.new(); root.add_child(cam); cam.fov = 40
	cam.look_at_from_position(Vector3(5.5, 1.2, 0), Vector3(0, 0.9, 0))
	root.size = Vector2i(320, 240)
	var n := int(a[3]) if a.size() > 3 else 8
	var clip := a[1]; ap.play(clip); ap.pause()
	var len := ap.get_animation(clip).length
	var sheet := Image.create(320 * 4, 240 * ceili(n / 4.0), false, Image.FORMAT_RGB8)
	for i in n:
		ap.seek(len * i / n, true)
		for k in 3: await process_frame
		var im := root.get_texture().get_image(); im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(0, 0, 320, 240), Vector2i((i % 4) * 320, (i / 4) * 240))
	sheet.save_png(ProjectSettings.globalize_path(a[2]))
	quit()
