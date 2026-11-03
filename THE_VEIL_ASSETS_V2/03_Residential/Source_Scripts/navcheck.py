"""First-person navigation tours for the Godot headless physics check.

From a house's metadata we build a route that starts outside the front steps,
enters through the front door and visits every room (through doors and up/down
stairs), then exits through the back door / garage when present. The Godot
script drives a 0.35 m-radius CharacterBody3D capsule along each leg with real
physics after opening every door, so a leg only passes if a player could
actually walk it.
"""
import math

import numpy as np


def door_points(d, off=0.55):
    """Points just either side of a doorway at standing height (+n side, -n side)."""
    c = np.array([d["center"][0], d["center"][2]])
    n = np.array(d["normal"])
    return c + n * off, c - n * off


def room_free_point(room, avoid=()):
    x0, z0, x1, z1 = room["rect"]
    return np.array([(x0 + x1) / 2, (z0 + z1) / 2])


def void_free_points(meta, margin=0.45):
    """Rooms that contain a stairwell void get a target point in their largest void-free part."""
    from house import rect_minus
    out = {}
    for r in meta["rooms"]:
        holes = []
        for s in meta["stairs"]:
            v = s["void"]
            x0, z0, x1, z1 = r["rect"]
            if abs(r["floor_y"] - s["y_to"]) < 0.3 and v[0] < x1 and v[2] > x0 and v[1] < z1 and v[3] > z0:
                holes.append((v[0] - margin, v[1] - margin, v[2] + margin, v[3] + margin))
        if not holes:
            continue
        x0, z0, x1, z1 = r["rect"]
        pieces = rect_minus((x0 + 0.4, z0 + 0.4, x1 - 0.4, z1 - 0.4), holes)
        pieces = [p for p in pieces if p[2] - p[0] > 0.3 and p[3] - p[1] > 0.3]
        if pieces:
            best = max(pieces, key=lambda p: (p[2] - p[0]) * (p[3] - p[1]))
            out[r["id"]] = np.array([(best[0] + best[2]) / 2, (best[1] + best[3]) / 2])
    return out


