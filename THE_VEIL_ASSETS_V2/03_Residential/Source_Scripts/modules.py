"""Reusable residential building modules (Exterior_Modules, Interior_Modules, Interactive_Props).

Snapping conventions
  * Wall modules: run along +X from x=0 to x=L (1 / 2 / 3 m), centred on z=0
    (exterior: +Z face = outside), base at y=0, storey height 2.72 m
    (floor 0 -> ceiling 2.6 + 0.12 plate). Place them on a 0.5 m grid; the
    house floor sits 0.6 m above the lot on the foundation module.
  * Floor/ceiling tiles: 2 x 2 m, origin at the min corner, top at y=0.
  * Stairs: base at origin, climbing +Z, 0.95 m wide (x 0..0.95).
  * Doors/windows: origin at the opening's bottom-left on the wall centreline.
  * Moving parts are child nodes whose origin is the pivot + glTF `extras`.
"""
import math

import arch
from arch import EXT_T, INT_T, TRIM, DRYWALL, wall, casing, window_unit, door_node, slider_node, garage_door_node
from res_materials import m01, mt, mr
from veil_mesh.mesh import MB, T, Ry, Rx
from veil_mesh.gltf import COL_KEY

H_WALL = 2.72


def mspec(name, cat, mb, col=None, nodes=(), **meta):
    ch = [{"name": name + "_Mesh", "mb": mb}]
    if col is not None and col.tri_count():
        ch.append({"name": name + "_Col-colonly", "mb": col})
    ch += list(nodes)
    m = dict(kind="module", category=cat, **meta)
    if nodes:
        m["interactive_nodes"] = [n["name"] for n in nodes if n.get("extras")]
        m["interactables"] = {n["name"]: n["extras"] for n in nodes if n.get("extras")}
    return {"name": name, "children": ch, "meta": m}


SIDINGS = {"White": "Arch_SidingWhite", "Blue": "Arch_SidingBlue", "Green": "Arch_SidingGreen",
           "BrickRed": "Arch_BrickRed", "BrickBrown": "Arch_BrickWeatheredBrown", "Planks": "Arch_WoodPlanksAged"}


# ---------------------------------------------------------------- exterior walls
def ext_wall(name, L, siding, openings=(), kind=None):
    mb, col = MB(), MB()
    M, _ = wall(mb, col, (L, 0.0), (0.0, 0.0), 0.0, H_WALL, EXT_T, m01(siding), DRYWALL, [o[:4] for o in openings])
    # wall p0->p1 runs -X here so that +n (left) = +Z: outside face toward +Z
    nodes = []
    for (u0, u1, v0, v1, k) in openings:
        if k == "window":
            st, nd = window_unit(u1 - u0, v1 - v0, EXT_T, "double_hung", sash_node="INT_WindowSash")
            mb.merge(st, M @ T(u0, v0, 0))
            casing(mb, M, u0, u1, v0, v1, EXT_T / 2, 1)
            casing(mb, M, u0, u1, v0, v1, -EXT_T / 2, -1, head_cap=False)
            for n in nd:
                p = M @ [u0, v0 + n["t"][1], 0, 1]
                n["t"] = (float(p[0]), float(p[1]), float(p[2]))
                n["yaw"] = math.pi
                nodes.append(n)
        else:
            casing(mb, M, u0, u1, v0, v1, EXT_T / 2, 1, sill=False)
            casing(mb, M, u0, u1, v0, v1, -EXT_T / 2, -1, sill=False, head_cap=False)
            p = M @ [u0 + 0.01, 0, -EXT_T / 2 + 0.03, 1]
            nodes.append(door_node("INT_Door", (float(p[0]), 0.01, float(p[2])), math.pi, u1 - u0 - 0.02, v1 - v0 - 0.02,
                                   mt("PaintRed"), "front", -95.0))
    return mspec(name, "exterior_wall", mb, col, nodes, size=[L, H_WALL, EXT_T], snap="0.5 m grid, runs +X, outside face +Z")


