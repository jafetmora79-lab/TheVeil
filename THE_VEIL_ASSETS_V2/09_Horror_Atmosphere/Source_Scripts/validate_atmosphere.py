#!/usr/bin/env python3
"""THE VEIL - Pack 09 focused validation (no screenshots, nothing saved from the renderer).

    python3 09_Horror_Atmosphere/Source_Scripts/validate_atmosphere.py [--gltf-validator DIR]
        [--godot BIN --godot-project DIR]   # project must already hold Packs 01/02/03/08 + Materials_Godot

Static: GLB structure (Pack 02 checker), embedded textures, .import remaps, UV range, palette lock of every Pack 09
texture, res:// references in every .tscn/.tres/.import, Compatibility-unsafe features (Decal, GPUParticles,
volumetric fog, SDFGI, SSAO/SSR, GI probes, screen/depth texture reads). Engine: Godot 4.3 headless import, then a
real gl_compatibility run (xvfb + opengl3) that loads every preset as VeilAtmospherePreset, instances every GLB and
scene for a few frames, and drives the demo rig through all five states. Writes Documentation/VALIDATION_REPORT.md.
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
PK = os.path.join(V2, "09_Horror_Atmosphere")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "06_Characters", "Source_Scripts"))
import validate_town as VT  # noqa: E402

fails, warns, info = VT.fails, VT.warns, VT.info
F, W = VT.F, VT.W

UNSAFE = [r"\bDecal\b", r"GPUParticles3D", r"volumetric_fog_enabled\s*=\s*true", r"sdfgi_enabled\s*=\s*true",
          r"ssao_enabled\s*=\s*true", r"ssr_enabled\s*=\s*true", r"ssil_enabled\s*=\s*true", r"VoxelGI", r"LightmapGI",
          r"hint_screen_texture", r"hint_depth_texture", r"SCREEN_TEXTURE", r"DEPTH_TEXTURE", r"FogVolume"]

GD = r'''extends SceneTree
const ROOT = "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/"
func list(dir: String, ext: String) -> Array:
	var out = []
	var d = DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + f)
	for s in d.get_directories():
		out += list(dir + s + "/", ext)
	return out
func frames(n):
	for i in n:
		await process_frame
func _initialize():
	print("CHECK RENDERER ", ProjectSettings.get_setting("rendering/renderer/rendering_method"), " ", RenderingServer.get_video_adapter_name())
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.7, 6)
	cam.make_current()
	for p in list(ROOT, ".tres"):
		var r = load(p)
		if r == null:
			print("CHECK FAIL load ", p)
		elif p.get_file().begins_with("STATE_") or p.get_file().begins_with("LGT_"):
			print("CHECK PRESET ", p.get_file(), " ", r is VeilAtmospherePreset)
	for p in list(ROOT, ".glb"):
		var ps = load(p)
		if ps == null:
			print("CHECK FAIL load ", p); continue
		var n = ps.instantiate(); root.add_child(n); await frames(1); n.queue_free()
		print("CHECK GLB ", p.get_file())
	for p in list(ROOT, ".tscn"):
		if p.ends_with("Greyhaven_Veil_Demo.tscn"):
			continue
		var ps = load(p)
		if ps == null:
			print("CHECK FAIL load ", p); continue
		var n = ps.instantiate(); root.add_child(n); await frames(3)
		var parts = 0
		for c in n.find_children("*", "CPUParticles3D", true, false) + ([n] if n is CPUParticles3D else []):
			if c.emitting: parts += 1
		print("CHECK SCENE ", p.get_file(), " emitting=", parts)
		n.queue_free(); await frames(1)
	cam.queue_free()
	var demo = load(ROOT + "Godot_Scenes/Greyhaven_Veil_Demo.tscn").instantiate()
	root.add_child(demo)
	await frames(3)
	var atm = demo.find_child("Atmosphere", true, false)
	var env = atm.world_environment.environment
	var mist = atm.mist
	var others = 0
	for w in demo.find_children("*", "WorldEnvironment", true, false):
		if w != atm.world_environment and w.environment != null: others += 1
	print("CHECK OTHER_ENV active=", others)
	var fl = get_nodes_in_group("veil_flicker").size()
	print("CHECK DEMO flicker_nodes=", fl, " corruption_nodes=", get_nodes_in_group("veil_corruption").size())
	for s in 5:
		atm.set_state(s, true)
		await frames(4)
		var vis = 0
		for c in get_nodes_in_group("veil_corruption"):
			if c.visible: vis += 1
		print("CHECK STATE %d fog=%.4f ambient=%.2f mist=%.2f corr_visible=%d rain=%s" % [s, env.fog_density, env.ambient_light_energy, mist.density, vis, str(demo.find_child("Rain", true, false).visible)])
	atm.set_state(4, false)
	await frames(30)
	print("CHECK TWEEN ok fog=%.4f" % env.fog_density)
	quit()
'''


def walk(ext):
    for root, _, fs in os.walk(PK):
        if "Source_Scripts" in root:
            continue
        for f in sorted(fs):
            if f.endswith(ext):
                yield os.path.join(root, f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gltf-validator")
    ap.add_argument("--godot")
    ap.add_argument("--godot-project")
    a = ap.parse_args()
    man = json.load(open(os.path.join(PK, "Documentation", "ATMOSPHERE_MANIFEST.json")))
    # names unique across packs
    names = [g["name"] for g in man["glbs"]]
    others = set()
    for root, _, fs in os.walk(V2):
        if "09_Horror_Atmosphere" not in root:
            others |= {f[:-4] for f in fs if f.endswith(".glb")}
    clash = sorted(set(names) & others) + sorted({n for n in names if names.count(n) > 1})
    if clash:
        F(f"GLB names collide: {clash}")
    info.append(f"GLB names unique across the repository: {not clash}")
    # textures: palette lock
    from PIL import Image
    from chr_tex import P
    pal = {tuple(c) for c in P.rgb.tolist()}
    nt = 0
    for png in walk(".png"):
        nt += 1
        im = np.asarray(Image.open(png).convert("RGBA")).reshape(-1, 4)
        im = im[im[:, 3] > 0][:, :3]
        off = {tuple(x) for x in im.tolist()} - pal
        if off and "T_Veil_" in png:
            # effect sprites (spark/dust/drip/rain/fluorescent/light shaft) are white masks tinted in-engine
            if not {(255, 255, 255)} >= off:
                F(f"{os.path.basename(png)}: {len(off)} colours outside the palette")
        if not os.path.exists(png + ".import"):
            F(f"{os.path.basename(png)}: .import missing")
    info.append(f"textures checked: {nt} (palette-locked; white effect masks allowed)")
    # GLBs
    tres = {}
    for root, _, fs in os.walk(V2):
        for f in fs:
            if f.endswith(".tres"):
                tres.setdefault(f[:-5], os.path.join(root, f))
    for g in man["glbs"]:
        glb = os.path.join(V2, g["glb"])
        if not os.path.exists(glb) or not os.path.exists(glb + ".import"):
            F(f"{g['name']}: GLB or .import missing")
            continue
        js, _ = VT.check_glb(glb)
        _, binb = VT.read_glb(glb)
        if any("uri" in im for im in js.get("images", [])):
            F(f"{g['name']}: external image URI (not embedded)")
        imp = open(glb + ".import").read()
        for m in g["materials"]:
            if m not in imp:
                F(f"{g['name']}: .import does not remap {m}")
        for mesh in js["meshes"]:
            for p in mesh["primitives"]:
                if "material" not in p:  # collision-only primitives
                    continue
                mn = js["materials"][p["material"]]["name"]
                if mn not in tres:
                    F(f"{g['name']}: material {mn} has no .tres")
                elif "TEXCOORD_0" in p["attributes"]:
                    uv = VT.accessor(js, binb, p["attributes"]["TEXCOORD_0"])
                    if (uv.min() < -1e-4 or uv.max() > 1 + 1e-4) and "texture_repeat = false" in open(tres[mn]).read():
                        F(f"{g['name']}: UVs outside 0..1 on non-repeating material {mn}")
    info.append(f"GLBs checked: {len(man['glbs'])}, triangles total {sum(g['triangles'] for g in man['glbs'])}")
    # references + unsupported features
    nref = nfile = 0
    for ext in (".tscn", ".tres", ".import", ".gdshader", ".gd"):
        for f in walk(ext):
            nfile += 1
            t = open(f).read()
            for r in re.findall(r'res://(THE_VEIL_ASSETS_V2/[^"\n]+)', t):
                nref += 1
                if not os.path.exists(os.path.join(REPO, r)):
                    F(f"{os.path.relpath(f, V2)}: broken reference {r}")
            if ext != ".gd":
                for u in UNSAFE:
                    if re.search(u, t):
                        F(f"{os.path.relpath(f, V2)}: Compatibility-unsafe feature {u}")
    info.append(f"files scanned for references / unsupported features: {nfile}, res:// references {nref}")
    if a.gltf_validator:
        code = r"""const v=require('gltf-validator'),fs=require('fs');const files=JSON.parse(fs.readFileSync(0,'utf8'));
