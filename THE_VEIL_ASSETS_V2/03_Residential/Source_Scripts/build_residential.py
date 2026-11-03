#!/usr/bin/env python3
"""THE VEIL - Pack 03 builder: Greyhaven residential houses, interiors, furniture.

    python3 03_Residential/Source_Scripts/build_residential.py

Steps
  1. Pack 03 textures (Textures/T_Res_*.png + .import) and materials (Materials/M_Res_*.tres)
  2. Furniture (Furniture/), modular kit (Exterior_Modules/, Interior_Modules/, Interactive_Props/)
     -> GLB + Godot .import (materials mapped to the Pack 01/02/03 .tres) + OBJ/MTL
  3. House variants (House_Variants/): 9 designs + the colourway / mirrored variants the town uses,
     each with a batched furnishing GLB and a .tscn wrapper carrying interaction metadata
  4. Player home scene (Player_Home/Player_Home.tscn): individually instanced, interactive furniture,
     warm lights, wake-up / car-keys / sedan markers and a bedroom-to-car path
  5. Lot fitting against the Pack 02 zones -> Residential_Scenes/Greyhaven_Residential.tscn,
     RES_LotConnections.glb (walkways + garage aprons), Greyhaven_Town_With_Houses.tscn
  6. Manifests -> Documentation/MODEL_MANIFEST.json/.md, HOUSE_LOTS.json
Deterministic: identical inputs produce identical files.  Packs 01/02 are read, never written.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import res_materials  # noqa: E402  (path setup)
from res_materials import MATS, V2, RES, all_res_materials, town_tres, m01  # noqa: E402
from res_gltf import GLBWriter, write_glb_import, write_obj  # noqa: E402
from veil_mesh.mesh import MB, T, Ry  # noqa: E402
from veil_mesh.materials import RES_ROOT  # noqa: E402
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
from build_library import write_import  # noqa: E402

import res_textures  # noqa: E402
import furniture  # noqa: E402
import modules  # noqa: E402
import plans  # noqa: E402
import house as house_mod  # noqa: E402
import furnish  # noqa: E402
import furnish_build  # noqa: E402
import placement  # noqa: E402
import navcheck  # noqa: E402

import numpy as np  # noqa: E402

BASE_KEYS = list(plans.PLANS)


def rel(p):
    return os.path.relpath(p, V2).replace(os.sep, "/")


def res_path(p):
    return RES_ROOT + "/" + rel(p)


def fnum(v):
    s = f"{float(v):.5f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def xform(yaw, x, y, z):
    c, s = math.cos(yaw), math.sin(yaw)
    return "Transform3D(" + ", ".join(fnum(v) for v in [c, 0, s, 0, 1, 0, -s, 0, c, x, y, z]) + ")"


def gv(v):
    """Python value -> Godot variant text."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return fnum(v) if float(v) != int(v) else f"{int(v)}.0"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, dict):
        return "{\n" + ",\n".join(f"{json.dumps(str(k))}: {gv(x)}" for k, x in v.items()) + "\n}" if v else "{}"
    if isinstance(v, (list, tuple, np.ndarray)):
        return "[" + ", ".join(gv(x) for x in v) + "]"
    if v is None:
        return "null"
    raise TypeError(type(v))


def strip_meta(spec):
    return {k: v for k, v in spec.items() if k != "meta"}


# ------------------------------------------------------------------ summaries
def walk_spec(spec, M=None, out=None):
    """Yield (node, world matrix) for every node."""
    M = np.eye(4) if M is None else M
    out = [] if out is None else out
    M2 = M @ T(*(spec.get("t") or (0, 0, 0))) @ Ry(spec.get("yaw") or 0.0)
    out.append((spec, M2))
    for c in spec.get("children", []):
        walk_spec(c, M2, out)
    return out


def walk_named(spec, M=None, chain=()):
    """Like walk_spec, plus the node-name chain from the root (inclusive)."""
    M = np.eye(4) if M is None else M
    M2 = M @ T(*(spec.get("t") or (0, 0, 0))) @ Ry(spec.get("yaw") or 0.0)
    ch = chain + (spec["name"],)
    out = [(spec, M2, ch)]
    for c in spec.get("children", []):
        out += walk_named(c, M2, ch)
    return out


