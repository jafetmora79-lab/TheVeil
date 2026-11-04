extends SceneTree
## Tree visibility along the drive (data-based: works headless, where the dummy renderer keeps no MultiMesh data).
## For route points, every tree (scatter.json) within 300 m of the camera must belong to a MultiMeshInstance whose
## visibility range covers the camera, measured to the node origin AND to the cell centre.
func _initialize(): _run.call_deferred()
func _run():
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 5: await process_frame
	var route: Array = w.data["route"]
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/world/scatter.json"))
	var cells := {}
	for m in w.get_node("Scatter").get_children():
		if m is MultiMeshInstance3D and String(m.name).begins_with("VG_Tree"):
			cells[String(m.name).get_slice("_Mesh", 0).get_slice("_VG_", 0) + "|" + str(m.get_meta("cell", []).slice(0, 2))] = m
	var hidden_total := 0
	var checked := 0
	var chunk: float = w.get_node("Scatter").CHUNK
	for k in range(0, route.size()):
		var cam := Vector3(route[k][0], 1.6, route[k][1])
		for it in d["items"]:
			if not String(it[0]).begins_with("VG_Tree"):
				continue
			if Vector2(it[1] - cam.x, it[2] - cam.z).length() > 300.0:
				continue
			checked += 1
			var cx := (floori(it[1] / chunk) + 0.5) * chunk
			var cz := (floori(it[2] / chunk) + 0.5) * chunk
			var mmi = null
			for key in cells:
				if key.begins_with(it[0] + "|") and absf(cells[key].position.x - cx) < 0.01 and absf(cells[key].position.z - cz) < 0.01:
					mmi = cells[key]
					break
			if mmi == null or cam.distance_to(mmi.global_position) > mmi.visibility_range_end:
				hidden_total += 1
	print("TREECHECK chunks=%d route_points=%d tree_checks=%d hidden=%d" % [cells.size(), route.size(), checked, hidden_total])
	quit()
