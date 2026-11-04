#!/usr/bin/env python3
"""THE VEIL - Pack 04 builder: commercial buildings, explorable interiors, modular fixtures, Godot scenes.

    python3 04_Commercial/Source_Scripts/build_commercial.py

* Textures/T_Com4_Atlas.png (+ .import) and Materials/M_Com4_{Atlas,Glass,Glow}.tres; building shells use Pack 01 materials
* Shared_Props/COM_*.glb            modular fixtures & props (gondolas, coolers, checkouts, counters, racks, pumps ...)
* <Location>/COM_<Location>.glb     building: exterior + interior + walk collision + door / auto-door nodes
* <Location>/COM_<Location>_Furnishing.glb   every fixture of that location batched (one static mesh + trimesh collision)
* Godot_Scenes/<Location>.tscn      building + furnishing + scene-instanced props + lights + doorway / interaction / nav markers
* Godot_Scenes/Greyhaven_Commercial.tscn (all locations in their Pack 02 zones), Greyhaven_Town_Complete.tscn (+ Pack 02/03)
* Documentation/COMMERCIAL_MANIFEST.json
Deterministic. Other packs are read, never written.
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
P4 = os.path.join(V2, "04_Commercial")
for p in ("03_Residential", "02_Town", "08_Inventory"):
    sys.path.insert(0, os.path.join(V2, p, "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))

import com_atlas  # noqa: E402

import com_fixtures as FX  # noqa: E402
import com_plans as CP  # noqa: E402
import furnish_build  # noqa: E402
import placement  # noqa: E402
from veil_mesh.materials import MATS, town_tres, RES_ROOT  # noqa: E402
from veil_mesh.gltf import GLBWriter, write_glb_import, COL_KEY  # noqa: E402
from veil_mesh.mesh import MB, T, Ry  # noqa: E402
from build_library import write_import  # noqa: E402
from build_inventory import embed_images  # noqa: E402

RES4 = RES_ROOT + "/04_Commercial"
FOLDER = {"supermarket": "Supermarket", "video_game_store": "Video_Game_Store", "gas_station": "Gas_Station", "pharmacy": "Pharmacy",
          "municipal_archive": "Municipal_Archive"}
LIGHT_COL = {"supermarket": "Color(1, 0.97, 0.9, 1)", "video_game_store": "Color(1, 0.88, 0.72, 1)", "gas_station": "Color(1, 0.97, 0.92, 1)",
             "pharmacy": "Color(0.97, 0.98, 1, 1)", "municipal_archive": "Color(1, 0.9, 0.76, 1)"}
MANIFEST = []


def rel(p):
    return os.path.relpath(p, V2).replace(os.sep, "/")


def res(p):
    return RES_ROOT + "/" + rel(p)


def fnum(v):
    v = float(v)
    return "0" if abs(v) < 1e-9 else f"{v:.5f}".rstrip("0").rstrip(".")


def xf(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return f"Transform3D({fnum(c)}, 0, {fnum(s)}, 0, 1, 0, {fnum(-s)}, 0, {fnum(c)}, {fnum(x)}, {fnum(y)}, {fnum(z)})"


def gv(v):
    """python value -> Godot variant text"""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return fnum(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(gv(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join(f"{json.dumps(str(k))}: {gv(x)}" for k, x in v.items()) + "}"
    return json.dumps(str(v))


def strip(spec):
    s = {k: v for k, v in spec.items() if k != "meta"}
    if "children" in s:
        s["children"] = [strip(c) for c in s["children"]]
    return s


def tris(spec):
    n = 0
    stack = [spec]
    while stack:
        c = stack.pop()
        if c.get("mb") is not None and "colonly" not in c["name"]:
            n += sum(len(g["i"]) // 3 for m, g in c["mb"].parts.items() if m != COL_KEY)
        stack += c.get("children", [])
    return n


def export(folder, spec, cat, extra=None):
    d = os.path.join(P4, folder)
    os.makedirs(d, exist_ok=True)
    glb = os.path.join(d, spec["name"] + ".glb")
    used = GLBWriter(glb).write(strip(spec))
    embed_images(glb)
    write_glb_import(glb, used)
    m = dict(name=spec["name"], glb=rel(glb), category=cat, triangles=tris(spec), materials=used)
    if spec.get("meta"):
        m.update({k: v for k, v in spec["meta"].items() if k in ("size", "interact")})
        if "category" in spec["meta"]:
            m["fixture_type"] = spec["meta"]["category"]
    if extra:
        m.update(extra)
    MANIFEST.append(m)
    return glb


# ------------------------------------------------------------------ furnishing
def footprint(size, x, z, yaw):
    w, d = size[0], size[1]
    c, s = abs(math.cos(yaw)), abs(math.sin(yaw))
    ex, ez = (w * c + d * s) / 2, (w * s + d * c) / 2
    return (x - ex, z - ez, x + ex, z + ez)


def wall_face(h, ext_pieces, room, side, lo, hi):
    """inner face coordinate of `room`'s wall on `side` over the span [lo, hi] (exterior 0.10 / partition 0.06 thick)"""
    x0, z0, x1, z1 = h.rooms[room]["rect"]
    t = 0.06
    for (r_, sd, axis, c_, plo, phi) in ext_pieces:
        if r_["id"] == room and sd == side and min(hi, phi) - max(lo, plo) > 0.01:
            t = 0.10
    return {"L": x0 + t, "R": x1 - t, "F": z0 + t, "B": z1 - t}[side]


