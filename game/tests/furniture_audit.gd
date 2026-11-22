extends SceneTree
## Review notes #47 / #48 ("how can u open drawers with the bed blocking the drawer door", "the fridge opens into the cooker"): an AUDIT of every explorable house's furniture layout in
## game/data/scavenge_houses.json. For each piece with a door or drawer it finds the zone in front of it that the door swings / the drawer slides through, and reports every piece or wall
## standing in it. With `-- fix` it then moves pieces (the one that is blocked sideways along its wall first, then whatever blocks it) to the nearest spot where nothing overlaps and every
## zone is clear, and writes the new positions back into the JSON.
##   godot --headless --path . --script res://game/tests/furniture_audit.gd            # report only
##   godot --headless --path . --script res://game/tests/furniture_audit.gd -- fix      # report, fix, write
const FURN := "res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/%s.glb"
const JSON_PATH := "res://game/data/scavenge_houses.json"
const DRAWER_MODELS := ["RES_Dresser", "RES_Dresser_Mirror", "RES_Desk", "RES_SideTable_Drawer", "RES_Nightstand", "RES_Wardrobe"]
const FLAT := ["Rug", "Curtain", "Picture", "Mirror_Wall", "Clock", "Poster"]
const NO_ZONE := ["RES_Toilet", "RES_MedicineCabinet"]          # (a lid / a wall cabinet: nothing swings across the floor)
const STEP := 0.1
var specs: Dictionary
var _aabb_cache := {}
var _front_cache := {}
var fix := false


func _initialize() -> void:
	fix = OS.get_cmdline_user_args().has("fix")
	_run.call_deferred()


func _run() -> void:
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	var raw := f.get_as_text()
	var crlf := raw.contains("\r\n")
	specs = JSON.parse_string(raw)
	f.close()
	var houses_scene := load("res://game/world/Greyhaven_Houses.tscn") as PackedScene
	var hs: Node = houses_scene.instantiate() if houses_scene else null
	if hs == null:
		print("AUDIT no houses scene")
		quit()
		return
	root.add_child(hs)
	for m in ["RES_Nightstand", "RES_Fridge_Retro", "RES_Dresser", "RES_Wardrobe", "RES_SideTable_Drawer", "RES_Counter_Sink", "RES_Stove_Harvest"]:
		var bx := _model_box(m)
		print("AUDITDBG %s box %s front %s" % [m, bx, _front_cache.get(m)])
	var total_bad := 0
	var total_fixed := 0
	var changed := 0
	for hid in specs["houses"]:
		var spec: Dictionary = specs["houses"][hid]
		var hn: Node = hs.find_child(hid, true, false)
		var rooms := {}
		if hn:
			for r in (hn.get_meta("veil_house", {}) as Dictionary).get("rooms", []):
				var rc: Array = r["rect"]
				rooms[String(r["id"])] = Rect2(float(rc[0]), float(rc[1]), float(rc[2]) - float(rc[0]), float(rc[3]) - float(rc[1]))
		var pieces: Array = spec["pieces"]
		if hid == "HOUSE_04":
			var pp: Dictionary = pieces[11]
			print("AUDITDBG2 piece %s zone %s foot %s room %s" % [pp, _zone(pp), _footprint(pp), rooms.get(String(pp.get("room", "")))])
		var bad := _conflicts(pieces, rooms)
		total_bad += bad.size()
		if not bad.is_empty():
			print("AUDIT %s: %d blocked" % [hid, bad.size()])
			for b in bad:
				print("   %s <- %s" % [b[0], b[1]])
		if fix and not bad.is_empty():
			var moved := _fix(pieces, rooms)
			var after := _conflicts(pieces, rooms)
			total_fixed += bad.size() - after.size()
			changed += moved
			print("   fixed %d, moved %d pieces, %d still blocked" % [bad.size() - after.size(), moved, after.size()])
			for b in after:
				print("   STILL %s <- %s" % [b[0], b[1]])
	print("AUDIT TOTAL blocked %d, fixed %d, pieces moved %d" % [total_bad, total_fixed, changed])
	if fix:
		var out := JSON.stringify(specs, " ", false)
		if crlf:
			out = out.replace("\n", "\r\n")
		var w := FileAccess.open(JSON_PATH, FileAccess.WRITE)
		w.store_string(out)
		w.close()
		print("AUDIT written")
	quit()


