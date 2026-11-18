extends SceneTree
## Hound before/after at the REAL magnitudes used in hound_ai.gd. Top row = side view, bottom = front. Columns: neutral, run, hard turn, pre-bite.
func _initialize() -> void:
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.12, 0.13, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.45, 0.47, 0.55)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); sun.light_energy = 0.8; root.add_child(sun)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.2, 0.22, 0.18); g.material_override = gm; root.add_child(g)
	var cam := Camera3D.new(); root.add_child(cam); cam.fov = 38
	var poses := [["neutral", 0.0, 0.0, 0.0], ["run", 0.06, 0.0, 0.0], ["hard turn", 0.0, -0.11, 0.0], ["pre-bite", 0.09, 0.0, 0.07]]  # pitch, bank, drop
	root.size = Vector2i(320, 240)
	var sheet := Image.create(1280, 480, false, Image.FORMAT_RGB8)
	for c in 4:
		var h: Node3D = (load("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn") as PackedScene).instantiate()
		root.add_child(h)
		var ap := h.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		ap.play("Run" if c == 1 else ("Attack_Bite" if c == 3 else "Idle")); ap.pause(); ap.seek(0.1 if c != 3 else 0.0, true)
		var m := h.get_node("Model") as Node3D
		m.rotation.x = poses[c][1]; m.rotation.z = poses[c][2]; m.position.y = -poses[c][3]
		for v in 2:
			if v == 0: cam.look_at_from_position(Vector3(6, 1.3, 0), Vector3(0, 0.8, 0))
			else: cam.look_at_from_position(Vector3(0.0, 1.3, 6.0), Vector3(0, 0.8, 0))
			for k in 3: await process_frame
			var im := root.get_texture().get_image(); im.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(im, Rect2i(0, 0, 320, 240), Vector2i(c * 320, v * 240))
		h.queue_free()
	sheet.save_png(ProjectSettings.globalize_path("res://refine/previews/hound_before_after.png"))
	quit()
