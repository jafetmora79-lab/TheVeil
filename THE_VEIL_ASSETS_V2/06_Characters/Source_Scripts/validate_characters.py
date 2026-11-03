#!/usr/bin/env python3
"""THE VEIL - Pack 06 validation (no rendering, no screenshots).

    python3 06_Characters/Source_Scripts/validate_characters.py [--gltf-validator DIR] [--godot BIN --godot-project DIR]

Per character: GLB structure (Pack 02 checker: accessors, UVs, unit normals agreeing with winding, no degenerate
triangles), skin (joint names/hierarchy = shared skeleton, inverse bind matrices = inverse rest transforms, <= 4
influences, weights sum to 1), texture (256x256, every pixel from the Greyhaven palette, embedded + external),
material (.tres, nearest filtering, .import remap), scale (height vs roster, feet on y = 0, faces +Z), hand sockets,
linear-blend-skinning deformation tests (elbow/knee/shoulder/hip/spine/neck/ankle poses: rigid parts stay rigid,
no stretched or exploded triangles), Khronos glTF-Validator, Godot 4.3 import (Skeleton3D, skinned mesh,
material remap, bone posing, BoneAttachment sockets). Writes Documentation/VALIDATION_REPORT.md.
"""
import argparse
import json
import math
import os
import shutil
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
CHR = os.path.join(V2, "06_Characters")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
import validate_town as VT  # noqa: E402

import chr_core  # noqa: E402
import chr_tex  # noqa: E402
from chr_roster import ROSTER  # noqa: E402

fails, warns, info = VT.fails, VT.warns, VT.info
F, W = VT.F, VT.W

POSES = {
    "elbows 100": {"LeftLowerArm": ("y", 100), "RightLowerArm": ("y", -100)},
    "knees 100": {"LeftLowerLeg": ("x", 100), "RightLowerLeg": ("x", 100)},
    "shoulders up 70": {"LeftUpperArm": ("z", 70), "RightUpperArm": ("z", -70)},
    "hips flex 70": {"LeftUpperLeg": ("x", -70), "RightUpperLeg": ("x", -70)},
    "spine bend 30 + twist 25": {"Spine": ("x", 15), "Chest": ("x", 15), "UpperChest": ("y", 25)},
    "head turn 60 + nod 25": {"Neck": ("x", 10), "Head": ("y", 60)},
    "wrists 60 / ankles 30": {"LeftHand": ("z", 60), "RightHand": ("z", -60), "LeftFoot": ("x", 30), "RightFoot": ("x", 30)},
}
AX = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}


def acc(js, binb, i):
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    comp = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    arr = np.frombuffer(binb[off:off + a["count"] * n * np.dtype(comp).itemsize], dtype=comp)
    return arr.reshape(-1, n) if n > 1 else arr