# ------------------------------------------------------------------ geometry
func _aabb_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	var all: Array = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		all.append(node)
	for vi in all:
		var a: AABB = (inv * (vi as VisualInstance3D).global_transform) * (vi as VisualInstance3D).get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _model_box(model: String) -> AABB:
	if _aabb_cache.has(model):
		return _aabb_cache[model]
	var ps := load(FURN % model) as PackedScene
	var box := AABB()
	if ps:
		var n := ps.instantiate() as Node3D
		root.add_child(n)
		box = _aabb_of(n)
		# the door / drawer parts: where the front is
		var moving: Dictionary = specs["moving_parts"].get(model, {})
		var dirs := Vector2.ZERO
		var depth := 0.0
		for part in moving:
			var pn := n.find_child(part, true, false) as Node3D
			if pn == null:
				continue
			var e: Dictionary = moving[part]
			var pb := _aabb_of(pn)
			var c: Vector3 = (n.global_transform.affine_inverse() * pn.global_transform) * pb.get_center() - box.get_center()      # (in the piece's own frame)
			dirs += Vector2(c.x, c.z)
			if String(e.get("veil_interact", "")) == "hinge":
				depth = maxf(depth, maxf(pb.size.x, pb.size.z))                # the leaf swings out through its own width
			else:
				depth = maxf(depth, float(e.get("distance", 0.3)) + 0.2)
		if moving.is_empty() and model in DRAWER_MODELS:
			dirs = Vector2(0, 1)
			depth = 0.55
		var front := Vector2(0, 1)
		if dirs.length() > 0.001:
			front = Vector2(1, 0) * signf(dirs.x) if absf(dirs.x) > absf(dirs.y) else Vector2(0, 1) * signf(dirs.y)
		_front_cache[model] = {"front": front, "depth": (depth if depth > 0.0 else 0.0) if not (model in NO_ZONE) else 0.0}
		n.queue_free()
	_aabb_cache[model] = box
	return box


func _xf(p: Dictionary) -> Transform2D:
	var pos: Array = p["pos"]
	var yaw := float(p.get("yaw", 0.0))
	# house-local plan: x, z; a yaw about +Y turns (x, z) by -yaw in the (x, z) plane
	return Transform2D(-yaw, Vector2(pos[0], pos[2]))


func _footprint(p: Dictionary) -> PackedVector2Array:
	var b := _model_box(String(p["model"]))
	var xf := _xf(p)
	var pts := PackedVector2Array()
	for c in [Vector2(b.position.x, b.position.z), Vector2(b.end.x, b.position.z), Vector2(b.end.x, b.end.z), Vector2(b.position.x, b.end.z)]:
		pts.append(xf * c)
	return pts


func _zone(p: Dictionary) -> PackedVector2Array:
	var model := String(p["model"])
	var b := _model_box(model)
	var fc: Dictionary = _front_cache.get(model, {})
	var depth := float(fc.get("depth", 0.0))
	if depth <= 0.0:
		return PackedVector2Array()
	var front: Vector2 = fc["front"]
	var xf := _xf(p)
	var pts := PackedVector2Array()
	if absf(front.x) > 0.5:                       # the front is along local x
		var x0 := b.end.x if front.x > 0 else b.position.x - depth
		var x1 := b.end.x + depth if front.x > 0 else b.position.x
		for c in [Vector2(x0, b.position.z), Vector2(x1, b.position.z), Vector2(x1, b.end.z), Vector2(x0, b.end.z)]:
			pts.append(xf * c)
	else:
		var z0 := b.end.z if front.y > 0 else b.position.z - depth
		var z1 := b.end.z + depth if front.y > 0 else b.position.z
		for c in [Vector2(b.position.x, z0), Vector2(b.end.x, z0), Vector2(b.end.x, z1), Vector2(b.position.x, z1)]:
			pts.append(xf * c)
	return pts


func _flat(p: Dictionary) -> bool:
	var m := String(p["model"])
	for k in FLAT:
		if m.contains(k):
			return true
	return _model_box(m).end.y < 0.25