def tour(meta, entry, exits=(), free_points=None):
    """Return a list of legs [(from_xyz, to_xyz, label)]. entry = (x, z) outside the front steps."""
    rooms = {r["id"]: r for r in meta["rooms"]}
    free_points = dict(void_free_points(meta), **(free_points or {}))
    adj = {}
    for d in meta["doors"]:
        if d["kind"] == "garage":
            continue
        a, b = d["rooms"]
        adj.setdefault(a, []).append((b, ("door", d)))
        adj.setdefault(b, []).append((a, ("door", d)))
    for s in meta["stairs"]:
        lo = _room_at(meta, s["origin"][0], s["origin"][2], s["y_from"], inside_stair=s)
        top = _stair_top(s)
        hi = _room_at(meta, top[0], top[1], s["y_to"])
        if lo and hi:
            adj.setdefault(lo, []).append((hi, ("stair", s)))
            adj.setdefault(hi, []).append((lo, ("stair", s)))
    front = [d for d in meta["doors"] if d["rooms"][0] == "OUT" and d["kind"] == "door" and d.get("style") == "front"]
    if not front:
        front = [d for d in meta["doors"] if d["rooms"][0] == "OUT" and d["kind"] == "door"]
    legs = []

    def P(xz, y):
        return [float(xz[0]), float(y) + 1.0, float(xz[1])]

    def center(rid):
        r = rooms[rid]
        fp = free_points.get(rid)
        return P(fp if fp is not None else room_free_point(r), r["floor_y"])
    fd = front[0]
    pout, pin = door_points(fd)
    start = P(entry, 0.0)
    porch = [q for q in meta.get("porches", []) if q.get("steps") and q["steps"][0] == "z0" and
             q["rect"][0] - 0.1 <= fd["center"][0] <= q["rect"][2] + 0.1]
    if porch:     # straight up the porch steps, then across the deck to the door
        q = porch[0]
        top = (q["steps"][1], q["rect"][1] + 0.4)
        legs.append((start, P(top, rooms[fd["rooms"][1]]["floor_y"]), "approach: climb porch steps"))
        legs.append((P(top, rooms[fd["rooms"][1]]["floor_y"]), P(pout, rooms[fd["rooms"][1]]["floor_y"]), "approach: cross porch"))
    else:
        legs.append((start, P(pout, rooms[fd["rooms"][1]]["floor_y"]), "approach front door"))
    legs.append((P(pout, rooms[fd["rooms"][1]]["floor_y"]), P(pin, rooms[fd["rooms"][1]]["floor_y"]), "enter front door"))
    legs.append((P(pin, rooms[fd["rooms"][1]]["floor_y"]), center(fd["rooms"][1]), "into " + fd["rooms"][1]))
    seen = {fd["rooms"][1]}
    order = [fd["rooms"][1]]

    def go(cur):
        for nxt, (kind, obj) in sorted(adj.get(cur, []), key=lambda t: t[0]):
            if nxt in seen or nxt == "OUT":
                continue
            seen.add(nxt)
            order.append(nxt)
            path = traverse(cur, nxt, kind, obj)
            legs.extend(path)
            go(nxt)
            legs.extend(traverse(nxt, cur, kind, obj, back=True))

    def traverse(a, b, kind, obj, back=False):
        ra, rb = rooms[a], rooms[b]
        if kind == "door":
            p1, p2 = door_points(obj)
            pa, pb = (p1, p2) if obj["rooms"][0] == a else (p2, p1)
            sa = 1 if obj["rooms"][0] == a else -1            # side of the wall normal that room a is on
            legs_ = []
            st = obj.get("steps")
            n = np.array(obj["normal"])
            c = np.array([obj["center"][0], obj["center"][2]])
            if st and st["side"] == sa:                       # a is the low side: line up with the steps first
                ap = c + n * sa * (st["run"] + 0.7)
                legs_ += [(center(a), P(ap, ra["floor_y"]), f"{a} to foot of steps"), (P(ap, ra["floor_y"]), P(pa, ra["floor_y"]), "climb steps")]
            else:
                legs_.append((center(a), P(pa, ra["floor_y"]), f"{a} to door"))
            legs_.append((P(pa, ra["floor_y"]), P(pb, rb["floor_y"]), f"through {obj['name']}"))
            if st and st["side"] == -sa:                      # b is the low side: walk down the steps straight
                ap = c - n * sa * (st["run"] + 0.7)
                legs_ += [(P(pb, rb["floor_y"]), P(ap, rb["floor_y"]), "descend steps"), (P(ap, rb["floor_y"]), center(b), f"into {b}")]
            else:
                legs_.append((P(pb, rb["floor_y"]), center(b), f"into {b}"))
            return legs_
        s = obj
        bot = _stair_bottom(s)
        top = _stair_top(s, beyond=s.get("arrive", 0.5))
        out_top = _stair_top(s, beyond=s.get("arrive", 0.5) + 0.35)    # step clear of the stairwell before turning
        # step back off the first tread as far as the landing allows (but at least 0.4 m)
        sb = _stair_bottom(s, back=0.2)
        lr = _room_at(meta, sb[0], sb[1], s["y_from"])
        land = 0.8
        if lr:
            x0, z0, x1, z1 = rooms[lr]["rect"]
            fx0, fz0, fx1, fz1 = s["foot"]
            room_gap = {"+z": fz0 - z0, "-z": z1 - fz1, "+x": fx0 - x0, "-x": x1 - fx1}[s["dir"]]
            land = max(0.4, min(0.8, room_gap - 0.07 - RADIUS - 0.02))
        out_bot = _stair_bottom(s, back=land)
        if ra["floor_y"] < rb["floor_y"]:
            return [(center(a), P(out_bot, s["y_from"]), f"{a} to stair foot"), (P(out_bot, s["y_from"]), P(bot, s["y_from"]), "line up"),
                    (P(bot, s["y_from"]), P(top, s["y_to"]), "climb stair"), (P(top, s["y_to"]), P(out_top, s["y_to"]), "step off"),
                    (P(out_top, s["y_to"]), center(b), f"into {b}")]
        return [(center(a), P(out_top, s["y_to"]), f"{a} to stair head"), (P(out_top, s["y_to"]), P(top, s["y_to"]), "line up"),
                (P(top, s["y_to"]), P(bot, s["y_from"]), "descend stair"), (P(bot, s["y_from"]), P(out_bot, s["y_from"]), "step off"),
                (P(out_bot, s["y_from"]), center(b), f"into {b}")]
    go(fd["rooms"][1])
    unreached = [r for r in rooms if r not in seen and rooms[r]["type"] not in ("porch",)]
    return legs, order, unreached


def _stair_dir(s):
    return {"+z": (0, 1), "-z": (0, -1), "+x": (1, 0), "-x": (-1, 0)}[s["dir"]]


