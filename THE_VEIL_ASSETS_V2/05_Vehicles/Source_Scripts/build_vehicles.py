#!/usr/bin/env python3
"""THE VEIL - Pack 05 builder: vehicles, abandoned variants, transportation props, Godot scenes.

    python3 05_Vehicles/Source_Scripts/build_vehicles.py

* Textures/T_Veh_Atlas.png + T_Veh_Atlas_Weathered.png (veh_atlas.py), palette-locked, nearest filtering
* Shared_Materials/: M_Veh_Atlas, M_Veh_Glass, M_Veh_Lights (+ weathered: M_Veh_Atlas_Weathered, M_Veh_Glass_Dirty, M_Veh_Lights_Off)
* <folder>/VEH_*.glb / TRN_*.glb (+ .import remapping to the shared .tres); the atlas PNG is embedded in each GLB
* Godot_Scenes/Protagonist_Sedan.tscn (+ demo on the Pack 03 town driveway), reuse scenes for Pack 02/09 props
* Documentation/VEHICLE_MANIFEST.json
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
P5 = os.path.join(V2, "05_Vehicles")
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "08_Inventory", "Source_Scripts"))

import veh_models as VM  # noqa: E402
import veh_atlas  # noqa: E402
from veil_mesh.materials import MATS, _reg, town_tres, RES_ROOT  # noqa: E402
from veil_mesh.gltf import GLBWriter, write_glb_import, COL_KEY  # noqa: E402
from build_library import write_import  # noqa: E402
from build_inventory import embed_images  # noqa: E402
import validate_town as VT  # noqa: E402

RES5 = RES_ROOT + "/05_Vehicles"
MANIFEST = []


def rel(p):
    return os.path.relpath(p, V2).replace(os.sep, "/")


class Writer(GLBWriter):
    """Pack 02 writer + full quaternion node rotations ("q") for pivots / poses"""

    def add_node(self, spec, parent=None):
        idx = super().add_node(spec, parent)
        if spec.get("q"):
            self.j["nodes"][idx]["rotation"] = [float(v) for v in spec["q"]]
        return idx


# ------------------------------------------------------------------ materials
def materials():
    tdir = os.path.join(P5, "Textures")
    os.makedirs(tdir, exist_ok=True)
    png, wpng = os.path.join(tdir, "T_Veh_Atlas.png"), os.path.join(tdir, "T_Veh_Atlas_Weathered.png")
    veh_atlas.build(png, wpng)
    for p in (png, wpng):
        write_import(p, RES_ROOT + "/" + rel(p))
    base = dict(uv=(1.0, 1.0), repeat=False, metal=0.0, pack="05")
    specs = {
        "M_Veh_Atlas": dict(png=png, alpha="OPAQUE", double=False, rough=0.55, **base),
        "M_Veh_Glass": dict(png=png, alpha="BLEND", double=True, rough=0.1, color=(1.0, 1.0, 1.0, 0.42), **base),
        "M_Veh_Lights": dict(png=png, alpha="OPAQUE", double=False, rough=0.3, emission=(1.0, 1.0, 1.0), energy=0.9, **base),
        "M_Veh_Atlas_Weathered": dict(png=wpng, alpha="OPAQUE", double=False, rough=0.85, **base),
        "M_Veh_Glass_Dirty": dict(png=wpng, alpha="BLEND", double=True, rough=0.6, color=(1.0, 1.0, 1.0, 0.7), **base),
        "M_Veh_Lights_Off": dict(png=wpng, alpha="OPAQUE", double=False, rough=0.5, **base),
    }
    for name, kw in specs.items():
        _reg(name, tres=f"05_Vehicles/Shared_Materials/{name}.tres", **kw)
        tp = os.path.join(V2, MATS[name]["tres"])
        os.makedirs(os.path.dirname(tp), exist_ok=True)
        open(tp, "w", newline="\n").write(town_tres(MATS[name]))
    return [rel(png), rel(wpng)], list(specs)


# ------------------------------------------------------------------ export
def tris(spec):
    n = 0
    for c in spec["children"]:
        if c.get("mb") is not None and "colonly" not in c["name"]:
            n += sum(len(g["i"]) // 3 for m, g in c["mb"].parts.items() if m != COL_KEY)
    return n


def export(folder, spec, desc, category, base=None, extra=None, veh=None):
    d = os.path.join(P5, folder)
    os.makedirs(d, exist_ok=True)
    glb = os.path.join(d, spec["name"] + ".glb")
    movable = [dict(node=c["name"], role=c.get("role"), pivot=[round(v, 4) for v in c["t"]], axis=c.get("axis"))
               for c in spec["children"] if c.get("mb") is not None and c.get("role") not in (None, "", "static body")]
    markers = {c["name"]: [round(v, 4) for v in c["t"]] for c in spec["children"] if c.get("mb") is None}
    used = Writer(glb).write(spec)
    embed_images(glb)
    write_glb_import(glb, used)
    js, binb = VT.read_glb(glb)
    P = []
    root_t = np.asarray(js["nodes"][js["scenes"][0]["nodes"][0]].get("translation", [0, 0, 0]))
    for nd in js["nodes"]:
        if "mesh" in nd and "rotation" not in nd:
            for p in js["meshes"][nd["mesh"]]["primitives"]:
                if "material" in p:
                    t = np.asarray(nd.get("translation", [0, 0, 0])) + (root_t if nd is not js["nodes"][js["scenes"][0]["nodes"][0]] else 0)
                    P.append(np.asarray(js["accessors"][p["attributes"]["POSITION"]]["min"]) + t)
                    P.append(np.asarray(js["accessors"][p["attributes"]["POSITION"]]["max"]) + t)
    P = np.array(P)
    size = [round(float(v), 3) for v in P.max(0) - P.min(0)]
    m = dict(name=spec["name"], folder=folder, glb=rel(glb), category=category, triangles=tris(spec), materials=used, size_m=size,
             bounds=[[round(float(v), 3) for v in P.min(0)], [round(float(v), 3) for v in P.max(0)]],
             movable_parts=movable, markers=markers, description=desc, status="new", variant_of=base)
    if extra:
        m.update(extra)
    if veh is not None and getattr(veh, "targets", None):
        m["sight_targets"] = {k: [round(float(x), 4) for x in v] for k, v in veh.targets.items()}
    MANIFEST.append(m)
    return glb


def vehicle_size(v):
    S = v.S
    ys = [s["top"] for s in S]
    return dict(length=round(S[-1]["z"] - S[0]["z"], 3), width=round(2 * max(s["hw"] for s in S), 3), height=round(max(ys) + 0.03, 3))


# ------------------------------------------------------------------ scenes
def fnum(v):
    v = float(v)
    return "0" if abs(v) < 1e-9 else (f"{v:.6f}".rstrip("0").rstrip("."))


def xf(x=0, y=0, z=0, R=None):
    R = np.eye(3) if R is None else R
    return "Transform3D(" + ", ".join(fnum(v) for v in [R[0, 0], R[0, 1], R[0, 2], R[1, 0], R[1, 1], R[1, 2], R[2, 0], R[2, 1], R[2, 2], x, y, z]) + ")"


class Tscn:
    def __init__(self, root, rtype="Node3D"):
        self.ext, self.sub, self.nodes, self.ids = [], [], [], {}
        self.root = (root, rtype)

    def e(self, path, typ):
        key = (path, typ)
        if key not in self.ids:
            self.ids[key] = f"{len(self.ids) + 1}_{os.path.basename(path).split('.')[0][:20]}"
            self.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{self.ids[key]}"]')
        return f'ExtResource("{self.ids[key]}")'

    def s(self, typ, props):
        sid = f"{typ}_{len(self.sub) + 1}"
        self.sub.append(f'[sub_resource type="{typ}" id="{sid}"]\n' + "\n".join(f"{k} = {v}" for k, v in props.items()))
        return f'SubResource("{sid}")'

    def n(self, name, typ=None, parent=".", props=None, instance=None):
        head = f'[node name="{name}"' + (f' type="{typ}"' if typ else "") + f' parent="{parent}"'
        if instance:
            head += f" instance={instance}"
        self.nodes.append(head + "]\n" + "\n".join(f"{k} = {v}" for k, v in (props or {}).items()))

    def write(self, path, root_props=None):
        rn, rt = self.root
        body = [f'[node name="{rn}" type="{rt}"]\n' + "\n".join(f"{k} = {v}" for k, v in (root_props or {}).items())]
        txt = f"[gd_scene load_steps={len(self.ext) + len(self.sub) + 1} format=3]\n\n" + "\n".join(self.ext) + "\n\n" + \
            "\n\n".join(self.sub) + ("\n\n" if self.sub else "") + "\n\n".join(body + self.nodes) + "\n"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w", newline="\n").write(txt)


def sedan_scene(markers):
    t = Tscn("ProtagonistSedan")
    t.n("Model", None, ".", {}, instance=t.e(f"{RES5}/Protagonist_Sedan/VEH_ProtagonistSedan.glb", "PackedScene"))
    cam = markers["Marker_Camera_FirstPerson"]
    t.n("DriverCamera", "Camera3D", ".", {"transform": xf(*cam), "fov": "72.0", "near": "0.05", "current": "false"})
    lights = t.n("Lights", "Node3D", ".")
    for side in ("L", "R"):
        p = markers[f"Marker_Headlight_{side}"]
        t.n(f"Headlight_{side}", "SpotLight3D", "Lights", {"transform": xf(*p, R=VM.Rx(-4)), "visible": "false", "light_color": "Color(1, 0.94, 0.8, 1)",
                                                        "light_energy": "3.0", "spot_range": "28.0", "spot_angle": "30.0", "shadow_enabled": "false"})
        p = markers[f"Marker_Taillight_{side}"]
        t.n(f"Taillight_{side}", "OmniLight3D", "Lights", {"transform": xf(*p), "visible": "false", "light_color": "Color(1, 0.15, 0.1, 1)",
                                                         "light_energy": "0.6", "omni_range": "1.6", "shadow_enabled": "false"})
    box = t.s("BoxShape3D", {"size": "Vector3(1.1, 1.8, 1.6)"})
    t.n("Interaction", "Node3D", ".")
    for side in ("Driver", "Passenger"):
        p = markers[f"Marker_Entry_{side}"]
        t.n(f"EntryArea_{side}", "Area3D", "Interaction", {"transform": xf(p[0] * 0.8, 0.9, p[2]), "monitorable": "false"})
        t.n("Shape", "CollisionShape3D", f"Interaction/EntryArea_{side}", {"shape": box})
    t.write(os.path.join(P5, "Godot_Scenes", "Protagonist_Sedan.tscn"),
            {"metadata/vehicle_id": '"protagonist_sedan"', "metadata/forward": '"-Z"'})


def demo_scene():
    t = Tscn("Greyhaven_Opening_Driveway")
    t.n("Town", None, ".", {}, instance=t.e(RES_ROOT + "/03_Residential/Residential_Scenes/Greyhaven_Town_With_Houses.tscn", "PackedScene"))
    # PLAYER_HOME driveway (Pack 02 layout: RD_Driveway_3x8m_014, x 29.5-32.5, z -98..-90, lots at y = 0.15); nose to the street
    t.n("ProtagonistSedan", None, ".", {"transform": xf(31.0, 0.15, -94.2)}, instance=t.e(f"{RES5}/Godot_Scenes/Protagonist_Sedan.tscn", "PackedScene"))
    t.n("Camera", "Camera3D", ".", {"transform": xf(35.5, 1.7, -101.0, R=VM.Ry(35)), "current": "true"})
    t.write(os.path.join(P5, "Godot_Scenes", "Greyhaven_Opening_Driveway.tscn"))


def upright_scene(name, src_glb, res_src):
    """stand a Pack 09 'fallen' prop back up (its GLB was built rotated 90 deg about Z): reuse, no new mesh"""
    js, binb = VT.read_glb(src_glb)
    pts = []
    for mesh in js["meshes"]:
        for p in mesh["primitives"]:
            if "material" in p:
                pts.append(VT.accessor(js, binb, p["attributes"]["POSITION"]))
    P = np.concatenate(pts)
    Rz = np.array([[0, 1, 0], [-1, 0, 0], [0, 0, 1]], float)     # rotate -90 deg about Z
    Q = P @ Rz.T
    mn, mx = Q.min(0), Q.max(0)
    off = [-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2]
    t = Tscn(name)
    t.n("Model", None, ".", {"transform": xf(*off, R=Rz)}, instance=t.e(res_src, "PackedScene"))
    t.write(os.path.join(P5, "Transportation_Props", name + ".tscn"))
    return [round(float(v), 3) for v in mx - mn]


def roadside_scene():
    t = Tscn("Roadside_BrokenDown_Van")
    t.n("Van", None, ".", {}, instance=t.e(f"{RES5}/Abandoned_Variants/VEH_DeliveryVan_BrokenDown.glb", "PackedScene"))
    t.n("Triangle", None, ".", {"transform": xf(-0.4, 0, 7.5, R=VM.Ry(180))}, instance=t.e(f"{RES5}/Transportation_Props/TRN_EmergencyTriangle.glb", "PackedScene"))
    t.n("GasCan", None, ".", {"transform": xf(1.4, 0, 2.2, R=VM.Ry(20))}, instance=t.e(f"{RES5}/Transportation_Props/TRN_GasCan.glb", "PackedScene"))
    t.n("SpareTire", None, ".", {"transform": xf(1.35, 0, 0.9, R=VM.Ry(80))}, instance=t.e(f"{RES5}/Transportation_Props/TRN_SpareTire.glb", "PackedScene"))
    cone = t.e(RES_ROOT + "/02_Town/Street_Props/SP_TrafficCone.glb", "PackedScene")
    for k, (x, z) in enumerate(((-1.6, 4.5), (-1.3, 6.0))):
        t.n(f"Cone_{k}", None, ".", {"transform": xf(x, 0, z)}, instance=cone)
    t.write(os.path.join(P5, "Abandoned_Variants", "Roadside_BrokenDown_Van.tscn"))


# ------------------------------------------------------------------ main
def main():
    textures, mats = materials()
    clean, worn = VM.Mats(False), VM.Mats(True)
    sizes = {}
    # Priority 1: protagonist sedan
    v = VM.build_sedan("VEH_ProtagonistSedan", clean)
    sp = v.spec()
    export("Protagonist_Sedan", sp, "The protagonist's older everyday sedan (early-2000s mid-size, muted slate blue): full exterior, "
           "complete first-person interior, separate wheels / doors / hood / trunk / steering wheel, seat + camera markers.", "hero vehicle", veh=v)
    sedan_markers = {c["name"]: c["t"] for c in sp["children"] if c.get("mb") is None}
    # Priority 2
    v = VM.build_police("VEH_PoliceCruiser", clean)
    export("Police_Cruiser", v.spec(), "Greyhaven Police cruiser (fictional): black / white livery, lightbar, push bar, A-pillar spotlight, "
           "partition, vinyl seats, separate wheels / doors / hood / trunk / steering wheel.", "vehicle", veh=v)
    v, pose = VM.build_pickup("VEH_PickupTruck", clean)
    export("Pickup", v.spec(pose), "Regular-cab pickup (faded red): cargo bed with wheel tubs, drop-down tailgate, bench-seat cabin, "
           "separate wheels / doors / hood / tailgate / steering wheel.", "vehicle", veh=v)
    v = VM.build_van("VEH_DeliveryVan", clean)
    export("Delivery_Van", v.spec(), "Harlow Bakery delivery van (fictional livery): cargo compartment with plywood floor, two hinged rear "
           "doors, two-seat cabin, separate wheels / cab doors / hood / rear doors / steering wheel.", "vehicle", veh=v)
    # traffic colour variants of the sedan platform (same mesh, other paint swatch) - ordinary opening-drive traffic
    for nm, paint in (("VEH_Sedan_Traffic_Green", "paint_green"), ("VEH_Sedan_Traffic_Beige", "paint_beige")):
        v = VM.build_sedan(nm, clean, paint=paint)
        export("Traffic_Variants", v.spec(), f"Sedan platform repainted ({paint.split('_')[1]}) for ordinary town traffic.", "traffic variant",
               base="VEH_ProtagonistSedan", veh=v)
    # Priority 3: abandoned variants (weathered material + pose / glass changes, no new destruction geometry)
    v = VM.build_sedan("VEH_Sedan_Dusty", worn)
    export("Abandoned_Variants", v.spec(), "Sedan left for weeks: dusty / rusty weathered atlas, dirty glass, dead lights.", "abandoned variant",
           base="VEH_ProtagonistSedan", veh=v)
    v = VM.build_sedan("VEH_Sedan_Damaged", worn, paint="paint_green", glass_rect="crack", skip_glass=("Door_FR",))
    export("Abandoned_Variants", v.spec({"Door_FL": VM.Ry(-38), "Hood": VM.Rx(9)}),
           "Damaged sedan: cracked windshield, passenger window gone, driver door hanging open, hood sprung.", "abandoned variant",
           base="VEH_ProtagonistSedan", veh=v)
    v = VM.build_police("VEH_PoliceCruiser_Abandoned", worn)
    export("Abandoned_Variants", v.spec({"Door_FL": VM.Ry(-62), "Door_FR": VM.Ry(25)}),
           "Police cruiser abandoned mid-call: weathered, both front doors open.", "abandoned variant", base="VEH_PoliceCruiser", veh=v)
    v, pose = VM.build_pickup("VEH_Pickup_Abandoned", worn, flat=True, tailgate_down=True)
    export("Abandoned_Variants", v.spec(pose | {"Hood": VM.Rx(0)}, sink=0.22 * 0.38),
           "Abandoned pickup: weathered, sitting on flat tyres, tailgate down.", "abandoned variant", base="VEH_PickupTruck", veh=v)
    v = VM.build_van("VEH_DeliveryVan_BrokenDown", worn)
    export("Abandoned_Variants", v.spec({"Hood": VM.Rx(48), "RearDoor_R": VM.Ry(70)}),
           "Broken-down delivery van: weathered, hood propped open, one rear door swung out.", "abandoned variant", base="VEH_DeliveryVan", veh=v)
    # transportation props
    for name, (spec, size), desc in VM.props(clean):
        export("Transportation_Props", spec, desc, "transportation prop")
    reused = []
    for name, src, desc in (("TRN_Bicycle", "09_Horror_Atmosphere/Abandoned_Props/ABN_FallenBicycle.glb", "Upright bicycle (Pack 09 mesh stood up)."),
                            ("TRN_ShoppingCart", "09_Horror_Atmosphere/Abandoned_Props/ABN_ShoppingCart_Overturned.glb", "Upright shopping cart (Pack 09 mesh stood up).")):
        size = upright_scene(name, os.path.join(V2, src), RES_ROOT + "/" + src)
        reused.append(dict(name=name, scene=f"05_Vehicles/Transportation_Props/{name}.tscn", source=src, size_m=size, description=desc))
    for nm in ("SP_TrafficCone", "SP_RoadBarrier", "SP_ParkingMeter", "SP_Sign_BusStop", "SP_Bench_Wood", "SP_BusShelter"):
        reused.append(dict(name=nm, source=f"02_Town/Street_Props/{nm}.glb", description="Pack 02 street prop, used as-is (no duplicate)."))
    # scenes
    sedan_scene(sedan_markers)
    demo_scene()
    roadside_scene()
    doc = os.path.join(P5, "Documentation")
    os.makedirs(doc, exist_ok=True)
    json.dump({"pack": "THE VEIL - Pack 05 Vehicles & Transportation", "conventions": {"units": "metres", "up": "+Y", "forward": "-Z",
               "origin": "ground level, centred between the axles"}, "textures": textures, "materials": mats, "models": MANIFEST,
               "reused_props": reused, "scenes": ["05_Vehicles/Godot_Scenes/Protagonist_Sedan.tscn", "05_Vehicles/Godot_Scenes/Greyhaven_Opening_Driveway.tscn",
                                                  "05_Vehicles/Abandoned_Variants/Roadside_BrokenDown_Van.tscn",
                                                  "05_Vehicles/Transportation_Props/TRN_Bicycle.tscn", "05_Vehicles/Transportation_Props/TRN_ShoppingCart.tscn"]},
              open(os.path.join(doc, "VEHICLE_MANIFEST.json"), "w", newline="\n"), indent=1)
    print(f"{len(MANIFEST)} GLBs, {sum(m['triangles'] for m in MANIFEST)} triangles; sedan {MANIFEST[0]['triangles']} tris {MANIFEST[0]['size_m']}")


if __name__ == "__main__":
    main()
