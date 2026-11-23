extends Node
## Scripted movement in WORLD space for directed story moments (displayed Chapter 11, chapter10.gd): routes over real floors and round real obstacles, swept every step with the actor's own radius.
##  - the floor is PROBED under every route cell (a ray from just above the previous floor), so stairs, porch steps and raised house floors are walkable and a 0.6 m drop is not;
##  - clearance is measured with spheres at body heights above THAT floor against the static world (layer 1: walls, props, door leaves and gate leaves as they are right now);
##  - `route()` returns [] when there is no way: nothing falls back to a straight line; `move()` waits, re-routes and finally reports (`failures`) instead of walking through things.
## Nothing here writes the camera or the player's controls: the scene that owns the moment does.

var world: Node
var player: Node3D
var failures: Array = []
var enabled := true
const CELL := 0.25
const SOLID_MASK := 1 | 2 | 4                            ## the layers a survivor body collides with (VeilSurvivorBody.SOLIDS without the other characters)
const STEP_UP := 0.45                                   ## the most a route may climb or drop between two cells (stairs and kerbs yes, walls and ledges no)


func setup(w: Node, p: Node3D) -> void:
	world = w
	player = p


func _space() -> PhysicsDirectSpaceState3D:
	return world.get_world_3d().direct_space_state


## Floor height under (x, z) within STEP_UP of `ref_y`; INF when there is none (a drop, a wall top, nothing).
func floor_at(x: float, z: float, ref_y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, ref_y + STEP_UP + 0.05, z), Vector3(x, ref_y - STEP_UP - 0.05, z), 1)
	q.exclude = [player.get_rid()]
	var h: Dictionary = _space().intersect_ray(q)
	return (h["position"] as Vector3).y if not h.is_empty() else INF


func _clear_at(p: Vector3, radius: float, heights: Array) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	q.shape = sph
	q.collision_mask = SOLID_MASK
	q.exclude = [player.get_rid()]
	for h in heights:
		q.transform = Transform3D(Basis(), p + Vector3(0, h, 0))
		if not _space().intersect_shape(q, 1).is_empty():
			return false
	return true


## Is this spot (x, z at the floor found under it) free for a body of this size?
func free_at(p: Vector3, radius: float, heights: Array) -> bool:
	var fy := floor_at(p.x, p.z, p.y)
	if fy == INF:
		return false
	return _clear_at(Vector3(p.x, fy, p.z), radius, heights)


func step_clear(from: Vector3, to: Vector3, radius: float, heights: Array, lift := -INF) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	q.shape = sph
	q.collision_mask = SOLID_MASK
	q.exclude = [player.get_rid()]
	var yb := maxf(maxf(from.y, to.y), lift)                          # a step or a kerb is not a wall: the sweep runs level at the higher floor, so only things above the knee stop a body
	for h in heights:
		q.transform = Transform3D(Basis(), Vector3(from.x, yb + h, from.z))
		q.motion = Vector3(to.x - from.x, 0.0, to.z - from.z)
		var r := _space().cast_motion(q)
		if r.size() > 0 and r[0] < 1.0:
			return false
	return true