def _stair_bottom(s, back=0.4):
    x0, z0, x1, z1 = s["rect"]
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    if s["dir"] == "+z":
        return np.array([cx, z0 - back])
    if s["dir"] == "-z":
        return np.array([cx, z1 + back])
    if s["dir"] == "+x":
        return np.array([x0 - back, cz])
    return np.array([x1 + back, cz])


def _stair_top(s, beyond=0.4):
    x0, z0, x1, z1 = s["rect"]
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    run = s["run"]
    # use the actual built run (may exceed the nominal rect)
    if s["dir"] == "+z":
        return np.array([cx, z0 + run + beyond])
    if s["dir"] == "-z":
        return np.array([cx, z1 - run - beyond])
    if s["dir"] == "+x":
        return np.array([x0 + run + beyond, cz])
    return np.array([x1 - run - beyond, cz])


def _room_at(meta, x, z, y, inside_stair=None):
    best = None
    for r in meta["rooms"]:
        x0, z0, x1, z1 = r["rect"]
        if x0 - 0.05 <= x <= x1 + 0.05 and z0 - 0.05 <= z <= z1 + 0.05 and abs(r["floor_y"] - y) < 0.3:
            best = r["id"]
    return best


GD_TOUR = r'''extends SceneTree
# Headless first-person walkability check (no rendering). Generated by navcheck.py.
var jobs = __JOBS__
var frames = 0
var results = []

func _init():
	pass

func open_all(n):
	for c in n.get_children():
		open_all(c)
	if n.name.begins_with("INT_Door_") or n.name.begins_with("INT_SlidingDoor_") or n.name.begins_with("INT_GarageDoor_"):
		var ex = {}
		if n.has_meta("extras"):
			ex = n.get_meta("extras")
		if n.name.begins_with("INT_Door_"):
			n.rotate_y(deg_to_rad(float(ex.get("open_deg", 95.0))))
		elif n.name.begins_with("INT_GarageDoor_"):
			n.position.y += 2.1
		else:
			n.position += n.transform.basis.x * float(ex.get("distance", 0.8))

func count_meta(n, acc):
	if n.has_meta("extras"):
		acc[0] += 1
	for c in n.get_children():
		count_meta(c, acc)

func _physics_process(_d):
	frames += 1
	if frames == 1:
		for j in jobs:
			var ps = load(j["scene"])
			if ps == null:
				print("TOUR FAIL load " + j["scene"])
				continue
			var inst = ps.instantiate()
			get_root().add_child(inst)
			inst.position = Vector3(j["offset"][0], 0, j["offset"][2])
			if j.has("extra"):     # furnishing (static batch) placed in the same frame
				var fx = load(j["extra"])
				if fx != null:
					var fi = fx.instantiate()
					inst.add_child(fi)
			if j.has("ground"):   # lot ground around (not under) the house, like Pack 02 terrain
				var g = j["ground"]
				var o = Vector3(j["offset"][0], 0, j["offset"][2])
				for r in [[g[0] - 30, g[1] - 30, g[0], g[3] + 30], [g[2], g[1] - 30, g[2] + 30, g[3] + 30], [g[0], g[1] - 30, g[2], g[1]], [g[0], g[3], g[2], g[3] + 30]]:
					var sb = StaticBody3D.new()
					var c = CollisionShape3D.new()
					var bx = BoxShape3D.new()
					bx.size = Vector3(r[2] - r[0], 0.2, r[3] - r[1])
					c.shape = bx
					sb.add_child(c)
					sb.position = o + Vector3((r[0] + r[2]) / 2.0, -0.1, (r[1] + r[3]) / 2.0)
					get_root().add_child(sb)
			var acc = [0]
			count_meta(inst, acc)
			print("TOUR META %s nodes_with_extras=%d" % [j["name"], acc[0]])
			open_all(inst)
			j["inst"] = inst
		return false
	if frames < 4:
		return false
	for j in jobs:
		if not j.has("inst"):
			continue
		var ok = 0
		var bad = []
		var body = CharacterBody3D.new()
		var cs = CollisionShape3D.new()
		var cap = CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.75
		cs.shape = cap
		body.add_child(cs)
		body.floor_max_angle = deg_to_rad(45)   # Godot default
		body.floor_snap_length = 0.3
		j["inst"].add_child(body)
		var off = Vector3(j["offset"][0], 0, j["offset"][2])
		for leg in j["legs"]:
			var a = Vector3(leg[0][0], leg[0][1], leg[0][2]) + off
			var b = Vector3(leg[1][0], leg[1][1], leg[1][2]) + off
			body.global_position = a - Vector3(0, 0.05, 0)
			body.velocity = Vector3.ZERO
			var reached = false
			for i in 480:
				var to = b - body.global_position
				to.y = 0
				if to.length() < 0.3:
					reached = true
					break
				var v = to.normalized() * 2.2
				body.velocity = Vector3(v.x, body.velocity.y - 9.8 / 60.0, v.z)
				if body.is_on_floor():
					body.velocity.y = -0.5
				body.move_and_slide()
				if body.global_position.y < -6.0:
					break
			if reached and abs(body.global_position.y - (b.y - 0.1)) < 0.75:
				ok += 1
			else:
				bad.append("%s (stopped at %s, wanted %s)" % [leg[2], str((body.global_position - off).snapped(Vector3(0.01, 0.01, 0.01))), str((b - off).snapped(Vector3(0.01, 0.01, 0.01)))])
		body.queue_free()
		print("TOUR RESULT %s legs_ok=%d/%d" % [j["name"], ok, j["legs"].size()])
		for s in bad:
			print("TOUR BLOCKED %s: %s" % [j["name"], s])
	print("TOUR DONE")
	quit()
	return true
'''