def summarize(cat, spec, glb, used, obj=None):
    vis, colt, cols = 0, 0, []
    pts = []
    inter = {}
    for n, M in walk_spec(spec):
        if n.get("extras"):
            inter[n["name"]] = n["extras"]
        mb = n.get("mb")
        if mb is None:
            continue
        if "colonly" in n["name"]:
            colt += mb.tri_count()
            cols.append(n["name"].split("-")[-1])
        else:
            vis += mb.tri_count()
            for g in mb.parts.values():
                if g["p"]:
                    P = np.asarray(g["p"])
                    pts.append((np.c_[P, np.ones(len(P))] @ M.T)[:, :3])
    a = np.concatenate(pts)
    mn, mx = a.min(0), a.max(0)
    meta = dict(spec.get("meta", {}))
    meta.pop("interactables", None)
    meta.pop("interactive_nodes", None)
    d = {"name": spec["name"], "category": cat, "glb": rel(glb), "obj": rel(obj) if obj else None,
         "triangles": int(vis), "collision_triangles": int(colt), "collision": sorted(set(cols)) or ["none"],
         "materials": used, "bounds_min": [round(float(v), 3) for v in mn], "bounds_max": [round(float(v), 3) for v in mx],
         "dimensions": [round(float(v), 3) for v in (mx - mn)]}
    if inter:
        d["interactables"] = inter
    d.update({k: v for k, v in meta.items() if k not in d})
    return d


def export(folder, spec, obj=True, cat=None):
    d = os.path.join(RES, folder)
    os.makedirs(d, exist_ok=True)
    glb = os.path.join(d, spec["name"] + ".glb")
    used = GLBWriter(glb).write(strip_meta(spec))
    write_glb_import(glb, used)
    op = None
    if obj:
        od = os.path.join(d, "OBJ")
        os.makedirs(od, exist_ok=True)
        open(os.path.join(od, ".gdignore"), "w").close()
        op = os.path.join(od, spec["name"] + ".obj")
        write_obj(op, spec["name"], strip_meta(spec))
        txt = open(op).read().replace("# THE VEIL Pack 02 - ", "# THE VEIL Pack 03 - ", 1)
        open(op, "w", newline="\n").write(txt)
    return summarize(cat or folder, spec, glb, used, op)


# ------------------------------------------------------------------ 1. textures + materials
def build_textures():
    tdir, mdir = os.path.join(RES, "Textures"), os.path.join(RES, "Materials")
    os.makedirs(tdir, exist_ok=True)
    os.makedirs(mdir, exist_ok=True)
    tex = []
    for name, (fn, size, alpha, desc) in res_textures.TEXTURES.items():
        img = fn().to_image()
        assert img.size == tuple(size), (name, img.size, size)
        assert (img.mode == "RGBA") == alpha, name
        p = os.path.join(tdir, f"T_Res_{name}.png")
        img.save(p, format="PNG", optimize=True)
        write_import(p, res_path(p))
        tex.append({"name": f"T_Res_{name}", "file": rel(p), "resolution": f"{size[0]}x{size[1]}", "alpha": alpha,
                    "description": desc})
    mats = []
    for m in all_res_materials():
        p = os.path.join(V2, MATS[m]["tres"])
        with open(p, "w", newline="\n") as f:
            f.write(town_tres(MATS[m]))
        mats.append({"name": m, "file": rel(p), "texture": rel(MATS[m]["png"]) if MATS[m].get("png") else None})
    W = 256
    atlas = {k: {"px": list(r), "uv": [r[0] / W, r[1] / W, (r[0] + r[2]) / W, (r[1] + r[3]) / W]}
             for k, r in res_textures.DETAIL_RECTS.items()}
    return tex, mats, atlas


# ------------------------------------------------------------------ 3. houses
def mirror_instances(inst):
    out = []
    for it in inst:
        q = dict(it)
        q["x"] = -it["x"]
        q["yaw"] = -it["yaw"]
        if it.get("footprint"):
            a, b, c, d = it["footprint"]
            q["footprint"] = (-c, b, -a, d)
        out.append(q)
    return out


_furn_cache = {}


def furnish_instances(key, mirror):
    ck = (key, mirror)
    if ck not in _furn_cache:
        h = placement.geometry(key, False)["house"]
        fmeta = {n: m["meta"] for n, m in furnish_build.specs().items()}
        rep = []
        inst = furnish.place_all(h, furnish.L[key], fmeta, rep)
        _furn_cache[ck] = (mirror_instances(inst) if mirror else inst, rep)
    return _furn_cache[ck]


