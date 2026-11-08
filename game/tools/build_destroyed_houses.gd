extends SceneTree
## THE VEIL - builds the post-time-skip damaged houses (game/world/destroyed/<HOUSE>.glb) from the real house
## models. Nothing is modelled from scratch: each variant's exterior shell, interior and furnishing meshes are
## copied and broken in 3D (triangles removed for breaches / broken glass / torn roofs, vertices crushed, sagged
## or bent), the doors are kept, hung open, knocked flat or left out, and rubble chunks cut from the house's own
## materials lie on the ground around the damage. The game swaps a house for its damaged model after
## p3_two_hours_later (game/world/town_destruction.gd), which also puts the original materials back by name and
## builds the collision from these meshes.
##   godot --headless --path . --script res://game/tools/build_destroyed_houses.gd
## Deterministic (seeded per house): rerunning gives the same models.

const VARIANTS := "res://THE_VEIL_ASSETS_V2/03_Residential/House_Variants/"
const OUT := "res://game/world/destroyed/"
## house id -> [house type, damage kind]   (kept in step with town_destruction.gd TARGETS). Every house that is not
## lootable and not part of a story scene. One model is built per (type, kind) and shared by the houses using it.
const TARGETS := {
	"HOUSE_02": ["RES_House_TwoStorey", "shellcrawler"],
	"HOUSE_09": ["RES_House_Ranch_C_Mirror", "tentacle"],
	"HOUSE_10": ["RES_House_MillWorker", "evacuation"],
	"HOUSE_11": ["RES_House_Cottage_B_Mirror", "evacuation"],
	"HOUSE_12": ["RES_House_TwoStorey_Mirror", "hound"],
	"HOUSE_14": ["RES_House_TwoStorey", "colossus"],
	"HOUSE_16": ["RES_House_MillWorker_B", "hound"],
	"HOUSE_17": ["RES_House_TwoStorey_B", "shellcrawler"],
	"HOUSE_18": ["RES_House_Ranch_B", "skitter"],
	"HOUSE_21": ["RES_House_SplitLevel_B", "shellcrawler"],
	"EXT_HOUSE_01": ["RES_House_TwoStorey_Mirror", "hound"],
	"EXT_HOUSE_02": ["RES_House_TwoStorey", "evacuation"],
	"EXT_HOUSE_05": ["RES_House_TwoStorey", "skitter"],
	"EXT_HOUSE_06": ["RES_House_Ranch_C_Mirror", "tentacle"],
	"EXT_HOUSE_07": ["RES_House_MillWorker_B", "hound"],
	"EXT_HOUSE_09": ["RES_House_TwoStorey_Mirror", "evacuation"],
	"EXT_HOUSE_11": ["RES_House_TwoStorey", "colossus"],
	"EXT_HOUSE_12": ["RES_House_Ranch_B", "skitter"],
	"EXT_HOUSE_13": ["RES_House_MillWorker", "tentacle"],
	"EXT_HOUSE_14": ["RES_House_TwoStorey", "shellcrawler"],
	"EXT_HOUSE_15": ["RES_House_TwoStorey", "evacuation"],
	"EXT_HOUSE_17": ["RES_House_TwoStorey", "skitter"],
	"EXT_HOUSE_18": ["RES_House_TwoStorey", "colossus"],
	"EXT_HOUSE_19": ["RES_House_Ranch_C_Mirror", "hound"],
	"EXT_HOUSE_20": ["RES_House_TwoStorey", "shellcrawler"],
	"EXT_HOUSE_22": ["RES_House_TwoStorey_B", "skitter"],
	"EXT_HOUSE_23": ["RES_House_TwoStorey", "evacuation"],
	"EXT_HOUSE_26": ["RES_House_MillWorker", "evacuation"],
	"EXT_HOUSE_28": ["RES_House_TwoStorey", "skitter"],
	"EXT_HOUSE_29": ["RES_House_Cottage_B_Mirror", "evacuation"],
	"EXT_HOUSE_32": ["RES_House_TwoStorey", "colossus"],
	"EXT_HOUSE_33": ["RES_House_MillWorker_B", "colossus"],
	"EXT_HOUSE_35": ["RES_House_TwoStorey_B", "shellcrawler"],
	"EXT_HOUSE_39": ["RES_House_TwoStorey", "evacuation"],
	"EXT_HOUSE_40": ["RES_House_MillWorker", "tentacle"],
	"PLAYER_HOME": ["Player_Home", "home"],
}
const HOME_SCENE := "res://THE_VEIL_ASSETS_V2/03_Residential/Player_Home/Player_Home.tscn"

