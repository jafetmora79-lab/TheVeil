#!/usr/bin/env python3
"""THE VEIL - Pack 08 builder: weapons, survival tools, inventory items and story props.

    python3 08_Inventory/Source_Scripts/build_inventory.py

* Textures/T_Inv_Atlas.png (+ .import): one shared 256x256 pixel-art atlas (inv_atlas.py)
* Shared_Materials/M_Inv_Atlas.tres: one StandardMaterial3D, nearest filtering -> every item = 1 draw call
* <Category>/INV_*.glb (+ .import remapping the material to the .tres); the atlas PNG is embedded in each GLB
  so browsers / other tools show the real texture
* Documentation/INVENTORY_MANIFEST.json/.md
Deterministic. Other packs are read, never written.
"""
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
INV = os.path.join(V2, "08_Inventory")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))

from veil_mesh.materials import MATS, _reg, town_tres, RES_ROOT  # noqa: E402
from veil_mesh.gltf import GLBWriter, write_glb_import  # noqa: E402
from build_library import write_import  # noqa: E402

import inv_atlas  # noqa: E402
import inv_models  # noqa: E402


def rel(p):
    return os.path.relpath(p, V2).replace(os.sep, "/")


def _pad(b, ch=b"\x00"):
    return b + ch * ((4 - len(b) % 4) % 4)


def embed_images(glb):
    """move external image URIs into the binary chunk (self-contained GLB)"""
    b = open(glb, "rb").read()
    jl = struct.unpack_from("<I", b, 12)[0]
    js = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack_from("<I", b, off)[0]
    binb = bytearray(b[off + 8:off + 8 + bl])
    for img in js.get("images", []):
        if "uri" not in img:
            continue
        data = open(os.path.normpath(os.path.join(os.path.dirname(glb), img.pop("uri"))), "rb").read()
        binb = bytearray(_pad(bytes(binb)))
        js["bufferViews"].append({"buffer": 0, "byteOffset": len(binb), "byteLength": len(data)})
        binb += data
        img["bufferView"] = len(js["bufferViews"]) - 1
        img["mimeType"] = "image/png"
    binb = bytearray(_pad(bytes(binb)))
    js["buffers"][0]["byteLength"] = len(binb)
    jb = _pad(json.dumps(js, separators=(",", ":")).encode(), b" ")
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(binb))
    out += struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(binb), 0x004E4942) + bytes(binb)
    open(glb, "wb").write(out)


def main():
    tdir = os.path.join(INV, "Textures")
    os.makedirs(tdir, exist_ok=True)
    png = os.path.join(tdir, "T_Inv_Atlas.png")
    inv_atlas.build(png)
    write_import(png, RES_ROOT + "/" + rel(png))
    mat = "M_Inv_Atlas"
    _reg(mat, png=png, tres="08_Inventory/Shared_Materials/M_Inv_Atlas.tres", uv=(1.0, 1.0), alpha="OPAQUE", double=False, repeat=False,
         rough=0.8, metal=0.0, pack="08")
    tp = os.path.join(V2, MATS[mat]["tres"])
    os.makedirs(os.path.dirname(tp), exist_ok=True)
    open(tp, "w", newline="\n").write(town_tres(MATS[mat]))
    man = []
    for prio, fn in inv_models.ITEMS:
        spec = fn()
        meta = spec.pop("meta")
        folder = os.path.join(INV, inv_models.FOLDER[meta["category"]])
        os.makedirs(folder, exist_ok=True)
        glb = os.path.join(folder, spec["name"] + ".glb")
        used = GLBWriter(glb).write(spec)
        embed_images(glb)
        write_glb_import(glb, used)
        tris = len(spec["children"][0]["mb"].parts[mat]["i"]) // 3
        nodes = [c["name"] for c in spec["children"] if "mb" not in c]
        man.append(dict(name=spec["name"], category=meta["category"], priority=prio, glb=rel(glb), triangles=tris,
                        texture="08_Inventory/Textures/T_Inv_Atlas.png (256x256, shared)", material=MATS[mat]["tres"],
                        size_m=meta["size"], collision="convex box", markers=nodes, grip=meta.get("grip"), holdable=meta.get("holdable", False),
                        grip_note=meta.get("grip_note"), description=meta["desc"], status="new"))
    doc = os.path.join(INV, "Documentation")
    os.makedirs(doc, exist_ok=True)
    json.dump({"pack": "THE VEIL - Pack 08 Inventory, Tools & Weapons", "existing_reused": [], "models": man},
              open(os.path.join(doc, "INVENTORY_MANIFEST.json"), "w", newline="\n"), indent=1)
    print(f"{len(man)} GLBs, {sum(m['triangles'] for m in man)} triangles total")


if __name__ == "__main__":
    main()
