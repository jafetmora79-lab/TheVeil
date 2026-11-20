class_name VeilFaceFit
extends RefCounted
## THE VEIL - expression faces on a Mixamo-rigged model. The old face-texture pipeline (VeilNpcFaceTex) wants a second surface on the face skin with front-projection UVs; the
## Mixamo models are a new mesh, so that surface is cut at load time: the head's front-facing triangles whose (scaled, shifted) place falls inside the old face mask get UVs from the
## old model's mapping (game/tools/measure_old_face.gd -> face_fit/<slug>.json). face_fit/<slug>.json also carries the per-character fit: "scale", "dr", "du" (new head -> old head).
## c = (right, up) of a vertex relative to the Head bone in the rig's own frame (right = forward x up, forward measured from the feet).


static func _rel(n: Node3D, top: Node) -> Transform3D:
	var t := Transform3D()
	var cur: Node = n
	while cur != null and cur != top:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func apply(model: Node3D, slug: String, ov := {}) -> bool:
	var jf := FileAccess.open("res://game/prototypes/npc_meshy/face_fit/%s.json" % slug, FileAccess.READ)
	if jf == null:
		return false
	var fit: Dictionary = JSON.parse_string(jf.get_as_text())
	fit.merge(ov, true)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return false
	var sk := sks[0] as Skeleton3D
	var head := sk.find_bone("mixamorig_Head")
	var lu := sk.find_bone("mixamorig_LeftUpLeg")
	var ru := sk.find_bone("mixamorig_RightUpLeg")
	if head < 0 or lu < 0 or ru < 0:
		return false
	var rg := sk.get_bone_global_pose(ru).origin - sk.get_bone_global_pose(lu).origin
	rg.y = 0.0
	var r := rg.normalized()
	var f := Vector3.UP.cross(r).normalized()
	var hp := sk.get_bone_global_pose(head).origin
	var mi: MeshInstance3D
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh is ArrayMesh and (m as MeshInstance3D).skin != null:
			mi = m
			break
	if mi == null:
		return false
	var mesh := mi.mesh as ArrayMesh
	var arr := mesh.surface_get_arrays(0)
	var mat := mi.get_active_material(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var to_sk := _rel(sk, model).affine_inverse() * _rel(mi, model)
	var mask := load("res://game/prototypes/npc_meshy/face/%s/face_mask.png" % slug) as Texture2D
	var mimg := mask.get_image()
	var s: float = fit.get("scale", 0.9)
	var dr: float = fit.get("dr", 0.0)
	var du: float = fit.get("du", 0.0)
	var pu: Array = fit["u"]
	var pv: Array = fit["v"]
	# per vertex: the projected UV and whether it faces forward
	var uvs := PackedVector2Array()
	uvs.resize(v.size())
	var front := PackedByteArray()
	front.resize(v.size())
	for i in v.size():
		var d := to_sk * v[i] - hp
		var cr := d.dot(r) / s + dr
		var cu := d.dot(Vector3.UP) / s + du
		uvs[i] = Vector2(pu[0] * cr + pu[1] * cu + pu[2], pv[0] * cr + pv[1] * cu + pv[2])
		front[i] = 1 if (to_sk.basis * nrm[i]).dot(f) > float(fit.get("facing", 0.25)) else 0
	# skin test on the model's own texture: hair, brows and clothes in front of the face stay as they are (the face image only replaces skin and the eye / mouth box)
	var ouv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var aimg: Image = null
	if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
		aimg = (mat as BaseMaterial3D).albedo_texture.get_image()
		if aimg.is_compressed():
			aimg.decompress()
	var skin_c := Color(float(fit.get("skin", [0.79, 0.48, 0.30])[0]), float(fit.get("skin", [0.79, 0.48, 0.30])[1]), float(fit.get("skin", [0.79, 0.48, 0.30])[2]))
	var skin_tol: float = fit.get("skin_tol", 0.2)
	var box: Array = fit.get("box", [0.2, 0.37, 0.8, 0.85])
	var ur: Array = fit.get("u_range", [0.28, 0.74])
	var vmin: float = fit.get("v_min", 0.36)
	var tint_sum := Vector3.ZERO
	var tint_n := 0
	var rest := PackedInt32Array()
	var face := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var inside := true
		var c := Vector2.ZERO
		for k in 3:
			var i := idx[t + k]
			c += uvs[i] / 3.0
			if front[i] == 0 or uvs[i].x < 0.0 or uvs[i].x > 1.0 or uvs[i].y < 0.0 or uvs[i].y > 1.0:
				inside = false
		if inside:
			var px := Vector2i(int(c.x * mimg.get_width()), int(c.y * mimg.get_height()))
			inside = mimg.get_pixelv(px).r > 0.5
			if inside and aimg != null:
				var in_box: bool = c.x >= box[0] and c.x <= box[2] and c.y >= box[1] and c.y <= box[3]
				if not in_box:
					var ou := (ouv[idx[t]] + ouv[idx[t + 1]] + ouv[idx[t + 2]]) / 3.0
					var col := aimg.get_pixelv(Vector2i(int(ou.x * aimg.get_width()) % aimg.get_width(), int(ou.y * aimg.get_height()) % aimg.get_height()))
					var dc := Vector3(col.r - skin_c.r, col.g - skin_c.g, col.b - skin_c.b).length()
					inside = dc < skin_tol and c.x >= ur[0] and c.x <= ur[1] and c.y >= vmin
					if inside:
						tint_sum += Vector3(col.r, col.g, col.b)
						tint_n += 1
		for k in 3:
			(face if inside else rest).append(idx[t + k])
	if face.is_empty():
		return false
	var nm := ArrayMesh.new()
	# surface 0: everything else, as it was
	var a0 := arr.duplicate()
	a0[Mesh.ARRAY_INDEX] = rest
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a0, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (arr[Mesh.ARRAY_BONES] != null and arr[Mesh.ARRAY_BONES].size() == 8 * v.size()) else 0)
	nm.surface_set_material(0, mat)
	# surface 1: the face triangles on their own vertices, with the projected UVs
	var remap := {}
	var a1 := []
	a1.resize(Mesh.ARRAY_MAX)
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nu := PackedVector2Array()
	var bones_src = arr[Mesh.ARRAY_BONES]
	var weights_src = arr[Mesh.ARRAY_WEIGHTS]
	var per := 0
	if bones_src != null and bones_src.size() > 0:
		per = bones_src.size() / v.size()
	var nb := PackedInt32Array()
	var nw := PackedFloat32Array()
	var ni := PackedInt32Array()
	for i in face:
		if not remap.has(i):
			remap[i] = nv.size()
			nv.append(v[i])
			nn.append(nrm[i])
			nu.append(uvs[i])
			for j in per:
				nb.append(bones_src[i * per + j])
				nw.append(weights_src[i * per + j])
		ni.append(remap[i])
	a1[Mesh.ARRAY_VERTEX] = nv
	a1[Mesh.ARRAY_NORMAL] = nn
	a1[Mesh.ARRAY_TEX_UV] = nu
	a1[Mesh.ARRAY_INDEX] = ni
	if per > 0:
		a1[Mesh.ARRAY_BONES] = nb
		a1[Mesh.ARRAY_WEIGHTS] = nw
	var flags := 0
	if per == 8:
		flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a1, [], {}, flags)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = VeilNpcFaceTex.texture(slug, "neutral")
	if tint_n > 5:
		# the face image's skin vs this model's own skin: the image is tinted to match (the Mixamo models were textured again)
		var fimg := fm.albedo_texture.get_image()
		var fs := Vector3.ZERO
		var fn := 0
		for _k in 600:
			var q := Vector2i(randi() % fimg.get_width(), randi() % fimg.get_height())
			var fc := fimg.get_pixelv(q)
			if Vector3(fc.r - skin_c.r, fc.g - skin_c.g, fc.b - skin_c.b).length() < skin_tol:
				fs += Vector3(fc.r, fc.g, fc.b)
				fn += 1
		if fn > 20:
			var mine := tint_sum / float(tint_n)
			var theirs := fs / float(fn)
			fm.albedo_color = Color(clampf(mine.x / maxf(theirs.x, 0.01), 0.5, 1.3), clampf(mine.y / maxf(theirs.y, 0.01), 0.5, 1.3), clampf(mine.z / maxf(theirs.z, 0.01), 0.5, 1.3))
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	nm.surface_set_material(1, fm)
	mi.mesh = nm
	print("FACEFIT ", slug, " face triangles ", face.size() / 3, " of ", idx.size() / 3)
	return true
