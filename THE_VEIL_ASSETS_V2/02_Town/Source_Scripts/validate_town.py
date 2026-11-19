#!/usr/bin/env python3
"""THE VEIL - Pack 02 automated validation (no rendering, no screenshots).

    python3 02_Town/Source_Scripts/validate_town.py [--gltf-validator DIR] [--godot BIN]

Checks
  files      every model has GLB + .import + OBJ/MTL; layout GLBs + scene exist
  glb        own structural parse: chunks, accessors, index ranges, UVs present,
             unit normals that agree with triangle winding, no degenerate tris
  khronos    official Khronos glTF-Validator (if --gltf-validator given)
  materials  every GLB material maps to an existing .tres whose texture exists
  grid       road/sidewalk ports on the snap grid; 5 cm top-down coverage test
             (0 holes, 0 overlapping surfaces) for every surface module
  collision  surface modules have trimesh collision; props declare hulls
  network    rebuilds the drivable graph from placements: every port joined
             or a declared terminus; one connected road network; required
             opening-sequence routes exist; zones reachable
  scene      tscn resources exist, node names unique
  godot      (if --godot given) headless import + scene instancing + physics
             raycasts along the opening route and across curbs
Writes 02_Town/Documentation/VALIDATION_REPORT.md; exit code 1 on failure.
"""
import argparse
import heapq
import json
import math
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "Source_Scripts"))

import numpy as np  # noqa: E402

from veil_mesh.materials import V2, TOWN, MATS, mt, m01, all_town_materials  # noqa: E402

fails, warns, info = [], [], []


def F(m):
    fails.append(m)


def W(m):
    warns.append(m)


# ----------------------------------------------------------------------------
def read_glb(path):
    b = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<III", b, 0)
    if magic != 0x46546C67 or ver != 2 or length != len(b):
        raise ValueError("bad GLB header")
    jl, jt = struct.unpack_from("<II", b, 12)
    js = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl, bt = struct.unpack_from("<II", b, off)
    if jt != 0x4E4F534A or bt != 0x004E4942:
        raise ValueError("bad chunk types")
    return js, b[off + 8:off + 8 + bl]


COMP = {5126: ("f", 4), 5123: ("H", 2), 5125: ("I", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}


def accessor(js, binb, i):
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    end = off + a["count"] * n * size
    if end > len(binb) or end > v.get("byteOffset", 0) + v["byteLength"]:
        raise ValueError("accessor out of range")
    arr = np.frombuffer(binb[off:end], dtype={"f": np.float32, "H": np.uint16, "I": np.uint32}[fmt])
    return arr.reshape(-1, n) if n > 1 else arr


def check_glb(path, expect_uv=True):
    js, binb = read_glb(path)
    stats = dict(tris=0, prims=0, col_prims=0, mats=[m["name"] for m in js.get("materials", [])])
    for mesh in js.get("meshes", []):
        for p in mesh["primitives"]:
            stats["prims"] += 1
            at = p["attributes"]
            P = accessor(js, binb, at["POSITION"])
            I = accessor(js, binb, p["indices"])
            if I.max() >= len(P):
                F(f"{os.path.basename(path)}: index out of range")
            acc = js["accessors"][at["POSITION"]]
            if not (np.allclose(P.min(0), acc["min"], atol=1e-4) and np.allclose(P.max(0), acc["max"], atol=1e-4)):
                F(f"{os.path.basename(path)}: POSITION min/max wrong")
            if "material" not in p:
                stats["col_prims"] += 1
                continue
            if "TEXCOORD_0" not in at:
                F(f"{os.path.basename(path)}: visual primitive without UVs")
            else:
                UV = accessor(js, binb, at["TEXCOORD_0"])
                if not np.isfinite(UV).all():
                    F(f"{os.path.basename(path)}: non-finite UVs")
            if "NORMAL" not in at:
                F(f"{os.path.basename(path)}: no normals")
                continue
            N = accessor(js, binb, at["NORMAL"])
            ln = np.linalg.norm(N, axis=1)
            if np.abs(ln - 1).max() > 1e-3:
                F(f"{os.path.basename(path)}: normals not unit length")
            T = I.reshape(-1, 3)
            a, b, c = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
            fn = np.cross(b - a, c - a)
            area = np.linalg.norm(fn, axis=1)
            if (area < 1e-10).any():
                F(f"{os.path.basename(path)}: {(area < 1e-10).sum()} degenerate triangles")
            vn = N[T[:, 0]] + N[T[:, 1]] + N[T[:, 2]]
            agree = (np.einsum("ij,ij->i", fn, vn) > 0).mean()
            if agree < 0.999:
                F(f"{os.path.basename(path)}: {100 * (1 - agree):.1f}% triangles wound against their normals")
            stats["tris"] += len(T)
    return js, stats


# ----------------------------------------------------------------------------
def tres_texture(tres_path):
    t = open(tres_path).read()
    return re.findall(r'path="res://THE_VEIL_ASSETS_V2/([^"]+)"', t)


def check_materials(js, glb):
    imp = open(glb + ".import").read()
    for m in js.get("materials", []):
        name = m["name"]
        try:  # resolve through the same registry the builder uses
            mt(name[7:]) if name.startswith("M_Town_") else m01(name[2:])
        except KeyError:
            pass
        if name not in MATS:
            F(f"{os.path.basename(glb)}: unknown material {name}")
            continue
        tres = os.path.join(V2, MATS[name]["tres"])
        if not os.path.exists(tres):
            F(f"{os.path.basename(glb)}: missing .tres {MATS[name]['tres']}")
            continue
        for rel in tres_texture(tres):
            if not os.path.exists(os.path.join(V2, rel)):
                F(f"{MATS[name]['tres']}: texture missing {rel}")
        if f'"{name}"' not in imp or MATS[name]["tres"] not in imp:
            F(f"{os.path.basename(glb)}.import does not map {name} to its .tres")
        for img in js.get("images", []):
            if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(glb), img["uri"]))):
                F(f"{os.path.basename(glb)}: image uri does not resolve: {img['uri']}")