def snap(h, ext_pieces, room, x, z, yaw, size):
    """push a wall unit so its back sits 1 cm off the wall face behind it"""
    bx, bz = -math.sin(yaw), -math.cos(yaw)
    a, b, c, d = footprint(size, x, z, yaw)
    if abs(bx) > 0.7:
        side = "R" if bx > 0 else "L"
        f = wall_face(h, ext_pieces, room, side, b, d)
        x = f - (c - a) / 2 - 0.01 if side == "R" else f + (c - a) / 2 + 0.01
    else:
        side = "B" if bz > 0 else "F"
        f = wall_face(h, ext_pieces, room, side, a, c)
        z = f - (d - b) / 2 - 0.01 if side == "B" else f + (d - b) / 2 + 0.01
    return x, z


def instances(h, plan, specs):
    out = []
    ext_pieces, _ = h.edges()
    for (model, x, z, yaw_deg, room, opts) in plan["fit"]:
        sp = specs[model]
        m = sp["meta"]
        yaw = math.radians(yaw_deg)
        if room and (m.get("wall") or opts.get("snap")) and not opts.get("nosnap") and not opts.get("straddle"):
            x, z = snap(h, ext_pieces, room, x, z, yaw, m["size"])
        fy = h.floor_y(h.rooms[room]) if room else 0.0
        y = fy + opts.get("y", 0.0)
        mounted = m.get("on_surface") or m.get("wall_mounted") or m["size"][1] < 0.06
        fp = opts.get("fp", not mounted)
        out.append(dict(model=model, x=x, y=y, z=z, yaw=yaw, room=room, floor_y=fy, outdoor=bool(opts.get("outdoor")),
                        footprint=footprint(m["size"], x, z, yaw) if fp else None, collide=not mounted, size=m["size"],
                        interact=m.get("interact", []), canopy_lights=m.get("canopy_lights"), straddle=bool(opts.get("straddle"))))
    return out


def batch(inst, specs, name):
    vis, col = MB(), MB()
    for it in inst:
        M = T(it["x"], it["y"], it["z"]) @ Ry(it["yaw"])
        for ch in specs[it["model"]]["children"]:
            mb = ch.get("mb")
            if mb is None:
                continue
            Mc = M @ T(*(ch.get("t") or (0, 0, 0))) @ Ry(ch.get("yaw") or 0.0)
            if "colonly" in ch["name"]:
                if it["collide"]:
                    col.merge(furnish_build._retag(mb), Mc)
            else:
                vis.merge(mb, Mc)
    children = [{"name": name + "_Mesh", "mb": vis}]
    if col.tri_count():
        children.append({"name": name + "_Col-colonly", "mb": col})
    return {"name": name, "children": children}