## A route (world points on the floor) from `from` to `to`; [] when none. Grid search over probed floors, string-pulled with swept checks.
func route(from: Vector3, to: Vector3, radius: float, heights: Array, margin := 5.0) -> Array:
	var lo := Vector2(minf(from.x, to.x) - margin, minf(from.z, to.z) - margin)
	var w := int((maxf(from.x, to.x) + margin - lo.x) / CELL) + 1
	var hg := int((maxf(from.z, to.z) + margin - lo.y) / CELL) + 1
	var ys := {}
	var cell_pos := func(c: Vector2i) -> Vector2: return Vector2(lo.x + c.x * CELL, lo.y + c.y * CELL)
	var cell_of := func(p: Vector3) -> Vector2i: return Vector2i(roundi((p.x - lo.x) / CELL), roundi((p.z - lo.y) / CELL))
	var s: Vector2i = cell_of.call(from)
	var g: Vector2i = cell_of.call(to)
	ys[s] = from.y
	var cache := {}
	# a cell is open when a floor lies within STEP_UP of the cell we came from and the body fits on it
	var open_cell := func(c: Vector2i, ref_y: float) -> float:
		if cache.has(c):
			return cache[c]
		var pz: Vector2 = cell_pos.call(c)
		var fy := floor_at(pz.x, pz.y, ref_y)
		var res := INF
		if fy != INF and _clear_at(Vector3(pz.x, fy, pz.y), radius, heights):
			res = fy
		cache[c] = res
		return res
	var gy: float = open_cell.call(g, to.y)
	if gy == INF:
		return []
	ys[g] = gy
	var bad := {}                                       # cell-to-cell edges a real sweep refused (a thin rail between two clear cells): banned, the search runs again
	var pts: Array = []
	var attempt := 0
	while attempt < 14:
		attempt += 1
		var open := {s: 0.0}
		var cost := {s: 0.0}
		var came := {}
		var found := false
		var it := 0
		while not open.is_empty() and it < 120000:
			it += 1
			var cur: Vector2i = s
			var best := INF
			for k in open:
				if open[k] < best:
					best = open[k]
					cur = k
			open.erase(cur)
			if cur == g:
				found = true
				break
			var cy: float = ys.get(cur, from.y)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var nb: Vector2i = cur + d
				if nb.x < 0 or nb.y < 0 or nb.x >= w or nb.y >= hg:
					continue
				var ny: float = open_cell.call(nb, cy) if nb != g else gy
				if ny == INF or absf(ny - cy) > STEP_UP or bad.has("%d,%d>%d,%d" % [cur.x, cur.y, nb.x, nb.y]):
					continue
				if d.x != 0 and d.y != 0:
					var a_ok: float = open_cell.call(Vector2i(cur.x + d.x, cur.y), cy)
					var b_ok: float = open_cell.call(Vector2i(cur.x, cur.y + d.y), cy)
					if a_ok == INF or b_ok == INF:
						continue
				var nc: float = cost[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
				if not cost.has(nb) or nc < cost[nb]:
					cost[nb] = nc
					came[nb] = cur
					ys[nb] = ny
					open[nb] = nc + Vector2(nb - g).length() * 1.25
		if not found:
			return []
		var cells: Array = [g]
		while cells[0] != s and came.has(cells[0]):
			cells.push_front(came[cells[0]])
		pts = []
		for c in cells:
			var pz: Vector2 = cell_pos.call(c)
			pts.append(Vector3(pz.x, ys.get(c, from.y), pz.y))
		pts[0] = from
		pts[pts.size() - 1] = to

		var clean := true
		for ei in range(cells.size() - 1):
			if not step_clear(pts[ei], pts[ei + 1], radius, heights):
				bad["%d,%d>%d,%d" % [cells[ei].x, cells[ei].y, cells[ei + 1].x, cells[ei + 1].y]] = true
				bad["%d,%d>%d,%d" % [cells[ei + 1].x, cells[ei + 1].y, cells[ei].x, cells[ei].y]] = true
				clean = false
		if clean:
			break
	# string pulling, but only over level ground: a stretch that climbs keeps its cells (the steps are where they are)
	var out: Array = []
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1:
			var level := true
			for m in range(i, j + 1):
				if absf((pts[m] as Vector3).y - (pts[i] as Vector3).y) > 0.06:
					level = false
					break
			if level and step_clear(pts[i], pts[j], radius, heights):
				break
			j -= 1
		out.append(pts[j])
		i = j
	return out


func actor(node: Node3D, anim, kind := "person") -> Dictionary:
	return {"node": node, "anim": anim, "kind": kind, "radius": 0.28, "heights": [0.5, 1.3], "done": true, "ok": true}


func pos(a: Dictionary) -> Vector3:
	return (a["node"] as Node3D).global_position


func set_pos(a: Dictionary, p: Vector3) -> void:
	var n: Node3D = a["node"]
	n.global_position = p
	if a["kind"] == "player":
		player.velocity = Vector3.ZERO


func near(a: Dictionary, p: Vector3, d := 0.35) -> bool:
	var c := pos(a)
	return Vector2(c.x - p.x, c.z - p.z).length() < d


func note(msg: String) -> void:
	failures.append(msg)
	push_warning("[scene_mover] " + msg)


## Walk the actor to `dest` (through the optional via points) at `speed`; false = it could not (reported).
func move(a: Dictionary, dest: Vector3, speed: float, via: Array = []) -> bool:
	var legs: Array = via.duplicate()
	legs.append(dest)
	# the player's own physics rest while a scene walks them along a swept route (otherwise the body fights the scripted position)
	var phys_was: bool = player != null and a["kind"] == "player" and player.is_physics_processing()
	if a["kind"] == "player":
		player.set_physics_process(false)
	var ok := true
	for leg in legs:
		if not await _leg(a, leg, speed):
			ok = false
			break
	if a["kind"] == "player" and phys_was and is_instance_valid(player):
		player.set_physics_process(true)
	return ok


func _leg(a: Dictionary, to: Vector3, speed: float) -> bool:
	var n: Node3D = a["node"]
	var anim = a["anim"]
	var pts: Array = route(pos(a), to, a["radius"], a["heights"])
	var waited := 0.0
	while pts.is_empty() and waited < 1.2:                 # a door leaf or a shelf may still be moving out of the way
		await get_tree().process_frame
		waited += get_process_delta_time()
		pts = route(pos(a), to, a["radius"], a["heights"])
	if pts.is_empty():
		note("no route for %s to %s" % [n.name, str(to)])
		return false
	if anim != null:
		return await _animated_leg(a, pts, to, speed)
	var idx := 0
	var blocked := 0.0
	var stalled := 0.0
	var expected := Vector3.INF
	var rerouted := 0
	while idx < pts.size():
		if not enabled:
			return false
		var cur := pos(a)
		var tgt: Vector3 = pts[idx]
		var d := tgt - cur
		var dflat := Vector3(d.x, 0.0, d.z)
		if dflat.length() < 0.08:
			idx += 1
			continue
		var dt := get_process_delta_time()
		# a body that the physics keeps pushing back (a collider the sphere test cannot see) has not progressed: that counts as stalled, and is reported
		if expected != Vector3.INF and cur.distance_to(expected) > 0.03:
			stalled += dt
			if stalled > 1.0:
				note("stalled: %s towards %s (pushed back at %s)" % [n.name, str(to), str(cur)])
				return false
		else:
			stalled = 0.0
		var step := dflat.normalized() * minf(speed * dt, dflat.length())
		var nxt := cur + step
		var fy := floor_at(nxt.x, nxt.z, cur.y)
		if fy != INF:
			nxt.y = fy
		if step_clear(cur, nxt, a["radius"], a["heights"], tgt.y):          # a climbing leg is swept level at its goal floor (the step ahead is not a wall)
			blocked = 0.0
			set_pos(a, nxt)
			expected = nxt
			if a["kind"] == "player":
				var yaw := atan2(-dflat.x, -dflat.z)
				player.set_yaw_pitch(lerp_angle(player.rotation.y, yaw, minf(1.0, 4.5 * dt)), lerpf(player.head.rotation.x, 0.0, 0.1))
			elif anim != null:
				anim.walk_speed = speed
				anim.walk_to([nxt + dflat.normalized() * 1.6], speed)
		else:
			blocked += dt
			if blocked > 1.5 and rerouted >= 3:
				note("blocked for good: %s towards %s (stuck at %s)" % [n.name, str(to), str(cur)])
				return false
			if blocked > 0.5 and rerouted < 3:                  # something moved into the way (a door leaf, a gate): a fresh route from here
				rerouted += 1
				blocked = 0.0
				pts = route(pos(a), to, a["radius"], a["heights"])
				idx = 0
				if pts.is_empty():
					note("blocked for good: %s towards %s" % [n.name, str(to)])
					return false
		await get_tree().process_frame
	if anim != null:
		anim.walk_to([])
	return true


## A survivor walks its (already swept) route with its own animator (it follows the floor and steps and animates the legs); this watches the walk and reports a stall (physics or a door in the way)
## instead of pretending, re-routing once from where it stands.
func _animated_leg(a: Dictionary, pts: Array, to: Vector3, speed: float) -> bool:
	var n: Node3D = a["node"]
	var anim = a["anim"]
	var frame := n.get_parent_node_3d()
	anim.free_walk = true
	anim.turn_to_face = true
	var rerouted := 0
	while true:
		var local_pts: Array = pts.map(func(p: Vector3) -> Vector3: return frame.to_local(p))
		anim.walk_to(local_pts, speed)
		var stall := 0.0
		var last := pos(a)
		await get_tree().process_frame
		while anim.is_walking():
			if not enabled:
				anim.walk_to([])
				return false
			await get_tree().process_frame
			var dt := get_process_delta_time()
			var cur := pos(a)
			if cur.distance_to(last) < 0.015:
				stall += dt
			else:
				stall = 0.0
				last = cur
			if stall > 1.5:
				anim.walk_to([])
				break
		if not anim.is_walking() and Vector2(pos(a).x - to.x, pos(a).z - to.z).length() < 0.6:
			return true
		if rerouted >= 2:
			note("stalled: %s towards %s (at %s)" % [n.name, str(to), str(pos(a))])
			return false
		rerouted += 1
		pts = route(pos(a), to, a["radius"], a["heights"])
		if pts.is_empty():
			note("no way on for %s towards %s from %s" % [n.name, str(to), str(pos(a))])
			return false
	return false


func go(a: Dictionary, dest: Vector3, speed: float, via: Array = []) -> void:
	a["done"] = false
	a["ok"] = false
	a["ok"] = await move(a, dest, speed, via)
	a["done"] = true


func all_done(list: Array) -> bool:
	for a in list:
		if not a["done"]:
			return false
	return true