var rng := RandomNumberGenerator.new()
var dark: StandardMaterial3D
var blood: StandardMaterial3D
var mud: StandardMaterial3D
var report := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	dark = _flat("M_Destroy_Soot", Color(0.07, 0.065, 0.06))
	blood = _flat("M_Destroy_Stain", Color(0.24, 0.05, 0.04))
	mud = _flat("M_Destroy_Mud", Color(0.16, 0.13, 0.1))
	var combos := {}
	for id in TARGETS:
		var spec: Array = TARGETS[id]
		combos["%s__%s" % [spec[0], spec[1]]] = spec
	for key in combos:
		var spec: Array = combos[key]
		rng.seed = hash(key)
		var ok := _build(String(key), String(spec[0]), String(spec[1]))
		print("BUILT %s %s %s" % [key, "ok" if ok else "FAILED", report.get(key, {})])
	quit(0)


func _flat(n: String, c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = n
	m.albedo_color = c
	m.roughness = 1.0
	return m


# ------------------------------------------------------------------ one house
var _src_root: Node3D
var _meta: Dictionary
var _box: AABB                     ## the exterior shell's bounds (house-root space)


func _build(id: String, variant: String, kind: String) -> bool:
	var ps := load(HOME_SCENE if variant == "Player_Home" else VARIANTS + variant + ".tscn") as PackedScene
	if ps == null:
		return false
	_src_root = ps.instantiate() as Node3D
	root.add_child(_src_root)
	_meta = _src_root.get_meta("veil_house", {})
	var ext := _src_root.find_child("*_Exterior", true, false) as MeshInstance3D
	var inte := _src_root.find_child("*_Interior", true, false) as MeshInstance3D
	var furn := _src_root.find_child("*_Furnishing_Mesh", true, false) as MeshInstance3D
	_box = _rel(ext) * ext.mesh.get_aabb()
	var out := Node3D.new()
	out.name = id + "_Destroyed"
	var r := {}
	match kind:
		"colossus": _colossus(out, ext, inte, furn, r)
		"skitter": _skitter(out, ext, inte, furn, r)
		"tentacle": _tentacle(out, ext, inte, furn, r)
		"hound": _hound(out, ext, inte, furn, r)
		"shellcrawler": _shellcrawler(out, ext, inte, furn, r)
		"evacuation": _evacuation(out, ext, inte, furn, r)
		"home": _home(out, ext, r)
	report[id] = r
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	root.add_child(out)
	var err := doc.append_from_scene(out, st)
	if err == OK:
		err = doc.write_to_filesystem(st, ProjectSettings.globalize_path(OUT + id + ".glb"))
	out.queue_free()
	_src_root.queue_free()
	return err == OK


func _rel(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p and p != _src_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## The material as exported: same name (the game puts the house's own material back by it), no textures inside
## the file (each GLB would otherwise carry every texture of the house again).
var _ph := {}


func _placeholder(m: Material) -> Material:
	if m == null:
		return null
	var n := String(m.resource_name)
	if n.begins_with("M_Destroy_"):
		return m
	if not _ph.has(n):
		var p := StandardMaterial3D.new()
		p.resource_name = n
		if m is StandardMaterial3D:
			p.albedo_color = (m as StandardMaterial3D).albedo_color
		_ph[n] = p
	return _ph[n]


func _ph_mesh(src: Mesh) -> Mesh:
	var m := src.duplicate() as Mesh
	if m is ArrayMesh:
		for i in m.get_surface_count():
			m.surface_set_material(i, _placeholder(src.surface_get_material(i)))
	return m


func _door(name: String) -> MeshInstance3D:
	return _src_root.find_child(name, true, false) as MeshInstance3D


func _door_center(name: String) -> Vector3:
	for d in _meta.get("doors", []):
		if String(d.get("name", "")) == name:
			var c: Array = d["center"]
			return Vector3(c[0], c[1], c[2])
	return Vector3.INF


## Copy a mesh into the output in house-root space: `move` bends vertices, `keep` decides per triangle.
func _copy(out: Node3D, src: MeshInstance3D, nm: String, move: Callable, keep: Callable) -> MeshInstance3D:
	if src == null:
		return null
	var xf := _rel(src)
	var m := ArrayMesh.new()
	var removed := 0
	for s in src.mesh.get_surface_count():
		var mat := src.mesh.surface_get_material(s)
		var mname := String(mat.resource_name) if mat else ""
		var a := src.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm = a[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i in v.size():
				idx.append(i)
		var nv := PackedVector3Array()
		nv.resize(v.size())
		for i in v.size():
			var p: Vector3 = xf * v[i]
			nv[i] = move.call(p, mname) if move.is_valid() else p
		if nrm is PackedVector3Array:
			var nn := PackedVector3Array()
			nn.resize((nrm as PackedVector3Array).size())
			for i in nn.size():
				nn[i] = (xf.basis * nrm[i]).normalized()
			a[Mesh.ARRAY_NORMAL] = nn
		a[Mesh.ARRAY_TANGENT] = null
		var ni := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var p0: Vector3 = xf * v[idx[t]]
			var p1: Vector3 = xf * v[idx[t + 1]]
			var p2: Vector3 = xf * v[idx[t + 2]]
			if keep.is_valid() and not keep.call((p0 + p1 + p2) / 3.0, mname, p0, p1, p2):
				removed += 1
				continue
			ni.append(idx[t])
			ni.append(idx[t + 1])
			ni.append(idx[t + 2])
		if ni.is_empty():
			continue
		a[Mesh.ARRAY_VERTEX] = nv
		a[Mesh.ARRAY_INDEX] = ni
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(m.get_surface_count() - 1, _placeholder(mat))
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	out.add_child(mi)
	mi.set_meta("removed", removed)
	return mi


## The remaining doors, fixtures as they were (except `skip`); `xf_of` may swing / move one.
func _doors(out: Node3D, skip: Array, xf_of := {}) -> void:
	for n in _src_root.find_children("INT_*", "MeshInstance3D", true, false):
		var nm := String(n.name)
		if nm.contains("LightSwitch") or skip.has(nm) or not (n.get_parent() is Node3D and String(n.get_parent().name).begins_with("RES_House")):
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Door_" + nm
		mi.mesh = _ph_mesh((n as MeshInstance3D).mesh)
		mi.transform = xf_of.get(nm, _rel(n as Node3D))
		out.add_child(mi)


func _glass(mname: String) -> bool:
	return mname.contains("Glass")


func _roof(mname: String) -> bool:
	return mname.contains("Roof")


## A rough chunk of the house's own material lying on the ground (its lowest corner touching it).
func _chunk(out: Node3D, at: Vector2, size: Vector3, mat: Material, tilt := 0.35) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var c: Array = []
	for i in 8:
		var p := Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1))
		c.append(p * Vector3(rng.randf_range(0.75, 1.15), rng.randf_range(0.7, 1.1), rng.randf_range(0.75, 1.15)))
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	for f in faces:
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var d: Vector3 = c[f[2]]
		var n := (b - a).cross(d - a).normalized()
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for k in tri:
				st.set_normal(n)
				st.set_uv(uvs[k] * Vector2(size.x, size.y) * 0.5)
				st.add_vertex(c[f[k]])
	st.set_material(_placeholder(mat))
	var mi := MeshInstance3D.new()
	mi.name = "Debris_%d" % out.get_child_count()
	mi.mesh = st.commit()
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(-tilt, tilt)) * Basis(Vector3.FORWARD, rng.randf_range(-tilt, tilt))
	var low := INF
	for p in c:
		low = minf(low, (basis * (p as Vector3)).y)
	mi.transform = Transform3D(basis, Vector3(at.x, -low - 0.04, at.y))     # resting on the ground, a little sunk in
	out.add_child(mi)