# ----------------------------------------------------------------------------
def R2(yaw, x, z):
    c, s = math.cos(yaw), math.sin(yaw)
    return (c * x + s * z, -s * x + c * z)


ROADNET = {"RD_Straight_2Lane_10m", "RD_Straight_2Lane_10m_Cracked", "RD_Straight_2Lane_10m_Patched",
           "RD_Straight_2Lane_10m_Unmarked", "RD_Intersection_4Way_12m", "RD_Intersection_T_12m",
           "RD_Curve_Gentle_Left_30m", "RD_Curve_Gentle_Right_30m", "RD_Corner_Sharp_12m", "RD_DeadEnd_12m",
           "RD_Street_Residential_10m", "RD_Street_Commercial_10m", "RD_Shoulder_Rural_10m",
           "RD_Transition_UrbanToRural_10m"}
RURAL_EDGE = {"RD_Shoulder_Rural_10m", "RD_Curve_Gentle_Left_30m", "RD_Curve_Gentle_Right_30m",
              "RD_Transition_UrbanToRural_10m"}
LOTS = {"RD_Driveway_3x8m", "RD_ParkingLot_10x20m", "RD_Alley_4x10m", "TOWN_GasForecourt"}


def network(layout, man):
    P = layout["placements"]
    by_name = {p["name"]: p for p in P}
    adj = {p["name"]: set() for p in P}

    def link(a, b, why):
        adj[a].add((b, why))
        adj[b].add((a, why))

    def rect(p):
        return p.get("rect")

    def inside(r, x, z, tol=0.0):
        return r is not None and r[0] - tol <= x <= r[2] + tol and r[1] - tol <= z <= r[3] + tol

    # 1. ports
    ports = []
    for p in P:
        if p["model"] not in ROADNET:
            continue
        for (pos, d) in man[p["model"]]["ports"]:
            wx, wz = R2(p["yaw"], pos[0], pos[2])
            dx, dz = R2(p["yaw"], d[0], d[2])
            ports.append((p["name"], round(p["x"] + wx, 3), round(p["z"] + wz, 3), dx, dz))
    matched = [False] * len(ports)
    bykey = {}
    for i, pt in enumerate(ports):
        bykey.setdefault((round(pt[1], 1), round(pt[2], 1)), []).append(i)
    for key, idx in bykey.items():
        for i in idx:
            for j in idx:
                if i < j:
                    a, b = ports[i], ports[j]
                    if abs(a[1] - b[1]) < 0.01 and abs(a[2] - b[2]) < 0.01 and a[3] * b[3] + a[4] * b[4] < -0.99:
                        link(a[0], b[0], "port")
                        matched[i] = matched[j] = True
    open_ports = [ports[i] for i in range(len(ports)) if not matched[i]]
    # 2. lots: entry edge = local z=0 edge
    sidewalk_dt = [p for p in P if p["model"] == "SW_DrivewayTransition_10m"]
    roads = [p for p in P if p["model"] in ROADNET]
    for p in P:
        if p["model"] not in LOTS or p["model"] == "TOWN_GasForecourt":
            continue
        ex, ez = p["x"], p["z"]                     # entry centre (local origin)
        out = R2(p["yaw"], 0, -1)                   # direction back toward the street
        hit = None
        for s in sidewalk_dt:                       # urban: through a dropped-curb apron
            ax, az = R2(s["yaw"], 2.25, 5.0)
            if abs(s["x"] + ax - ex) < 0.6 and abs(s["z"] + az - ez) < 0.6:
                rx, rz = R2(s["yaw"], -0.6, 5.0)
                for r in roads:
                    if inside(rect(r), s["x"] + rx, s["z"] + rz):
                        hit = (r["name"], "driveway apron")
        if hit is None:                             # rural: straight off the shoulder
            for r in roads:
                if r["model"] in RURAL_EDGE and inside(rect(r), ex + out[0] * 0.3, ez + out[1] * 0.3):
                    hit = (r["name"], "rural shoulder")
        if hit is None:                             # lot behind another lot (parking rows, alley chain)
            for q in P:
                if q is not p and q["model"] in LOTS and inside(rect(q), ex + out[0] * 0.3, ez + out[1] * 0.3):
                    hit = (q["name"], "lot-to-lot")
        if hit:
            link(p["name"], hit[0], hit[1])
    # parking-lot rows and alley pieces join side by side / end to end
    lots = [p for p in P if p["model"] in LOTS]
    for i, a in enumerate(lots):
        for b in lots[i + 1:]:
            ra, rb = rect(a), rect(b)
            ox = min(ra[2], rb[2]) - max(ra[0], rb[0])
            oz = min(ra[3], rb[3]) - max(ra[1], rb[1])
            if (abs(ox) < 0.01 and oz > 2.0) or (abs(oz) < 0.01 and ox > 2.0):
                link(a["name"], b["name"], "lot-adjacent")
    # forecourt: vehicle entrances wherever it shares >= 4 m of edge with a rural road
    for f in [p for p in P if p["model"] == "TOWN_GasForecourt"]:
        rf = rect(f)
        for r in roads:
            if r["model"] not in RURAL_EDGE:
                continue
            rr = rect(r)
            ox = min(rf[2], rr[2]) - max(rf[0], rr[0])
            oz = min(rf[3], rr[3]) - max(rf[1], rr[1])
            if (abs(ox) < 0.01 and oz >= 4) or (abs(oz) < 0.01 and ox >= 4):
                link(f["name"], r["name"], "forecourt entrance")
    # 3. zones
    zone_v = {}
    for z in layout["zones"]:
        ax, az = z["access"]
        best = None
        for p in P:
            if p["model"] in LOTS or p["model"] in ROADNET:
                if inside(rect(p), ax, az, 0.75):
                    best = p["name"]
                    if p["model"] in LOTS:
                        break
        if best is None:                            # pedestrian frontage: sidewalk -> its road
            for s in P:
                if s["model"].startswith("SW_") and inside(rect(s), ax, az, 0.75):
                    rx, rz = R2(s["yaw"], -0.6, 1.0)
                    for r in roads:
                        if inside(rect(r), s["x"] + rx, s["z"] + rz):
                            best = r["name"]
        zone_v[z["id"]] = best
        if best is None:
            F(f"zone {z['id']}: access point {z['access']} is not on any road, sidewalk or lot")
        else:
            adj.setdefault("ZONE:" + z["id"], set())
            link("ZONE:" + z["id"], best, "zone access")

    def dijkstra(src):
        def c(n):
            if n.startswith("ZONE:"):
                zz = [z for z in layout["zones"] if z["id"] == n[5:]][0]
                return zz["access"]
            r = by_name[n].get("rect")
            return ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2) if r else (by_name[n]["x"], by_name[n]["z"])
        dist = {src: 0.0}
        prev = {}
        pq = [(0.0, src)]
        while pq:
            d, u = heapq.heappop(pq)
            if d > dist.get(u, 1e18):
                continue
            for v, why in adj.get(u, ()):
                a, b = c(u), c(v)
                nd = d + math.hypot(a[0] - b[0], a[1] - b[1])
                if nd < dist.get(v, 1e18):
                    dist[v] = nd
                    prev[v] = u
                    heapq.heappush(pq, (nd, v))
        return dist, prev
    return adj, open_ports, zone_v, dijkstra


