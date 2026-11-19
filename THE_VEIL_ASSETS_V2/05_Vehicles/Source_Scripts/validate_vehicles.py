#!/usr/bin/env python3
"""THE VEIL - Pack 05 focused validation (no rendering output, no screenshots).

    python3 05_Vehicles/Source_Scripts/validate_vehicles.py [--gltf-validator DIR] [--godot BIN --godot-project DIR]
        (the Godot project must already contain Packs 01/02/03/09 + Materials_Godot; Pack 05 is copied in)

Static: GLB structure (Pack 02 checker: accessors, unit normals agreeing with winding, no degenerate triangles), embedded
atlas, .import remaps to the shared .tres, UVs inside the (non-repeating) atlas, palette lock, unique names, gallery
listing. Vehicle structure: separate wheel nodes with the mesh centred on the pivot and the tyre touching y = 0, wheels
inside the body width, hinge-edge pivots for doors / hood / trunk / tailgate / rear doors, steering-wheel pivot,
seat / camera / entry / light markers, forward = -Z, plausible scale, collision boxes covering the body.
Engine: Godot 4.3 headless import, then a gl_compatibility run (xvfb + opengl3) that instances every GLB and scene for
a few frames and checks node organisation. Writes Documentation/VALIDATION_REPORT.md.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
REPO = os.path.dirname(V2)
PK = os.path.join(V2, "05_Vehicles")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
import validate_town as VT  # noqa: E402

fails, warns, info = VT.fails, VT.warns, VT.info
F, W = VT.F, VT.W

REQ_MARKERS = ["Marker_Seat_Driver", "Marker_Seat_Passenger", "Marker_Camera_FirstPerson", "Marker_Entry_Driver", "Marker_Entry_Passenger",
               "Marker_Headlight_L", "Marker_Headlight_R", "Marker_Taillight_L", "Marker_Taillight_R"]
SEDAN_PARTS = ["Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR", "SteeringWheel", "Door_FL", "Door_FR", "Door_RL", "Door_RR", "Hood", "Trunk"]

GD = r'''extends SceneTree
const ROOT = "res://THE_VEIL_ASSETS_V2/05_Vehicles/"
func list(dir: String, ext: String) -> Array:
	var out = []
	var d = DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + f)
	for s in d.get_directories():
		if s != "Source_Scripts":
			out += list(dir + s + "/", ext)
	return out
func frames(n):
	for i in n:
		await process_frame
func _initialize():
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(5, 2.5, 7)
	cam.look_at_from_position(cam.position, Vector3(0, 0.8, 0))
	cam.make_current()
	for p in list(ROOT, ".glb"):
		var ps = load(p)
		if ps == null:
			print("CHECK FAIL load ", p); continue
		var n = ps.instantiate(); root.add_child(n); await frames(1)
		var mats = {}
		var meshes = 0
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			meshes += 1
			for s in mi.mesh.get_surface_count():
				var m = mi.get_active_material(s)
				mats[m.resource_path if m else "none"] = true
		var cols = n.find_children("*", "CollisionShape3D", true, false).size()
		var wheels = 0
		for w in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
			var wn = n.find_child(w, true, false)
			if wn and wn is MeshInstance3D:
				wheels += 1
		print("CHECK GLB %s meshes=%d wheels=%d cols=%d mats=%s" % [p.get_file(), meshes, wheels, cols, ",".join(mats.keys())])
		n.queue_free()
	for p in list(ROOT, ".tscn"):
		var ps = load(p)
		if ps == null:
			print("CHECK FAIL load ", p); continue
		var n = ps.instantiate(); root.add_child(n); await frames(3)
		var extra = ""
		if p.ends_with("Protagonist_Sedan.tscn"):
			var mk = n.find_child("Marker_Camera_FirstPerson", true, false)
			var dc = n.get_node("DriverCamera")
			extra = " cam_offset=%.4f lights=%d areas=%d" % [mk.global_position.distance_to(dc.global_position), n.get_node("Lights").get_child_count(), n.find_children("*", "Area3D", true, false).size()]
			# movable parts respond to rotation about their pivots
			var door = n.find_child("Door_FL", true, false)
			var before = door.global_position
			door.rotate_object_local(Vector3.UP, deg_to_rad(-60))
			n.find_child("Hood", true, false).rotate_object_local(Vector3.RIGHT, deg_to_rad(40))
			n.find_child("Wheel_FL", true, false).rotate_object_local(Vector3.UP, deg_to_rad(25))
			n.find_child("SteeringWheel", true, false).rotate_object_local(Vector3.BACK, deg_to_rad(90))
			await frames(2)
			extra += " hinge_fixed=%s" % str(before.distance_to(door.global_position) < 0.0001)
		print("CHECK SCENE ", p.get_file(), extra)
		n.queue_free(); await frames(1)
	quit()
'''


def node_world(js):
    """node index -> (translation incl. parents, has_rotation)"""
    out = {}

    def walk(i, t, rot):
        n = js["nodes"][i]
        t2 = t + np.asarray(n.get("translation", [0, 0, 0]), float)
        r2 = rot or ("rotation" in n)
        out[i] = (t2, r2)
        for c in n.get("children", []):
            walk(c, t2, r2)
    for r in js["scenes"][0]["nodes"]:
        walk(r, np.zeros(3), False)
    return out


def mesh_bounds(js, binb, mi, col=False):
    P = [VT.accessor(js, binb, p["attributes"]["POSITION"]) for p in js["meshes"][mi]["primitives"] if col or "material" in p]
    P = np.concatenate(P)
    return P.min(0), P.max(0)


def qm(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)], [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def vehicle_tris(js, binb):
    """all render triangles in vehicle space (root children: translation + rotation applied)"""
    out = []
    root = js["scenes"][0]["nodes"][0]
    for ci in js["nodes"][root].get("children", []):
        n = js["nodes"][ci]
        if "mesh" not in n or "colonly" in n["name"]:
            continue
        t = np.asarray(n.get("translation", [0, 0, 0]), float)
        Rm = qm(n["rotation"]) if "rotation" in n else np.eye(3)
        for p in js["meshes"][n["mesh"]]["primitives"]:
            if "material" in p:
                P = VT.accessor(js, binb, p["attributes"]["POSITION"]) @ Rm.T + t
                I = VT.accessor(js, binb, p["indices"]).reshape(-1, 3)
                out.append((n["name"], js["materials"][p["material"]]["name"], P[I]))
    return out


def cast(T, o, d):
    hits = []
    for part, mat, tr in T:
        e1, e2 = tr[:, 1] - tr[:, 0], tr[:, 2] - tr[:, 0]
        h = np.cross(d, e2)
        a = (e1 * h).sum(1)
        ok = np.abs(a) > 1e-12
        f = np.where(ok, 1 / np.where(ok, a, 1), 0)
        s = o - tr[:, 0]
        u = f * (s * h).sum(1)
        q = np.cross(s, e1)
        v = f * (q * d).sum(1)
        t = f * (e2 * q).sum(1)
        m = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-4)
        hits += [(float(x), part, mat) for x in t[m]]
    return sorted(hits)


def sightlines(js, binb, m, world, byname):
    """driver's view from Marker_Camera_FirstPerson (geometric ray casts, not a render)"""
    T = vehicle_tris(js, binb)
    root = js["scenes"][0]["nodes"][0]
    eye = world[byname["Marker_Camera_FirstPerson"]][0] - world[root][0]
    res = {}
    d = nrm_(V_(0, -0.06, -1))
    h = cast(T, eye, d)
    opaque = [x for x in h if "Glass" not in x[2]]
    res["road ahead"] = bool(h) and "Glass" in h[0][2] and (not opaque or opaque[0][0] > 1.5)
    tg = m["sight_targets"]
    for key in ("cluster", "mirror"):
        p = np.asarray(tg[key], float)
        dist = np.linalg.norm(p - eye)
        h = cast(T, eye, nrm_(p - eye))
        res[key] = bool(h) and h[0][1] == "Body" and h[0][0] > dist - 0.08
    p = np.asarray(tg["wheel_hub"], float)
    h = cast(T, eye, nrm_(p - eye))
    res["steering wheel"] = bool(h) and h[0][1] == "SteeringWheel"
    hp = world[byname["Hood"]][0] - world[root][0]
    hmn, _ = mesh_bounds(js, binb, js["nodes"][byname["Hood"]]["mesh"])
    h = cast(T, eye, nrm_(V_(eye[0], hp[1] - 0.05, hp[2] + 0.5 * hmn[2]) - eye))       # middle of the hood
    opaque = [x for x in h if "Glass" not in x[2]]
    res["hood over the wheel"] = bool(opaque) and opaque[0][1] == "Hood"
    h = cast(T, eye, nrm_(V_(-1, 0.02, -0.15)))
    res["left side window"] = bool(h) and "Glass" in h[0][2]
    return res