def interactables_of(spec):
    out = []
    for n, M in walk_spec(spec):
        if n.get("extras"):
            p = M[:3, 3]
            out.append(dict(node=n["name"], pos=[round(float(v), 3) for v in p], **n["extras"]))
    return out


def house_record(h, name, key, cw, mirror):
    m = h.meta
    return {
        "name": name, "design": key, "colorway": cw or "A", "mirrored": mirror, "title": h.p.get("title", ""),
        "rooms": [dict(id=r["id"], type=r["type"], level=r["lvl"], rect=[round(float(v), 3) for v in r["rect"]],
                       floor_y=round(float(r["floor_y"]), 3)) for r in m["rooms"]],
        "doors": [dict(name=d["name"], kind=d["kind"], rooms=d["rooms"], exterior=bool(d["exterior"]),
                       center=[round(float(v), 3) for v in d["center"]]) for d in m["doors"]],
        "stairs": len(m["stairs"]), "windows": len(m["windows"]), "lights": [l["room"] for l in m["lights"]],
    }


def write_variant_tscn(path, name, glb, furn_glb, rec, inter):
    ext = [f'[ext_resource type="PackedScene" path="{res_path(glb)}" id="1_house"]']
    if furn_glb:
        ext.append(f'[ext_resource type="PackedScene" path="{res_path(furn_glb)}" id="2_furnishing"]')
    lines = [f"[gd_scene load_steps={len(ext) + 1} format=3]", ""] + ext + ["",
             f'[node name="{name}" type="Node3D"]', f"metadata/veil_house = {gv(rec)}",
             f"metadata/veil_interactables = {gv(inter)}", "",
             '[node name="House" parent="." instance=ExtResource("1_house")]', ""]
    if furn_glb:
        lines += ['[node name="Furnishing" parent="." instance=ExtResource("2_furnishing")]', ""]
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines))


def build_houses(variants):
    """variants: list of (key, cw, mirror). Returns manifest entries + per-variant info."""
    hv = os.path.join(RES, "House_Variants")
    os.makedirs(hv, exist_ok=True)
    man, info, furn_done = [], {}, {}
    for key, cw, mirror in variants:
        name = placement.variant_name(key, cw, mirror)
        p = placement.plan_for(key, mirror)
        colw = p.get("colorways", {}).get(cw) if cw else None
        h = house_mod.House(p, colw).build()
        spec = h.spec(name)
        spec["meta"] = dict(kind="house", design=key, colorway=cw or "A", mirrored=mirror, title=p.get("title", ""),
                            rooms=len(h.meta["rooms"]), doors=len(h.meta["doors"]), stairs=len(h.meta["stairs"]))
        e = export("House_Variants", spec, obj=(cw is None and not mirror), cat="House_Variants")
        man.append(e)
        fk = (key, mirror)
        if fk not in furn_done:
            inst, rep = furnish_instances(key, mirror)
            fname = plans.PLANS[key]["name"] + ("_Mirror" if mirror else "") + "_Furnishing"
            fb = furnish_build.batch(inst, fname)
            fb["meta"] = dict(kind="furnishing", design=key, mirrored=mirror, pieces=len(inst))
            fe = export("House_Variants", fb, obj=False, cat="House_Furnishing")
            man.append(fe)
            furn_done[fk] = (os.path.join(hv, fname + ".glb"), inst, rep)
        fglb, inst, rep = furn_done[fk]
        rec = house_record(h, name, key, cw, mirror)
        rec["furniture_pieces"] = len(inst)
        inter = interactables_of(spec)
        write_variant_tscn(os.path.join(hv, name + ".tscn"), name, os.path.join(hv, name + ".glb"), fglb, rec, inter)
        info[name] = dict(house=h, spec=spec, inst=inst, report=rep, glb=os.path.join(hv, name + ".glb"), furn=fglb,
                          tscn=os.path.join(hv, name + ".tscn"), key=key, cw=cw, mirror=mirror)
    return man, info


