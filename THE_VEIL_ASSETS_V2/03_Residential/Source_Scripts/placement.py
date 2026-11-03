"""Fit Pack 03 houses into the Pack 02 Greyhaven building zones.

Reads (never writes) 02_Town/Town_Layout/greyhaven_layout.json and the Pack 02
model manifest. The street network, zones and Pack 02 placements are not changed.

Zone frame (= house frame)
  origin  zone front-edge centre, lot level (world y = 0.15)
  +z      into the lot, away from the street (the zone `front` vector is -z)
  +x      across the frontage:  X_world = (cos yaw, 0, -sin yaw)
  yaw     atan2(-front.x, -front.z)

For every zone the solver picks mirror / lateral shift so that
  * exterior walls stay inside the zone (wall faces may sit <= WALL_TOL past the
    zone line, i.e. the zone line is treated as the wall centreline),
  * a garage door lines up with the Pack 02 driveway (|dx| <= 0.35 m), or for
    garage-less houses nothing low (walls, porch, steps, chimney) sits in the
    driveway corridor (|x - access.x| < 1.6 m, z < 2.4 m),
  * nothing low touches a Pack 02 placement (trees, bushes, mailbox, meter, fences),
  * the shift is as small as possible (houses stay centred in their lots).
A concrete walkway then links the front steps to the driveway (A* on a 0.1 m grid
around Pack 02 props); garages set back from the driveway end get an apron slab.
"""
import heapq
import json
import math
import os

import plans
import house as house_mod

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
LAYOUT = os.path.join(V2, "02_Town", "Town_Layout", "greyhaven_layout.json")
P02_MANIFEST = os.path.join(V2, "02_Town", "Documentation", "MODEL_MANIFEST.json")
LOT_Y = 0.15
WALL_TOL = 0.12
DRIVE_HALF = 1.5

# zone -> (plan key, colorway or None)       distinct neighbours, no two identical facades side by side
ASSIGN = {
    "HOUSE_01": ("Ranch", None), "HOUSE_02": ("TwoStorey", None), "HOUSE_03": ("Ranch", "B"),
    "HOUSE_04": ("Cottage", None), "HOUSE_05": ("TwoStorey", "B"), "HOUSE_06": ("Bungalow", None),
    "HOUSE_07": ("Bungalow", "B"), "HOUSE_08": ("Cottage", "B"), "HOUSE_09": ("Ranch", "C"),
    "HOUSE_10": ("MillWorker", None), "HOUSE_11": ("Cottage", "B"), "HOUSE_12": ("TwoStorey", None),
    "HOUSE_13": ("Ranch", None), "PLAYER_HOME": ("PlayerHome", None), "HOUSE_15": ("Cottage", None),
    "HOUSE_16": ("MillWorker", "B"), "HOUSE_17": ("TwoStorey", "B"), "HOUSE_18": ("Ranch", "B"),
    "HOUSE_19": ("SplitLevel", None), "HOUSE_20": ("Abandoned", None), "HOUSE_21": ("SplitLevel", "B"),
    "HOUSE_22": ("Ranch", "C"), "HOUSE_23": ("Bungalow", "B"),
    "FARMHOUSE": ("Farmhouse", None), "MILL_HOUSE": ("MillWorker", None),
}


def variant_name(key, cw, mirror):
    n = plans.PLANS[key]["name"]
    if cw:
        n += "_" + cw
    if mirror:
        n += "_Mirror"
    return n


def plan_for(key, mirror):
    p = plans.PLANS[key]
    return plans.mirror_plan(p) if mirror else p


# ------------------------------------------------------------------ geometry
def _step_rect(po):
    st = po.get("steps")
    if not st:
        return None
    x0, z0, x1, z1 = po["rect"]
    n = po.get("risers") or max(1, int(round(po["deck_y"] / 0.15)))
    side, c, w = st
    run = n * 0.3
    if side == "z0":
        return (c - w / 2, z0 - run, c + w / 2, z0)
    if side == "x1":
        return (x1, c - w / 2, x1 + run, c + w / 2)
    return (x0 - run, c - w / 2, x0, c + w / 2)