def corner_board(name="RES_Ext_CornerBoard"):
    mb = MB()
    mb.box(TRIM, (-0.13, 0, -0.13), (0.13, H_WALL, 0.13), skip=("-y", "+y"))
    return mspec(name, "exterior_trim", mb, size=[0.26, H_WALL, 0.26], snap="outside corner at the origin")


def foundation(name="RES_Ext_Foundation_2m", L=2.0):
    mb, col = MB(), MB()
    pts = [[0, 0, EXT_T / 2 + 0.02], [L, 0, EXT_T / 2 + 0.02], [L, 0.58, EXT_T / 2 + 0.02], [0, 0.58, EXT_T / 2 + 0.02]]
    mb.quad(m01("Arch_ConcreteFoundation"), *pts, n=(0, 0, 1), uv=[(p[0], -p[1]) for p in pts])
    mb.box(mt("VentGrille"), (L / 2 - 0.2, 0.2, EXT_T / 2 + 0.02), (L / 2 + 0.2, 0.38, EXT_T / 2 + 0.032), skip=("-z",))
    col.box(COL_KEY, (0, 0, -EXT_T / 2), (L, 0.58, EXT_T / 2 + 0.02), skip=())
    return mspec(name, "foundation", mb, col, size=[L, 0.58, EXT_T + 0.02], snap="under a 2 m wall module; floor level 0.6")


def crawl_vent():
    mb = MB()
    mb.box(mt("VentGrille"), (-0.2, 0, 0), (0.2, 0.18, 0.012), skip=("-z",))
    mb.box(TRIM, (-0.23, -0.03, 0), (0.23, 0.21, 0.008), skip=("-z", "+z"))
    return mspec("RES_Ext_CrawlVent", "foundation", mb, size=[0.46, 0.24, 0.012])


# ---------------------------------------------------------------- roofs
def roof_gable(name, w=8.0, d=6.0, pitch=35, mat="Arch_RoofShinglesDarkGray", gable="Arch_SidingWhite"):
    mb, col = MB(), MB()
    arch.gable_roof(mb, col, (0, 0, w, d), 0.0, pitch, "x", mat=m01(mat), gable_mat=m01(gable))
    return mspec(name, "roof", mb, None, size=[w, d * 0.5 * math.tan(math.radians(pitch)), d],
                 snap="rect = outer wall faces (0,0)-(w,d); base y = top of the walls")


def roof_hip(name, w=8.0, d=6.0, pitch=25, mat="Arch_RoofShinglesBrown"):
    mb = MB()
    arch.hip_roof(mb, None, (0, 0, w, d), 0.0, pitch, mat=m01(mat))
    return mspec(name, "roof", mb, size=[w, d / 2 * math.tan(math.radians(pitch)), d])


def roof_shed(name="RES_Ext_Roof_Shed_3x1.5"):
    mb = MB()
    arch.shed_roof(mb, None, (0, 0, 3.0, 1.5), 0.0, 0.3, "z1", mat=m01("Arch_RoofShinglesDarkGray"))
    return mspec(name, "roof", mb, size=[3.0, 0.3, 1.5], snap="porch roof: high edge (z=1.5) against the house wall")


def fascia_gutter(name="RES_Ext_FasciaGutter_2m"):
    mb = MB()
    mb.box(TRIM, (0, -0.14, -0.02), (2.0, 0.0, 0.0), skip=())
    mb.box(mt("PaintWhite"), (0, -0.24, 0.0), (2.0, -0.12, 0.12), skip=())
    mb.box(mt("PaintWhite"), (1.85, -2.9, 0.03), (1.91, -0.24, 0.09), skip=())
    return mspec(name, "roof_trim", mb, size=[2.0, 2.9, 0.12], snap="hangs from the eave line (origin)")


