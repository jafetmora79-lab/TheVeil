class_name VeilFaceFit
extends RefCounted
## THE VEIL - expression faces on a Mixamo-rigged model. The old face-texture pipeline (VeilNpcFaceTex) wants a second surface on the face skin with front-projection UVs; the
## Mixamo models are a new mesh, so that surface is cut at load time: the head's front-facing triangles whose (scaled, shifted) place falls inside the old face mask get UVs from the
## old model's mapping (game/tools/measure_old_face.gd -> face_fit/<slug>.json). face_fit/<slug>.json also carries the per-character fit: "scale", "dr", "du" (new head -> old head).
## c = (right, up) of a vertex relative to the Head bone in the rig's own frame (right = forward x up, forward measured from the feet).


const FACE_SHADER := preload("res://game/npc/face_fit.gdshader")
static var _dm := {}


static func _mask_texture(slug: String, grow: int, cut: float) -> ImageTexture:
	var m := _diff_mask(slug, grow, cut)
	var img := Image.create(128, 128, false, Image.FORMAT_L8)
	var eyes: Image = null
	var ep := "res://game/prototypes/npc_meshy/face_fit/%s_eyes.png" % slug
	if ResourceLoader.exists(ep):
		eyes = (load(ep) as Texture2D).get_image()
	for y in 128:
		for x in 128:
			img.set_pixel(x, y, Color(1, 1, 1) if (m[y * 128 + x] == 1 or (eyes != null and eyes.get_pixel(x, y).r > 0.5)) else Color(0, 0, 0))
	return ImageTexture.create_from_image(img)


