#!/usr/bin/env python3
"""THE VEIL - Phase 1 game world generator (Greyhaven, extended for the opening drive).

    python3 game/tools/build_world.py

Why: in the Pack 02 layout the protagonist's house (Maple Ave) is ~200 m of road from the supermarket - about
15 s of driving. The opening needs >= 60 s of real driving, so the town grows outward instead:

  * ROUTE 9 (which already left the town core at its south-east corner) continues as a county road through the
    woods, with two gentle 90-degree bends, to a T junction (N20, bus stop),
  * HARLOW LN runs west from it into a new subdivision with a side cul-de-sac (ASPEN CT) and FERN CT, where the
    protagonist's house now stands (same lot geometry as before, so the hero house, its driveway, walkway and
    the sedan marker fit exactly),
  * the old Maple Ave lot becomes an ordinary neighbour's house (Pack 03 Ranch B).

Nothing in THE_VEIL_ASSETS_V2 is modified. The Pack 02 layout generator (town_layout.py) and the Pack 03 house
fitter (placement.py / build_residential.lot_connections) are used as libraries:
  * extension streets, sidewalks, lots, driveways, fences, lamps and yard dressing come from the same code paths,
  * the terrain (cut out around every road / sidewalk / lot) and the woods are regenerated for the whole, larger
    map, so new roads never sit under grass or trees,
  * every house (core + new) is re-fitted by placement.solve, and all walkways / garage aprons are rebuilt.
Outputs (game/world/generated/, res://game/world/...):
  TOWN_Ground_Game.glb, TOWN_Woods_Game_*.glb, RES_LotConnections_Game.glb (+ .import)
  ../Greyhaven_Extension.tscn  - extension streets + props + regenerated ground + woods + street lights
  ../Greyhaven_Houses.tscn     - every house (core + subdivision), the relocated Player_Home
  ../world_data.json           - spawn / sedan / destination / route polyline + lengths (used by game code + tests)
"""
import json
import math
import os
import sys
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
V2 = os.path.join(REPO, "THE_VEIL_ASSETS_V2")
for p in (os.path.join(V2, "02_Town", "Source_Scripts"), os.path.join(V2, "Source_Scripts"),
          os.path.join(V2, "03_Residential", "Source_Scripts")):
    sys.path.insert(0, p)
sys.path.insert(0, HERE)

import town_layout as TL  # noqa: E402
from veil_mesh.mesh import MB  # noqa: E402
from veil_mesh.materials import m01  # noqa: E402
from veil_mesh.gltf import GLBWriter, COL_KEY  # noqa: E402
from veil_mesh.kit import LOT_Y, ROW_HALF, EDGE  # noqa: E402
import placement  # noqa: E402

OUT = os.path.join(REPO, "game", "world", "generated")
WORLD = os.path.join(REPO, "game", "world")
RES_GAME = "res://game/world/generated"
RES_V2 = "res://THE_VEIL_ASSETS_V2"
BOUNDS = (-160.0, -160.0, 400.0, 600.0)
CORES = [(-92.0, -134.0, 136.0, 40.0),          # town core (Pack 02)
         (46.0, 356.0, 354.0, 578.0)]           # Harlow / Fern subdivision (lawns, no woods)
CELL = 0.5

LAYOUT = json.load(open(os.path.join(V2, "02_Town", "Town_Layout", "greyhaven_layout.json")))
MANIFEST = json.load(open(os.path.join(V2, "02_Town", "Documentation", "MODEL_MANIFEST.json")))["models"]
MODEL_PATH = {m["name"]: RES_V2 + "/" + m["glb"] for m in MANIFEST}


def xform(yaw, x, y, z):
    return TL.xform(yaw, x, y, z)


# =============================================================================== extension network
def route9_chain(L):
    """Continue Route 9 from the end of the Pack 02 chain (184, 44) heading +Z. Returns (end point, dir, route pts)."""
    x, z, d = 184.0, 44.0, (0, 1)
    pts = [(184.0, 44.0)]
    pieces = ["R"] * 20 + ["CL"] + ["R"] * 10 + ["CR"] + ["R"] * 14
    for i, p in enumerate(pieces):
        yaw = TL.yaw_for(d)
        if p == "R":
            L.place("RD_Shoulder_Rural_10m", "Roads", x, z, yaw, tag=f"ROUTE_9X:{i}")
            x, z = x + d[0] * 10, z + d[1] * 10
            pts.append((x, z))
        else:
            mdl = "RD_Curve_Gentle_Right_30m" if p == "CR" else "RD_Curve_Gentle_Left_30m"
            L.place(mdl, "Roads", x, z, yaw, tag=f"ROUTE_9X:{i}")
            # arc of radius 24 about the curve centre (pts every 15 degrees for the route polyline)
            for k in range(1, 7):
                a = math.radians(15 * k)
                lx, lz = (-24 + 24 * math.cos(a), 24 * math.sin(a)) if p == "CR" else (24 - 24 * math.cos(a), 24 * math.sin(a))
                ox, oz = TL.rot(yaw, lx, lz)
                pts.append((x + ox, z + oz))
            ex = -24 if p == "CR" else 24
            ox, oz = TL.rot(yaw, ex, 24)
            x, z = x + ox, z + oz
            nd = TL.rot(yaw, -1 if p == "CR" else 1, 0)
            d = (round(nd[0]), round(nd[1]))
    return (x, z), d, pts


