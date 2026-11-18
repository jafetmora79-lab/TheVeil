extends SceneTree
## The Colossus as the game shows it (VeilCreatureLook.apply_colossus: dark, dim moon key, fog), old v2 left vs new v3 right.
func _initialize() -> void:
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.11, 0.125, 0.13)
	env.fog_enabled = true; env.fog_light_color = Color(0.11, 0.125, 0.13); env.fog_density = 0.012
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.07, 0.08, 0.08); g.material_override = gm; root.add_child(g)
	var i := 0
	for p in ["res://game/creatures/colossus/CRT_Colossus_v2.tscn", "res://game/creatures/colossus/CRT_Colossus_v3.tscn"]:
		var c: Node3D = (load(p) as PackedScene).instantiate()
		root.add_child(c)
		(c.get_node("Model") as Node3D).scale = Vector3.ONE * 3.0
		c.position = Vector3(-14 + i * 28, 0, 0)
		VeilCreatureLook.apply_colossus(c, 0.0)
		var ap: AnimationPlayer = c.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Idle_Breathe"); ap.seek(1.0, true)
		i += 1
	var cam := Camera3D.new(); root.add_child(cam); cam.fov = 45
	cam.look_at_from_position(Vector3(0, 9, 75), Vector3(0, 14, 0))
	root.size = Vector2i(1280, 720)
	for k in 6: await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://creatures/colossus_ingame_v2_vs_v3.png"))
	quit()
