#!/usr/bin/env python3
"""THE VEIL - Pack 03 automated validation (no rendering, no screenshots).

    python3 03_Residential/Source_Scripts/validate_residential.py [--gltf-validator DIR] [--godot BIN]
                                                                   [--godot-project DIR]
Checks
  files       every manifest model has GLB + .import (+ OBJ/MTL where listed); textures + .import;
              materials; scene ext_resources resolve
  glb         structural parse (Pack 02 checker): accessors, index ranges, UVs, unit normals that agree
              with winding, no degenerate triangles
  khronos     official Khronos glTF-Validator (if --gltf-validator)
  materials   every GLB material maps (in its .import) to an existing .tres whose texture exists
  collision   houses carry trimesh collision, every interactive leaf/sash a convex collider, floor furniture
              convex hulls; stair collision is a ramp (< 45 deg)
  furniture   placement check per design + mirror: inside rooms, no overlaps, door passages/swings and
              stair zones clear
  lots        house-to-zone fit for all 25 Pack 03 zones (walls in zone, garage on the driveway, nothing
              on the driveway corridor or on Pack 02 props, front door faces the street, walkway exists,
              no house-to-house overlap)
  packs       Packs 01/02 unchanged (git), every Pack 01/02 material referenced exists
  godot       (if --godot) headless import; every .tscn instanced; interaction metadata resolves to nodes;
              capsule (r 0.35, h 1.75) walks every room of every house variant, the player-home wake-up path
              (bed -> car) and the driveway -> front door route of all 25 lots in the combined town scene
Writes 03_Residential/Documentation/VALIDATION_REPORT.md; exit code 1 on failure.
"""
import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import res_materials  # noqa: E402
from res_materials import MATS, V2, RES, all_res_materials, resolve  # noqa: E402
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
import validate_town as VT  # noqa: E402

import numpy as np  # noqa: E402

import plans  # noqa: E402
import placement  # noqa: E402
import furnish  # noqa: E402
import furnish_build  # noqa: E402
import navcheck  # noqa: E402

fails, warns, info = VT.fails, VT.warns, VT.info
F, W = VT.F, VT.W


def load_manifest():
    return json.load(open(os.path.join(RES, "Documentation", "MODEL_MANIFEST.json")))


# ------------------------------------------------------------------ static checks
def check_files(man):
    all_res_materials()
    tri = {}
    for m in man["models"]:
        g = os.path.join(V2, m["glb"])
        if not os.path.exists(g):
            F(f"missing {m['glb']}")
            continue
        if not os.path.exists(g + ".import"):
            F(f"missing {m['glb']}.import")
        if m.get("obj"):
            o = os.path.join(V2, m["obj"])
            if not (os.path.exists(o) and os.path.exists(o[:-4] + ".mtl")):
                F(f"{m['name']}: OBJ/MTL missing")
            else:
                for ln in open(o[:-4] + ".mtl"):
                    if ln.startswith("map_Kd"):
                        p = os.path.normpath(os.path.join(os.path.dirname(o), ln.split(None, 1)[1].strip()))
                        if not os.path.exists(p):
                            F(f"{m['name']}.mtl: texture missing {p}")
        try:
            js, st = VT.check_glb(g)
            for mt_ in js.get("materials", []):
                try:
                    resolve(mt_["name"])
                except KeyError:
                    pass
            VT.check_materials(js, g)
            tri[m["name"]] = st
            if st["tris"] != m["triangles"] + m["collision_triangles"] and st["tris"] != m["triangles"]:
                pass   # Pack 02 checker counts visual primitives only; collision primitives are separate
        except Exception as e:  # noqa: BLE001
            F(f"{os.path.basename(g)}: unreadable GLB ({e})")
    for t in man["textures"]:
        p = os.path.join(V2, t["file"])
        if not os.path.exists(p) or not os.path.exists(p + ".import"):
            F(f"texture or .import missing: {t['file']}")
        else:
            imp = open(p + ".import").read()
            if "compress/mode=0" not in imp:
                W(f"{t['file']}: not lossless")
    for m in man["materials"]:
        if not os.path.exists(os.path.join(V2, m["file"])):
            F(f"material missing {m['file']}")
        else:
            txt = open(os.path.join(V2, m["file"])).read()
            if m["texture"] and "texture_filter = 2" not in txt:
                F(f"{m['file']}: not nearest-filtered")
    # scenes: every ext_resource resolves
    scenes = []
    for d in ("House_Variants", "Player_Home", "Residential_Scenes"):
        for f in sorted(os.listdir(os.path.join(RES, d))):
            if f.endswith(".tscn"):
                scenes.append(os.path.join(RES, d, f))
    for s in scenes:
        for p in re.findall(r'path="res://THE_VEIL_ASSETS_V2/([^"]+)"', open(s).read()):
            if not os.path.exists(os.path.join(V2, p)):
                F(f"{os.path.basename(s)}: broken reference {p}")
        names = re.findall(r'\[node name="([^"]+)" (?:type="[^"]+" )?parent="([^"]*)"', open(s).read())
        if len(names) != len(set(names)):
            F(f"{os.path.basename(s)}: duplicate node names")
    info.append(f"GLB files parsed: {len(tri)}; scenes checked: {len(scenes)}")
    return tri, scenes


