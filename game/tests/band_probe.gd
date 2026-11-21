extends SceneTree
## Dev probe (review note #5): the biggest exterior-trim triangles that lie inside the player's home, from the ORIGINAL asset (before any fix).
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	var ps := load("res://THE_VEIL_ASSETS_V2/03_Residential/House_Variants/RES_PlayerHome.glb") as PackedScene
	var inst := ps.instantiate() as Node3D
	root.add_child(inst)
	await process_frame
	# the home's world transform: the world places it; here use the offset known from the world probe (home origin)
	var ext := inst.find_child("RES_PlayerHome_Exterior", true, false) as MeshInstance3D
	var rows: Array = []
	for sx in ext.mesh.get_surface_count():
		var mt := ext.mesh.surface_get_material(sx)
		var arr := ext.mesh.surface_get_arrays(sx)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var a := vs[idx[t]]
			var b := vs[idx[t + 1]]
			var c := vs[idx[t + 2]]
			var area := (b - a).cross(c - a).length() * 0.5
			rows.append([area, sx, mt.resource_name if mt else "-", a, b, c])
	print("PROBE mesh local aabb ", ext.get_aabb())
	rows.sort_custom(func(x, y): return x[0] > y[0])
	var shown := 0
	for r in rows:
		var ys := [r[3].y, r[4].y, r[5].y]
		# in this asset's own frame the floor is at 0.6 and the ceiling at 3.2 (world: +0.15): the band is the member between 2.2 and 3.2 high
		if minf(ys[0], minf(ys[1], ys[2])) > 1.9 and minf(ys[0], minf(ys[1], ys[2])) < 3.3 and r[2] != "M_Arch_WindowGlassDirty":
			print("PROBE tri area ", snappedf(r[0], 0.01), " s", r[1], " ", r[2], " ", r[3], r[4], r[5])
			shown += 1
			if shown >= 14: break
	quit()