# ------------------------------------------------------------------ 4. player home
def player_home_path(h, inst):
    """Marker path: beside the bed -> bedroom door -> hall -> living room -> front door -> porch steps
    -> walkway -> driver's side of the sedan on the driveway. Returns list of [x, y, z] (floor level)."""
    meta = h.meta
    doors = {d["name"]: d for d in meta["doors"]}
    rooms = {r["id"]: r for r in meta["rooms"]}
    fy = rooms["BED"]["floor_y"]
    bed = [i for i in inst if i["model"].startswith("RES_Bed") and i["room"] == "BED"][0]
    spawn = wake_spot(h, inst)

    def dn(suffix):
        return [d for n, d in doors.items() if n.endswith(suffix)][0]

    def side(d, room):
        a, b = navcheck.door_points(d)
        return a if d["rooms"][0] == room else b
    pts = [("Bed", spawn)]
    bd = dn("Bedroom")
    pts += [("BedroomDoor", side(bd, "BED")), ("Hall", side(bd, "HALL"))]
    lh = dn("LivHall")
    pts += [("HallToLiving", side(lh, "HALL")), ("Living", side(lh, "LIV"))]
    fd = dn("Front")
    pin = side(fd, "LIV")
    pout = side(fd, "OUT")
    pts += [("FrontDoorInside", pin), ("FrontDoorOutside", pout)]
    po = [q for q in meta["porches"] if q["steps"] and q["steps"][0] == "z0"][0]
    sx = po["steps"][1]
    pts += [("PorchStepsTop", (sx, po["rect"][1] + 0.4))]
    (fx, fz), _ = placement._step_foot(po)
    pts += [("PorchStepsFoot", (fx, fz))]
    car = sedan_spot()
    pts += [("Walkway", (car[0] - 1.45, fz)), ("SedanDriverDoor", (car[0] - 1.25, car[2] + 0.4))]
    # route in-room stretches around furniture (same planner as the validation tours)
    grid = navcheck.FloorGrid(meta, fy, [i["footprint"] for i in inst if i["footprint"] and abs(i["floor_y"] - fy) < 0.05])
    inside = {"Bed", "BedroomDoor", "Hall", "HallToLiving", "Living", "FrontDoorInside"}
    fine = [pts[0]]
    for (na, a), (nb, b) in zip(pts[:-1], pts[1:]):
        if na in inside and nb in inside:
            pp = grid.path(tuple(a), tuple(b))
            if pp:
                fine += [(f"{nb}_via{k}", q) for k, q in enumerate(pp[1:-1], 1)]
        fine.append((nb, b))
    pts = fine
    out = []
    for nm, (x, z) in pts:
        r = navcheck._room_at(meta, x, z, fy)
        y = rooms[r]["floor_y"] if r else (po["deck_y"] if nm == "PorchStepsTop" or nm == "FrontDoorOutside" else 0.0)
        out.append((nm, [round(float(x), 3), round(float(y), 3), round(float(z), 3)]))
    return out


def wake_spot(h, inst):
    """Standing spot beside the bed (largest free side), on the bedroom floor."""
    bed = [i for i in inst if i["model"].startswith("RES_Bed") and i["room"] == "BED"][0]
    r = [q for q in h.meta["rooms"] if q["id"] == "BED"][0]
    g = navcheck.FloorGrid(h.meta, r["floor_y"], [i["footprint"] for i in inst if i["footprint"] and
                                                abs(i["floor_y"] - r["floor_y"]) < 0.05])
    a, b, c, d = bed["footprint"]
    best = None
    for (x, z) in (((a + c) / 2, d + 0.45), ((a + c) / 2, b - 0.45), (a - 0.45, (b + d) / 2), (c + 0.45, (b + d) / 2)):
        cell = g.nearest_free(g.cell((x, z)), rmax=6)
        if cell is None:
            continue
        p = (g.o[0] + (cell[1] + 0.5) * g.res, g.o[1] + (cell[0] + 0.5) * g.res)
        dd = abs(p[0] - x) + abs(p[1] - z)
        if best is None or dd < best[0]:
            best = (dd, p)
    return best[1]


def sedan_spot():
    """Pack 02 journey point 2_SEDAN_ON_DRIVEWAY in the player-home lot frame (x, y, z)."""
    lay = placement.load_layout()
    z = [q for q in lay["zones"] if q["id"] == "PLAYER_HOME"][0]
    fr = placement.zone_frame(z)
    j = [q for q in lay["journey"] if q[0] == "2_SEDAN_ON_DRIVEWAY"][0]
    lx, lz = placement.to_local(fr, j[1], j[2])
    return (round(lx, 3), 0.0, round(lz, 3))