## A flat mark on the ground or a wall (soot, stains, scrapes, prints): a polygon a hair off the surface.
func _mark(out: Node3D, pts: PackedVector2Array, mat: Material, xf: Transform3D, nm: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(pts)
	for i in tris:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(pts[i].x, 0.0, pts[i].y))
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.transform = xf
	out.add_child(mi)


func _blob(r: float, n := 9, rough := 0.35) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(Vector2(cos(a), sin(a)) * r * rng.randf_range(1.0 - rough, 1.0 + rough))
	return p


func _mats(src: MeshInstance3D, want: Array) -> Array:
	var out: Array = []
	for s in src.mesh.get_surface_count():
		var m := src.mesh.surface_get_material(s)
		if m and want.any(func(w): return String(m.resource_name).contains(w)):
			out.append(m)
	return out


func _rubble(out: Node3D, centre: Vector2, r0: float, r1: float, n: int, mats: Array, big := 1.0) -> void:
	for i in n:
		var a := rng.randf_range(0.0, TAU)
		var d := sqrt(rng.randf_range(r0 * r0, r1 * r1))
		var at := centre + Vector2(cos(a), sin(a)) * d
		if _box.grow(-0.3).has_point(Vector3(at.x, 0.5, at.y)) and rng.randf() < 0.5:
			continue                                         # mostly outside the walls (inside is the house's floor)
		var s := Vector3(rng.randf_range(0.3, 1.1), rng.randf_range(0.12, 0.45), rng.randf_range(0.3, 0.9)) * big
		_chunk(out, at, s, mats[rng.randi() % mats.size()])


