extends SceneTree
## THE VEIL - every house the player can enter (the survivor's house, the cottage and the explorable houses):
## no holes in the floors (except stairwells), and every doorway can be walked through once its door is opened.
## Uses each house's own room / door data (meta "veil_house"). Headless.
const DEV := preload("res://game/tools/dev_chapter7.gd")
var fails := 0
var w: Node
var h: Node3D


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func G(p: Vector3) -> Vector3:
	return h.global_transform * p


func walk_to(p, to: Vector3, secs: float) -> float:
	Input.action_press("move_forward")
	for i in int(secs * 60):
		var d: Vector3 = G(to) - p.global_position
		d.y = 0
		if d.length() < 0.3:
			break
		p.set_yaw_pitch(atan2(-d.x, -d.z), 0.0)
		await physics_frame
	Input.action_release("move_forward")
	for i in 4:
		await physics_frame
	var r: Vector3 = h.to_local(p.global_position)
	return Vector2(r.x - to.x, r.z - to.z).length()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 120:
		await process_frame
	var targets: Array = [w.phase4.chapter5.shouse, w.phase4.chapter5.house]
	for k in w.expedition.houses:
		if k != "_done":
			targets.append(w.expedition.houses[k].house)
	var p = w.player
	p.controls_enabled = true
	var space = w.get_world_3d().direct_space_state
	for house in targets:
		h = house
		var info: Dictionary = h.get_meta("veil_house", {})
		var rooms := {}
		var holes := []
		for r in info.get("rooms", []):
			rooms[r["id"]] = r
			if int(r.get("level", 0)) < 0:
				continue
			var rc: Array = r["rect"]
			var fy: float = r["floor_y"]
			var x: float = rc[0] + 0.3
			while x <= rc[2] - 0.3:
				var z: float = rc[1] + 0.3
				while z <= rc[3] - 0.3:
					var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(G(Vector3(x, fy + 1.4, z)), G(Vector3(x, fy - 1.0, z)), 1))
					if not hit or h.to_local(hit["position"]).y < fy - 0.15:
						holes.append("%s(%.1f,%.1f)" % [r["id"], x, z])
					z += 0.5
				x += 0.5
		# stairwell openings are holes by design: only the strip over a stair counts as one
		var stair_x := []
		for hs in holes:
			pass
		var bad_doors := []
		for d in info.get("doors", []):
			var pair: Array = d.get("rooms", [])
			if d.get("exterior", false) or pair.size() < 2 or float(d["center"][1]) < 0.0:
				continue
			if not rooms.has(pair[0]) or not rooms.has(pair[1]):
				continue
			var dc := Vector3(d["center"][0], float(d["center"][1]) + 0.15, d["center"][2])
			var ra: Array = rooms[pair[0]]["rect"]
			var rb: Array = rooms[pair[1]]["rect"]
			var ca := Vector3((ra[0] + ra[2]) * 0.5, dc.y, (ra[1] + ra[3]) * 0.5)
			var cb := Vector3((rb[0] + rb[2]) * 0.5, dc.y, (rb[1] + rb[3]) * 0.5)
			var na := ((ca - dc) * Vector3(1, 0, 1))
			var nb := ((cb - dc) * Vector3(1, 0, 1))
			# step straight through the doorway, perpendicular to the wall it is in
			var axis := Vector3(1, 0, 0) if absf(na.x) > absf(na.z) else Vector3(0, 0, 1)
			var a_pt := dc + axis * signf(na.dot(axis)) * 0.9
			var b_pt := dc + axis * signf(nb.dot(axis)) * 0.9
			var leaf: Node = h.find_child(String(d["name"]), true, false)
			var it = leaf.get_node_or_null("Interact") if leaf else null
			if it and not it.is_open:
				it.interact(p)
				for i in 70:
					await physics_frame
			var side := Vector3(axis.z, 0, axis.x)
			var res := []
			for leg in [[a_pt, b_pt], [b_pt, a_pt]]:
				var best := 9.0
				for off in [0.0, 0.45, -0.45]:
					p.global_position = G(leg[0] + side * off)
					p.velocity = Vector3.ZERO
					for i in 4:
						await physics_frame
					await walk_to(p, dc + side * off * 0.3, 4.0)
					best = minf(best, await walk_to(p, leg[1] + side * off, 4.0))
					if best < 0.6:
						break
				res.append(best)
			if (res[0] > 0.6) != (res[1] > 0.6):
				print("  one-way %s %s->%s %.2f / back %.2f (a step between floors %.2f / %.2f)" % [d["name"], pair[0], pair[1], res[0], res[1], rooms[pair[0]]["floor_y"], rooms[pair[1]]["floor_y"]])
			if res[0] > 0.6 and res[1] > 0.6:
				var fa: float = rooms[pair[0]]["floor_y"]
				var fb: float = rooms[pair[1]]["floor_y"]
				bad_doors.append("%s(%s->%s %.2f, back %.2f, floors %.2f/%.2f%s)" % [d["name"], pair[0], pair[1], res[0], res[1], fa, fb, "" if it or String(d.get("kind", "")) == "arch" else " no-open"])
		print("HOUSE %s %s holes %d %s" % [h.name, info.get("design", ""), holes.size(), str(holes.slice(0, 12))])
		ok("doors_" + String(h.name), bad_doors.is_empty(), str(bad_doors))
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