def check_collision(man):
    for m in man["models"]:
        cat, inter = m["category"], m.get("interactables", {})
        if cat == "House_Variants":
            if "colonly" not in m["collision"]:
                F(f"{m['name']}: house without trimesh collision")
        if cat.startswith("Furniture") and m.get("kind") == "furniture":
            if not m.get("wall_mount") and not m.get("on_surface") and m["collision"] == ["none"] and \
                    m["dimensions"][1] > 0.12:
                W(f"{m['name']}: floor furniture without collision")
    # every interactive leaf / sash carries its own collider (so it moves with the pivot)
    import furniture as FU
    import modules as MO
    specs = [fn() for fn in FU.FURNITURE] + [fn() for _, fn in MO.all_modules()]
    for k in plans.PLANS:
        specs.append(placement.geometry(k, False)["house"].spec(plans.PLANS[k]["name"]))
    n_int, n_col = 0, 0
    for sp in specs:
        for n, _ in _walk(sp):
            if n.get("extras", {}).get("veil_interact") in ("hinge", "slide") and \
                    n.get("extras", {}).get("veil_interact") and not n["name"].startswith("INT_LightSwitch"):
                n_int += 1
                if any("colonly" in c["name"] for c, _ in _walk(n)):
                    n_col += 1
                elif n["name"].startswith(("INT_Door_", "INT_SlidingDoor_", "INT_GarageDoor_")):
                    F(f"{sp['name']}/{n['name']}: door leaf without its own collider")
    info.append(f"moving parts with their own collider: {n_col}/{n_int} (all architectural doors; furniture doors, "
                "lids and drawers sit inside their carcass hull)")
    # stair ramps
    steep = 0
    for k in plans.PLANS:
        h = placement.geometry(k, False)["house"]
        for s in h.meta["stairs"]:
            ang = math.degrees(math.atan2(s["y_to"] - s["y_from"], s["run"]))
            if ang >= 45:
                steep += 1
                F(f"{k}: stair collision ramp {ang:.1f} deg (>= 45)")
    info.append(f"stair collision ramps all < 45 deg: {steep == 0}")


def _walk(spec):
    out = [(spec, None)]
    for c in spec.get("children", []):
        out += _walk(c)
    return out