func _noise3(p: Vector3) -> float:
	return sin(p.x * 3.1 + p.z * 1.7) * 0.5 + sin(p.y * 4.3 - p.x * 2.2) * 0.3 + sin(p.z * 5.9 + p.y) * 0.2


# ------------------------------------------------------------------ A. the Colossus stepped on it
func _colossus(out: Node3D, ext: MeshInstance3D, inte: MeshInstance3D, furn: MeshInstance3D, r: Dictionary) -> void:
	var c := Vector2(_box.get_center().x + _box.size.x * 0.12, _box.get_center().z + _box.size.z * 0.08)
	var R := maxf(_box.size.x, _box.size.z) * 0.62
	var floor_y := 1.0
	var crush := func(p: Vector3, _m: String) -> Vector3:
		if p.y <= floor_y:
			return p
		var d := Vector2(p.x, p.z).distance_to(c) / R
		var f := clampf(1.0 - d, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		var flat := floor_y + (p.y - floor_y) * 0.2 + _noise3(p) * 0.18
		var out_dir := Vector2(p.x, p.z) - c
		out_dir = out_dir.normalized() if out_dir.length() > 0.01 else Vector2.ZERO
		var q := Vector3(p.x, lerpf(p.y, flat, f), p.z)
		q += Vector3(out_dir.x, 0, out_dir.y) * (p.y - floor_y) * 0.1 * f    # the walls splay out under the weight
		return q
	var keep := func(ct: Vector3, m: String, _a, _b, _cc) -> bool:
		var d := Vector2(ct.x, ct.z).distance_to(c) / R
		if _glass(m):
			return rng.randf() > 0.75
		if ct.y > floor_y + 0.6 and d < 0.55 and rng.randf() < 0.22:
			return false                                     # torn through where the foot came down
		return true
	var e := _copy(out, ext, "Exterior", crush, keep)
	_copy(out, inte, "Interior", crush, keep)
	_copy(out, furn, "Furnishing", crush, Callable())
	_doors(out, [], {})
	var mats := _mats(ext, ["Siding", "Roof", "Brick", "Trim", "Planks"])
	_rubble(out, c, R * 0.55, R * 1.35, 34, mats, 1.2)
	# the print beside it: a heel and three toes, pressed into the yard (with a lip of thrown-up earth)
	var px := Vector2(_box.position.x - 3.0, _box.get_center().z - 1.0)
	_mark(out, _blob(2.4, 11, 0.2), mud, Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3(1.0, 1.0, 1.5)), Vector3(px.x, 0.035, px.y)), "Print_Heel")
	for k in 3:
		var a := -0.55 + k * 0.55 + 0.3
		var toe := px + Vector2(sin(a), -cos(a)) * 4.4
		_mark(out, _blob(1.0, 9, 0.25), mud, Transform3D(Basis(Vector3.UP, a).scaled(Vector3(1.0, 1.0, 2.2)), Vector3(toe.x, 0.036, toe.y)), "Print_Toe%d" % k)
	_rubble(out, px, 3.2, 4.6, 14, [mud, mats[0]], 0.7)
	r["removed"] = e.get_meta("removed")