def _step_foot(po):
    """Point 0.6 m beyond the bottom step + the outward approach direction."""
    st = po["steps"]
    r = _step_rect(po)
    side, c, _ = st
    if side == "z0":
        return (c, r[1] - 0.6), (0, -1)
    if side == "x1":
        return (r[2] + 0.6, c), (1, 0)
    return (r[0] - 0.6, c), (-1, 0)


_geo_cache = {}


def geometry(key, mirror):
    """Low obstacles (walls, porches, steps, chimneys), wall rects, front door/steps, garage, eave footprint."""
    ck = (key, mirror)
    if ck in _geo_cache:
        return _geo_cache[ck]
    p = plan_for(key, mirror)
    h = house_mod.House(p).build()
    walls = [(r["rect"][0] - 0.1, r["rect"][1] - 0.1, r["rect"][2] + 0.1, r["rect"][3] + 0.1)
             for r in p["rooms"] if r.get("type") != "attic"]
    low = list(walls)
    front_po = None
    for po in p.get("porches", []):
        low.append(tuple(po["rect"]))
        sr = _step_rect(po)
        if sr:
            low.append(sr)
            if po["steps"][0] == "z0" and front_po is None:
                front_po = po
    for ch in p.get("chimneys", []):
        x, z, w, d = ch[:4]
        low.append((x - w / 2 - 0.06, z - d / 2 - 0.06, x + w / 2 + 0.06, z + d / 2 + 0.06))
    gar = [d for d in h.meta["doors"] if d["kind"] == "garage"]
    front = [d for d in h.meta["doors"] if d["kind"] == "door" and d["exterior"] and d["name"].endswith("Front")]
    g = dict(plan=p, house=h, walls=walls, low=low, front_po=front_po, footprint=h.footprint(),
             garage=gar[0] if gar else None, front_door=front[0] if front else None,
             flare=p.get("driveway_flare"))
    _geo_cache[ck] = g
    return g


# ------------------------------------------------------------------ zones
def load_layout():
    return json.load(open(LAYOUT))


def zone_frame(z):
    r = z["rect"]
    fx, fz = z["front"]
    yaw = math.atan2(-fx, -fz)
    cx, cz = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
    along_z = abs(fz) > 0.5
    W = abs(r[2] - r[0]) if along_z else abs(r[3] - r[1])
    D = abs(r[3] - r[1]) if along_z else abs(r[2] - r[0])
    ox, oz = cx + fx * D / 2, cz + fz * D / 2
    return dict(yaw=yaw, origin=(ox, oz), W=W, D=D)


def to_local(fr, x, z):
    yaw = fr["yaw"]
    dx, dz = x - fr["origin"][0], z - fr["origin"][1]
    return (dx * math.cos(yaw) - dz * math.sin(yaw), dx * math.sin(yaw) + dz * math.cos(yaw))


def to_world(fr, x, z):
    yaw = fr["yaw"]
    return (fr["origin"][0] + x * math.cos(yaw) + z * math.sin(yaw), fr["origin"][1] - x * math.sin(yaw) + z * math.cos(yaw))


_p02 = None


def p02_bounds():
    global _p02
    if _p02 is None:
        m = json.load(open(P02_MANIFEST))
        _p02 = {x["name"]: (x["bounds_min"], x["bounds_max"]) for x in m["models"]}
    return _p02


def zone_obstacles(layout, z, fr):
    """Pack 02 placements around the zone as local-frame rects: (name, model, rect, kind)."""
    bd = p02_bounds()
    out = []
    for p in layout["placements"]:
        lx, lz = to_local(fr, p["x"], p["z"])
        if not (-fr["W"] / 2 - 4 < lx < fr["W"] / 2 + 4 and -9 < lz < fr["D"] + 4):
            continue
        m = p["model"]
        if m.startswith("RD_Driveway"):
            continue
        if m not in bd:
            continue
        mn, mx = bd[m]
        if m.startswith("VG_Tree"):           # trunk only blocks; canopy reported separately
            mn, mx = [-0.3, 0, -0.3], [0.3, 0, 0.3]
        elif m.startswith(("VG_Flower", "VG_Bush")):   # round clumps: bbox corners are empty
            mn, mx = [mn[0] + 0.15, mn[1], mn[2] + 0.15], [mx[0] - 0.15, mx[1], mx[2] - 0.15]
        # rotate the local bounds corners by the placement yaw into world, then into zone frame
        pts = []
        for ax in (mn[0], mx[0]):
            for az in (mn[2], mx[2]):
                c, s = math.cos(p["yaw"]), math.sin(p["yaw"])
                wx, wz = p["x"] + ax * c + az * s, p["z"] - ax * s + az * c
                pts.append(to_local(fr, wx, wz))
        xs, zs = [q[0] for q in pts], [q[1] for q in pts]
        out.append((p["name"], m, (min(xs), min(zs), max(xs), max(zs)), p["group"]))
    return out