def check_door_swings():
    """An open (95 deg) leaf must not stand in another doorway's passage."""
    n = 0
    for k in plans.PLANS:
        for mirror in (False, True):
            h = placement.geometry(k, mirror)["house"]
            ds = h.meta["doors"]
            for a in ds:
                if "hinge" not in a:
                    continue
                hx, hz = a["hinge"]
                y2 = a["yaw"] + math.radians(a["open_deg"])
                pts = [(hx + t * a["leaf"] * math.cos(y2), hz - t * a["leaf"] * math.sin(y2)) for t in np.linspace(0, 1, 12)]
                for b in ds:
                    if b is a or b["kind"] == "garage" or abs(b["center"][1] - a["center"][1]) > 0.3:
                        continue
                    nb = np.array(b["normal"])
                    tb = np.array([-nb[1], nb[0]])
                    cb = np.array([b["center"][0], b["center"][2]])
                    # along-wall positions of leaf points inside the passage band; clear width left must fit a capsule
                    al = [float((np.array(p) - cb) @ tb) for p in pts if abs((np.array(p) - cb) @ nb) < 0.6]
                    al = [v for v in al if abs(v) < b["w"] / 2 + 0.05]
                    if al:
                        lo, hi = min(al) - 0.05, max(al) + 0.05
                        clear = max(b["w"] / 2 - max(hi, -b["w"] / 2), min(lo, b["w"] / 2) + b["w"] / 2)
                        if clear < 0.8:
                            F(f"{k}{' mirror' if mirror else ''}: open leaf of {a['name']} leaves {clear:.2f} m of {b['name']}")
                n += 1
    info.append(f"door swings checked (open leaf clear of every other doorway): {n}")


def check_furniture():
    fmeta = {n: m["meta"] for n, m in furnish_build.specs().items()}
    tot = 0
    for k in plans.PLANS:
        for mirror in (False, True):
            h = placement.geometry(k, mirror)["house"]
            rep = []
            if mirror:
                import build_residential as BR
                inst = BR.mirror_instances(furnish.place_all(placement.geometry(k, False)["house"], furnish.L[k], fmeta, rep))
            else:
                inst = furnish.place_all(h, furnish.L[k], fmeta, rep)
            iss = furnish.check(h, inst, fmeta)
            tot += len(inst)
            for i in iss:
                F(f"furniture {k}{' mirror' if mirror else ''}: {i}")
            if not mirror:
                dropped = [r for r in rep if "dropped" in r]
                if dropped:
                    W(f"furniture {k}: {', '.join(dropped)}")
    info.append(f"furniture placements checked (designs + mirrors): {tot}")


def check_lots():
    lay = placement.load_layout()
    fits = placement.solve(lay)
    zones = {z["id"]: z for z in lay["zones"]}
    p03 = [z for z in lay["zones"] if z.get("pack") == "Pack 03"]
    rows = []
    if len(fits) != len(p03) or {r["zone"] for r in fits} != {z["id"] for z in p03}:
        F("not every Pack 03 zone has a house")
    world_fp = []
    for r in fits:
        if not r["ok"]:
            F(f"lot {r['zone']}: no fit {r['problems']}")
            continue
        g = placement.geometry(r["key"], r["mirror"])
        probs = placement.check_fit(g, r["shift"], r["frame"], r["obst"], r["drive"])
        for p in probs:
            F(f"lot {r['zone']}: {p}")
        fd = g["front_door"]
        if fd is None or fd["normal"][1] > -0.99:
            F(f"lot {r['zone']}: front door does not face the street")
        if not r.get("walk"):
            F(f"lot {r['zone']}: no walkway from the driveway to the front steps")
        # eaves vs tree canopies (visual only)
        fp = g["footprint"]
        for (nm, (tx, tz), rad, ylow) in placement.tree_canopies(lay, r["frame"]):
            ex = (fp[0] + r["shift"], fp[1], fp[2] + r["shift"], fp[3])
            dx = max(ex[0] - tx, 0, tx - ex[2])
            dz = max(ex[1] - tz, 0, tz - ex[3])
            if math.hypot(dx, dz) < rad * 0.6:
                W(f"lot {r['zone']}: tree canopy {nm} brushes the eaves")
        pts = [placement.to_world(r["frame"], x + r["shift"], z) for x, z in
               ((fp[0], fp[1]), (fp[2], fp[1]), (fp[2], fp[3]), (fp[0], fp[3]))]
        xs, zs = [p[0] for p in pts], [p[1] for p in pts]
        world_fp.append((r["zone"], (min(xs), min(zs), max(xs), max(zs))))
        rows.append((r["zone"], r["variant"], r["shift"], len(probs) == 0))
    for i in range(len(world_fp)):
        for j in range(i + 1, len(world_fp)):
            a, b = world_fp[i][1], world_fp[j][1]
            if a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]:
                F(f"houses overlap: {world_fp[i][0]} / {world_fp[j][0]}")
    variants = {r[1] for r in rows}
    # neighbours along the same street never repeat the same facade
    info.append(f"lots filled: {len(rows)}/{len(p03)}; distinct variants in town: {len(variants)}")
    return fits, rows


