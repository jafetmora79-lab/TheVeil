extends SceneTree
## Fixed-camera render of one real house design, same camera/light/resolution for before and after.
## godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://refine/tools/house_compare.gd -- <design> <out.png> <before|after|sides>
const Dressing := preload("res://game/world/house_dressing.gd")
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var house := (load("res://THE_VEIL_ASSETS_V2/03_Residential/House_Variants/%s.tscn" % a[0]) as PackedScene).instantiate() as Node3D
	root.add_child(house)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.16, 0.18, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.32, 0.36, 0.5); env.ambient_light_energy = 0.9
	env.fog_enabled = true; env.fog_light_color = Color(0.28, 0.31, 0.38); env.fog_density = 0.022
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-28, 140, 0); sun.light_color = Color(0.62, 0.68, 0.9); sun.light_energy = 0.8; root.add_child(sun)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(120, 120); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.2, 0.24, 0.17); g.material_override = gm; g.position.y = -0.02; root.add_child(g)
	if a[2] != "before": Dressing.apply(house)
	var cam := Camera3D.new(); cam.fov = 58; root.add_child(cam)
	root.size = Vector2i(1280, 720)
	var views := {"before": [Vector3(-4.8, 1.6, -7.2), Vector3(0.4, 1.5, 1.8)], "after": [Vector3(-4.8, 1.6, -7.2), Vector3(0.4, 1.5, 1.8)]}
	if a[2] == "sides":
		var sheet := Image.create(1280, 720 * 2, false, Image.FORMAT_RGB8)
		var i := 0
		for p in [Vector3(-9, 2.2, 13), Vector3(-9, 2.2, -13), Vector3(13, 2.2, 9), Vector3(-13, 2.2, 9)]:
			cam.look_at_from_position(p, Vector3(0, 1.6, 0))
			for k in 4: await process_frame
			var im := root.get_texture().get_image(); im.convert(Image.FORMAT_RGB8); im.resize(640, 360)
			sheet.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360)); i += 1
		sheet.save_png(ProjectSettings.globalize_path(a[1])); quit(); return
	cam.look_at_from_position(views[a[2]][0], views[a[2]][1])
	for k in 5: await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(a[1]))
	quit()