## 128 x 128 mask (1 = changed by some expression, then dilated by `grow` cells) of the face image space.
static func _diff_mask(slug: String, grow: int, cut := 0.0) -> PackedByteArray:
	var key := "%s/%d/%.2f" % [slug, grow, cut]
	if _dm.has(key):
		return _dm[key]
	var base := VeilNpcFaceTex.texture(slug, "neutral").get_image()
	base.decompress() if base.is_compressed() else null
	base.resize(128, 128, Image.INTERPOLATE_NEAREST)
	var m := PackedByteArray()
	m.resize(128 * 128)
	for n in ["blink", "talk_small", "talk_wide", "scared", "angry", "worried"]:
		var im := VeilNpcFaceTex.texture(slug, n).get_image()
		im.decompress() if im.is_compressed() else null
		im.resize(128, 128, Image.INTERPOLATE_NEAREST)
		for y in range(int(cut * 128.0), 128):
			for x in 128:
				var d := base.get_pixel(x, y)
				var e := im.get_pixel(x, y)
				if maxf(absf(d.r - e.r), maxf(absf(d.g - e.g), absf(d.b - e.b))) > 0.07:
					m[y * 128 + x] = 1
	var ep := "res://game/prototypes/npc_meshy/face_fit/%s_eyes.png" % slug
	if ResourceLoader.exists(ep):                                  # the model's own painted eyes count as changed: the face image replaces all of the eye
		var eimg := (load(ep) as Texture2D).get_image()
		for y in 128:
			for x in 128:
				if eimg.get_pixel(x, y).r > 0.5:
					m[y * 128 + x] = 1
	var g := PackedByteArray()
	g.resize(128 * 128)
	for y in 128:
		for x in 128:
			if m[y * 128 + x] == 1:
				for dy in range(-grow, grow + 1):
					for dx in range(-grow, grow + 1):
						var xx := x + dx
						var yy := y + dy
						if xx >= 0 and xx < 128 and yy >= 0 and yy < 128:
							g[yy * 128 + xx] = 1
	_dm[key] = g
	return g


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
	# what the expressions change (brows, eyes, mouth), grown a little: only those triangles get the face image, everything else keeps the model's own painted face
	var dm := _diff_mask(slug, int(fit.get("dilate", 9)), float(fit.get("brow_cut", 0.45)))
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
			var hit := false
			var ta := uvs[idx[t]]
			var tb := uvs[idx[t + 1]]
			var tc := uvs[idx[t + 2]]
			for pt in [c, ta, tb, tc, (ta + tb) * 0.5, (tb + tc) * 0.5, (ta + tc) * 0.5, (ta * 2.0 + tb + tc) * 0.25, (tb * 2.0 + ta + tc) * 0.25, (tc * 2.0 + ta + tb) * 0.25]:
				var q := Vector2i(int(pt.x * 127.0), int(pt.y * 127.0))
				if dm[clampi(q.y, 0, 127) * 128 + clampi(q.x, 0, 127)] == 1:
					hit = true
			inside = hit
			# skin samples for the tint (cheeks and nose, the old face mask's skin)
			if aimg != null and mimg.get_pixelv(Vector2i(int(c.x * mimg.get_width()), int(c.y * mimg.get_height()))).r > 0.5 and c.x >= ur[0] and c.x <= ur[1] and c.y >= vmin:
				var ou := (ouv[idx[t]] + ouv[idx[t + 1]] + ouv[idx[t + 2]]) / 3.0
				var col := aimg.get_pixelv(Vector2i(int(ou.x * aimg.get_width()) % aimg.get_width(), int(ou.y * aimg.get_height()) % aimg.get_height()))
				if Vector3(col.r - skin_c.r, col.g - skin_c.g, col.b - skin_c.b).length() < skin_tol:
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
	var nou := PackedVector2Array()
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
			nou.append(ouv[i])
			for j in per:
				nb.append(bones_src[i * per + j])
				nw.append(weights_src[i * per + j])
		ni.append(remap[i])
	a1[Mesh.ARRAY_VERTEX] = nv
	a1[Mesh.ARRAY_NORMAL] = nn
	a1[Mesh.ARRAY_TEX_UV] = nu
	a1[Mesh.ARRAY_TEX_UV2] = nou
	a1[Mesh.ARRAY_INDEX] = ni
	if per > 0:
		a1[Mesh.ARRAY_BONES] = nb
		a1[Mesh.ARRAY_WEIGHTS] = nw
	var flags := 0
	if per == 8:
		flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a1, [], {}, flags)
	# the face surface is a shader: the face image only where an expression changes something (the mask), the model's own painted face everywhere else
	var sm := ShaderMaterial.new()
	sm.shader = FACE_SHADER
	sm.set_shader_parameter("face_tex", VeilNpcFaceTex.texture(slug, "neutral"))
	sm.set_shader_parameter("orig_tex", (mat as BaseMaterial3D).albedo_texture)
	sm.set_shader_parameter("mask_tex", _mask_texture(slug, int(fit.get("dilate_mask", 1)), float(fit.get("brow_cut", 0.45))))
	sm.set_shader_parameter("amount", 0.0)
	sm.set_shader_parameter("blink_line_v", float(fit.get("blink_line_v", 0.505)))
	if tint_n > 5:
		var fimg := VeilNpcFaceTex.texture(slug, "neutral").get_image()
		if fimg.is_compressed():
			fimg.decompress()
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
			var tn := Vector3(clampf(mine.x / maxf(theirs.x, 0.01), 0.5, 1.3), clampf(mine.y / maxf(theirs.y, 0.01), 0.5, 1.3), clampf(mine.z / maxf(theirs.z, 0.01), 0.5, 1.3))
			sm.set_shader_parameter("tint", tn)
	# the lid colour of a blink: this model's own skin just under its eyes (the vertices that sit nearest under the eyes of the face image)
	if aimg != null:
		var acc := Vector3.ZERO
		for target in [Vector2(0.38, 0.60), Vector2(0.62, 0.60)]:
			var best := 1e9
			var bi := 0
			for i in v.size():
				if front[i] == 1:
					var dd := uvs[i].distance_squared_to(target)
					if dd < best:
						best = dd
						bi = i
			var cc := aimg.get_pixelv(Vector2i(int(ouv[bi].x * aimg.get_width()) % aimg.get_width(), int(ouv[bi].y * aimg.get_height()) % aimg.get_height()))
			acc += Vector3(cc.r, cc.g, cc.b)
		acc /= 2.0
		sm.set_shader_parameter("skin_col", Vector3(acc.x, acc.y, acc.z))
	var epx := "res://game/prototypes/npc_meshy/face_fit/%s_eyes.png" % slug
	if ResourceLoader.exists(epx):
		sm.set_shader_parameter("eye_tex", load(epx))
	nm.surface_set_material(1, sm)
	mi.mesh = nm
	print("FACEFIT ", slug, " face triangles ", face.size() / 3, " of ", idx.size() / 3)
	return true