def components(adj, nodes):
    seen, comps = set(), []
    for n in nodes:
        if n in seen:
            continue
        stack, comp = [n], set()
        while stack:
            u = stack.pop()
            if u in seen:
                continue
            seen.add(u)
            comp.add(u)
            stack += [v for v, _ in adj[u] if v in nodes]
        comps.append(comp)
    return comps


# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator", default=None, help="dir containing node_modules/gltf-validator")
    ap.add_argument("--godot", default=None, help="Godot 4 binary for the headless import/physics check")
    ap.add_argument("--godot-project", default=None, help="scratch project dir (THE_VEIL_ASSETS_V2 is copied in)")
    args = ap.parse_args()
    manifest = json.load(open(os.path.join(TOWN, "Documentation", "MODEL_MANIFEST.json")))
    models = manifest["models"]
    man = {m["name"]: m for m in models}
    layout = json.load(open(os.path.join(TOWN, "Town_Layout", "greyhaven_layout.json")))
    man["TOWN_GasForecourt"] = {"name": "TOWN_GasForecourt"}

    # ---- files + glb + materials ------------------------------------------------
    lay_dir = os.path.join(TOWN, "Town_Layout")
    glbs = [os.path.join(V2, m["glb"]) for m in models] + \
        sorted(os.path.join(lay_dir, f) for f in os.listdir(lay_dir) if f.endswith(".glb"))
    for mc in layout.get("merged_scatter", []):
        if not os.path.exists(os.path.join(lay_dir, mc["name"] + ".glb")):
            F(f"missing woods chunk {mc['name']}.glb")
    total_tris = 0
    tri_of = {}
    for g in glbs:
        if not os.path.exists(g):
            F(f"missing {os.path.relpath(g, V2)}")
            continue
        if not os.path.exists(g + ".import"):
            F(f"missing import file for {os.path.basename(g)}")
        try:
            js, st = check_glb(g)
            check_materials(js, g)
            tri_of[os.path.basename(g)[:-4]] = st["tris"]
        except Exception as e:  # noqa: BLE001
            F(f"{os.path.basename(g)}: unreadable GLB ({e})")
    for m in models:
        obj = os.path.join(V2, m["obj"])
        if not os.path.exists(obj) or not os.path.exists(obj[:-4] + ".mtl"):
            F(f"{m['name']}: OBJ/MTL missing")
    for t in all_town_materials():
        if not os.path.exists(os.path.join(V2, MATS[t]["tres"])):
            F(f"Pack 02 material missing: {MATS[t]['tres']}")
    info.append(f"GLB files parsed: {len(tri_of)}")
    # level check: terrain + forecourt must sit exactly on the 0.15 m lot level
    for lvl_glb in ("TOWN_Ground.glb", "TOWN_GasForecourt.glb"):
        js, binb = read_glb(os.path.join(TOWN, "Town_Layout", lvl_glb))
        for mesh in js["meshes"]:
            for p in mesh["primitives"]:
                if "material" in p and "Marking" in js["materials"][p["material"]]["name"]:
                    continue  # road paint is layered 6 mm above on purpose
                Pp = accessor(js, binb, p["attributes"]["POSITION"])
                ground = Pp[:, 1] < 0.2
                if ground.any() and np.abs(Pp[ground, 1] - 0.15).max() > 1e-4:
                    F(f"{lvl_glb}/{mesh['name']}: ground surface not at lot level 0.15 m "
                      f"(found y {Pp[ground, 1].min():.3f}..{Pp[ground, 1].max():.3f})")

    # ---- Khronos validator ---------------------------------------------------------
    if args.gltf_validator:
        js_code = r"""
const v=require('gltf-validator'),fs=require('fs'),path=require('path');
const files=JSON.parse(fs.readFileSync(0,'utf8'));
(async()=>{const out={};for(const f of files){const r=await v.validateBytes(new Uint8Array(fs.readFileSync(f)),
{externalResourceFunction:(u)=>Promise.resolve(new Uint8Array(fs.readFileSync(path.resolve(path.dirname(f),decodeURIComponent(u)))))});
out[f]={e:r.issues.numErrors,w:r.issues.numWarnings,msgs:r.issues.messages.filter(m=>m.severity<=1).slice(0,3).map(m=>m.code+' '+m.pointer)};}
console.log(JSON.stringify(out));})();"""
        res = subprocess.run(["node", "-e", js_code], input=json.dumps(glbs), capture_output=True, text=True,
                             cwd=args.gltf_validator, timeout=600)
        try:
            out = json.loads(res.stdout)
            ne = sum(v["e"] for v in out.values())
            nw = sum(v["w"] for v in out.values())
            info.append(f"Khronos glTF-Validator: {len(out)} files, {ne} errors, {nw} warnings")
            for f, v in out.items():
                if v["e"]:
                    F(f"Khronos: {os.path.basename(f)}: {v['e']} errors {v['msgs']}")
                elif v["w"]:
                    W(f"Khronos: {os.path.basename(f)}: {v['w']} warnings {v['msgs']}")
        except Exception:  # noqa: BLE001
            F("Khronos validator did not run: " + res.stderr[-400:])
    else:
        W("Khronos glTF-Validator not run (pass --gltf-validator)")

    # ---- grid + coverage + collision -------------------------------------------------
    import models_roads
    from veil_mesh.coverage import coverage
    n_cov = 0
    for cat, fn in models_roads.ROAD_MODELS:
        spec = fn()
        meta = spec["meta"]
        names = [c["name"] for c in spec["children"]]
        if meta["kind"] in ("segment", "node", "curve", "lot", "sidewalk"):
            if not any("colonly" in n for n in names):
                F(f"{spec['name']}: walkable module without collision")
        for (pos, d) in meta.get("ports", []):
            if any(abs(v * 4 - round(v * 4)) > 1e-6 for v in (pos[0], pos[2])):
                F(f"{spec['name']}: port {pos} off the 0.25 m snap grid")
            if abs(abs(d[0]) + abs(d[2]) - 1) > 1e-6:
                F(f"{spec['name']}: port direction not axis-aligned")
        fp = meta.get("footprint")
        if fp and meta["kind"] not in ("marking", "decal"):
            mxy = 0.31 if "Edge" in spec["name"] else 0.2
            h, o, n, _ = coverage(spec["children"][0]["mb"], fp, max_y=mxy)
            n_cov += 1
            if h or o:
                F(f"{spec['name']}: coverage holes={h} overlaps={o} (of {n} samples)")
            mn, mx = spec["children"][0]["mb"].bounds()
            if meta["kind"] in ("segment", "node", "curve") and (abs(mn[0] - fp[0]) > 0.01 or abs(mx[0] - fp[2]) > 0.01
                                                                 or abs(mn[2] - fp[1]) > 0.01 or abs(mx[2] - fp[3]) > 0.01):
                F(f"{spec['name']}: mesh bounds do not match its declared footprint {fp}")
    info.append(f"Surface modules coverage-tested at 5 cm: {n_cov}")
    no_col_ok = {"decal", "marking", "span"}
    for m in models:
        if m["collision"] == ["none"] and m.get("kind") not in no_col_ok and m["category"] in ("Street_Props", "Fences", "Utilities"):
            if m["name"] not in ("SP_Lamp_Wall", "SP_ManholeCover", "SP_DrainGrate", "UT_WaterMeter", "UT_UtilityAccessCover",
                                 "UT_JunctionBox", "UT_Transformer_PoleMount"):
                W(f"{m['name']}: no collision")
        if m["collision_triangles"] > 400 and m["category"] not in ("Roads", "Sidewalks"):
            W(f"{m['name']}: heavy collision ({m['collision_triangles']} tris)")
        if m["triangles"] > 1500:
            W(f"{m['name']}: {m['triangles']} triangles exceeds the 1500 prop budget")
        if len(m["materials"]) > 8:
            W(f"{m['name']}: {len(m['materials'])} material slots")

    # ---- network --------------------------------------------------------------------
    adj, open_ports, zone_v, dijkstra = network(layout, man)
    termini = []
    for (pname, x, z, dx, dz) in open_ports:
        z_hit = [zz["id"] for zz in layout["zones"] if zz["rect"][0] - 0.6 <= x <= zz["rect"][2] + 0.6 and
                 zz["rect"][1] - 0.6 <= z <= zz["rect"][3] + 0.6]
        if z_hit:
            termini.append((pname, z_hit[0]))
        else:
            F(f"unconnected road port at ({x}, {z}) on {pname}")
    info.append(f"Road ports: {sum(1 for p in layout['placements'] if p['model'] in ROADNET)} road modules; "
                f"open ports = {len(open_ports)} (all at declared termini: {', '.join(t[1] for t in termini)})")
    roadnodes = {p["name"] for p in layout["placements"] if p["model"] in ROADNET}
    comps = components(adj, roadnodes)
    if len(comps) != 1:
        F(f"road network splits into {len(comps)} components")
    else:
        info.append(f"Road network: 1 connected component ({len(roadnodes)} modules)")
    dist, prev = dijkstra("ZONE:PLAYER_HOME")
    route_rows = []
    for a, b in layout["required_routes"]:
        d = dist.get("ZONE:" + b)
        if d is None:
            F(f"no drivable route {a} -> {b}")
        else:
            route_rows.append((a, b, d))
    # walking: supermarket <-> game shop straight-line + crosswalk presence
    zs = {z["id"]: z for z in layout["zones"]}
    sm, gs = zs["SUPERMARKET"]["access"], zs["GAME_SHOP"]["access"]
    walk = math.hypot(sm[0] - gs[0], sm[1] - gs[1])
    xw = [p for p in layout["placements"] if p["model"] == "SW_Crosswalk_7m" and abs(p["z"]) < 7 and -1 < p["x"] < 40]
    info.append(f"Supermarket <-> game shop: {walk:.0f} m apart across Main St; crosswalks within reach: {len(xw)}")
    if walk > 120:
        F("commercial district not walkable (supermarket - game shop > 120 m)")
    for zid, v in zone_v.items():
        if v and ("ZONE:" + zid) not in dist:
            F(f"zone {zid} not reachable from PLAYER_HOME")

    # ---- scene ------------------------------------------------------------------------
    scene = os.path.join(TOWN, "Godot_Scenes", "Greyhaven_Town.tscn")
    st = open(scene).read()
    res = re.findall(r'\[ext_resource type="PackedScene" path="res://THE_VEIL_ASSETS_V2/([^"]+)"', st)
    for r in res:
        if not os.path.exists(os.path.join(V2, r)):
            F(f"scene references missing {r}")
    nodes = re.findall(r'\[node name="([^"]+)"[^\]]*parent="([^"]+)"', st)
    seen = set()
    for n, par in nodes:
        if (par, n) in seen:
            F(f"duplicate node {par}/{n}")
        seen.add((par, n))
    n_inst = len(re.findall(r"instance=ExtResource", st))
    scene_tris = sum(tri_of.get(p["model"], 0) for p in layout["placements"]) + tri_of.get("TOWN_Ground", 0) + \
        sum(tri_of.get(mc["name"], 0) for mc in layout.get("merged_scatter", []))
    surf = {m["name"]: len(m["materials"]) for m in models}
    draw = sum(surf.get(p["model"], 1) for p in layout["placements"]) + \
        sum(mc["surfaces"] for mc in layout.get("merged_scatter", [])) + 7
    info.append(f"Estimated static draw surfaces (before Godot culling): ~{draw} "
                f"({len(layout.get('scatter_items', []))} woods/undergrowth items batched into "
                f"{len(layout.get('merged_scatter', []))} chunk meshes)")
    info.append(f"Scene: {len(res)} external scenes, {n_inst} instances, {len(nodes)} nodes, ~{scene_tris:,} visual triangles")

    # ---- Godot headless ------------------------------------------------------------------
    godot_lines = []
    if args.godot:
        godot_lines = run_godot(args.godot, args.godot_project, layout)
    else:
        W("Godot headless import/physics check not run (pass --godot)")
    write_report(models, route_rows, godot_lines, tri_of)
    print(f"{len(fails)} failures, {len(warns)} warnings")
    for f in fails[:60]:
        print("FAIL", f)
    for w in warns[:40]:
        print("WARN", w)
    return 1 if fails else 0


