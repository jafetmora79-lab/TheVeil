"""Floor-plan driven house generator.

A plan lists rooms (axis-aligned rectangles = wall centrelines), doors,
windows, stairs, roofs and porches. The generator derives every wall:
union-boundary edges become exterior walls (mitred corners, foundation,
siding), shared edges become interior partitions (per-side room finishes).

House-local frame: X across the frontage, the street is toward -Z, the zone
front line is z = 0, lot level is y = 0, ground floor finished level y = 0.6.
"""
import math

import numpy as np

import arch
from arch import EXT_T, INT_T, TRIM, DRYWALL, GLASS, wall, casing, window_unit, door_node, slider_node, garage_door_node
from res_materials import m01, mt, mr
from veil_mesh.mesh import MB, T, Ry, Rx, nrm
from veil_mesh.gltf import COL_KEY

EPS = 1e-6
SIDES = {"F": (0, -1), "B": (0, 1), "L": (-1, 0), "R": (1, 0)}


def mat_of(name):
    """'Res_X' -> Pack 03, 'Town_X' -> Pack 02, anything else -> Pack 01 id."""
    if name.startswith("Res_"):
        return mr(name[4:])
    if name.startswith("Town_"):
        return mt(name[5:])
    return m01(name)


def room_side(r, side):
    x0, z0, x1, z1 = r
    return {"F": ("z", z0, x0, x1), "B": ("z", z1, x0, x1), "L": ("x", x0, z0, z1), "R": ("x", x1, z0, z1)}[side]


def opp(side):
    return {"F": "B", "B": "F", "L": "R", "R": "L"}[side]


def seg_points(axis, c, lo, hi, side):
    """p0 -> p1 so that the wall's +n (left) normal points out of the room through `side`."""
    if side == "F":
        return (hi, c), (lo, c)
    if side == "B":
        return (lo, c), (hi, c)
    if side == "L":
        return (c, lo), (c, hi)
    return (c, hi), (c, lo)


def subtract_intervals(lo, hi, cuts):
    out = [(lo, hi)]
    for a, b in cuts:
        nxt = []
        for (p, q) in out:
            if b <= p + EPS or a >= q - EPS:
                nxt.append((p, q))
                continue
            if a > p + EPS:
                nxt.append((p, a))
            if b < q - EPS:
                nxt.append((b, q))
        out = nxt
    return [(p, q) for p, q in out if q - p > 1e-4]


def rect_minus(r, holes):
    """Rect minus hole rects -> list of rects (simple guillotine split)."""
    out = [r]
    for h in holes:
        nxt = []
        for (x0, z0, x1, z1) in out:
            hx0, hz0, hx1, hz1 = h
            if hx1 <= x0 + EPS or hx0 >= x1 - EPS or hz1 <= z0 + EPS or hz0 >= z1 - EPS:
                nxt.append((x0, z0, x1, z1))
                continue
            if hz0 > z0 + EPS:
                nxt.append((x0, z0, x1, hz0))
            if hz1 < z1 - EPS:
                nxt.append((x0, hz1, x1, z1))
            mz0, mz1 = max(z0, hz0), min(z1, hz1)
            if hx0 > x0 + EPS:
                nxt.append((x0, mz0, hx0, mz1))
            if hx1 < x1 - EPS:
                nxt.append((hx1, mz0, x1, mz1))
        out = nxt
    return out