# ----------------------------------------------------------------------------
# Grid path planning (what a player has to do: walk around stairs, voids, furniture)
# ----------------------------------------------------------------------------
import heapq as _hq

RADIUS = 0.37          # capsule radius + 2 cm


class FloorGrid:
    def __init__(self, meta, y, furniture=(), res=0.1):
        self.res = res
        rooms = [r for r in meta["rooms"] if abs(r["floor_y"] - y) < 0.06]
        allr = [r.get("walk", r["rect"]) for r in meta["rooms"]]
        x0 = min(r[0] for r in allr) - 1.0
        z0 = min(r[1] for r in allr) - 1.0
        x1 = max(r[2] for r in allr) + 1.0
        z1 = max(r[3] for r in allr) + 1.0
        self.o = (x0, z0)
        self.nx, self.nz = int((x1 - x0) / res) + 1, int((z1 - z0) / res) + 1
        X = x0 + (np.arange(self.nx) + 0.5) * res
        Z = z0 + (np.arange(self.nz) + 0.5) * res
        self.X, self.Z = np.meshgrid(X, Z)
        w = np.zeros((self.nz, self.nx), bool)
        for r in rooms:
            a, b, c, d = r.get("walk", r["rect"])
            ins = 0.07 + RADIUS if "walk" not in r else RADIUS     # partition half-thickness 6 cm (+1 cm)
            w |= (self.X > a + ins) & (self.X < c - ins) & (self.Z > b + ins) & (self.Z < d - ins)
        ids = {r["id"] for r in rooms}
        for dr in meta["doors"]:
            if dr["kind"] == "garage" or not (set(dr["rooms"]) & ids):
                continue
            n = np.array(dr["normal"])
            t = np.array([-n[1], n[0]])
            c = np.array([dr["center"][0], dr["center"][2]])
            rel_x, rel_z = self.X - c[0], self.Z - c[1]
            along = rel_x * t[0] + rel_z * t[1]
            across = rel_x * n[0] + rel_z * n[1]
            w |= (np.abs(along) < dr["w"] / 2 - RADIUS + 0.06) & (np.abs(across) < 0.75)
        for s in meta["stairs"]:
            if abs(s["y_from"] - y) < 0.06:
                a, b, c, d = s["foot"]
                w &= ~((self.X > a - RADIUS) & (self.X < c + RADIUS) & (self.Z > b - RADIUS) & (self.Z < d + RADIUS))
            if abs(s["y_to"] - y) < 0.06:
                a, b, c, d = s["void"]
                w &= ~((self.X > a - RADIUS - 0.05) & (self.X < c + RADIUS + 0.05) & (self.Z > b - RADIUS - 0.05) & (self.Z < d + RADIUS + 0.05))
        for (a, b, c, d) in furniture:
            w &= ~((self.X > a - RADIUS) & (self.X < c + RADIUS) & (self.Z > b - RADIUS) & (self.Z < d + RADIUS))
        self.w = w

    def cell(self, p):
        i = int((p[0] - self.o[0]) / self.res)
        j = int((p[1] - self.o[1]) / self.res)
        return min(max(j, 0), self.nz - 1), min(max(i, 0), self.nx - 1)

    def nearest_free(self, c, rmax=8):
        if self.w[c]:
            return c
        best = None
        for dj in range(-rmax, rmax + 1):
            for di in range(-rmax, rmax + 1):
                j, i = c[0] + dj, c[1] + di
                if 0 <= j < self.nz and 0 <= i < self.nx and self.w[j, i]:
                    d = dj * dj + di * di
                    if best is None or d < best[0]:
                        best = (d, (j, i))
        return best[1] if best else None

    def los(self, a, b):
        n = max(abs(a[0] - b[0]), abs(a[1] - b[1])) + 1
        for k in range(n + 1):
            t = k / n
            j, i = round(a[0] + (b[0] - a[0]) * t), round(a[1] + (b[1] - a[1]) * t)
            if not self.w[j, i]:
                return False
        return True

    def path(self, p, q):
        s, g = self.nearest_free(self.cell(p)), self.nearest_free(self.cell(q))
        if s is None or g is None:
            return None
        openq = [(0.0, s)]
        came = {s: None}
        cost = {s: 0.0}
        while openq:
            _, cur = _hq.heappop(openq)
            if cur == g:
                break
            for dj, di, c in ((1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (1, 1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (-1, -1, 1.414)):
                n = (cur[0] + dj, cur[1] + di)
                if not (0 <= n[0] < self.nz and 0 <= n[1] < self.nx) or not self.w[n]:
                    continue
                nc = cost[cur] + c
                if nc < cost.get(n, 1e18):
                    cost[n] = nc
                    came[n] = cur
                    h = math.hypot(n[0] - g[0], n[1] - g[1])
                    _hq.heappush(openq, (nc + h, n))
        if g not in came:
            return None
        cells = [g]
        while came[cells[-1]] is not None:
            cells.append(came[cells[-1]])
        cells.reverse()
        simp = [cells[0]]
        k = 0
        while k < len(cells) - 1:
            m = len(cells) - 1
            while m > k + 1 and not self.los(cells[k], cells[m]):
                m -= 1
            simp.append(cells[m])
            k = m
        pts = [(self.o[0] + (i + 0.5) * self.res, self.o[1] + (j + 0.5) * self.res) for (j, i) in simp]
        pts[0], pts[-1] = tuple(p), tuple(q)
        return pts


STRAIGHT = ("through", "climb", "descend", "line up", "step off", "approach", "enter front", "foot of steps", "climb steps",
            "descend steps")


def route(meta, legs, furniture_by_y=None):
    """Replace in-room legs with grid-planned paths. In-room targets that fall on furniture
    (room centres under a table or bed) are snapped to the nearest standable cell.
    Returns (legs, unroutable)."""
    grids = {}
    out, bad = [], []
    snap = {}

    def grid_for(y):
        key = round(y, 2)
        if key not in grids:
            grids[key] = FloorGrid(meta, y, (furniture_by_y or {}).get(key, []))
        return grids[key]

    fixed = []
    for (a, b, label) in legs:
        a = snap.get(tuple(round(v, 4) for v in a), a)
        if not any(k in label for k in STRAIGHT) and abs(a[1] - b[1]) < 0.06 and ("into" in label or "free" in label):
            g = grid_for(b[1] - 1.0)
            c = g.nearest_free(g.cell((b[0], b[2])), rmax=15)
            if c is not None:
                nb = [g.o[0] + (c[1] + 0.5) * g.res, b[1], g.o[1] + (c[0] + 0.5) * g.res]
                if abs(nb[0] - b[0]) + abs(nb[2] - b[2]) > 1e-6:
                    snap[tuple(round(v, 4) for v in b)] = nb
                    b = nb
        fixed.append((a, b, label))
    legs = fixed
    for (a, b, label) in legs:
        if any(k in label for k in STRAIGHT) or abs(a[1] - b[1]) > 0.06:
            out.append((a, b, label))
            continue
        pts = grid_for(a[1] - 1.0).path((a[0], a[2]), (b[0], b[2]))
        if pts is None:
            bad.append(label)
            out.append((a, b, label + " [no grid path]"))
            continue
        for k in range(len(pts) - 1):
            out.append(([pts[k][0], a[1], pts[k][1]], [pts[k + 1][0], a[1], pts[k + 1][1]], label + (f" #{k + 1}" if len(pts) > 2 else "")))
    return out, bad
