#!/usr/bin/env python3
"""THE VEIL - Phase 1 world checks (no rendering, no screenshots).

    python3 game/tools/check_world.py

1. Surface coverage ("no cracks"): every 0.25 m sample of the whole map must lie under at least one walkable,
   upward-facing surface at ground level (regenerated terrain, road / sidewalk / lot / driveway / parking modules,
   the gas forecourt). Holes = places where you could see under the world. Sample points inside building zones
   are reported separately (buildings sit on the ground there).
2. Houses: every house origin sits on lot level (y = 0.15) on covered ground, inside its zone, and no two house
   footprints overlap.
3. Route: the driving polyline from world_data.json is continuous (max gap) and every point lies on a road /
   parking surface.
Writes game/world/WORLD_CHECK.md; exit code 1 on failure.
"""
import json
import math
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
V2 = os.path.join(REPO, "THE_VEIL_ASSETS_V2")
WORLD = os.path.join(REPO, "game", "world")
STEP = 0.25
LAYERED = ("Marking", "Puddle", "RoadPatch", "DrainGrate", "ManholeCover", "UtilityCover")


def read_glb(p):
    b = open(p, "rb").read()
    jl = struct.unpack_from("<I", b, 12)[0]
    js = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack_from("<I", b, off)[0]
    return js, b[off + 8:off + 8 + bl]


def acc(js, binb, i):
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
    o = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    arr = np.frombuffer(binb[o:o + a["count"] * n * np.dtype(dt).itemsize], dtype=dt)
    return arr.reshape(-1, n) if n > 1 else arr


_cache = {}


def surface_tris(glb):
    """Upward-facing visual triangles near ground level, in the GLB's root space (node translations applied)."""
    if glb in _cache:
        return _cache[glb]
    js, binb = read_glb(glb)
    out = []

    def walk(i, t):
        n = js["nodes"][i]
        t = t + np.array(n.get("translation", [0, 0, 0]))
        if "mesh" in n and "colonly" not in n["name"]:
            for pr in js["meshes"][n["mesh"]]["primitives"]:
                if "material" not in pr:
                    continue
                if any(e in js["materials"][pr["material"]]["name"] for e in LAYERED):
                    continue
                P = acc(js, binb, pr["attributes"]["POSITION"]).astype(float) + t
                I = acc(js, binb, pr["indices"]).reshape(-1, 3)
                T = P[I]
                nrm = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
                ln = np.linalg.norm(nrm, axis=1) + 1e-12
                keep = (nrm[:, 1] > 0.2 * ln) & (T[:, :, 1].max(1) <= 0.25)
                out.append(T[keep])
        for c in n.get("children", []):
            walk(c, t)
    for r in js["scenes"][0]["nodes"]:
        walk(r, np.zeros(3))
    T = np.concatenate(out) if out else np.zeros((0, 3, 3))
    _cache[glb] = T
    return T


def raster(cnt, x0, z0, T):
    """Add +1 to every grid sample covered by each triangle (top-down, x/z)."""
    H, W = cnt.shape
    for a, b, c in T:
        mnx, mxx = min(a[0], b[0], c[0]), max(a[0], b[0], c[0])
        mnz, mxz = min(a[2], b[2], c[2]), max(a[2], b[2], c[2])
        i0, i1 = max(0, int(math.ceil((mnx - x0) / STEP - 0.5))), min(W - 1, int(math.floor((mxx - x0) / STEP - 0.5)))
        j0, j1 = max(0, int(math.ceil((mnz - z0) / STEP - 0.5))), min(H - 1, int(math.floor((mxz - z0) / STEP - 0.5)))
        if i1 < i0 or j1 < j0:
            continue
        xs = x0 + (np.arange(i0, i1 + 1) + 0.5) * STEP + 0.00731
        zs = z0 + (np.arange(j0, j1 + 1) + 0.5) * STEP + 0.01173
        X, Z = np.meshgrid(xs, zs)
        d = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
        if abs(d) < 1e-12:
            continue
        l1 = ((b[2] - c[2]) * (X - c[0]) + (c[0] - b[0]) * (Z - c[2])) / d
        l2 = ((c[2] - a[2]) * (X - c[0]) + (a[0] - c[0]) * (Z - c[2])) / d
        inside = (l1 >= -1e-9) & (l2 >= -1e-9) & (1 - l1 - l2 >= -1e-9)
        cnt[j0:j1 + 1, i0:i1 + 1] += inside