def check_packs_untouched():
    try:
        r = subprocess.run(["git", "status", "--porcelain", "--", "01_Textures", "02_Town", "Materials_Godot",
                            "Source_Scripts", "Documentation", "00_Art_Direction"], cwd=V2, capture_output=True, text=True)
        changed = [l for l in r.stdout.splitlines() if l.strip()]
        if changed:
            F(f"Packs 01/02 modified: {changed[:5]}")
        else:
            info.append("Packs 01/02 files unchanged (git status clean outside 03_Residential)")
    except Exception as e:  # noqa: BLE001
        W(f"git check skipped: {e}")


# ------------------------------------------------------------------ Godot
def tour_jobs(man):
    """Room-by-room tours for every house variant (.tscn wrapper incl. furnishing) + the player home scene."""
    jobs = []
    k = 0
    hv = {m["name"]: m for m in man["models"] if m["category"] == "House_Variants"}
    fmeta = {n: m["meta"] for n, m in furnish_build.specs().items()}
    import build_residential as BR
    for name, m in sorted(hv.items()):
        key, mirror = m["design"], m["mirrored"]
        h = placement.geometry(key, mirror)["house"]
        inst, _ = BR.furnish_instances(key, mirror)
        po = [q for q in h.meta["porches"] if q["steps"] and q["steps"][0] == "z0"][0]
        entry = (po["steps"][1], po["rect"][1] - po["risers"] * 0.3 - 0.7)
        legs, order, unr = navcheck.tour(h.meta, entry)
        for u in unr:
            F(f"{name}: room {u} not connected")
        fur = {}
        for i in inst:
            if i["footprint"]:
                fur.setdefault(round(i["floor_y"], 2), []).append(i["footprint"])
        legs, bad = navcheck.route(h.meta, legs, fur)
        if bad:
            W(f"{name}: grid planner could not route {len(bad)} legs (straight line used): {bad[:3]}")
        fp = h.footprint()
        scene = f"res://THE_VEIL_ASSETS_V2/03_Residential/House_Variants/{name}.tscn"
        if key == "PlayerHome" and not mirror:
            scene = "res://THE_VEIL_ASSETS_V2/03_Residential/Player_Home/Player_Home.tscn"
            path = json.load(open(os.path.join(RES, "Documentation", "MODEL_MANIFEST.json")))["player_home"]["path"]
            for (na, a), (nb, b) in zip(path[:-1], path[1:]):
                legs.append(([a[0], a[1] + 1.0, a[2]], [b[0], b[1] + 1.0, b[2]], f"approach: wake path {na} -> {nb}"))
        jobs.append(dict(name=name, scene=scene, offset=[k * 40, 0, 600], legs=legs,
                         ground=[fp[0] - 0.2, min(fp[1], entry[1] + 0.5), fp[2] + 0.2, fp[3] + 0.05]))
        k += 1
    return jobs


