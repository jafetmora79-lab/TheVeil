#!/usr/bin/env python3
"""THE VEIL - Pack 08 focused validation (no rendering, no screenshots).

    python3 08_Inventory/Source_Scripts/validate_inventory.py [--gltf-validator DIR] [--godot BIN --godot-project DIR]

Checks per item: GLB structure (Pack 02 checker: accessors, UVs, unit normals agreeing with winding, no degenerate
triangles), one material, UVs inside the atlas, texture embedded (browser) + .import remap to the shared .tres
(Godot), atlas palette-locked to the Greyhaven ramps, size within a sane real-world range, collision + Inspect_Center
markers (+ Grip on holdables), unique asset names across the repository, Khronos glTF-Validator, Godot 4.3 import
+ instancing with the external material. Writes Documentation/VALIDATION_REPORT.md and INVENTORY_MANIFEST.md.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
INV = os.path.join(V2, "08_Inventory")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
import validate_town as VT  # noqa: E402

fails, warns, info = VT.fails, VT.warns, VT.info
F, W = VT.F, VT.W

GD = r'''extends SceneTree
var items = __ITEMS__
func _init():
	for it in items:
		var ps = load(it)
		if ps == null:
			print("CHECK FAIL load " + it)
			continue
		var n = ps.instantiate()
		var mi = find(n, "MeshInstance3D")
		var col = find(n, "CollisionShape3D")
		var mat = ""
		if mi:
			var m = mi.get_active_material(0)
			if m:
				mat = m.resource_path
		print("CHECK OK %s mat=%s col=%s grip=%s" % [it.get_file(), mat, str(col != null), str(n.find_child("Grip", true, false) != null)])
		n.free()
	quit()
func find(n, t):
	if n.get_class() == t:
		return n
	for c in n.get_children():
		var r = find(c, t)
		if r:
			return r
	return null
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator")
    ap.add_argument("--godot")
    ap.add_argument("--godot-project", default=os.path.join(os.environ.get("TMPDIR", "/tmp"), "veil_p08_check"))
    a = ap.parse_args()
    man = json.load(open(os.path.join(INV, "Documentation", "INVENTORY_MANIFEST.json")))["models"]
    status = {}
    # unique names across the repo
    names = [m["name"] for m in man]
    if len(names) != len(set(names)):
        F("duplicate names inside Pack 08")
    others = set()
    for root, _, fs in os.walk(V2):
        if "08_Inventory" in root:
            continue
        others |= {f[:-4] for f in fs if f.endswith(".glb")}
    clash = sorted(set(names) & others)
    if clash:
        F(f"names collide with other packs: {clash}")
    info.append(f"asset names unique across the repository: {not clash}")
    # atlas palette
    from PIL import Image
    sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
    from chr_tex import P
    pal = {tuple(c) for c in P.rgb.tolist()}
    png = os.path.join(INV, "Textures", "T_Inv_Atlas.png")
    im = np.asarray(Image.open(png).convert("RGB")).reshape(-1, 3)
    off = sum(1 for c in {tuple(x) for x in im.tolist()} if c not in pal)
    info.append(f"atlas 256x256, colours outside the Greyhaven palette: {off}")
    if off:
        F(f"atlas: {off} colours outside the palette")
    tres = os.path.join(INV, "Shared_Materials", "M_Inv_Atlas.tres")
    t = open(tres).read()
    if "texture_filter = 2" not in t or "T_Inv_Atlas.png" not in t:
        F("M_Inv_Atlas.tres: not nearest-filtered or wrong texture")
    for m in man:
        nf = len(fails)
        glb = os.path.join(V2, m["glb"])
        if not os.path.exists(glb) or not os.path.exists(glb + ".import"):
            F(f"{m['name']}: GLB or .import missing")
            continue
        js, st = VT.check_glb(glb)
        if len(js.get("materials", [])) != 1:
            F(f"{m['name']}: expected one material, found {len(js.get('materials', []))}")
        if not js.get("images") or "bufferView" not in js["images"][0]:
            F(f"{m['name']}: texture not embedded")
        if "M_Inv_Atlas.tres" not in open(glb + ".import").read():
            F(f"{m['name']}: .import does not remap to M_Inv_Atlas.tres")
        _, binb = VT.read_glb(glb)
        for mesh in js["meshes"]:
            for p in mesh["primitives"]:
                if "TEXCOORD_0" in p["attributes"]:
                    uv = VT.accessor(js, binb, p["attributes"]["TEXCOORD_0"])
                    if uv.min() < -1e-6 or uv.max() > 1 + 1e-6:
                        F(f"{m['name']}: UVs outside the atlas")
        nodes = {n["name"] for n in js["nodes"]}
        if "Inspect_Center" not in nodes or not any(n.endswith("-convcolonly") for n in nodes):
            F(f"{m['name']}: missing Inspect_Center marker or collision")
        if m["holdable"] and "Grip" not in nodes:
            F(f"{m['name']}: holdable item without Grip marker")
        mx = max(m["size_m"])
        if not (0.005 < mx < 1.0) or min(m["size_m"]) < 0.0005:
            F(f"{m['name']}: implausible size {m['size_m']}")
        status[m["name"]] = "pass" if len(fails) == nf else "FAIL"
    info.append(f"GLBs checked: {len(man)}")
    if a.gltf_validator:
        js_code = r"""const v=require('gltf-validator'),fs=require('fs');const files=JSON.parse(fs.readFileSync(0,'utf8'));
