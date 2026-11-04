"""THE VEIL - Pack 07 Godot scenes + gallery integration.

creature_scene(): CharacterBody3D root (ready for a future enemy controller; no AI / damage / pathfinding here) with
the imported GLB instanced as "Model" (its AnimationPlayer is Model/AnimationPlayer), simple collision shapes and
Marker3D nodes. Collision is static, coarse and does not follow the animation (by design: cheap bounds).

gallery(): appends the Pack 07 .glb/.png/.tres paths to docs/index.html initialAssets and adds the pack07 filter
to docs/gallery.js the same way packs 04/05/06/08/09 were added. Idempotent.
"""
import json
import os
import re

import cr_core as C

DOCS = os.path.normpath(os.path.join(C.V2, "..", "docs"))


def _tf(pos, basis=None):
    b = basis or (1, 0, 0, 0, 1, 0, 0, 0, 1)
    return "Transform3D(" + ", ".join(f"{v:g}" for v in list(b) + [round(float(x), 4) for x in pos]) + ")"


def creature_scene(path, root_name, glb, shapes, markers, meta, script=None, root_type="CharacterBody3D", extra_nodes=""):
    """shapes: [(node, kind, params dict, pos)] kind in BoxShape3D / CylinderShape3D / CapsuleShape3D / SphereShape3D.
    markers: [(node, pos)]. meta: {key: value} stored as node metadata."""
    ext = [f'[ext_resource type="PackedScene" path="{C.res_of(glb)}" id="1_model"]']
    if script:
        ext.append(f'[ext_resource type="Script" path="{C.res_of(script)}" id="2_script"]')
    subs = []
    for k, (n, kind, prm, _) in enumerate(shapes):
        lines = [f'[sub_resource type="{kind}" id="{kind}_{k}"]']
        for key, v in prm.items():
            lines.append(f"{key} = " + (f"Vector3({v[0]:g}, {v[1]:g}, {v[2]:g})" if isinstance(v, (tuple, list)) else f"{v:g}"))
        subs.append("\n".join(lines))
    head = f'[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n\n".join(subs)
    root = [f'[node name="{root_name}" type="{root_type}"]']
    if script:
        root.append('script = ExtResource("2_script")')
    for k, v in meta.items():
        if isinstance(v, (list, tuple)):
            root.append(f"metadata/{k} = PackedStringArray(" + ", ".join(json.dumps(x) for x in v) + ")")
        elif isinstance(v, str):
            root.append(f"metadata/{k} = {json.dumps(v)}")
        else:
            root.append(f"metadata/{k} = {v:g}")
    body = ["\n".join(root), '[node name="Model" parent="." instance=ExtResource("1_model")]']
    for k, (n, kind, prm, pos) in enumerate(shapes):
        body.append(f'[node name="{n}" type="CollisionShape3D" parent="."]\ntransform = {_tf(pos)}\nshape = SubResource("{kind}_{k}")')
    if markers:
        body.append('[node name="Markers" type="Node3D" parent="."]')
        for n, pos in markers:
            body.append(f'[node name="{n}" type="Marker3D" parent="Markers"]\ntransform = {_tf(pos)}')
    txt = head.rstrip() + "\n\n" + "\n\n".join(body) + "\n" + extra_nodes
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="\n") as f:
        f.write(txt)


def gallery():
    idx = os.path.join(DOCS, "index.html")
    js = os.path.join(DOCS, "gallery.js")
    paths = []
    root = os.path.join(C.V2, "07_Creatures")
    for d, _, fs in os.walk(root):
        if "Source_Scripts" in d:
            continue
        for f in fs:
            if f.endswith((".glb", ".png", ".tres")):
                paths.append("THE_VEIL_ASSETS_V2/" + os.path.relpath(os.path.join(d, f), C.V2).replace(os.sep, "/"))
    order = {".glb": 0, ".png": 1, ".tres": 2}
    paths.sort(key=lambda p: (order[os.path.splitext(p)[1]], p))
    s = open(idx, encoding="utf-8").read()
    m = re.search(r"initialAssets=\[(.*?)\];", s, re.S)
    cur = json.loads("[" + m.group(1) + "]")
    add = [p for p in paths if p not in cur]
    if add:
        new = m.group(1) + "".join(", " + json.dumps(p) for p in add)
        s = s[:m.start(1)] + new + s[m.end(1):]
        open(idx, "w", encoding="utf-8", newline="").write(s)
    g = open(js, encoding="utf-8").read()
    if "pack07=" not in g:
        g = g.replace("pack06=p=>p.startsWith(PREFIX+'06_Characters/'),",
                      "pack06=p=>p.startsWith(PREFIX+'06_Characters/'),pack07=p=>p.startsWith(PREFIX+'07_Creatures/'),", 1)
        g = g.replace("c==='pack06'&&pack06(p)&&model(p)||", "c==='pack06'&&pack06(p)&&model(p)||c==='pack07'&&pack07(p)&&model(p)||", 1)
        g = g.replace("new Option('Pack 06 — Characters','pack06'),",
                      "new Option('Pack 06 — Characters','pack06'),new Option('Pack 07 — Creatures','pack07'),", 1)
        assert g.count("pack07") == 4, "gallery.js anchors changed"
        open(js, "w", encoding="utf-8", newline="").write(g)
    return add