def tree_canopies(layout, fr):
    bd = p02_bounds()
    out = []
    for p in layout["placements"]:
        if not p["model"].startswith("VG_Tree"):
            continue
        lx, lz = to_local(fr, p["x"], p["z"])
        mn, mx = bd[p["model"]]
        rad = max(mx[0] - mn[0], mx[2] - mn[2]) / 2
        out.append((p["name"], (lx, lz), rad, mn[1] + 0.35 * (mx[1] - mn[1])))
    return out


def driveway_local(layout, z, fr):
    for p in layout["placements"]:
        if p["model"].startswith("RD_Driveway") and p.get("tag") == z["id"]:
            r = p["rect"]
            a, b = to_local(fr, r[0], r[1]), to_local(fr, r[2], r[3])
            return (min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]))
    return None


def _ov(a, b, m=0.0):
    return a[0] < b[2] + m and a[2] > b[0] - m and a[1] < b[3] + m and a[3] > b[1] - m


def _sh(r, s):
    return (r[0] + s, r[1], r[2] + s, r[3])


# ------------------------------------------------------------------ solve
def _garage_x(g, s):
    """x where the house wants the driveway (garage door centre, or the flared apron mouth)."""
    if g["flare"]:
        fx = [q[0] for q in g["flare"] if abs(q[1] - min(f[1] for f in g["flare"])) < 1e-6]
        return (min(fx) + max(fx)) / 2 + s
    if g["garage"] is not None:
        return g["garage"]["center"][0] + s
    return None


def check_fit(g, s, fr, obst, drive):
    """Return list of problems for house geometry g shifted by s along local x."""
    W, D = fr["W"], fr["D"]
    probs = []
    for w in g["walls"]:
        w = _sh(w, s)
        if w[0] < -W / 2 - WALL_TOL or w[2] > W / 2 + WALL_TOL or w[1] < -WALL_TOL or w[3] > D + WALL_TOL:
            probs.append(f"wall outside zone {tuple(round(v, 2) for v in w)}")
            break
    for lo in g["low"]:
        lo = _sh(lo, s)
        for (nm, m, r, grp) in obst:
            if _ov(lo, r, 0.05):
                probs.append(f"touches {nm}")
    dxc = (drive[0] + drive[2]) / 2
    corridor = (dxc - DRIVE_HALF - 0.1, -50, dxc + DRIVE_HALF + 0.1, drive[3] - 0.02)
    gx = _garage_x(g, s)
    if gx is not None:
        if abs(gx - dxc) > 0.35:
            probs.append(f"garage/apron x {gx:.2f} != driveway {dxc:.2f}")
        gz = g["garage"]["center"][2] if g["garage"] else 99
        for lo in g["low"]:
            lo = _sh(lo, s)
            if _ov(lo, (dxc - DRIVE_HALF + 0.05, -50, dxc + DRIVE_HALF - 0.05, min(gz - 0.12, drive[3] + 0.05))):
                probs.append("blocks driveway")
                break
    else:
        for lo in g["low"]:
            if _ov(_sh(lo, s), corridor):
                probs.append("blocks driveway corridor")
                break
    return probs