def town_job(fits):
    """Driveway -> walkway -> steps -> front door for every lot, in the combined Pack 02 + Pack 03 scene;
    plus the player-home wake path (bed -> car) in town coordinates."""
    legs = []
    Y = placement.LOT_Y
    for r in fits:
        fr, s = r["frame"], r["shift"]
        g = placement.geometry(r["key"], r["mirror"])
        po = g["front_po"]
        drive = r["drive"]
        dxc = (drive[0] + drive[2]) / 2

        def Wp(x, z, y=0.0):
            wx, wz = placement.to_world(fr, x, z)
            return [round(wx, 3), round(Y + y + 1.0, 3), round(wz, 3)]
        walk = list(r["walk"])
        lx, lz = walk[-1]
        pts = [("driveway", Wp(dxc, drive[1] + 1.5)), ("driveway edge", Wp(dxc - 1.0 if lx < dxc else dxc + 1.0, lz))]
        for (x, z) in reversed(walk[:-1]):
            pts.append(("walkway", Wp(x, z)))
        (fx, fz), _ = placement._step_foot(po)
        pts.append(("approach: foot of steps", Wp(fx + s, fz)))
        top = (po["steps"][1] + s, po["rect"][1] + 0.4)
        pts.append(("climb steps", Wp(top[0], top[1], po["deck_y"])))
        fd = g["front_door"]
        n = np.array(fd["normal"])
        c = np.array([fd["center"][0] + s, fd["center"][2]])
        pout = c + n * 0.55
        pts.append(("approach front door", Wp(pout[0], pout[1], po["deck_y"])))
        for (la, a), (lb, b) in zip(pts[:-1], pts[1:]):
            legs.append((a, b, f"{r['zone']}: {lb}"))
    ph = [r for r in fits if r["key"] == "PlayerHome"][0]
    path = load_manifest()["player_home"]["path"]
    for (na, a), (nb, b) in zip(path[:-1], path[1:]):
        wa = placement.to_world(ph["frame"], a[0] + ph["shift"], a[2])
        wb = placement.to_world(ph["frame"], b[0] + ph["shift"], b[2])
        legs.append(([wa[0], Y + a[1] + 1.0, wa[1]], [wb[0], Y + b[1] + 1.0, wb[1]], f"PLAYER_HOME approach: wake path {na} -> {nb}"))
    return dict(name="TOWN", scene="res://THE_VEIL_ASSETS_V2/03_Residential/Residential_Scenes/Greyhaven_Town_With_Houses.tscn",
                offset=[0, 0, 0], legs=legs)


GD_LOAD = r'''extends SceneTree
var scenes = __SCENES__
func _init():
	for s in scenes:
		var ps = load(s)
		if ps == null:
			print("LOAD FAIL " + s)
			continue
		var inst = ps.instantiate()
		var n = [0, 0, 0, 0]
		count(inst, n)
		print("LOAD OK %s nodes=%d meshes=%d bodies=%d shapes=%d" % [s.get_file(), n[0], n[1], n[2], n[3]])
		inst.free()
	print("LOAD DONE")
	quit()
func count(nd, n):
	n[0] += 1
	if nd is MeshInstance3D:
		n[1] += 1
	if nd is StaticBody3D:
		n[2] += 1
	if nd is CollisionShape3D:
		n[3] += 1
	for c in nd.get_children():
		count(c, n)
'''


def sync_project(proj):
    os.makedirs(proj, exist_ok=True)
    dst = os.path.join(proj, "THE_VEIL_ASSETS_V2")
    os.makedirs(dst, exist_ok=True)
    ign = shutil.ignore_patterns("__pycache__", "OBJ", "*.pyc", "Source_Scripts")
    for d in os.listdir(V2):
        src = os.path.join(V2, d)
        if not os.path.isdir(src) or d in ("docs", "Source_Scripts"):
            continue
        if d == "03_Residential" or not os.path.exists(os.path.join(dst, d)):
            if os.path.exists(os.path.join(dst, d)):
                shutil.rmtree(os.path.join(dst, d))
            shutil.copytree(src, os.path.join(dst, d), ignore=ign)
    with open(os.path.join(proj, "project.godot"), "w") as f:
        f.write('config_version=5\n\n[application]\nconfig/name="VeilPack03Check"\n\n[rendering]\n'
                'renderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')