# ------------------------------------------------------------------ B. Skitters live in it now
func _skitter(out: Node3D, ext: MeshInstance3D, inte: MeshInstance3D, furn: MeshInstance3D, r: Dictionary) -> void:
	var b := _box
	var hole := Vector3(b.position.x + b.size.x * 0.25, b.end.y - 0.4, b.get_center().z + b.size.z * 0.15)
	var keep := func(ct: Vector3, m: String, _a, _b, _c) -> bool:
		if _glass(m):
			return rng.randf() > 0.9                         # nearly every pane broken
		if m.contains("BulbGlow"):
			return false                                     # dark inside
		if ct.distance_to(hole) < 1.4 + _noise3(ct) * 0.4:
			return false                                     # a hole torn in the roof
		if _roof(m):
			var edge := minf(minf(ct.x - b.position.x, b.end.x - ct.x), minf(ct.z - b.position.z, b.end.z - ct.z))
			if edge < 0.9 and rng.randf() < 0.45:
				return false                                 # chewed eaves
		return true
	var e := _copy(out, ext, "Exterior", Callable(), keep)
	_copy(out, inte, "Interior", Callable(), keep)
	_copy(out, furn, "Furnishing", Callable(), func(_ct, m, _a, _b, _c): return not m.contains("Glow"))
	_doors(out, [])
	var mats := _mats(ext, ["Roof", "Trim", "Siding"])
	_rubble(out, Vector2(hole.x, b.position.z - 0.8), 0.2, 2.2, 8, mats, 0.6)
	r["removed"] = e.get_meta("removed")
	r["window_spot"] = _front_window(ext)


## The front window most in view (a broken pane a Skitter shows behind): house-root space.
func _front_window(ext: MeshInstance3D) -> Vector3:
	var xf := _rel(ext)
	var best := Vector3.INF
	for s in ext.mesh.get_surface_count():
		var m := ext.mesh.surface_get_material(s)
		if m == null or not _glass(String(m.resource_name)):
			continue
		for p in ext.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var q: Vector3 = xf * (p as Vector3)
			if q.y > 0.8 and q.y < 2.6 and (best == Vector3.INF or q.z < best.z - 0.05):
				best = q
	return best


# ------------------------------------------------------------------ C. a tentacle burst through the garage
func _tentacle(out: Node3D, ext: MeshInstance3D, inte: MeshInstance3D, furn: MeshInstance3D, r: Dictionary) -> void:
	var gd := _door_center("INT_GarageDoor_Garage")
	var c := gd + Vector3(0.0, 1.2, 0.0) if gd.is_finite() else Vector3(_box.end.x - 2.5, 1.2, _box.position.z)
	var hole_r := func(p: Vector3) -> float:
		return 1.9 + _noise3(p * 1.7) * 0.55
	var bend := func(p: Vector3, _m: String) -> Vector3:
		var d := p.distance_to(c)
		var hr: float = hole_r.call(p)
		if d < hr + 1.4:
			var f := clampf(1.0 - (d - hr) / 1.4, 0.0, 1.0)
			return p + Vector3(0, -0.05, 0.35) * f                # the wall around it bent inward
		return p
	var keep := func(ct: Vector3, m: String, _a, _b, _c) -> bool:
		if _glass(m):
			return rng.randf() > 0.45
		return ct.distance_to(c) > hole_r.call(ct)
	var e := _copy(out, ext, "Exterior", bend, keep)
	_copy(out, inte, "Interior", bend, keep)
	_doors(out, ["INT_GarageDoor_Garage"])
	var mats := _mats(ext, ["Siding", "Trim", "Foundation"])
	_rubble(out, Vector2(c.x, c.z - 1.2), 0.3, 3.2, 22, mats, 0.9)
	# the garage door, torn off and thrown on the drive
	var g := _door("INT_GarageDoor_Garage")
	if g:
		var mi := MeshInstance3D.new()
		mi.name = "Debris_GarageDoor"
		mi.mesh = _ph_mesh(g.mesh)
		mi.transform = Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -PI * 0.5 + 0.06), Vector3(c.x - 1.6, 0.12, c.z - 4.2))
		out.add_child(mi)
	_mark(out, _blob(1.6, 10, 0.4), dark, Transform3D(Basis(), Vector3(c.x, 0.03, c.z - 2.2)), "Residue")
	r["removed"] = e.get_meta("removed")
	r["breach"] = c