def world_of(it, p):
    c, s = math.cos(it["yaw"]), math.sin(it["yaw"])
    return [it["x"] + p[0] * c + p[2] * s, it["y"] + p[1], it["z"] - p[0] * s + p[2] * c]


# ------------------------------------------------------------------ scenes
class Tscn:
    def __init__(self, root, rtype="Node3D"):
        self.ext, self.sub, self.nodes, self.ids = [], [], [], {}
        self.root = (root, rtype)

    def e(self, path, typ="PackedScene"):
        if path not in self.ids:
            self.ids[path] = f"{len(self.ids) + 1}_{os.path.basename(path).split('.')[0][:24]}"
            self.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{self.ids[path]}"]')
        return f'ExtResource("{self.ids[path]}")'

    def n(self, name, typ=None, parent=".", props=None, instance=None):
        head = f'[node name="{name}"' + (f' type="{typ}"' if typ else "") + f' parent="{parent}"'
        if instance:
            head += f" instance={instance}"
        self.nodes.append(head + "]\n" + "\n".join(f"{k} = {v}" for k, v in (props or {}).items()))

    def write(self, path, root_props=None):
        rn, rt = self.root
        body = [f'[node name="{rn}" type="{rt}"]\n' + "\n".join(f"{k} = {v}" for k, v in (root_props or {}).items())]
        txt = f"[gd_scene load_steps={len(self.ext) + len(self.sub) + 1} format=3]\n\n" + "\n".join(self.ext) + "\n\n" + \
            "\n\n".join(body + self.nodes) + "\n"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w", newline="\n").write(txt)


def location_scene(key, plan, h, glb, furn_glb, inst):
    name = "".join(w.capitalize() for w in key.split("_")) if key in FOLDER else plan["name"].replace("COM_", "")
    t = Tscn(name)
    t.n("Building", None, ".", {}, instance=t.e(res(glb)))
    t.n("Furnishing", None, ".", {}, instance=t.e(res(furn_glb)))
    if plan.get("dyn"):
        t.n("Props", "Node3D", ".")
        for (path, x, z, yaw, nm) in plan["dyn"]:
            t.n(nm, None, "Props", {"transform": xf(x, 0.0 if z < 0.2 else h.floor_y(list(h.rooms.values())[0]), z, math.radians(yaw))}, instance=t.e(path))
    t.n("Lights", "Node3D", ".")
    col = LIGHT_COL.get(key, "Color(1, 0.95, 0.88, 1)")
    for lt in h.meta["lights"]:
        t.n("Light_" + lt["room"], "OmniLight3D", "Lights", {"transform": xf(*lt["pos"]), "light_color": col, "light_energy": "0.9",
                                                          "omni_range": fnum(lt.get("range", 6.0)), "shadow_enabled": "false"})
    for i, p in enumerate(h.meta.get("ext_lights", [])):
        t.n(f"ExtLight_{i}", "OmniLight3D", "Lights", {"transform": xf(*p), "light_color": "Color(1, 0.85, 0.6, 1)", "light_energy": "0.8",
                                                     "omni_range": "7.0", "shadow_enabled": "false"})
    for it in inst:
        for i, p in enumerate(it.get("canopy_lights") or []):
            t.n(f"CanopyLight_{i}", "OmniLight3D", "Lights", {"transform": xf(*world_of(it, p)), "light_color": "Color(1, 0.98, 0.94, 1)",
                                                            "light_energy": "1.2", "omni_range": "9.0", "shadow_enabled": "false"})
    t.n("Doorways", "Node3D", ".")
    doors = []
    for d in h.meta["doors"]:
        if not d["exterior"]:
            continue
        n = np.array(d["normal"])
        c = np.array([d["center"][0], d["center"][2]])
        for side, sg in (("Outside", 1), ("Inside", -1)):
            p = c + n * sg * 0.8
            yaw = math.atan2(-n[0] * sg, -n[1] * sg)        # marker -Z faces the doorway
            t.n(f"{d['name'].split('_', 2)[-1]}_{side}", "Marker3D", "Doorways",
                {"transform": xf(p[0], d["center"][1] if side == "Inside" else 0.0, p[1], yaw), "metadata/door": json.dumps(d["name"]),
                 "metadata/width": fnum(d["w"])})
        doors.append(dict(name=d["name"], kind=d["kind"], w=d["w"], h=d["h"], center=[round(v, 3) for v in d["center"]]))
    t.n("Interaction", "Node3D", ".")
    k = 0
    for it in inst:
        for ia in it["interact"]:
            k += 1
            t.n(f"{ia['name']}_{k}", "Marker3D", "Interaction", {"transform": xf(*world_of(it, ia["pos"])), "metadata/kind": json.dumps(ia["kind"]),
                                                               "metadata/fixture": json.dumps(it["model"])})
    for (nm, x, z, kind) in plan.get("interact_extra", []):
        t.n(nm, "Marker3D", "Interaction", {"transform": xf(x, 0.9, z), "metadata/kind": json.dumps(kind)})
    t.n("NavTargets", "Node3D", ".")
    for (nm, x, z) in plan.get("nav", []):
        room = room_at(h, x, z)
        t.n(nm, "Marker3D", "NavTargets", {"transform": xf(x, h.floor_y(h.rooms[room]) if room else 0.0, z)})
    rooms = [dict(id=r["id"], type=r["type"], rect=[round(v, 3) for v in r["rect"]], floor_y=round(r["floor_y"], 3), ceil_y=round(r["ceil_y"], 3))
             for r in h.meta["rooms"]]
    path = os.path.join(P4, "Godot_Scenes", name + ".tscn")
    t.write(path, {"metadata/location_id": json.dumps(key), "metadata/zone_id": json.dumps(plan["zone"]), "metadata/title": json.dumps(plan["title"]),
                   "metadata/rooms": gv(rooms), "metadata/exterior_doors": gv(doors)})
    return path, name