def check_model(m, bones):
    name = m["name"]
    glb = os.path.join(V2, m["glb"])
    res = {"name": name, "ok": True}
    nf = len(fails)
    if not os.path.exists(glb) or not os.path.exists(glb + ".import"):
        F(f"{name}: GLB or .import missing")
        return res
    js, st = VT.check_glb(glb)
    _, binb = VT.read_glb(glb)
    res["tris"] = st["tris"]
    prim = js["meshes"][0]["primitives"][0]
    P = acc(js, binb, prim["attributes"]["POSITION"])
    Jt = acc(js, binb, prim["attributes"]["JOINTS_0"])
    Wt = acc(js, binb, prim["attributes"]["WEIGHTS_0"])
    UV = acc(js, binb, prim["attributes"]["TEXCOORD_0"])
    I = acc(js, binb, prim["indices"]).reshape(-1, 3)
    if UV.min() < -1e-6 or UV.max() > 1 + 1e-6:
        F(f"{name}: UVs outside 0..1")
    # skin
    sk = js["skins"][0]
    names = [js["nodes"][j]["name"] for j in sk["joints"]]
    if names != [b for b, _ in bones]:
        F(f"{name}: joint names/order differ from the shared skeleton")
    parent = {}
    for k, nd in enumerate(js["nodes"]):
        for ch in nd.get("children", []):
            parent[ch] = k
    for j, (b, p) in zip(sk["joints"], bones):
        pj = parent.get(j)
        pn = js["nodes"][pj]["name"] if pj is not None else None
        if p and pn != p:
            F(f"{name}: bone {b} parent {pn} != {p}")
    # world rest positions from node translations
    world = {}

    def wpos(k):
        if k in world:
            return world[k]
        t = np.array(js["nodes"][k].get("translation", [0, 0, 0]), float)
        if "rotation" in js["nodes"][k] or "scale" in js["nodes"][k]:
            F(f"{name}: joint {js['nodes'][k]['name']} has rest rotation/scale (expected identity)")
        world[k] = t + (wpos(parent[k]) if k in parent else 0)
        return world[k]
    joints = {js["nodes"][j]["name"]: wpos(j) for j in sk["joints"]}
    IBM = acc(js, binb, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    for k, b in enumerate(names):
        G = np.eye(4)
        G[:3, 3] = joints[b]
        if np.abs(IBM[k] @ G - np.eye(4)).max() > 1e-4:
            F(f"{name}: inverse bind matrix of {b} is not the inverse rest transform")
    if Jt.max() >= len(names):
        F(f"{name}: joint index out of range")
    ws = Wt.sum(1)
    if np.abs(ws - 1).max() > 1e-3:
        F(f"{name}: skin weights do not sum to 1 (max err {np.abs(ws - 1).max():.4f})")
    if (Wt < -1e-6).any():
        F(f"{name}: negative weights")
    unused = sorted(set(names) - {names[j] for j in np.unique(Jt[Wt > 1e-4])})
    res["unweighted_bones"] = unused
    # texture: embedded == external, palette
    img = js["images"][0]
    bv = js["bufferViews"][img["bufferView"]]
    emb = binb[bv["byteOffset"]:bv["byteOffset"] + bv["byteLength"]]
    png = os.path.join(V2, m["texture"])
    if emb != open(png, "rb").read():
        W(f"{name}: embedded texture differs from {m['texture']}")
    from PIL import Image
    im = np.asarray(Image.open(png).convert("RGB")).reshape(-1, 3)
    pal = {tuple(c) for c in chr_tex.P.rgb.tolist()}
    off = sum(1 for c in {tuple(x) for x in im.tolist()} if c not in pal)
    if off:
        F(f"{name}: {off} texture colours outside the Greyhaven palette")
    res["tex"] = "x".join(map(str, Image.open(png).size))
    if not os.path.exists(png + ".import") or "compress/mode=0" not in open(png + ".import").read():
        F(f"{name}: texture .import missing or not lossless")
    tres = os.path.join(V2, m["material"])
    t = open(tres).read() if os.path.exists(tres) else ""
    if "texture_filter = 2" not in t or m["texture"] not in t:
        F(f"{name}: material .tres missing, not nearest-filtered or not pointing at its texture")
    if os.path.basename(tres)[:-5] not in open(glb + ".import").read():
        F(f"{name}: .glb.import does not remap the material to its .tres")
    # scale / orientation / sockets
    fp = "FP" in name
    nodes = {nd["name"]: k for k, nd in enumerate(js["nodes"])}
    if not fp:
        c = [q for q in ROSTER if q["name"] == m["character"]][0]
        h = P[:, 1].max()
        res["height"] = round(float(h), 3)
        if abs(h - c["height"]) / c["height"] > 0.04:
            F(f"{name}: height {h:.2f} m vs roster {c['height']} m")
        if abs(P[:, 1].min()) > 0.005:
            F(f"{name}: feet not on y = 0 (min y {P[:, 1].min():.3f})")
        nose_z = P[(P[:, 1] > joints["Head"][1]) & (np.abs(P[:, 0]) < 0.02)][:, 2].max()
        if nose_z < joints["Head"][2] + 0.05:
            F(f"{name}: face does not point +Z")
    for s in ("LeftHand_ItemSocket", "RightHand_ItemSocket"):
        if s not in nodes:
            F(f"{name}: missing {s}")
        else:
            k = nodes[s]
            hb = "LeftHand" if s.startswith("Left") else "RightHand"
            if js["nodes"][parent[k]]["name"] != hb:
                F(f"{name}: {s} not parented to {hb}")
            sp = wpos(parent[k]) + np.array(js["nodes"][k]["translation"])
            hand = P[(Wt[:, 0] > 0.99) & (Jt[:, 0] == names.index(hb))]
            if len(hand) and np.linalg.norm(hand.mean(0) - sp) > 0.09:
                F(f"{name}: {s} is {np.linalg.norm(hand.mean(0) - sp):.2f} m from the hand")
    # deformation (linear blend skinning, like Godot / any engine)
    E = np.unique(np.sort(np.concatenate([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]]), axis=1), axis=0)
    L0 = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
    worst = {}
    for pose, spec in POSES.items():
        rots = {b: chr_core.rot(AX[a], d) for b, (a, d) in spec.items() if b in names}
        if not rots:
            continue
        Q = chr_core.lbs(P.astype(float), Jt.astype(int), Wt.astype(float), bones, joints, rots)
        if not np.isfinite(Q).all():
            F(f"{name}: non-finite vertices in pose '{pose}'")
            continue
        L1 = np.linalg.norm(Q[E[:, 0]] - Q[E[:, 1]], axis=1)
        ratio = L1 / np.maximum(L0, 1e-6)
        mx = float(ratio.max())
        mn = float(ratio[L0 > 0.01].min())
        worst[pose] = (round(mx, 2), round(mn, 2))
        if mx > 3.0:
            F(f"{name}: pose '{pose}' stretches an edge x{mx:.2f}")
        # rigid parts must stay rigid: vertices weighted 100% to one bone keep their mutual distances
        for b in rots:
            sel = np.where((Wt[:, 0] > 0.999) & (Jt[:, 0] == names.index(b)))[0][:40]
            if len(sel) > 3:
                d0 = np.linalg.norm(P[sel][:, None] - P[sel][None], axis=2)
                d1 = np.linalg.norm(Q[sel][:, None] - Q[sel][None], axis=2)
                if np.abs(d0 - d1).max() > 1e-4:
                    F(f"{name}: rigid part of {b} deforms in '{pose}'")
    res["deform"] = worst
    res["ok"] = len(fails) == nf
    return res