# ---------------------------------------------------------------- openings (frame + moving part)
def window_module(name, w, h, style="double_hung"):
    mb = MB()
    st, nodes = window_unit(w, h, EXT_T, style, sash_node="INT_WindowSash" if style == "double_hung" else None)
    mb.merge(st)
    M = T(0, 0, 0)
    casing(mb, M, 0, w, 0, h, EXT_T / 2, 1)
    casing(mb, M, 0, w, 0, h, -EXT_T / 2, -1, head_cap=False)
    return mspec(name, "window", mb, None, nodes, size=[w, h, EXT_T], snap="origin = opening bottom-left on the wall centreline")


def shutters_pair():
    mb = MB()
    arch.shutters(mb, T(0, 0, 0), 0, 1.1, 0, 1.3, 0.13)
    return mspec("RES_Ext_Shutters_Pair", "window", mb, size=[2.04, 1.3, 0.03], snap="fits a 1.1 x 1.3 window opening")


def door_module(name, style, w=1.0, h=2.15, paint="Town_PaintRed"):
    mb = MB()
    M = T(0, 0, 0)
    casing(mb, M, 0, w, 0, h, EXT_T / 2, 1, sill=False)
    casing(mb, M, 0, w, 0, h, -EXT_T / 2, -1, sill=False, head_cap=False)
    mb.box(m01("Furn_WoodDark"), (0, -0.002, -EXT_T / 2), (w, 0.012, EXT_T / 2), skip=("-y",))
    for (u0, u1) in ((-0.0, 0.0),):
        pass
    pm = mt(paint[5:]) if paint.startswith("Town_") else m01(paint)
    nd = door_node("INT_Door", (0.01, 0.01, -EXT_T / 2 + 0.03), 0.0, w - 0.02, h - 0.02, pm, style, 95.0)
    return mspec(name, "door", mb, None, [nd], size=[w, h, EXT_T], snap="origin = opening bottom-left; leaf swings inward (-Z)")


def garage_module():
    """Complete attached single garage: 4 x 6 m, gable roof, sectional door, side door."""
    plan = dict(name="RES_Ext_Garage_Attached_4x6", levels={0: (0.02, 2.9)}, garage_x=2.0,
                rooms=[dict(id="GAR", lvl=0, rect=(0.0, 0.0, 4.0, 6.0), type="garage", floor="Int_BasementConcrete",
                            wall="Com_StorageConcrete", y=0.02, h=2.9)],
                doors=[dict(room="GAR", side="F", at=2.0, w=2.8, h=2.2, kind="garage", style="front", into="GAR", name="Garage"),
                       dict(room="GAR", side="R", at=4.5, w=0.9, h=2.05, kind="door", style="back", into="GAR", name="Side")],
                windows=[dict(room="GAR", side="L", at=3.0, w=0.8, h=0.6, sill=1.45, kind="window", style="double_hung")],
                roofs=[("gable", (-0.1, -0.1, 4.1, 6.1), 3.04, 28, "z", {})],
                ext=dict(siding="Arch_SidingWhite", trim="Arch_TrimPainted", roof="Arch_RoofShinglesDarkGray"))
    import house
    h = house.House(plan).build()
    sp = h.spec(plan["name"])
    sp["meta"] = dict(kind="module", category="garage", size=[4.0, 4.1, 6.0], snap="footprint (0,0)-(4,6); door faces -Z",
                      interactive_nodes=[n["name"] for n in h.nodes])
    return sp


def porch_deck(name="RES_Ext_PorchDeck_3x1.6"):
    mb, col = MB(), MB()
    arch.porch(mb, col, (0, 0, 3.0, 1.6), 0.58, steps=("z0", 1.5, 1.2), rails=("x0", "x1", "z0"), risers=3,
               columns=[(0.1, 0.1), (2.9, 0.1)], deck_mat=m01("Arch_WoodPlanksAged"))
    return mspec(name, "porch", mb, col, size=[3.0, 3.0, 2.5], snap="deck (0,0)-(3,1.6), house wall at z=1.6, steps toward -Z")