def room_at(h, x, z):
    for r in h.p["rooms"]:
        x0, z0, x1, z1 = r["rect"]
        if x0 <= x <= x1 and z0 <= z <= z1:
            return r["id"]
    return None


# ------------------------------------------------------------------ main
def main():
    os.makedirs(os.path.join(P4, "Textures"), exist_ok=True)
    png = os.path.join(P4, "Textures", "T_Com4_Atlas.png")
    rects = com_atlas.build(png)
    write_import(png, res(png))
    for m in (FX.ATLAS, FX.GLASS, FX.GLOW):
        tp = os.path.join(V2, MATS[m]["tres"])
        os.makedirs(os.path.dirname(tp), exist_ok=True)
        open(tp, "w", newline="\n").write(town_tres(MATS[m]))
    specs = dict(furnish_build.specs())                      # Pack 03 furniture (reused by name)
    exported = []
    for name, fn, exp in FX.all_fixtures():
        sp = fn()
        specs[name] = sp
        if exp:
            export("Shared_Props", sp, "fixture/" + sp["meta"]["category"])
            exported.append(name)
    layout = json.load(open(os.path.join(V2, "02_Town", "Town_Layout", "greyhaven_layout.json")))
    zones = {z["id"]: z for z in layout["zones"]}
    locs, placed = [], []
    for key, plan, prio in CP.PRIORITY:
        h = CP.ComBuilding(plan).build()
        spec = h.spec(plan["name"])
        folder = FOLDER.get(key, "Storefronts")
        glb = export(folder, spec, "building", extra=dict(location=key, priority=prio))
        inst = instances(h, plan, specs)
        fb = batch(inst, specs, plan["name"] + "_Furnishing")
        fglb = export(folder, fb, "furnishing", extra=dict(location=key, pieces=len(inst)))
        path, scene_name = location_scene(key, plan, h, glb, fglb, inst)
        fr = placement.zone_frame(zones[plan["zone"]])
        reused = sorted({i["model"] for i in inst if i["model"].startswith("RES_")} | {os.path.basename(d[0]).split(".")[0] for d in plan.get("dyn", [])})
        locs.append(dict(id=key, priority=prio, zone=plan["zone"], title=plan["title"], scene=rel(path), building=rel(glb), furnishing=rel(fglb),
                         rooms=[dict(id=r["id"], type=r["type"], rect=r["rect"], floor_y=r["floor_y"], ceil_y=r["ceil_y"]) for r in h.meta["rooms"]],
                         doors=[dict(name=d["name"], kind=d["kind"], w=d["w"], h=d["h"], exterior=d["exterior"], rooms=d["rooms"], center=d["center"],
                                     normal=d["normal"], **({"hinge": d["hinge"], "yaw": d["yaw"], "open_deg": d["open_deg"], "leaf": d["leaf"]} if "hinge" in d else {}))
                                for d in h.meta["doors"]],
                         fixtures=[dict(model=i["model"], x=round(i["x"], 3), z=round(i["z"], 3), yaw_deg=round(math.degrees(i["yaw"]), 1), room=i["room"],
                                        footprint=[round(v, 3) for v in i["footprint"]] if i["footprint"] else None, outdoor=i["outdoor"], straddle=i["straddle"]) for i in inst],
                         nav=[list(n) for n in plan.get("nav", [])], lights=len(h.meta["lights"]) + len(h.meta.get("ext_lights", [])),
                         reused_from_other_packs=reused, zone_frame=dict(yaw=round(fr["yaw"], 6), origin=[round(fr["origin"][0], 3), placement.LOT_Y, round(fr["origin"][1], 3)])))
        placed.append((scene_name, path, fr, plan["zone"]))
    # town integration (Pack 02 town + Pack 03 houses + Pack 04 commercial); other packs' scenes are instanced, never edited
    t = Tscn("Greyhaven_Commercial")
    for scene_name, path, fr, zone in placed:
        t.n(zone, None, ".", {"transform": xf(fr["origin"][0], placement.LOT_Y, fr["origin"][1], fr["yaw"]), "metadata/zone_id": json.dumps(zone)},
            instance=t.e(res(path)))
    t.write(os.path.join(P4, "Godot_Scenes", "Greyhaven_Commercial.tscn"), {"metadata/note": json.dumps("Pack 04 locations in their Pack 02 zones (world coordinates)")})
    t = Tscn("Greyhaven_Town_Complete")
    t.n("Town_With_Houses", None, ".", {}, instance=t.e(RES_ROOT + "/03_Residential/Residential_Scenes/Greyhaven_Town_With_Houses.tscn"))
    t.n("Commercial", None, ".", {}, instance=t.e(res(os.path.join(P4, "Godot_Scenes", "Greyhaven_Commercial.tscn"))))
    t.write(os.path.join(P4, "Godot_Scenes", "Greyhaven_Town_Complete.tscn"))
    doc = os.path.join(P4, "Documentation")
    os.makedirs(doc, exist_ok=True)
    json.dump({"pack": "THE VEIL - Pack 04 Commercial Buildings & Stores", "conventions": dict(frame="Pack 03 zone frame", lot_y=placement.LOT_Y, floor_y=CP.FY),
               "texture": rel(png), "atlas_rects": {k: list(v) for k, v in rects.items()}, "materials": [MATS[m]["tres"] for m in (FX.ATLAS, FX.GLASS, FX.GLOW)],
               "locations": locs, "models": MANIFEST, "shared_fixtures": exported},
              open(os.path.join(doc, "COMMERCIAL_MANIFEST.json"), "w", newline="\n"), indent=1)
    nb = sum(1 for m in MANIFEST if m["category"] == "building")
    print(f"{len(MANIFEST)} GLBs ({len(exported)} shared fixtures, {nb} buildings, {nb} furnishings), "
          f"{sum(m['triangles'] for m in MANIFEST)} triangles, {len(locs)} location scenes")


if __name__ == "__main__":
    main()
