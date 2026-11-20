extends SceneTree
## One-off: how an NPC's old face texture is laid on its head. Fits UV = affine(c) over the face-skin surface of CHR_<slug>_FaceTex.glb, c = (right, up) of the vertex relative to the
## Head bone in the rig's own frame (right = forward x up, forward from the feet). Writes game/prototypes/npc_meshy/face_fit/<slug>.json (used by game/npc/face_fit.gd).
##   godot --headless --path . --script res://game/tools/measure_old_face.gd -- eddie
func _initialize() -> void:
	var slug: String = OS.get_cmdline_user_args()[0]
	var n := (load("res://game/prototypes/npc_meshy/CHR_%s_FaceTex.glb" % slug) as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var rg := sk.get_bone_global_pose(sk.find_bone("RightUpperLeg")).origin - sk.get_bone_global_pose(sk.find_bone("LeftUpperLeg")).origin
	rg.y = 0.0
	var r := rg.normalized()
	var f := Vector3.UP.cross(r).normalized()
	var hp := sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var mi: MeshInstance3D
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh.get_surface_count() >= 2:
			mi = m
	var a := (mi.mesh as ArrayMesh).surface_get_arrays(1)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	# least squares u = p0*cr + p1*cu + p2 (and v likewise)
	var ata := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var atu := [0.0, 0.0, 0.0]
	var atv := [0.0, 0.0, 0.0]
	var lo := Vector2(1e9, 1e9)
	var hi := -lo
	for i in v.size():
		var d := mi.global_transform * v[i] - hp
		var row := [d.dot(r), d.dot(Vector3.UP), 1.0]
		lo = lo.min(Vector2(row[0], row[1]))
		hi = hi.max(Vector2(row[0], row[1]))
		for p in 3:
			atu[p] += row[p] * uv[i].x
			atv[p] += row[p] * uv[i].y
			for q in 3:
				ata[p][q] += row[p] * row[q]
	var su := _solve(ata, atu)
	var sv := _solve(ata, atv)
	var err := 0.0
	for i in v.size():
		var d := mi.global_transform * v[i] - hp
		var pu: float = su[0] * d.dot(r) + su[1] * d.dot(Vector3.UP) + su[2]
		var pv: float = sv[0] * d.dot(r) + sv[1] * d.dot(Vector3.UP) + sv[2]
		err = maxf(err, Vector2(pu, pv).distance_to(uv[i]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://game/prototypes/npc_meshy/face_fit"))
	var out := FileAccess.open("res://game/prototypes/npc_meshy/face_fit/%s.json" % slug, FileAccess.WRITE)
	var info = JSON.parse_string(FileAccess.get_file_as_string("res://creatures/humans/npcs/%s/face_tex/face_info.json" % slug))
	var sk3: Array = info["skin"]
	out.store_string(JSON.stringify({"skin": [sk3[0] / 255.0, sk3[1] / 255.0, sk3[2] / 255.0], "scale": 0.96, "dr": 0.0, "du": 0.0, "u": su, "v": sv, "face_min": [lo.x, lo.y], "face_max": [hi.x, hi.y], "head_y": hp.y, "max_uv_error": err}))
	out.close()
	print("fit ", slug, " u ", su, " v ", sv, " err ", err, " face box ", lo, hi)
	quit(0)


func _solve(m: Array, b: Array) -> Array:
	var a := [m[0].duplicate(), m[1].duplicate(), m[2].duplicate()]
	var x := [b[0], b[1], b[2]]
	for i in 3:
		var piv := i
		for k in range(i + 1, 3):
			if absf(a[k][i]) > absf(a[piv][i]):
				piv = k
		var t = a[i]; a[i] = a[piv]; a[piv] = t
		var tx = x[i]; x[i] = x[piv]; x[piv] = tx
		for k in range(i + 1, 3):
			var fct: float = a[k][i] / a[i][i]
			for j in range(i, 3):
				a[k][j] -= fct * a[i][j]
			x[k] -= fct * x[i]
	var res := [0.0, 0.0, 0.0]
	for i in range(2, -1, -1):
		var s: float = x[i]
		for j in range(i + 1, 3):
			s -= a[i][j] * res[j]
		res[i] = s / a[i][i]
	return res
