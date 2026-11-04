"""Pack 04 commercial building plans, built with the Pack 03 House kit (walls with real openings, hinged / garage
doors, floors, ceilings, walk collision, room metadata) plus commercial extras: flat roofs behind parapets, signage,
storefront glass doors, bi-parting automatic entrance doors, fluorescent troffer grids, hanging aisle signs,
exterior lighting, aprons, parking lines and walkways.

Coordinates are the Pack 03 zone frame: x across the frontage (centred on the zone), z = depth from the zone front
line (street towards -z), y up from lot level (world y 0.15). Furnishing ("fit") entries: (model, x, z, yaw_deg, room, opts).
Fixture convention: origin floor centre, front +Z; yaw 0 -> front faces +z, 180 -> -z (towards the street), 90 -> +x, -90 -> -x.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(V2, "03_Residential", "Source_Scripts"))
sys.path.insert(0, os.path.join(V2, "02_Town", "Source_Scripts"))

import com_fixtures as FX  # noqa: E402  (registers the Pack 04 materials)
import arch  # noqa: E402
import house as house_mod  # noqa: E402
from plans import R, D, DX, Wn  # noqa: E402
from arch import EXT_T, METAL, GLASS  # noqa: E402
from house import seg_points  # noqa: E402
from res_materials import m01  # noqa: E402
from veil_mesh.mesh import MB, T  # noqa: E402
from veil_mesh.gltf import COL_KEY  # noqa: E402

ATLAS, GLOW = FX.ATLAS, FX.GLOW
abox, decal = FX.abox, FX.decal

# ------------------------------------------------------------------ storefront glass door style (Pack 03 kit untouched)
_orig_leaf = arch.panel_door_leaf


def _leaf(w, h, paint, style="interior", t=0.045, knob_side="r"):
    if style != "storefront":
        return _orig_leaf(w, h, paint, style, t, knob_side)
    mb = MB()
    fr = 0.06
    for (a, b, c, d) in ((0.005, 0.0, w - 0.005, 0.12), (0.005, h - fr, w - 0.005, h - 0.005), (0.005, 0.0, fr, h), (w - fr, 0.0, w - 0.005, h)):
        mb.box(METAL, (a, b, -t / 2), (c, d, t / 2), skip=())
    mb.box(GLASS, (fr, 0.12, -0.006), (w - fr, h - fr, 0.006), skip=())
    kx = w - 0.12 if knob_side == "r" else 0.12
    mb.box(METAL, (kx - 0.02, 0.85, t / 2), (kx + 0.02, 1.25, t / 2 + 0.05), skip=())       # pull handle
    mb.box(METAL, (0.1, 0.95, -t / 2 - 0.05), (w - 0.1, 1.0, -t / 2), skip=())             # push bar
    return mb


arch.panel_door_leaf = _leaf


# ------------------------------------------------------------------ commercial building
class ComBuilding(house_mod.House):
    def add_lights(self):
        """fluorescent troffer grid (emissive panels) + a small number of light markers per room; no house switches"""
        for r in self.meta["rooms"]:
            x0, z0, x1, z1 = r["rect"]
            w, d = x1 - x0, z1 - z0
            y = r["ceil_y"]
            spx, spz = (3.2, 2.6) if r["type"] in ("sales", "vestibule", "storage", "records") else (2.4, 2.2)
            nx, nz = max(1, int(round(w / spx))), max(1, int(round(d / spz)))
            fx_ = MB()
            for i in range(nx):
                for j in range(nz):
                    cx, cz = x0 + (i + 0.5) * w / nx, z0 + (j + 0.5) * d / nz
                    abox(fx_, "steel", (cx - 0.64, y - 0.035, cz - 0.34), (cx + 0.64, y, cz + 0.34), skip=("+y",))
                    fx_.box(GLOW, (cx - 0.6, y - 0.04, cz - 0.3), (cx + 0.6, y - 0.035, cz + 0.3), skip=("+y",),
                            uvrect={f: FX.R("light_panel") for f in ("-y", "+x", "-x", "+z", "-z")})
            self.inner.merge(fx_)
            lx, lz = max(1, int(round(w / 9.0))), max(1, int(round(d / 8.0)))
            for i in range(lx):
                for j in range(lz):
                    self.meta["lights"].append(dict(room=r["id"] if lx * lz == 1 else f"{r['id']}_{i}{j}",
                                                    pos=[x0 + (i + 0.5) * w / lx, y - 0.4, z0 + (j + 0.5) * d / lz],
                                                    range=round(max(w / lx, d / lz) * 0.95 + 1.5, 2)))


def parapets(h, top_by_room, cap="Arch_TrimPainted"):
    """raise every exterior wall to an absolute parapet height (per room) + coping; build a flat roof slab per room"""
    siding_default = house_mod.mat_of(h.cw["siding"])
    capm = house_mod.mat_of(cap)
    for (r, side, axis, c, lo, hi) in h.ext_pieces:
        p0, p1 = seg_points(axis, c, lo, hi, side)
        M, L = arch.frame_2d(p0, p1)
        y0 = h.top_y(r)
        y1 = top_by_room.get(r["id"], top_by_room["*"])
        sid = house_mod.mat_of(r.get("siding", h.cw["siding"]))
        b = MB()
        b.box(sid or siding_default, (-EXT_T / 2, y0, -EXT_T / 2), (L + EXT_T / 2, y1, EXT_T / 2), skip=("-y", "+y"))
        b.box(capm, (-EXT_T / 2 - 0.03, y1, -EXT_T / 2 - 0.04), (L + EXT_T / 2 + 0.03, y1 + 0.08, EXT_T / 2 + 0.04), skip=())
        h.ext.merge(b, M)
    roof = m01("Road_Asphalt")
    for r in h.p["rooms"]:
        x0, z0, x1, z1 = r["rect"]
        y = h.top_y(r)
        pts = [(x0 - EXT_T / 2, z0 - EXT_T / 2), (x1 + EXT_T / 2, z0 - EXT_T / 2), (x1 + EXT_T / 2, z1 + EXT_T / 2), (x0 - EXT_T / 2, z1 + EXT_T / 2)]
        h.ext.ground_poly(roof, pts, y=y)


def sign_board(mb, rect, x, y, z, w, h, face="-z", depth=0.1, frame="enamel_white", glow=True):
    """sign box standing proud of a wall; face -z = towards the street in the zone frame"""
    if face == "-z":
        abox(mb, frame, (x - w / 2 - 0.06, y - h / 2 - 0.06, z - depth), (x + w / 2 + 0.06, y + h / 2 + 0.06, z), skip=("+z",))
        decal(mb, rect, (x, y, z - depth), w, h, face="-z", mat=GLOW if glow else ATLAS, lift=0.004)
    elif face == "+z":
        abox(mb, frame, (x - w / 2 - 0.06, y - h / 2 - 0.06, z), (x + w / 2 + 0.06, y + h / 2 + 0.06, z + depth), skip=("-z",))
        decal(mb, rect, (x, y, z + depth), w, h, face="+z", mat=GLOW if glow else ATLAS, lift=0.004)


def wall_lamp(h, x, y, z, face="-z"):
    """exterior wall pack / gooseneck head (emissive) + light marker"""
    s = -1 if face == "-z" else 1
    zz0, zz1 = sorted((z, z + s * 0.25))
    abox(h.ext, "black_plastic", (x - 0.2, y - 0.08, zz0), (x + 0.2, y + 0.1, zz1), skip=())
    h.ext.box(GLOW, (x - 0.16, y - 0.1, zz0 + 0.02), (x + 0.16, y - 0.08, zz1 - 0.02), skip=("+y",),
              uvrect={f: FX.R("light_panel") for f in ("-y", "+x", "-x", "+z", "-z")})
    h.meta.setdefault("ext_lights", []).append([x, y - 0.4, z + s * 0.6])


def door_sign(h, door_name, rect, w=0.5, hgt=0.11, side=None, glow=False):
    """small sign above a door (on the side of room `side`)"""
    for dr in h.meta["doors"]:
        if dr["name"].endswith("_" + door_name):
            n = np.array(dr["normal"])
            c = np.array([dr["center"][0], dr["center"][2]])
            # room [1] is on the -n side
            sg = -1 if (side is None or side == dr["rooms"][1]) else 1
            t = EXT_T if dr["exterior"] else 0.12
            p = c + n * sg * (t / 2 + 0.002)
            y = dr["center"][1] + dr["h"] + 0.18
            face = ("+x" if n[0] * sg > 0 else "-x") if abs(n[0]) > 0.5 else ("+z" if n[1] * sg > 0 else "-z")
            decal(h.inner, rect, (p[0], y, p[1]), w, hgt, face=face, mat=GLOW if glow else ATLAS, lift=0.004)
            return
    raise KeyError(door_name)


def hanging_sign(h, rect, x, z, y, w=0.9, hgt=0.68, along="x"):
    """double-sided ceiling-hung sign with two rods"""
    b = h.inner
    if along == "x":
        abox(b, "enamel_white", (x - w / 2, y - hgt / 2, z - 0.02), (x + w / 2, y + hgt / 2, z + 0.02), skip=())
        decal(b, rect, (x, y, z + 0.02), w - 0.06, hgt - 0.06, face="+z", lift=0.002)
        decal(b, rect, (x, y, z - 0.02), w - 0.06, hgt - 0.06, face="-z", lift=0.002)
    else:
        abox(b, "enamel_white", (x - 0.02, y - hgt / 2, z - w / 2), (x + 0.02, y + hgt / 2, z + w / 2), skip=())
        decal(b, rect, (x + 0.02, y, z), w - 0.06, hgt - 0.06, face="+x", lift=0.002)
        decal(b, rect, (x - 0.02, y, z), w - 0.06, hgt - 0.06, face="-x", lift=0.002)


def ceiling_rods(h, x, z, y0, y1, half):
    for dx in (-half, half):
        abox(h.inner, "steel", (x + dx - 0.006, y0, z - 0.006), (x + dx + 0.006, y1, z + 0.006), skip=())


def slab(h, mat, pts, y=0.012):
    """walkable exterior surface (front walk, apron, pad, walkway) - visual + floor collision"""
    h.ext.ground_poly(m01(mat) if not mat.startswith("M_") else mat, pts, y=y)
    h.col.ground_poly(COL_KEY, pts, y=y)


def line(h, x0, z0, x1, z1, w=0.1, y=0.016):
    """painted ground line (Pack 01 white road marking)"""
    d = np.array([x1 - x0, z1 - z0], float)
    d /= np.linalg.norm(d)
    n = np.array([-d[1], d[0]]) * w / 2
    pts = [(x0 - n[0], z0 - n[1]), (x1 - n[0], z1 - n[1]), (x1 + n[0], z1 + n[1]), (x0 + n[0], z0 + n[1])]
    h.ext.ground_poly(m01("Road_MarkingWhite"), pts, y=y)


def window_dressing(h, rect, x, y, z, w, hgt, face="-z"):
    """poster / banner pasted inside the glass, facing out"""
    decal(h.inner, rect, (x, y, z), w, hgt, face=face, lift=0.0)


def auto_doors(h, x, z, w, hgt, name):
    """bi-parting automatic sliding glass doors in an arch opening (two interactive leaves, closed pose)"""
    for k, sg in (("L", -1), ("R", 1)):
        leaf = MB()
        lw = w / 2
        for (a, b, c, d) in ((0, 0, lw, 0.08), (0, hgt - 0.06, lw, hgt), (0, 0, 0.05, hgt), (lw - 0.05, 0, lw, hgt)):
            leaf.box(METAL, (a, b, -0.025), (c, d, 0.025), skip=())
        leaf.box(GLASS, (0.05, 0.08, -0.006), (lw - 0.05, hgt - 0.06, 0.006), skip=())
        col = MB()
        col.box(COL_KEY, (0, 0, -0.03), (lw, hgt, 0.03), skip=())
        x0 = x if sg > 0 else x - lw
        nm = f"INT_AutoDoor_{name}_{k}"
        h.nodes.append({"name": nm, "t": (float(x0), float(h.floor_y(h.rooms[h.p['auto_room']]) + 0.0), float(z)), "mb": leaf,
                        "extras": {"veil_interact": "slide", "axis": "x", "distance": float(sg * (lw - 0.08)), "auto": True},
                        "children": [{"name": nm + "_Col-convcolonly", "mb": col}]})
    abox(h.ext, "steel", (x - w / 2 - 0.1, hgt, z - 0.12), (x + w / 2 + 0.1, hgt + 0.25, z + 0.12), skip=())    # operator header


# =================================================================== plans
FLOOR = "Com_SupermarketFloorTiles"
CEIL = "Com_CeilingTiles"
DRY = "Int_DrywallLight"
FY = 0.04            # finished floor: a 4 cm threshold above the sidewalk / lot (step-free)


def _supermarket_extras(h):
    parapets(h, {"VEST": 6.6, "*": 5.4})
    b = h.ext
    sign_board(b, "sign_market", 0.0, 5.55, 0.2 - EXT_T / 2, 6.4, 0.8)
    sign_board(b, "sign_market_sub", -11.0, 4.85, 3.2 - EXT_T / 2, 4.0, 0.38, glow=False)
    sign_board(b, "sign_market_sub", 11.0, 4.85, 3.2 - EXT_T / 2, 4.0, 0.38, glow=False)
    auto_doors(h, 0.0, 0.2, 2.4, 2.3, "Entrance")
    for x in (-16.0, -6.0, 6.0, 16.0):
        wall_lamp(h, x, 4.0, 3.2 - EXT_T / 2, "-z")
    h.meta.setdefault("ext_lights", []).append([21.0, 3.2, 15.9])
    abox(h.ext, "black_plastic", (20.1, 3.2, 15.7), (20.4, 3.45, 16.1), skip=())
    # front walk + entrance apron joining the Pack 02 lot edge; loading pad on the service side (+x)
    slab(h, "Road_SidewalkConcrete", [(-21.0, -1.0), (21.0, -1.0), (21.0, 3.1), (-21.0, 3.1)])
    slab(h, "Int_BasementConcrete", [(20.1, 13.6), (24.5, 13.6), (24.5, 18.2), (20.1, 18.2)])
    for x in (-3.0, 3.0):                               # bollards at the entrance
        abox(h.ext, "yellow_paint", (x - 0.12, 0.0, -0.6), (x + 0.12, 1.0, -0.36), skip=("-y",))
    # window banners
    window_dressing(h, "specials", -12.6, 1.6, 3.2 - EXT_T / 2 + 0.01 + 0.2, 2.4, 0.6)
    window_dressing(h, "produce_banner", -17.0, 1.6, 3.2 - EXT_T / 2 + 0.21, 2.4, 0.6)
    window_dressing(h, "specials", 12.6, 1.6, 3.2 - EXT_T / 2 + 0.21, 2.4, 0.6)
    # hanging aisle / department signs
    y = h.ceil_y(h.rooms["SALES"]) - 0.75
    for k in range(7):
        x = -10.0 + 3.0 * k
        ceiling_rods(h, x, 8.4, y + 0.34, y + 1.1, 0.35)
        hanging_sign(h, f"aisle_{k + 1}", x, 8.4, y, w=0.9, hgt=0.68)
    for rect, x, z, al in (("aisle_produce", -16.5, 9.5, "x"), ("aisle_frozen", 15.0, 9.5, "z"), ("aisle_dairy", -4.0, 13.0, "x")):
        ceiling_rods(h, x, z, y + 0.2, y + 1.1, 0.3) if al == "x" else None
        hanging_sign(h, rect, x, z, y + 0.1, w=1.5, hgt=0.38, along=al)
    door_sign(h, "Staff", "staff", side="SALES")
    door_sign(h, "Stockroom", "staff", side="SALES")
    door_sign(h, "Office", "staff", side="SALES")
    door_sign(h, "BackExit", "exit", w=0.3, hgt=0.15, side="BACK", glow=True)
    door_sign(h, "Vestibule", "exit", w=0.3, hgt=0.15, side="SALES", glow=True)
    door_sign(h, "Restroom", "restroom", side="BACK")
    # tiled band along the sales-floor walls
    for (x0, z0, x1, z1, f) in ((-19.94, 3.3, -19.94, 14.1, "+x"), (19.94, 3.3, 19.94, 14.1, "-x")):
        decal(h.inner, "tile_band", (x0, 3.6, (z0 + z1) / 2), z1 - z0, 0.25, face=f, lift=0.0)


SUPERMARKET = dict(
    name="COM_Supermarket", title="Greyhaven Market - supermarket", width=40.0, levels={0: (FY, 4.2)}, zone="SUPERMARKET",
    auto_room="VEST",
    rooms=[
        R("VEST", 0, (-3.5, 0.2, 3.5, 3.2), "vestibule", FLOOR, "Com_StorefrontConcrete", h=3.4, ceil=CEIL),
        R("SALES", 0, (-20.0, 3.2, 20.0, 14.2), "sales", FLOOR, DRY, ceil=CEIL),
        R("BACK", 0, (-14.5, 14.2, 20.0, 17.6), "storage", "Int_BasementConcrete", "Com_StorageConcrete", h=3.6, ceil="Com_StorageConcrete"),
        R("OFFICE", 0, (-20.0, 14.2, -17.0, 17.6), "office", "Int_Linoleum", DRY, h=2.7, ceil=CEIL),
        R("RESTRM", 0, (-17.0, 14.2, -14.5, 17.6), "restroom", "Int_TilesBathroom", "Int_TilesBathroom", h=2.7, ceil=CEIL),
    ],
    doors=[
        DX("VEST", "F", 0.0, w=2.4, h=2.3, kind="arch", name="Entrance"),
        D("VEST", "SALES", -1.6, w=2.0, h=2.3, kind="arch", name="Vestibule"),
        D("VEST", "SALES", 1.6, w=2.0, h=2.3, kind="arch", name="VestibuleIn"),
        D("SALES", "BACK", 8.4, w=1.6, h=2.3, kind="arch", name="Stockroom"),
        D("SALES", "BACK", 15.5, w=1.0, h=2.2, into="BACK", name="Staff"),
        D("SALES", "OFFICE", -18.5, w=0.95, into="OFFICE", name="Office"),
        D("BACK", "RESTRM", 16.0, w=0.85, into="RESTRM", name="Restroom"),
        DX("BACK", "R", 15.9, w=2.8, h=3.0, kind="garage", name="Loading"),
        DX("BACK", "B", 8.0, w=1.0, h=2.15, style="back", name="BackExit"),
    ],
    windows=[Wn("SALES", "F", x, w=3.6, h=2.5, sill=0.35, style="picture") for x in (-17.0, -12.6, -8.2, 8.2, 12.6, 17.0)] +
            [Wn("VEST", "L", 1.7, w=2.2, h=2.3, sill=0.4, style="picture"), Wn("VEST", "R", 1.7, w=2.2, h=2.3, sill=0.4, style="picture")],
    ext=dict(siding="Com_StorefrontBrick", trim="Arch_TrimPainted", roof="Road_Asphalt", door="Town_PaintGreen", foundation="Com_StorefrontConcrete"),
    extras=[_supermarket_extras],
    fit=(
        # 8 double-sided gondolas = 7 aisles (signs 1-7), power aisle in front, back aisle along the dairy wall
        [(g, -11.5 + 3.0 * k, 10.0, 90, "SALES", {}) for k, g in enumerate(
            ["COM_Gondola_Bread", "COM_Gondola_Grocery_A", "COM_Gondola_Grocery_B", "COM_Gondola_Grocery_C",
             "COM_Gondola_Grocery_D", "COM_Gondola_Grocery_A", "COM_Gondola_Grocery_B", "COM_Gondola_Grocery_C"])] +
        [("COM_Cooler_Dairy" if i < 4 else "COM_Cooler_Drinks", -11.1 + 2.36 * i, 13.74, 180, "SALES", {}) for i in range(8)] +
        [("COM_Cooler_Frozen", 19.49, z, -90, "SALES", {}) for z in (5.5, 7.9, 10.3, 12.7)] +
        [("COM_Freezer_Chest", 15.0, z, 90, "SALES", {}) for z in (7.6, 11.0)] +
        [("COM_Produce_WallCase", -19.43, z, 90, "SALES", {}) for z in (5.6, 8.0, 10.4, 12.8)] +
        [("COM_Produce_Table", -16.0, z, 90, "SALES", {}) for z in (7.4, 11.0)] +
        [("COM_Checkout_Lane", x, 5.0, 90, "SALES", {}) for x in (-12.5, -9.5, -6.5, -3.5)] +
        [("COM_ServiceCounter", 6.0, 5.0, 0, "SALES", {}), ("COM_BasketStack", 4.2, 3.6, 0, "SALES", {}), ("COM_BasketStack", -4.6, 3.6, 0, "SALES", {})] +
        [("COM_GroceryBag", -11.0 + 3.0 * k, 4.4, 0, "SALES", {"y": 0.62, "fp": False}) for k in range(3)] +
        [("COM_PalletRack", x, 17.0, 180, "BACK", {}) for x in (-11.0, -8.1, -5.2, -2.3)] +
        [("COM_PalletStack", x, 15.2, 0, "BACK", {}) for x in (2.5, 4.0)] +
        [("RES_Shelving_Metal", x, 17.27, 180, "BACK", {}) for x in (10.2, 11.5, 12.8)] +
        [("RES_CardboardBox_Stack", 6.5, 17.1, 0, "BACK", {}), ("RES_CardboardBox_Closed", 5.4, 17.0, 20, "BACK", {}),
         ("RES_ElectricalPanel", 19.9, 14.9, -90, "BACK", {"y": 1.2, "fp": False})] +
        [("RES_Desk_Computer", -18.5, 17.2, 180, "OFFICE", {}), ("RES_DeskChair_Office", -18.5, 16.4, 180, "OFFICE", {}),
         ("COM_FilingCabinet", -19.57, 15.0, 90, "OFFICE", {}), ("RES_WallCalendar", -17.07, 16.0, -90, "OFFICE", {"y": 1.5, "fp": False})] +
        [("RES_Toilet", -15.8, 17.15, 180, "RESTRM", {}), ("RES_BathSink_Pedestal", -16.65, 15.3, 90, "RESTRM", {})] +
        [("COM_CartCorral", -12.0, -9.0, 0, None, {"outdoor": True}), ("COM_CartCorral", 12.0, -14.0, 0, None, {"outdoor": True})]
    ),
    dyn=[("res://THE_VEIL_ASSETS_V2/05_Vehicles/Transportation_Props/TRN_ShoppingCart.tscn", x, z, 180, f"Cart_{i}")
         for i, (x, z) in enumerate([(-3.0, 0.75), (-3.0, 1.6), (-3.0, 2.45), (3.0, 0.75), (3.0, 1.6), (3.0, 2.45), (-12.0, -9.0), (-11.0, -9.0)])],
    nav=[("Entrance", 0.0, -0.4), ("Checkout_1", -11.8, 5.0), ("Checkout_4", -2.8, 5.0), ("CustomerService", 6.0, 6.0),
         ("Aisle_1", -10.0, 10.0), ("Aisle_4", -1.0, 10.0), ("Aisle_7", 8.0, 10.0), ("Produce", -17.5, 9.3), ("Dairy", -10.0, 12.75),
         ("Freezers", 17.4, 9.3), ("Backroom", 0.0, 15.6), ("LoadingDoor", 18.8, 15.9), ("Office", -18.5, 15.4), ("Restroom", -15.8, 15.8)],
    interact_extra=[("ShoppingCarts", 3.0, 1.6, "cart_pickup"), ("Baskets", 2.3, 4.2, "basket_pickup")],
)


def _gameshop_extras(h):
    parapets(h, {"*": 4.8})
    b = h.ext
    zf = 0.3 - EXT_T / 2
    sign_board(b, "sign_games", 0.0, 4.1, zf, 5.4, 0.9)
    wall_lamp(h, -3.0, 3.2, zf, "-z")
    wall_lamp(h, 3.0, 3.2, zf, "-z")
    slab(h, "Road_SidewalkConcrete", [(-6.0, -0.4), (6.0, -0.4), (6.0, 0.25), (-6.0, 0.25)])
    # display window: low platform, console boxes, posters on the glass, neon OPEN sign
    zi = 0.3 + EXT_T / 2
    abox(h.inner, "counter_wood", (-0.4, FY, zi), (4.0, FY + 0.45, zi + 0.7), skip=("-y",))
    FX.stock_run(h.inner, -0.2, 1.6, FY + 0.45, zi + 0.45, 0.3, 0.32, "consoles_boxes", face=-1, facing=0.18)
    FX.stock_run(h.inner, 2.0, 3.8, FY + 0.45, zi + 0.35, 0.12, 0.2, "games_a", face=-1, facing=0.135)
    for x, rect in ((0.3, "preorder"), (3.3, "tradein")):
        window_dressing(h, rect, x, 1.6, zi + 0.002, 0.55, 0.7, face="-z")
    window_dressing(h, "poster_5", 1.8, 1.7, zi + 0.002, 0.6, 0.8, face="-z")
    decal(h.inner, "open", (-4.65, 1.9, zi + 0.004), 0.6, 0.26, face="-z", mat=GLOW, lift=0.0)
    door_sign(h, "StockRoom", "staff", side="SHOP")
    door_sign(h, "Office", "staff", side="SHOP")
    door_sign(h, "BackExit", "exit", w=0.3, hgt=0.15, side="STOCK", glow=True)


GAME_SHOP = dict(
    name="COM_GameShop", title="Game Haven - independent video game shop", width=11.2, levels={0: (FY, 3.3)}, zone="GAME_SHOP",
    rooms=[
        R("SHOP", 0, (-5.6, 0.3, 5.6, 8.4), "sales", "Int_CarpetWorn", "Int_WallpaperFaded", ceil=CEIL),
        R("STOCK", 0, (-5.6, 8.4, 0.8, 11.6), "storage", "Int_BasementConcrete", "Com_StorageConcrete", h=3.0, ceil="Com_StorageConcrete"),
        R("OFFICE", 0, (0.8, 8.4, 5.6, 11.6), "office", "Int_Linoleum", DRY, h=2.8, ceil=CEIL),
    ],
    doors=[
        DX("SHOP", "F", -3.2, w=1.0, h=2.2, style="storefront", name="Entrance"),
        D("SHOP", "STOCK", -2.0, w=0.95, into="STOCK", name="StockRoom"),
        D("SHOP", "OFFICE", 3.6, w=0.95, into="OFFICE", name="Office"),
        D("STOCK", "OFFICE", 10.0, w=0.9, into="OFFICE", name="StockOffice"),
        DX("STOCK", "B", -3.5, w=1.0, h=2.15, style="back", name="BackExit"),
    ],
    windows=[Wn("SHOP", "F", 1.8, w=4.6, h=2.0, sill=0.5, style="picture"), Wn("SHOP", "F", -4.65, w=1.4, h=2.0, sill=0.5, style="picture")],
    ext=dict(siding="Com_StorefrontBrick", trim="Town_PaintNavy", roof="Road_Asphalt", door="Town_PaintNavy", foundation="Com_StorefrontConcrete"),
    extras=[_gameshop_extras],
    fit=[
        ("COM_GameWallShelf", -5.32, 2.25, 90, "SHOP", {}), ("COM_GameWallShelf_Used", -5.32, 4.3, 90, "SHOP", {}),
        ("COM_GameWallShelf", -5.32, 6.35, 90, "SHOP", {}),
        ("COM_ConsoleWallShelf", -4.3, 8.115, 180, "SHOP", {}),
        ("COM_PosterBoard", -0.4, 8.33, 180, "SHOP", {"y": 1.3, "fp": False}),
        ("COM_PosterBoard_B", 5.53, 5.3, -90, "SHOP", {"y": 1.4, "fp": False}),
        ("COM_GameRack_New", -1.6, 3.0, 90, "SHOP", {}), ("COM_GameRack_Used", -1.6, 5.6, 90, "SHOP", {}),
        ("COM_ConsoleCase", 1.8, 3.3, 0, "SHOP", {}),
        ("COM_DemoStation", 5.2, 2.6, -90, "SHOP", {"snap": True}),
        ("RES_TVStand", 5.27, 4.3, -90, "SHOP", {}), ("RES_TV_CRT_Small", 5.27, 4.3, -90, "SHOP", {"y": 0.59, "fp": False}),
        ("RES_GameConsole", 5.25, 3.85, -90, "SHOP", {"y": 0.59, "fp": False}),
        ("COM_RetailCounter", 2.8, 6.6, 180, "SHOP", {}),
        ("RES_Shelving_Metal", 1.6, 8.115, 180, "SHOP", {}),
        ("RES_WallClock", 5.57, 7.0, -90, "SHOP", {"y": 2.4, "fp": False}),
        ("RES_Desk_Computer", 3.2, 11.2, 180, "OFFICE", {}), ("RES_DeskChair_Office", 3.2, 10.4, 180, "OFFICE", {}),
        ("RES_CardboardBox_Stack", 5.1, 9.0, 0, "OFFICE", {}), ("RES_WallCalendar", 5.57, 10.3, -90, "OFFICE", {"y": 1.5, "fp": False}),
        ("RES_Shelving_Metal", -4.8, 11.27, 180, "STOCK", {}), ("RES_Shelving_Metal", -0.1, 11.27, 180, "STOCK", {}),
        ("RES_Shelving_Metal", -1.6, 11.27, 180, "STOCK", {}), ("COM_DocumentBoxes", -5.0, 9.2, 90, "STOCK", {}),
        ("RES_CardboardBox_Closed", -0.6, 9.3, 15, "STOCK", {}),
    ],
    dyn=[],
    nav=[("Entrance", -3.2, -0.4), ("NewReleases", -1.6, 1.6), ("UsedGames", -3.0, 5.6), ("WallGames", -4.4, 4.3), ("Consoles", -4.3, 7.3),
         ("DemoStation", 4.4, 2.6), ("Counter_Customer", 2.8, 5.7), ("BehindCounter", 2.8, 7.5), ("Office", 3.2, 9.6), ("StockRoom", -2.5, 9.6)],
    interact_extra=[],
)


def _pharmacy_extras(h):
    parapets(h, {"*": 4.7})
    zf = 0.3 - EXT_T / 2
    sign_board(h.ext, "sign_drug", 0.0, 4.05, zf, 6.0, 0.88)
    for x in (-8.0, 8.0):
        wall_lamp(h, x, 3.3, zf, "-z")
    slab(h, "Road_SidewalkConcrete", [(-11.0, -0.4), (11.0, -0.4), (11.0, 0.25), (-11.0, 0.25)])
    door_sign(h, "Stock", "staff", side="STORE")
    door_sign(h, "Dispensary", "staff", side="STORE")
    door_sign(h, "BackExit", "exit", w=0.3, hgt=0.15, side="STOCK", glow=True)
    decal(h.inner, "waiting", (7.5, 2.2, 0.3 + EXT_T / 2 + 0.004), 0.8, 0.2, face="+z", lift=0.0)
    decal(h.inner, "open", (-6.9, 1.9, 0.3 + EXT_T / 2 + 0.004), 0.5, 0.22, face="-z", mat=GLOW, lift=0.0)


PHARMACY = dict(
    name="COM_Pharmacy", title="Hollis Drug - pharmacy", width=21.0, levels={0: (FY, 3.4)}, zone="PHARMACY",
    rooms=[
        R("STORE", 0, (-10.5, 0.3, 10.5, 7.6), "sales", "Int_Linoleum", DRY, ceil=CEIL),
        R("DISP", 0, (3.0, 7.6, 10.5, 10.6), "dispensary", "Int_Linoleum", DRY, h=3.0, ceil=CEIL),
        R("STOCK", 0, (-10.5, 7.6, 3.0, 10.6), "storage", "Int_BasementConcrete", "Com_StorageConcrete", h=3.0, ceil="Com_StorageConcrete"),
    ],
    doors=[
        DX("STORE", "F", -6.0, w=1.0, h=2.2, style="storefront", name="Entrance"),
        D("STORE", "STOCK", -4.0, w=0.95, into="STOCK", name="Stock"),
        D("STORE", "DISP", 3.7, w=0.95, into="DISP", name="Dispensary"),
        D("STORE", "DISP", 7.5, w=3.0, h=2.2, kind="arch", name="PharmacyWindow"),
        D("STOCK", "DISP", 9.1, w=0.9, into="DISP", name="StockDisp"),
        DX("STOCK", "B", -8.0, w=1.0, h=2.15, style="back", name="BackExit"),
    ],
    windows=[Wn("STORE", "F", x, w=w, h=2.0, sill=0.5, style="picture") for x, w in ((-8.6, 2.8), (-2.4, 4.2), (3.0, 4.2), (7.8, 4.2))],
    ext=dict(siding="Com_StorefrontConcrete", trim="Town_PaintRed", roof="Road_Asphalt", door="Town_PaintRed", foundation="Com_StorefrontBrick"),
    extras=[_pharmacy_extras],
    fit=[
        ("COM_RetailCounter", -8.8, 3.0, 90, "STORE", {}),
        ("COM_Gondola_Health", -4.0, 4.3, 90, "STORE", {}), ("COM_Gondola_Health", -1.0, 4.3, 90, "STORE", {}),
        ("COM_Gondola_Health", 2.0, 4.3, 90, "STORE", {}),
        ("COM_WallShelf_Health", 10.17, 2.0, -90, "STORE", {}), ("COM_WallShelf_Health", 10.17, 4.4, -90, "STORE", {}),
        ("COM_PharmacyCounter", 7.5, 7.6, 180, "STORE", {"straddle": True}),
        ("COM_WaitingChairs", 7.0, 4.9, 0, "STORE", {})
    ] + [("COM_DispensaryShelf", x, 10.3, 180, "DISP", {}) for x in (5.0, 7.2, 9.35)] + [
        ("COM_FilingCabinet", 10.07, 8.6, -90, "DISP", {})
    ] + [("RES_Shelving_Metal", x, 10.27, 180, "STOCK", {}) for x in (-9.75, -6.6, -5.3, -4.0)] + [
        ("RES_CardboardBox_Stack", -2.0, 10.1, 0, "STOCK", {}), ("COM_PalletStack", 0.5, 9.6, 90, "STOCK", {}),
        ("RES_WallClock", -10.43, 5.5, 90, "STORE", {"y": 2.5, "fp": False}),
    ],
    dyn=[],
    nav=[("Entrance", -6.0, -0.4), ("FrontCounter", -7.9, 3.0), ("Aisle_A", -5.5, 4.3), ("Aisle_C", 0.5, 4.3), ("WallShelves", 9.2, 3.2),
         ("PharmacyCounter", 7.5, 6.6), ("Waiting", 7.0, 5.9), ("Dispensary", 6.0, 8.9), ("Stock", -4.0, 9.0)],
    interact_extra=[],
)


def _gas_extras(h):
    parapets(h, {"*": 4.5})
    zf = 0.5 - EXT_T / 2
    sign_board(h.ext, "sign_mart", -2.0, 3.85, zf, 4.0, 0.62)
    for x in (-5.5, 2.0, 6.2):
        wall_lamp(h, x, 3.1, zf, "-z")
    slab(h, "Road_SidewalkConcrete", [(-7.5, -1.2), (7.5, -1.2), (7.5, 0.45), (-7.5, 0.45)], y=0.1)
    abox(h.ext, "concrete", (-7.5, 0.0, -1.2), (7.5, 0.1, -1.05), skip=("-y",))          # curb face
    for k in range(5):                                   # parking stalls in front of the store
        line(h, -6.6 + 2.6 * k, -1.3, -6.6 + 2.6 * k, -6.3)
    door_sign(h, "Restroom", "restroom", side="MART")
    door_sign(h, "Storage", "staff", side="MART")
    door_sign(h, "Office", "staff", side="MART")
    door_sign(h, "BackExit", "exit", w=0.3, hgt=0.15, side="STORE", glow=True)
    decal(h.inner, "open", (5.6, 1.9, 0.5 + EXT_T / 2 + 0.004), 0.5, 0.22, face="-z", mat=GLOW, lift=0.0)
    decal(h.inner, "coffee_sign", (0.2, 2.6, 8.2 - 0.06), 0.9, 0.22, face="-z", lift=0.002)


GAS_STATION = dict(
    name="COM_GasStation", title="Quarry Fuel - gas station & Food Mart", width=14.0, levels={0: (FY, 3.2)}, zone="GAS_STATION",
    rooms=[
        R("MART", 0, (-7.0, 0.5, 7.0, 8.2), "sales", FLOOR, DRY, ceil=CEIL),
        R("STORE", 0, (-7.0, 8.2, 1.5, 11.5), "storage", "Int_BasementConcrete", "Com_StorageConcrete", h=3.0, ceil="Com_StorageConcrete"),
        R("RR", 0, (1.5, 8.2, 4.2, 11.5), "restroom", "Int_TilesBathroom", "Int_TilesBathroom", h=2.7, ceil=CEIL),
        R("OFFICE", 0, (4.2, 8.2, 7.0, 11.5), "office", "Int_Linoleum", DRY, h=2.7, ceil=CEIL),
    ],
    doors=[
        DX("MART", "F", 4.0, w=1.0, h=2.2, style="storefront", name="Entrance"),
        D("MART", "RR", 2.85, w=0.85, into="RR", name="Restroom"),
        D("MART", "STORE", -3.0, w=0.95, into="STORE", name="Storage"),
        D("MART", "OFFICE", 5.6, w=0.9, into="OFFICE", name="Office"),
        DX("STORE", "B", -5.0, w=1.0, h=2.15, style="back", name="BackExit"),
    ],
    windows=[Wn("MART", "F", x, w=w, h=2.0, sill=0.5, style="picture") for x, w in ((-5.0, 3.0), (-0.6, 4.2), (6.0, 1.6))],
    ext=dict(siding="Com_StorefrontConcrete", trim="Town_PaintRed", roof="Road_Asphalt", door="Town_PaintRed", foundation="Com_StorefrontBrick"),
    extras=[_gas_extras],
    fit=[
    ] + [("COM_Cooler_Drinks", -6.5, z, 90, "MART", {}) for z in (2.6, 5.0)] + [
        ("COM_Gondola_Snacks", -3.5, 4.4, 90, "MART", {}), ("COM_Gondola_Snacks", -0.5, 4.4, 90, "MART", {}),
        ("COM_MartCounter", 4.6, 3.4, -90, "MART", {}),
        ("COM_CoffeeStation", 0.2, 7.825, 180, "MART", {"snap": True}),
        ("COM_WallShelf_Mart", -5.4, 7.915, 180, "MART", {})
    ] + [("RES_Shelving_Metal", x, 11.17, 180, "STORE", {}) for x in (-6.2, -1.0, 0.3)] + [
        ("RES_CardboardBox_Stack", -4.6, 9.6, 0, "STORE", {}), ("COM_PalletStack", -2.6, 10.6, 0, "STORE", {}),
        ("RES_Toilet", 2.85, 11.07, 180, "RR", {}), ("RES_BathSink_Pedestal", 3.91, 9.3, -90, "RR", {}),
        ("RES_Mirror_Bathroom", 4.13, 9.3, -90, "RR", {"y": 1.1, "fp": False}),
        ("RES_Desk_Computer", 5.6, 11.1, 180, "OFFICE", {}), ("RES_DeskChair_Office", 5.6, 10.3, 180, "OFFICE", {}),
        ("COM_FilingCabinet", 6.57, 9.0, -90, "OFFICE", {}),
        ("COM_IceChest", 6.0, -0.02, 180, None, {"outdoor": True}), ("COM_AirPump", -7.6, 2.0, -90, None, {"outdoor": True}),
        # forecourt (Pack 02 GAS_PUMP_CANOPY zone, world x 134-150, z -22..-10 = local x 6..22, z -16..-4)
        ("COM_GasCanopy", 14.0, -10.0, 0, None, {"outdoor": True, "fp": False}),
        ("COM_PumpIsland", 11.0, -10.0, 90, None, {"outdoor": True}), ("COM_PumpIsland", 17.0, -10.0, 90, None, {"outdoor": True}),
        ("COM_FuelPump", 11.0, -11.2, 90, None, {"outdoor": True, "y": 0.16}), ("COM_FuelPump", 11.0, -8.8, 90, None, {"outdoor": True, "y": 0.16}),
        ("COM_FuelPump", 17.0, -11.2, 90, None, {"outdoor": True, "y": 0.16}), ("COM_FuelPump", 17.0, -8.8, 90, None, {"outdoor": True, "y": 0.16}),
        ("COM_PriceSign", 22.5, -18.5, 180, None, {"outdoor": True}),
    ],
    dyn=[("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_TrashBin_Public.glb", 11.0, -13.1, 0, "TrashBin_A"),
         ("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_TrashBin_Public.glb", 17.0, -6.9, 0, "TrashBin_B"),
         ("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_TrashBin_Public.glb", -1.0, -0.5, 0, "TrashBin_Store")],
    nav=[("Entrance", 4.0, -0.6), ("Coolers", -5.6, 3.8), ("SnackAisle", -2.0, 4.4), ("Counter_Customer", 3.5, 3.4), ("BehindCounter", 5.9, 3.4),
         ("Coffee", 0.2, 7.0), ("Restroom", 2.85, 9.6), ("Storage", -3.0, 9.4), ("Office", 5.6, 9.4)],
    interact_extra=[],
)


def _archive_extras(h):
    b = h.ext
    # plaque over the portico entrance (on the front wall above the door)
    zf = 7.0 - EXT_T / 2
    sign_board(b, "sign_archive", 0.0, 3.95, zf, 2.6, 0.33, glow=False, frame="laminate_cream", depth=0.06)
    for x in (-2.2, 2.2):
        wall_lamp(h, x, 3.0, zf, "-z")
    # walkway from the gap in the Pack 02 brick wall (world x ~ -30, z -6.8 = local x -2, z -7.2) to the portico steps
    slab(h, "Road_SidewalkConcrete", [(-3.0, -7.4), (-1.0, -7.4), (-1.0, 1.0), (-3.0, 1.0)])
    slab(h, "Road_SidewalkConcrete", [(-3.0, 1.0), (3.0, 1.0), (3.0, 3.75), (-3.0, 3.75)])
    door_sign(h, "ReadingRoom", "reading", side="LOBBY")
    door_sign(h, "Records", "records", side="LOBBY")
    door_sign(h, "Office", "staff", side="LOBBY")
    door_sign(h, "BackExit", "exit", w=0.3, hgt=0.15, side="STORAGE", glow=True)


AY = 0.75   # raised civic floor
ARCHIVE = dict(
    name="COM_MunicipalArchive", title="Greyhaven Municipal Archive", width=22.0, levels={0: (AY, 3.6)}, zone="MUNICIPAL_ARCHIVE",
    rooms=[
        R("READ", 0, (-11.0, 7.0, -3.0, 13.0), "reading", "Int_FloorboardsOld", "Int_WallpaperFaded", ceil=DRY),
        R("LOBBY", 0, (-3.0, 7.0, 3.0, 13.0), "lobby", "Int_Linoleum", DRY, ceil=DRY),
        R("OFFICE", 0, (3.0, 7.0, 11.0, 13.0), "office", "Int_CarpetWorn", DRY, ceil=CEIL),
        R("RECORDS", 0, (-11.0, 13.0, 4.0, 21.0), "records", "Int_Linoleum", DRY, ceil=CEIL),
        R("STORAGE", 0, (4.0, 13.0, 11.0, 21.0), "storage", "Int_BasementConcrete", "Com_StorageConcrete", ceil="Com_StorageConcrete"),
    ],
    doors=[
        DX("LOBBY", "F", 0.0, w=1.2, h=2.4, style="front", name="Entrance"),
        D("LOBBY", "READ", 10.0, w=1.6, h=2.3, kind="arch", name="ReadingRoom"),
        D("LOBBY", "OFFICE", 10.5, w=0.95, into="OFFICE", name="Office"),
        D("LOBBY", "RECORDS", 0.0, w=1.0, into="RECORDS", name="Records"),
        D("READ", "RECORDS", -7.0, w=1.0, into="RECORDS", name="ReadRecords"),
        D("RECORDS", "STORAGE", 17.0, w=1.0, into="STORAGE", name="Storage"),
        D("OFFICE", "STORAGE", 7.5, w=0.95, into="STORAGE", name="OfficeStorage"),
        DX("STORAGE", "B", 7.5, w=1.0, h=2.15, style="back", name="BackExit"),
    ],
    windows=[Wn("READ", "F", x, w=1.4, h=2.0, sill=0.9) for x in (-9.0, -5.0)] + [Wn("OFFICE", "F", x, w=1.4, h=2.0, sill=0.9) for x in (5.0, 9.0)] +
            [Wn("LOBBY", "F", x, w=0.7, h=2.0, sill=0.6, style="picture") for x in (-1.8, 1.8)] +
            [Wn("READ", "L", 10.0, w=1.4, h=2.0, sill=0.9), Wn("OFFICE", "R", 10.0, w=1.4, h=2.0, sill=0.9),
             Wn("RECORDS", "L", 17.0, w=1.0, h=1.0, sill=1.7), Wn("STORAGE", "R", 17.0, w=1.0, h=1.0, sill=1.7)],
    porches=[
        dict(rect=(-4.0, 4.6, 4.0, 7.0), deck_y=AY - 0.02, risers=5, steps=("z0", 0.0, 3.0), rails=(), skirt=True,
             columns=[(-3.75, 4.85), (-1.35, 4.85), (1.35, 4.85), (3.75, 4.85)], col_h=3.4, col_mat="Com_StorefrontConcrete",
             roof=("gable", (-4.3, 4.35, 4.3, 7.1), AY + 3.45, 26, "z", {"overhang": 0.25})),
        dict(rect=(6.5, 21.0, 8.5, 22.2), deck_y=AY - 0.02, steps=("x1", 21.6, 1.0), rails=("x0", "z1"), columns=[]),
    ],
    roofs=[("hip", (-11.1, 6.9, 11.1, 21.1), AY + 3.6 + 0.12, 22, {})],
    ext=dict(siding="Arch_BrickRed", trim="Arch_TrimPainted", roof="Arch_RoofShinglesDarkGray", door="Furn_WoodDark", foundation="Com_StorefrontConcrete"),
    extras=[_archive_extras],
    fit=[
        ("COM_ReceptionDesk", 0.0, 9.6, 180, "LOBBY", {}), ("RES_DeskChair_Office", 0.0, 10.6, 180, "LOBBY", {}),
        ("COM_NoticeBoard", -2.93, 9.0, 90, "LOBBY", {"y": 1.3, "fp": False}),
        ("COM_ReadingTable", -7.0, 8.6, 0, "READ", {}), ("COM_ReadingTable", -7.0, 11.8, 0, "READ", {}),
    ] + [("RES_DiningChair_Wood", -7.0 + dx, z + dz, yaw, "READ", {}) for z in (8.6, 11.8) for dx, dz, yaw in
         ((-0.7, -0.75, 0), (0.7, -0.75, 0), (-0.7, 0.75, 180), (0.7, 0.75, 180))] + [
    ] + [("COM_RecordsShelf", x, z, 0, "RECORDS", {}) for x in (-8.6, -5.6) for z in (15.4, 18.4)] + [
    ] + [("COM_RecordsShelf", -2.0, 18.4, 0, "RECORDS", {})] + [("COM_FilingCabinet", x, 20.55, 180, "RECORDS", {}) for x in (0.6, 1.2, 1.8, 2.4)] + [
        ("COM_ReadingTable", 1.5, 15.6, 0, "RECORDS", {}), ("RES_DiningChair_Wood", 1.0, 16.35, 180, "RECORDS", {}),
        ("COM_DocumentBoxes", -10.3, 14.0, 90, "RECORDS", {}),
        ("RES_Desk_Computer", 5.0, 12.64, 180, "OFFICE", {}), ("RES_DeskChair_Office", 5.0, 11.8, 180, "OFFICE", {}),
        ("RES_Desk", 9.0, 12.64, 180, "OFFICE", {}), ("RES_DeskChair_Office", 9.0, 11.8, 180, "OFFICE", {}),
        ("COM_FilingCabinet", 10.57, 8.2, -90, "OFFICE", {}), ("COM_FilingCabinet", 10.57, 8.7, -90, "OFFICE", {}),
        ("RES_Lamp_Table", 9.3, 12.64, 0, "OFFICE", {"y": 0.75, "fp": False})
    ] + [("RES_Shelving_Metal", x, 20.67, 180, "STORAGE", {}) for x in (4.75, 6.05, 9.0, 10.25)] + [
    ] + [("COM_DocumentBoxes", x, 15.0, 0, "STORAGE", {}) for x in (5.2, 6.2, 7.2)] + [
        ("COM_PalletStack", 9.8, 15.2, 90, "STORAGE", {}), ("RES_WallClock", -2.93, 11.6, 90, "LOBBY", {"y": 2.6, "fp": False}),
    ],
    dyn=[],
    nav=[("Walkway", -2.0, -0.3), ("Reception", 0.0, 8.4), ("ReadingRoom", -7.0, 10.2), ("Records_Stacks", -7.1, 16.9), ("Records_Files", 1.5, 19.6),
         ("Office", 7.0, 10.0), ("Storage", 7.5, 17.5)],
    interact_extra=[],
)


def _storefront_extras(h):
    parapets(h, {"*": h.p["parapet"]})
    zf = 0.3 - EXT_T / 2
    abox(h.ext, "enamel_white", (-h.p["width"] / 2 + 0.6, 3.75, zf - 0.08), (h.p["width"] / 2 - 0.6, 4.35, zf), skip=("+z",))   # blank sign band
    wall_lamp(h, -2.5, 3.2, zf, "-z")
    wall_lamp(h, 2.5, 3.2, zf, "-z")
    slab(h, "Road_SidewalkConcrete", [(-h.p["width"] / 2, -0.4), (h.p["width"] / 2, -0.4), (h.p["width"] / 2, 0.25), (-h.p["width"] / 2, 0.25)])


def storefront(name, W, D_, zone, siding, trim):
    hw = W / 2
    return dict(
        name=name, title="Main Street storefront (unassigned tenant)", width=W, levels={0: (FY, 3.3)}, zone=zone, parapet=4.6,
        rooms=[R("SHOP", 0, (-hw, 0.3, hw, D_ - 3.4), "sales", "Int_FloorboardsOld", "Int_WallpaperFaded", ceil=CEIL),
               R("BACK", 0, (-hw, D_ - 3.4, hw, D_ - 0.4), "storage", "Int_BasementConcrete", "Com_StorageConcrete", h=3.0, ceil="Com_StorageConcrete")],
        doors=[DX("SHOP", "F", -hw + 2.0, w=1.0, h=2.2, style="storefront", name="Entrance"),
               D("SHOP", "BACK", hw - 1.5, w=0.95, into="BACK", name="Back"),
               DX("BACK", "B", -hw + 2.0, w=1.0, h=2.15, style="back", name="BackExit")],
        windows=[Wn("SHOP", "F", x, w=min(3.6, W / 2 - 1.6), h=2.0, sill=0.5, style="picture") for x in (0.9, hw - 2.2) if x + min(3.6, W / 2 - 1.6) / 2 < hw - 0.3][:2],
        ext=dict(siding=siding, trim=trim, roof="Road_Asphalt", door=trim, foundation="Com_StorefrontConcrete"),
        extras=[_storefront_extras],
        fit=[("RES_Shelving_Metal", hw - 1.0, D_ - 0.735, 180, "BACK", {}),
             ("RES_CardboardBox_Stack", -hw + 3.6, D_ - 0.9, 0, "BACK", {}),
             ("COM_RetailCounter", hw - 2.0, D_ - 5.0, 180, "SHOP", {}),
             ("RES_Bookshelf_Tall", -hw + 0.3, 3.5, 90, "SHOP", {})],
        dyn=[], nav=[("Entrance", -hw + 2.0, -0.4), ("Shop", 0.0, (D_ - 3.4) / 2), ("Back", hw - 1.5, D_ - 1.9)], interact_extra=[],
    )


STOREFRONTS = [
    storefront("COM_Storefront_A", 12.0, 12.0, "STOREFRONT_A", "Com_StorefrontBrick", "Town_PaintGreen"),
    storefront("COM_Storefront_B", 19.0, 12.0, "STOREFRONT_B", "Arch_BrickWeatheredBrown", "Town_PaintNavy"),
    storefront("COM_Storefront_C", 22.0, 11.0, "STOREFRONT_C", "Com_StorefrontConcrete", "Town_PaintRed"),
    storefront("COM_Storefront_D", 21.0, 13.0, "STOREFRONT_D", "Com_StorefrontBrick", "Town_PaintYellow"),
]

PRIORITY = [("supermarket", SUPERMARKET, 1), ("video_game_store", GAME_SHOP, 1), ("gas_station", GAS_STATION, 2), ("pharmacy", PHARMACY, 2),
            ("municipal_archive", ARCHIVE, 3)] + [(p["zone"].lower(), p, 3) for p in STOREFRONTS]