def build_player_home(info):
    name = "RES_PlayerHome"
    v = info[name]
    h, inst, spec = v["house"], v["inst"], v["spec"]
    fs = furnish_build.specs()
    pdir = os.path.join(RES, "Player_Home")
    os.makedirs(pdir, exist_ok=True)
    models = sorted({i["model"] for i in inst})
    ext = [f'[ext_resource type="PackedScene" path="{res_path(v["glb"])}" id="1_house"]']
    ids = {}
    for k, m in enumerate(models):
        ids[m] = f"{k + 2}_{m[:24]}"
        ext.append(f'[ext_resource type="PackedScene" path="{RES_ROOT}/03_Residential/Furniture/{m}.glb" id="{ids[m]}"]')
    path = player_home_path(h, inst)
    car = sedan_spot()
    # interaction metadata: house + every furniture instance's moving parts (prefixed with the instance node)
    inter = interactables_of(spec)
    nodes = []
    counts = {}
    keys_pos = None
    for i in inst:
        counts[i["model"]] = counts.get(i["model"], 0) + 1
        nn = f"{i['model'][4:]}_{counts[i['model']]:02d}".replace(".", "_")   # Godot node names cannot hold "."
        nodes.append(f'[node name="{nn}" parent="Furniture" instance=ExtResource("{ids[i["model"]]}")]')
        nodes.append(f"transform = {xform(i['yaw'], i['x'], i['y'], i['z'])}")
        nodes.append(f'metadata/room = "{i["room"]}"')
        nodes.append("")
        Mi = T(i["x"], i["y"], i["z"]) @ Ry(i["yaw"])
        for n, M, chain in walk_named(fs[i["model"]], Mi):
            if n.get("extras"):
                p = M[:3, 3]
                # Godot keeps the glTF root node under the instance: Furniture/<instance>/<model>/<part>
                inter.append(dict(node=f"Furniture/{nn}/" + "/".join(c.replace(".", "_") for c in chain), pos=[round(float(q), 3) for q in p], **n["extras"]))
                if n["name"] == "INT_Pickup_CarKeys":
                    keys_pos = [float(q) for q in p]
    rec = house_record(h, name, "PlayerHome", None, False)
    rec["furniture_pieces"] = len(inst)
    rec["story"] = ("Friday evening, 6:47 pm. The protagonist wakes in the ground-floor bedroom, walks the hall to the "
                    "living room, takes the car keys from the coat rack by the front door and drives the sedan off the driveway.")
    lines = [f"[gd_scene load_steps={len(ext) + 1} format=3]", ""] + ext + ["",
             f'[node name="Player_Home" type="Node3D"]', f"metadata/veil_house = {gv(rec)}",
             f"metadata/veil_interactables = {gv(inter)}",
             f"metadata/veil_wake_path = {gv([p for _, p in path])}", "",
             '[node name="House" parent="." instance=ExtResource("1_house")]', "",
             '[node name="Furniture" type="Node3D" parent="."]', ""] + nodes
    # lights: warm, a few only (Compatibility renderer budget) - bedroom lamp, hall, living, kitchen, porch
    lights = {l["room"]: l["pos"] for l in h.meta["lights"]}
    lam = [i for i in inst if i["model"] in ("RES_Lamp_Table", "RES_Lamp_Floor") and i["room"] in ("BED", "LIV")]
    lines += ['[node name="Lights" type="Node3D" parent="."]', ""]
    L = []
    for rid, energy, rng in (("BED", 0.0, 4.5), ("HALL", 0.45, 4.0), ("LIV", 0.7, 6.0), ("KIT", 0.8, 5.5)):
        if rid in lights:
            L.append((f"Ceiling_{rid}", lights[rid], energy, rng, rid == "BED"))
    for i in lam:
        L.append((f"Lamp_{i['room']}", [i["x"], i["top_y"] - 0.15 if i.get("top_y") else i["y"] + 1.2, i["z"]], 0.9, 4.0, False))
    po = [q for q in h.meta["porches"] if q["steps"] and q["steps"][0] == "z0"][0]
    L.append(("Porch", [(po["rect"][0] + po["rect"][2]) / 2, po["deck_y"] + 2.2, (po["rect"][1] + po["rect"][3]) / 2], 0.6, 5.0, False))
    for nm, p, e, rng, off in L:
        lines += [f'[node name="{nm}" type="OmniLight3D" parent="Lights"]',
                  f"transform = {xform(0, p[0], p[1], p[2])}", "light_color = Color(1, 0.82, 0.6, 1)",
                  f"light_energy = {fnum(e if not off else 0.0)}", f"omni_range = {fnum(rng)}", "shadow_enabled = false"]
        if off:
            lines.append('metadata/note = "off at wake-up; the bedside lamp is the only light on"')
        lines.append("")
    # markers
    spawn = path[0][1]
    bed = [i for i in inst if i["model"].startswith("RES_Bed") and i["room"] == "BED"][0]
    face = math.atan2(bed["x"] - spawn[0], bed["z"] - spawn[2])    # Godot forward is -Z: look away from the bed
    lines += ['[node name="Markers" type="Node3D" parent="."]', "",
              '[node name="Spawn_WakeUp" type="Marker3D" parent="Markers"]', f"transform = {xform(face, *spawn)}",
              'metadata/note = "player stands up here beside the bed; Friday evening"', "",
              '[node name="Sedan_Driveway" type="Marker3D" parent="Markers"]', f"transform = {xform(0.0, *car)}",
              'metadata/note = "Pack 02 journey point 2_SEDAN_ON_DRIVEWAY; -Z (forward) faces the street; driver door on -X"', ""]
    if keys_pos:
        lines += ['[node name="Pickup_CarKeys" type="Marker3D" parent="Markers"]', f"transform = {xform(0, *keys_pos)}", ""]
    lines += ['[node name="WakePath" type="Node3D" parent="Markers"]', ""]
    for k, (nm, p) in enumerate(path):
        lines += [f'[node name="WP_{k:02d}_{nm}" type="Marker3D" parent="Markers/WakePath"]', f"transform = {xform(0, *p)}", ""]
    with open(os.path.join(pdir, "Player_Home.tscn"), "w", newline="\n") as f:
        f.write("\n".join(lines))
    return dict(path=path, keys=keys_pos, sedan=car, lights=len(L), furniture=len(inst), unique_models=len(models))