class House:
    def __init__(self, plan, cw=None):
        self.p = plan
        self.cw = dict(plan["ext"])
        if cw:
            self.cw.update(cw)
        self.rooms = {r["id"]: r for r in plan["rooms"]}
        self.ext, self.inner, self.col = MB(), MB(), MB()
        self.nodes = []
        self.meta = {"rooms": [], "doors": [], "windows": [], "stairs": [], "lights": [], "switches": []}

    # ---------------------------------------------------------------- levels
    def floor_y(self, r):
        return r.get("y", self.p["levels"][r["lvl"]][0])

    def ceil_y(self, r):
        lvl = self.p["levels"][r["lvl"]]
        return self.floor_y(r) + r.get("h", lvl[1])

    def top_y(self, r):
        """Top of this room's walls: next storey floor if a room sits above, else ceiling + plate."""
        up = [q for q in self.p["rooms"] if q["lvl"] == r["lvl"] + 1 and q.get("type") != "attic" and
              self._overlap(q["rect"], r["rect"])]
        if up:
            return self.p["levels"][r["lvl"] + 1][0]
        return self.ceil_y(r) + 0.12

    @staticmethod
    def _overlap(a, b):
        return a[0] < b[2] - EPS and a[2] > b[0] + EPS and a[1] < b[3] - EPS and a[3] > b[1] + EPS

    # ---------------------------------------------------------------- edges
    def edges(self):
        """Exterior pieces: (room, side, axis, c, lo, hi); interior: (roomA, side, roomB, axis, c, lo, hi)."""
        ext, inner = [], []
        seen = set()
        rooms = [r for r in self.p["rooms"] if r.get("type") != "attic"]
        for r in rooms:
            for side in "FBLR":
                axis, c, lo, hi = room_side(r["rect"], side)
                cuts = []
                for q in rooms:
                    if q is r or q["lvl"] != r["lvl"]:
                        continue
                    a2, c2, lo2, hi2 = room_side(q["rect"], opp(side))
                    if abs(c2 - c) < EPS and lo2 < hi - EPS and hi2 > lo + EPS:
                        a, b = max(lo, lo2), min(hi, hi2)
                        cuts.append((a, b))
                        key = (r["lvl"], axis, round(c, 4), round(a, 4), round(b, 4))
                        if key not in seen:
                            seen.add(key)
                            inner.append((r, side, q, axis, c, a, b))
                for (a, b) in subtract_intervals(lo, hi, cuts):
                    ext.append((r, side, axis, c, a, b))
        return ext, inner

    # ---------------------------------------------------------------- openings
    def openings_for(self, piece_rooms, side, axis, c, lo, hi, p0):
        """Collect openings that fall on this piece; returns [(u0,u1,v0,v1,spec)]."""
        out = []
        for o in self.p.get("doors", []) + self.p.get("windows", []):
            if o.get("_skip"):
                continue
            if "room" in o:      # window or exterior door: room + side
                if not (piece_rooms[1] is None and o["room"] == piece_rooms[0] and o["side"] == side):
                    continue
            else:                # interior door between two rooms
                if piece_rooms[1] is None or {o["a"], o["b"]} != {piece_rooms[0], piece_rooms[1]}:
                    continue
            at = o["at"]
            if not (lo - EPS <= at - o["w"] / 2 and at + o["w"] / 2 <= hi + EPS):
                continue
            # u is measured from p0 along the wall direction
            if axis == "z":
                u = abs(at - p0[0])
            else:
                u = abs(at - p0[1])
            v0 = o.get("sill", 0.0)
            out.append((u - o["w"] / 2, u + o["w"] / 2, v0, v0 + o["h"], o))
        return out

    # ---------------------------------------------------------------- build
    def build(self):
        ext, inner = self.edges()
        self.ext_pieces = ext
        self.build_exterior_walls(ext)
        self.build_partitions(inner)
        for st in self.p.get("stairs", []):      # stairs first: they define the floor/ceiling voids
            self.build_stair(st)
        self.build_floors()
        for po in self.p.get("porches", []):
            self.build_porch(po)
        for rf in self.p.get("roofs", []):
            self.build_roof(rf)
        for ch in self.p.get("chimneys", []):
            arch.chimney(self.ext, self.col, *ch[:5], mat=mat_of(self.cw.get("chimney", "Arch_BrickRed")))
        self.clip_gutters_inside()
        if self.p.get("driveway_flare"):     # flared concrete apron from the Pack 02 driveway to the garage
            self.ext.ground_poly(m01("Road_SidewalkConcrete"), self.p["driveway_flare"], y=0.006)
        for extra in self.p.get("extras", []):
            extra(self)
        self.add_lights()
        return self

    def clip_gutters_inside(self):
        """Gutters and downspouts are generated per roof eave. Where a roof's eave runs over another part of the
        house (a front gable joining the main hip roof, a garage gable against the house) they ended up inside
        rooms - a white post and beam standing in the bedroom. Cut every gutter / downspout box out of every
        room volume it passes through (rooms of all levels, floor to ceiling)."""
        key = mt("PaintWhite")
        g = self.ext.parts.get(key)
        if not g or not g["i"]:
            return
        P = np.asarray(g["p"])
        I = np.asarray(g["i"]).reshape(-1, 3)
        keyv = [tuple(np.round(p, 4)) for p in P]
        par = list(range(len(I)))

        def f(x):
            while par[x] != x:
                par[x] = par[par[x]]
                x = par[x]
            return x
        seen = {}
        for ti, t in enumerate(I):
            for v in t:
                k = keyv[v]
                if k in seen:
                    par[f(ti)] = f(seen[k])
                else:
                    seen[k] = ti
        comps = {}
        for ti in range(len(I)):
            comps.setdefault(f(ti), []).append(ti)
        rooms = [(r["rect"], self.floor_y(r) + 0.02, self.ceil_y(r)) for r in self.p["rooms"] if r.get("type") != "attic"]
        drop, add = set(), []
        for tris in comps.values():
            Q = P[I[tris]].reshape(-1, 3)
            mn, mx = Q.min(0), Q.max(0)
            a = 0 if (mx[0] - mn[0]) >= (mx[2] - mn[2]) else 2          # long horizontal axis
            b = 2 - a
            cuts = []
            for (rc, fy, cy) in rooms:
                lo_a, hi_a = (rc[0], rc[2]) if a == 0 else (rc[1], rc[3])
                lo_b, hi_b = (rc[0], rc[2]) if b == 0 else (rc[1], rc[3])
                if mx[b] <= lo_b or mn[b] >= hi_b or mx[1] <= fy or mn[1] >= cy:
                    continue
                if mx[a] <= lo_a or mn[a] >= hi_a:
                    continue
                cuts.append((lo_a, hi_a))
            if not cuts:
                continue
            drop.update(tris)
            segs = [(mn[a], mx[a])]
            for c0, c1 in cuts:
                nxt = []
                for s0, s1 in segs:
                    if c1 <= s0 or c0 >= s1:
                        nxt.append((s0, s1))
                        continue
                    if c0 > s0:
                        nxt.append((s0, c0))
                    if c1 < s1:
                        nxt.append((c1, s1))
                segs = nxt
            for s0, s1 in segs:
                if s1 - s0 > 0.05:
                    lo, hi = mn.copy(), mx.copy()
                    lo[a], hi[a] = s0, s1
                    add.append((tuple(lo), tuple(hi)))
        if not drop:
            return
        keep = [t for ti, t in enumerate(I) if ti not in drop]
        old = g
        self.ext.parts[key] = {"p": [], "n": [], "uv": [], "i": []}
        ng = self.ext.parts[key]
        for t in keep:
            base = len(ng["p"])
            for v in t:
                ng["p"].append(old["p"][v])
                ng["n"].append(old["n"][v])
                ng["uv"].append(old["uv"][v])
            ng["i"].extend([base, base + 1, base + 2])
        for lo, hi in add:
            self.ext.box(key, lo, hi, skip=())
        self.meta["gutter_boxes_clipped"] = len({f(t) for t in drop})

    # exterior walls --------------------------------------------------------
    def build_exterior_walls(self, ext):
        pieces = []
        for (r, side, axis, c, lo, hi) in ext:
            p0, p1 = seg_points(axis, c, lo, hi, side)
            pieces.append((r, side, axis, c, lo, hi, p0, p1))
        # endpoints -> corner classification
        ends = {}
        for i, pc in enumerate(pieces):
            for k, pt in ((0, pc[6]), (1, pc[7])):
                ends.setdefault((round(pt[0], 4), round(pt[1], 4), pc[0]["lvl"]), []).append((i, k))
        for i, (r, side, axis, c, lo, hi, p0, p1) in enumerate(pieces):
            n = SIDES[side]
            d = (p1[0] - p0[0], p1[1] - p0[1])
            L = math.hypot(*d)
            d = (d[0] / L, d[1] / L)
            e_out, e_in = [0.0, 0.0], [0.0, 0.0]
            caps = []
            for k, pt in ((0, p0), (1, p1)):
                key = (round(pt[0], 4), round(pt[1], 4), r["lvl"])
                for (j, kk) in ends.get(key, []):
                    if j == i:
                        continue
                    q = pieces[j]
                    qa = q[7] if kk == 0 else q[6]            # other end of that piece = direction away
                    e = (qa[0] - pt[0], qa[1] - pt[1])
                    le = math.hypot(*e)
                    e = (e[0] / le, e[1] / le)
                    dot_n = e[0] * n[0] + e[1] * n[1]
                    if abs(dot_n) < 0.5:
                        continue                               # collinear continuation
                    if dot_n < 0:                              # convex corner
                        e_out[k] = EXT_T / 2
                        e_in[k] = -EXT_T / 2
                    else:                                      # concave corner
                        e_out[k] = -EXT_T / 2
                        e_in[k] = 0.0
                        caps.append(k)
            siding = mat_of(r.get("siding", self.cw["siding"]))
            y_floor = self.floor_y(r)
            garage = r.get("type") == "garage"
            under = self.p["levels"][r["lvl"]][0] < 0
            y0 = 0.0 if garage else y_floor
            y_top = self.top_y(r)
            y_ceil = self.ceil_y(r)
            ops = self.openings_for((r["id"], None), side, axis, c, lo, hi, p0)
            holes_w = [(a, b, v0 + y_floor if o.get("kind") != "garage" else v0, v1 + y_floor if o.get("kind") != "garage" else v1)
                       for (a, b, v0, v1, o) in ops]
            wall_in = mat_of(r["wall"])
            if not under:
                M, _ = wall(self.ext, self.col, p0, p1, y0, y_top, EXT_T, siding, None, holes_w,
                            ext={"pos": tuple(e_out)}, faces=("pos",))
                if not garage and y_floor > 0.05:   # foundation band
                    fm = MB()
                    for (a, b, c2, d2) in [(-e_out[0], L + e_out[1], 0.0, y_floor)]:
                        z = EXT_T / 2 + 0.02
                        pts = [[a, c2, z], [b, c2, z], [b, d2 - 0.02, z], [a, d2 - 0.02, z]]
                        fm.quad(mat_of(self.cw.get("foundation", "Arch_ConcreteFoundation")), *pts, n=(0, 0, 1),
                                uv=[(p[0], -p[1]) for p in pts])
                        fm.quad(mat_of(self.cw.get("foundation", "Arch_ConcreteFoundation")), [a, d2 - 0.02, z],
                                [b, d2 - 0.02, z], [b, d2 - 0.02, EXT_T / 2], [a, d2 - 0.02, EXT_T / 2], n=(0, 1, 0))
                        k = 1.2
                        while k < L - 0.8 and y_floor > 0.4:      # crawlspace vents
                            fm.box(mt("VentGrille"), (k, 0.2, z), (k + 0.4, 0.38, z + 0.012), skip=("-z",))
                            k += 3.0
                    self.ext.merge(fm, M)
            else:
                M, _ = arch.frame_2d(p0, p1)
            # inner face up to the ceiling
            wall(self.inner, None if not under else self.col, p0, p1, y_floor, y_ceil, EXT_T, None, wall_in, holes_w,
                 ext={"neg": tuple(e_in)}, faces=("neg",))
            for k in caps:      # close the 4 cm step where an exterior wall meets a partition line
                u = 0.0 if k == 0 else L
                cap = MB()
                zz0, zz1 = -EXT_T / 2, -INT_T / 2
                pts = [[u, y_floor, zz0], [u, y_floor, zz1], [u, y_ceil, zz1], [u, y_ceil, zz0]]
                cap.quad(wall_in, *pts, n=(1 if k == 0 else -1, 0, 0))
                self.inner.merge(cap, M)
            for (a, b, v0, v1, o) in ops:
                self.place_opening(o, M, a, b, v0, v1, y_floor, side_rooms=(None, r["id"]), exterior=True,
                                   wall_p0=p0, wall_p1=p1)

    def build_partitions(self, inner):
        for (r, side, q, axis, c, lo, hi) in inner:
            p0, p1 = seg_points(axis, c, lo, hi, side)
            ops = self.openings_for((r["id"], q["id"]), side, axis, c, lo, hi, p0)
            yr, yq = self.floor_y(r), self.floor_y(q)
            ylo = min(yr, yq)
            holes = [(a, b, v0 + max(yr, yq) if o.get("kind") != "arch" else v0 + max(yr, yq), v1 + max(yr, yq))
                     for (a, b, v0, v1, o) in ops]
            wr, wq = mat_of(r["wall"]), mat_of(q["wall"])
            M, L = wall(self.inner, self.col, p0, p1, yq, self.ceil_y(q), INT_T, wq, None, holes, faces=("pos",),
                        reveal=TRIM, col_wall=False)
            wall(self.inner, None, p0, p1, yr, self.ceil_y(r), INT_T, None, wr, holes, faces=("neg",), reveal=TRIM)
            # collision: from the lower floor to the higher ceiling
            for (a, b, c2, d2) in arch.rects_minus((0, L, ylo, max(self.ceil_y(r), self.ceil_y(q))), holes):
                lc = MB()
                lc.box(COL_KEY, (a, c2, -INT_T / 2), (b, d2, INT_T / 2), skip=())
                self.col.merge(lc, M)
            for (a, b, v0, v1, o) in ops:
                self.place_opening(o, M, a, b, v0, v1, max(yr, yq), side_rooms=(q["id"], r["id"]), exterior=False,
                                   wall_p0=p0, wall_p1=p1, floors=(yq, yr))

    # openings ------------------------------------------------------------------
    def place_opening(self, o, M, u0, u1, v0, v1, y_floor, side_rooms, exterior, wall_p0, wall_p1, floors=None):
        kind = o.get("kind", "window" if "sill" in o else "door")
        t = EXT_T if exterior else INT_T
        d = np.array([M[0, 0], M[2, 0]])
        n = np.array([M[0, 2], M[2, 2]])
        p0 = np.array(wall_p0)
        yb = y_floor if kind not in ("garage",) else 0.0
        w = u1 - u0
        name_base = o.get("name") or f"{kind}_{len(self.meta['doors']) + len(self.meta['windows']) + 1:02d}"
        if kind == "window":
            static, nodes = window_unit(w, o["h"], t, o.get("style", "double_hung"),
                                        sash_node=("INT_WindowSash_" + name_base) if self.p.get("interactive_windows") else None)
            W = M @ T(u0, yb + v0, 0)
            self.ext.merge(static, W)
            if o.get("style") != "boarded":
                casing(self.ext, M, u0, u1, yb + v0, yb + v1, t / 2, 1, mat=mat_of(self.cw.get("trim", "Arch_TrimPainted")))
                casing(self.inner, M, u0, u1, yb + v0, yb + v1, -t / 2, -1, sill=True, head_cap=False)
                if o.get("shutters") or self.cw.get("shutters"):
                    arch.shutters(self.ext, M, u0, u1, yb + v0, yb + v1, t / 2 + 0.03)
            pos = p0 + d * u0
            for nd in nodes:
                nd["t"] = (float(pos[0]), float(yb + v0 + nd["t"][1]), float(pos[1]))
                nd["yaw"] = math.atan2(-d[1], d[0])
                self.nodes.append(nd)
            ctr = p0 + d * (u0 + u1) / 2
            self.meta["windows"].append(dict(name=name_base, center=[float(ctr[0]), yb + (v0 + v1) / 2, float(ctr[1])],
                                             w=w, h=o["h"], room=side_rooms[1], style=o.get("style", "double_hung")))
            return
        # doors / arches / garage
        if kind != "arch":
            for (sz, nz, target) in ((t / 2, 1, self.ext if exterior else self.inner), (-t / 2, -1, self.inner)):
                casing(target, M, u0, u1, yb + v0, yb + v1, sz, nz, mat=(mat_of(self.cw.get("trim", "Arch_TrimPainted")) if (exterior and nz > 0) else TRIM),
                       sill=False, head_cap=exterior and nz > 0)
        else:
            for (sz, nz) in ((t / 2, 1), (-t / 2, -1)):
                casing(self.inner, M, u0, u1, yb + v0, yb + v1, sz, nz, sill=False, head_cap=False, w=0.07)
        # door threshold strip
        if kind != "garage":
            th = MB()
            th.box(m01("Furn_WoodDark"), (u0, yb - 0.002, -t / 2), (u1, yb + 0.012, t / 2), skip=("-y",))
            (self.inner if not exterior else self.ext).merge(th, M)
        # which side does the leaf swing into? room [1] is on the wall's -n side
        into = o.get("into")
        swing_side = "in" if (into is None or into == side_rooms[1] or (side_rooms[0] is None and into != "OUT")) else "out"
        hinge = o.get("hinge", "l")
        name = "INT_" + {"door": "Door", "garage": "GarageDoor", "slider": "SlidingDoor", "arch": "Arch"}[kind] + "_" + name_base
        ctr = p0 + d * (u0 + u1) / 2
        rec = dict(name=name, kind=kind, center=[float(ctr[0]), float(yb), float(ctr[1])], w=w, h=o["h"],
                   normal=[float(n[0]), float(n[1])], rooms=[side_rooms[0] or "OUT", side_rooms[1]], exterior=exterior,
                   style=o.get("style", "interior"))
        self.meta["doors"].append(rec)
        if kind == "arch":
            return
        if kind == "garage":
            pos = p0 + d * u0
            nd = garage_door_node(name, (float(pos[0]), 0.02, float(pos[1])), math.atan2(-d[1], d[0]), w, o["h"])
            # leaf sits flush with the outer face of the wall
            off = n * (t / 2 - 0.02)
            nd["t"] = (float(pos[0] + off[0]), 0.02, float(pos[1] + off[1]))
            self.nodes.append(nd)
            return
        if o.get("paint"):
            paint = mat_of(o["paint"])
        elif exterior and o.get("style") == "front":
            # the Town_Paint* textures are flat, low-contrast stucco paints: on a door leaf at night they read as a
            # concrete slab. Front doors get stained wood (grain, raised panels) instead.
            dp = self.cw.get("door", "Town_PaintRed")
            paint = mat_of("Furn_WoodDark" if dp.startswith("Town_Paint") else dp)
        elif exterior:
            paint = m01("Furn_WoodPainted")
        else:
            paint = m01("Arch_TrimPainted")
        if kind == "slider":
            pos = p0 + d * u0 - n * 0.03
            self.nodes.append(slider_node(name, (float(pos[0]), float(yb), float(pos[1])), math.atan2(-d[1], d[0]),
                                          w * 0.5 + 0.04, o["h"], m01("Furn_WoodPainted"), w * 0.5 - 0.05,
                                          glass=o.get("glass", True)))
            return
        # hinged leaf: hinge on the chosen jamb, on the face of the swing side
        side_sign = -1 if swing_side == "in" else 1           # -n side is room [1]
        off = n * side_sign * (t / 2 - 0.03)
        lw = w - 0.02
        if hinge == "l":
            pos = p0 + d * (u0 + 0.01) + off
            yaw = math.atan2(-d[1], d[0])
            open_deg = 95.0 if side_sign < 0 else -95.0
        else:
            pos = p0 + d * (u1 - 0.01) + off
            yaw = math.atan2(-d[1], d[0]) + math.pi
            open_deg = -95.0 if side_sign < 0 else 95.0
        nd = door_node(name, (float(pos[0]), float(yb + 0.01), float(pos[1])), yaw, lw, o["h"] - 0.02, paint,
                       o.get("style", "interior"), open_deg)
        rec.update(hinge=[float(pos[0]), float(pos[1])], yaw=yaw, open_deg=open_deg, leaf=lw)
        self.nodes.append(nd)
        # steps on the low side when floors differ (garage -> house, outside -> porch handled by porches)
        if floors and abs(floors[0] - floors[1]) > 0.05:
            lowside = 1 if floors[0] < floors[1] else -1        # +n side is room [0]
            ylo, yhi = min(floors), max(floors)
            nst = max(1, int(round((yhi - ylo) / 0.16)))
            st, sc = MB(), MB()
            for k in range(nst):
                dz0 = t / 2 + k * 0.28
                st.box(m01("Com_StorageConcrete"), (u0 - 0.1, ylo, dz0), (u1 + 0.1, ylo + (yhi - ylo) * (nst - k) / nst, dz0 + 0.28),
                       skip=("-y", "-z"))
            run = nst * 0.28
            sc.quad(COL_KEY, [u0 - 0.1, yhi, t / 2], [u1 + 0.1, yhi, t / 2], [u1 + 0.1, ylo, t / 2 + run + 0.15],
                    [u0 - 0.1, ylo, t / 2 + run + 0.15], n=(0, 1, 0))
            Mf = M if lowside > 0 else M @ np.diag([1.0, 1, -1, 1])
            self.inner.merge(st, Mf)
            self.col.merge(sc, Mf)
            rec["steps"] = dict(side=int(lowside), run=run)

    # floors / ceilings -------------------------------------------------------------
    def voids(self, lvl):
        out = []
        for st in self.p.get("stairs", []):
            if st["to"] == lvl:
                out.append(st["void"])
        return out

    def build_floors(self):
        for r in self.p["rooms"]:
            y = self.floor_y(r)
            fmat = mat_of(r["floor"])
            holes = self.voids(r["lvl"])
            for (x0, z0, x1, z1) in rect_minus(r["rect"], holes):
                self.inner.ground_poly(fmat, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], y=y)
                self.col.ground_poly(COL_KEY, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], y=y)
            if r.get("type") == "attic":
                continue
            yc = self.ceil_y(r)
            ch = self.voids(r["lvl"] + 1)
            cm = mat_of(r.get("ceil", "Int_DrywallLight"))
            for (x0, z0, x1, z1) in rect_minus(r["rect"], ch):
                pts = [[x0, yc, z0], [x0, yc, z1], [x1, yc, z1], [x1, yc, z0]]
                self.inner.quad(cm, *pts, n=(0, -1, 0), uv=[(p[0], p[2]) for p in pts])
            self.meta["rooms"].append(dict(id=r["id"], type=r["type"], lvl=r["lvl"], rect=list(r["rect"]), floor_y=y,
                                           ceil_y=yc))
        for r in self.p["rooms"]:
            if r.get("type") == "attic":
                self.meta["rooms"].append(dict(id=r["id"], type="attic", lvl=r["lvl"], rect=list(r["rect"]),
                                               floor_y=self.floor_y(r), ceil_y=self.floor_y(r) + 1.6,
                                               walk=list(r.get("walk", r["rect"]))))

    def build_stair(self, st):
        x0, z0, x1, z1 = st["rect"]
        lvl_from, lvl_to = st["from"], st["to"]
        y_a = st.get("y_from", self.p["levels"][lvl_from][0])
        y_b = st.get("y_to", self.p["levels"][lvl_to][0] if lvl_to in self.p["levels"] else None)
        n = st.get("risers") or max(2, int(round((y_b - y_a) / 0.18)))
        rise = (y_b - y_a) / n
        tread = st.get("tread", 0.27)
        run = n * tread
        dirn = st.get("dir", "+z")
        width = (x1 - x0) if dirn in ("+z", "-z") else (z1 - z0)
        if "void_len" not in st or st.get("auto_void", True):
            # open the ceiling where a 1.75 m player (+0.35 margin) would hit the slab above
            start = max(0.0, run * (y_b - 2.1 - y_a) / (y_b - y_a) - 0.35)
            st["void_len"] = run - start
        if dirn == "+z":
            origin, yaw = (x0, y_a, z0), 0.0
            void = (x0, z0 + run - min(run, st.get("void_len", run)), x1, z0 + run)
        elif dirn == "-z":
            origin, yaw = (x1, y_a, z1), math.pi
            void = (x0, z1 - run, x1, z1 - run + min(run, st.get("void_len", run)))
        elif dirn == "+x":
            origin, yaw = (x0, y_a, z1), math.pi / 2
            void = (x0 + run - min(run, st.get("void_len", run)), z0, x0 + run, z1)
        else:
            origin, yaw = (x1, y_a, z0), -math.pi / 2
            void = (x1 - run, z0, x1 - run + min(run, st.get("void_len", run)), z1)
        st["void"] = tuple(round(v, 4) for v in void)
        arch.stair(self.inner, self.col, origin, yaw, width, n, rise, tread, open_sides=st.get("open", ("r",)))
        # guard rails on every void edge except the arrival edge and edges that run along a wall
        vx0, vz0, vx1, vz1 = st["void"]
        edges = {"z0": ((vx0, vz0), (vx1, vz0)), "z1": ((vx1, vz1), (vx0, vz1)),
                 "x0": ((vx0, vz1), (vx0, vz0)), "x1": ((vx1, vz0), (vx1, vz1))}
        arrival = {"+z": "z1", "-z": "z0", "+x": "x1", "-x": "x0"}[dirn]
        upper = [q for q in self.p["rooms"] if q["lvl"] == lvl_to and self._overlap(q["rect"], st["void"])]
        rails = []
        for key, (a, b) in edges.items():
            if key == arrival:
                continue
            c = a[1] if key[0] == "z" else a[0]
            near_wall = any(abs(c - (q["rect"][1] if key == "z0" else q["rect"][3] if key == "z1" else
                                     q["rect"][0] if key == "x0" else q["rect"][2])) < 0.12 for q in upper)
            mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            crossed = any(o is not st and (o["rect"][0] - 0.05 <= mid[0] <= o["rect"][2] + 0.05) and
                          (o["rect"][1] - 0.6 <= mid[1] <= o["rect"][3] + 0.6) for o in self.p.get("stairs", []))
            if not near_wall and not crossed:
                arch.railing(self.inner, self.col, a, b, y_b)
                rails.append(key)
        st["rails_built"] = rails
        foot = {"+z": (x0, z0, x1, z0 + run), "-z": (x0, z1 - run, x1, z1), "+x": (x0, z0, x0 + run, z1),
                "-x": (x1 - run, z0, x1, z1)}[dirn]
        self.meta["stairs"].append(dict(rect=list(st["rect"]), foot=list(foot), dir=dirn, y_from=y_a, y_to=y_b, run=run, width=width,
                                        arrive=st.get("arrive", 0.5), lvl_from=lvl_from, lvl_to=lvl_to,
                                        risers=n, rise=rise, tread=tread, origin=list(origin), yaw=yaw, void=list(void)))

    def build_porch(self, po):
        arch.porch(self.ext, self.col, po["rect"], po["deck_y"], steps=po.get("steps"), rails=po.get("rails", ("x0", "x1", "z0")),
                   columns=po.get("columns"), deck_mat=mat_of(po.get("deck", "Arch_WoodPlanksAged")), skirt=po.get("skirt", True),
                   col_h=po.get("col_h", 2.45), risers=po.get("risers"),
                   col_mat=mat_of(po["col_mat"]) if po.get("col_mat") else None)
        self.meta.setdefault("porches", []).append(dict(rect=list(po["rect"]), deck_y=po["deck_y"], steps=po.get("steps"),
                                                        risers=po.get("risers") or max(1, int(round(po["deck_y"] / 0.15)))))
        rf = po.get("roof")
        if rf:
            self.build_roof(rf)

    def build_roof(self, rf):
        kind = rf[0]
        roof_mat = mat_of(rf[-1].get("mat", self.cw["roof"])) if isinstance(rf[-1], dict) else mat_of(self.cw["roof"])
        kw = dict(rf[-1]) if isinstance(rf[-1], dict) else {}
        kw.pop("mat", None)
        if kind == "gable":
            _, rect, base_y, pitch, ridge = rf[:5]
            gm = mat_of(self.cw.get("gable", self.cw["siding"]))
            arch.gable_roof(self.ext, self.col, rect, base_y, pitch, ridge, mat=roof_mat, gable_mat=gm,
                            fascia=mat_of(self.cw.get("trim", "Arch_TrimPainted")), **kw)
        elif kind == "hip":
            _, rect, base_y, pitch = rf[:4]
            arch.hip_roof(self.ext, self.col, rect, base_y, pitch, mat=roof_mat, fascia=mat_of(self.cw.get("trim", "Arch_TrimPainted")), **kw)
        elif kind == "shed":
            _, rect, y_low, y_high, high = rf[:5]
            arch.shed_roof(self.ext, self.col, rect, y_low, y_high, high, mat=roof_mat, fascia=mat_of(self.cw.get("trim", "Arch_TrimPainted")), **kw)

    def add_lights(self):
        for r in self.meta["rooms"]:
            if r["type"] in ("attic", "porch"):
                continue
            x0, z0, x1, z1 = r["rect"]
            cx, cz, y = (x0 + x1) / 2, (z0 + z1) / 2, r["ceil_y"]
            fx = MB()
            fx.cyl(mr("BulbGlow"), (cx, y - 0.12, cz), 0.16, 0.1, seg=8, r_top=0.12, caps=("bottom",))
            fx.cyl(TRIM, (cx, y - 0.02, cz), 0.2, 0.02, seg=8, caps=("bottom",))
            self.inner.merge(fx)
            self.meta["lights"].append(dict(room=r["id"], pos=[cx, y - 0.25, cz]))
        # light switches beside each room's first interior door (on that room's side)
        done = set()
        for dr in self.meta["doors"]:
            room = dr["rooms"][1]
            if room in done or dr["kind"] == "garage":
                continue
            done.add(room)
            nrm2 = np.array(dr["normal"])
            dvec = np.array([-nrm2[1], nrm2[0]])
            ctr = np.array([dr["center"][0], dr["center"][2]])
            t = EXT_T if dr["exterior"] else INT_T
            pos = ctr + dvec * (dr["w"] / 2 + 0.22) - nrm2 * (t / 2 + 0.005)
            yaw = math.atan2(-nrm2[0], -nrm2[1])
            plate = MB()
            plate.box(mr("DetailAtlas"), (-0.04, -0.06, 0), (0.04, 0.06, 0.012), skip=("-z",),
                      uvrect={"+z": _drect("light_switch")})
            tog = MB()
            tog.box(m01("Furn_PlasticDirty"), (-0.008, -0.02, 0), (0.008, 0.02, 0.02), skip=("-z",))
            y = dr["center"][1] + 1.2
            name = f"INT_LightSwitch_{room}"
            self.nodes.append({"name": name, "t": (float(pos[0]), float(y), float(pos[1])), "yaw": yaw, "mb": plate,
                               "extras": {"veil_interact": "switch", "room": room},
                               "children": [{"name": name + "_Toggle", "t": (0, 0, 0.012), "mb": tog,
                                             "extras": {"veil_interact": "toggle", "axis": "x", "open_deg": 25}}]})
            self.meta["switches"].append(dict(name=name, room=room, pos=[float(pos[0]), y, float(pos[1])]))

    # ---------------------------------------------------------------- output
    def spec(self, name):
        children = [{"name": name + "_Exterior", "mb": self.ext}, {"name": name + "_Interior", "mb": self.inner},
                    {"name": name + "_Col-colonly", "mb": self.col}]
        children += self.nodes
        for lt in self.meta["lights"]:
            children.append({"name": "Light_" + lt["room"], "t": tuple(lt["pos"])})
        return {"name": name, "children": children}

    def footprint(self):
        """Outer bounds of all visual geometry at lot level (for zone fitting)."""
        allp = []
        for mb in (self.ext, self.inner):
            for g in mb.parts.values():
                allp += g["p"]
        a = np.asarray(allp)
        return [float(a[:, 0].min()), float(a[:, 2].min()), float(a[:, 0].max()), float(a[:, 2].max())]


def _drect(key):
    from res_textures import DETAIL_RECTS
    x, y, w, h = DETAIL_RECTS[key]
    return (x / 256, y / 256, (x + w) / 256, (y + h) / 256)