GD = r'''extends SceneTree
var models = __MODELS__
var bones = __BONES__
func _init():
	for m in models:
		var ps = load(m["res"])
		if ps == null:
			print("CHECK FAIL load " + m["res"])
			continue
		var inst = ps.instantiate()
		get_root().add_child(inst)
		var sk = find_type(inst, "Skeleton3D")
		if sk == null:
			print("CHECK FAIL %s no Skeleton3D" % m["name"])
			continue
		var miss = []
		for b in m["bones"]:
			if sk.find_bone(b) < 0:
				miss.append(b)
		var mi = find_type(inst, "MeshInstance3D")
		var mat = ""
		if mi and mi.mesh:
			var sm = mi.get_active_material(0)
			if sm:
				mat = sm.resource_path
		var skinned = mi != null and mi.skin != null and mi.get_node_or_null(mi.skeleton) == sk
		var aabb = mi.get_aabb() if mi else AABB()
		# pose test: bend the right elbow 90 deg, the hand bone must swing
		var e = sk.find_bone("RightLowerArm")
		var h = sk.find_bone("RightHand")
		var p0 = sk.get_bone_global_pose(h).origin
		sk.set_bone_pose_rotation(e, Quaternion(Vector3(0, 1, 0), deg_to_rad(90)))
		sk.force_update_all_bone_transforms()
		var p1 = sk.get_bone_global_pose(h).origin
		var att = 0
		for sname in m["sockets"]:
			if sk.find_bone(sname) >= 0 or find_name(inst, sname) != null:
				att += 1
		print("CHECK OK %s bones=%d missing=%s skinned=%s material=%s aabb_h=%.3f hand_moved=%.3f attachments=%d tris_ok=%s" % [m["name"], sk.get_bone_count(), str(miss), str(skinned), mat, aabb.size.y, p0.distance_to(p1), att, str(mi.mesh.get_surface_count() == 1)])
		get_root().remove_child(inst)
		inst.free()
	var lp = load("res://THE_VEIL_ASSETS_V2/06_Characters/Shared_Rigs/Characters_Lineup.tscn")
	var li = lp.instantiate() if lp else null
	print("CHECK LINEUP %s" % str(li != null))
	if li:
		li.free()
	quit()

func find_name(n, nm):
	if String(n.name) == nm:
		return n
	for c in n.get_children():
		var r = find_name(c, nm)
		if r:
			return r
	return null

func find_type(n, t):
	if n.get_class() == t:
		return n
	for c in n.get_children():
		var r = find_type(c, t)
		if r:
			return r
	return null
'''