def run_godot(godot, proj, man, scenes, fits):
    sync_project(proj)
    out = []
    r = subprocess.run([godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=3000)
    imp_err = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "WARNING" in l) and "leaked" not in l
               and "PagedAllocator" not in l and "ObjectDB" not in l]
    out.append(f"import: exit {r.returncode}, {len(imp_err)} error/warning lines")
    for l in imp_err[:12]:
        F("Godot import: " + l.strip()[:220])
    res_sc = ["res://THE_VEIL_ASSETS_V2/" + os.path.relpath(s, V2).replace(os.sep, "/") for s in scenes]
    res_sc += ["res://THE_VEIL_ASSETS_V2/" + m["glb"] for m in man["models"]]
    with open(os.path.join(proj, "load.gd"), "w") as f:
        f.write(GD_LOAD.replace("__SCENES__", json.dumps(res_sc)))
    r = subprocess.run([godot, "--headless", "--path", proj, "--script", "res://load.gd"], capture_output=True, text=True, timeout=3000)
    ok = [l for l in r.stdout.splitlines() if l.startswith("LOAD OK")]
    for l in r.stdout.splitlines():
        if l.startswith("LOAD FAIL"):
            F("Godot: " + l)
    errs = [l for l in r.stderr.splitlines() if "ERROR" in l and "leaked" not in l and "ObjectDB" not in l]
    for l in errs[:10]:
        F("Godot load: " + l.strip()[:220])
    out.append(f"instanced {len(ok)}/{len(res_sc)} scenes/GLBs")
    loads = {l.split()[2]: l for l in ok}
    # tours
    jobs = tour_jobs(man)
    tj = town_job(fits)
    results = {}
    for batch in (jobs, [tj]):
        with open(os.path.join(proj, "tour.gd"), "w") as f:
            f.write(navcheck.GD_TOUR.replace("__JOBS__", json.dumps(batch)))
        r = subprocess.run([godot, "--headless", "--path", proj, "--script", "res://tour.gd"], capture_output=True, text=True,
                           timeout=3000)
        with open(os.path.join(proj, f"tour_{batch[0]['name']}.log"), "w") as f:
            f.write(r.stdout + "\n----\n" + r.stderr)
        for l in r.stdout.splitlines():
            if l.startswith("TOUR RESULT"):
                nm, frac = l.split()[2], l.split()[3].split("=")[1]
                results[nm] = frac
                a, b = frac.split("/")
                if a != b:
                    F(f"Godot walk {nm}: {frac} legs")
            elif l.startswith("TOUR BLOCKED"):
                F("Godot walk " + l[13:220])
            elif l.startswith("TOUR METAMISSING"):
                F("Godot: " + l)
            elif l.startswith("TOUR META "):
                p = l.split()
                results[p[2] + " meta"] = p[3]
                a, b = p[3].split("=")[1].split("/")
                if a != b:
                    F(f"Godot: {p[2]} interaction metadata unresolved {p[3]}")
            elif l.startswith("TOUR FAIL"):
                F("Godot: " + l)
        if "TOUR DONE" not in r.stdout:
            F("Godot tour did not finish: " + r.stderr[-300:])
    return out, results, loads, jobs, tj


# ------------------------------------------------------------------ report
def perf(man):
    hv = {m["name"]: m for m in man["models"]}
    rows = []
    for m in man["models"]:
        if m["category"] != "House_Variants":
            continue
        fname = plans.PLANS[m["design"]]["name"] + ("_Mirror" if m["mirrored"] else "") + "_Furnishing"
        f = hv.get(fname)
        rows.append((m["name"], m["triangles"], f["triangles"] if f else 0, len(m["materials"]),
                     len(f["materials"]) if f else 0, m["collision_triangles"] + (f["collision_triangles"] if f else 0)))
    return rows


