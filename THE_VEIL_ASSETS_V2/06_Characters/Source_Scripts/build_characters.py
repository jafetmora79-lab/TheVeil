#!/usr/bin/env python3
"""THE VEIL - Pack 06 builder: Greyhaven characters (story cast).

    python3 06_Characters/Source_Scripts/build_characters.py

For every character in chr_roster.ROSTER:
  * skinned mesh on the shared VEIL humanoid skeleton (chr_core.BONES), rest = relaxed A-pose
  * 256x256 pixel-art atlas (chr_tex) -> Textures/T_Chr_<Name>.png (+ .import), embedded in the GLB too
  * Materials/M_Chr_<Name>.tres (StandardMaterial3D, nearest filtering) mapped in the .glb.import
  * <Folder>/CHR_<Name>.glb
Protagonist also gets Protagonist/CHR_Protagonist_FP_Arms.glb (camera-space first-person arms).
Shared_Rigs/VEIL_Humanoid_Skeleton.json documents bone names, parents and every character's rest joints.
Deterministic. Packs 01-03 are read, never written.
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
CHR = os.path.join(V2, "06_Characters")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))

from veil_mesh.materials import MATS, _reg, town_tres, RES_ROOT  # noqa: E402
from veil_mesh.gltf import write_glb_import  # noqa: E402
from build_library import write_import  # noqa: E402

import numpy as np  # noqa: E402

import chr_core  # noqa: E402
import chr_body  # noqa: E402
import chr_tex  # noqa: E402
from chr_roster import ROSTER, ROSTER_V2  # noqa: E402


def rel(p):
    return os.path.relpath(p, V2).replace(os.sep, "/")


def material(name, png):
    m = f"M_Chr_{name}"
    _reg(m, png=png, tres=f"06_Characters/Materials/{m}.tres", uv=(1.0, 1.0), alpha="OPAQUE", double=False,
         repeat=False, rough=1.0, metal=0.0, pack="06")
    p = os.path.join(V2, MATS[m]["tres"])
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", newline="\n") as f:
        f.write(town_tres(MATS[m]))
    return m


def export(c, body, bones, glb, mat, png_bytes, extras):
    bidx = {b: i for i, (b, _) in enumerate(bones)}
    arrays = body.m.finish(bidx)
    os.makedirs(os.path.dirname(glb), exist_ok=True)
    chr_core.write_glb(glb, os.path.basename(glb)[:-4], bones, body.J, arrays, png_bytes, mat,
                       extra_nodes=body.extra_nodes, extras=extras)
    write_glb_import(glb, [mat])
    P = arrays[0]
    return dict(triangles=int(len(arrays[5]) // 3), vertices=int(len(P)), bones=len(bones),
                bounds_min=[round(float(v), 3) for v in P.min(0)], bounds_max=[round(float(v), 3) for v in P.max(0)],
                sockets=[n for n, _, _ in body.extra_nodes])


def main():
    tdir = os.path.join(CHR, "Textures")
    os.makedirs(tdir, exist_ok=True)
    manifest, rig = [], {"bones": [{"name": b, "parent": p} for b, p in chr_core.BONES],
                         "fp_bones": [{"name": b, "parent": p} for b, p in chr_core.FP_BONES],
                         "convention": "metres, +Y up, character faces +Z, origin between the feet; rest = relaxed A-pose; "
                                       "bone rest rotations are identity; names = Godot SkeletonProfileHumanoid",
                         "rest_joints": {}}
    for c in ROSTER + ROSTER_V2:
        body = chr_body.Body(c).build()
        at = chr_tex.paint(c, body.meta)
        img = at.image()
        png = os.path.join(tdir, f"T_Chr_{c['name']}.png")
        img.save(png, format="PNG", optimize=True)
        write_import(png, RES_ROOT + "/" + rel(png))
        buf = io.BytesIO()
        img.save(buf, format="PNG", optimize=True)
        mat = material(c["name"], png)
        glb = os.path.join(CHR, c["folder"], f"CHR_{c['name']}.glb")
        extras = {"veil_character": c["name"], "title": c["title"], "role": c["role"], "height_m": c["height"],
                  "rest_pose": "A-pose", "forward": "+Z"}
        st = export(c, body, chr_core.BONES, glb, mat, buf.getvalue(), extras)
        manifest.append(dict(name=f"CHR_{c['name']}", character=c["name"], title=c["title"], role=c["role"], glb=rel(glb),
                             texture=rel(png), texture_size="256x256", material=rel(os.path.join(V2, MATS[mat]["tres"])),
                             height_m=c["height"], rigged=True, skeleton="VEIL_Humanoid (23 bones)", revision=c.get("rev", 1), **st))
        rig["rest_joints"][c["name"]] = {b: [round(float(v), 4) for v in body.J[b]] for b, _ in chr_core.BONES}
        if c.get("fp_arms"):
            fb = chr_body.fp_arms(c)
            glb = os.path.join(CHR, c["folder"], f"CHR_{c['name']}_FP_Arms.glb")
            extras = {"veil_character": c["name"], "kind": "first_person_arms",
                      "space": "camera: origin = Camera3D, looks -Z, +Y up; parent this under the player camera"}
            st = export(c, fb, chr_core.FP_BONES, glb, mat, buf.getvalue(), extras)
            manifest.append(dict(name=f"CHR_{c['name']}_FP_Arms", character=c["name"], title=c["title"] + " - first-person arms",
                                 role="first-person view model", glb=rel(glb), texture=rel(png), texture_size="256x256",
                                 material=rel(os.path.join(V2, MATS[mat]["tres"])), height_m=None, rigged=True,
                                 skeleton="VEIL_FP_Arms (9 bones)", **st))
            rig["fp_rest_joints"] = {b: [round(float(v), 4) for v in fb.J[b]] for b, _ in chr_core.FP_BONES}
    sr = os.path.join(CHR, "Shared_Rigs")
    os.makedirs(sr, exist_ok=True)
    with open(os.path.join(sr, "VEIL_Humanoid_Skeleton.json"), "w", newline="\n") as f:
        json.dump(rig, f, indent=1)
    doc = os.path.join(CHR, "Documentation")
    os.makedirs(doc, exist_ok=True)
    with open(os.path.join(doc, "CHARACTER_MANIFEST.json"), "w", newline="\n") as f:
        json.dump({"pack": "THE VEIL - Pack 06 Greyhaven Characters", "models": manifest}, f, indent=1)
    # lineup scene for quick inspection in the editor (no game logic)
    ext, nodes = [], []
    for k, m in enumerate(manifest):
        ext.append(f'[ext_resource type="PackedScene" path="{RES_ROOT}/{m["glb"]}" id="{k + 1}_{m["character"]}"]')
        x = (k - len(manifest) / 2) * 1.1
        y = 1.62 if m["height_m"] is None else 0.0
        nodes += [f'[node name="{m["name"]}" parent="." instance=ExtResource("{k + 1}_{m["character"]}")]',
                  f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.2f}, {y}, 0)", ""]
    with open(os.path.join(sr, "Characters_Lineup.tscn"), "w", newline="\n") as f:
        f.write("\n".join([f"[gd_scene load_steps={len(ext) + 1} format=3]", ""] + ext +
                          ["", '[node name="Characters_Lineup" type="Node3D"]', ""] + nodes))
    print(f"{len(manifest)} character GLBs; tris: " + ", ".join(f"{m['character']}{'(FP)' if 'FP' in m['name'] else ''} {m['triangles']}" for m in manifest))


if __name__ == "__main__":
    main()
