#!/usr/bin/env python3
"""Build Pack 02 supplementary textures + their Godot materials."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "Source_Scripts"))

from build_library import write_import  # noqa: E402  (Pack 01 import writer: lossless + mipmaps)
from town_textures import TEXTURES, SIGN_RECTS  # noqa: E402
from veil_mesh.materials import TOWN, V2, MATS, all_town_materials, town_tres, RES_ROOT  # noqa: E402


def main():
    tdir = os.path.join(TOWN, "Textures")
    mdir = os.path.join(TOWN, "Materials")
    os.makedirs(tdir, exist_ok=True)
    os.makedirs(mdir, exist_ok=True)
    manifest = []
    for name, (fn, size, alpha, desc) in TEXTURES.items():
        img = fn().to_image()
        assert img.size == size, (name, img.size, size)
        assert (img.mode == "RGBA") == alpha, name
        p = os.path.join(tdir, f"T_Town_{name}.png")
        img.save(p, format="PNG", optimize=True)
        write_import(p, RES_ROOT + "/" + os.path.relpath(p, V2).replace(os.sep, "/"))
        manifest.append({"name": f"T_Town_{name}", "file": os.path.relpath(p, V2).replace(os.sep, "/"),
                         "resolution": f"{size[0]}x{size[1]}", "alpha": alpha, "description": desc})
    for m in all_town_materials():
        with open(os.path.join(TOWN, MATS[m]["tres"].split("02_Town/")[1]), "w", newline="\n") as f:
            f.write(town_tres(MATS[m]))
    # Optional world-space (triplanar) road materials: identical textures and
    # density, but sampled in world space so 10 m modules never show tiling
    # seams. Slightly more expensive (3 samples) - opt-in, not used by default.
    for tex, pre in (("Road_Asphalt", "VEIL_Ground"), ("Road_AsphaltCracked", "VEIL_Ground"),
                     ("Road_ParkingLotAsphalt", "VEIL_Ground")):
        m = json.load(open(os.path.join(V2, "Documentation", "TEXTURE_MANIFEST.json")))
        t = [x for x in m["textures"] if x["id"] == tex][0]
        sc = t["recommended_uv_scale"][0]
        name = f"M_Town_{tex.split('_', 1)[1]}_WorldUV"
        with open(os.path.join(mdir, name + ".tres"), "w", newline="\n") as f:
            f.write(f"""[gd_resource type="StandardMaterial3D" load_steps=2 format=3]

[ext_resource type="Texture2D" path="{RES_ROOT}/{t['file']}" id="1_albedo"]

[resource]
resource_name = "{name}"
albedo_texture = ExtResource("1_albedo")
metallic_specular = 0.2
roughness = 0.97
uv1_scale = Vector3({sc}, {sc}, {sc})
uv1_triplanar = true
uv1_triplanar_sharpness = 8.0
uv1_world_triplanar = true
texture_filter = 4
""")
    W = 256
    atlas = {k: {"px": list(r), "uv": [r[0] / W, r[1] / W, (r[0] + r[2]) / W, (r[1] + r[3]) / W]}
             for k, r in SIGN_RECTS.items()}
    os.makedirs(os.path.join(TOWN, "Documentation"), exist_ok=True)
    with open(os.path.join(TOWN, "Documentation", "PACK02_TEXTURES.json"), "w", newline="\n") as f:
        json.dump({"textures": manifest, "sign_atlas_rects": atlas}, f, indent=2)
    print(f"{len(manifest)} Pack 02 textures, {len(all_town_materials())} materials")


if __name__ == "__main__":
    main()