# ------------------------------------------------------------------ D. Hounds forced their way in
func _hound(out: Node3D, ext: MeshInstance3D, inte: MeshInstance3D, furn: MeshInstance3D, r: Dictionary) -> void:
	var fd := _door_center("INT_Door_Front")
	var keep := func(ct: Vector3, m: String, _a, _b, _c) -> bool:
		if _glass(m):
			return rng.randf() > 0.6
		if fd.is_finite() and absf(ct.x - fd.x) < 0.75 and ct.y < fd.y + 2.3 and ct.y > fd.y - 0.1 and absf(ct.z - fd.z) < 0.35 and m.contains("Trim"):
			return rng.randf() > 0.5                         # the frame splintered
		return true
	var e := _copy(out, ext, "Exterior", Callable(), keep)
	_copy(out, inte, "Interior", Callable(), keep)
	_doors(out, ["INT_Door_Front"])
	var d := _door("INT_Door_Front")
	if d and fd.is_finite():
		var mi := MeshInstance3D.new()
		mi.name = "Debris_FrontDoor"
		mi.mesh = _ph_mesh(d.mesh)
		mi.transform = Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(fd.x - 0.3, fd.y + 0.09, fd.z + 1.3))
		out.add_child(mi)
		# claw marks on the siding beside the door, and on the frame (a hair off the wall)
		for k in 2:
			var wx := fd.x + (0.85 if k == 0 else -0.85)
			for s in 4:
				var pts := PackedVector2Array([Vector2(-0.025, 0), Vector2(0.025, 0), Vector2(0.06, 0.9), Vector2(0.03, 0.9)])
				var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, 0.25), Vector3(wx + s * 0.07, fd.y + 0.7 + s * 0.04, fd.z - 0.03))
				_mark(out, pts, dark, xf, "Claw_%d_%d" % [k, s])
		# where it happened: stains on the porch and the hall floor, small
		for k in 3:
			var at := Vector3(fd.x + rng.randf_range(-0.8, 0.8), fd.y + 0.012, fd.z + rng.randf_range(-0.9, 1.6))
			_mark(out, _blob(rng.randf_range(0.14, 0.32), 8, 0.4), blood, Transform3D(Basis(), at), "Stain_%d" % k)
	r["removed"] = e.get_meta("removed")
	r["door"] = fd


# ------------------------------------------------------------------ E. a Shellcrawler brought a corner down
func _shellcrawler(out: Node3D, ext: MeshInstance3D, inte: MeshInstance3D, furn: MeshInstance3D, r: Dictionary) -> void:
	var b := _box
	var corner := Vector3(b.end.x, 0.0, b.position.z)
	var R := 4.6
	var sag := func(p: Vector3, _m: String) -> Vector3:
		var d := Vector2(p.x - corner.x, p.z - corner.z).length()
		var f := clampf(1.0 - d / R, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		var q := p
		q.y = p.y * (1.0 - 0.6 * f) + _noise3(p) * 0.12 * f
		q += Vector3(0.35, 0, -0.35) * f * (p.y / maxf(b.size.y, 1.0))         # leaning out over the crushed corner
		return q
	var keep := func(ct: Vector3, m: String, _a, _b, _c) -> bool:
		if _glass(m):
			return rng.randf() > 0.7
		var d := Vector2(ct.x - corner.x, ct.z - corner.z).length()
		return d > 1.7 + _noise3(ct) * 0.5                  # the corner itself is gone
	var e := _copy(out, ext, "Exterior", sag, keep)
	_copy(out, inte, "Interior", sag, keep)
	_copy(out, furn, "Furnishing", sag, Callable())
	_doors(out, [])
	var mats := _mats(ext, ["Siding", "Brick", "Foundation", "Roof", "Trim"])
	_rubble(out, Vector2(corner.x, corner.z), 0.0, 3.4, 30, mats, 1.1)
	# cracks up the foundation, and the scrape marks it left dragging itself across the drive
	for k in 3:
		var zz := PackedVector2Array([Vector2(0, -0.05), Vector2(0.9, 0.02), Vector2(1.6, -0.06), Vector2(1.6, 0.0), Vector2(0.9, 0.08), Vector2(0, 0.02)])
		_mark(out, zz, dark, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, rng.randf_range(-0.6, 0.6)),
			Vector3(b.position.x + 1.5 + k * 2.6, 0.25, b.position.z - 0.02)), "Crack_%d" % k)
	for k in 3:
		var pts := PackedVector2Array([Vector2(-0.06, 0), Vector2(0.06, 0), Vector2(0.09, -7.0), Vector2(-0.03, -7.0)])
		_mark(out, pts, dark, Transform3D(Basis(Vector3.UP, 0.12), Vector3(corner.x - 1.2 + k * 0.45, 0.03, corner.z - 0.5)), "Scrape_%d" % k)
	r["removed"] = e.get_meta("removed")
	r["corner"] = corner


