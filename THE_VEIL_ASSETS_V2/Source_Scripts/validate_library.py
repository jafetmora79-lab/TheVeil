#!/usr/bin/env python3
"""THE VEIL - Asset Pack 01 automated validation.

Lightweight file / data checks only. This does NOT and cannot verify visual
quality - that requires a human looking at the textures in Godot.

    python3 Source_Scripts/validate_library.py
Writes Documentation/VALIDATION_REPORT.md and exits non-zero on failure.
"""
import hashlib
import json
import os
import re
import sys
from itertools import combinations

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

from veil_texgen.palettes import RAMPS  # noqa: E402
from veil_texgen.registry import TEXTURES, ATLASES, PRESETS, TEXEL_DENSITY, texture_id, transparency_of  # noqa: E402

ROOT = os.path.dirname(HERE)
DOC = os.path.join(ROOT, "Documentation")
REQUIRED_FIELDS = ["id", "name", "category", "file", "width", "height", "resolution", "tiles",
                   "transparency", "intended_material", "preset", "recommended_uv_scale", "texture_filter",
                   "description"]

fails, warns, rows = [], [], []


def fail(msg):
    fails.append(msg)


def warn(msg):
    warns.append(msg)


def seam_metrics(a, axis):
    """Return (A, B) for the wrap edge along one axis.

    A = (edge jump + 2) / (mean interior jump + 2): how much harsher the wrap
        edge is than a typical neighbouring column/row (damped for very flat
        textures).
    B = edge jump / mean of the 2 strongest interior jumps: whether the edge
        is harsher than the texture's own deliberate lines (grout, joints,
        board gaps). A deliberate joint on the edge always has an interior
        twin, so it scores ~1.0.
    A texture fails only when both A > 1.6 and B > 1.25."""
    a = a.astype(float)
    if axis == 0:
        a = a.T
    d = np.abs(np.diff(a, axis=1)).mean(axis=0)
    e = np.abs(a[:, -1] - a[:, 0]).mean()
    A = (e + 2.0) / (d.mean() + 2.0)
    B = e / (np.sort(d)[-2:].mean() + 1e-6)
    return A, B


def orphan_ratio(rgb):
    k = (rgb[..., 0].astype(np.int64) << 16) | (rgb[..., 1].astype(np.int64) << 8) | rgb[..., 2]
    same = np.zeros(k.shape, bool)
    for ax, sh in ((0, 1), (0, -1), (1, 1), (1, -1)):
        same |= np.roll(k, sh, ax) == k
    return 1.0 - same.mean()