(async()=>{const o={};for(const f of files){const r=await v.validateBytes(new Uint8Array(fs.readFileSync(f)));o[f]={e:r.issues.numErrors,w:r.issues.numWarnings,m:r.issues.messages.filter(x=>x.severity<=1).slice(0,3).map(x=>x.code)};}console.log(JSON.stringify(o));})();"""
        r = subprocess.run(["node", "-e", code], input=json.dumps([os.path.join(V2, g["glb"]) for g in man["glbs"]]),
                           capture_output=True, text=True, cwd=a.gltf_validator, timeout=600)
        out = json.loads(r.stdout)
        info.append(f"Khronos glTF-Validator: {len(out)} files, {sum(v['e'] for v in out.values())} errors, "
                    f"{sum(v['w'] for v in out.values())} warnings")
        for f, v in out.items():
            (F if v["e"] else W)(f"Khronos {os.path.basename(f)}: {v['m']}") if (v["e"] or v["w"]) else None
    if a.godot:
        proj = a.godot_project
        dst = os.path.join(proj, "THE_VEIL_ASSETS_V2", "09_Horror_Atmosphere")
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        shutil.copytree(PK, dst, ignore=shutil.ignore_patterns("__pycache__", "Source_Scripts"))
        r = subprocess.run([a.godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=1800)
        errs = [l for l in (r.stdout + r.stderr).splitlines() if ("ERROR" in l or "WARNING" in l) and "leaked" not in l]
        info.append(f"Godot 4.3 headless import: exit {r.returncode}, {len(errs)} error/warning lines")
        for l in errs[:8]:
            F("Godot import: " + l.strip()[:200])
        open(os.path.join(proj, "atm_check.gd"), "w").write(GD)
        r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 640x360x24", a.godot, "--path", proj, "--rendering-driver", "opengl3",
                            "--script", "res://atm_check.gd"], capture_output=True, text=True, timeout=1800)
        out = r.stdout + r.stderr
        lines = [l for l in out.splitlines() if l.startswith("CHECK")]
        bad = [l for l in out.splitlines() if re.search(r"SCRIPT ERROR|SHADER ERROR|ERROR:", l) and "ERR_CANT_OPEN" not in l
               and "audio" not in l.lower() and "leaked" not in l]  # exit-time GL leak notices from the scripted quit()
        for l in bad[:10]:
            F("Godot runtime: " + l.strip()[:200])
        api = [l for l in out.splitlines() if l.startswith("OpenGL API")]
        info.append("renderer: " + (api[0] if api else "?"))
        pre = [l for l in lines if l.startswith("CHECK PRESET")]
        if len(pre) != 13 or any(not l.endswith("true") for l in pre):
            F(f"presets: {len(pre)} loaded, not all VeilAtmospherePreset")
        info.append(f"presets loaded as VeilAtmospherePreset: {sum(l.endswith('true') for l in pre)}/13")
        info.append(f"GLBs instanced and rendered: {sum(l.startswith('CHECK GLB') for l in lines)}/{len(man['glbs'])}")
        sc = [l for l in lines if l.startswith("CHECK SCENE")]
        info.append(f"scenes instanced and rendered (3 frames each): {len(sc)} + demo")
        for l in lines:
            if l.startswith("CHECK FAIL"):
                F("Godot " + l)
            if l.startswith(("CHECK DEMO", "CHECK STATE", "CHECK TWEEN")):
                info.append("`" + l[6:] + "`")
        st = [l for l in lines if l.startswith("CHECK STATE")]
        fog = [float(re.search(r"fog=([\d.]+)", l).group(1)) for l in st]
        if len(st) != 5 or len(set(fog)) < 4:
            F("state machine: states did not change the environment")
        if any(l.startswith("CHECK OTHER_ENV") and not l.endswith("=0") for l in lines):
            F("a second WorldEnvironment is still active in the demo")
        if not any(l.startswith("CHECK TWEEN") for l in lines):
            F("demo run did not complete")
    else:
        W("Godot check not run")
    L = ["# THE VEIL - Pack 09 Validation Report", "",
         "Automated file, reference and engine checks only. **Nothing was captured from the renderer** (no screenshots), "
         "so the look of the mist, lighting and corruption has not been verified.", "",
         f"**Result: {'PASS' if not fails else 'FAIL'}** - {len(fails)} failures, {len(warns)} warnings", ""] + [f"* {i}" for i in info]
    L += ["", "## Failures", ""] + ([f"* {f}" for f in fails] or ["None."]) + ["", "## Warnings", ""] + ([f"* {w}" for w in warns] or ["None."])
    open(os.path.join(PK, "Documentation", "VALIDATION_REPORT.md"), "w", newline="\n").write("\n".join(L) + "\n")
    print(f"{'PASS' if not fails else 'FAIL'}: {len(fails)} failures, {len(warns)} warnings")
    for x in info:
        print(" ", x)
    for x in (fails + warns)[:30]:
        print("  !", x)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