# ------------------------------------------------------------------ F. they left in a hurry (people, not creatures)
func _evacuation(out: Node3D, ext: MeshInstance3D, inte: MeshInstance3D, furn: MeshInstance3D, r: Dictionary) -> void:
	var keep := func(_ct: Vector3, m: String, _a, _b, _c) -> bool:
		return not _glass(m) or rng.randf() > 0.2
	var e := _copy(out, ext, "Exterior", Callable(), keep)
	_copy(out, inte, "Interior", Callable(), Callable())
	var d := _door("INT_Door_Front")
	var open := {}
	if d:
		open["INT_Door_Front"] = _rel(d) * Transform3D(Basis(Vector3.UP, -1.3), Vector3.ZERO)   # left wide open
	_doors(out, [], open)
	# boards nailed across the front windows (over the frame, flat on the wall)
	var planks := _mats(ext, ["Planks"])
	if planks.is_empty():
		planks = _mats(furn, ["WoodDark", "WoodLight"])
	var w := _front_window(ext)
	var nboard := 0
	if w.is_finite() and not planks.is_empty():
		for k in 3:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var bx := BoxMesh.new()
			bx.size = Vector3(1.5, 0.16, 0.04)
			var mi := MeshInstance3D.new()
			mi.name = "Board_%d" % k
			mi.mesh = bx
			bx.material = _placeholder(planks[0])
			mi.transform = Transform3D(Basis(Vector3.FORWARD, [0.18, -0.12, 0.05][k]), Vector3(w.x - 0.55, w.y - 0.45 + k * 0.42, w.z - 0.06))
			out.add_child(mi)
			nboard += 1
	r["removed"] = e.get_meta("removed")
	r["boards"] = nboard
	r["door"] = _door_center("INT_Door_Front")


# ------------------------------------------------------------------ the protagonist's home: its back corner stepped on
## Shell only (the game keeps the home's own doors, rooms, furniture and collision): the exterior's back corner
## (away from the front door and the drive) crushed down, the roof torn there, rubble behind it and a print in the
## back yard. The windows in the crushed part are hidden by the game.
func _home(out: Node3D, ext: MeshInstance3D, r: Dictionary) -> void:
	var c := Vector2(_box.position.x + 2.2, _box.end.z - 2.2)
	var R := 5.0
	var floor_y := 1.0
	var crush := func(p: Vector3, _m: String) -> Vector3:
		if p.y <= floor_y:
			return p
		var d := Vector2(p.x, p.z).distance_to(c) / R
		var f := clampf(1.0 - d, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		var flat := floor_y + (p.y - floor_y) * 0.3 + _noise3(p) * 0.15
		return Vector3(p.x, lerpf(p.y, flat, f), p.z)
	var keep := func(ct: Vector3, m: String, _a, _b, _cc) -> bool:
		var d := Vector2(ct.x, ct.z).distance_to(c) / R
		if _glass(m):
			return d > 0.9 or rng.randf() > 0.7
		if ct.y > floor_y + 0.8 and d < 0.5 and rng.randf() < 0.25:
			return false
		return true
	var e := _copy(out, ext, "Exterior", crush, keep)
	var mats := _mats(ext, ["Siding", "Roof", "Brick", "Trim"])
	_rubble(out, c + Vector2(0.0, 2.6), 0.0, 3.0, 22, mats, 1.0)
	var px := Vector2(c.x - 1.5, _box.end.z + 4.5)
	_mark(out, _blob(2.2, 11, 0.2), mud, Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3(1.0, 1.0, 1.4)), Vector3(px.x, 0.035, px.y)), "Print_Heel")
	r["removed"] = e.get_meta("removed")
	r["crush_c"] = c
	r["crush_r"] = R
