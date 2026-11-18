extends SceneTree
## Sign check of the Hound's visual pose: left = neutral, right = pitch +0.09 (nose must drop) and bank -0.11 (leans toward +X = its left).
func _initialize() -> void:
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.25, 0.27, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.7, 0.72, 0.8)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 30, 0); root.add_child(sun)
	var cam := Camera3D.new(); root.add_child(cam); cam.fov = 40
	var hs: Array = []
	for i in 2:
		var h: Node3D = (load("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn") as PackedScene).instantiate()
		root.add_child(h); h.position.x = i * 3.0; hs.append(h)
		var ap := h.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer; ap.play("Idle"); ap.pause()
	var mdl := (hs[1] as Node3D).get_node("Model") as Node3D
	mdl.rotation.x = 0.35; mdl.rotation.z = -0.35                      # exaggerated x3 so the direction is obvious
	root.size = Vector2i(640, 360)
	var sheet := Image.create(1280, 360, false, Image.FORMAT_RGB8)
	var views := [Vector3(8, 1.5, 1.5), Vector3(1.5, 1.5, -8)]
	for v in 2:
		cam.look_at_from_position(views[v], Vector3(1.5, 0.8, 0.0))
		for k in 3: await process_frame
		var im := root.get_texture().get_image(); im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(v * 640, 0))
	sheet.save_png(ProjectSettings.globalize_path("res://refine/previews/hound_pose_check.png"))
	quit()
