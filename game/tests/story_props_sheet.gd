extends SceneTree
## Renders each story prop on its own, framed close (png per prop), for a contact sheet.
##   godot --path . --resolution 640x560 --script res://game/tests/story_props_sheet.gd -- dir=<folder>
func _initialize() -> void:
	_run.call_deferred()
func aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		var a := m.global_transform * m.get_aabb()
		if first: out = a; first = false
		else: out = out.merge(a)
	return out
func _run() -> void:
	var dir := "C:/Users/Themo/AppData/Local/Temp/propshots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dir="): dir = a.substr(4)
	DirAccess.make_dir_recursive_absolute(dir)
	var stage := Node3D.new()
	root.add_child(stage)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.21, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.76)
	e.ambient_light_energy = 0.9
	we.environment = e
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_energy = 0.9
	stage.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.3, 0.32)
	floor_mi.material_override = fm
	stage.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 38
	stage.add_child(cam)
	cam.current = true
	var P := "res://game/prototypes/story_props/"
	var items := [["FAC_PowerControl", 0], ["FAC_SlidingDoor", 0], ["FAC_SlidingDoor_Rust", 0], ["FAC_VentDuct", 0], ["FAC_DuctRun_3m", 0],
		["PRP_Plank_1.4", 1], ["PRP_Plank_1.0_Broken", 1], ["PRP_Paper_Pile_A", 2], ["PRP_Paper_Pile_B", 2], ["PRP_Paper_Pile_C", 2]]
	for it in items:
		var n: Node3D = load(P + it[0] + ".glb").instantiate()
		stage.add_child(n)
		var bb := aabb_of(n)
		var c := bb.get_center()
		var d := bb.size.length() * 1.25
		var off := Vector3(-0.55, 0.35, 1.0).normalized()
		if it[1] == 2:
			off = Vector3(0.2, 1.0, 0.45).normalized()
		cam.global_position = c + off * d
		cam.look_at(c, Vector3.UP)
		floor_mi.position.y = bb.position.y - 0.01
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [dir, it[0]])
		n.queue_free()
		await process_frame
	# wall pictures, face on
	for art in ["art_safety", "art_grid", "art_schedule", "art_warning", "art_pinboard", "paper_a"]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0) * (1.0 if art != "paper_a" else 0.8)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(P + "tex/" + art + ".png")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		stage.add_child(mi)
		mi.position = Vector3(0, 1.0, 0)
		floor_mi.position.y = -50
		cam.global_position = Vector3(0, 1.0, 1.7)
		cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [dir, art])
		mi.queue_free()
		await process_frame
	print("SHOTS done ", dir)
	quit()
