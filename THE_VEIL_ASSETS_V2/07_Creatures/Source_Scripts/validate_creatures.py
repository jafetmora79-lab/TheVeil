"""THE VEIL - Pack 07 validator.

    python3 07_Creatures/Source_Scripts/validate_creatures.py [--gltf-validator DIR] [--godot BIN --godot-project DIR]

Everything is re-read from the written files (not from the builder's memory):
  * GLB integrity / topology (validate_town.check_glb: header, accessor ranges, unit normals, no degenerate or
    inside-out triangles), UV ranges (atlas materials inside 0..1), skin (joint names / parents = manifest,
    identity rest rotations, inverse bind matrices, 4 weights summing to 1, joint indices in range),
  * textures: embedded images = the PNGs the .tres use, albedo palette-locked (cr_tex palette), emission masks
    black or "crt_glow" only and sparse, lossless PNG imports, nearest filtering, .glb.import remaps every
    material to its .tres, imports every clip with every bone track kept and the right loop mode,
  * animation: every manifest clip present, unit quaternions, looping clips seamless; then each clip is
    re-sampled from the GLB's own keyframes and the mesh is skinned (LBS) on every key: ground penetration and
    edge stretch must stay inside the creature's limits,
  * Godot scenes (.tscn) and gallery integration (docs/index.html + docs/gallery.js),
  * optional: Khronos glTF-Validator, Godot 4.3 headless import + inspection, and a Compatibility-renderer
    (OpenGL 3, xvfb) run that instantiates every scene and plays every clip. No screenshots are taken.
Writes 07_Creatures/Documentation/VALIDATION_REPORT.md; exit code 1 on any failure.
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
sys.path.insert(0, HERE)
import cr_core as C  # noqa: E402
import cr_tex as X  # noqa: E402
import validate_town as VT  # noqa: E402

DOC = os.path.join(C.CR, "Documentation")
fails, warns = [], []


def F(m):
    fails.append(m)


def W(m):
    warns.append(m)


def acc(js, binb, i):
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    cnt = a["count"] * n
    if off + cnt * np.dtype(dt).itemsize > v.get("byteOffset", 0) + v["byteLength"]:
        raise ValueError("accessor out of range")
    arr = np.frombuffer(binb[off:off + cnt * np.dtype(dt).itemsize], dtype=dt)
    return arr.reshape(-1, n) if n > 1 else arr


def img_bytes(js, binb, tex_index):
    im = js["images"][js["textures"][tex_index]["source"]]
    bv = js["bufferViews"][im["bufferView"]]
    return bytes(binb[bv["byteOffset"]:bv["byteOffset"] + bv["byteLength"]])


def tres_info(path):
    t = open(path).read()
    tex = dict(re.findall(r'path="res://THE_VEIL_ASSETS_V2/([^"]+)" id="(\w+)"', t))
    alb = [p for p, i in tex.items() if i == "1_albedo"]
    emi = [p for p, i in tex.items() if i == "2_emit"]
    return {"albedo": alb[0] if alb else None, "emit": emi[0] if emi else None, "filter": "texture_filter = 2" in t,
            "repeat": "texture_repeat = true" in t, "emission": "emission_enabled = true" in t}


# ------------------------------------------------------------------ GLB checks
def check_model(name, m):
    glb = os.path.join(C.V2, m["glb"])
    res = {"name": name, "glb": m["glb"]}
    if not os.path.exists(glb) or not os.path.exists(glb + ".import"):
        F(f"{name}: GLB or .import missing")
        return res, None
    js, st = VT.check_glb(glb)
    _, binb = VT.read_glb(glb)
    res["tris"] = st["tris"]
    if st["tris"] != m["triangles"]:
        F(f"{name}: triangle count {st['tris']} != manifest {m['triangles']}")
    imp = open(glb + ".import").read()
    for need in ("animation/import=true", "animation/remove_immutable_tracks=false", "animation/trimming=false"):
        if need not in imp:
            F(f"{name}: .glb.import lacks {need}")
    # skin
    sk = js["skins"][0]
    names = [js["nodes"][j]["name"] for j in sk["joints"]]
    if names != m["bone_names"]:
        F(f"{name}: skin joints differ from the manifest skeleton")
    parent = {}
    for k, nd in enumerate(js["nodes"]):
        for ch in nd.get("children", []):
            parent[ch] = k
    world = {}

    def wpos(k):
        if k not in world:
            nd = js["nodes"][k]
            if "rotation" in nd or "scale" in nd:
                F(f"{name}: joint {nd['name']} has a rest rotation/scale (expected identity)")
            world[k] = np.array(nd.get("translation", [0, 0, 0]), float) + (wpos(parent[k]) if k in parent else 0)
        return world[k]
    J = {names[q]: wpos(j) for q, j in enumerate(sk["joints"])}
    jset = set(sk["joints"])
    par = {}
    for q, j in enumerate(sk["joints"]):
        p = parent.get(j)
        par[names[q]] = js["nodes"][p]["name"] if (p is not None and p in jset) else None
        if q > 0 and p not in jset:
            F(f"{name}: bone {names[q]} is not parented inside the skeleton")
    IBM = acc(js, binb, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    for q, b in enumerate(names):
        G_ = np.eye(4)
        G_[:3, 3] = J[b]
        if np.abs(IBM[q] @ G_ - np.eye(4)).max() > 1e-4:
            F(f"{name}: inverse bind matrix of {b} is not the inverse rest transform")
    # primitives
    mats = js["materials"]
    allP, allJ, allW, allI, off = [], [], [], [], 0
    used = set()
    for prim in js["meshes"][0]["primitives"]:
        at = prim["attributes"]
        P = acc(js, binb, at["POSITION"]).astype(float)
        Jt = acc(js, binb, at["JOINTS_0"]).astype(int)
        Wt = acc(js, binb, at["WEIGHTS_0"]).astype(float)
        UV = acc(js, binb, at["TEXCOORD_0"])
        I = acc(js, binb, prim["indices"]).reshape(-1, 3)
        mat = mats[prim["material"]]
        if Jt.max() >= len(names):
            F(f"{name}: joint index out of range")
        if np.abs(Wt.sum(1) - 1).max() > 1e-3 or (Wt < -1e-6).any():
            F(f"{name}: skin weights not normalised / negative")
        tres = os.path.join(C.CR, "Shared_Materials", mat["name"] + ".tres")
        if not os.path.exists(tres):
            F(f"{name}: material {mat['name']} has no .tres")
            continue
        ti = tres_info(tres)
        if not ti["filter"]:
            F(f"{mat['name']}.tres: not nearest-filtered (texture_filter = 2)")
        if not ti["repeat"] and (UV.min() < -1e-6 or UV.max() > 1 + 1e-6):
            F(f"{name}: {mat['name']} (atlas, clamped) has UVs outside 0..1")
        if not np.isfinite(UV).all():
            F(f"{name}: non-finite UVs")
        if f'"{mat["name"]}"' not in imp or C.res_of(tres) not in imp:
            F(f"{name}: .glb.import does not remap {mat['name']} to its .tres")
        # textures: embedded == files, palette lock, emission mask
        if mat["name"] not in used:
            used.add(mat["name"])
            check_textures(name, js, binb, mat, ti)
        allP.append(P)
        allJ.append(Jt)
        allW.append(Wt)
        allI.append(I + off)
        off += len(P)
    P, Jt, Wt, I = np.vstack(allP), np.vstack(allJ), np.vstack(allW), np.vstack(allI)
    wb = {names[j] for j in np.unique(Jt[Wt > 1e-4])}
    res["unweighted"] = [b for b in names if b not in wb]
    res["height"] = float(P[:, 1].max())
    res["extent"] = [round(float(x), 2) for x in (P.max(0) - P.min(0))]
    if P[:, 1].min() < -0.08:
        F(f"{name}: rest mesh goes {P[:, 1].min():.2f} m below the ground")
    # imported loop settings
    for c in m["clips"]:
        mm = re.search(r'"%s": \{\n"settings/loop_mode": (\d)' % re.escape(c["name"]), imp)
        if not mm or int(mm.group(1)) != (1 if c["loop"] else 0):
            F(f"{name}: .glb.import loop mode wrong/missing for {c['name']}")
    sockets = [js["nodes"][k]["name"] for k in range(len(js["nodes"])) if js["nodes"][k]["name"] in m["sockets"]]
    if sorted(sockets) != sorted(m["sockets"]):
        F(f"{name}: sockets missing {set(m['sockets']) - set(sockets)}")
    return res, dict(js=js, binb=binb, names=names, par=par, J=J, P=P, Jt=Jt, Wt=Wt, I=I)


def check_textures(name, js, binb, mat, ti):
    pal = X.palette_rgb()
    glow = X.glow_rgb() | {(0, 0, 0)}
    from PIL import Image
    import io
    pairs = [("albedo", mat["pbrMetallicRoughness"]["baseColorTexture"]["index"])]
    if "emissiveTexture" in mat:
        pairs.append(("emit", mat["emissiveTexture"]["index"]))
        if not ti["emission"]:
            F(f"{mat['name']}.tres: GLB has emission but the .tres does not enable it")
    for kind, tix in pairs:
        rel = ti[kind]
        if not rel:
            F(f"{mat['name']}.tres: no {kind} texture")
            continue
        path = os.path.join(C.V2, rel)
        if img_bytes(js, binb, tix) != open(path, "rb").read():
            F(f"{name}: embedded {kind} texture of {mat['name']} differs from {rel}")
        imp = path + ".import"
        if not os.path.exists(imp) or "compress/mode=0" not in open(imp).read():
            F(f"{rel}: .import missing or not lossless")
        im = np.asarray(Image.open(io.BytesIO(open(path, "rb").read())).convert("RGB")).reshape(-1, 3)
        cols = {tuple(int(x) for x in c) for c in np.unique(im, axis=0)}
        if kind == "albedo":
            bad = cols - pal
            if bad:
                F(f"{rel}: {len(bad)} colours outside the palette")
        else:
            bad = cols - glow
            if bad:
                F(f"{rel}: emission mask uses non-glow colours")
            lit = (im.sum(1) > 0).mean()
            if lit > 0.15:
                F(f"{rel}: emission covers {lit:.0%} of the texture (keep emissive detail subtle)")


# ------------------------------------------------------------------ animation from the GLB
def sample(times, vals, t, quat):
    if t <= times[0]:
        return vals[0]
    if t >= times[-1]:
        return vals[-1]
    k = int(np.searchsorted(times, t)) - 1
    u = (t - times[k]) / (times[k + 1] - times[k])
    a, b = vals[k], vals[k + 1]
    if quat and np.dot(a, b) < 0:
        b = -b
    v = a * (1 - u) + b * u
    return v / np.linalg.norm(v) if quat else v


def check_anims(name, m, g, res):
    js, binb, names = g["js"], g["binb"], g["names"]
    node_of = {js["nodes"][j]["name"]: j for j in js["skins"][0]["joints"]}
    bone_of = {j: n for n, j in node_of.items()}
    anims = {a["name"]: a for a in js.get("animations", [])}
    rig = C.Rig(name)
    for b in names:
        rig.add(b, g["par"][b], g["J"][b])
    E = None
    lim = m["limits"]
    res["clips"] = {}
    for c in m["clips"]:
        a = anims.get(c["name"])
        if a is None:
            F(f"{name}: clip {c['name']} missing from the GLB")
            continue
        tracks = {}
        tmax = 0.0
        for ch in a["channels"]:
            s = a["samplers"][ch["sampler"]]
            if s["interpolation"] != "LINEAR":
                F(f"{name}/{c['name']}: non-linear sampler")
            T = acc(js, binb, s["input"]).astype(float)
            V = acc(js, binb, s["output"]).astype(float)
            if ch["target"]["node"] not in bone_of:
                F(f"{name}/{c['name']}: channel targets a non-joint node")
                continue
            if ch["target"]["path"] == "rotation" and np.abs(np.linalg.norm(V, axis=1) - 1).max() > 1e-3:
                F(f"{name}/{c['name']}: non-unit quaternion")
            if (np.diff(T) <= 0).any():
                F(f"{name}/{c['name']}: keyframe times not increasing")
            tracks[(bone_of[ch["target"]["node"]], ch["target"]["path"])] = (T, V)
            tmax = max(tmax, float(T[-1]))
        if abs(tmax - c["duration_s"]) > 1e-3:
            F(f"{name}/{c['name']}: duration {tmax:.3f} != {c['duration_s']}")
        rot_bones = {b for (b, p) in tracks if p == "rotation"}
        if rot_bones != set(names):
            F(f"{name}/{c['name']}: not every bone has a rotation track ({len(rot_bones)}/{len(names)})")
        keys = sorted({float(t) for (T, _) in tracks.values() for t in T})
        if c["loop"]:
            for (b, p), (T, V) in tracks.items():
                d = abs(abs(float(np.dot(V[0], V[-1]))) - 1) if p == "rotation" else float(np.abs(V[0] - V[-1]).max())
                if d > 1e-4:
                    F(f"{name}/{c['name']}: loop not seamless on {b} {p}")
                    break
        P, Jt, Wt, I = g["P"], g["Jt"], g["Wt"], g["I"]
        if E is None:
            E = np.unique(np.sort(np.vstack([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]]), 1), axis=0)
            L0 = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
            keep = L0 > 1e-4
            E, L0 = E[keep], L0[keep]
            D0 = np.maximum(L0, m.get("edge_floor", 0.05))
        miny, mx, p999 = 1e9, 0.0, 0.0
        for t in keys:
            local, trans = {}, {}
            for (b, p), (T, V) in tracks.items():
                v = sample(T, V, t, p == "rotation")
                if p == "rotation":
                    local[b] = C.qmat(v)
                else:
                    pb = g["par"][b]
                    trans[b] = v - (g["J"][b] - (g["J"][pb] if pb else 0.0))
            D = rig.deform(P, Jt, Wt, local, trans)
            miny = min(miny, float(D[:, 1].min()))
            r = (np.linalg.norm(D[E[:, 0]] - D[E[:, 1]], axis=1) - L0) / D0 + 1
            mx = max(mx, float(r.max()))
            p999 = max(p999, float(np.percentile(r, 99.9)))
        death = "death" in c["name"].lower()
        res["clips"][c["name"]] = dict(keys=len(keys), min_y=round(miny, 3), stretch=round(mx, 2), p999=round(p999, 2))
        if miny < lim["min_y"]:
            F(f"{name}/{c['name']}: mesh dips {miny:.2f} m below the ground")
        if mx > lim["max_stretch_death" if death else "max_stretch"]:
            F(f"{name}/{c['name']}: edge stretch {mx:.2f} over the limit")
        if p999 > lim["p999_stretch_death" if death else "p999_stretch"]:
            F(f"{name}/{c['name']}: 99.9th percentile stretch {p999:.2f} over the limit")
    return res


# ------------------------------------------------------------------ scenes / gallery
def check_scene(name, m):
    if not m.get("scene"):
        F(f"{name}: no Godot scene")
        return
    for sc in ([m["scene"]] if isinstance(m["scene"], str) else m["scene"]):
        p = os.path.join(C.V2, sc)
        if not os.path.exists(p):
            F(f"{name}: scene {sc} missing")
            continue
        t = open(p).read()
        for r in re.findall(r'path="(res://[^"]+)"', t):
            if not os.path.exists(os.path.join(C.V2, r[len(C.RES_ROOT) + 1:])):
                F(f"{sc}: broken reference {r}")
        if "CollisionShape3D" not in t:
            F(f"{sc}: no collision shapes")


def check_gallery(man):
    docs = os.path.normpath(os.path.join(C.V2, "..", "docs"))
    idx = open(os.path.join(docs, "index.html"), encoding="utf-8").read()
    js = open(os.path.join(docs, "gallery.js"), encoding="utf-8").read()
    m = re.search(r"initialAssets=\[(.*?)\];", idx, re.S)
    assets = json.loads("[" + m.group(1) + "]")
    if len(assets) != len(set(assets)):
        F("gallery: duplicate paths in initialAssets")
    n = 0
    for d, _, fs in os.walk(C.CR):
        if "Source_Scripts" in d:
            continue
        for f in fs:
            if f.endswith((".glb", ".png", ".tres")):
                p = "THE_VEIL_ASSETS_V2/" + os.path.relpath(os.path.join(d, f), C.V2).replace(os.sep, "/")
                n += 1
                if p not in assets:
                    F(f"gallery: {p} not listed in initialAssets")
    for a in assets:
        if a.startswith("THE_VEIL_ASSETS_V2/07_Creatures/") and not os.path.exists(os.path.join(C.V2, a[len("THE_VEIL_ASSETS_V2/"):])):
            F(f"gallery: listed file missing {a}")
    for need in ("pack07=p=>p.startsWith(PREFIX+'07_Creatures/')", "c==='pack07'&&pack07(p)&&model(p)||",
                 "new Option('Pack 07 — Creatures','pack07')"):
        if need not in js:
            F(f"gallery.js: missing {need}")
    for k in ("02", "03", "04", "05", "06", "08", "09"):
        if f"c==='pack{k}'&&pack{k}(p)&&model(p)" not in js:
            F(f"gallery.js: existing pack{k} filter lost")
    return n


# ------------------------------------------------------------------ external tools
def run_khronos(gv_dir, man):
    out = {}
    js = ("const v=require('gltf-validator');const fs=require('fs');(async()=>{for(const p of process.argv.slice(1)){"
          "const r=await v.validateBytes(new Uint8Array(fs.readFileSync(p)));const i=r.issues;"
          "console.log(JSON.stringify({p,e:i.numErrors,w:i.numWarnings,m:i.messages.filter(x=>x.severity<2).map(x=>x.code)}))}})()")
    paths = [os.path.join(C.V2, m["glb"]) for m in man.values()]
    r = subprocess.run(["node", "-e", js] + paths, cwd=gv_dir, capture_output=True, text=True, timeout=600)
    for line in r.stdout.splitlines():
        d = json.loads(line)
        nm = os.path.basename(d["p"])[:-4]
        out[nm] = f"{d['e']} errors, {d['w']} warnings" + (f" ({', '.join(sorted(set(d['m'])))})" if d["m"] else "")
        if d["e"]:
            F(f"glTF-Validator {nm}: {d['e']} errors {sorted(set(d['m']))}")
    if r.returncode or not out:
        F("glTF-Validator did not run: " + r.stderr[-300:])
    return out


GD = r'''extends SceneTree
var MODELS = __MODELS__
func _initialize():
	await process_frame
	for m in MODELS:
		var ps = load(m["scene"])
		if ps == null:
			print("CHECK FAIL ", m["name"], " scene did not load")
			continue
		var inst = ps.instantiate()
		root.add_child(inst)
		await process_frame
		var sks = inst.find_children("*", "Skeleton3D", true, false)
		var mis = inst.find_children("*", "MeshInstance3D", true, false)
		var aps = inst.find_children("*", "AnimationPlayer", true, false)
		if sks.is_empty() or mis.is_empty() or aps.is_empty():
			print("CHECK FAIL ", m["name"], " skeleton/mesh/animation player missing")
			continue
		var sk = sks[0]
		var mi = mis[0]
		var ap = aps[0]
		var mats = []
		var emis = 0
		for i in mi.mesh.get_surface_count():
			var mt = mi.mesh.surface_get_material(i)
			mats.append(mt.resource_path.get_file() if mt else "none")
			if mt and mt is StandardMaterial3D and mt.emission_enabled:
				emis += 1
		var clips = []
		var moved = []
		var probe = sk.find_bone(m["probe"])
		for a in m["clips"]:
			if not ap.has_animation(a["name"]):
				clips.append(a["name"] + ":MISSING")
				continue
			var an = ap.get_animation(a["name"])
			clips.append(a["name"] + ":" + str(an.loop_mode) + ":" + str(snapped(an.length, 0.001)))
			ap.play(a["name"])
			ap.seek(0.0, true)
			var p0 = sk.get_bone_global_pose(probe)
			var best = 0.0
			for k in 8:
				ap.seek(an.length * (k + 1) / 9.0, true)
				var p1 = sk.get_bone_global_pose(probe)
				best = max(best, p0.origin.distance_to(p1.origin) + (p0.basis.get_rotation_quaternion().angle_to(p1.basis.get_rotation_quaternion())))
			moved.append(snapped(best, 0.001))
		var shapes = inst.find_children("*", "CollisionShape3D", true, false).size()
		print("CHECK OK ", m["name"], " bones=", sk.get_bone_count(), " skinned=", mi.skin != null, " mats=", ",".join(mats),
			" emissive=", emis, " reset=", ap.has_animation("RESET"), " shapes=", shapes, " clips=", "|".join(clips),
			" moved=", ",".join(moved.map(func(x): return str(x))))
		inst.queue_free()
		await process_frame
	quit()
'''

RENDER = r'''extends SceneTree
var SCENES = __SCENES__
func _initialize():
	var cam = Camera3D.new()
	root.add_child(cam)
	var sun = DirectionalLight3D.new()
	root.add_child(sun)
	await process_frame
	var frames = 0
	for s in SCENES:
		var inst = load(s).instantiate()
		root.add_child(inst)
		await process_frame
		cam.look_at_from_position(Vector3(0, 6, 30), Vector3(0, 4, 0))
		var ap = inst.find_children("*", "AnimationPlayer", true, false)[0]
		for a in ap.get_animation_list():
			ap.play(a)
			for k in 6:
				await process_frame
				frames += 1
		inst.queue_free()
		await process_frame
	print("RENDER OK frames=", frames, " driver=", RenderingServer.get_video_adapter_name(), " api=", RenderingServer.get_video_adapter_api_version())
	quit()
'''


def run_godot(godot, proj, man):
    os.makedirs(os.path.join(proj, "THE_VEIL_ASSETS_V2"), exist_ok=True)
    dst = os.path.join(proj, "THE_VEIL_ASSETS_V2", "07_Creatures")
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(C.CR, dst, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "Source_Scripts"))
    with open(os.path.join(proj, "project.godot"), "w") as f:
        f.write('config_version=5\n\n[application]\nconfig/name="VeilPack07Check"\n\n[rendering]\n'
                'renderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
    r = subprocess.run([godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=1800)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "WARNING" in l) and "leaked" not in l
            and "ObjectDB" not in l and "PagedAllocator" not in l]
    out = {"import": f"exit {r.returncode}, {len(errs)} error/warning lines"}
    for l in errs[:10]:
        F("Godot import: " + l.strip()[:200])
    extracted = [f for d, _, fs in os.walk(dst) for f in fs if f.endswith(".png") and not f.startswith("T_Crt_")]
    if extracted:
        F(f"Godot import extracted embedded images into the project: {extracted[:3]}")
    models = []
    for nm, m in man.items():
        for sc in ([m["scene"]] if isinstance(m["scene"], str) else m["scene"]):
            models.append(dict(name=nm, scene=C.RES_ROOT + "/" + sc, clips=m["clips"], probe=m["probe_bone"]))
    with open(os.path.join(proj, "crt_check.gd"), "w") as f:
        f.write(GD.replace("__MODELS__", json.dumps(models)))
    r = subprocess.run([godot, "--headless", "--path", proj, "--script", "res://crt_check.gd"], capture_output=True, text=True,
                       timeout=900)
    seen = set()
    for l in r.stdout.splitlines():
        if l.startswith("CHECK OK"):
            p = l.split(" ", 3)
            nm = p[2]
            kv = dict(x.split("=", 1) for x in p[3].split(" ") if "=" in x)
            out.setdefault(nm, []).append(kv)
            seen.add(nm)
            m = man[nm]
            if int(kv["bones"]) != len(m["bone_names"]) + len(m["sockets"]):
                F(f"Godot {nm}: {kv['bones']} bones (expected {len(m['bone_names'])} + {len(m['sockets'])} sockets)")
            if kv["skinned"] != "true":
                F(f"Godot {nm}: mesh not skinned")
            if sorted(kv["mats"].split(",")) != sorted(x + ".tres" for x in m["materials"]):
                F(f"Godot {nm}: materials {kv['mats']} are not the external .tres")
            if kv["reset"] != "true":
                F(f"Godot {nm}: no RESET animation")
            if int(kv["shapes"]) < 1:
                F(f"Godot {nm}: scene has no collision")
            for c, mv in zip(kv["clips"].split("|"), kv["moved"].split(",")):
                cn, lp, ln = c.split(":")
                mc = [x for x in m["clips"] if x["name"] == cn][0]
                if int(lp) != (1 if mc["loop"] else 0) or abs(float(ln) - mc["duration_s"]) > 0.01:
                    F(f"Godot {nm}/{cn}: loop {lp} length {ln} do not match the manifest")
                if float(mv) < 1e-3:
                    F(f"Godot {nm}/{cn}: probe bone {m['probe_bone']} does not move")
        elif l.startswith("CHECK FAIL"):
            F("Godot: " + l[11:])
    for nm in man:
        if nm not in seen:
            F(f"Godot: {nm} was not inspected")
    errs = [l for l in r.stderr.splitlines() if "ERROR" in l and "leaked" not in l and "ObjectDB" not in l
            and "mesh_get_surface_count" not in l and "Parameter \"m\" is null" not in l]
    for l in errs[:5]:
        F("Godot run: " + l.strip()[:200])
    # real Compatibility renderer (OpenGL 3 under xvfb): instantiate every scene and play every clip
    scenes = sorted({C.RES_ROOT + "/" + sc for m in man.values() for sc in ([m["scene"]] if isinstance(m["scene"], str) else m["scene"])})
    with open(os.path.join(proj, "crt_render.gd"), "w") as f:
        f.write(RENDER.replace("__SCENES__", json.dumps(scenes)))
    if shutil.which("xvfb-run"):
        r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 640x360x24", godot, "--path", proj, "--rendering-driver", "opengl3",
                            "--script", "res://crt_render.gd"], capture_output=True, text=True, timeout=900)
        ok = [l for l in r.stdout.splitlines() if l.startswith("RENDER OK")]
        out["render"] = ok[0][10:] if ok else "FAILED"
        if not ok:
            F("Godot Compatibility-renderer run failed: " + (r.stderr[-300:]))
        errs = [l for l in r.stderr.splitlines() if "ERROR" in l and "ALSA" not in l and "audio" not in l.lower()
                and "leaked" not in l and "ObjectDB" not in l]
        for l in errs[:5]:
            F("Godot render run: " + l.strip()[:200])
        out["render_errors"] = len(errs)
    else:
        W("xvfb-run not found: Compatibility-renderer run skipped")
    return out


# ------------------------------------------------------------------ report
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator")
    ap.add_argument("--godot")
    ap.add_argument("--godot-project")
    a = ap.parse_args()
    man = json.load(open(os.path.join(DOC, "CREATURE_MANIFEST.json")))["creatures"]
    results = []
    for nm, m in man.items():
        res, g = check_model(nm, m)
        if g is not None:
            check_anims(nm, m, g, res)
        check_scene(nm, m)
        results.append(res)
    n_gallery = check_gallery(man)
    kh = run_khronos(a.gltf_validator, man) if a.gltf_validator else None
    gd = run_godot(a.godot, a.godot_project, man) if a.godot and a.godot_project else None
    L = ["# Pack 07 - Validation report", "",
         "Generated by `07_Creatures/Source_Scripts/validate_creatures.py`. Automated checks prove file structure, rigging,",
         "skinning maths and engine compatibility only - **they do not prove visual quality**. No screenshots, renders or",
         "videos were produced.", "",
         f"* Result: **{'PASS' if not fails else 'FAIL'}** ({len(fails)} failures, {len(warns)} warnings)",
         f"* Gallery: {n_gallery} Pack 07 files listed in `docs/index.html`; `pack07` filter present in `docs/gallery.js`",
         f"* Khronos glTF-Validator: {'not run' if kh is None else 'run'}",
         f"* Godot 4.3 (Compatibility): {'not run' if gd is None else 'headless import ' + gd['import'] + '; renderer run: ' + str(gd.get('render'))}",
         ""]
    L += ["| Model | Triangles | Height (m) | Extent x/y/z (m) | Unweighted (helper) bones | glTF-Validator | Godot |",
          "|---|---|---|---|---|---|---|"]
    for r in results:
        g = "-"
        if gd and r["name"] in gd:
            kv = gd[r["name"]][0]
            g = f"{kv['bones']} bones, skinned={kv['skinned']}, {kv['emissive']} emissive mats, RESET={kv['reset']}, {kv['shapes']} shapes"
        L.append(f"| {r['name']} | {r.get('tris')} | {r.get('height', 0):.2f} | {r.get('extent')} | "
                 f"{', '.join(r.get('unweighted', [])) or '-'} | {kh.get(r['name'], '-') if kh else '-'} | {g} |")
    L += ["", "## Clips (re-sampled from the GLB keyframes, mesh skinned with LBS on every key)", "",
          "Stretch = 1 + (deformed - rest edge length) / max(rest length, floor). min_y = lowest skinned vertex.", "",
          "| Model | Clip | Keys | min_y (m) | max stretch | 99.9% stretch |", "|---|---|---|---|---|---|"]
    for r in results:
        for c, v in r.get("clips", {}).items():
            L.append(f"| {r['name']} | {c} | {v['keys']} | {v['min_y']} | {v['stretch']} | {v['p999']} |")
    L += ["", "## Failures", ""] + ([f"* {x}" for x in fails] or ["* none"])
    L += ["", "## Warnings", ""] + ([f"* {x}" for x in warns] or ["* none"])
    os.makedirs(DOC, exist_ok=True)
    with open(os.path.join(DOC, "VALIDATION_REPORT.md"), "w", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("\n".join(L[5:9]))
    for x in fails:
        print("FAIL", x)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