def porch_column():
    mb, col = MB(), MB()
    mb.box(TRIM, (-0.11, 0, -0.11), (0.11, 0.25, 0.11), skip=("-y",))
    mb.box(TRIM, (-0.07, 0.25, -0.07), (0.07, 2.35, 0.07), skip=("-y", "+y"))
    mb.box(TRIM, (-0.1, 2.35, -0.1), (0.1, 2.45, 0.1), skip=())
    col.box(COL_KEY, (-0.11, 0, -0.11), (0.11, 2.45, 0.11), skip=())
    return mspec("RES_Ext_PorchColumn", "porch", mb, col, size=[0.22, 2.45, 0.22])


def porch_railing():
    mb, col = MB(), MB()
    arch.railing(mb, col, (0, 0), (2.0, 0), 0.0, 0.9, TRIM, TRIM)
    return mspec("RES_Ext_PorchRailing_2m", "porch", mb, col, size=[2.0, 0.9, 0.06])


def porch_steps():
    mb, col = MB(), MB()
    for k in range(3):
        mb.box(m01("Arch_WoodPlanksAged"), (0, 0, -(k + 1) * 0.3), (1.2, 0.58 - k * 0.193, -k * 0.3), skip=("-y",))
    col.quad(COL_KEY, [0, 0, -1.0], [1.2, 0, -1.0], [1.2, 0.58, 0], [0, 0.58, 0], n=(0, 1, 0))
    return mspec("RES_Ext_PorchSteps_3Riser", "porch", mb, col, size=[1.2, 0.58, 0.9], snap="top edge at z=0 (deck edge), descends toward -Z")


def lattice_panel():
    mb = MB()
    pts = [[0, 0, 0], [2.0, 0, 0], [2.0, 0.4, 0], [0, 0.4, 0]]
    mb.quad(mr("Lattice"), *pts, n=(0, 0, 1), uv=[(p[0], -p[1]) for p in pts])
    return mspec("RES_Ext_LatticeSkirt_2m", "porch", mb, size=[2.0, 0.4, 0.0])


def chimney_module():
    mb, col = MB(), MB()
    arch.chimney(mb, col, 0, 0, 0.6, 0.9, 7.5)
    return mspec("RES_Ext_Chimney_Brick", "exterior_detail", mb, col, size=[0.72, 7.6, 1.02])