# ------------------------------------------------------------------ 5. town placement
def lot_connections(fits):
    """Walkways (step foot -> driveway edge) + garage aprons, merged into one world-space GLB (visual only:
    1-2 cm slabs on the Pack 02 lot ground, which already carries collision)."""
    mb = MB()
    conc = m01("Road_SidewalkConcrete")
    out = []
    for r in fits:
        fr, s = r["frame"], r["shift"]
        g = placement.geometry(r["key"], r["mirror"])
        po = g["front_po"]
        sr = placement._step_rect(po)
        pts = list(r["walk"])
        segs = []
        (fx, fz), _ = placement._step_foot(po)
        fx += s
        # from the bottom step to the foot point
        segs.append(((fx, sr[1]), (fx, fz)))
        for a, b in zip(pts[:-1], pts[1:]):
            segs.append((a, b))
        if len(pts) >= 1:          # nudge the last point 0.1 m onto the driveway
            dxc = (r["drive"][0] + r["drive"][2]) / 2
            lx, lz = pts[-1]
            ex = dxc - placement.DRIVE_HALF + 0.1 if lx < dxc else dxc + placement.DRIVE_HALF - 0.1
            segs.append(((lx, lz), (ex, lz)))
        rects = []
        for (a, b) in segs:
            x0, x1 = sorted((a[0], b[0]))
            z0, z1 = sorted((a[1], b[1]))
            if x1 - x0 < 1e-6 and z1 - z0 < 1e-6:
                continue
            rects.append((x0 - 0.5, z0 - 0.5, x1 + 0.5, z1 + 0.5))
        # trim the first segment so it does not run under the steps
        rects[0] = (rects[0][0], rects[0][1], rects[0][2], min(rects[0][3], sr[1]))
        gz = g["garage"]["center"][2] if g["garage"] else None
        if gz is not None and gz > r["drive"][3] + 0.05 and not g["flare"]:
            gx = g["garage"]["center"][0] + s
            rects.append((gx - 1.6, r["drive"][3] - 0.05, gx + 1.6, gz - 0.06))
        for k, (x0, z0, x1, z1) in enumerate(rects):
            y = 0.008 + 0.001 * (k % 3)          # stagger overlapping slabs to avoid z-fighting
            corners = [placement.to_world(fr, x0, z0), placement.to_world(fr, x1, z0), placement.to_world(fr, x1, z1),
                       placement.to_world(fr, x0, z1)]
            poly = [(c[0], c[1]) for c in corners]
            # ground_poly wants counter-clockwise (seen from above) order in x/z
            area = sum(poly[i][0] * poly[(i + 1) % 4][1] - poly[(i + 1) % 4][0] * poly[i][1] for i in range(4))
            if area < 0:
                poly = poly[::-1]
            mb.ground_poly(conc, poly, y=placement.LOT_Y + y)
        out.append(dict(zone=r["zone"], slabs=len(rects)))
    spec = {"name": "RES_LotConnections", "children": [{"name": "RES_LotConnections_Mesh", "mb": mb}],
            "meta": dict(kind="lot_connections", note="walkways + garage aprons, world space, visual only")}
    return spec, out


