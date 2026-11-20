extends SceneTree
## Step 2 of the baked-expression pipeline: the 2D expression composites (compose_expressions.py) are mapped onto the model's OWN UV texture. For every texel of the face triangles the 3D point it
## covers is found (barycentric), turned into head space (right, up) and then into the composite's pixel through the kit projection (the exact projection the base crop was rendered with); the
## composite colour and its feathered alpha are written into a patch image at that texel. At run time the head's material shows  mix(original texel, patch texel, patch alpha), so only the feature
## texels change and no second surface, seam or overlay exists.
##   godot --headless --path . --script res://game/tools/bake_expression_patches.gd -- <slug> [model=<glb slug>] [centre_r=0.0106 centre_u=0.0383]
## Reads game/prototypes/npc_meshy/face_bake/<slug>_src/{expr_<name>.png, alpha_all.png}; writes face_bake/<slug>/patch_<name>.png and rect.json.
const NAMES := ["blink", "talk_small", "talk_wide", "scared", "angry", "worried"]
const SIZE := 0.30                                   ## metres across the base crop
var centre_r := 0.0106                               ## head-space (right, up) of the crop centre
var centre_u := 0.0383


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var slug: String = a[0]
	var model_slug := slug
	for e in a:
		if String(e).begins_with("model="):
			model_slug = String(e).substr(6)
		if String(e).begins_with("centre_r="):
			centre_r = float(String(e).substr(9))
		if String(e).begins_with("centre_u="):
			centre_u = float(String(e).substr(9))
	var n := (load("res://game/prototypes/npc_meshy/CHR_%s_Mixamo.glb" % model_slug) as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var rg := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightUpLeg")).origin - sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftUpLeg")).origin
	rg.y = 0.0
	var rvec := rg.normalized()
	var fvec := Vector3.UP.cross(rvec).normalized()
	var hp := sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin
	var mi: MeshInstance3D
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tex := ((mi.get_active_material(0) as BaseMaterial3D).albedo_texture).get_image()
	if tex.is_compressed():
		tex.decompress()
	var tw := tex.get_width()
	var th := tex.get_height()
	var src := "res://game/prototypes/npc_meshy/face_bake/%s_src/" % slug
	var comps := {}
	for nm in NAMES:
		var im := (load(src + "expr_%s.png" % nm) as Texture2D).get_image()
		if im.is_compressed():
			im.decompress()
		comps[nm] = im
	var al := (load(src + "alpha_all.png") as Texture2D).get_image()
	if al.is_compressed():
		al.decompress()
	var patches := {}
	for nm in NAMES:
		patches[nm] = Image.create(tw, th, false, Image.FORMAT_RGBA8)
	var minx := tw
	var miny := th
	var maxx := 0
	var maxy := 0
	var tri_used := 0
	var hair_ref := Vector3(0.43, 0.27, 0.18)
	for e in a:
		if String(e).begins_with("hair="):
			var hp3 := String(e).substr(5).split(",")
			hair_ref = Vector3(float(hp3[0]), float(hp3[1]), float(hp3[2]))
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		# hair (in front of the skin) is not the surface the face is painted on: the same classification the brow tool uses
		# hair (in front of the skin) is not the surface the face is painted on: a triangle whose texels (corners + centre) average to the hair colour is hair; everything else
		# (skin, painted brows, eyes, mouth, and the mixes between them) is face
		var mean_c := (_col(tex, uv[i0]) + _col(tex, uv[i1]) + _col(tex, uv[i2]) + _col(tex, (uv[i0] + uv[i1] + uv[i2]) / 3.0)) / 4.0
		if Vector3(mean_c.r - hair_ref.x, mean_c.g - hair_ref.y, mean_c.b - hair_ref.z).length() < 0.10:
			continue
		var nn := ((nrm[i0] + nrm[i1] + nrm[i2]) / 3.0).dot(fvec)
		if nn < 0.2:
			continue
		var pr: Array[Vector2] = []
		for i in [i0, i1, i2]:
			var d: Vector3 = v[i] - hp
			pr.append(Vector2(d.dot(rvec), d.dot(Vector3.UP)))
		var cpx := 0.0
		var cpy := 0.0
		for q in pr:
			cpx += _px(q.x) / 3.0
			cpy += _py(q.y) / 3.0
		if cpx < 230.0 or cpx > 790.0 or cpy < 330.0 or cpy > 780.0:
			continue
		tri_used += 1
		var a0 := Vector2(uv[i0].x * tw, uv[i0].y * th)
		var a1 := Vector2(uv[i1].x * tw, uv[i1].y * th)
		var a2 := Vector2(uv[i2].x * tw, uv[i2].y * th)
		var x0 := int(floor(minf(a0.x, minf(a1.x, a2.x))))
		var x1 := int(ceil(maxf(a0.x, maxf(a1.x, a2.x))))
		var y0 := int(floor(minf(a0.y, minf(a1.y, a2.y))))
		var y1 := int(ceil(maxf(a0.y, maxf(a1.y, a2.y))))
		var den := (a1.y - a2.y) * (a0.x - a2.x) + (a2.x - a1.x) * (a0.y - a2.y)
		if absf(den) < 1e-9:
			continue
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var px := x + 0.5
				var py := y + 0.5
				var l1b: float = ((a1.y - a2.y) * (px - a2.x) + (a2.x - a1.x) * (py - a2.y)) / den
				var l2b: float = ((a2.y - a0.y) * (px - a2.x) + (a0.x - a2.x) * (py - a2.y)) / den
				var l3b: float = 1.0 - l1b - l2b
				if l1b < -0.02 or l2b < -0.02 or l3b < -0.02:
					continue                                                # texels on a triangle's edge are included, so no gap shows between triangles
				var rr: float = l1b * pr[0].x + l2b * pr[1].x + l3b * pr[2].x
				var uu: float = l1b * pr[0].y + l2b * pr[1].y + l3b * pr[2].y
				var cx := _px(rr)
				var cy := _py(uu)
				if cx < 0.0 or cx > 999.0 or cy < 0.0 or cy > 999.0:
					continue
				var alpha := _bil(al, cx, cy).r
				if alpha < 0.004:
					continue
				for nm in NAMES:
					var c := _bil(comps[nm], cx, cy)
					(patches[nm] as Image).set_pixel(clampi(x, 0, tw - 1), clampi(y, 0, th - 1), Color(c.r, c.g, c.b, alpha))
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	# a fragment near a triangle's edge can sample a texel whose centre lies just outside it (the painted padding): those texels get the nearest written value too, 2 texels out
	for nm in NAMES:
		var img: Image = patches[nm]
		for pass_i in 2:
			var snap := img.duplicate() as Image
			for y in range(maxi(miny - 2, 1), mini(maxy + 3, th - 1)):
				for x in range(maxi(minx - 2, 1), mini(maxx + 3, tw - 1)):
					if snap.get_pixel(x, y).a > 0.0:
						continue
					var best := Color(0, 0, 0, 0)
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
						var c := snap.get_pixel(x + d.x, y + d.y)
						if c.a > best.a:
							best = c
					if best.a > 0.0:
						img.set_pixel(x, y, best)
	print("BAKE triangles ", tri_used, " texel box ", minx, ",", miny, " - ", maxx, ",", maxy)
	var out_dir := "res://game/prototypes/npc_meshy/face_bake/%s/" % slug
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	for nm in NAMES:
		var crop := (patches[nm] as Image).get_region(Rect2i(minx, miny, bw, bh))
		crop.save_png(ProjectSettings.globalize_path(out_dir + "patch_%s.png" % nm))
	var f := FileAccess.open(out_dir + "rect.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"x": minx, "y": miny, "w": bw, "h": bh, "tex": [tw, th]}))
	f.close()
	quit(0)


func _px(r: float) -> float:
	return 500.0 - (r - centre_r) / SIZE * 1000.0


func _py(u: float) -> float:
	return 500.0 - (u - centre_u) / SIZE * 1000.0


func _col(img: Image, q: Vector2) -> Color:
	return img.get_pixelv(Vector2i(int(q.x * img.get_width()) % img.get_width(), int(q.y * img.get_height()) % img.get_height()))


func _lum(img: Image, q: Vector2) -> float:
	var c := img.get_pixelv(Vector2i(int(q.x * img.get_width()) % img.get_width(), int(q.y * img.get_height()) % img.get_height()))
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


func _bil(img: Image, x: float, y: float) -> Color:
	var fx := x - 0.5
	var fy := y - 0.5
	var ix := clampi(int(floor(fx)), 0, img.get_width() - 2)
	var iy := clampi(int(floor(fy)), 0, img.get_height() - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var ty := clampf(fy - iy, 0.0, 1.0)
	var c00 := img.get_pixel(ix, iy)
	var c10 := img.get_pixel(ix + 1, iy)
	var c01 := img.get_pixel(ix, iy + 1)
	var c11 := img.get_pixel(ix + 1, iy + 1)
	return c00.lerp(c10, tx).lerp(c01.lerp(c11, tx), ty)
