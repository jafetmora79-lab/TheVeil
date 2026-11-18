extends SceneTree
## Cutaway of one house design (exterior hidden) from above, to judge floors, stairs and holes. Args: <design> <out.png> [mirror]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var n: Node3D = (load("res://THE_VEIL_ASSETS_V2/03_Residential/House_Variants/%s.tscn" % a[0]) as PackedScene).instantiate()
	n.position = Vector3(0, 0, 0)
	root.add_child(n)
	for m in n.find_children("*Exterior*", "MeshInstance3D", true, false): m.visible = false
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.9, 0.9, 0.95)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-70, 20, 0); root.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 50; root.add_child(cam)
	root.size = Vector2i(1100, 800)
	var c := n.global_position + Vector3(0, 2.5, 0)
	var views := [[c + Vector3(0, 15, 8), c], [c + Vector3(-8, 8, 10), c], [c + Vector3(8, 8, -10), c]]
	var sheet := Image.create(1100, 800 * views.size(), false, Image.FORMAT_RGB8)
	for i in views.size():
		cam.look_at_from_position(views[i][0], views[i][1])
		for k in 4: await process_frame
		var img := root.get_texture().get_image(); img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, 1100, 800), Vector2i(0, 800 * i))
	sheet.save_png(ProjectSettings.globalize_path(a[1]))
	quit()