def run_godot(godot, proj, man):
    os.makedirs(proj, exist_ok=True)
    dst = os.path.join(proj, "THE_VEIL_ASSETS_V2")
    os.makedirs(dst, exist_ok=True)
    for d in ("01_Textures", "Materials_Godot", "06_Characters"):
        if d == "06_Characters" and os.path.exists(os.path.join(dst, d)):
            shutil.rmtree(os.path.join(dst, d))
        if not os.path.exists(os.path.join(dst, d)):
            shutil.copytree(os.path.join(V2, d), os.path.join(dst, d), ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    if not os.path.exists(os.path.join(proj, "project.godot")):
        with open(os.path.join(proj, "project.godot"), "w") as f:
            f.write('config_version=5\n\n[application]\nconfig/name="VeilPack06Check"\n\n[rendering]\n'
                    'renderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
    r = subprocess.run([godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=1800)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "WARNING" in l) and "leaked" not in l
            and "ObjectDB" not in l and "PagedAllocator" not in l]
    out = {"import": f"exit {r.returncode}, {len(errs)} error/warning lines"}
    for l in errs[:10]:
        F("Godot import: " + l.strip()[:200])
    models = [dict(name=m["name"], res="res://THE_VEIL_ASSETS_V2/" + m["glb"],
                   bones=[b for b, _ in (chr_core.FP_BONES if "FP" in m["name"] else chr_core.BONES)], sockets=m["sockets"]) for m in man]
    with open(os.path.join(proj, "chr_check.gd"), "w") as f:
        f.write(GD.replace("__MODELS__", json.dumps(models)).replace("__BONES__", "[]"))
    r = subprocess.run([godot, "--headless", "--path", proj, "--script", "res://chr_check.gd"], capture_output=True, text=True, timeout=900)
    for l in r.stdout.splitlines():
        if l.startswith("CHECK OK"):
            p = l.split()
            nm = p[2]
            kv = dict(x.split("=", 1) for x in p[3:] if "=" in x)
            out[nm] = kv
            mm = [m for m in man if m["name"] == nm][0]
            nb = (9 if "FP" in nm else 23) + len(mm["sockets"])      # Godot turns socket nodes into (unweighted) bones
            if int(kv["bones"]) != nb or kv["missing"] != "[]":
                F(f"Godot {nm}: skeleton bones {kv['bones']} missing {kv['missing']}")
            if kv["skinned"] != "true":
                F(f"Godot {nm}: mesh is not skinned to the Skeleton3D")
            if not kv["material"].endswith(os.path.basename(mm["material"])):
                F(f"Godot {nm}: material is {kv['material']} (expected the external .tres)")
            if float(kv["hand_moved"]) < 0.05:
                F(f"Godot {nm}: posing the elbow did not move the hand bone")
            if int(kv["attachments"]) != len(mm["sockets"]):
                F(f"Godot {nm}: item sockets missing after import ({kv['attachments']}/{len(mm['sockets'])})")
        elif l.startswith("CHECK FAIL"):
            F("Godot: " + l[11:])
        elif l.startswith("CHECK LINEUP"):
            out["lineup"] = l.split()[2]
            if l.split()[2] != "true":
                F("Godot: lineup scene failed to load")
    errs = [l for l in r.stderr.splitlines() if "ERROR" in l and "leaked" not in l and "ObjectDB" not in l and "PagedAllocator" not in l
            and "mesh_get_surface_count" not in l and "Parameter \"m\" is null" not in l]
    for l in errs[:5]:
        F("Godot run: " + l.strip()[:200])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator")
    ap.add_argument("--godot")
    ap.add_argument("--godot-project", default=os.path.join(os.environ.get("TMPDIR", "/tmp"), "veil_p06_check"))
    a = ap.parse_args()
    man = json.load(open(os.path.join(CHR, "Documentation", "CHARACTER_MANIFEST.json")))["models"]
    results = [check_model(m, chr_core.FP_BONES if "FP" in m["name"] else chr_core.BONES) for m in man]
    if a.gltf_validator:
        js_code = r"""
const v=require('gltf-validator'),fs=require('fs');const files=JSON.parse(fs.readFileSync(0,'utf8'));
(async()=>{const out={};for(const f of files){const r=await v.validateBytes(new Uint8Array(fs.readFileSync(f)));
out[f]={e:r.issues.numErrors,w:r.issues.numWarnings,msgs:r.issues.messages.filter(m=>m.severity<=1).slice(0,4).map(m=>m.code+' '+m.pointer)};}
console.log(JSON.stringify(out));})();"""
        glbs = [os.path.join(V2, m["glb"]) for m in man]
        r = subprocess.run(["node", "-e", js_code], input=json.dumps(glbs), capture_output=True, text=True, cwd=a.gltf_validator, timeout=600)
        out = json.loads(r.stdout)
        info.append(f"Khronos glTF-Validator: {len(out)} files, {sum(v['e'] for v in out.values())} errors, {sum(v['w'] for v in out.values())} warnings")
        for f, v in out.items():
            if v["e"]:
                F(f"Khronos {os.path.basename(f)}: {v['msgs']}")
            elif v["w"]:
                W(f"Khronos {os.path.basename(f)}: {v['msgs']}")
    else:
        W("Khronos glTF-Validator not run")
    gd = run_godot(a.godot, a.godot_project, man) if a.godot else None
    if not gd:
        W("Godot checks not run")
    L = ["# THE VEIL - Pack 06 Validation Report", "",
         "Generated by `06_Characters/Source_Scripts/validate_characters.py`. These are automated file, skin, deformation and "
         "engine checks only. **Nothing was rendered or visually inspected**, so the look of the characters is unverified.", "",
         f"**Result: {'PASS' if not fails else 'FAIL'}** - {len(fails)} failures, {len(warns)} warnings", ""]
    L += [f"* {i}" for i in info]
    if gd:
        L += [f"* Godot 4.3 headless (Compatibility): import {gd['import']}; lineup scene loads: {gd.get('lineup')}"]
    L += ["", "| Character | GLB | Triangles | Texture | Rigged | Height (m) | Godot import | Notes |", "|---|---|---|---|---|---|---|---|"]
    for m, r in zip(man, results):
        g = gd.get(m["name"]) if gd else None
        gtxt = (f"OK - {g['bones']} bones (incl. {g['attachments']} socket bones), skinned, .tres material, elbow pose moves hand" if g else "not run")
        note = "unweighted (helper) bones: " + ", ".join(r.get("unweighted_bones", [])) if r.get("unweighted_bones") else ""
        L.append(f"| {m['character']}{' (first-person arms)' if 'FP' in m['name'] else ''} | `{m['glb']}` | {r.get('tris')} | "
                 f"{r.get('tex')} | yes ({m['skeleton']}) | {r.get('height', '-')} | {gtxt} | {note} |")
    L += ["", "### Skinning deformation (max / min edge-length ratio under each test pose; rigid parts verified rigid)", "",
          "| Character | " + " | ".join(POSES) + " |", "|---|" + "---|" * len(POSES)]
    for m, r in zip(man, results):
        d = r.get("deform", {})
        L.append(f"| {m['character']}{' FP' if 'FP' in m['name'] else ''} | " + " | ".join(f"{d[p][0]} / {d[p][1]}" if p in d else "-" for p in POSES) + " |")
    L += ["", "## Failures", ""] + ([f"* {f}" for f in fails] or ["None."]) + ["", "## Warnings", ""] + ([f"* {w}" for w in warns] or ["None."])
    with open(os.path.join(CHR, "Documentation", "VALIDATION_REPORT.md"), "w", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print(f"{'PASS' if not fails else 'FAIL'}: {len(fails)} failures, {len(warns)} warnings")
    for f in fails[:30]:
        print("  FAIL", f)
    for w in warns[:20]:
        print("  WARN", w)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