def small_fixture(name, kind):
    mb = MB()
    if kind == "mailslot":
        mb.box(m01("Furn_MetalBrushed"), (-0.15, -0.04, 0), (0.15, 0.04, 0.012), skip=("-z",))
        mb.box(m01("Road_RoadPatch"), (-0.12, -0.012, 0.012), (0.12, 0.012, 0.013), skip=("-z",))
    elif kind == "porchlight":
        mb.box(mt("PaintBlack"), (-0.08, -0.12, 0), (0.08, 0.12, 0.03))
        mb.box(mr("BulbGlow"), (-0.07, -0.1, 0.03), (0.07, 0.08, 0.17), skip=())
        mb.box(mt("PaintBlack"), (-0.09, 0.08, 0.02), (0.09, 0.12, 0.19))
    elif kind == "hosebib":
        mb.cyl(m01("Furn_MetalBrushed"), (0, 0, 0.0), 0.02, 0.02, seg=6, caps=("top",))
        t = MB()
        t.cyl(m01("Furn_MetalBrushed"), (0, 0, 0), 0.015, 0.1, seg=6, caps=("top",))
        mb.merge(t, Rx(math.pi / 2))
        mb.cyl(mt("PaintRed"), (0, 0.03, 0.08), 0.03, 0.01, seg=6, caps=("top",))
    elif kind == "gasmeter":
        mb.box(m01("Com_SignageBacking"), (-0.16, -0.2, 0), (0.16, 0.15, 0.2))
        mb.cyl(m01("Arch_WindowGlassDirty"), (0, 0.15, 0.1), 0.06, 0.01, seg=8, caps=("top",))
        mb.tube(mt("PaintYellow"), [(0, -0.2, 0.1), (0, -0.6, 0.1), (0, -0.6, 0.0)], 0.02, 4)
    elif kind == "electricmeter":
        mb.box(m01("Com_SignageBacking"), (-0.13, -0.18, 0), (0.13, 0.18, 0.1))
        mb.cyl(m01("Arch_WindowGlassDirty"), (0, 0.02, 0.1), 0.09, 0.08, seg=10, caps=("top",))
        mb.tube(m01("Furn_MetalBrushed"), [(0, 0.18, 0.05), (0, 1.5, 0.05)], 0.02, 4)
    elif kind == "dryervent":
        mb.box(m01("Furn_PlasticDirty"), (-0.08, -0.08, 0), (0.08, 0.08, 0.06))
        mb.box(m01("Furn_PlasticDirty"), (-0.08, -0.08, 0.06), (0.08, 0.0, 0.1), skip=("-z",))
    elif kind == "housenumber":
        mb.box(m01("Furn_WoodDark"), (-0.18, -0.08, 0), (0.18, 0.08, 0.02), skip=("-z",))
        for k in range(3):
            mb.box(m01("Furn_MetalBrushed"), (-0.14 + k * 0.1, -0.05, 0.02), (-0.08 + k * 0.1, 0.05, 0.026), skip=("-z",))
    nodes = [{"name": "LightPoint", "t": (0, 0, 0.12)}] if kind == "porchlight" else []
    return mspec(name, "exterior_detail", mb, None, nodes, size=list(map(float, mb.bounds()[1] - mb.bounds()[0])),
                 snap="wall-mounted: origin on the wall face, faces +Z")


def slab(name, w, d, mat="Road_SidewalkConcrete"):
    mb = MB()
    mb.ground_poly(m01(mat), [(-w / 2, 0), (w / 2, 0), (w / 2, d), (-w / 2, d)], y=0.006)
    return mspec(name, "lot_connection", mb, size=[w, 0.006, d], snap="lot level (y=0), starts at z=0 and runs +Z")


# ---------------------------------------------------------------- interior
INT_FINISHES = {"Drywall": "Int_DrywallLight", "WallpaperFaded": "Int_WallpaperFaded", "WallpaperPatterned": "Int_WallpaperPatterned",
                "TilesBathroom": "Int_TilesBathroom", "WoodPanel": "Res_WoodPanel", "PlasterDamaged": "Int_PlasterDamaged",
                "Concrete": "Com_StorageConcrete"}
FLOORS = {"Carpet": "Int_CarpetWorn", "Floorboards": "Int_FloorboardsOld", "Linoleum": "Int_Linoleum",
          "KitchenTiles": "Int_TilesKitchen", "Concrete": "Int_BasementConcrete", "Darkened": "Hor_WoodDarkened"}


def _mat(n):
    return mr(n[4:]) if n.startswith("Res_") else m01(n)


def int_wall(name, L, finish, doorway=False):
    mb, col = MB(), MB()
    ops = [(L / 2 - 0.45, L / 2 + 0.45, 0.0, 2.1)] if doorway else []
    M, _ = wall(mb, col, (L, 0.0), (0.0, 0.0), 0.0, 2.6, INT_T, _mat(finish), _mat(finish), ops)
    if doorway:
        for (sz, nz) in ((INT_T / 2, 1), (-INT_T / 2, -1)):
            casing(mb, M, L / 2 - 0.45, L / 2 + 0.45, 0.0, 2.1, sz, nz, sill=False, head_cap=False)
    return mspec(name, "interior_wall", mb, col, size=[L, 2.6, INT_T], snap="runs +X from origin, 0.12 m thick, 2.6 m high")


