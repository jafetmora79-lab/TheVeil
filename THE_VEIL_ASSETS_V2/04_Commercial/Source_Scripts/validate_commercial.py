#!/usr/bin/env python3
"""THE VEIL - Pack 04 focused validation (no screenshots; nothing captured from the renderer).

    python3 04_Commercial/Source_Scripts/validate_commercial.py [--gltf-validator DIR] [--godot BIN --godot-project DIR]
        (Godot project must already hold Packs 01/02/03/05/09 + Materials_Godot; Pack 04 is copied in)

Static: GLB structure (Pack 02 checker), embedded textures + .import remaps, atlas UVs in range, palette lock, unique names,
scene references, gallery listing. Architecture: ceiling heights, door sizes, building inside its Pack 02 zone, fixtures
inside their rooms / not overlapping / not in door clearances, walk paths (Pack 03 FloorGrid, capsule radius 0.37 m) from
outside every location to every room and named target, floor + wall collision present.
Engine: Godot 4.3 import; gl_compatibility run (xvfb + opengl3) instancing every scene, physics ray casts for floor
collision under every nav target and a clear passage through every exterior doorway (door leaves excluded = open), and the
complete-town scene. Writes Documentation/VALIDATION_REPORT.md.
"""
import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
REPO = os.path.dirname(V2)
P4 = os.path.join(V2, "04_Commercial")
for p in ("03_Residential", "02_Town"):
    sys.path.insert(0, os.path.join(V2, p, "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
import validate_town as VT  # noqa: E402

fails, warns, info = VT.fails, VT.warns, VT.info
F, W = VT.F, VT.W

GD = r'''extends SceneTree
var scenes = __SCENES__
func frames(n):
	for i in n:
		await process_frame
func bodies_named(n, pat, out):
	if n is CollisionObject3D and String(n.get_parent().name).begins_with(pat):
		out.append(n.get_rid())
	if n is CollisionObject3D and String(n.name).begins_with(pat):
		out.append(n.get_rid())
	for c in n.get_children():
		bodies_named(c, pat, out)
func _initialize():
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	for p in scenes:
		var ps = load(p)
		if ps == null:
			print("CHECK FAIL load ", p); continue
		var n = ps.instantiate(); root.add_child(n)
		cam.look_at_from_position(Vector3(0, 6, -14), Vector3(0, 1, 6))
		await frames(3)
		await physics_frame
		await physics_frame
		var space = n.get_world_3d().direct_space_state
		var excl = []
		bodies_named(n, "INT_", excl)
		var nav_ok = 0
		var nav_bad = []
		var nt = n.get_node_or_null("NavTargets")
		if nt:
			for m in nt.get_children():
				var q = PhysicsRayQueryParameters3D.create(m.global_position + Vector3(0, 1.2, 0), m.global_position + Vector3(0, -0.6, 0))
				q.exclude = excl
				var r = space.intersect_ray(q)
				if r and abs(r.position.y - m.global_position.y) < 0.15:
					nav_ok += 1
				else:
					nav_bad.append(String(m.name))
		var door_ok = 0
		var door_bad = []
		var dw = n.get_node_or_null("Doorways")
		if dw:
			for m in dw.get_children():
				if not String(m.name).ends_with("_Outside"):
					continue
				var inner = dw.get_node_or_null(String(m.name).replace("_Outside", "_Inside"))
				if inner == null:
					continue
				var clear = true
				var a0 = m.global_position
				var b0 = inner.global_position
				var side = (b0 - a0).cross(Vector3.UP).normalized()
				var half = min(0.3, float(m.get_meta("width")) / 2.0 - 0.12)
				for hgt in [0.35, 1.0, 1.8]:
					for off in [-half, 0.0, half]:
						var a = Vector3(a0.x, b0.y + hgt, a0.z) + side * off
						var b = Vector3(b0.x, b0.y + hgt, b0.z) + side * off
						var q = PhysicsRayQueryParameters3D.create(a, b)
						q.exclude = excl
						if space.intersect_ray(q):
							clear = false
				if clear:
					door_ok += 1
				else:
					door_bad.append(String(m.name))
		var shapes = n.find_children("*", "CollisionShape3D", true, false).size()
		print("CHECK SCENE %s nav=%d/%d door=%d bad_nav=%s bad_door=%s shapes=%d lights=%d" % [p.get_file(), nav_ok, nav_ok + nav_bad.size(), door_ok,
			",".join(nav_bad), ",".join(door_bad), shapes, n.find_children("*", "Light3D", true, false).size()])
		n.queue_free()
		await frames(2)
	var town = load("res://THE_VEIL_ASSETS_V2/04_Commercial/Godot_Scenes/Greyhaven_Town_Complete.tscn")
	if town == null:
		print("CHECK FAIL town")
	else:
		var tn = town.instantiate(); root.add_child(tn)
		cam.look_at_from_position(Vector3(31, 1.75, -10), Vector3(31, 2, -40))
		await frames(4)
		print("CHECK TOWN nodes=%d" % tn.find_children("*", "", true, false).size())
	quit()
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator")
    ap.add_argument("--godot")
    ap.add_argument("--godot-project")
    args = ap.parse_args()
    man = json.load(open(os.path.join(P4, "Documentation", "COMMERCIAL_MANIFEST.json")))
    models, locs = man["models"], man["locations"]
    # names / palette / materials
    names = [m["name"] for m in models]
    others = set()
    for root, _, fs in os.walk(V2):
        if "04_Commercial" not in root:
            others |= {f[:-4] for f in fs if f.endswith(".glb")}
    clash = sorted(set(names) & others) + sorted({n for n in names if names.count(n) > 1})
    if clash:
        F(f"GLB names collide: {clash}")
    info.append(f"GLB names unique across the repository: {not clash}")
    from PIL import Image
    from chr_tex import P as PAL
    pal = {tuple(c) for c in PAL.rgb.tolist()}
    im = np.asarray(Image.open(os.path.join(V2, man["texture"])).convert("RGB")).reshape(-1, 3)
    off = {tuple(x) for x in im.tolist()} - pal
    if off:
        F(f"atlas: {len(off)} colours outside the Greyhaven palette")
    info.append(f"T_Com4_Atlas.png 512x512 palette-locked: {not off}; {len(man['atlas_rects'])} atlas regions")
    for t in man["materials"]:
        s = open(os.path.join(V2, t)).read()
        if "texture_filter = 2" not in s:
            F(f"{t}: not nearest-filtered")
    atlas_mats = {"M_Com4_Atlas", "M_Com4_Glass", "M_Com4_Glow"}
    for m in models:
        glb = os.path.join(V2, m["glb"])
        if not os.path.exists(glb + ".import"):
            F(f"{m['name']}: .import missing")
            continue
        js, _ = VT.check_glb(glb)
        _, binb = VT.read_glb(glb)
        if any("uri" in im_ for im_ in js.get("images", [])):
            F(f"{m['name']}: texture not embedded")
        imp = open(glb + ".import").read()
        for mat in m["materials"]:
            if mat not in imp:
                F(f"{m['name']}: .import has no remap for {mat}")
        for mesh in js["meshes"]:
            for p in mesh["primitives"]:
                if "material" in p and js["materials"][p["material"]]["name"] in atlas_mats:
                    uv = VT.accessor(js, binb, p["attributes"]["TEXCOORD_0"])
                    if uv.min() < -1e-5 or uv.max() > 1 + 1e-5:
                        F(f"{m['name']}: atlas UVs out of range")
        if m["category"] in ("building", "furnishing") and not any(n["name"].endswith("-colonly") for n in js["nodes"]):
            F(f"{m['name']}: no static collision")
        if m["category"].startswith("fixture") and m.get("size") and not any("colonly" in n["name"] for n in js["nodes"]) and m["size"][1] > 0.06:
            F(f"{m['name']}: fixture without collision")
    info.append(f"GLBs checked: {len(models)}, {sum(m['triangles'] for m in models)} triangles")
    # architecture + walkability
    import com_plans as CP
    import com_atlas
    com_atlas.build(os.path.join(P4, "Textures", "T_Com4_Atlas.png"))
    import navcheck
    plans = {k: p for k, p, _ in CP.PRIORITY}
    layout = json.load(open(os.path.join(V2, "02_Town", "Town_Layout", "greyhaven_layout.json")))
    zones = {z["id"]: z for z in layout["zones"]}
    import placement
    rows = []
    for L in locs:
        nf = len(fails)
        plan = plans[L["id"]]
        h = CP.ComBuilding(plan).build()
        rooms = {r["id"]: r for r in h.meta["rooms"]}
        for r in h.meta["rooms"]:
            ch = r["ceil_y"] - r["floor_y"]
            need = 3.2 if r["type"] in ("sales",) and L["priority"] == 1 else 2.6
            if ch < need - 1e-6:
                F(f"{L['id']} {r['id']}: ceiling {ch:.2f} m below {need}")
        for d in h.meta["doors"]:
            if d["w"] < 0.85 - 1e-6 or (d["kind"] != "arch" and d["h"] < 2.1 - 1e-6):
                F(f"{L['id']} {d['name']}: door {d['w']}x{d['h']} too small")
        fr = placement.zone_frame(zones[L["zone"]])
        pts = np.concatenate([np.asarray(g["p"]) for mb in (h.ext, h.inner) for g in mb.parts.values() if g["p"]])
        pts = pts[pts[:, 1] > 0.06]                       # ignore ground-level aprons / walks / pads outside the zone
        fp = [float(pts[:, 0].min()), float(pts[:, 2].min()), float(pts[:, 0].max()), float(pts[:, 2].max())]
        if fp[0] < -fr["W"] / 2 - 0.25 or fp[2] > fr["W"] / 2 + 0.25 or fp[3] > fr["D"] + 0.25:
            F(f"{L['id']}: building ({[round(v, 2) for v in fp]}) leaves its zone ({fr['W']} x {fr['D']})")
        # fixtures inside rooms, no overlaps, door clearances
        fps = [f for f in L["fixtures"] if f["footprint"] and not f["outdoor"]]
        ext_pieces, _ = h.edges()

        def half_t(room, side, lo, hi):
            """wall half-thickness on that side of the room over [lo, hi]: exterior 0.10, partition 0.06"""
            for (r_, sd, axis, c_, plo, phi) in ext_pieces:
                if r_["id"] == room and sd == side and min(hi, phi) - max(lo, plo) > 0.01:
                    return 0.10
            return 0.06
        for f in fps:
            if f.get("straddle"):
                continue
            r = rooms[f["room"]]
            x0, z0, x1, z1 = r["rect"]
            a, b, c, d = f["footprint"]
            gap = 0.003
            bad_side = []
            if a < x0 + half_t(f["room"], "L", b, d) + gap:
                bad_side.append("L")
            if c > x1 - half_t(f["room"], "R", b, d) - gap:
                bad_side.append("R")
            if b < z0 + half_t(f["room"], "F", a, c) + gap:
                bad_side.append("F")
            if d > z1 - half_t(f["room"], "B", a, c) - gap:
                bad_side.append("B")
            if bad_side:
                F(f"{L['id']} {f['model']} at ({f['x']}, {f['z']}) penetrates the {'/'.join(bad_side)} wall of {f['room']}")
        for i in range(len(fps)):
            for j in range(i + 1, len(fps)):
                A, B = fps[i]["footprint"], fps[j]["footprint"]
                if min(A[2], B[2]) - max(A[0], B[0]) > 0.03 and min(A[3], B[3]) - max(A[1], B[1]) > 0.03:
                    F(f"{L['id']}: {fps[i]['model']} overlaps {fps[j]['model']}")
        for d in h.meta["doors"]:
            n = np.array(d["normal"])
            tv = np.array([-n[1], n[0]])
            c = np.array([d["center"][0], d["center"][2]])
            for f in fps:
                a, b, cc, dd = f["footprint"]
                blocked = 0
                for s in np.linspace(-d["w"] / 2 + 0.1, d["w"] / 2 - 0.1, 5):
                    for k in (0.3, 0.6):
                        for sg in (-1, 1):
                            p = c + tv * s + n * sg * k
                            if a < p[0] < cc and b < p[1] < dd:
                                blocked += 1
                if blocked and not (f.get("straddle") and d["kind"] == "arch"):
                    F(f"{L['id']}: {f['model']} blocks the clearance of door {d['name']}")
        # walk paths from outside the main entrance
        ent = [d for d in h.meta["doors"] if d["exterior"] and d["name"].endswith("_Entrance")][0]
        fy = rooms[ent["rooms"][1]]["floor_y"]
        grid = navcheck.FloorGrid(h.meta, fy, [f["footprint"] for f in fps])
        n = np.array(ent["normal"])
        start = (ent["center"][0] + n[0] * 0.55, ent["center"][2] + n[1] * 0.55)
        targets = [(f"room {r['id']}", None) for r in h.meta["rooms"] if abs(r["floor_y"] - fy) < 0.06] + [(nm, (x, z)) for nm, x, z in L["nav"]]
        ok, bad = 0, []
        for nm, p in targets:
            if p is None:
                r = rooms[nm.split()[1]]
                x0, z0, x1, z1 = r["rect"]
                best = None
                for xx in np.linspace(x0 + 0.5, x1 - 0.5, 9):
                    for zz in np.linspace(z0 + 0.5, z1 - 0.5, 9):
                        c_ = grid.cell((xx, zz))
                        if grid.w[c_]:
                            dd = (xx - (x0 + x1) / 2) ** 2 + (zz - (z0 + z1) / 2) ** 2
                            if best is None or dd < best[0]:
                                best = (dd, (xx, zz))
                if best is None:
                    bad.append(nm + " (no free floor)")
                    continue
                p = best[1]
            elif p[1] < 0.0:            # outdoor targets (in front of the entrance) are the start itself
                ok += 1
                continue
            c_ = grid.cell(p)
            if not grid.w[c_]:
                nb = grid.nearest_free(c_, rmax=4)
                if nb is None:
                    bad.append(nm + " (blocked)")
                    continue
            path = grid.path(start, p)
            if path is None:
                bad.append(nm)
            else:
                ok += 1
        if bad:
            F(f"{L['id']}: not walkable from the entrance to {bad}")
        st = "pass" if len(fails) == nf else "FAIL"
        rows.append(f"| {L['id']} | P{L['priority']} | {len(h.meta['rooms'])} | {sum(1 for d in h.meta['doors'] if d['exterior'])} | {len(L['fixtures'])} | "
                    f"{ok}/{len(targets)} | {L['lights']} | {st} |")
        info.append(f"{L['id']}: {len(h.meta['rooms'])} rooms, {len(L['fixtures'])} fixtures, walk paths {ok}/{len(targets)} from outside the entrance")
    # references + gallery
    nref = 0
    for root, _, fs in os.walk(P4):
        if "Source_Scripts" in root:
            continue
        for f in fs:
            if f.endswith((".tscn", ".tres", ".import")):
                for r in re.findall(r'res://(THE_VEIL_ASSETS_V2/[^"\n]+)', open(os.path.join(root, f)).read()):
                    nref += 1
                    if not os.path.exists(os.path.join(REPO, r)):
                        F(f"{f}: broken reference {r}")
    info.append(f"res:// references checked: {nref}")
    idx = open(os.path.join(REPO, "docs", "index.html")).read()
    miss = [m["glb"] for m in models if ("THE_VEIL_ASSETS_V2/" + m["glb"]) not in idx]
    if miss:
        F(f"gallery: {len(miss)} Pack 04 GLBs missing")
    info.append(f"gallery lists {len(models) - len(miss)}/{len(models)} Pack 04 GLBs; Pack 04 filter: {'pack04' in open(os.path.join(REPO, 'docs', 'gallery.js')).read()}")
    if args.gltf_validator:
        code = r"""const v=require('gltf-validator'),fs=require('fs');const files=JSON.parse(fs.readFileSync(0,'utf8'));
(async()=>{const o={};for(const f of files){const r=await v.validateBytes(new Uint8Array(fs.readFileSync(f)));o[f]={e:r.issues.numErrors,w:r.issues.numWarnings,m:r.issues.messages.filter(x=>x.severity<=1).slice(0,3).map(x=>x.code)};}console.log(JSON.stringify(o));})();"""
        r = subprocess.run(["node", "-e", code], input=json.dumps([os.path.join(V2, m["glb"]) for m in models]), capture_output=True, text=True, cwd=args.gltf_validator, timeout=900)
        out = json.loads(r.stdout)
        info.append(f"Khronos glTF-Validator: {len(out)} files, {sum(v['e'] for v in out.values())} errors, {sum(v['w'] for v in out.values())} warnings")
        for f, v in out.items():
            if v["e"]:
                F(f"Khronos {os.path.basename(f)}: {v['m']}")
            elif v["w"]:
                W(f"Khronos {os.path.basename(f)}: {v['m']}")
    if args.godot:
        proj = args.godot_project
        dst = os.path.join(proj, "THE_VEIL_ASSETS_V2", "04_Commercial")
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        shutil.copytree(P4, dst, ignore=shutil.ignore_patterns("__pycache__", "Source_Scripts"))
        r = subprocess.run([args.godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=2400)
        errs = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "WARNING" in l) and "leaked" not in l]
        info.append(f"Godot 4.3 headless import: exit {r.returncode}, {len(errs)} error/warning lines")
        for l in errs[:8]:
            F("Godot import: " + l.strip()[:200])
        scenes = ["res://THE_VEIL_ASSETS_V2/" + L["scene"] for L in locs]
        open(os.path.join(proj, "com_check.gd"), "w").write(GD.replace("__SCENES__", json.dumps(scenes)))
        r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 640x360x24", args.godot, "--path", proj, "--rendering-driver", "opengl3",
                            "--script", "res://com_check.gd"], capture_output=True, text=True, timeout=2400)
        out = r.stdout + r.stderr
        api = [l for l in out.splitlines() if l.startswith("OpenGL API")]
        info.append("renderer: " + (api[0] if api else "?"))
        for l in [l for l in out.splitlines() if re.search(r"SCRIPT ERROR|SHADER ERROR|ERROR:", l) and "ERR_CANT_OPEN" not in l and "leaked" not in l][:10]:
            F("Godot runtime: " + l.strip()[:200])
        sc = [l for l in out.splitlines() if l.startswith("CHECK")]
        for l in sc:
            if l.startswith("CHECK FAIL"):
                F("Godot " + l)
            elif l.startswith("CHECK SCENE"):
                m_ = re.search(r"CHECK SCENE (\S+) nav=(\d+)/(\d+) door=(\d+) bad_nav=(\S*) bad_door=(\S*) shapes=(\d+) lights=(\d+)", l)
                info.append(f"Godot {m_.group(1)}: floor collision under {m_.group(2)}/{m_.group(3)} nav targets, {m_.group(4)} exterior doorways clear, "
                            f"{m_.group(7)} collision shapes, {m_.group(8)} lights")
                if m_.group(2) != m_.group(3) or m_.group(6):
                    F(f"Godot {m_.group(1)}: nav without floor [{m_.group(5)}] / blocked doorways [{m_.group(6)}]")
            elif l.startswith("CHECK TOWN"):
                info.append("Godot: " + l[6:] + " (Greyhaven_Town_Complete.tscn = Pack 02 town + Pack 03 houses + Pack 04 commercial, rendered)")
        if not any(l.startswith("CHECK TOWN") for l in sc):
            F("Godot: complete-town scene did not finish")
    else:
        W("Godot check not run")
    L_ = ["# THE VEIL - Pack 04 Validation Report", "",
          "Automated file, architecture, walkability and engine checks only. **Nothing was captured from the renderer** (no screenshots), "
          "so the look of the stores has not been verified.", "",
          f"**Result: {'PASS' if not fails else 'FAIL'}** - {len(fails)} failures, {len(warns)} warnings", ""] + [f"* {i}" for i in info]
    L_ += ["", "## Locations", "", "| Location | Priority | Rooms | Exterior doors | Fixtures | Walk paths | Lights | Status |", "|---|---|---|---|---|---|---|---|"] + rows
    L_ += ["", "## Failures", ""] + ([f"* {f}" for f in fails] or ["None."]) + ["", "## Warnings", ""] + ([f"* {w}" for w in warns] or ["None."])
    open(os.path.join(P4, "Documentation", "VALIDATION_REPORT.md"), "w", newline="\n").write("\n".join(L_) + "\n")
    print(f"{'PASS' if not fails else 'FAIL'}: {len(fails)} failures, {len(warns)} warnings")
    for x in info:
        print(" ", x)
    for x in (fails + warns)[:60]:
        print("  !", x)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
