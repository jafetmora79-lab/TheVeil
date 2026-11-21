extends SceneTree
## Re-takes the camera views of review notes to check a fix:  godot --path . --resolution 960x540 --script res://game/tests/review_shots.gd -- ids=2,3,4,5 dir=<folder> [flags=a,b]
## Reads the notes file (the camera position / rotation each note was made from), starts the world with the intro skipped and takes one picture per note.
var ids: Array = []
var dir := "C:/Users/Themo/AppData/Local/Temp/reviewshots"
var extra_flags: Array = []
var paint := ""                # "NodePath:surface": that surface is drawn with a colour per metre-square of its triangles (and the key is printed)
var custom := ""               # "x,y,z,rx,ry,rz": one extra picture from there (custom.png)
var kill := ""                 # "MeshName:surface" - the surface is left out (to find which one a visual fault comes from)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ids="):
			for p in a.substr(4).split(","): ids.append(int(p))
		elif a.begins_with("dir="): dir = a.substr(4)
		elif a.begins_with("flags="): extra_flags = a.substr(6).split(",")
		elif a.begins_with("kill="): kill = a.substr(5)
		elif a.begins_with("paint="): paint = a.substr(6)
		elif a.begins_with("cam="): custom = a.substr(4)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open("user://veil_notes.json", FileAccess.READ)
	var notes: Array = JSON.parse_string(f.get_as_text())["notes"]
	var game = root.get_node("Game")
	game.new_game()
	game.flags["intro_seen"] = true
	for fl in extra_flags:
		game.flags[fl] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 120: await process_frame
	if w.get("hud"): w.hud.visible = false
	if kill != "":
		var parts := kill.split(":")
		var mi := (w.get_node(parts[0]) if "/" in parts[0] else w.find_child(parts[0], true, false)) as MeshInstance3D
		var skip := int(parts[1])
		var out := ArrayMesh.new()
		for sx in mi.mesh.get_surface_count():
			if sx == skip: continue
			out.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(sx), mi.mesh.surface_get_arrays(sx))
			out.surface_set_material(out.get_surface_count() - 1, mi.mesh.surface_get_material(sx))
		mi.mesh = out
	if paint != "":
		var parts2 := paint.split(":")
		var mi2 := w.get_node(parts2[0]) as MeshInstance3D
		var sk := int(parts2[1])
		var out2 := ArrayMesh.new()
		var pal := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN, Color.ORANGE, Color.WHITE, Color.PURPLE, Color.LIME]
		var keys := {}
		for sx in mi2.mesh.get_surface_count():
			var arr2 := mi2.mesh.surface_get_arrays(sx)
			if sx == sk:
				var vs: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr2[Mesh.ARRAY_INDEX]
				var nv := PackedVector3Array()
				var cols := PackedColorArray()
				var ni := PackedInt32Array()
				for t in range(0, idx.size() - 2, 3):
					var a3: Vector3 = mi2.global_transform * vs[idx[t]]
					var b3: Vector3 = mi2.global_transform * vs[idx[t + 1]]
					var c3: Vector3 = mi2.global_transform * vs[idx[t + 2]]
					var ctr: Vector3 = (a3 + b3 + c3) / 3.0
					var key := "x%d_z%d" % [int(floor(ctr.x)), int(floor(ctr.z))]
					if not keys.has(key): keys[key] = pal[keys.size() % pal.size()]
					for q in [idx[t], idx[t + 1], idx[t + 2]]:
						ni.append(nv.size())
						nv.append(vs[q])
						cols.append(keys[key])
				var arr3: Array = []
				arr3.resize(Mesh.ARRAY_MAX)
				arr3[Mesh.ARRAY_VERTEX] = nv
				arr3[Mesh.ARRAY_COLOR] = cols
				arr3[Mesh.ARRAY_INDEX] = ni
				out2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr3)
				var pm := StandardMaterial3D.new()
				pm.vertex_color_use_as_albedo = true
				pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				pm.cull_mode = BaseMaterial3D.CULL_DISABLED
				out2.surface_set_material(out2.get_surface_count() - 1, pm)
			else:
				out2.add_surface_from_arrays(mi2.mesh.surface_get_primitive_type(sx), arr2)
				out2.surface_set_material(out2.get_surface_count() - 1, mi2.mesh.surface_get_material(sx))
		mi2.mesh = out2
		for k in keys: print("PAINT ", k, " ", keys[k])
	if "stockroom" in extra_flags:                  # note #12: the stock-room scene's seats, set up the way the cinematic does
		w._p3_place_marcus_in_shop()
		await process_frame
		w._seat("Marcus", w.SEAT_DOCS, w.SEAT_DOCS_H, w.STOCK_CIRCLE)
		if w.animators.has("Eddie"):
			w.animators["Eddie"].walk_to([])
			w.place_survivor(w.animators["Eddie"].root, w.EDDIE_STAND)
			w.animators["Eddie"].face_towards(w.game_shop.global_transform * w.STOCK_CIRCLE)
		for i in 20: await process_frame
	var cam := Camera3D.new()
	cam.far = 400.0
	w.add_child(cam)
	cam.current = true
	w.player.visible = false
	for n in notes:
		if not ids.is_empty() and not (int(n["id"]) in ids): continue
		var c: Dictionary = n["camera"]
		cam.fov = float(c.get("fov", 75.0))
		cam.global_position = Vector3(c["position"][0], c["position"][1], c["position"][2])
		cam.global_rotation_degrees = Vector3(c["rotation_deg"][0], c["rotation_deg"][1], c["rotation_deg"][2])
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/note_%03d.png" % [dir, int(n["id"])])
	if custom != "":
		var q := custom.split(",")
		cam.fov = 70.0
		cam.global_position = Vector3(float(q[0]), float(q[1]), float(q[2]))
		cam.global_rotation_degrees = Vector3(float(q[3]), float(q[4]), float(q[5]))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/custom.png" % dir)
	print("SHOTS done")
	quit()