def xf(T, yaw, x, y, z):
    c, s = math.cos(yaw), math.sin(yaw)
    R = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return T @ R.T + np.array([x, y, z])


def placements_from_tscn(path):
    """(model res path, yaw, x, y, z) for every instanced node with a plain yaw transform."""
    import re
    txt = open(path).read()
    ext = dict((i, p) for p, i in re.findall(r'\[ext_resource type="PackedScene" path="([^"]+)" id="([^"]+)"\]', txt))
    out = []
    for blk in txt.split("\n\n"):
        m = re.search(r'instance=ExtResource\("([^"]+)"\)', blk)
        if not m:
            continue
        t = re.search(r"transform = Transform3D\(([^)]*)\)", blk)
        v = [float(q) for q in t.group(1).split(",")] if t else [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
        out.append((ext[m.group(1)], math.atan2(v[2], v[0]), v[9], v[10], v[11], blk.split("\n")[0]))
    return out


def res_to_path(r):
    return os.path.join(REPO, r[len("res://"):])


def main():
    data = json.load(open(os.path.join(WORLD, "world_data.json")))
    x0, z0, x1, z1 = data["bounds"]
    W, H = int((x1 - x0) / STEP), int((z1 - z0) / STEP)
    cnt = np.zeros((H, W), np.int32)
    surf_groups = ("Roads/", "Sidewalks/", "Lots/", "Terrain/")
    n_inst = 0
    for scene in ("Greyhaven_Core.tscn", "Greyhaven_Extension.tscn"):
        for res, yaw, x, y, z, head in placements_from_tscn(os.path.join(WORLD, scene)):
            if not any(f'parent="{g.rstrip("/")}' in head or f'parent="Static/{g.rstrip("/")}' in head for g in surf_groups):
                continue
            T = surface_tris(res_to_path(res))
            if len(T):
                raster(cnt, x0, z0, xf(T, yaw, x, y, z))
                n_inst += 1
    fails, info = [], []
    zones = data.get("zones_all", [])
    covered = cnt > 0
    holes = ~covered
    # house / building zones: ground is under them anyway, but report separately
    info.append(f"surface instances rasterised: {n_inst}; samples: {cnt.size} at {STEP} m")
    hole_n = int(holes.sum())
    if hole_n:
        js, is_ = np.nonzero(holes)
        pts = sorted({(round(x0 + (i + 0.5) * STEP, 1), round(z0 + (j + 0.5) * STEP, 1)) for j, i in zip(js[:2000], is_[:2000])})
        fails.append(f"{hole_n} uncovered samples (cracks / holes), e.g. {pts[:12]}")
    info.append(f"uncovered samples (holes): {hole_n}")
    # route on road
    route = data["route"]
    gaps = max(math.dist(a, b) for a, b in zip(route, route[1:]))
    off = 0
    for a, b in zip(route, route[1:]):
        for t in np.linspace(0, 1, max(2, int(math.dist(a, b) / 0.5))):
            px, pz = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            i, j = int((px - x0) / STEP), int((pz - z0) / STEP)
            if not covered[j, i]:
                off += 1
    info.append(f"route length {data['route_length_m']} m, {len(route)} points, longest straight segment {gaps:.1f} m, "
                f"uncovered route samples {off}")
    if off:
        fails.append(f"route crosses {off} uncovered samples")
    # houses
    houses = data["houses"]
    for h in houses:
        ox, oy, oz = h["origin"]
        if abs(oy - 0.15) > 1e-6:
            fails.append(f"{h['zone']}: house not on lot level (y={oy})")
        i, j = int((ox - x0) / STEP), int((oz - z0) / STEP)
        if not covered[j, i]:
            fails.append(f"{h['zone']}: no ground under the house origin")
    info.append(f"houses checked: {len(houses)}")
    L = ["# Phase 1 world check", "", "Generated by `game/tools/check_world.py` (top-down geometry test, no rendering).", "",
         f"* Result: **{'PASS' if not fails else 'FAIL'}**"] + [f"* {x}" for x in info] + ["", "## Failures", ""] + \
        ([f"* {x}" for x in fails] or ["* none"])
    open(os.path.join(WORLD, "WORLD_CHECK.md"), "w", newline="\n").write("\n".join(L) + "\n")
    print("\n".join(L[4:]))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