def build_town(info, ph_info):
    lay = placement.load_layout()
    fits = placement.solve(lay)
    bad = [r for r in fits if not r["ok"]]
    assert not bad, bad
    sdir = os.path.join(RES, "Residential_Scenes")
    os.makedirs(sdir, exist_ok=True)
    lc_spec, lc = lot_connections(fits)
    lc_man = export("Residential_Scenes", lc_spec, obj=False, cat="Lot_Connections")
    ext, ids = [], {}
    for r in fits:
        tscn = os.path.join(RES, "Player_Home", "Player_Home.tscn") if r["key"] == "PlayerHome" else info[r["variant"]]["tscn"]
        if tscn not in ids:
            ids[tscn] = f"{len(ids) + 1}_{os.path.basename(tscn)[:-5][:26]}"
            ext.append(f'[ext_resource type="PackedScene" path="{res_path(tscn)}" id="{ids[tscn]}"]')
    lcg = os.path.join(sdir, "RES_LotConnections.glb")
    ext.append(f'[ext_resource type="PackedScene" path="{res_path(lcg)}" id="{len(ids) + 1}_lots"]')
    lines = [f"[gd_scene load_steps={len(ext) + 1} format=3]", ""] + ext + ["",
             '[node name="Greyhaven_Residential" type="Node3D"]',
             'metadata/note = "Pack 03 houses in the Pack 02 Greyhaven zones (world coordinates; instance next to Greyhaven_Town.tscn)"', "",
             f'[node name="LotConnections" parent="." instance=ExtResource("{len(ids) + 1}_lots")]', "",
             '[node name="Houses" type="Node3D" parent="."]', ""]
    lots = []
    for r in fits:
        fr = r["frame"]
        ox, oz = placement.to_world(fr, r["shift"], 0.0)
        tscn = os.path.join(RES, "Player_Home", "Player_Home.tscn") if r["key"] == "PlayerHome" else info[r["variant"]]["tscn"]
        lines += [f'[node name="{r["zone"]}" parent="Houses" instance=ExtResource("{ids[tscn]}")]',
                  f"transform = {xform(fr['yaw'], ox, placement.LOT_Y, oz)}",
                  f'metadata/zone_id = "{r["zone"]}"', f'metadata/variant = "{r["variant"]}"', ""]
        g = placement.geometry(r["key"], r["mirror"])
        fd = g["front_door"]
        lots.append(dict(zone=r["zone"], zone_type=r["zone_type"], variant=r["variant"], design=r["key"],
                         colorway=r["cw"] or "A", mirrored=r["mirror"], shift=r["shift"],
                         yaw=round(fr["yaw"], 6), origin=[round(ox, 3), placement.LOT_Y, round(oz, 3)],
                         zone_size=[fr["W"], fr["D"]], scene=rel(tscn),
                         front_door_world=[round(v, 3) for v in placement.to_world(fr, fd["center"][0] + r["shift"], fd["center"][2])],
                         walkway=[[round(a, 2), round(b, 2)] for a, b in r["walk"]]))
    with open(os.path.join(sdir, "Greyhaven_Residential.tscn"), "w", newline="\n") as f:
        f.write("\n".join(lines))
    # combined preview scene: Pack 02 town (unchanged) + Pack 03 houses
    town = "res://THE_VEIL_ASSETS_V2/02_Town/Godot_Scenes/Greyhaven_Town.tscn"
    comb = ["[gd_scene load_steps=3 format=3]", "",
            f'[ext_resource type="PackedScene" path="{town}" id="1_town"]',
            f'[ext_resource type="PackedScene" path="{res_path(os.path.join(sdir, "Greyhaven_Residential.tscn"))}" id="2_res"]', "",
            '[node name="Greyhaven_With_Houses" type="Node3D"]', "",
            '[node name="Greyhaven_Town" parent="." instance=ExtResource("1_town")]', "",
            '[node name="Greyhaven_Residential" parent="." instance=ExtResource("2_res")]', "",
            '[node name="TOWN_BuildingZones" parent="Greyhaven_Town/BuildingZones"]',
            "visible = false", 'metadata/note = "Pack 02 zone preview boxes hidden here (the Pack 02 scene itself is unchanged)"', ""]
    with open(os.path.join(sdir, "Greyhaven_Town_With_Houses.tscn"), "w", newline="\n") as f:
        f.write("\n".join(comb))
    return fits, lots, lc, lc_man