def main():
    palette = {tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for r in RAMPS.values() for h in r}
    man_path = os.path.join(DOC, "TEXTURE_MANIFEST.json")
    if not os.path.exists(man_path):
        fail("TEXTURE_MANIFEST.json missing")
        return finish()
    man = json.load(open(man_path))
    by_id = {m["id"]: m for m in man["textures"]}

    arrays = {}
    expected_files = set()
    for cat, short, fn, (w, h), tiles, preset, desc in TEXTURES:
        tid = texture_id(cat, short)
        m = by_id.get(tid)
        if m is None:
            fail(f"{tid}: missing from manifest")
            continue
        for k in REQUIRED_FIELDS:
            if m.get(k) in (None, ""):
                fail(f"{tid}: manifest field '{k}' empty")
        path = os.path.join(ROOT, m["file"])
        expected_files.add(os.path.normpath(path))
        if not os.path.exists(path):
            fail(f"{tid}: PNG missing ({m['file']})")
            continue
        try:
            with Image.open(path) as im:
                im.verify()
            im = Image.open(path)
            im.load()
        except Exception as e:  # noqa: BLE001
            fail(f"{tid}: unreadable PNG ({e})")
            continue
        if im.format != "PNG":
            fail(f"{tid}: not a PNG")
        if im.size != (w, h) or (m["width"], m["height"]) != (w, h):
            fail(f"{tid}: size {im.size} != spec {(w, h)}")
        tr = transparency_of(preset)
        want_mode = "RGB" if tr == "none" else "RGBA"
        if im.mode != want_mode:
            fail(f"{tid}: mode {im.mode}, expected {want_mode}")
        a = np.asarray(im)
        rgb = a[..., :3]
        arrays[tid] = a
        info = {"id": tid, "res": f"{w}x{h}", "tiles": tiles, "alpha": tr}

        # alpha validity
        if im.mode == "RGBA":
            al = a[..., 3]
            vis = (al > 0).mean()
            info["alpha_cov"] = f"{vis:.0%}"
            if al.min() == 255:
                fail(f"{tid}: RGBA but fully opaque (alpha unused)")
            if vis < 0.05:
                fail(f"{tid}: almost fully transparent ({vis:.1%})")
            if tr == "scissor" and ((al > 0) & (al < 255)).mean() > 0.02:
                warn(f"{tid}: scissor texture has partial alpha pixels")
            if tiles == "none":
                border = np.concatenate([al[0], al[-1], al[:, 0], al[:, -1]])
                if m["preset"] in ("VEIL_Decal_Blend", "VEIL_Cutout") and border.max() > 0:
                    fail(f"{tid}: decal/cutout border not transparent (edge bleeding)")
            pal_px = rgb[al > 0]
        else:
            pal_px = rgb.reshape(-1, 3)

        # controlled palette
        cols = {tuple(c) for c in np.unique(pal_px.reshape(-1, 3), axis=0)}
        off = cols - palette
        if off:
            fail(f"{tid}: {len(off)} colours outside the Greyhaven master palette")
        info["colours"] = len(cols)

        # not empty / not placeholder
        lum = rgb.astype(float).mean(axis=2)
        _, counts = np.unique(pal_px.reshape(-1, 3), axis=0, return_counts=True)
        dom = counts.max() / counts.sum()
        info["dominant"] = f"{dom:.0%}"
        if len(cols) < 4:
            fail(f"{tid}: only {len(cols)} colours - placeholder?")
        if lum.std() < 2.0:
            fail(f"{tid}: near-flat image (luma std {lum.std():.2f})")
        if dom > 0.85:
            fail(f"{tid}: one colour covers {dom:.0%} of pixels")

        # pixel-cluster sanity (static-noise detector)
        orr = orphan_ratio(rgb)
        info["orphans"] = f"{orr:.0%}"
        if orr > 0.45:
            warn(f"{tid}: {orr:.0%} isolated pixels - may read as noise")

        # seamless tiling
        if tiles == "uv":
            (au, bu), (av, bv) = seam_metrics(lum, 1), seam_metrics(lum, 0)
            info["seam_u"], info["seam_v"] = f"{au:.2f}/{bu:.2f}", f"{av:.2f}/{bv:.2f}"
            for ax, A_, B_ in (("U", au, bu), ("V", av, bv)):
                if A_ > 1.6 and B_ > 1.25:
                    fail(f"{tid}: wrap seam along {ax} (A={A_:.2f}, B={B_:.2f})")

        # import settings
        imp = path + ".import"
        if not os.path.exists(imp):
            fail(f"{tid}: .import file missing")
        else:
            t = open(imp).read()
            if "compress/mode=0" not in t or "mipmaps/generate=true" not in t or "detect_3d/compress_to=0" not in t:
                fail(f"{tid}: .import not lossless+mipmaps+no-3D-recompress")

        # material
        mat = os.path.join(ROOT, m["intended_material"])
        if not os.path.exists(mat):
            fail(f"{tid}: material missing ({m['intended_material']})")
        else:
            t = open(mat).read()
            refs = re.findall(r'path="(res://[^"]+)"', t)
            if len(refs) != 1:
                fail(f"{tid}: material should reference exactly one texture, found {len(refs)}")
            for r in refs:
                rel = r.split("THE_VEIL_ASSETS_V2/", 1)[-1]
                if os.path.normpath(os.path.join(ROOT, rel)) != os.path.normpath(path):
                    fail(f"{tid}: material points at {r}, expected {m['file']}")
                if not os.path.exists(os.path.join(ROOT, rel)):
                    fail(f"{tid}: material texture path does not resolve: {r}")
            exp_tr = {"none": None, "blend": "transparency = 1", "scissor": "transparency = 2"}[tr]
            if exp_tr and exp_tr not in t:
                fail(f"{tid}: material transparency mismatch (want '{exp_tr}')")
            if not exp_tr and "transparency =" in t:
                fail(f"{tid}: opaque texture but material is transparent")
            uv = m["recommended_uv_scale"]
            if tiles == "uv":
                if abs(uv[0] - TEXEL_DENSITY / w) > 1e-3 or abs(uv[1] - TEXEL_DENSITY / h) > 1e-3:
                    fail(f"{tid}: manifest UV scale {uv} breaks {TEXEL_DENSITY}px/m density")
                if uv != [1.0, 1.0] and "uv1_scale" not in t:
                    fail(f"{tid}: material missing uv1_scale")
            if f"texture_filter = {PRESETS[preset]['filter']}" not in t:
                fail(f"{tid}: material texture_filter mismatch")
        rows.append(info)

    # duplicates / identical placeholders
    hashes = {}
    for tid, a in arrays.items():
        hsh = hashlib.sha1(a.tobytes()).hexdigest()
        if hsh in hashes:
            fail(f"{tid}: pixel-identical to {hashes[hsh]}")
        hashes[hsh] = tid
    for (t1, a1), (t2, a2) in combinations(arrays.items(), 2):
        if a1.shape == a2.shape:
            d = np.abs(a1[..., :3].astype(int) - a2[..., :3].astype(int)).mean()
            if d < 4:
                fail(f"{t1} vs {t2}: near-duplicate (mean diff {d:.1f})")

    # stray files
    for sub in os.listdir(os.path.join(ROOT, "01_Textures")):
        if sub == "Atlases":
            continue
        for f in os.listdir(os.path.join(ROOT, "01_Textures", sub)):
            if f.endswith(".png") and os.path.normpath(os.path.join(ROOT, "01_Textures", sub, f)) not in expected_files:
                warn(f"unregistered PNG: 01_Textures/{sub}/{f}")

    # atlases
    for an, spec in ATLASES.items():
        meta = man["atlases"].get(an)
        if not meta:
            fail(f"{an}: missing from manifest")
            continue
        p = os.path.join(ROOT, meta["file"])
        if not os.path.exists(p):
            fail(f"{an}: atlas PNG missing")
            continue
        at = np.asarray(Image.open(p))
        if (at.shape[1], at.shape[0]) != tuple(spec["size"]):
            fail(f"{an}: atlas size mismatch")
        if not os.path.exists(p + ".import"):
            fail(f"{an}: .import missing")
        for c in meta["cells"]:
            if c["texture"] == "RESERVED":
                continue
            x, y, cw, ch = c["px"]
            src = arrays.get(c["texture"])
            if src is None:
                fail(f"{an}: cell {c['index']} references unknown {c['texture']}")
                continue
            tiled = np.tile(src, (ch // src.shape[0], cw // src.shape[1], 1))
            cell = at[y:y + ch, x:x + cw]
            if cell.shape[2] != tiled.shape[2]:
                tiled = tiled[..., :cell.shape[2]] if tiled.shape[2] > cell.shape[2] else tiled
            if not np.array_equal(cell[..., :3], tiled[..., :3]):
                fail(f"{an}: cell {c['index']} does not match {c['texture']}")
        for mpath in meta["materials"].values():
            mp = os.path.join(ROOT, mpath)
            if not os.path.exists(mp):
                fail(f"{an}: material missing {mpath}")
            else:
                for r in re.findall(r'path="(res://[^"]+)"', open(mp).read()):
                    if not os.path.exists(os.path.join(ROOT, r.split("THE_VEIL_ASSETS_V2/", 1)[-1])):
                        fail(f"{an}: material path does not resolve: {r}")

    for pn in PRESETS:
        if not os.path.exists(os.path.join(ROOT, "Materials_Godot", "_Presets", f"P_{pn}.tres")):
            fail(f"preset template missing: P_{pn}.tres")
    if len(man["textures"]) != len(TEXTURES):
        fail(f"manifest has {len(man['textures'])} textures, registry has {len(TEXTURES)}")
    return finish()


def finish():
    lines = ["# THE VEIL - Pack 01 Validation Report", "",
             "Automated file/data checks only. **Visual quality is NOT verified by this report** - "
             "it must be judged by a person in Godot.", "",
             f"- Textures checked: {len(rows)}",
             f"- Failures: {len(fails)}",
             f"- Warnings: {len(warns)}", "",
             "Checks: file exists, PNG readable, resolution = spec, RGB/RGBA mode matches transparency, "
             "alpha actually used and decal borders clear, every colour from the master palette, "
             "not flat/placeholder, not duplicate, seam continuity on tiled axes, .import lossless+mipmaps, "
             "material exists and points at the right texture, transparency/filter/UV scale consistent, "
             "manifest complete, atlas cells match sources.", "",
             "Seam A/B (see seam_metrics): A = wrap-edge jump vs. average interior jump (damped); "
             "B = wrap-edge jump vs. the strongest deliberate interior lines. Fail only if A > 1.6 AND B > 1.25. "
             "This catches gross wrap breaks; subtle seams still need a visual check in Godot. "
             "Orphans = share of pixels with no "
             "same-colour 4-neighbour (high values suggest noise rather than pixel clusters).", ""]
    if fails:
        lines += ["## Failures", ""] + [f"- {f}" for f in fails] + [""]
    if warns:
        lines += ["## Warnings", ""] + [f"- {w}" for w in warns] + [""]
    lines += ["## Per-texture metrics", "",
              "| ID | Res | Tiles | Alpha | Colours | Dominant | Orphans | Seam U | Seam V | Alpha cover |",
              "|---|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        lines.append(f"| `{r['id']}` | {r['res']} | {r['tiles']} | {r['alpha']} | {r.get('colours', '')} | "
                     f"{r.get('dominant', '')} | {r.get('orphans', '')} | {r.get('seam_u', '-')} | "
                     f"{r.get('seam_v', '-')} | {r.get('alpha_cov', '-')} |")
    os.makedirs(DOC, exist_ok=True)
    with open(os.path.join(DOC, "VALIDATION_REPORT.md"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{len(rows)} textures, {len(fails)} failures, {len(warns)} warnings")
    for f_ in fails:
        print("FAIL", f_)
    for w in warns:
        print("WARN", w)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