def solve(layout=None):
    layout = layout or load_layout()
    zones = {z["id"]: z for z in layout["zones"]}
    res = []
    for zid, (key, cw) in ASSIGN.items():
        z = zones[zid]
        fr = zone_frame(z)
        obst = zone_obstacles(layout, z, fr)
        drive = driveway_local(layout, z, fr)
        cands = []
        for mirror in (False, True):
            g = geometry(key, mirror)
            for i in range(-120, 121):
                s = round(i * 0.05, 2)
                if check_fit(g, s, fr, obst, drive):
                    continue
                gx = _garage_x(g, s)
                cost = abs(s) + (2 * abs(gx - (drive[0] + drive[2]) / 2) if gx is not None else 0)
                cands.append((round(cost, 3), mirror, s))
        cands.sort()
        pick = None
        for c in cands[:80]:
            wk = walkway(geometry(key, c[1]), c[2], fr, obst, drive)
            if wk is not None:
                pick = (c, wk)
                break
        if pick is None:
            probs = {}
            for mirror in (False, True):
                probs[mirror] = check_fit(geometry(key, mirror), 0.0, fr, obst, drive) or ["no walkway route"]
            res.append(dict(zone=zid, key=key, cw=cw, ok=False, problems=probs))
            continue
        (_, mirror, s), wk = pick
        res.append(dict(zone=zid, zone_type=z["type"], key=key, cw=cw, mirror=mirror, shift=s, ok=True, frame=fr,
                        variant=variant_name(key, cw, mirror), drive=drive, obst=obst, walk=wk))
    return res


# ------------------------------------------------------------------ walkway / apron
def walkway(g, s, fr, obst, drive):
    """A* (0.1 m grid) from the front-step foot to the driveway edge; returns simplified polyline (local)."""
    po = g["front_po"]
    (fx, fz), _ = _step_foot(po)
    fx += s
    dxc = (drive[0] + drive[2]) / 2
    res_ = 0.1
    x0, x1 = -fr["W"] / 2 - 2.5, fr["W"] / 2 + 2.5
    z0, z1 = drive[1] + 0.6, 2.6
    nx, nz = int((x1 - x0) / res_) + 1, int((z1 - z0) / res_) + 1
    HALF = 0.55          # half walkway width + clearance

    def blocked(cx, cz):
        q = (cx - HALF, cz - HALF, cx + HALF, cz + HALF)
        for lo in g["low"]:
            if _ov(_sh(lo, s), q, -0.05):
                return True
        for (_, m, r, grp) in obst:
            if _ov(r, q, -0.02):
                return True
        return False

    def cell(i, j):
        return x0 + i * res_, z0 + j * res_

    start = (int(round((fx - x0) / res_)), int(round((fz - z0) / res_)))
    goal_x = {int(round((dxc - DRIVE_HALF - x0) / res_)), int(round((dxc + DRIVE_HALF - x0) / res_))}

    def is_goal(i, j):
        cx, cz = cell(i, j)
        return (abs(abs(cx - dxc) - DRIVE_HALF) < 0.06 and drive[1] + 0.5 <= cz <= drive[3] - 0.3)

    if abs(fx - dxc) <= DRIVE_HALF:          # steps foot already on the driveway
        return [(fx, fz)]
    openl = [(0, start)]
    came = {start: None}
    cost = {start: 0}
    found = None
    while openl:
        c, cur = heapq.heappop(openl)
        if is_goal(*cur):
            found = cur
            break
        for di, dj, w in ((1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1)):
            nb = (cur[0] + di, cur[1] + dj)
            if not (0 <= nb[0] < nx and 0 <= nb[1] < nz):
                continue
            if nb not in cost and blocked(*cell(*nb)) and nb != start:
                continue
            turn = 0
            if came.get(cur) is not None:
                pd = (cur[0] - came[cur][0], cur[1] - came[cur][1])
                turn = 3 if pd != (di, dj) else 0
            nc = cost[cur] + w + turn
            if nc < cost.get(nb, 1e9):
                cost[nb] = nc
                came[nb] = cur
                hx = min(abs(nb[0] - gx) for gx in goal_x)
                heapq.heappush(openl, (nc + hx, nb))
    if found is None:
        return None
    path = []
    n = found
    while n is not None:
        path.append(cell(*n))
        n = came[n]
    path.reverse()
    # simplify to corner points
    pts = [path[0]]
    for i in range(1, len(path) - 1):
        a, b, c = path[i - 1], path[i], path[i + 1]
        if (round(b[0] - a[0], 3), round(b[1] - a[1], 3)) != (round(c[0] - b[0], 3), round(c[1] - b[1], 3)):
            pts.append(b)
    pts.append(path[-1])
    pts[0] = (fx, fz)
    return pts


if __name__ == "__main__":
    for r in solve():
        if not r["ok"]:
            print(r["zone"], r["key"], "NO FIT", r["problems"])
            continue
        print(r["zone"], r["variant"], "shift", r["shift"], "walk", len(r["walk"]))