def ext_network(chain_end, d):
    ex, ez = chain_end
    assert d == (0, 1), d
    n20 = (ex, ez + 6)
    n23 = (n20[0] - (12 + 10 * 12), n20[1])
    n21 = (n23[0] - (12 + 10 * 12), n20[1])
    n24 = (n23[0], n23[1] - (12 + 10 * 5))
    n22 = (n21[0], n21[1] + 12 + 10 * 11)
    n25 = (n20[0], n20[1] + 12 + 10 * 3)
    nodes = {
        "N20": (n20[0], n20[1], "T", "NSW", ("ROUTE 9", "HARLOW LN")),
        "N23": (n23[0], n23[1], "T", "EWN", ("ASPEN CT", "HARLOW LN")),
        "N21": (n21[0], n21[1], "L", "ES", ("FERN CT", "HARLOW LN")),
        "N24": (n24[0], n24[1], "D", "S", ("ASPEN CT", "")),
        "N22": (n22[0], n22[1], "D", "N", ("FERN CT", "")),
        "N25": (n25[0], n25[1], "D", "N", ("ROUTE 9", "")),
    }
    edges = [("HARLOW_E", "N20", "N23", "res", "HARLOW LN"), ("HARLOW_W", "N23", "N21", "res", "HARLOW LN"),
             ("ASPEN", "N23", "N24", "res", "ASPEN CT"), ("FERN", "N21", "N22", "res", "FERN CT"),
             ("ROUTE9_S", "N20", "N25", "conn", "ROUTE 9")]
    return nodes, edges


DESIGNS = [("Ranch", None), ("TwoStorey", None), ("Cottage", "B"), ("Bungalow", None), ("SplitLevel", None),
           ("Ranch", "C"), ("MillWorker", "B"), ("Cottage", None), ("TwoStorey", "B"), ("Bungalow", "B"),
           ("SplitLevel", "B"), ("Ranch", "B"), ("MillWorker", None)]


