"""THE VEIL - Pack 07 build entry point.

    python3 07_Creatures/Source_Scripts/build_creatures.py [colossus mist hound skitter shellcrawler]

Builds the requested creatures (default: all that exist), runs the baked-frame skinning checks (cr_check) on
every clip, writes Documentation/CREATURE_MANIFEST.json and integrates the GLBs / textures / materials into the
browser gallery (docs/index.html + docs/gallery.js).
"""
import importlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cr_core as C  # noqa: E402
import cr_check as K  # noqa: E402
import cr_scenes as S  # noqa: E402

ORDER = ["colossus", "mist", "hound", "skitter", "shellcrawler"]
MODULES = {"colossus": "build_colossus", "mist": "build_mist_tentacles", "hound": "build_hound",
           "skitter": "build_skitter", "shellcrawler": "build_shellcrawler"}
MANIFEST = os.path.join(C.CR, "Documentation", "CREATURE_MANIFEST.json")


def check(r):
    rig = r["rig"]
    arr = K.mesh_arrays(r["meshes"], rig)
    feet = r.get("feet", [])
    out = {}
    for c in r["clips"]:
        fr = r["frames"][c.name]
        a = K.check_clip(rig, arr, fr, every=1, edge_floor=r.get("edge_floor", 0.05))
        if feet:
            a.update(K.feet_report(rig, fr, feet))
        a["loop_seamless"] = K.loop_ok(c) if c.loop else None
        out[c.name] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in a.items()}
    return out


def entry(r, checks):
    return {"name": r["name"], "glb": os.path.relpath(r["glb"], C.V2).replace(os.sep, "/"), "triangles": r["tris"],
            "bones": len(r["rig"].bones), "bone_names": r["rig"].names,
            "materials": sorted(r["mats"].keys()), "sockets": [s[0] for s in r["sockets"]],
            "clips": [{"name": c.name, "duration_s": round(c.duration, 3), "loop": c.loop} for c in r["clips"]],
            "scene": r.get("scene"), "probe_bone": r.get("probe", r["rig"].names[1]),
            "edge_floor": r.get("edge_floor", 0.05), "feet": r.get("feet", []), "checks": checks, "limits": r.get("limits", {})}


def main(argv):
    want = [a for a in argv if a in MODULES] or [k for k in ORDER if os.path.exists(os.path.join(HERE, MODULES[k] + ".py"))]
    man = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {"pack": "07_Creatures", "creatures": {}}
    for k in want:
        mod = importlib.import_module(MODULES[k])
        results = mod.build()
        for r in (results if isinstance(results, list) else [results]):
            ch = check(r)
            man["creatures"][r["name"]] = entry(r, ch)
            print(f"{r['name']}: {r['tris']} tris, {len(r['rig'].bones)} bones, {len(r['clips'])} clips")
            for n, v in ch.items():
                print(f"   {n:24s} min_y {v['min_y']:7.3f}  stretch {v['max_stretch']:.2f} (99.9% {v['p999_stretch']:.2f})"
                      f"  loop {v['loop_seamless']}")
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    man["creatures"] = {k: man["creatures"][k] for k in sorted(man["creatures"])}
    with open(MANIFEST, "w", newline="\n") as f:
        json.dump(man, f, indent=1)
        f.write("\n")
    added = S.gallery()
    print("gallery: +", len(added), "paths")


if __name__ == "__main__":
    main(sys.argv[1:])
