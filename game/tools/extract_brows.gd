extends SceneTree
## Finds the painted eyebrows of a Mixamo-rigged NPC in its own UV texture (they are painted: the mesh has no brow geometry) by rasterising the head's front surface in head space
## (right, up, forward). Writes the region image for checking. Usage: godot --headless --path . --script res://game/tools/extract_brows.gd -- <slug> <out_dir>
const RES := 0.00025                          ## metres per pixel
var R0 := -0.075
var U0 := 0.028
var W := 640
var H := 300
var tri_buf := PackedInt32Array()
var tp := PackedVector3Array()
var tuv := PackedVector2Array()
var tidx := PackedInt32Array()


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var slug: String = a[0]
	var out: String = a[1]
	var n := (load("res://game/prototypes/npc_meshy/CHR_%s_Mixamo.glb" % slug) as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var rg := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightUpLeg")).origin - sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftUpLeg")).origin
	rg.y = 0.0
	var r := rg.normalized()
	var f := Vector3.UP.cross(r).normalized()
	var hp := sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tex := ((mi.get_active_material(0) as BaseMaterial3D).albedo_texture).get_image()
	if tex.is_compressed():
		tex.decompress()
	var p := PackedVector3Array()
	p.resize(v.size())
	for i in v.size():
		var d := v[i] - hp
		p[i] = Vector3(d.dot(r), d.dot(Vector3.UP), d.dot(f))
	var depth := PackedFloat32Array()
	depth.resize(W * H)
	depth.fill(-9.0)
	var uvb := PackedVector2Array()
	uvb.resize(W * H)
	tri_buf.resize(W * H)
	tri_buf.fill(-1)
	tp = p
	tuv = uv
	tidx = idx
	var lum := func(q: Vector2) -> float:
		var c := tex.get_pixelv(Vector2i(int(q.x * tex.get_width()) % tex.get_width(), int(q.y * tex.get_height()) % tex.get_height()))
		return c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	for t in range(0, idx.size(), 3):
		var l0: float = lum.call(uv[idx[t]])
		var l1b: float = lum.call(uv[idx[t + 1]])
		var l2b: float = lum.call(uv[idx[t + 2]])
		var skinlike := maxf(l0, maxf(l1b, l2b)) > 0.45
		var browlike := maxf(l0, maxf(l1b, l2b)) < 0.19
		if not (skinlike or browlike):
			continue                                   # hair (in front of the skin) is not the surface the brows are painted on
		var a0 := p[idx[t]]
		var b0 := p[idx[t + 1]]
		var c0 := p[idx[t + 2]]
		var nrm := (b0 - a0).cross(c0 - a0)
		# front-facing: the normal points along +forward (winding may be either: use the vertex normals' side instead)
		var minr := minf(a0.x, minf(b0.x, c0.x))
		var maxr := maxf(a0.x, maxf(b0.x, c0.x))
		var minu := minf(a0.y, minf(b0.y, c0.y))
		var maxu := maxf(a0.y, maxf(b0.y, c0.y))
		if maxr < R0 or minr > R0 + W * RES or maxu < U0 or minu > U0 + H * RES:
			continue
		var x0 := maxi(int((minr - R0) / RES), 0)
		var x1 := mini(int((maxr - R0) / RES) + 1, W - 1)
		var y0 := maxi(int((minu - U0) / RES), 0)
		var y1 := mini(int((maxu - U0) / RES) + 1, H - 1)
		var den := (b0.y - c0.y) * (a0.x - c0.x) + (c0.x - b0.x) * (a0.y - c0.y)
		if absf(den) < 1e-12:
			continue
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var pr := R0 + (x + 0.5) * RES
				var pu := U0 + (y + 0.5) * RES
				var l1 := ((b0.y - c0.y) * (pr - c0.x) + (c0.x - b0.x) * (pu - c0.y)) / den
				var l2 := ((c0.y - a0.y) * (pr - c0.x) + (a0.x - c0.x) * (pu - c0.y)) / den
				var l3 := 1.0 - l1 - l2
				if l1 < -0.001 or l2 < -0.001 or l3 < -0.001:
					continue
				var z := l1 * a0.z + l2 * b0.z + l3 * c0.z
				if z > depth[y * W + x]:
					depth[y * W + x] = z
					tri_buf[y * W + x] = t
					uvb[y * W + x] = l1 * uv[idx[t]] + l2 * uv[idx[t + 1]] + l3 * uv[idx[t + 2]]
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			if depth[y * W + x] > -8.0:
				var q := uvb[y * W + x]
				img.set_pixel(x, H - 1 - y, tex.get_pixelv(Vector2i(int(q.x * tex.get_width()) % tex.get_width(), int(q.y * tex.get_height()) % tex.get_height())))
			else:
				img.set_pixel(x, H - 1 - y, Color(0, 1, 0))
	img.save_png("%s/%s_region.png" % [out, slug])
	var dimg := Image.create(W, H, false, Image.FORMAT_L8)
	var zmin := 9.0
	var zmax := -9.0
	for i in depth.size():
		if depth[i] > -8.0:
			zmin = minf(zmin, depth[i])
			zmax = maxf(zmax, depth[i])
	for y in H:
		for x in W:
			var z := depth[y * W + x]
			dimg.set_pixel(x, H - 1 - y, Color.BLACK if z < -8.0 else Color.WHITE * ((z - zmin) / maxf(zmax - zmin, 0.001)))
	dimg.save_png("%s/%s_depth.png" % [out, slug])
	print("REGION done z ", zmin, " ", zmax)
	_extract(slug, out, tex, depth, uvb, tex)
	quit(0)