def doorframe():
    mb = MB()
    M = T(0, 0, 0)
    for (sz, nz) in ((INT_T / 2, 1), (-INT_T / 2, -1)):
        casing(mb, M, 0, 0.9, 0, 2.1, sz, nz, sill=False, head_cap=False)
    mb.box(m01("Furn_WoodDark"), (0, -0.002, -INT_T / 2), (0.9, 0.012, INT_T / 2), skip=("-y",))
    return mspec("RES_Int_Doorframe_0.9", "interior_wall", mb, size=[1.08, 2.19, INT_T + 0.05])


def floor_tile(name, mat):
    mb, col = MB(), MB()
    mb.ground_poly(_mat(mat), [(0, 0), (2, 0), (2, 2), (0, 2)], y=0.0)
    col.ground_poly(COL_KEY, [(0, 0), (2, 0), (2, 2), (0, 2)], y=0.0)
    return mspec(name, "floor", mb, col, size=[2.0, 0.0, 2.0], snap="2 x 2 m, origin at the min corner, top y=0")


def ceiling_tile():
    mb = MB()
    pts = [[0, 0, 0], [0, 0, 2], [2, 0, 2], [2, 0, 0]]
    mb.quad(m01("Int_DrywallLight"), *pts, n=(0, -1, 0), uv=[(p[0], p[2]) for p in pts])
    return mspec("RES_Int_Ceiling_2x2", "ceiling", mb, size=[2.0, 0.0, 2.0], snap="faces down; place at floor + 2.6")


def stair_module(name, rise_total, n=None, tread=0.27, open_side="r"):
    mb, col = MB(), MB()
    n = n or int(round(rise_total / 0.18))
    arch.stair(mb, col, (0, 0, 0), 0.0, 0.95, n, rise_total / n, tread, open_sides=(open_side,))
    return mspec(name, "stair", mb, col, size=[0.95, rise_total, n * tread],
                 snap=f"base at origin, climbs +Z: {n} risers x {rise_total / n:.3f} m, run {n * tread:.2f} m; collision = walkable ramp")


def stair_rail():
    mb, col = MB(), MB()
    arch.railing(mb, col, (0, 0), (2.0, 0), 0.0)
    return mspec("RES_Int_StairwellRailing_2m", "stair", mb, col, size=[2.0, 0.95, 0.06])


def attic_floor():
    mb, col = MB(), MB()
    mb.ground_poly(mr("Insulation"), [(0, 0), (2, 0), (2, 2), (0, 2)], y=0.0)
    mb.box(m01("Arch_WoodPlanksAged"), (0.7, 0.0, 0.0), (1.3, 0.03, 2.0), skip=("-y",))   # walk boards
    col.ground_poly(COL_KEY, [(0, 0), (2, 0), (2, 2), (0, 2)], y=0.0)
    return mspec("RES_Int_AtticFloor_2x2", "attic", mb, col, size=[2.0, 0.03, 2.0])


def attic_hatch():
    mb = MB()
    mb.box(TRIM, (-0.4, -0.03, -0.35), (0.4, 0.0, -0.3), skip=())
    mb.box(TRIM, (-0.4, -0.03, 0.3), (0.4, 0.0, 0.35), skip=())
    mb.box(TRIM, (-0.4, -0.03, -0.3), (-0.35, 0.0, 0.3), skip=())
    mb.box(TRIM, (0.35, -0.03, -0.3), (0.4, 0.0, 0.3), skip=())
    panel = MB()
    panel.box(m01("Int_DrywallLight"), (0, -0.03, 0), (0.7, 0.0, 0.6), skip=())
    panel.cyl(m01("Furn_MetalBrushed"), (0.6, -0.06, 0.3), 0.01, 0.03, seg=4, caps=("bottom",))
    return mspec("RES_Int_AtticHatch", "attic", mb, None,
                 [{"name": "INT_Hatch", "t": (-0.35, 0.0, -0.3), "mb": panel, "extras": {"veil_interact": "hinge", "axis": "z", "open_deg": -90}}],
                 size=[0.8, 0.03, 0.7], snap="ceiling-mounted, origin at the ceiling plane")