def nrm_(v):
    return v / np.linalg.norm(v)


def V_(*a):
    return np.array(a, float)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator")
    ap.add_argument("--godot")
    ap.add_argument("--godot-project")
    a = ap.parse_args()
    man = json.load(open(os.path.join(PK, "Documentation", "VEHICLE_MANIFEST.json")))
    models = man["models"]
    names = [m["name"] for m in models]
    others = set()
    for root, _, fs in os.walk(V2):
        if "05_Vehicles" not in root:
            others |= {f[:-4] for f in fs if f.endswith(".glb")}
    clash = sorted(set(names) & others) + sorted({n for n in names if names.count(n) > 1})
    if clash:
        F(f"GLB names collide: {clash}")
    info.append(f"GLB names unique across the repository: {not clash}")
    # palette
    from PIL import Image
    from chr_tex import P as PAL
    pal = {tuple(c) for c in PAL.rgb.tolist()}
    for t in man["textures"]:
        im = np.asarray(Image.open(os.path.join(V2, t)).convert("RGB")).reshape(-1, 3)
        off = {tuple(x) for x in im.tolist()} - pal
        if off:
            F(f"{t}: {len(off)} colours outside the Greyhaven palette")
        if not os.path.exists(os.path.join(V2, t) + ".import"):
            F(f"{t}: .import missing")
    info.append(f"atlases palette-locked: {', '.join(os.path.basename(t) for t in man['textures'])}")
    for mname in man["materials"]:
        t = open(os.path.join(PK, "Shared_Materials", mname + ".tres")).read()
        if "texture_filter = 2" not in t or "texture_repeat = false" not in t:
            F(f"{mname}.tres: not nearest-filtered / non-repeating")
    # per model
    status = {}
    sight_ok = []
    for m in models:
        nf = len(fails)
        glb = os.path.join(V2, m["glb"])
        if not os.path.exists(glb) or not os.path.exists(glb + ".import"):
            F(f"{m['name']}: GLB or .import missing")
            continue
        js, _ = VT.check_glb(glb)
        _, binb = VT.read_glb(glb)
        if any("uri" in im for im in js.get("images", [])) or not js.get("images"):
            F(f"{m['name']}: atlas not embedded")
        imp = open(glb + ".import").read()
        for mat in m["materials"]:
            if f"05_Vehicles/Shared_Materials/{mat}.tres" not in imp:
                F(f"{m['name']}: .import does not remap {mat}")
        for mesh in js["meshes"]:
            for p in mesh["primitives"]:
                if "TEXCOORD_0" in p["attributes"]:
                    uv = VT.accessor(js, binb, p["attributes"]["TEXCOORD_0"])
                    if uv.min() < -1e-5 or uv.max() > 1 + 1e-5:
                        F(f"{m['name']}: UVs outside the atlas")
        byname = {n["name"]: i for i, n in enumerate(js["nodes"])}
        world = node_world(js)
        cols = [n for n in byname if n.endswith("-convcolonly")]
        if not cols:
            F(f"{m['name']}: no collision")
        if m["category"] == "transportation prop":
            status[m["name"]] = "pass" if len(fails) == nf else "FAIL"
            continue
        # ---- vehicle structure
        req = SEDAN_PARTS if m["name"].startswith(("VEH_ProtagonistSedan", "VEH_Sedan", "VEH_PoliceCruiser")) else \
            ["Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR", "SteeringWheel", "Door_FL", "Door_FR", "Hood"]
        if "Pickup" in m["name"]:
            req = req + ["Tailgate"]
        if "Van" in m["name"]:
            req = req + ["RearDoor_L", "RearDoor_R"]
        for r in req + REQ_MARKERS:
            if r not in byname:
                F(f"{m['name']}: missing node {r}")
        meshes_used = [js["nodes"][byname[w]].get("mesh") for w in ("Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR") if w in byname]
        if len(set(meshes_used)) != 4 or None in meshes_used:
            F(f"{m['name']}: wheels are not 4 separate meshes")
        flat = "Abandoned" in m["name"] and "Pickup" in m["name"]
        bmn, bmx = mesh_bounds(js, binb, js["nodes"][byname["Body"]]["mesh"])
        for w in ("Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"):
            i = byname[w]
            mn, mx = mesh_bounds(js, binb, js["nodes"][i]["mesh"])
            c = (mn + mx) / 2
            t = world[i][0]
            r = (mx[1] - mn[1]) / 2
            if abs(c[0]) > 0.005 or abs(c[2]) > 0.005 or (not flat and abs(c[1]) > 0.005):
                F(f"{m['name']} {w}: mesh not centred on its pivot {c.round(4)}")
            ground = t[1] + mn[1]
            if abs(ground) > 0.006:
                F(f"{m['name']} {w}: tyre bottom at y={ground:.3f}, not on the ground")
            if abs(t[0]) + (mx[0] - mn[0]) / 2 > max(abs(bmn[0]), abs(bmx[0])) + 0.002:
                F(f"{m['name']} {w}: wheel sticks out of the body width")
            if (w[-2] == "F") != (t[2] < 0) or (w[-1] == "L") != (t[0] < 0):
                F(f"{m['name']} {w}: wheel placed on the wrong corner (forward must be -Z, left = -X)")
        # hinge pivots: geometry must lie on the opening side of the pivot (rest pose nodes only)
        for nm, axis, side in (("Door_FL", 2, 1), ("Door_FR", 2, 1), ("Door_RL", 2, 1), ("Door_RR", 2, 1), ("Hood", 2, -1), ("Trunk", 2, 1),
                               ("RearDoor_L", 0, 1), ("RearDoor_R", 0, -1), ("Tailgate", 1, 1)):
            if nm not in byname or "rotation" in js["nodes"][byname[nm]]:
                continue
            mn, mx = mesh_bounds(js, binb, js["nodes"][byname[nm]]["mesh"])
            lo, hi = (mn[axis], mx[axis]) if side > 0 else (-mx[axis], -mn[axis])
            if lo < -0.03 or hi < 0.2:
                F(f"{m['name']} {nm}: pivot is not on the hinge edge (local extent {lo:.3f}..{hi:.3f} on axis {'xyz'[axis]})")
        sw = js["nodes"][byname["SteeringWheel"]]
        mn, mx = mesh_bounds(js, binb, sw["mesh"])
        if np.abs((mn + mx) / 2)[:2].max() > 0.01 or "rotation" not in sw:
            F(f"{m['name']}: steering wheel not centred on a tilted column pivot")
        # scale / orientation / markers
        L, Wd, H = m["size_m"][2], bmx[0] - bmn[0], m["size_m"][1]
        if not (4.0 <= L <= 5.9 and 1.6 <= Wd <= 2.1 and 1.3 <= H <= 2.4):
            F(f"{m['name']}: implausible size L{L} W{Wd:.2f} H{H}")
        mk = {n: world[byname[n]][0] for n in REQ_MARKERS if n in byname}
        root_t = world[js["scenes"][0]["nodes"][0]][0]
        if mk and not (mk["Marker_Headlight_L"][2] < 0 < mk["Marker_Taillight_L"][2]):
            F(f"{m['name']}: lights not front = -Z / rear = +Z")
        if mk:
            cam = mk["Marker_Camera_FirstPerson"] - root_t
            seat = mk["Marker_Seat_Driver"] - root_t
            if not (cam[0] < 0 and seat[0] < 0 and bmn[1] < cam[1] < bmx[1] - 0.05 and abs(cam[0]) < bmx[0]):
                F(f"{m['name']}: first-person camera / driver seat marker outside the cabin or not left-hand drive")
            if not (0.5 < cam[1] - seat[1] < 0.8):
                F(f"{m['name']}: camera height above the seat implausible ({cam[1] - seat[1]:.2f} m)")
        if "sight_targets" in m and "Door_FL" in byname and "rotation" not in js["nodes"][byname["Door_FL"]]:
            sl = sightlines(js, binb, m, world, byname)
            bad = [k for k, ok_ in sl.items() if not ok_]
            if bad:
                F(f"{m['name']}: driver cannot see {bad} from the first-person camera marker")
            sight_ok.append(m["name"])
        cb = [mesh_bounds(js, binb, js["nodes"][byname[c]]["mesh"], col=True) for c in cols]
        cmn, cmx = np.min([c[0] for c in cb], axis=0), np.max([c[1] for c in cb], axis=0)
        cov = np.prod(np.minimum(cmx, bmx) - np.maximum(cmn, bmn)) / np.prod(bmx - bmn)
        if cov < 0.75:
            F(f"{m['name']}: collision covers only {cov:.0%} of the body bounds")
        status[m["name"]] = "pass" if len(fails) == nf else "FAIL"
    info.append(f"driver sightlines (ray casts from the eye marker: road through the windshield, hood over the wheel rim, cluster past the wheel hub, steering wheel, "
                f"rear-view mirror, left window) checked on {len(sight_ok)} vehicles with closed driver doors")
    info.append(f"GLBs checked: {len(models)} ({sum(1 for m in models if m['category'] != 'transportation prop')} vehicles), "
                f"triangles total {sum(m['triangles'] for m in models)}")
    # reuse + scenes + references
    nref = 0
    for root, _, fs in os.walk(PK):
        if "Source_Scripts" in root:
            continue
        for f in fs:
            if f.endswith((".tscn", ".tres", ".import")):
                t = open(os.path.join(root, f)).read()
                for r in re.findall(r'res://(THE_VEIL_ASSETS_V2/[^"\n]+)', t):
                    nref += 1
                    if not os.path.exists(os.path.join(REPO, r)):
                        F(f"{f}: broken reference {r}")
                if re.search(r"VehicleBody3D|GPUParticles3D|\bDecal\b", t):
                    W(f"{f}: uses a feature outside the requested scope / Compatibility renderer")
    for r in man["reused_props"]:
        if not os.path.exists(os.path.join(V2, r["source"])):
            F(f"reused prop missing: {r['source']}")
    info.append(f"res:// references checked: {nref}; reused props present: {len(man['reused_props'])}")
    # gallery
    idx = open(os.path.join(REPO, "docs", "index.html")).read()
    missing = [m["glb"] for m in models if ("THE_VEIL_ASSETS_V2/" + m["glb"]) not in idx]
    if missing:
        F(f"gallery: {len(missing)} Pack 05 GLBs not listed")
    js_ = open(os.path.join(REPO, "docs", "gallery.js")).read()
    if "pack05" not in js_:
        F("gallery: no Pack 05 filter")
    info.append(f"gallery lists {len(models) - len(missing)}/{len(models)} Pack 05 GLBs, Pack 05 filter present: {'pack05' in js_}")
    if a.gltf_validator:
        code = r"""const v=require('gltf-validator'),fs=require('fs');const files=JSON.parse(fs.readFileSync(0,'utf8'));
(async()=>{const o={};for(const f of files){const r=await v.validateBytes(new Uint8Array(fs.readFileSync(f)));o[f]={e:r.issues.numErrors,w:r.issues.numWarnings,m:r.issues.messages.filter(x=>x.severity<=1).slice(0,3).map(x=>x.code)};}console.log(JSON.stringify(o));})();"""
        r = subprocess.run(["node", "-e", code], input=json.dumps([os.path.join(V2, m["glb"]) for m in models]), capture_output=True, text=True,
                           cwd=a.gltf_validator, timeout=600)
        out = json.loads(r.stdout)
        info.append(f"Khronos glTF-Validator: {len(out)} files, {sum(v['e'] for v in out.values())} errors, {sum(v['w'] for v in out.values())} warnings")
        for f, v in out.items():
            if v["e"]:
                F(f"Khronos {os.path.basename(f)}: {v['m']}")
            elif v["w"]:
                W(f"Khronos {os.path.basename(f)}: {v['m']}")
    if a.godot:
        proj = a.godot_project
        dst = os.path.join(proj, "THE_VEIL_ASSETS_V2", "05_Vehicles")
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        shutil.copytree(PK, dst, ignore=shutil.ignore_patterns("__pycache__", "Source_Scripts"))
        r = subprocess.run([a.godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=1800)
        errs = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "WARNING" in l) and "leaked" not in l]
        info.append(f"Godot 4.3 headless import: exit {r.returncode}, {len(errs)} error/warning lines")
        for l in errs[:8]:
            F("Godot import: " + l.strip()[:200])
        open(os.path.join(proj, "veh_check.gd"), "w").write(GD)
        r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 640x360x24", a.godot, "--path", proj, "--rendering-driver", "opengl3",
                            "--script", "res://veh_check.gd"], capture_output=True, text=True, timeout=1800)
        out = r.stdout + r.stderr
        api = [l for l in out.splitlines() if l.startswith("OpenGL API")]
        info.append("renderer: " + (api[0] if api else "?"))
        bad = [l for l in out.splitlines() if re.search(r"SCRIPT ERROR|SHADER ERROR|ERROR:", l) and "ERR_CANT_OPEN" not in l and "leaked" not in l]
        for l in bad[:10]:
            F("Godot runtime: " + l.strip()[:200])
        lines = [l for l in out.splitlines() if l.startswith("CHECK")]
        ok = 0
        for l in lines:
            if l.startswith("CHECK FAIL"):
                F("Godot " + l)
            elif l.startswith("CHECK GLB"):
                kv = dict(x.split("=", 1) for x in l.split()[3:])
                nm = l.split()[2][:-4]
                veh = nm.startswith("VEH_")
                if int(kv["cols"]) < 1 or (veh and kv["wheels"] != "4") or "none" in kv["mats"] or "05_Vehicles/Shared_Materials" not in kv["mats"]:
                    F(f"Godot {nm}: wheels={kv['wheels']} collision shapes={kv['cols']} materials={kv['mats']}")
                else:
                    ok += 1
            elif l.startswith("CHECK SCENE"):
                if "Protagonist_Sedan" in l:
                    info.append("`" + l[6:] + "`")
                    m_ = re.search(r"cam_offset=([\d.]+).*hinge_fixed=(\w+)", l)
                    if not m_ or float(m_.group(1)) > 0.01 or m_.group(2) != "true":
                        F("Protagonist_Sedan.tscn: DriverCamera not on the marker or door does not rotate about its hinge")
        nsc = sum(1 for l in lines if l.startswith("CHECK SCENE"))
        info.append(f"Godot (gl_compatibility): {ok}/{len(models)} GLBs instanced with external Pack 05 materials, separate wheel nodes and collision; "
                    f"{nsc} scenes instanced and rendered")
        if ok != len(models):
            F(f"Godot: only {ok}/{len(models)} GLBs passed")
    else:
        W("Godot check not run")
    rows = ["| Asset | Category | Tris | Size (m) | Movable parts | Status |", "|---|---|---|---|---|---|"]
    for m in models:
        rows.append(f"| `{m['name']}` | {m['category']} | {m['triangles']} | {' x '.join(str(v) for v in m['size_m'])} | "
                    f"{', '.join(p['node'] for p in m['movable_parts']) or '-'} | {status.get(m['name'], '?')} |")
    L = ["# THE VEIL - Pack 05 Validation Report", "",
         "Automated file, structure and engine checks only. **Nothing was captured from the renderer** (no screenshots), so the "
         "look of the vehicles has not been verified.", "",
         f"**Result: {'PASS' if not fails else 'FAIL'}** - {len(fails)} failures, {len(warns)} warnings", ""] + [f"* {i}" for i in info]
    L += ["", "## Assets", ""] + rows
    L += ["", "## Failures", ""] + ([f"* {f}" for f in fails] or ["None."]) + ["", "## Warnings", ""] + ([f"* {w}" for w in warns] or ["None."])
    open(os.path.join(PK, "Documentation", "VALIDATION_REPORT.md"), "w", newline="\n").write("\n".join(L) + "\n")
    print(f"{'PASS' if not fails else 'FAIL'}: {len(fails)} failures, {len(warns)} warnings")
    for x in info:
        print(" ", x)
    for x in (fails + warns)[:40]:
        print("  !", x)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