func _px_lum(tex: Image, q: Vector2) -> float:
	var c := tex.get_pixelv(Vector2i(int(q.x * tex.get_width()) % tex.get_width(), int(q.y * tex.get_height()) % tex.get_height()))
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


func _extract(slug: String, out: String, tex: Image, depth: PackedFloat32Array, uvb: PackedVector2Array, _t: Image) -> void:
	var umin_px := int((0.0545 - U0) / RES)
	var umax_px := int((0.092 - U0) / RES)
	var mask := PackedByteArray()
	mask.resize(W * H)
	for y in range(umin_px, umax_px):
		for x in W:
			if depth[y * W + x] > -8.0 and _px_lum(tex, uvb[y * W + x]) < 0.20:
				mask[y * W + x] = 1
	# per column only the dark run that holds the brow's middle (eyelids and pupils below it are not brow)
	var seed_lo := int((0.064 - U0) / RES)
	var seed_hi := int((0.074 - U0) / RES)
	for x in W:
		var keep := PackedByteArray()
		keep.resize(H)
		for y0 in range(seed_lo, seed_hi):
			if mask[y0 * W + x] == 1 and keep[y0] == 0:
				var y := y0
				while y >= umin_px and mask[y * W + x] == 1:
					keep[y] = 1
					y -= 1
				y = y0 + 1
				while y < umax_px and mask[y * W + x] == 1:
					keep[y] = 1
					y += 1
		for y in range(umin_px, umax_px):
			if mask[y * W + x] == 1 and keep[y] == 0:
				mask[y * W + x] = 0
	# the two brows: columns with mask, split at the biggest gap
	var cols := []
	for x in W:
		var any := false
		for y in range(umin_px, umax_px):
			if mask[y * W + x] == 1:
				any = true
				break
		cols.append(any)
	var runs := []
	var start := -1
	var gap := 0
	for x in W:
		if cols[x]:
			if start < 0:
				start = x
			gap = 0
		elif start >= 0:
			gap += 1
			if gap > 20:
				runs.append([start, x - gap])
				start = -1
	if start >= 0:
		runs.append([start, W - 1])
	print("BROW runs ", runs)
	var strips := []
	var mid_r := 0.0
	var n_sec := 8
	for run in runs:
		if run[1] - run[0] < 100:
			continue
		mid_r += (R0 + (run[0] + run[1]) * 0.5 * RES)
	mid_r /= maxf(runs.size(), 1)
	for run in runs:
		if run[1] - run[0] < 100:
			continue
		var r_lo: float = R0 + run[0] * RES
		var r_hi: float = R0 + run[1] * RES
		var inner_is_low: bool = absf(r_lo - mid_r) < absf(r_hi - mid_r)
		# a grid of 1 mm cells over the brow (and a little margin): every cell takes its own UV from the triangle under its centre (extended linearly), so UV seams across the brow do not matter
		var top := -1
		var bot := 99999
		for xx in range(run[0], run[1] + 1):
			for y in range(umin_px, umax_px):
				if mask[y * W + xx] == 1:
					top = maxi(top, y)
					bot = mini(bot, y)
		var step := 0.001
		var u_lo := U0 + (bot - 3) * RES
		var u_hi := U0 + (top + 4) * RES
		var nr := int(ceil((r_hi - r_lo) / step))
		var nu := int(ceil((u_hi - u_lo) / step))
		var fs := []
		for j in nu + 1:
			for i in nr + 1:
				var px := clampi(int((r_lo + i * step - R0) / RES), 0, W - 1)
				var py := clampi(int((u_lo + j * step - U0) / RES), 0, H - 1)
				var fz := -9.0
				for dy in range(-6, 7):
					for dx in range(-6, 7):
						var qx := clampi(px + dx, 0, W - 1)
						var qy := clampi(py + dy, 0, H - 1)
						if depth[qy * W + qx] > -8.0:
							fz = maxf(fz, depth[qy * W + qx]) if dx * dx + dy * dy <= 4 else fz
				if fz < -8.0:
					for dy in range(-6, 7):
						for dx in range(-6, 7):
							var qx := clampi(px + dx, 0, W - 1)
							var qy := clampi(py + dy, 0, H - 1)
							fz = maxf(fz, depth[qy * W + qx])
				fs.append(snappedf(fz, 0.00001))
		var cells := []
		for j in nu:
			for i in nr:
				var cr := r_lo + (i + 0.5) * step
				var cu := u_lo + (j + 0.5) * step
				var px := clampi(int((cr - R0) / RES), 0, W - 1)
				var py := clampi(int((cu - U0) / RES), 0, H - 1)
				var tt := tri_buf[py * W + px]
				if tt < 0:
					cells.append([0, 0, 0, 0, 0, 0, 0, 0, 0])
					continue
				var a3: Vector3 = tp[tidx[tt]]
				var b3: Vector3 = tp[tidx[tt + 1]]
				var c3: Vector3 = tp[tidx[tt + 2]]
				var den := (b3.y - c3.y) * (a3.x - c3.x) + (c3.x - b3.x) * (a3.y - c3.y)
				var cell := [1]
				for corner in [[0, 0], [1, 0], [0, 1], [1, 1]]:
					var pr: float = r_lo + (i + corner[0]) * step
					var pu: float = u_lo + (j + corner[1]) * step
					var l1: float = ((b3.y - c3.y) * (pr - c3.x) + (c3.x - b3.x) * (pu - c3.y)) / den
					var l2: float = ((c3.y - a3.y) * (pr - c3.x) + (a3.x - c3.x) * (pu - c3.y)) / den
					var l3: float = 1.0 - l1 - l2
					var q: Vector2 = l1 * tuv[tidx[tt]] + l2 * tuv[tidx[tt + 1]] + l3 * tuv[tidx[tt + 2]]
					cell.append(snappedf(q.x, 0.000001))
					cell.append(snappedf(q.y, 0.000001))
				cells.append(cell)
		strips.append({"inner_low": inner_is_low, "r0": r_lo, "u0": u_lo, "step": step, "nr": nr, "nu": nu, "f": fs, "cells": cells})
	# the texels to wipe: the brow's own texels and their dark rim, filled with the skin above / below
	var w := tex.get_width()
	var h := tex.get_height()
	var patch := {}
	for y in range(umin_px - 6, umax_px + 6):
		for x in W:
			var near := false
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					var yy := y + dy
					var xx := x + dx
					if yy >= 0 and yy < H and xx >= 0 and xx < W and mask[yy * W + xx] == 1:
						near = true
			if not near or depth[y * W + x] < -8.0:
				continue
			var q := uvb[y * W + x]
			if _px_lum(tex, q) > 0.48:
				continue
			# nearest un-masked, light pixels straight up and straight down
			var up := y
			while up < H - 1 and (mask[up * W + x] == 1 or _px_lum(tex, uvb[up * W + x]) < 0.40 or depth[up * W + x] < -8.0) and up - y < 40:
				up += 1
			var dn := y
			while dn > 0 and (mask[dn * W + x] == 1 or _px_lum(tex, uvb[dn * W + x]) < 0.40 or depth[dn * W + x] < -8.0) and y - dn < 40:
				dn -= 1
			var cu := tex.get_pixelv(Vector2i(int(uvb[up * W + x].x * w) % w, int(uvb[up * W + x].y * h) % h))
			var cd := tex.get_pixelv(Vector2i(int(uvb[dn * W + x].x * w) % w, int(uvb[dn * W + x].y * h) % h))
			var tfrac := float(y - dn) / maxf(float(up - dn), 1.0)
			var col := cd.lerp(cu, tfrac)
			var key := Vector2i(int(q.x * w) % w, int(q.y * h) % h)
			patch[key] = col
			# the texture is finer than the 0.25 mm pixels: the neighbouring dark texels no pixel centre landed on get the same fill
			for dy2 in range(-2, 3):
				for dx2 in range(-2, 3):
					var nk := Vector2i(key.x + dx2, key.y + dy2)
					if not patch.has(nk) and nk.x >= 0 and nk.x < w and nk.y >= 0 and nk.y < h:
						var nc := tex.get_pixelv(nk)
						if nc.r * 0.3 + nc.g * 0.59 + nc.b * 0.11 < 0.48:
							patch[nk] = col
	var flat := []
	for k in patch:
		var c: Color = patch[k]
		flat.append_array([k.x, k.y, int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://game/prototypes/npc_meshy/face_fit"))
	var f := FileAccess.open("res://game/prototypes/npc_meshy/face_fit/%s_brows.json" % slug, FileAccess.WRITE)
	f.store_string(JSON.stringify({"strips": strips, "patch": flat, "tex": [w, h]}))
	f.close()
	# a check image: the region with the wiped texels (what the head looks like without brows) and the strip outlines
	var chk := Image.create(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			if depth[y * W + x] < -8.0:
				chk.set_pixel(x, H - 1 - y, Color(0, 1, 0))
				continue
			var q := uvb[y * W + x]
			var key := Vector2i(int(q.x * w) % w, int(q.y * h) % h)
			chk.set_pixel(x, H - 1 - y, patch[key] if patch.has(key) else tex.get_pixelv(key))
	chk.save_png("%s/%s_nobrow.png" % [out, slug])
	print("BROWS strips ", strips.size(), " patch texels ", patch.size())
	_eye_mask(slug, tex, depth, uvb)


## The painted eyes (white and pupil pixels) of this model, as a mask in the FACE IMAGE's space (through the fit in face_fit/<slug>.json): the expression image replaces the whole
## painted eye, so no corner of the old eye is left beside a blink or a wide eye.
func _eye_mask(slug: String, tex: Image, depth: PackedFloat32Array, uvb: PackedVector2Array) -> void:
	var fit = JSON.parse_string(FileAccess.get_file_as_string("res://game/prototypes/npc_meshy/face_fit/%s.json" % slug))
	var sc: float = fit["scale"]
	var dr: float = fit["dr"]
	var du: float = fit["du"]
	var pu: Array = fit["u"]
	var pv: Array = fit["v"]
	var em := PackedByteArray()
	em.resize(128 * 128)
	for y in H:
		for x in W:
			if depth[y * W + x] < -8.0:
				continue
			var r := R0 + (x + 0.5) * RES
			var u := U0 + (y + 0.5) * RES
			if u < 0.030 or u > 0.0585 or r < -0.05 or r > 0.07:
				continue
			var l := _px_lum(tex, uvb[y * W + x])
			if l > 0.22 and l < 0.72:
				continue
			var ux: float = pu[0] * (r / sc + dr) + pu[2]
			var vy: float = pv[1] * (u / sc + du) + pv[2]
			if ux < 0.29 or ux > 0.70:
				continue
			var ix := clampi(int(ux * 127.0), 0, 127)
			var iy := clampi(int(vy * 127.0), 0, 127)
			em[iy * 128 + ix] = 1
	var out := PackedByteArray()
	out.resize(128 * 128)
	for y in 128:
		for x in 128:
			if em[y * 128 + x] == 1:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var xx := x + dx
						var yy := y + dy
						if xx >= 0 and xx < 128 and yy >= 0 and yy < 128:
							out[yy * 128 + xx] = 255
	var img := Image.create_from_data(128, 128, false, Image.FORMAT_L8, out)
	img.save_png("res://game/prototypes/npc_meshy/face_fit/%s_eyes.png" % slug)
	print("EYES mask saved")