func _shrink(poly: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for v in poly:
		c += v
	c /= float(poly.size())
	var out := PackedVector2Array()
	for v in poly:
		out.append(c + (v - c) * (1.0 - k) if k < 1.0 else c)
	return out


func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	var r := Geometry2D.intersect_polygons(_shrink(a, 0.04), _shrink(b, 0.04))
	if r.is_empty():
		return false
	for poly in r:
		var area := 0.0
		for i in poly.size():
			var q: Vector2 = poly[i]
			var w: Vector2 = poly[(i + 1) % poly.size()]
			area += q.x * w.y - w.x * q.y
		if absf(area) * 0.5 > 0.012:
			return true
	return false


func _inside_room(poly: PackedVector2Array, room: Rect2) -> bool:
	if room.size == Vector2.ZERO:
		return true
	var r := room.grow(0.06)
	for v in poly:
		if not r.has_point(v):
			return false
	return true


## [[piece label, what blocks it], ...]
func _conflicts(pieces: Array, rooms: Dictionary) -> Array:
	var out := []
	var foots: Array = pieces.map(func(p): return _footprint(p))
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var z := _zone(p)
		if z.is_empty():
			continue
		var label := "%s#%d" % [p["model"], i]
		var room: Rect2 = rooms.get(String(p.get("room", "")), Rect2())
		if not _inside_room(z, room) and room.size != Vector2.ZERO:
			var hit_wall := false
			for v in z:
				if not room.grow(0.06).has_point(v):
					hit_wall = true
			if hit_wall:
				out.append([label, "a wall (the zone runs outside its room)"])
		for j in pieces.size():
			if j == i or _flat(pieces[j]):
				continue
			if _overlap(z, foots[j]):
				out.append([label, "%s#%d" % [pieces[j]["model"], j]])
	return out


func _bad_for(pieces: Array, rooms: Dictionary, idx: int) -> bool:
	# does the layout have a problem involving piece idx (its own zone, or its footprint in anyone's zone, or overlapping, or leaving its room)?
	var p: Dictionary = pieces[idx]
	var fp := _footprint(p)
	var room: Rect2 = rooms.get(String(p.get("room", "")), Rect2())
	if not _inside_room(fp, room):
		return true
	var z := _zone(p)
	for j in pieces.size():
		if j == idx:
			continue
		var q: Dictionary = pieces[j]
		var fq := _footprint(q)
		if not _flat(p) and not _flat(q) and _overlap(fp, fq):
			return true
		if not _flat(p) and _overlap(_zone(q), fp):
			return true
		if not _flat(q) and _overlap(z, fq):
			return true
	if not z.is_empty() and room.size != Vector2.ZERO:
		for v in z:
			if not room.grow(0.06).has_point(v):
				return true
	return false


func _try_move(pieces: Array, rooms: Dictionary, idx: int, max_d: float) -> bool:
	var p: Dictionary = pieces[idx]
	var pos: Array = p["pos"]
	var home := Vector2(pos[0], pos[2])
	var best := Vector2.INF
	var best_d := INF
	var n := int(max_d / STEP)
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var o := Vector2(ix, iz) * STEP
			var d := o.length()
			if d > max_d or d >= best_d:
				continue
			pos[0] = home.x + o.x
			pos[2] = home.y + o.y
			if not _bad_for(pieces, rooms, idx):
				best = o
				best_d = d
	pos[0] = home.x
	pos[2] = home.y
	if best_d < INF:
		pos[0] = snappedf(home.x + best.x, 0.001)
		pos[2] = snappedf(home.y + best.y, 0.001)
		return true
	return false


func _fix(pieces: Array, rooms: Dictionary) -> int:
	var moved := {}
	for round in 6:
		var bad := _conflicts(pieces, rooms)
		if bad.is_empty():
			break
		for b in bad:
			# who is blocked, who blocks: try the blocked piece first (it slides along its wall), then the blocker
			var cands: Array = []
			for label in [b[0], b[1]]:
				var s := String(label)
				if s.contains("#"):
					cands.append(int(s.get_slice("#", 1).split(" ")[0]))
			for idx in cands:
				if idx < 0 or idx >= pieces.size():
					continue
				if _try_move(pieces, rooms, idx, 1.6):
					moved[idx] = true
					break
	return moved.size()