def ext_lots(frames):
    """17 m lots along every residential extension edge (driveway module chosen inside each lot)."""
    lots, n = [], 0
    core_pl = None
    for (eid, sides) in (("HARLOW_E", "NS"), ("HARLOW_W", "NS"), ("ASPEN", "EW"), ("FERN", "EW")):
        fr = frames[eid]
        span = fr["n"] * 10
        m = int(span // 17)
        w, off = span / m, 0.0
        if eid == "FERN":          # 17 m lots offset 5 m: lot 3 = the Maple Ave hero-lot geometry (driveway 0.5 m past centre)
            w, off = 17.0, 5.0
        for side in sides:
            for j in range(m):
                s0, s1 = 6 + off + w * j, 6 + off + w * (j + 1)
                ks = [k for k in range(fr["n"]) if s0 + 4 <= 6 + 10 * k + 5 <= s1 - 4]
                if not ks:
                    continue
                k = min(ks, key=lambda q: abs(6 + 10 * q + 5 - (s0 + s1) / 2))
                n += 1
                lots.append(dict(id=f"EXT_HOUSE_{n:02d}", edge=eid, side=side, s0=round(s0, 3), s1=round(s1, 3), k=k))
    # protagonist's home: Fern Ct, the same 17 m lot / driveway geometry as the old Maple Ave lot (22..39, k=2)
    for lot in lots:
        if lot["edge"] == "FERN" and lot["side"] == "W" and abs(lot["s0"] - 62.0) < 1e-6:
            lot.update(id="PLAYER_HOME")
            core_pl = lot
    assert core_pl and 6 + 10 * core_pl["k"] + 5 - (core_pl["s0"] + core_pl["s1"]) / 2 == 0.5, core_pl
    return lots


def ext_props(L, frames, lots, nodes, edges):
    rng = TL.rng_of("greyhaven_ext_props")
    drv = {}
    for lot in lots:
        drv.setdefault(lot["edge"], []).append((6 + 10 * lot["k"] + 5, lot["sideAB"]))
    for (eid, A, B, style, street) in edges:
        fr = frames[eid]
        s, side = 8.0, "A"
        while s < 6 + fr["L"] - 1:
            if any(abs(s - ds) < 3 and sd == side for ds, sd in drv.get(eid, [])):
                s += 3
            x, z = TL.at(fr, s, EDGE + 1.9, side)
            sgn = 1 if side == "A" else -1
            L.lights.append(L.place("SP_Lamp_Residential", "StreetProps", x, z,
                                    TL.yaw_for((-fr["lx"][0] * sgn, -fr["lx"][1] * sgn)), tag=eid))
            side = "B" if side == "A" else "A"
            s += 25
    for nid, (x, z, kind, arms, names) in nodes.items():
        if kind != "T":
            continue
        stem = [a for a in arms if TL.DIRS[a] == tuple(-v for v in TL.DIRS[[b for b in "NSEW" if b not in arms][0]])]
        for a in stem:
            d = TL.DIRS[a]
            t = (-d[0], -d[1])
            right = (-t[1], t[0])
            L.place("SP_Sign_Stop", "StreetProps", x + d[0] * 6.8 + right[0] * 4.6, z + d[1] * 6.8 + right[1] * 4.6,
                    TL.yaw_for(d), tag=nid)
        L.place("SP_FireHydrant", "StreetProps", x - 5.2, z + 6.8, 0.0, tag=nid)
    for nid in ("N22", "N24"):
        x, z = nodes[nid][:2]
        L.place("SP_Sign_DeadEnd", "StreetProps", x + 5.2, z - 8.0 if nid == "N22" else z + 8.0, 0.0, tag=nid)
    # Route 9 / Harlow junction: bus stop (landmark) + speed limit
    n20 = nodes["N20"]
    L.place("SP_BusShelter", "StreetProps", n20[0] + 9.0, n20[1] - 16.0, -math.pi / 2, tag="N20")
    L.place("SP_Sign_BusStop", "StreetProps", n20[0] + 7.2, n20[1] - 21.0, -math.pi / 2, tag="N20")
    L.place("SP_TrashBin_Public", "StreetProps", n20[0] + 8.0, n20[1] - 11.5, 0.0, tag="N20")
    L.place("SP_Sign_SpeedLimit25", "StreetProps", n20[0] - 12.0, n20[1] - 7.0, math.pi, tag="HARLOW_E")
    n25 = nodes["N25"]
    L.place("SP_RoadBarrier", "Interactive", n25[0], n25[1] + 4.0, 0.0, tag="ROUTE9_END")
    for k in range(3):
        L.place("SP_TrafficCone", "Interactive", n25[0] - 2 + 2 * k, n25[1] + 2.5, 0.0, tag="ROUTE9_END")
    # lot dressing: same recipe as the Pack 02 core lots (mailbox, water meter, yard tree, bushes, fences)
    for lot in lots:
        fr = frames[lot["edge"]]
        side = lot["sideAB"]
        drv_s = 6 + 10 * lot["k"] + 5
        r = TL.rng_of(lot["id"] + "_ext")
        sgn = 1 if side == "A" else -1
        to_road = (-fr["lx"][0] * sgn, -fr["lx"][1] * sgn)
        mx, mz = TL.at(fr, drv_s + 2.3, ROW_HALF + 0.5, side)
        L.place("SP_Mailbox_Residential", "StreetProps", mx, mz, TL.yaw_for(to_road), tag=lot["id"])
        wx, wz = TL.at(fr, drv_s - 2.4, ROW_HALF + 0.6, side)
        L.place("UT_WaterMeter", "StreetProps", wx, wz, 0.0, tag=lot["id"])
        ts = lot["s0"] + 3.5 if drv_s - lot["s0"] > 7 else lot["s1"] - 3.5
        tx, tz = TL.at(fr, ts, ROW_HALF + 3.2, side)
        L.place("VG_Tree_DeciduousLarge" if r.random() < 0.45 else "VG_Tree_DeciduousSmall", "Vegetation", tx, tz,
                r.random() * 6.28, tag=lot["id"])
        for _ in range(2):
            bs = r.uniform(lot["s0"] + 3, lot["s1"] - 3)
            if abs(bs - drv_s) > 3:
                bx, bz = TL.at(fr, bs, ROW_HALF + 4.9, side)
                L.place("VG_Bush" if r.random() < 0.7 else "VG_FlowerPatch", "Vegetation", bx, bz, r.random() * 6.28,
                        tag=lot["id"])
        style = ["picket", "hedge", "none", "picket", "none"][zlib.crc32(lot["id"].encode()) % 5]
        if lot["id"] == "PLAYER_HOME":
            style = "picket"
        path_s = (lot["s0"] + lot["s1"]) / 2 if abs((lot["s0"] + lot["s1"]) / 2 - drv_s) > 3.5 else lot["s0"] + 4
        fence_run(L, fr, side, lot["s0"] + 0.25, lot["s1"] - 0.25, ROW_HALF + 0.25, style,
                     gaps=[(drv_s - 1.75, drv_s + 1.75)], gate=(path_s if style == "picket" else None), tag=lot["id"])
        back = "privacy" if zlib.crc32((lot["id"] + "b").encode()) % 3 else "chain"
        fence_run(L, fr, side, lot["s0"] + 0.25, lot["s1"] - 0.25, ROW_HALF + 19.6, back, gaps=[], gate=None,
                     tag=lot["id"], gate_model="FN_FenceGate_Privacy_1.25m")


def route9_poles(L, pts):
    """Utility poles with street-light arms every ~45 m along the county road (east verge)."""
    acc, last = 0.0, None
    for i in range(1, len(pts)):
        a, b = np.array(pts[i - 1]), np.array(pts[i])
        seg = np.linalg.norm(b - a)
        acc += seg
        if acc >= 45.0:
            acc = 0.0
            d = (b - a) / seg
            right = np.array([-d[1], d[0]])
            p = b + right * 7.4
            L.lights.append(L.place("SP_UtilityPole_Streetlight", "Utilities", float(p[0]), float(p[1]),
                                    TL.yaw_for((-right[0], -right[1])), tag="ROUTE_9X"))


def fence_run(L, fr, side, s0, s1, lat, style, gaps, gate, tag, gate_model="FN_GardenGate_1.25m"):
    """Pack 02 fence_run with one fix: a gap (driveway) gets a post at each edge and nothing inside it.
    (The Pack 02 version steps through gaps in 1.25 m increments and drops a post at every step, so every
    driveway in the core town had 3-4 picket posts standing in it.)"""
    if style == "none":
        return
    sec = {"picket": "FN_Picket_2.5m", "hedge": "FN_HedgeBoundary_2.5m", "privacy": "FN_Privacy_2.5m",
           "chain": "FN_ChainLink_2.5m"}[style]
    post = {"picket": "FN_Post_Picket", "privacy": "FN_Post_Privacy", "chain": "FN_Post_ChainLink"}.get(style)
    d = fr["d"]
    yaw = TL.yaw_for((d[0], d[1])) - math.pi / 2
    s = s0
    while s + 2.5 <= s1 + 1e-6:
        if gate is not None and s <= gate < s + 2.5:
            x, z = TL.at(fr, s, lat, side)
            L.place(gate_model, "Interactive", x, z, yaw, tag=tag)
            if post:
                x2, z2 = TL.at(fr, s + 1.25, lat, side)
                L.place(post, "Fences", x2, z2, yaw, tag=tag)
            s += 1.25
            gate = None
            continue
        hit = [(a, b) for a, b in gaps if not (s + 2.5 <= a or s >= b)]
        if hit:
            a, b = hit[0]
            if post:
                x, z = TL.at(fr, s, lat, side)
                L.place(post, "Fences", x, z, yaw, tag=tag)
            s = max(s + 1.25, b)
            if post and s + 2.5 <= s1 + 1e-6:
                x, z = TL.at(fr, s, lat, side)
                L.place(post, "Fences", x, z, yaw, tag=tag)
            continue
        x, z = TL.at(fr, s, lat, side)
        L.place(sec, "Fences", x, z, yaw, tag=tag)
        s += 2.5
    if post:
        x, z = TL.at(fr, s, lat, side)
        L.place(post, "Fences", x, z, yaw, tag=tag)


# =============================================================================== terrain + woods (whole map)
def in_cores(X, Z):
    m = np.zeros_like(X, dtype=bool)
    for (a, b, c, d) in CORES:
        m |= (X > a) & (X < c) & (Z > b) & (Z < d)
    return m


def terrain(items, zones):
    x0, z0, x1, z1 = BOUNDS
    nx, nz = int((x1 - x0) / CELL), int((z1 - z0) / CELL)
    occ = np.zeros((nz, nx), bool)
    xs = x0 + (np.arange(nx) + 0.5) * CELL
    zs = z0 + (np.arange(nz) + 0.5) * CELL
    for it in items:
        r = it.get("rect")
        if r is None or it["group"] not in ("Roads", "Sidewalks", "Lots"):
            continue
        i0, i1 = np.searchsorted(xs, r[0] - 1e-6), np.searchsorted(xs, r[2] + 1e-6)
        j0, j1 = np.searchsorted(zs, r[1] - 1e-6), np.searchsorted(zs, r[3] + 1e-6)
        occ[j0:j1, i0:i1] = True
    names = ["Grnd_GrassShort", "Grnd_GrassOvergrown", "Grnd_LeavesFallen", "Grnd_DeadVegetation", "Grnd_GrassDry",
             "Road_Gravel", "Grnd_Soil"]
    X, Z = np.meshgrid(xs, zs)
    woods = ~in_cores(X, Z)
    mat = np.zeros((nz, nx), np.int8)
    h = ((np.floor(X / 8).astype(int) * 73856093) ^ (np.floor(Z / 8).astype(int) * 19349663)) % 100
    mat[woods] = 1
    mat[woods & (h < 30)] = 2
    mat[woods & (h > 88)] = 3
    for zn in zones:
        r = zn["rect"]
        inside = (X >= r[0]) & (X <= r[2]) & (Z >= r[1]) & (Z <= r[3])
        if zn["type"].startswith("storefront") or zn["type"] in ("supermarket", "pharmacy", "commercial_spare", "gas_canopy"):
            mat[inside] = 4
        elif zn["type"] in ("quarry_entrance", "trailhead"):
            mat[inside] = 5
        elif zn["type"] == "route_exit":
            mat[inside] = 6
    back = (X > -56) & (X < 56) & (Z > 6) & (Z < 19)
    mat[back & (mat == 0)] = 4
    mb, col = MB(), MB()
    rects = 0
    for m in range(len(names)):
        grid = (~occ) & (mat == m)
        done = np.zeros_like(grid)
        for j in range(nz):
            i = 0
            while i < nx:
                if grid[j, i] and not done[j, i]:
                    i2 = i
                    while i2 < nx and grid[j, i2] and not done[j, i2]:
                        i2 += 1
                    j2 = j + 1
                    while j2 < nz and grid[j2, i:i2].all() and not done[j2, i:i2].any():
                        j2 += 1
                    done[j:j2, i:i2] = True
                    q = [(x0 + i * CELL, z0 + j * CELL), (x0 + i2 * CELL, z0 + j * CELL),
                         (x0 + i2 * CELL, z0 + j2 * CELL), (x0 + i * CELL, z0 + j2 * CELL)]
                    mb.ground_poly(m01(names[m]), q, y=LOT_Y)
                    col.ground_poly(COL_KEY, q, y=LOT_Y)
                    rects += 1
                    i = i2
                else:
                    i += 1
    spec = {"name": "TOWN_Ground_Game", "children": [{"name": "TOWN_Ground_Game_Mesh", "mb": mb},
                                                      {"name": "TOWN_Ground_Game_Col-colonly", "mb": col}]}
    return spec, occ, rects


def scatter(L, occ, zones, lot_rects):
    rng = TL.rng_of("greyhaven_woods_game")
    x0, z0, x1, z1 = BOUNDS
    zr_all = [z["rect"] for z in zones] + lot_rects

    def blocked(x, z, m):
        i, j = int((x - x0) / CELL), int((z - z0) / CELL)
        r = int(m / CELL) + 1
        if i - r < 0 or j - r < 0 or i + r >= occ.shape[1] or j + r >= occ.shape[0]:
            return True
        if occ[j - r:j + r, i - r:i + r].any():
            return True
        return any(zr[0] - m <= x <= zr[2] + m and zr[1] - m <= z <= zr[3] + m for zr in zr_all)
    # only a band of woods along the roads is ever seen (evening haze); deeper forest is skipped to keep the
    # world light enough for a browser build. near[j, i] = within `band` m of a road / sidewalk / lot cell.
    ii = np.pad(occ.astype(np.int32).cumsum(0).cumsum(1), ((1, 0), (1, 0)))   # integral image

    def near(x, z, band):
        i, j = int((x - x0) / CELL), int((z - z0) / CELL)
        r = int(band / CELL)
        a0, a1 = max(0, j - r), min(occ.shape[0], j + r + 1)
        b0, b1 = max(0, i - r), min(occ.shape[1], i + r + 1)
        return ii[a1, b1] - ii[a0, b1] - ii[a1, b0] + ii[a0, b0] > 0
    n = 0
    for gz in np.arange(z0 + 4, z1 - 4, 8.0):
        for gx in np.arange(x0 + 4, x1 - 4, 8.0):
            x, z = gx + rng.uniform(-3, 3), gz + rng.uniform(-3, 3)
            if in_cores(np.array([x]), np.array([z]))[0] or not near(x, z, 55.0) or blocked(x, z, 3.5):
                continue
            roll = rng.random()
            mdl = ("VG_Tree_Pine" if roll < 0.5 else "VG_Tree_DeciduousSmall" if roll < 0.68 else
                   "VG_Tree_DeciduousLarge" if roll < 0.82 else "VG_Tree_Dead" if roll < 0.93 else "VG_Tree_Overgrown")
            L.place(mdl, "Vegetation", x, z, rng.random() * 6.28, tag="WOODS")
            n += 1
    under = ["VG_TallGrassClump", "VG_Weeds", "VG_DeadVegetation", "VG_RocksSmall", "VG_TreeStump", "VG_FallenBranch",
             "VG_FallenLeaves", "VG_DirtMound", "VG_MudPatch", "VG_TallGrassClump", "VG_Weeds"]
    for gz in np.arange(z0 + 2, z1 - 2, 6.0):
        for gx in np.arange(x0 + 2, x1 - 2, 6.0):
            if rng.random() > 0.3:
                continue
            x, z = gx + rng.uniform(-2.5, 2.5), gz + rng.uniform(-2.5, 2.5)
            if in_cores(np.array([x]), np.array([z]))[0] and rng.random() > 0.12:
                continue
            if not near(x, z, 25.0) or blocked(x, z, 1.2):
                continue
            L.place(under[int(rng.integers(0, len(under)))], "Vegetation", x, z, rng.random() * 6.28, tag="UNDERGROWTH")
    return n


# =============================================================================== houses
def solve_houses(zones, placements, assign):
    placement.ASSIGN = assign
    return placement.solve({"zones": zones, "placements": placements})


# =============================================================================== main
def main():
    os.makedirs(OUT, exist_ok=True)
    L = TL.Layout(MANIFEST)
    chain_end, d, r9pts = route9_chain(L)
    nodes, edges = ext_network(chain_end, d)
    TL.NODES, TL.EDGES, TL.RURAL = nodes, edges, []
    frames0 = {e[0]: TL.edge_frame(e[1], e[2]) for e in edges}
    lots = ext_lots(frames0)
    frames = TL.build_streets(L, lots)
    TL.build_lots(L, frames, lots)
    for lot in lots:
        lot["sideAB"] = TL.world_side(frames[lot["edge"]], lot["side"])
    ext_props(L, frames, lots, nodes, edges)
    route9_poles(L, r9pts)
    # the escape-route zone moves to the new end of Route 9
    n25 = nodes["N25"]
    TL.zone(L, "ESCAPE_ROUTE_EAST", "route_exit", (n25[0] - 6, n25[1] + 6, n25[0] + 6, n25[1] + 20), (0, -1),
            (n25[0], n25[1] + 6.5), "future", 0.0, note="Route 9 continues out of town (closed for now)")
    for it in L.items:
        it["rect"] = it.get("rect") or L.world_rect(it)
    ext_items = list(L.items)
    # ---- zones: core (old PLAYER_HOME becomes HOUSE_14, old escape zone dropped) + extension
    core_zones = []
    for z in LAYOUT["zones"]:
        z = dict(z)
        if z["id"] == "ESCAPE_ROUTE_EAST":
            continue
        if z["id"] == "PLAYER_HOME":
            z.update(id="HOUSE_14", hero=False, note="")
        core_zones.append(z)
    zones = core_zones + L.zones
    core_pl = []
    for p in LAYOUT["placements"]:
        p = dict(p)
        if p.get("tag") == "PLAYER_HOME":
            p["tag"] = "HOUSE_14"
        core_pl.append(p)
    # ---- terrain + woods for the whole (larger) map
    all_items = core_pl + ext_items
    ground, occ, nrects = terrain(all_items, zones)
    p = os.path.join(OUT, "TOWN_Ground_Game.glb")
    GLBWriter(p).write(ground)
    TL.LAYOUT_DIR = OUT
    lot_rects = [lot["rect"] for lot in lots] + [z["rect"] for z in core_zones if z["type"] == "residential_house"]
    n_trees = scatter(L, occ, zones, lot_rects)
    scat = [[it["model"], round(it["x"], 3), round(it["z"], 3), round(it["yaw"], 4)] for it in L.items
            if it.get("tag") in ("WOODS", "UNDERGROWTH")]
    L.items = [it for it in L.items if it.get("tag") not in ("WOODS", "UNDERGROWTH")]
    scat_models = {m: MODEL_PATH[m] for m in sorted({q[0] for q in scat})}
    with open(os.path.join(WORLD, "scatter.json"), "w", newline="\n") as f:
        json.dump({"models": scat_models, "items": scat, "y": LOT_Y}, f, separators=(",", ":"))
    write_core_tscn()
    # ---- houses: re-fit every lot (core assignment unchanged; HOUSE_14 = Ranch B; subdivision designs cycled)
    assign = dict(placement.ASSIGN)
    assign.pop("PLAYER_HOME")
    assign["HOUSE_14"] = ("Ranch", "B")
    k = 0
    for lot in lots:
        if lot["id"] == "PLAYER_HOME":
            assign["PLAYER_HOME"] = ("PlayerHome", None)
        else:
            assign[lot["id"]] = DESIGNS[k % len(DESIGNS)]
            k += 1
    avail = BR_variant_scenes()

    def usable(f):
        return f["ok"] and (f["key"] == "PlayerHome" or f["variant"] in avail)
    fits = solve_houses(zones, all_items, assign)
    for f in fits:
        f["ok"] = usable(f)
    bad = [f for f in fits if not f["ok"]]
    # a lot whose design does not fit gets the next design that does
    for f in bad:
        for alt in DESIGNS + [("Cottage", "B"), ("Bungalow", "B")]:
            a2 = {f["zone"]: alt}
            r = solve_houses(zones, all_items, a2)[0]
            if usable(r):
                fits = [x if x["zone"] != f["zone"] else r for x in fits]
                break
    bad = [f["zone"] for f in fits if not f["ok"]]
    assert not bad, f"houses that do not fit: {bad}"
    ph = [f for f in fits if f["zone"] == "PLAYER_HOME"][0]
    # the hero house is authored unmirrored and its sedan marker is lot-local: same mirror / shift as on Maple Ave
    old_lay = dict(LAYOUT)
    placement.ASSIGN = {"PLAYER_HOME": ("PlayerHome", None)}
    old_fit = placement.solve(old_lay)[0]
    assert not ph["mirror"] and not old_fit["mirror"], "hero house must stay unmirrored"
    assert abs(ph["shift"] - old_fit["shift"]) < 1e-6, (ph["shift"], old_fit["shift"])
    od, nd = old_fit["drive"], ph["drive"]
    assert max(abs(a - b) for a, b in zip(od, nd)) < 1e-3, ("driveway differs in the lot frame", od, nd)
    import build_residential as BR
    lc_spec, _ = BR.lot_connections(fits)
    lc_spec = {k_: v for k_, v in lc_spec.items() if k_ != "meta"}
    lc_spec["name"] = "RES_LotConnections_Game"
    lc_spec["children"][0]["name"] = "RES_LotConnections_Game_Mesh"
    GLBWriter(os.path.join(OUT, "RES_LotConnections_Game.glb")).write(lc_spec)
    for g in ("TOWN_Ground_Game", "RES_LotConnections_Game"):
        write_import(os.path.join(OUT, g + ".glb"))
    # ---- scenes
    write_extension_tscn(L, [])
    house_info = write_houses_tscn(fits)
    # ---- crack filler: any spot no surface covers (slivers where 30 m curve modules meet the 0.5 m ground grid)
    #      gets a ground cell; the coverage test is the same one game/tools/check_world.py runs
    import check_world as CW
    x0, z0, x1, z1 = BOUNDS
    W, H = int((x1 - x0) / CW.STEP), int((z1 - z0) / CW.STEP)
    cnt = np.zeros((H, W), np.int32)
    for scene in ("Greyhaven_Core.tscn", "Greyhaven_Extension.tscn"):
        for res, yaw, x, y, z, head in CW.placements_from_tscn(os.path.join(WORLD, scene)):
            if any(f'parent="{g}' in head or f'parent="Static/{g}' in head for g in ("Roads", "Sidewalks", "Lots", "Terrain")):
                T = CW.surface_tris(CW.res_to_path(res))
                if len(T):
                    CW.raster(cnt, x0, z0, CW.xf(T, yaw, x, y, z))
    js_, is_ = np.nonzero(cnt == 0)
    cells = sorted({(math.floor((x0 + (i + 0.5) * CW.STEP) / CELL), math.floor((z0 + (j + 0.5) * CW.STEP) / CELL))
                    for j, i in zip(js_, is_)})
    mb, col = ground["children"][0]["mb"], ground["children"][1]["mb"]
    for (ci, cj) in cells:
        q = [(ci * CELL, cj * CELL), ((ci + 1) * CELL, cj * CELL), ((ci + 1) * CELL, (cj + 1) * CELL), (ci * CELL, (cj + 1) * CELL)]
        mb.ground_poly(m01("Grnd_GrassOvergrown"), q, y=LOT_Y)
        col.ground_poly(COL_KEY, q, y=LOT_Y)
    if cells:
        GLBWriter(os.path.join(OUT, "TOWN_Ground_Game.glb")).write(ground)
        write_import(os.path.join(OUT, "TOWN_Ground_Game.glb"))
    print("crack filler cells:", cells)
    # ---- world data: spawn / sedan / destination / route
    fr = ph["frame"]
    ox, oz = placement.to_world(fr, ph["shift"], 0.0)
    route = build_route(nodes, r9pts, ph)
    data = dict(
        bounds=BOUNDS, player_home=dict(origin=[ox, LOT_Y, oz], yaw=fr["yaw"], zone=[z for z in zones if z["id"] == "PLAYER_HOME"][0]),
        nodes={k_: list(v[:2]) for k_, v in nodes.items()}, route=route["pts"], route_sections=route["sections"],
        route_length_m=route["length"], destination=dict(name="SUPERMARKET", parking_center=[31.0, 0.15, -16.0],
                                                           trigger_size=[30.0, 4.0, 14.0]),
        houses=house_info, trees=n_trees, scatter_items=len(scat), terrain_rects=nrects, ext_items=len(ext_items))
    with open(os.path.join(WORLD, "world_data.json"), "w", newline="\n") as f:
        json.dump(data, f, indent=1)
    print(f"extension items {len(ext_items)}, woods trees {n_trees}, terrain rects {nrects}, "
          f"scatter {len(scat)}, houses {len(fits)}, route {route['length']:.0f} m")


def write_core_tscn():
    """Game copy of the Pack 02 town scene: identical placements, minus the old ground, the old merged woods
    (both replaced for the extended map), the debug zone boxes / labels and the journey markers."""
    src = open(os.path.join(V2, "02_Town", "Godot_Scenes", "Greyhaven_Town.tscn")).read().split("\n\n")
    drop_ids, keep = set(), []
    import re
    drives = [p["rect"] for p in LAYOUT["placements"] if p["model"].startswith("RD_Driveway")]
    def in_drive(x, z, r):
        if r[2] - r[0] < r[3] - r[1]:      # narrow in x: driveway runs along z
            return r[0] + 0.05 < x < r[2] - 0.05 and r[1] - 0.6 < z < r[3] + 0.6
        return r[1] + 0.05 < z < r[3] - 0.05 and r[0] - 0.6 < x < r[2] + 0.6
    posts_in_drive = {p["name"] for p in LAYOUT["placements"] if p["model"].startswith("FN_Post")
                      and any(in_drive(p["x"], p["z"], r) for r in drives)}
    dropped_posts = 0
    for blk in src:
        head = blk.strip().split("\n")[0] if blk.strip() else ""
        nm = re.search(r'name="([^"]+)"', head)
        if head.startswith("[node") and nm and nm.group(1) in posts_in_drive:
            dropped_posts += 1
            continue
        if head.startswith("[node") and re.search(r'name="(TOWN_Ground|TOWN_Woods_[^"]*|TOWN_BuildingZones|BuildingZones|Journey)"', head):
            continue
        if head.startswith("[node") and re.search(r'parent="(BuildingZones|Journey)[^"]*"', head):
            continue
        keep.append(blk)
    txt = "\n\n".join(keep)
    used = set(re.findall(r'ExtResource\("([^"]+)"\)', txt))
    out = []
    for line in txt.split("\n"):
        m = re.match(r'\[ext_resource .* id="([^"]+)"\]', line)
        if m and m.group(1) not in used:
            continue
        out.append(line)
    txt = "\n".join(out)
    txt = re.sub(r"load_steps=\d+", f"load_steps={len(used) + 4}", txt, count=1)
    txt = txt.replace('[node name="Greyhaven_Town" type="Node3D"]', '[node name="Greyhaven_Core" type="Node3D"]\n'
                      'metadata/note = "Game copy of 02_Town/Godot_Scenes/Greyhaven_Town.tscn (same placements) without the '
                      'old ground / woods / zone markers - regenerated by game/tools/build_world.py"', 1)
    with open(os.path.join(WORLD, "Greyhaven_Core.tscn"), "w", newline="\n") as f:
        f.write(txt)
    print("core copy: fence posts removed from driveways:", dropped_posts)


def write_import(glb):
    from veil_mesh.gltf import write_glb_import
    # the generated GLBs carry only Pack 01 / Pack 02 materials; map them to the shared .tres like Pack 02 does
    js = json.loads(open(glb, "rb").read()[20:20 + int.from_bytes(open(glb, "rb").read()[12:16], "little")])
    used = [m["name"] for m in js.get("materials", [])]
    write_glb_import(glb, used)
    txt = open(glb + ".import").read()
    rel = "res://" + os.path.relpath(glb, REPO).replace(os.sep, "/")
    import hashlib
    import re
    md5 = hashlib.md5(rel.encode()).hexdigest()
    txt = re.sub(r'source_file="[^"]+"', f'source_file="{rel}"', txt)
    txt = re.sub(r'res://\.godot/imported/[^"]+\.scn', f"res://.godot/imported/{os.path.basename(glb)}-{md5}.scn", txt)
    open(glb + ".import", "w", newline="\n").write(txt)


def write_extension_tscn(L, woods):
    used = sorted({it["model"] for it in L.items})
    ids = {m: f"{i + 1}_{m[:24]}" for i, m in enumerate(used)}
    ext = [f'[ext_resource type="PackedScene" path="{MODEL_PATH[m]}" id="{ids[m]}"]' for m in used]
    gid = len(used) + 1
    ext.append(f'[ext_resource type="PackedScene" path="{RES_GAME}/TOWN_Ground_Game.glb" id="{gid}_ground"]')
    for i, w in enumerate(woods):
        ext.append(f'[ext_resource type="PackedScene" path="{RES_GAME}/{w}.glb" id="{gid + 1 + i}_{w}"]')
    lines = [f"[gd_scene load_steps={len(ext) + 1} format=3]", ""] + ext + ["",
             '[node name="Greyhaven_Extension" type="Node3D"]',
             'metadata/note = "Generated by game/tools/build_world.py: Route 9 county road, Harlow Ln / Aspen Ct / Fern Ct, '
             'regenerated ground + woods for the whole map"', ""]
    for g in ("Terrain", "Roads", "Sidewalks", "Lots", "Markings", "StreetProps", "Utilities", "Vegetation", "Woods",
              "Fences", "Interactive", "Lights"):
        lines += [f'[node name="{g}" type="Node3D" parent="."]', ""]
    lines += [f'[node name="TOWN_Ground_Game" parent="Terrain" instance=ExtResource("{gid}_ground")]', ""]
    for i, w in enumerate(woods):
        lines += [f'[node name="{w}" parent="Woods" instance=ExtResource("{gid + 1 + i}_{w}")]', ""]
    par = {"Roads": "Roads", "Sidewalks": "Sidewalks", "Lots": "Lots", "Markings": "Markings", "StreetProps": "StreetProps",
           "Utilities": "Utilities", "Vegetation": "Vegetation", "Fences": "Fences", "Interactive": "Interactive"}
    for it in L.items:
        lines.append(f'[node name="{it["name"]}" parent="{par[it["group"]]}" instance=ExtResource("{ids[it["model"]]}")]')
        lines.append("transform = " + xform(it["yaw"], it["x"], it["y"], it["z"]))
        if it.get("tag"):
            lines.append(f'metadata/tag = "{it["tag"]}"')
        lines.append("")
    n = 0
    for it in L.lights:
        lp = L.man[it["model"]].get("light")
        if not lp or not (it.get("tag", "").startswith(("HARLOW", "FERN", "ROUTE_9X"))):
            continue
        n += 1
        lx, lz = TL.rot(it["yaw"], lp[0], lp[2])
        lines += [f'[node name="StreetLight_{n:02d}" type="OmniLight3D" parent="Lights"]',
                  "transform = " + xform(0, it["x"] + lx, it["y"] + lp[1] - 0.3, it["z"] + lz),
                  "light_color = Color(1, 0.8, 0.55, 1)", "light_energy = 1.2", "omni_range = 11.0",
                  "omni_attenuation = 1.4", "distance_fade_enabled = true", "distance_fade_begin = 45.0",
                  "distance_fade_length = 15.0", ""]
    with open(os.path.join(WORLD, "Greyhaven_Extension.tscn"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def write_houses_tscn(fits):
    import build_residential as BR
    info = BR_variant_scenes()
    ext, ids = [], {}
    ph_scene = RES_V2 + "/03_Residential/Player_Home/Player_Home.tscn"
    for r in fits:
        sc = ph_scene if r["key"] == "PlayerHome" else info[r["variant"]]
        if sc not in ids:
            ids[sc] = f"{len(ids) + 1}_{os.path.basename(sc)[:-5][:26]}"
            ext.append(f'[ext_resource type="PackedScene" path="{sc}" id="{ids[sc]}"]')
    ext.append(f'[ext_resource type="PackedScene" path="{RES_GAME}/RES_LotConnections_Game.glb" id="{len(ids) + 1}_lots"]')
    lines = [f"[gd_scene load_steps={len(ext) + 1} format=3]", ""] + ext + ["",
             '[node name="Greyhaven_Houses" type="Node3D"]',
             'metadata/note = "Generated by game/tools/build_world.py: every Pack 03 house re-fitted on the extended map"', "",
             f'[node name="LotConnections" parent="." instance=ExtResource("{len(ids) + 1}_lots")]', "",
             '[node name="Houses" type="Node3D" parent="."]', ""]
    out = []
    for r in fits:
        fr = r["frame"]
        ox, oz = placement.to_world(fr, r["shift"], 0.0)
        sc = ph_scene if r["key"] == "PlayerHome" else info[r["variant"]]
        lines += [f'[node name="{r["zone"]}" parent="Houses" instance=ExtResource("{ids[sc]}")]',
                  "transform = " + xform(fr["yaw"], ox, LOT_Y, oz), f'metadata/zone_id = "{r["zone"]}"',
                  f'metadata/variant = "{r["variant"]}"', ""]
        out.append(dict(zone=r["zone"], variant=r["variant"], origin=[round(ox, 3), LOT_Y, round(oz, 3)], yaw=round(fr["yaw"], 6)))
    with open(os.path.join(WORLD, "Greyhaven_Houses.tscn"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return out


def BR_variant_scenes():
    d = os.path.join(V2, "03_Residential", "House_Variants")
    return {f[:-5]: RES_V2 + "/03_Residential/House_Variants/" + f for f in os.listdir(d) if f.endswith(".tscn")}


def build_route(nodes, r9pts, ph):
    """Driving route (road centrelines) from the home driveway to the supermarket
    parking lot, as a dense polyline with named sections."""
    fr = ph["frame"]
    drive = ph["drive"]
    dcx = (drive[0] + drive[2]) / 2
    start = placement.to_world(fr, dcx, drive[1] + 4.0)            # sedan on the driveway (lot frame)
    mouth = placement.to_world(fr, dcx, drive[1] - 0.5)
    n21, n20 = nodes["N21"], nodes["N20"]
    centre = [start, mouth,
              (n21[0], mouth[1]), (n21[0], n21[1]),                 # Fern Ct north to the corner
              (n20[0], n20[1])]                                     # Harlow Ln east to Route 9
    centre += list(reversed(r9pts))                                  # Route 9 north / west back to town
    centre += [(184.0, 34.0), (184.0, 24.0)]                         # Pack 02 Route 9 pieces
    centre += [(160 + 24 * math.sin(math.radians(a)), 24 - 24 * math.cos(math.radians(a))) for a in range(90, -1, -15)]
    centre += [(150.0, 0.0), (130.0, 0.0), (124.0, 0.0), (62.0, 0.0), (31.0, 0.0), (31.0, -8.0), (31.0, -16.0)]
    # dedupe + densify
    pts = [centre[0]]
    for p in centre[1:]:
        if math.dist(p, pts[-1]) > 0.5:
            pts.append(p)
    length = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
    sections = {"A_residential": [start, (n20[0], n20[1])], "C_county_road": [(n20[0], n20[1]), (184.0, 24.0)],
                "B_transition": [(184.0, 24.0), (124.0, 0.0)], "D_commercial": [(124.0, 0.0), (31.0, 0.0)],
                "E_destination": [(31.0, 0.0), (31.0, -16.0)]}
    return dict(pts=[[round(a, 3), round(b, 3)] for a, b in pts], length=round(length, 2),
                sections={k: [[round(v, 2) for v in p] for p in s] for k, s in sections.items()})


if __name__ == "__main__":
    main()
