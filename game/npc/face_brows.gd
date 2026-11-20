class_name VeilFaceBrows
extends RefCounted
## THE VEIL - movable eyebrows for a Mixamo-rigged NPC whose brows are painted into its texture (game/tools/extract_brows.gd -> face_fit/<slug>_brows.json):
##   * the painted brow texels are wiped from the head's texture (a patched copy, filled with the skin above and below), so no brow stays underneath;
##   * two thin strips of geometry sit on the brow, on the Head bone, textured with the ORIGINAL texture (only its dark brow pixels show) and bent by a shader:
##     lift (inner / outer end), shift toward the nose. VeilNpcFaceTex drives them from the expression.
## Call before VeilFaceFit.apply (that reads the head's texture, which is now the patched one).
const BROW_SHADER := preload("res://game/npc/face_brow.gdshader")
static var _patched := {}


static func apply(model: Node3D, slug: String) -> bool:
	var jf := FileAccess.open("res://game/prototypes/npc_meshy/face_fit/%s_brows.json" % slug, FileAccess.READ)
	if jf == null:
		return false
	var data: Dictionary = JSON.parse_string(jf.get_as_text())
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return false
	var sk := sks[0] as Skeleton3D
	var head := sk.find_bone("mixamorig_Head")
	var lu := sk.find_bone("mixamorig_LeftUpLeg")
	var ru := sk.find_bone("mixamorig_RightUpLeg")
	var mi: MeshInstance3D
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
			break
	if head < 0 or mi == null or lu < 0 or ru < 0:
		return false
	var mat := mi.get_active_material(0) as BaseMaterial3D
	if mat == null or mat.albedo_texture == null:
		return false
	var orig_tex := mat.albedo_texture
	# the head's texture without the painted brows
	if not _patched.has(slug):
		var img := Image.new()
		img.copy_from(orig_tex.get_image())            # a copy: the texture's own image is shared and must keep the painted brows (the strips use it)
		if img.is_compressed():
			img.decompress()
		var flat: Array = data["patch"]
		for i in range(0, flat.size(), 5):
			img.set_pixel(int(flat[i]), int(flat[i + 1]), Color8(int(flat[i + 2]), int(flat[i + 3]), int(flat[i + 4])))
		_patched[slug] = ImageTexture.create_from_image(img)
	var m2 := mat.duplicate() as BaseMaterial3D
	m2.albedo_texture = _patched[slug]
	mi.set_surface_override_material(0, m2)
	# the strips, in the Head bone's own frame
	var rg := sk.get_bone_global_pose(ru).origin - sk.get_bone_global_pose(lu).origin
	rg.y = 0.0
	var rvec := rg.normalized()
	var fvec := Vector3.UP.cross(rvec).normalized()
	var hpose := sk.get_bone_global_pose(head)
	var inv := hpose.affine_inverse()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var nrms := PackedVector3Array()
	var idx := PackedInt32Array()
	var mid_r := 0.0
	for st in data["strips"]:
		mid_r += float(st["r0"]) + float(st["nr"]) * float(st["step"]) * 0.5
	mid_r /= float(maxi(data["strips"].size(), 1))
	var nrm_local := (inv.basis * fvec).normalized()
	for st in data["strips"]:
		var r0: float = st["r0"]
		var u0: float = st["u0"]
		var step: float = st["step"]
		var nr: int = int(st["nr"])
		var nu: int = int(st["nu"])
		var fg: Array = st["f"]
		var rc := r0 + nr * step * 0.5
		var inward_local := inv.basis * (rvec * signf(mid_r - rc))
		var icol := Color(inward_local.x * 0.5 + 0.5, inward_local.y * 0.5 + 0.5, inward_local.z * 0.5 + 0.5)
		var cells: Array = st["cells"]
		for j in nu:
			for i in nr:
				var cell: Array = cells[j * nr + i]
				if int(cell[0]) == 0:
					continue
				var base := verts.size()
				for k in 4:
					var ci := k % 2
					var cj := k / 2
					var rr := r0 + (i + ci) * step
					var uu := u0 + (j + cj) * step
					var ff: float = fg[(j + cj) * (nr + 1) + (i + ci)]
					verts.append(inv * (hpose.origin + rvec * rr + Vector3.UP * uu + fvec * (ff + 0.0022)))
					uvs.append(Vector2(float(cell[1 + k * 2]), float(cell[2 + k * 2])))
					var tf := (rr - r0) / maxf(nr * step, 0.001)
					uv2s.append(Vector2(tf if bool(st["inner_low"]) else 1.0 - tf, 0.0))
					cols.append(icol)
					nrms.append(nrm_local)
				idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	if verts.is_empty():
		return false
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sm := ShaderMaterial.new()
	sm.shader = BROW_SHADER
	sm.set_shader_parameter("tex", orig_tex)
	sm.set_shader_parameter("tex_lin", orig_tex)
	var al: Array = data.get("alpha", [0.30, 0.42])
	sm.set_shader_parameter("alpha_lo", float(al[0]))
	sm.set_shader_parameter("alpha_hi", float(al[1]))
	sm.set_shader_parameter("up_local", inv.basis * Vector3.UP)
	mesh.surface_set_material(0, sm)
	var att := BoneAttachment3D.new()
	att.name = "BrowAttachment"
	att.bone_name = "mixamorig_Head"
	sk.add_child(att)
	var bm := MeshInstance3D.new()
	bm.name = "Brows"
	bm.mesh = mesh
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(bm)
	return true