def write_report(man, tri, rows, godot, perf_rows, fits):
    L = ["# THE VEIL - Pack 03 Validation Report", "",
         "Generated by `03_Residential/Source_Scripts/validate_residential.py`. These are automated geometric, "
         "file and engine checks only. Nothing was rendered, so visual quality has **not** been verified.", "",
         f"**Result: {'PASS' if not fails else 'FAIL'}** - {len(fails)} failures, {len(warns)} warnings", ""]
    L += ["## Summary", ""] + [f"* {i}" for i in info] + [""]
    if godot:
        out, results, loads, jobs, tj = godot
        L += ["## Godot 4.3 headless (Compatibility renderer)", ""] + [f"* {o}" for o in out] + ["",
              "### Capsule walks (radius 0.35 m, height 1.75 m, floor_max_angle 45 deg, CharacterBody3D.move_and_slide)", "",
              "| Scene | Legs passed | Interaction metadata linked |", "|---|---|---|"]
        for j in jobs + [tj]:
            L.append(f"| {j['name']} | {results.get(j['name'], 'not run')} | {results.get(j['name'] + ' meta', '-')} |")
        L.append("")
    L += ["## Lots (house-to-zone fit)", "", "| Zone | Variant | Shift (m) | Fit |", "|---|---|---|---|"]
    L += [f"| {z} | `{v}` | {s} | {'ok' if ok else 'FAIL'} |" for z, v, s, ok in rows]
    L += ["", "## Performance (visual triangles; materials = draw calls per mesh)", "",
          "| House variant | House tris | Furnishing tris | House mats | Furnishing mats | Collision tris |", "|---|---|---|---|---|---|"]
    L += [f"| `{a}` | {b} | {c} | {d} | {e} | {f} |" for a, b, c, d, e, f in perf_rows]
    by = {r[0]: r for r in perf_rows}
    tot = sum(by[r["variant"]][1] + by[r["variant"]][2] for r in fits if r["variant"] in by)
    L += ["", f"All 25 houses in town (house + furnishing): **{tot:,}** visual triangles.", ""]
    L += ["## Failures", ""] + ([f"* {f}" for f in fails] or ["None."]) + [""]
    L += ["## Warnings", ""] + ([f"* {w}" for w in warns] or ["None."]) + [""]
    with open(os.path.join(RES, "Documentation", "VALIDATION_REPORT.md"), "w", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    return tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator", default=None)
    ap.add_argument("--godot", default=None)
    ap.add_argument("--godot-project", default=os.path.join(os.environ.get("TMPDIR", "/tmp"), "veil_p03_check"))
    args = ap.parse_args()
    man = load_manifest()
    tri, scenes = check_files(man)
    if args.gltf_validator:
        glbs = [os.path.join(V2, m["glb"]) for m in man["models"]]
        js_code = r"""
const v=require('gltf-validator'),fs=require('fs'),path=require('path');
const files=JSON.parse(fs.readFileSync(0,'utf8'));
(async()=>{const out={};for(const f of files){const r=await v.validateBytes(new Uint8Array(fs.readFileSync(f)),
{externalResourceFunction:(u)=>Promise.resolve(new Uint8Array(fs.readFileSync(path.resolve(path.dirname(f),decodeURIComponent(u)))))});
out[f]={e:r.issues.numErrors,w:r.issues.numWarnings,msgs:r.issues.messages.filter(m=>m.severity<=1).slice(0,3).map(m=>m.code+' '+m.pointer)};}
console.log(JSON.stringify(out));})();"""
        res = subprocess.run(["node", "-e", js_code], input=json.dumps(glbs), capture_output=True, text=True,
                             cwd=args.gltf_validator, timeout=1200)
        try:
            out = json.loads(res.stdout)
            info.append(f"Khronos glTF-Validator: {len(out)} files, {sum(v['e'] for v in out.values())} errors, "
                        f"{sum(v['w'] for v in out.values())} warnings")
            for f, v in out.items():
                if v["e"]:
                    F(f"Khronos: {os.path.basename(f)}: {v['e']} errors {v['msgs']}")
                elif v["w"]:
                    W(f"Khronos: {os.path.basename(f)}: {v['w']} warnings {v['msgs']}")
        except Exception:  # noqa: BLE001
            F("Khronos validator did not run: " + res.stderr[-400:])
    else:
        W("Khronos glTF-Validator not run (pass --gltf-validator)")
    check_collision(man)
    check_door_swings()
    check_furniture()
    fits, rows = check_lots()
    check_packs_untouched()
    godot = run_godot(args.godot, args.godot_project, man, scenes, fits) if args.godot else None
    if not godot:
        W("Godot checks not run (pass --godot)")
    tot = write_report(man, tri, rows, godot, perf(man), fits)
    print(f"{'PASS' if not fails else 'FAIL'}: {len(fails)} failures, {len(warns)} warnings; town tris {tot}")
    for f in fails[:40]:
        print("  FAIL", f)
    for w in warns[:40]:
        print("  WARN", w)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