# ----------------------------------------------------------------------------
def run_godot(godot, proj, layout):
    import shutil
    proj = proj or os.path.join(os.environ.get("TMPDIR", "/tmp"), "veil_godot_check")
    if os.path.exists(proj):
        shutil.rmtree(proj)
    os.makedirs(proj)
    shutil.copytree(V2, os.path.join(proj, "THE_VEIL_ASSETS_V2"),
                    ignore=shutil.ignore_patterns("__pycache__", "OBJ", "*.pyc"))
    with open(os.path.join(proj, "project.godot"), "w") as f:
        f.write('config_version=5\n\n[application]\nconfig/name="VeilPack02Check"\n\n[rendering]\n'
                'renderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
    probes = []
    # opening-route raycast probes (x, z, expected surface height range)
    for (a, b) in (((31.0, -98.5 + 8), (31.0, -98.5)), ((31, -104), (0, -104)), ((0, -104), (0, 0)), ((0, 0), (31, 0)),
                   ((31, -1), (31, -16)), ((14, -2), (14, 6.5))):
        for t in np.linspace(0, 1, 9):
            probes.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    # full-height (15 cm) curbs on plain sidewalk modules: road edge, chamfer, sidewalk top
    curbs = [(-45.0, 3.3), (-45.0, 3.6), (-45.0, 3.75), (-45.0, 3.95), (-45.0, 5.0), (40.0, -98.6 + 0.0), (40.0, -97.5)]
    with open(os.path.join(proj, "check.gd"), "w") as f:
        f.write(GD_CHECK.replace("__PROBES__", json.dumps(probes)).replace("__CURBS__", json.dumps(curbs)))
    out = []
    r = subprocess.run([godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=1800)
    imp_err = [l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l and "leaked" not in l and "PagedAllocator" not in l]
    out.append(f"import: exit {r.returncode}, {len(imp_err)} error lines")
    for l in imp_err[:10]:
        F("Godot import: " + l.strip()[:200])
    r = subprocess.run([godot, "--headless", "--path", proj, "--script", "res://check.gd"], capture_output=True, text=True,
                       timeout=1800)
    for l in r.stdout.splitlines():
        if l.startswith("CHECK"):
            out.append(l[6:])
            if l.startswith("CHECK FAIL"):
                F("Godot: " + l[11:])
    # engine teardown noise after quit() (dummy renderer, leak reports) is not an asset problem
    lines_ = r.stderr.splitlines()
    err = []
    for i, l in enumerate(lines_):
        if not ("ERROR" in l or "SCRIPT ERROR" in l) or "leaked" in l or "PagedAllocator" in l or "still in use" in l:
            continue
        nxt = lines_[i + 1] if i + 1 < len(lines_) else ""
        if "dummy/storage" in nxt:   # dummy (headless) renderer teardown after quit()
            continue
        err.append(l)
    for l in err[:10]:
        F("Godot runtime: " + l.strip()[:200])
    if not any(l.startswith("CHECK DONE") for l in r.stdout.splitlines()):
        F("Godot check script did not finish")
    info.extend("Godot: " + l for l in out)
    return out


GD_CHECK = r'''extends SceneTree
var probes = __PROBES__
var curbs = __CURBS__
var root_node
var frames = 0

func _init():
	var ps = load("res://THE_VEIL_ASSETS_V2/02_Town/Godot_Scenes/Greyhaven_Town.tscn")
	if ps == null:
		print("CHECK FAIL scene did not load")
		quit()
		return
	root_node = ps.instantiate()
	get_root().add_child(root_node)
	var meshes = 0
	var bad_mat = 0
	var ext_mat = 0
	var bodies = 0
	var shapes = 0
	var stack = [root_node]
	while stack.size() > 0:
		var n = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			meshes += 1
			for i in n.mesh.get_surface_count():
				var m = n.mesh.surface_get_material(i)
				if m == null:
					bad_mat += 1
				elif m.resource_path.begins_with("res://THE_VEIL_ASSETS_V2/Materials_Godot/") or m.resource_path.begins_with("res://THE_VEIL_ASSETS_V2/02_Town/Materials/"):
					ext_mat += 1
				else:
					bad_mat += 1
		if n is StaticBody3D:
			bodies += 1
		if n is CollisionShape3D and n.shape != null:
			shapes += 1
	print("CHECK mesh instances=%d surfaces using library .tres=%d, surfaces with other/null material=%d" % [meshes, ext_mat, bad_mat])
	print("CHECK static bodies=%d collision shapes=%d" % [bodies, shapes])
	if bad_mat > 0:
		print("CHECK FAIL %d surfaces not using Pack 01/02 materials" % bad_mat)
	if shapes < 100:
		print("CHECK FAIL too few collision shapes")
	var dir = DirAccess.open("res://THE_VEIL_ASSETS_V2/02_Town/Materials")
	var nm = 0
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var mat = load("res://THE_VEIL_ASSETS_V2/02_Town/Materials/" + f)
			if mat == null or not (mat is StandardMaterial3D):
				print("CHECK FAIL material does not load: " + f)
			nm += 1
	print("CHECK Pack 02 materials loaded: %d" % nm)

func _physics_process(_d):
	frames += 1
	if frames < 3:
		return false
	var space = root_node.get_world_3d().direct_space_state
	var miss = 0
	var hmin = 99.0
	var hmax = -99.0
	for p in probes:
		var q = PhysicsRayQueryParameters3D.create(Vector3(p[0], 5, p[1]), Vector3(p[0], -5, p[1]))
		var r = space.intersect_ray(q)
		if r.is_empty():
			miss += 1
		else:
			hmin = min(hmin, r.position.y)
			hmax = max(hmax, r.position.y)
	print("CHECK opening-route probes: %d/%d hit ground, surface height %.3f..%.3f m" % [probes.size() - miss, probes.size(), hmin, hmax])
	if miss > 0:
		print("CHECK FAIL %d route probes found no collision" % miss)
	var curb_txt = ""
	for c in curbs:
		var q2 = PhysicsRayQueryParameters3D.create(Vector3(c[0], 5, c[1]), Vector3(c[0], -5, c[1]))
		var r2 = space.intersect_ray(q2)
		if r2.is_empty():
			print("CHECK FAIL curb probe %s no collision" % str(c))
		else:
			curb_txt += "%.3f " % r2.position.y
			if r2.normal.y < 0.7:
				print("CHECK FAIL curb collision too steep at %s (normal.y=%.2f)" % [str(c), r2.normal.y])
	print("CHECK curb-crossing collision heights (road->sidewalk ramps): " + curb_txt)
	# capsule walk test: a 0.35 m radius capsule slides from the road onto the sidewalk
	var body = CharacterBody3D.new()
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	body.add_child(cs)
	root_node.add_child(body)
	# walk tests over full 15 cm curbs: Main St (south side) and Maple Ave in front of PLAYER_HOME
	for t in [[Vector3(-45.0, 0.9, 1.5), Vector3(0, 0, 3.0), "z", 4.8], [Vector3(40.0, 0.9, -101.5), Vector3(0, 0, 3.0), "z", -97.0]]:
		body.global_position = t[0]
		var climbed = false
		for i in 150:
			body.velocity = Vector3(0, -2.0, 0) + t[1]
			body.move_and_slide()
			if body.global_position.z > t[3] and body.global_position.y > t[0].y + 0.1:
				climbed = true
				break
		print("CHECK capsule walk road->sidewalk over 15 cm curb at %s: %s (end %s)" % [str(t[0]), "ok" if climbed else "blocked", str(body.global_position)])
		if not climbed:
			print("CHECK FAIL capsule blocked by the curb at %s" % str(t[0]))
	print("CHECK DONE")
	root_node.queue_free()
	quit()
	return true
'''


def write_report(models, routes, godot_lines, tri_of):
    cats = {}
    for m in models:
        cats.setdefault(m["category"], []).append(m)
    lines = ["# THE VEIL - Pack 02 Validation Report", "",
             "Automated checks only. **Visual quality has NOT been verified** - no renders or screenshots were made; "
             "judge the look in Godot.", "",
             f"- Failures: **{len(fails)}**", f"- Warnings: {len(warns)}", "", "## Summary", ""]
    lines += [f"- {i}" for i in info]
    lines += ["", "## Drivable routes from PLAYER_HOME (graph distance through placed modules)", "",
              "| From | To | Route length |", "|---|---|---|"]
    lines += [f"| {a} | {b} | {d:.0f} m |" for a, b, d in routes]
    lines += ["", "## Models per category", "", "| Category | Models | Visual triangles (min / median / max) |", "|---|---|---|"]
    for c, ms in cats.items():
        t = sorted(m["triangles"] for m in ms)
        lines.append(f"| {c} | {len(ms)} | {t[0]} / {t[len(t) // 2]} / {t[-1]} |")
    if fails:
        lines += ["", "## Failures", ""] + [f"- {f}" for f in fails]
    if warns:
        lines += ["", "## Warnings", ""] + [f"- {w}" for w in warns]
    with open(os.path.join(TOWN, "Documentation", "VALIDATION_REPORT.md"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
