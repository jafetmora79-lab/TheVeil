#!/usr/bin/env python3
"""THE VEIL - Asset Pack 01 builder.

Regenerates every PNG texture, atlas, Godot import file, material resource,
palette export and manifest from source. Deterministic: same code -> same
bytes.

    python3 Source_Scripts/build_library.py [--res-root res://THE_VEIL_ASSETS_V2]

--res-root is where THE_VEIL_ASSETS_V2 lives inside your Godot project.
"""
import argparse
import csv
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from PIL import Image  # noqa: E402

from veil_texgen.palettes import RAMPS  # noqa: E402
from veil_texgen.registry import (TEXTURES, ATLASES, PRESETS, TEXEL_DENSITY, CATEGORY_DIR,  # noqa: E402
                                  texture_id, transparency_of)

ROOT = os.path.dirname(HERE)
TEX_DIR = os.path.join(ROOT, "01_Textures")
MAT_DIR = os.path.join(ROOT, "Materials_Godot")
DOC_DIR = os.path.join(ROOT, "Documentation")
ART_DIR = os.path.join(ROOT, "00_Art_Direction")

FILTER_NAME = {2: "nearest_mipmaps", 4: "nearest_mipmaps_anisotropic"}


def fmt(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def res_path(res_root, *parts):
    return res_root.rstrip("/") + "/" + "/".join(parts)


def write_import(png_abs, res_png):
    md5 = hashlib.md5(res_png.encode("utf-8")).hexdigest()
    name = os.path.basename(png_abs)
    dest = f"res://.godot/imported/{name}-{md5}.ctex"
    txt = f"""[remap]

importer="texture"
type="CompressedTexture2D"
path="{dest}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res_png}"
dest_files=["{dest}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""
    with open(png_abs + ".import", "w", newline="\n") as f:
        f.write(txt)


def material_tres(name, preset, res_tex=None, uv=(1.0, 1.0)):
    p = PRESETS[preset]
    lines = []
    if res_tex:
        lines += ['[gd_resource type="StandardMaterial3D" load_steps=2 format=3]', "",
                  f'[ext_resource type="Texture2D" path="{res_tex}" id="1_albedo"]', ""]
    else:
        lines += ['[gd_resource type="StandardMaterial3D" format=3]', ""]
    lines += ["[resource]", f'resource_name = "{name}"']
    tr = p.get("transparency", "none")
    if tr == "blend":
        lines.append("transparency = 1")
    elif tr == "scissor":
        lines += ["transparency = 2", "alpha_scissor_threshold = 0.5"]
    if p.get("cull") == "disabled":
        lines.append("cull_mode = 2")
    if res_tex:
        lines.append('albedo_texture = ExtResource("1_albedo")')
    if p["metallic"] > 0:
        lines.append(f"metallic = {fmt(p['metallic'])}")
    lines.append(f"metallic_specular = {fmt(p['specular'])}")
    lines.append(f"roughness = {fmt(p['roughness'])}")
    if uv != (1.0, 1.0):
        lines.append(f"uv1_scale = Vector3({fmt(uv[0])}, {fmt(uv[1])}, 1)")
    lines.append(f"texture_filter = {p['filter']}")
    if p.get("repeat") is False:
        lines.append("texture_repeat = false")
    return "\n".join(lines) + "\n"


def save_png(img, path):
    img.save(path, format="PNG", optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--res-root", default="res://THE_VEIL_ASSETS_V2")
    args = ap.parse_args()
    rr = args.res_root

    manifest = []
    images = {}
    for cat, short, fn, (w, h), tiles, preset, desc in TEXTURES:
        tid = texture_id(cat, short)
        cv = fn()
        img = cv.to_image()
        if img.size != (w, h):
            raise SystemExit(f"{tid}: generator returned {img.size}, spec {(w, h)}")
        sub = CATEGORY_DIR[cat]
        os.makedirs(os.path.join(TEX_DIR, sub), exist_ok=True)
        fname = f"T_{tid}.png"
        png_abs = os.path.join(TEX_DIR, sub, fname)
        save_png(img, png_abs)
        res_png = res_path(rr, "01_Textures", sub, fname)
        write_import(png_abs, res_png)
        images[tid] = img

        uv = (TEXEL_DENSITY / w, TEXEL_DENSITY / h) if tiles == "uv" else (1.0, 1.0)
        mname = f"M_{tid}"
        os.makedirs(os.path.join(MAT_DIR, sub), exist_ok=True)
        with open(os.path.join(MAT_DIR, sub, mname + ".tres"), "w", newline="\n") as f:
            f.write(material_tres(mname, preset, res_png, uv))
        manifest.append({
            "id": tid, "name": short, "category": cat,
            "file": f"01_Textures/{sub}/{fname}",
            "width": w, "height": h, "resolution": f"{w}x{h}",
            "tiles": {"uv": "seamless U+V", "none": "no (0..1 unwrap / decal)"}[tiles],
            "tiles_code": tiles,
            "transparency": transparency_of(preset),
            "channels": "RGBA" if img.mode == "RGBA" else "RGB",
            "intended_material": f"Materials_Godot/{sub}/{mname}.tres",
            "preset": preset,
            "recommended_uv_scale": [round(uv[0], 4), round(uv[1], 4)],
            "uv_convention": "meter-UV (1 UV unit = 1 m)" if tiles == "uv" else "0..1 unwrap",
            "world_coverage_m": [w / TEXEL_DENSITY, h / TEXEL_DENSITY] if tiles == "uv" else None,
            "texture_filter": FILTER_NAME[PRESETS[preset]["filter"]],
            "description": desc,
        })
        print(f"  {tid:32s} {w}x{h} {tiles}")

    # --- atlases ---------------------------------------------------------------
    atlas_meta = {}
    os.makedirs(os.path.join(TEX_DIR, "Atlases"), exist_ok=True)
    os.makedirs(os.path.join(MAT_DIR, "Atlases"), exist_ok=True)
    for aname, spec in ATLASES.items():
        W, H = spec["size"]
        c = spec["cell"]
        mode = "RGBA" if spec["alpha"] else "RGB"
        from veil_texgen.core import P
        fill = (0, 0, 0, 0) if spec["alpha"] else tuple(int(v) for v in P.rgb[P("concrete", 3)])
        atlas = Image.new(mode, (W, H), fill)
        cols = W // c
        cells = []
        for i, tid in enumerate(spec["cells"]):
            x, y = (i % cols) * c, (i // cols) * c
            entry = {"index": i, "texture": tid, "px": [x, y, c, c],
                     "uv": [x / W, y / H, (x + c) / W, (y + c) / H]}
            if tid is None:
                entry["texture"] = "RESERVED"
            else:
                src = images[tid].convert(mode)
                for oy in range(0, c, src.size[1]):
                    for ox in range(0, c, src.size[0]):
                        atlas.paste(src, (x + ox, y + oy))
                if src.size[0] < c:
                    entry["note"] = f"{src.size[0]}px texture tiled {c // src.size[0]}x{c // src.size[1]} to keep 64 px/m"
            cells.append(entry)
        fname = f"T_{aname}.png"
        png_abs = os.path.join(TEX_DIR, "Atlases", fname)
        save_png(atlas, png_abs)
        res_png = res_path(rr, "01_Textures", "Atlases", fname)
        write_import(png_abs, res_png)
        mats = {}
        if spec["alpha"]:
            for suffix, preset in (("Blend", "VEIL_Decal_Blend"), ("Cutout", "VEIL_Cutout")):
                mn = f"M_{aname}_{suffix}"
                mats[suffix] = f"Materials_Godot/Atlases/{mn}.tres"
                with open(os.path.join(MAT_DIR, "Atlases", mn + ".tres"), "w", newline="\n") as f:
                    f.write(material_tres(mn, preset, res_png))
        else:
            mn = f"M_{aname}"
            mats["Opaque"] = f"Materials_Godot/Atlases/{mn}.tres"
            with open(os.path.join(MAT_DIR, "Atlases", mn + ".tres"), "w", newline="\n") as f:
                f.write(material_tres(mn, spec["preset"], res_png))
        atlas_meta[aname] = {"file": f"01_Textures/Atlases/{fname}", "size": [W, H], "cell": c,
                             "channels": mode, "materials": mats, "cells": cells}

    # --- material presets (texture-less templates) ----------------------------
    os.makedirs(os.path.join(MAT_DIR, "_Presets"), exist_ok=True)
    for pname in PRESETS:
        with open(os.path.join(MAT_DIR, "_Presets", f"P_{pname}.tres"), "w", newline="\n") as f:
            f.write(material_tres(f"P_{pname}", pname))

    # --- manifest ---------------------------------------------------------------
    os.makedirs(DOC_DIR, exist_ok=True)
    with open(os.path.join(DOC_DIR, "TEXTURE_MANIFEST.json"), "w", newline="\n") as f:
        json.dump({"pack": "THE VEIL - Asset Pack 01", "texel_density_px_per_m": TEXEL_DENSITY,
                   "res_root": rr, "textures": manifest, "atlases": atlas_meta,
                   "presets": PRESETS}, f, indent=2)
    keys = ["id", "category", "file", "resolution", "tiles", "transparency", "channels",
            "intended_material", "preset", "recommended_uv_scale", "texture_filter", "description"]
    with open(os.path.join(DOC_DIR, "TEXTURE_MANIFEST.csv"), "w", newline="") as f:
        wr = csv.writer(f)
        wr.writerow(keys)
        for m in manifest:
            wr.writerow([m[k] if k != "recommended_uv_scale" else f"{m[k][0]} x {m[k][1]}" for k in keys])
    md = ["# THE VEIL - Pack 01 Texture Manifest", "",
          f"Texel density: **{TEXEL_DENSITY} px/m** for every surface. Generated by `Source_Scripts/build_library.py` - do not edit by hand.", "",
          "| ID | Category | Res | Tiles | Alpha | UV scale | Material | Notes |",
          "|---|---|---|---|---|---|---|---|"]
    for m in manifest:
        md.append(f"| `{m['id']}` | {m['category']} | {m['resolution']} | {m['tiles_code']} | {m['transparency']} | "
                  f"{m['recommended_uv_scale'][0]} x {m['recommended_uv_scale'][1]} | `{os.path.basename(m['intended_material'])}` | {m['description']} |")
    md += ["", "## Atlases", ""]
    for an, a in atlas_meta.items():
        md += [f"### {an} ({a['size'][0]}x{a['size'][1]}, {a['cell']}px cells, {a['channels']})", "",
               "| Cell | Texture | Pixel rect (x,y,w,h) | UV rect (u0,v0,u1,v1) |", "|---|---|---|---|"]
        for c in a["cells"]:
            md.append(f"| {c['index']} | `{c['texture']}` | {tuple(c['px'])} | ({', '.join(fmt(v) for v in c['uv'])}) |")
        md.append("")
    with open(os.path.join(DOC_DIR, "TEXTURE_MANIFEST.md"), "w", newline="\n") as f:
        f.write("\n".join(md) + "\n")

    # --- palette exports --------------------------------------------------------
    os.makedirs(ART_DIR, exist_ok=True)
    with open(os.path.join(ART_DIR, "GREYHAVEN_PALETTE.gpl"), "w", newline="\n") as f:
        f.write("GIMP Palette\nName: THE VEIL - Greyhaven Master\nColumns: 7\n#\n")
        for rn, ramp in RAMPS.items():
            for k, hx in enumerate(ramp):
                r, g, b = (int(hx[i:i + 2], 16) for i in (1, 3, 5))
                f.write(f"{r:3d} {g:3d} {b:3d}\t{rn}_{k}\n")
    with open(os.path.join(ART_DIR, "GREYHAVEN_PALETTE.json"), "w", newline="\n") as f:
        json.dump(RAMPS, f, indent=2)
    print(f"Built {len(manifest)} textures, {len(atlas_meta)} atlases, {len(PRESETS)} presets.")


if __name__ == "__main__":
    main()