(async()=>{const o={};for(const f of files){const r=await v.validateBytes(new Uint8Array(fs.readFileSync(f)));o[f]={e:r.issues.numErrors,w:r.issues.numWarnings,m:r.issues.messages.filter(x=>x.severity<=1).slice(0,3).map(x=>x.code)};}console.log(JSON.stringify(o));})();"""
        r = subprocess.run(["node", "-e", js_code], input=json.dumps([os.path.join(V2, m["glb"]) for m in man]), capture_output=True, text=True,
                           cwd=a.gltf_validator, timeout=600)
        out = json.loads(r.stdout)
        info.append(f"Khronos glTF-Validator: {len(out)} files, {sum(v['e'] for v in out.values())} errors, {sum(v['w'] for v in out.values())} warnings")
        for f, v in out.items():
            if v["e"]:
                F(f"Khronos {os.path.basename(f)}: {v['m']}")
                status[os.path.basename(f)[:-4]] = "FAIL"
            elif v["w"]:
                W(f"Khronos {os.path.basename(f)}: {v['m']}")
    if a.godot:
        proj = a.godot_project
        dst = os.path.join(proj, "THE_VEIL_ASSETS_V2")
        os.makedirs(dst, exist_ok=True)
        if os.path.exists(os.path.join(dst, "08_Inventory")):
            shutil.rmtree(os.path.join(dst, "08_Inventory"))
        shutil.copytree(INV, os.path.join(dst, "08_Inventory"), ignore=shutil.ignore_patterns("__pycache__", "Source_Scripts"))
        if not os.path.exists(os.path.join(proj, "project.godot")):
            open(os.path.join(proj, "project.godot"), "w").write('config_version=5\n\n[application]\nconfig/name="VeilPack08Check"\n\n[rendering]\n'
                                                                  'renderer/rendering_method="gl_compatibility"\n')
        r = subprocess.run([a.godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=1800)
        errs = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "WARNING" in l) and "leaked" not in l and "ObjectDB" not in l]
        info.append(f"Godot 4.3 headless import: exit {r.returncode}, {len(errs)} error/warning lines")
        for l in errs[:8]:
            F("Godot import: " + l.strip()[:200])
        open(os.path.join(proj, "inv_check.gd"), "w").write(GD.replace("__ITEMS__", json.dumps(["res://THE_VEIL_ASSETS_V2/" + m["glb"] for m in man])))
        r = subprocess.run([a.godot, "--headless", "--path", proj, "--script", "res://inv_check.gd"], capture_output=True, text=True, timeout=900)
        ok = 0
        for l in r.stdout.splitlines():
            if l.startswith("CHECK OK"):
                p = l.split()
                kv = dict(x.split("=", 1) for x in p[3:])
                nm = p[2][:-4]
                if not kv["mat"].endswith("M_Inv_Atlas.tres") or kv["col"] != "true":
                    F(f"Godot {nm}: material {kv['mat']} collision {kv['col']}")
                    status[nm] = "FAIL"
                else:
                    ok += 1
            elif l.startswith("CHECK FAIL"):
                F("Godot " + l)
        info.append(f"Godot: {ok}/{len(man)} GLBs instanced with the external M_Inv_Atlas.tres and a collision shape")
    else:
        W("Godot check not run")
    # manifest md + report
    rows = ["# THE VEIL - Pack 08 Inventory Manifest", "",
            "All items are new; no earlier pack contains a matching handheld item. The Pack 03 RES_Radio is a household set, "
            "and its car keys are only a node on the coat rack.",
            "Every item uses the shared 256x256 atlas (`Textures/T_Inv_Atlas.png`) and one material (`Shared_Materials/M_Inv_Atlas.tres`).", "",
            "| Asset | Category | Priority | GLB | Tris | Size (m) | Grip | Status |", "|---|---|---|---|---|---|---|---|"]
    for m in man:
        rows.append(f"| `{m['name']}` | {m['category']} | {m['priority']} | `{m['glb']}` | {m['triangles']} | {' x '.join(str(v) for v in m['size_m'])} | "
                    f"{'yes' if m['grip'] else '-'} | {status.get(m['name'], '?')} (new) |")
    open(os.path.join(INV, "Documentation", "INVENTORY_MANIFEST.md"), "w", newline="\n").write("\n".join(rows) + "\n")
    L = ["# THE VEIL - Pack 08 Validation Report", "",
         "Automated file, geometry and engine checks only. **Nothing was rendered**, so visual quality has not been verified.", "",
         f"**Result: {'PASS' if not fails else 'FAIL'}** - {len(fails)} failures, {len(warns)} warnings", ""] + [f"* {i}" for i in info]
    L += ["", "## Failures", ""] + ([f"* {f}" for f in fails] or ["None."]) + ["", "## Warnings", ""] + ([f"* {w}" for w in warns] or ["None."])
    open(os.path.join(INV, "Documentation", "VALIDATION_REPORT.md"), "w", newline="\n").write("\n".join(L) + "\n")
    print(f"{'PASS' if not fails else 'FAIL'}: {len(fails)} failures, {len(warns)} warnings")
    for x in info:
        print(" ", x)
    for x in (fails + warns)[:25]:
        print("  !", x)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