# ---------------------------------------------------------------- interactive props
def ip_door(name, style, w, h, paint):
    return mspec(name, "interactive", MB(), None, [door_node("INT_Door", (0, 0, 0), 0.0, w, h, paint, style, 95.0)],
                 size=[w, h, 0.045], snap="hinge line at the origin; leaf along +X")


def ip_slider(name, w, h, glass):
    return mspec(name, "interactive", MB(), None, [slider_node("INT_SlidingDoor", (0, 0, 0), 0.0, w, h, m01("Furn_WoodPainted"), w * 0.9, glass)],
                 size=[w, h, 0.05], snap="slides along +X")


def ip_garage():
    return mspec("RES_IP_GarageDoor_Sectional", "interactive", MB(), None, [garage_door_node("INT_GarageDoor", (0, 0, 0), 0.0, 2.8, 2.2)],
                 size=[2.8, 2.2, 0.04], snap="origin bottom-left, raises along +Y")


def ip_window():
    st, nodes = window_unit(1.1, 1.3, EXT_T, "double_hung", sash_node="INT_WindowSash")
    return mspec("RES_IP_Window_DoubleHung", "interactive", st, None, nodes, size=[1.1, 1.3, EXT_T])


def ip_switch():
    import house
    mb = MB()
    mb.box(mr("DetailAtlas"), (-0.04, -0.06, 0), (0.04, 0.06, 0.012), skip=("-z",), uvrect={"+z": house._drect("light_switch")})
    tog = MB()
    tog.box(m01("Furn_PlasticDirty"), (-0.008, -0.02, 0), (0.008, 0.02, 0.02), skip=("-z",))
    return mspec("RES_IP_LightSwitch", "interactive", mb, None,
                 [{"name": "INT_Toggle", "t": (0, 0, 0.012), "mb": tog, "extras": {"veil_interact": "toggle", "axis": "x", "open_deg": 25}}],
                 size=[0.08, 0.12, 0.032], snap="wall-mounted at 1.2 m")


def ip_from_furniture(name, fn):
    m = fn()
    m["name"] = name
    for ch in m["children"]:
        if ch["name"].startswith(fn().get("name", "")):
            ch["name"] = ch["name"].replace(fn()["name"], name)
    m["meta"]["category"] = "interactive"
    return m