# ------------------------------------------------------------------ main
def main():
    tex, mats, atlas = build_textures()
    manifest = []
    for fn in furniture.FURNITURE:
        spec = fn()
        manifest.append(export("Furniture", spec, cat="Furniture/" + spec["meta"]["category"]))
    for folder, fn in modules.all_modules():
        spec = fn()
        manifest.append(export(folder, spec))
    fits = placement.solve()
    variants = [(k, None, False) for k in BASE_KEYS]
    for r in fits:
        v = (r["key"], r["cw"], r["mirror"])
        if v not in variants:
            variants.append(v)
    hman, info = build_houses(variants)
    manifest += hman
    ph = build_player_home(info)
    fits, lots, lc, lc_man = build_town(info, ph)
    manifest.append(lc_man)
    doc = os.path.join(RES, "Documentation")
    os.makedirs(doc, exist_ok=True)
    furn_rep = {placement.variant_name(k, None, m): rep for (k, m), (_, rep) in _furn_cache.items()}
    with open(os.path.join(doc, "MODEL_MANIFEST.json"), "w", newline="\n") as f:
        json.dump({"pack": "THE VEIL - Pack 03 Greyhaven Residential", "models": manifest, "textures": tex,
                   "materials": mats, "detail_atlas_rects": atlas, "player_home": ph,
                   "furnishing_notes": furn_rep}, f, indent=1)
    with open(os.path.join(doc, "HOUSE_LOTS.json"), "w", newline="\n") as f:
        json.dump({"lots": lots, "lot_connections": lc}, f, indent=1)
    write_manifest_md(manifest, tex, mats, lots, os.path.join(doc, "MODEL_MANIFEST.md"))
    nh = sum(1 for m in manifest if m["category"] == "House_Variants")
    print(f"{len(tex)} textures, {len(mats)} materials, {len(manifest)} GLB models "
          f"({nh} house variants), {len(lots)} lots filled")


def write_manifest_md(manifest, tex, mats, lots, path):
    L = ["# THE VEIL - Pack 03 Model Manifest", "",
         "Generated by `03_Residential/Source_Scripts/build_residential.py`. Triangle counts are visual meshes; "
         "collision is listed separately. Dimensions are W x H x D in metres (x, y, z).", ""]
    cats = []
    for m in manifest:
        if m["category"] not in cats:
            cats.append(m["category"])
    for c in cats:
        ms = [m for m in manifest if m["category"] == c]
        L += [f"## {c} ({len(ms)})", "", "| Model | Tris | Collision | Dimensions | Mats | Interactive parts |",
              "|---|---|---|---|---|---|"]
        for m in ms:
            it = ", ".join(sorted(m.get("interactables", {})))
            if len(it) > 90:
                it = f"{len(m['interactables'])} parts"
            dm = " x ".join(f"{v:.2f}" for v in m["dimensions"])
            L.append(f"| `{m['name']}` | {m['triangles']} | {', '.join(m['collision'])} ({m['collision_triangles']}) | "
                     f"{dm} | {len(m['materials'])} | {it} |")
        L.append("")
    L += ["## Pack 03 textures", "", "| Texture | Size | Alpha | Description |", "|---|---|---|---|"]
    L += [f"| `{t['name']}` | {t['resolution']} | {t['alpha']} | {t['description']} |" for t in tex]
    L += ["", "## Lots", "", "| Zone | Variant | Mirrored | Shift (m) |", "|---|---|---|---|"]
    L += [f"| {q['zone']} | `{q['variant']}` | {q['mirrored']} | {q['shift']} |" for q in lots]
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(L) + "\n")


if __name__ == "__main__":
    main()
