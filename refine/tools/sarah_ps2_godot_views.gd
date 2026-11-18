extends SceneTree
## Godot 4.3 (GL Compatibility) check of the repainted PS2 Sarah head: texture filtering, front / three-quarter / side views, restrained flat light.
func _initialize() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.72, 0.76)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 0.55
	root.add_child(sun)
	var holder := Node3D.new()
	root.add_child(holder)
	var m: Node3D = (load("res://game/creatures/sarah_ps2/CHR_Sarah_PS2.glb") as PackedScene).instantiate()
	holder.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat and mat.albedo_texture:
				print("MATX ", mi.name, " albedo=", mat.albedo_color, " emission=", mat.emission_enabled, mat.emission, " metallic=", mat.metallic, " rough=", mat.roughness, " transp=", mat.transparency, " shading=", mat.shading_mode, " cull=", mat.cull_mode)
				print("MAT ", mi.name, " ", mat.resource_name, " filter=", mat.texture_filter, " (0=nearest 1=linear 2=nearest+mip 3=linear+mip) tex=", mat.albedo_texture.get_size())
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 28
	root.size = Vector2i(480, 480)
	var sheet := Image.create(480 * 3, 480, false, Image.FORMAT_RGB8)
	var i := 0
	for yaw in [0.0, 40.0, 90.0]:
		holder.rotation_degrees.y = yaw
		cam.look_at_from_position(Vector3(0, 1.54, 1.25), Vector3(0, 1.53, 0))
		for k in 4:
			await process_frame
		var im := root.get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(0, 0, 480, 480), Vector2i(i * 480, 0))
		i += 1
	sheet.save_png(ProjectSettings.globalize_path("res://creatures/humans/work/sarah_godot_views.png"))
	quit()