def all_modules():
    import furniture as F
    ext = []
    for k, sid in SIDINGS.items():
        ext.append(lambda k=k, sid=sid: ext_wall(f"RES_Ext_Wall_2m_{k}", 2.0, sid))
    ext += [lambda: ext_wall("RES_Ext_Wall_1m_White", 1.0, "Arch_SidingWhite"),
            lambda: ext_wall("RES_Ext_Wall_3m_White", 3.0, "Arch_SidingWhite"),
            lambda: ext_wall("RES_Ext_Wall_2m_Window_White", 2.0, "Arch_SidingWhite", [(0.45, 1.55, 0.85, 2.15, "window")]),
            lambda: ext_wall("RES_Ext_Wall_2m_Window_BrickRed", 2.0, "Arch_BrickRed", [(0.45, 1.55, 0.85, 2.15, "window")]),
            lambda: ext_wall("RES_Ext_Wall_2m_Door_White", 2.0, "Arch_SidingWhite", [(0.5, 1.5, 0.0, 2.15, "door")]),
            corner_board, lambda: foundation(), crawl_vent,
            lambda: roof_gable("RES_Ext_Roof_Gable_8x6"), lambda: roof_gable("RES_Ext_Roof_Gable_Steep_6x6", 6.0, 6.0, 48, "Furn_MetalRusted"),
            lambda: roof_hip("RES_Ext_Roof_Hip_8x6"), roof_shed, fascia_gutter,
            lambda: window_module("RES_Ext_Window_DoubleHung_1.1x1.3", 1.1, 1.3),
            lambda: window_module("RES_Ext_Window_Picture_1.6x1.4", 1.6, 1.4, "picture"),
            lambda: window_module("RES_Ext_Window_Small_0.6x0.7", 0.6, 0.7),
            lambda: window_module("RES_Ext_Window_Boarded_1.0x1.3", 1.0, 1.3, "boarded"), shutters_pair,
            lambda: door_module("RES_Ext_Door_Front_Red", "front"), lambda: door_module("RES_Ext_Door_Front_Green", "front", paint="Town_PaintGreen"),
            lambda: door_module("RES_Ext_Door_Back_HalfGlass", "back", 0.9, 2.1, "Furn_WoodPainted"),
            garage_module, porch_deck, porch_column, porch_railing, porch_steps, lattice_panel, chimney_module,
            lambda: small_fixture("RES_Ext_MailSlot", "mailslot"), lambda: small_fixture("RES_Ext_PorchLight", "porchlight"),
            lambda: small_fixture("RES_Ext_HoseBib", "hosebib"), lambda: small_fixture("RES_Ext_GasMeter", "gasmeter"),
            lambda: small_fixture("RES_Ext_ElectricMeter", "electricmeter"), lambda: small_fixture("RES_Ext_DryerVent", "dryervent"),
            lambda: small_fixture("RES_Ext_HouseNumber", "housenumber"),
            lambda: slab("RES_Ext_Walkway_1x2", 1.0, 2.0), lambda: slab("RES_Ext_DrivewayExtension_3x3", 3.0, 3.0)]
    inn = []
    for k, f in INT_FINISHES.items():
        inn.append(lambda k=k, f=f: int_wall(f"RES_Int_Wall_2m_{k}", 2.0, f))
    inn += [lambda: int_wall("RES_Int_Wall_2m_Doorway_Drywall", 2.0, "Int_DrywallLight", True),
            lambda: int_wall("RES_Int_Wall_1m_Drywall", 1.0, "Int_DrywallLight"), doorframe]
    for k, f in FLOORS.items():
        inn.append(lambda k=k, f=f: floor_tile(f"RES_Int_Floor_2x2_{k}", f))
    inn += [ceiling_tile, lambda: stair_module("RES_Int_Stair_Storey_3.0m", 3.0),
            lambda: stair_module("RES_Int_Stair_Basement_2.7m", 2.7),
            lambda: stair_module("RES_Int_Stair_Attic_Steep", 2.55, n=12, tread=0.24), stair_rail, attic_floor, attic_hatch]
    ip = [lambda: ip_door("RES_IP_Door_Interior", "interior", 0.93, 2.08, m01("Arch_TrimPainted")),
          lambda: ip_door("RES_IP_Door_Front", "front", 0.98, 2.13, mt("PaintRed")),
          lambda: ip_door("RES_IP_Door_Back", "back", 0.88, 2.08, m01("Furn_WoodPainted")),
          lambda: ip_slider("RES_IP_Door_Sliding_Patio", 1.0, 2.1, True), lambda: ip_slider("RES_IP_Door_Sliding_Closet", 0.8, 2.05, False),
          ip_garage, ip_window, ip_switch,
          lambda: ip_from_furniture("RES_IP_CabinetDoorUnit", lambda: F.wall_cabinet("RES_IP_CabinetDoorUnit", 0.8)),
          lambda: ip_from_furniture("RES_IP_DrawerUnit", F.nightstand),
          lambda: ip_from_furniture("RES_IP_StorageChest", F.storage_chest),
          lambda: ip_from_furniture("RES_IP_StorageBin", lambda: F.storage_bin("RES_IP_StorageBin"))]
    return [("Exterior_Modules", f) for f in ext] + [("Interior_Modules", f) for f in inn] + [("Interactive_Props", f) for f in ip]
