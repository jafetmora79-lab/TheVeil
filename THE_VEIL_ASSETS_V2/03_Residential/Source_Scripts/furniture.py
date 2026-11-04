"""Residential furniture & props (Pack 03).

Convention: origin on the floor at the centre of the footprint, the usable
front faces +Z, footprint x in [-w/2, w/2], z in [-d/2, d/2]. Wall-mounted
pieces have their back on z = -d/2 and a `mount_y` hint. Moving parts are
child nodes whose origin is the pivot (see arch.py docstring for extras).
"""
import math
import zlib

import numpy as np

import res_materials  # noqa: F401
from res_materials import m01, mt, mr
from veil_mesh.mesh import MB, T, Ry, Rx, Rz, S, nrm
from veil_mesh.gltf import COL_KEY
from res_textures import DETAIL_RECTS


class _FurnMB(MB):
    """Mesh builder for furniture: MB.box omits the bottom face by default (right for things standing on the
    floor), but raised parts - table tops, shelves, seats, drawer boxes - must keep their underside or they are
    see-through from below. Boxes whose bottom is more than 3 cm above the model's floor keep it."""

    def box(self, mat, mn, mx, skip=("-y",), **kw):
        if "-y" in skip and mn[1] > 0.03:
            skip = tuple(f for f in skip if f != "-y")
        return super().box(mat, mn, mx, skip=skip, **kw)


MB = _FurnMB  # noqa: F811

WOOD_L, WOOD_D, WOOD_P = m01("Furn_WoodLight"), m01("Furn_WoodDark"), m01("Furn_WoodPainted")
METAL, PLASTIC, RUBBER = m01("Furn_MetalBrushed"), m01("Furn_PlasticDirty"), m01("Furn_Rubber")
TWEED, LEATHER, DENIM = m01("Furn_FabricUpholstery"), m01("Furn_LeatherWorn"), m01("Furn_Denim")
CARD = m01("Furn_Cardboard")
WHITE = mt("PaintWhite")
PORC = mr("Porcelain")
DET, DETG = mr("DetailAtlas"), mr("DetailAtlasGlow")
TRIM = m01("Arch_TrimPainted")


def drect(k):
    x, y, w, h = DETAIL_RECTS[k]
    return (x / 256, y / 256, (x + w) / 256, (y + h) / 256)


def rng_of(s):
    return np.random.default_rng(zlib.crc32(s.encode()))


def fmodel(name, cat, mb, size, cols=(), nodes=(), **meta):
    """size = (w, d, h). cols: list of (mn, mx) boxes -> one convex hull node each."""
    children = [{"name": name + "_Mesh", "mb": mb}]
    for i, (mn, mx) in enumerate(cols):
        c = MB()
        c.box(COL_KEY, mn, mx, skip=())
        children.append({"name": f"{name}_Col{i if len(cols) > 1 else ''}-convcolonly", "mb": c})
    children += list(nodes)
    m = dict(kind="furniture", category=cat, size=list(size), **meta)
    if nodes:
        m["interactive_nodes"] = [n["name"] for n in nodes]
        m["interactables"] = {n["name"]: n.get("extras", {}) for n in nodes}
    return {"name": name, "children": children, "meta": m}


def rbox(mb, mat, mn, mx, r=0.04, axis="x", seg=2):
    """Rounded-profile box (cushions, mattresses): rounded rect profile in the
    plane perpendicular to `axis`, extruded along `axis`."""
    (x0, y0, z0), (x1, y1, z1) = mn, mx
    if axis == "x":
        a0, a1, p = x0, x1, (z0, y0, z1, y1)
    else:
        a0, a1, p = z0, z1, (x0, y0, x1, y1)
    u0, v0, u1, v1 = p
    r = min(r, (u1 - u0) / 2.01, (v1 - v0) / 2.01)
    pts = []
    for (cu, cv, a_start) in ((u1 - r, v0 + r, -math.pi / 2), (u1 - r, v1 - r, 0), (u0 + r, v1 - r, math.pi / 2),
                              (u0 + r, v0 + r, math.pi)):
        for k in range(seg + 1):
            a = a_start + (math.pi / 2) * k / seg
            pts.append((cu + r * math.cos(a), cv + r * math.sin(a)))
    loc = MB()
    loc.prism(mat, pts, a0, a1)
    if axis == "x":
        # prism outline is (u, v) = (z, y) extruded along local z -> rotate so extrusion runs along X
        M = np.array([[0, 0, 1, 0], [0, 1, 0, 0], [1, 0, 0, 0], [0, 0, 0, 1.0]])
    else:
        M = np.eye(4)
    mb.merge(loc, M)


def hollow(mb, mat, mn, mx, skip=(), t=0.018):
    """Container box (carcass, drawer, appliance body, crate) with a real inside.
    skip = the open face ("+z" front / "+y" top). Instead of leaving a see-through hole (the old single-face skip
    showed the background wherever a door or drawer front did not cover the opening, and every open drawer or
    cabinet was empty), this builds: the outer shell without the open face, inward-facing inner walls inset by the
    panel thickness t (same material, so insides are textured), and a rim joining the two on the open face.
    Panels thinner than 2.5 t, or boxes with no single open face, are simply closed."""
    skip = tuple(skip)
    x0, y0, z0 = mn
    x1, y1, z1 = mx
    open_ = skip[0] if len(skip) == 1 and skip[0] in ("+z", "+y") else None
    dims = (x1 - x0, y1 - y0, z1 - z0)
    if open_ is None or min(dims) < 2.5 * t:
        mb.box(mat, mn, mx, skip=tuple(f for f in skip if f not in ("+z", "+y")))
        return
    mb.box(mat, mn, mx, skip=(open_,))
    ix0, iy0, iz0, ix1, iy1, iz1 = x0 + t, y0 + t, z0 + t, x1 - t, y1 - t, z1 - t
    if open_ == "+z":
        iz1 = z1
    else:
        iy1 = y1
    # inner walls (normals point into the cavity)
    inner = {
        "-x": ([ix0, iy0, iz0], [ix0, iy1, iz0], [ix0, iy1, iz1], [ix0, iy0, iz1], (1, 0, 0)),
        "+x": ([ix1, iy0, iz0], [ix1, iy0, iz1], [ix1, iy1, iz1], [ix1, iy1, iz0], (-1, 0, 0)),
        "-y": ([ix0, iy0, iz0], [ix0, iy0, iz1], [ix1, iy0, iz1], [ix1, iy0, iz0], (0, 1, 0)),
        "+y": ([ix0, iy1, iz0], [ix1, iy1, iz0], [ix1, iy1, iz1], [ix0, iy1, iz1], (0, -1, 0)),
        "-z": ([ix0, iy0, iz0], [ix1, iy0, iz0], [ix1, iy1, iz0], [ix0, iy1, iz0], (0, 0, 1)),
        "+z": ([ix0, iy0, iz1], [ix0, iy1, iz1], [ix1, iy1, iz1], [ix1, iy0, iz1], (0, 0, -1)),
    }
    for k, (a, b, c, d, n) in inner.items():
        if k != open_:
            mb.quad(mat, a, b, c, d, n=n)
    # rim on the open face (frame between the outer edge and the opening)
    if open_ == "+z":
        z = z1
        rims = [((x0, y0), (x1, iy0)), ((x0, iy1), (x1, y1)), ((x0, iy0), (ix0, iy1)), ((ix1, iy0), (x1, iy1))]
        for (a0, b0), (a1, b1) in rims:
            mb.quad(mat, [a0, b0, z], [a1, b0, z], [a1, b1, z], [a0, b1, z], n=(0, 0, 1))
    else:
        y = y1
        rims = [((x0, z0), (x1, iz0)), ((x0, iz1), (x1, z1)), ((x0, iz0), (ix0, iz1)), ((ix1, iz0), (x1, iz1))]
        for (a0, b0), (a1, b1) in rims:
            mb.quad(mat, [a0, y, b0], [a0, y, b1], [a1, y, b1], [a1, y, b0], n=(0, 1, 0))


def legs(mb, mat, w, d, h, inset=0.05, r=0.025, seg=5, taper=0.7):
    for sx in (-1, 1):
        for sz in (-1, 1):
            mb.cyl(mat, (sx * (w / 2 - inset), 0, sz * (d / 2 - inset)), r, h, seg=seg, r_top=r / taper if taper else r,
                   caps=("top",))


def face_quad(mb, mat, rect_uv, x0, y0, x1, y1, z, nz=1):
    u0, v0, u1, v1 = rect_uv
    pts = [[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]]
    uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
    if nz < 0:
        pts = [[x1, y0, z], [x0, y0, z], [x0, y1, z], [x1, y1, z]]
    mb.quad(mat, *pts, n=(0, 0, nz), uv=uv)


def face_frame(mb, mat, z_front, rails, stiles=()):
    """Carcass joinery behind the fronts, clear of the 20 mm hinge sweep."""
    for x0, y0, x1, y1 in (*rails, *stiles):
        mb.box(mat, (x0, y0, z_front - 0.039), (x1, y1, z_front - 0.021), skip=())


def drawer(name, x0, y0, x1, y1, z_front, depth, mat, handle=METAL, *, face_left=0.0):
    """Drawer node: pivot at its closed front-bottom-centre, slides +Z."""
    mb = MB()
    w, h = x1 - x0, y1 - y0
    mb.box(mat, (-w / 2 + face_left, 0, -0.02), (w / 2, h, 0.0), skip=())                 # front panel
    hollow(mb, mat, (-w / 2 + 0.02, 0.01, -depth), (w / 2 - 0.02, h * 0.75, -0.02), skip=("+y",))   # box
    mb.box(handle, (-0.06, h / 2 - 0.012, 0.0), (0.06, h / 2 + 0.012, 0.025), skip=())
    return {"name": name, "t": ((x0 + x1) / 2, y0, z_front), "mb": mb,
            "extras": {"veil_interact": "slide", "axis": "z", "distance": depth * 0.75}}


def cab_door(name, hinge_x, y0, w, h, z_front, mat, side="l", handle=METAL, axis="y"):
    """Cabinet door node: pivot on the hinge edge; leaf extends +X (left hinge) or -X."""
    mb = MB()
    sx = 1 if side == "l" else -1
    xa, xb = sorted((0, sx * w))
    mb.box(mat, (xa, 0, -0.02), (xb, h, 0.0), skip=())
    mb.box(mat, (xa + 0.04, 0.04, 0.0), (xb - 0.04, h - 0.04, 0.008), skip=("-z",))
    hx = sx * (w - 0.05)
    mb.box(handle, (hx - 0.012, h * 0.45, 0.0), (hx + 0.012, h * 0.65, 0.03), skip=())
    return {"name": name, "t": (hinge_x, y0, z_front), "mb": mb,
            "extras": {"veil_interact": "hinge", "axis": axis, "open_deg": -100 * sx if axis == "y" else -85}}


# ============================================================================
# LIVING ROOM
# ============================================================================
def sofa(name="RES_Sofa_Plaid", fabric=None, w=2.0, seats=3, feet=WOOD_D):
    fabric = fabric or mr("FabricPlaid")
    mb = MB()
    d, h = 0.9, 0.85
    legs(mb, feet, w - 0.1, d - 0.1, 0.1, r=0.03, taper=1.2)
    rbox(mb, fabric, (-w / 2 + 0.01, 0.1, -d / 2), (w / 2 - 0.01, 0.42, d / 2 - 0.02), r=0.06)    # base (inside the arms)
    rbox(mb, fabric, (-w / 2 + 0.05, 0.42, -d / 2), (w / 2 - 0.05, h, -d / 2 + 0.22), r=0.08)     # back frame
    for sx in (-1, 1):                                                                           # rolled arms
        rbox(mb, fabric, (sx * w / 2 - (0.2 if sx > 0 else 0), 0.1, -d / 2), (sx * w / 2 + (0.0 if sx > 0 else 0.2), 0.66, d / 2),
             r=0.09, axis="z")
    cw = (w - 0.44) / seats
    for k in range(seats):
        x0 = -w / 2 + 0.22 + k * cw
        rbox(mb, fabric, (x0 + 0.01, 0.42, -d / 2 + 0.2), (x0 + cw - 0.01, 0.56, d / 2 - 0.03), r=0.05)   # seat cushion
        rbox(mb, fabric, (x0 + 0.02, 0.5, -d / 2 + 0.16), (x0 + cw - 0.02, h - 0.02, -d / 2 + 0.36), r=0.07)  # back cushion
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, 0.55, d / 2)), ((-w / 2, 0.55, -d / 2), (w / 2, h, -d / 2 + 0.3))],
                  wall=True, clear_front=0.9)


def armchair(name="RES_Armchair_Recliner", fabric=None, lever=True):
    fabric = fabric or TWEED
    mb = MB()
    w, d, h = 0.92, 0.95, 1.02
    rbox(mb, fabric, (-w / 2 + 0.06, 0.05, -d / 2), (w / 2 - 0.06, 0.45, d / 2), r=0.07)
    rbox(mb, fabric, (-w / 2 + 0.1, 0.4, -d / 2), (w / 2 - 0.1, h, -d / 2 + 0.28), r=0.12)
    for sx in (-1, 1):
        rbox(mb, fabric, (sx * w / 2 - (0.2 if sx > 0 else 0), 0.05, -d / 2 + 0.05), (sx * w / 2 + (0 if sx > 0 else 0.2), 0.68, d / 2 - 0.02),
             r=0.1, axis="z")
    rbox(mb, fabric, (-w / 2 + 0.22, 0.45, -d / 2 + 0.25), (w / 2 - 0.22, 0.58, d / 2 - 0.02), r=0.05)
    if lever:
        mb.box(WOOD_D, (w / 2, 0.3, 0.1), (w / 2 + 0.03, 0.45, 0.14))
    mb.box(WOOD_D, (-w / 2 + 0.06, 0.0, -d / 2 + 0.05), (w / 2 - 0.06, 0.05, d / 2 - 0.05))
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], wall=False, clear_front=0.6)


def wingback():
    name = "RES_Armchair_Wingback"
    mb = MB()
    w, d, h = 0.8, 0.85, 1.15
    legs(mb, WOOD_D, w - 0.1, d - 0.1, 0.2, r=0.025, taper=0.8)
    rbox(mb, TWEED, (-w / 2, 0.2, -d / 2 + 0.05), (w / 2, 0.45, d / 2), r=0.04)
    rbox(mb, TWEED, (-w / 2 + 0.02, 0.4, -d / 2), (w / 2 - 0.02, h, -d / 2 + 0.16), r=0.08)
    for sx in (-1, 1):   # wings
        mb.box(TWEED, (sx * w / 2 - (0.12 if sx > 0 else 0), 0.45, -d / 2 + 0.05), (sx * w / 2 + (0 if sx > 0 else 0.12), h - 0.08, -d / 2 + 0.45))
        mb.box(TWEED, (sx * w / 2 - (0.1 if sx > 0 else 0), 0.45, -d / 2 + 0.45), (sx * w / 2 + (0 if sx > 0 else 0.1), 0.66, d / 2 - 0.04))
    rbox(mb, mr("FabricPlaid"), (-w / 2 + 0.12, 0.45, -d / 2 + 0.15), (w / 2 - 0.12, 0.56, d / 2 - 0.02), r=0.04)
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], clear_front=0.6)


def coffee_table(name="RES_CoffeeTable_Wood"):
    mb = MB()
    w, d, h = 1.1, 0.6, 0.42
    mb.box(WOOD_L, (-w / 2, h - 0.04, -d / 2), (w / 2, h, d / 2))
    mb.box(WOOD_L, (-w / 2 + 0.06, 0.12, -d / 2 + 0.06), (w / 2 - 0.06, 0.14, d / 2 - 0.06))
    legs(mb, WOOD_D, w - 0.04, d - 0.04, h - 0.04, r=0.025, taper=0.7)
    mag = MB()
    mag.box(DET, (0, 0, 0), (0.22, 0.012, 0.3), skip=("-y",), uvrect={"+y": drect("tv_guide")})
    mb.merge(mag, T(0.15, h, -0.1) @ Ry(0.3))
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], center=True)


def side_table():
    name = "RES_SideTable_Drawer"
    mb = MB()
    w, d, h = 0.5, 0.45, 0.58
    mb.box(WOOD_D, (-w / 2, h - 0.03, -d / 2), (w / 2, h, d / 2))
    hollow(mb, WOOD_D, (-w / 2 + 0.03, h - 0.17, -d / 2 + 0.03), (w / 2 - 0.03, h - 0.03, d / 2 - 0.03), skip=("+z",))
    legs(mb, WOOD_D, w - 0.06, d - 0.06, h - 0.17, r=0.02, taper=0.6)
    mb.box(WOOD_D, (-w / 2 + 0.05, 0.12, -d / 2 + 0.05), (w / 2 - 0.05, 0.14, d / 2 - 0.05))
    dr = drawer("INT_Drawer_1", -w / 2 + 0.04, h - 0.16, w / 2 - 0.04, h - 0.04, d / 2 - 0.03, 0.34, WOOD_D)
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=[dr], wall=True, surface_y=h)


def crt_tv(name="RES_TV_CRT_Small", w=0.56, h=0.48, d=0.48, on=True, wood=False):
    mb = MB()
    shell = WOOD_D if wood else m01("Com_SignageBacking")
    mb.box(shell, (-w / 2, 0, -d / 2 + 0.12), (w / 2, h, d / 2))
    hollow(mb, shell, (-w / 2 + 0.07, 0.07, -d / 2), (w / 2 - 0.07, h - 0.07, -d / 2 + 0.12), skip=("+z",))   # tube back
    face_quad(mb, DETG if on else DET, drect("crt_screen" if on else "crt_screen_off"), -w / 2 + 0.05, 0.07, w / 2 - 0.12, h - 0.06, d / 2 + 0.002)
    for k in range(2):
        mb.box(PLASTIC, (w / 2 - 0.08, 0.22 + k * 0.1, d / 2), (w / 2 - 0.04, 0.26 + k * 0.1, d / 2 + 0.02))
    mb.tube(METAL, [(-0.06, h, 0.0), (-0.2, h + 0.3, -0.05)], 0.006, 3)   # rabbit ears
    mb.tube(METAL, [(0.06, h, 0.0), (0.2, h + 0.3, -0.05)], 0.006, 3)
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], on_surface=True, glow=on)


def tv_console():
    name = "RES_TV_CRT_Console"
    mb = MB()
    w, d, h = 1.05, 0.55, 0.82
    mb.box(WOOD_D, (-w / 2, 0.1, -d / 2), (w / 2, h, d / 2))
    legs(mb, WOOD_D, w - 0.1, d - 0.1, 0.1, r=0.02, taper=1.4)
    face_quad(mb, DETG, drect("crt_screen"), -w / 2 + 0.07, 0.3, 0.2, h - 0.07, d / 2 + 0.002)
    face_quad(mb, DET, drect("keypad_radio"), 0.24, 0.3, w / 2 - 0.06, 0.6, d / 2 + 0.002)
    mb.box(TWEED, (-w / 2 + 0.05, 0.14, d / 2), (w / 2 - 0.05, 0.27, d / 2 + 0.003), skip=("-z",))   # speaker cloth
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], wall=True, clear_front=1.5, glow=True)


def tv_stand():
    name = "RES_TVStand"
    mb = MB()
    w, d, h = 1.0, 0.45, 0.55
    hollow(mb, WOOD_L, (-w / 2, 0.05, -d / 2), (w / 2, h, d / 2), skip=("+z",))
    mb.box(WOOD_L, (-w / 2, 0, -d / 2 + 0.02), (w / 2, 0.05, d / 2 - 0.02))
    hollow(mb, WOOD_D, (-w / 2 + 0.03, 0.08, -d / 2 + 0.03), (w / 2 - 0.03, h - 0.03, d / 2 - 0.02), skip=("+z",))
    face_quad(mb, DET, drect("game_cartridges"), -w / 2 + 0.06, 0.1, -0.05, 0.25, d / 2 - 0.03)
    nodes = [cab_door("INT_CabinetDoor_L", -w / 2 + 0.02, 0.07, w / 2 - 0.04, h - 0.1, d / 2, WOOD_L, "l"),
             cab_door("INT_CabinetDoor_R", w / 2 - 0.02, 0.07, w / 2 - 0.04, h - 0.1, d / 2, WOOD_L, "r")]
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=nodes, wall=True,
                  surface_y=h, clear_front=1.5)


def floor_lamp():
    name = "RES_Lamp_Floor"
    mb = MB()
    mb.cyl(METAL, (0, 0, 0), 0.16, 0.03, seg=10, caps=("top",))
    mb.cyl(METAL, (0, 0.03, 0), 0.015, 1.3, seg=6, caps=())
    mb.cyl(mr("Lampshade"), (0, 1.25, 0), 0.24, 0.32, seg=10, r_top=0.15, caps=())
    mb.cyl(mr("BulbGlow"), (0, 1.3, 0), 0.05, 0.08, seg=6, caps=("top",))
    return fmodel(name, "living", mb, (0.4, 0.4, 1.6), cols=[((-0.15, 0, -0.15), (0.15, 1.6, 0.15))],
                  nodes=[{"name": "LightPoint", "t": (0, 1.35, 0)}], corner=True)


def table_lamp():
    name = "RES_Lamp_Table"
    mb = MB()
    mb.cyl(mr("EnamelHarvest"), (0, 0, 0), 0.08, 0.04, seg=8, caps=("top",))
    mb.cyl(mr("EnamelHarvest"), (0, 0.04, 0), 0.06, 0.22, seg=8, r_top=0.03, caps=())
    mb.cyl(METAL, (0, 0.26, 0), 0.01, 0.08, seg=4, caps=())
    mb.cyl(mr("Lampshade"), (0, 0.3, 0), 0.16, 0.22, seg=10, r_top=0.11, caps=())
    return fmodel(name, "living", mb, (0.32, 0.32, 0.55), cols=[], nodes=[{"name": "LightPoint", "t": (0, 0.4, 0)}], on_surface=True)


def bookshelf(name="RES_Bookshelf_Tall", w=0.9, h=1.9, shelves=5):
    mb = MB()
    d = 0.32
    mb.box(WOOD_D, (-w / 2, 0, -d / 2), (-w / 2 + 0.03, h, d / 2))
    mb.box(WOOD_D, (w / 2 - 0.03, 0, -d / 2), (w / 2, h, d / 2))
    hollow(mb, WOOD_D, (-w / 2, 0, -d / 2), (w / 2, h, -d / 2 + 0.01), skip=("+z",))
    sh = (h - 0.08) / shelves
    for k in range(shelves + 1):
        y = 0.04 + k * sh
        mb.box(WOOD_D, (-w / 2 + 0.03, y - 0.03, -d / 2 + 0.01), (w / 2 - 0.03, y, d / 2))
        if k < shelves:
            key = "book_spines" if k % 2 == 0 else "book_spines_b"
            if k == shelves - 1 and name.endswith("Low"):
                key = "vinyl_records"
            bh = sh * (0.78 if k % 3 else 0.68)
            bk = MB()
            bk.box(m01("Furn_Cardboard"), (-w / 2 + 0.05, y, -d / 2 + 0.03), (w / 2 - 0.08 - 0.1 * (k % 2), y + bh, d / 2 - 0.04),
                   skip=("-y",), uvrect={"+z": drect(key)})
            mb.merge(bk)
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], wall=True, clear_front=0.6,
                  surface_y=h if h < 1.2 else None)


def rug(name="RES_Rug_Oval", w=2.0, d=1.4, mat=None, oval=True):
    mb = MB()
    mat = mat or mr("RugBraided")
    n = 16 if oval else 4
    if oval:
        pts = [(w / 2 * math.cos(2 * math.pi * k / n), 0.008, d / 2 * math.sin(2 * math.pi * k / n)) for k in range(n)]
        mb.poly(mat, pts, (0, 1, 0), uvf=lambda p: (p[0] / w + 0.5, p[2] / d + 0.5))
    else:
        pts = [(-w / 2, 0.008, -d / 2), (w / 2, 0.008, -d / 2), (w / 2, 0.008, d / 2), (-w / 2, 0.008, d / 2)]
        mb.poly(mat, pts, (0, 1, 0))
    return fmodel(name, "living", mb, (w, d, 0.01), cols=[], center=True, floor_layer=True)


def frame(name, key, w, h, wood=WOOD_L):
    mb = MB()
    d = 0.03
    mb.box(wood, (-w / 2, -h / 2, -d), (w / 2, h / 2, 0.0), skip=("-z",))
    face_quad(mb, DET, drect(key), -w / 2 + 0.01, -h / 2 + 0.01, w / 2 - 0.01, h / 2 - 0.01, 0.002)
    return fmodel(name, "decor", mb, (w, d, h), cols=[], wall_mount=True, mount_y=1.55)


def curtains(name="RES_Curtains_Gingham", mat=None, w=1.6, h=1.9):
    mat = mat or mr("Gingham")
    mb = MB()
    rod = MB()
    rod.tube(WOOD_D, [(-w / 2 - 0.1, h, 0.08), (w / 2 + 0.1, h, 0.08)], 0.015, 5, caps=True)
    mb.merge(rod)
    for sx in (-1, 1):   # two gathered panels: zig-zag folds
        pts = []
        n = 6
        x0 = sx * (w / 2 + 0.05)
        x1 = sx * (w / 2 - 0.4)
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            z = 0.04 + (0.035 if k % 2 else 0.0)
            pts.append((x, z))
        for k in range(n):
            (xa, za), (xb, zb) = pts[k], pts[k + 1]
            q = [[xa, h, za + 0.02], [xb, h, zb + 0.02], [xb, 0.05, zb], [xa, 0.05, za]]
            mb.quad(mat, *q, n=(0, 0, 1), uv=[(p[0], -p[1]) for p in q])
    return fmodel(name, "decor", mb, (w + 0.2, 0.12, h), cols=[], wall_mount=True, mount_y=0.0, over_window=True)


def wall_clock():
    name = "RES_WallClock"
    mb = MB()
    mb.cyl(WOOD_D, (0, 0, 0), 0.17, 0.05, seg=12, caps=("top",))
    disc = MB()
    pts = [(0.15 * math.cos(2 * math.pi * k / 12), 0.051, 0.15 * math.sin(2 * math.pi * k / 12)) for k in range(12)]
    r = drect("clock_face")
    disc.poly(DET, pts, (0, 1, 0), uvf=lambda p: (r[0] + (p[0] / 0.34 + 0.5) * (r[2] - r[0]), r[1] + (p[2] / 0.34 + 0.5) * (r[3] - r[1])))
    mb.merge(disc)
    out = MB()
    out.merge(mb, Rx(math.pi / 2))   # face +Z
    return fmodel(name, "decor", out, (0.34, 0.05, 0.34), cols=[], wall_mount=True, mount_y=1.9)


def calendar():
    name = "RES_WallCalendar"
    mb = MB()
    mb.box(m01("Furn_Cardboard"), (-0.18, -0.25, -0.005), (0.18, 0.25, 0.0), skip=("-z",))
    face_quad(mb, DET, drect("calendar"), -0.17, -0.24, 0.17, 0.24, 0.001)
    return fmodel(name, "decor", mb, (0.36, 0.01, 0.5), cols=[], wall_mount=True, mount_y=1.5)


def poster():
    name = "RES_Poster_Band"
    mb = MB()
    face_quad(mb, DET, drect("poster_band"), -0.3, -0.4, 0.3, 0.4, 0.003)
    return fmodel(name, "decor", mb, (0.6, 0.01, 0.8), cols=[], wall_mount=True, mount_y=1.6)


def coat_rack():
    name = "RES_CoatRack_Wall"
    mb = MB()
    mb.box(WOOD_D, (-0.4, -0.06, -0.02), (0.4, 0.06, 0.0), skip=("-z",))
    for k in range(4):
        mb.tube(METAL, [(-0.3 + k * 0.2, 0.0, 0.0), (-0.3 + k * 0.2, 0.03, 0.07)], 0.008, 3)
    jacket = MB()   # denim jacket hanging on the first hook
    rbox(jacket, DENIM, (-0.25, -0.75, 0.01), (0.12, -0.02, 0.12), r=0.05)
    mb.merge(jacket)
    keys = MB()      # car keys on the last hook (opening sequence)
    keys.box(METAL, (0.28, -0.06, 0.05), (0.31, 0.0, 0.06))
    keys.box(m01("Furn_PlasticDirty"), (0.27, -0.1, 0.045), (0.32, -0.06, 0.065))
    mb.merge(keys)
    return fmodel(name, "decor", mb, (0.8, 0.12, 0.9), cols=[], wall_mount=True, mount_y=1.65,
                  nodes=[{"name": "INT_Pickup_CarKeys", "t": (0.295, -0.08, 0.055),
                          "extras": {"veil_interact": "pickup", "item": "car_keys"}}])


# ============================================================================
# KITCHEN
# ============================================================================
def fridge(name="RES_Fridge_Retro", mat=None, w=0.76, d=0.72, h=1.7, top_freezer=False):
    mat = mat or mr("EnamelHarvest")
    mb = MB()
    rbox(mb, mat, (-w / 2, 0.04, -d / 2), (w / 2, h, d / 2 - 0.06), r=0.08)
    mb.box(RUBBER, (-w / 2 + 0.05, 0.0, -d / 2 + 0.05), (w / 2 - 0.05, 0.04, d / 2 - 0.1))
    nodes = []
    if top_freezer:
        nodes.append(_appl_door("INT_ApplianceDoor_Freezer", -w / 2, h * 0.72, w, h * 0.27, d / 2 - 0.06, mat))
        nodes.append(_appl_door("INT_ApplianceDoor_Fridge", -w / 2, 0.06, w, h * 0.65, d / 2 - 0.06, mat, notes=True))
    else:
        nodes.append(_appl_door("INT_ApplianceDoor_Fridge", -w / 2, 0.06, w, h - 0.1, d / 2 - 0.06, mat, notes=True, round_top=True))
    return fmodel(name, "kitchen", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=nodes, wall=True, clear_front=0.9)


def _appl_door(name, x0, y0, w, h, z, mat, notes=False, round_top=False):
    mb = MB()
    rbox(mb, mat, (0, 0, 0), (w, h, 0.06), r=0.05 if round_top else 0.02, axis="z")
    mb.box(METAL, (w - 0.08, h * 0.45, 0.06), (w - 0.05, h * 0.75, 0.1))
    if notes:
        face_quad(mb, DET, drect("fridge_notes"), 0.12, h * 0.45, 0.46, h * 0.8, 0.062)
    return {"name": name, "t": (x0, y0, z), "mb": mb, "extras": {"veil_interact": "hinge", "axis": "y", "open_deg": 100}}


def stove(name="RES_Stove_Electric", mat=None):
    mat = mat or WHITE
    mb = MB()
    w, d, h = 0.76, 0.65, 0.92
    front = d / 2 - 0.03
    hollow(mb, mat, (-w / 2, 0.06, -d / 2), (w / 2, h - 0.01, front), skip=("+z",))
    mb.box(mat, (-w / 2 + 0.018, 0.704, front - 0.03),
           (w / 2 - 0.018, h - 0.028, front), skip=())  # fixed fascia above the oven door
    mb.box(RUBBER, (-w / 2 + 0.02, 0, -d / 2 + 0.03), (w / 2 - 0.02, 0.06, d / 2 - 0.06))
    mb.box(mat, (-w / 2, h, -d / 2), (w / 2, h + 0.18, -d / 2 + 0.06))              # backsplash with knobs
    for k in range(4):
        mb.box(PLASTIC, (-0.29 + k * 0.18, h + 0.07, -d / 2 + 0.06), (-0.25 + k * 0.18, h + 0.11, -d / 2 + 0.085))
    top = MB()
    top.box(mat, (-w / 2, h - 0.01, -d / 2 + 0.06), (w / 2, h, d / 2 - 0.03), skip=("-y",), uvrect={"+y": drect("stove_top")})
    # Tile the full cooktop height once. The backsplash sits on the rear strip.
    mb.box(mat, (-w / 2, h - 0.01, -d / 2), (w / 2, h, -d / 2 + 0.06), skip=("-y",))
    mb.merge(top)
    door = MB()
    door.box(mat, (-w / 2 + 0.03, 0, -0.03), (w / 2 - 0.03, 0.6, 0.0), skip=())
    door.box(m01("Arch_WindowGlassDirty"), (-0.22, 0.22, 0.0), (0.22, 0.48, 0.004), skip=("-z",))
    door.tube(METAL, [(-0.28, 0.56, 0.02), (0.28, 0.56, 0.02)], 0.012, 4)
    nodes = [{"name": "INT_ApplianceDoor_Oven", "t": (0, 0.1, d / 2 - 0.03), "mb": door,
              "extras": {"veil_interact": "hinge", "axis": "x", "open_deg": 85}}]
    return fmodel(name, "kitchen", mb, (w, d, h + 0.18), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=nodes, wall=True,
                  clear_front=0.9, counter=True)


def counter(name="RES_Counter_Base_1.2", w=1.2, sink=False, drawers=True, top=None):
    top = top or mr("Formica")
    mb = MB()
    d, h = 0.6, 0.92
    hollow(mb, WOOD_P, (-w / 2, 0.1, -d / 2), (w / 2, h - 0.04, d / 2 - 0.02), skip=("+z",))
    mb.box(WOOD_D, (-w / 2 + 0.02, 0, -d / 2 + 0.02), (w / 2 - 0.02, 0.1, d / 2 - 0.08), skip=("-y",))   # toe kick
    mb.box(top, (-w / 2, h - 0.04, -d / 2), (w / 2, h, d / 2 + 0.02))
    mb.box(top, (-w / 2, h, -d / 2), (w / 2, h + 0.1, -d / 2 + 0.02))   # backsplash
    nodes = []
    nd = max(1, int(round(w / 0.45)))
    cw = (w - 0.04) / nd
    for k in range(nd):
        x0 = -w / 2 + 0.02 + k * cw
        if drawers and not sink:
            nodes.append(drawer(f"INT_Drawer_{k + 1}", x0 + 0.01, h - 0.22, x0 + cw - 0.01, h - 0.06, d / 2 - 0.02, 0.48, WOOD_P))
            nodes.append(cab_door(f"INT_CabinetDoor_{k + 1}", x0 + 0.01 if k % 2 == 0 else x0 + cw - 0.01, 0.12, cw - 0.02,
                                  h - 0.36, d / 2 - 0.02, WOOD_P, "l" if k % 2 == 0 else "r"))
        else:
            nodes.append(cab_door(f"INT_CabinetDoor_{k + 1}", x0 + 0.01 if k % 2 == 0 else x0 + cw - 0.01, 0.12, cw - 0.02,
                                  h - 0.2, d / 2 - 0.02, WOOD_P, "l" if k % 2 == 0 else "r"))
    inner_left, inner_right = -w / 2 + 0.018, w / 2 - 0.018
    bottom, top_edge = 0.118, h - 0.058
    rails = []
    if drawers and not sink:
        rails.append((inner_left, h - 0.237, inner_right, h - 0.223))
    # Tie adjacent bays into the carcass. The door and drawer edges keep
    # 3 mm clearance from each stile, including at the ends of the run.
    stiles = [(inner_left, bottom, -w / 2 + 0.027, top_edge),
              (w / 2 - 0.027, bottom, inner_right, top_edge)]
    for k in range(1, nd):
        split = -w / 2 + 0.02 + k * cw
        if rails:
            stiles.extend([(split - 0.007, bottom, split + 0.007, rails[0][1]),
                           (split - 0.007, rails[0][3], split + 0.007, top_edge)])
        else:
            stiles.append((split - 0.007, bottom, split + 0.007, top_edge))
    if rails:
        rails[0] = (-w / 2 + 0.027, rails[0][1], w / 2 - 0.027, rails[0][3])
    face_frame(mb, WOOD_P, d / 2 - 0.02, rails, stiles)
    if sink:
        basin = MB()
        basin.box(METAL, (-0.35, h - 0.2, -0.2), (0.35, h - 0.18, 0.2), skip=("-y",))
        for (a, b, c, e) in ((-0.35, -0.33, -0.2, 0.2), (0.33, 0.35, -0.2, 0.2)):
            basin.box(METAL, (a, h - 0.2, c), (b, h + 0.002, e), skip=("-y",))
        for (c, e) in ((-0.2, -0.18), (0.18, 0.2)):
            basin.box(METAL, (-0.35, h - 0.2, c), (0.35, h + 0.002, e), skip=("-y",))
        mb.merge(basin)
        # remove countertop over the basin: cover is fine at low poly - draw dark basin interior
        mb.tube(METAL, [(0, h, -0.26), (0, h + 0.3, -0.26), (0, h + 0.32, -0.08)], 0.015, 5, caps=True)
        for sx in (-0.12, 0.12):
            mb.cyl(METAL, (sx, h, -0.25), 0.02, 0.06, seg=6, caps=("top",))
    return fmodel(name, "kitchen", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=nodes, wall=True,
                  clear_front=0.9, surface_y=h, counter=True)


def counter_corner():
    name = "RES_Counter_Corner"
    mb = MB()
    s, h = 0.9, 0.92
    corner_x, front = -s / 2 + 0.6, s / 2 - 0.3
    mb.box(WOOD_P, (-s / 2, 0.1, -s / 2), (corner_x, h - 0.04, s / 2), skip=())
    # The door overlays the left edge of this bay at the existing hinge.
    hollow(mb, WOOD_P, (corner_x, 0.1, -s / 2), (s / 2, h - 0.04, front), skip=("+z",))
    mb.box(WOOD_D, (-s / 2 + 0.02, 0, -s / 2 + 0.02),
           (corner_x, 0.1, s / 2 - 0.05))
    mb.box(WOOD_D, (corner_x, 0, -s / 2 + 0.02), (s / 2 - 0.02, 0.1, front - 0.05))
    mb.box(mr("Formica"), (-s / 2, h - 0.04, -s / 2), (corner_x + 0.02, h, s / 2))
    mb.box(mr("Formica"), (corner_x + 0.02, h - 0.04, -s / 2), (s / 2, h, front + 0.02))
    nodes = [cab_door("INT_CabinetDoor_1", -s / 2 + 0.6, 0.12, 0.28, h - 0.2, s / 2 - 0.3, WOOD_P, "l")]
    return fmodel(name, "kitchen", mb, (s, s, h), cols=[((-s / 2, 0, -s / 2), (s / 2, h, s / 2 - 0.3)), ((-s / 2, 0, -s / 2), (-s / 2 + 0.6, h, s / 2))],
                  nodes=nodes, corner=True, surface_y=h)


def wall_cabinet(name="RES_WallCabinet_0.8", w=0.8):
    mb = MB()
    d, h = 0.33, 0.7
    hollow(mb, WOOD_P, (-w / 2, 0, -d / 2), (w / 2, h, d / 2 - 0.02), skip=("+z",))
    nodes = [cab_door("INT_CabinetDoor_L", -w / 2 + 0.01, 0.01, w / 2 - 0.015, h - 0.02, d / 2 - 0.02, WOOD_P, "l"),
             cab_door("INT_CabinetDoor_R", w / 2 - 0.01, 0.01, w / 2 - 0.015, h - 0.02, d / 2 - 0.02, WOOD_P, "r")]
    face_frame(mb, WOOD_P, d / 2 - 0.02, [], [(-0.002, 0.018, 0.002, h - 0.018)])
    return fmodel(name, "kitchen", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=nodes, wall_mount=True, mount_y=1.45)


def island():
    name = "RES_KitchenIsland"
    mb = MB()
    w, d, h = 1.5, 0.8, 0.92
    mb.box(WOOD_P, (-w / 2 + 0.05, 0.1, -d / 2 + 0.05), (w / 2 - 0.05, h - 0.04, d / 2 - 0.05))
    mb.box(WOOD_D, (-w / 2 + 0.08, 0, -d / 2 + 0.08), (w / 2 - 0.08, 0.1, d / 2 - 0.08), skip=("-y",))
    mb.box(WOOD_L, (-w / 2, h - 0.05, -d / 2), (w / 2, h, d / 2))   # butcher block
    return fmodel(name, "kitchen", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], center=True, surface_y=h)


def dining_table(name="RES_DiningTable_Rect", w=1.5, d=0.9, round_=False, cloth=None):
    mb = MB()
    h = 0.75
    if round_:
        mb.cyl(cloth or WOOD_L, (0, h - 0.04, 0), w / 2, 0.04, seg=14, caps=("top", "bottom"))
        if cloth:
            mb.cyl(cloth, (0, h - 0.25, 0), w / 2 + 0.05, 0.21, seg=14, r_top=w / 2, caps=())
        mb.cyl(WOOD_D, (0, 0, 0), 0.06, h - 0.04, seg=8, caps=())
        mb.cyl(WOOD_D, (0, 0, 0), 0.3, 0.05, seg=8, r_top=0.08, caps=("top",))
        cols = [((-w / 2, 0.0, -w / 2), (w / 2, h, w / 2))]
    else:
        mb.box(WOOD_L, (-w / 2, h - 0.04, -d / 2), (w / 2, h, d / 2))
        hollow(mb, WOOD_L, (-w / 2 + 0.05, h - 0.12, -d / 2 + 0.05), (w / 2 - 0.05, h - 0.04, d / 2 - 0.05), skip=("+y",))
        legs(mb, WOOD_D, w - 0.04, d - 0.04, h - 0.04, r=0.03, taper=0.75)
        cols = [((-w / 2, 0, -d / 2), (w / 2, h, d / 2))]
    return fmodel(name, "kitchen", mb, (w, d if not round_ else w, h), cols=cols, center=True, surface_y=h, chairs=True)


def dining_chair(name="RES_DiningChair_Wood", vinyl=False):
    mb = MB()
    w, d, h = 0.44, 0.46, 0.92
    if vinyl:   # chrome & red vinyl diner chair
        for sx in (-1, 1):
            mb.tube(METAL, [(sx * 0.19, 0, 0.2), (sx * 0.19, 0.45, 0.2), (sx * 0.19, 0.45, -0.2), (sx * 0.19, 0.0, -0.2)], 0.012, 4)
            mb.tube(METAL, [(sx * 0.19, 0.45, -0.2), (sx * 0.19, 0.9, -0.22)], 0.012, 4)
        rbox(mb, mt("PaintRed"), (-0.21, 0.42, -0.21), (0.21, 0.5, 0.21), r=0.03)
        rbox(mb, mt("PaintRed"), (-0.2, 0.62, -0.25), (0.2, 0.88, -0.2), r=0.03)
    else:
        legs(mb, WOOD_D, w - 0.02, d - 0.02, 0.45, r=0.018, taper=0.9)
        mb.box(WOOD_L, (-w / 2, 0.45, -d / 2), (w / 2, 0.49, d / 2))
        for sx in (-1, 1):
            mb.box(WOOD_D, (sx * (w / 2 - 0.02) - 0.018, 0.49, -d / 2 + 0.005), (sx * (w / 2 - 0.02) + 0.018, h, -d / 2 + 0.04))
        for y in (0.62, 0.78, 0.88):
            mb.box(WOOD_L, (-w / 2 + 0.03, y, -d / 2 + 0.01), (w / 2 - 0.03, y + 0.05, -d / 2 + 0.035))
    return fmodel(name, "kitchen", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, 0.5, d / 2))])


def microwave():
    name = "RES_Microwave"
    mb = MB()
    w, d, h = 0.5, 0.38, 0.3
    hollow(mb, WHITE, (-w / 2, 0.01, -d / 2), (w / 2, h, d / 2 - 0.02), skip=("+z",))
    front = d / 2 - 0.02
    panel_left = w / 2 - 0.126
    # Mount the controls on a solid end enclosure tied into the top and side shell.
    mb.box(WHITE, (panel_left, 0.028, front - 0.035),
           (w / 2 - 0.018, h - 0.018, front), skip=())
    face_quad(mb, DET, drect("microwave_panel"), panel_left + 0.003, 0.032,
              w / 2 - 0.021, h - 0.032, front + 0.001)
    door = MB()
    door.box(WHITE, (0, 0, -0.02), (w - 0.14, h - 0.04, 0.0), skip=())
    door.box(m01("Arch_WindowGlassDirty"), (0.04, 0.04, 0.0), (w - 0.2, h - 0.08, 0.003), skip=("-z",))
    nodes = [{"name": "INT_ApplianceDoor_Microwave", "t": (-w / 2 + 0.01, 0.02, d / 2 - 0.02), "mb": door,
              "extras": {"veil_interact": "hinge", "axis": "y", "open_deg": 100}}]
    return fmodel(name, "kitchen", mb, (w, d, h), cols=[], nodes=nodes, on_surface=True)


def kettle():
    name = "RES_Kettle"
    mb = MB()
    mb.cyl(mt("PaintRed"), (0, 0, 0), 0.1, 0.16, seg=10, r_top=0.07, caps=())
    mb.cyl(mt("PaintRed"), (0, 0.16, 0), 0.07, 0.03, seg=10, r_top=0.02, caps=("top",))
    mb.cyl(PLASTIC, (0, 0.19, 0), 0.015, 0.02, seg=5, caps=("top",))
    mb.tube(PLASTIC, [(-0.06, 0.17, 0), (0, 0.24, 0), (0.06, 0.17, 0)], 0.012, 4)
    mb.tube(mt("PaintRed"), [(0.08, 0.05, 0), (0.15, 0.13, 0)], 0.018, 5, caps=True)
    return fmodel(name, "kitchen", mb, (0.3, 0.2, 0.25), cols=[], on_surface=True, prop=True)


def dish_rack():
    name = "RES_DishRack"
    mb = MB()
    mb.box(PLASTIC, (-0.22, 0, -0.16), (0.22, 0.04, 0.16))
    for k in range(7):
        mb.box(PLASTIC, (-0.2 + k * 0.065, 0.04, -0.15), (-0.195 + k * 0.065, 0.14, 0.15), skip=())
    for k in range(4):
        p = MB()
        p.cyl(PORC, (0, 0, 0), 0.11, 0.015, seg=10, caps=("top", "bottom"))
        mb.merge(p, T(-0.12 + k * 0.07, 0.14, 0) @ Rz(math.pi / 2 - 0.1))
    return fmodel(name, "kitchen", mb, (0.44, 0.32, 0.26), cols=[], on_surface=True, prop=True)


def dishes():
    name = "RES_Dishes_Set"
    mb = MB()
    for k in range(5):
        mb.cyl(PORC, (-0.1, k * 0.018, 0), 0.12, 0.016, seg=12, r_top=0.13, caps=("top",))
    for k, (x, z) in enumerate(((0.12, -0.05), (0.18, 0.06))):
        mb.cyl(mt("PaintNavy") if k else PORC, (x, 0, z), 0.04, 0.09, seg=8, caps=("bottom",))
        mb.tube(mt("PaintNavy") if k else PORC, [(x + 0.04, 0.07, z), (x + 0.07, 0.045, z), (x + 0.04, 0.02, z)], 0.008, 3)
    mb.cyl(PORC, (0.0, 0, 0.14), 0.08, 0.06, seg=10, r_top=0.1, caps=("bottom",))
    return fmodel(name, "kitchen", mb, (0.4, 0.35, 0.1), cols=[], on_surface=True, prop=True)


def trash_can():
    name = "RES_TrashCan_Pedal"
    mb = MB()
    mb.cyl(METAL, (0, 0, 0), 0.15, 0.46, seg=10, r_top=0.16, caps=())
    mb.cyl(METAL, (0, 0.46, 0), 0.165, 0.04, seg=10, r_top=0.12, caps=("top",))
    mb.box(m01("Furn_Rubber"), (-0.06, 0.0, 0.14), (0.06, 0.03, 0.22))
    return fmodel(name, "kitchen", mb, (0.34, 0.4, 0.5), cols=[((-0.16, 0, -0.16), (0.16, 0.5, 0.16))], corner=True)


def cereal_box():
    name = "RES_CerealBox"
    mb = MB()
    mb.box(m01("Furn_Cardboard"), (-0.1, 0, -0.03), (0.1, 0.28, 0.03), uvrect={"+z": drect("cereal_box"), "-z": drect("cereal_box")})
    return fmodel(name, "kitchen", mb, (0.2, 0.06, 0.28), cols=[], on_surface=True, prop=True)


# ============================================================================
# BEDROOM
# ============================================================================
def bed(name="RES_Bed_Double", w=1.5, l=2.1, bedding=None, head=WOOD_D, messy=False):
    bedding = bedding or mr("Quilt")
    mb = MB()
    d = l
    # origin at the foot-centre... keep convention: centred footprint, headboard on -Z (against the wall)
    mb.box(head, (-w / 2 - 0.03, 0, -d / 2), (w / 2 + 0.03, 1.05, -d / 2 + 0.06))
    mb.box(head, (-w / 2 - 0.03, 0, d / 2 - 0.05), (w / 2 + 0.03, 0.55, d / 2))
    mb.box(head, (-w / 2, 0.18, -d / 2 + 0.06), (w / 2, 0.32, d / 2 - 0.05))
    rbox(mb, m01("Int_DrywallLight"), (-w / 2 + 0.02, 0.32, -d / 2 + 0.07), (w / 2 - 0.02, 0.5, d / 2 - 0.06), r=0.05)  # mattress
    top = 0.5
    rbox(mb, bedding, (-w / 2 - 0.02, top - 0.12, -d / 2 + 0.55 + (0.25 if messy else 0)), (w / 2 + 0.02, top + 0.05, d / 2 - 0.04),
         r=0.04)   # quilt over the mattress
    if messy:
        fold = MB()
        rbox(fold, bedding, (-w / 2, 0, -0.18), (w / 2 * 0.7, 0.12, 0.18), r=0.05)
        mb.merge(fold, T(0.1, top, -d / 2 + 0.75) @ Ry(0.15))
    npw = 2 if w > 1.2 else 1
    for k in range(npw):
        cx = (-w / 4 + k * w / 2) if npw == 2 else 0
        rbox(mb, mt("PaintWhite"), (cx - 0.3 + 0.04, top, -d / 2 + 0.12), (cx + 0.3 - 0.04, top + 0.14, -d / 2 + 0.48), r=0.06)
    return fmodel(name, "bedroom", mb, (w + 0.06, d, 1.05), cols=[((-w / 2, 0, -d / 2), (w / 2, 0.55, d / 2)), ((-w / 2, 0, -d / 2), (w / 2, 1.05, -d / 2 + 0.06))],
                  wall=True, clear_front=0.7, clear_sides=0.6)


def mattress_bare():
    name = "RES_Mattress_Bare"
    mb = MB()
    rbox(mb, m01("Int_DrywallLight"), (-0.7, 0.0, -0.97), (0.7, 0.22, 0.97), r=0.06)
    stain = MB()
    stain.ground_poly(m01("Furn_Cardboard"), [(-0.2, -0.3), (0.25, -0.25), (0.3, 0.1), (-0.1, 0.2)], y=0.221)
    mb.merge(stain)
    return fmodel(name, "bedroom", mb, (1.4, 1.94, 0.22), cols=[((-0.7, 0, -0.97), (0.7, 0.22, 0.97))], center=True)


def pillow():
    name = "RES_Pillow"
    mb = MB()
    rbox(mb, mt("PaintWhite"), (-0.3, 0, -0.2), (0.3, 0.14, 0.2), r=0.06)
    return fmodel(name, "bedroom", mb, (0.6, 0.4, 0.14), cols=[], prop=True)


def blanket_folded():
    name = "RES_Blanket_Folded"
    mb = MB()
    for k in range(3):
        rbox(mb, mr("FabricPlaid"), (-0.3, k * 0.045, -0.22), (0.3, k * 0.045 + 0.045, 0.22), r=0.02)
    return fmodel(name, "bedroom", mb, (0.6, 0.44, 0.14), cols=[], on_surface=True, prop=True)


def nightstand():
    name = "RES_Nightstand"
    mb = MB()
    w, d, h = 0.48, 0.4, 0.58
    hollow(mb, WOOD_D, (-w / 2, 0.05, -d / 2), (w / 2, h, d / 2 - 0.02), skip=("+z",))
    legs(mb, WOOD_D, w, d, 0.05, inset=0.03, r=0.02)
    nodes = [drawer("INT_Drawer_1", -w / 2 + 0.03, h - 0.2, w / 2 - 0.03, h - 0.04, d / 2 - 0.02, 0.3, WOOD_D),
             drawer("INT_Drawer_2", -w / 2 + 0.03, 0.08, w / 2 - 0.03, h - 0.24, d / 2 - 0.02, 0.3, WOOD_D)]
    inner_left, inner_right = -w / 2 + 0.018, w / 2 - 0.018
    face_left, face_right = -w / 2 + 0.027, w / 2 - 0.027
    face_frame(mb, WOOD_D, d / 2 - 0.02,
               [(face_left, h - 0.237, face_right, h - 0.203),
                (face_left, h - 0.037, face_right, h - 0.018),
                (face_left, 0.068, face_right, 0.077)],
               [(inner_left, 0.068, face_left, h - 0.018),
                (face_right, 0.068, inner_right, h - 0.018)])
    return fmodel(name, "bedroom", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=nodes, wall=True, surface_y=h)


def dresser(name="RES_Dresser", w=1.2, rows=3, mirror=False):
    mb = MB()
    d, h = 0.48, 0.85
    hollow(mb, WOOD_L, (-w / 2, 0.08, -d / 2), (w / 2, h, d / 2 - 0.02), skip=("+z",))
    mb.box(WOOD_L, (-w / 2 - 0.02, h, -d / 2 - 0.01), (w / 2 + 0.02, h + 0.03, d / 2))
    legs(mb, WOOD_D, w, d, 0.08, inset=0.04, r=0.025, taper=1.2)
    nodes = []
    rh = (h - 0.12) / rows
    for r in range(rows):
        y0 = 0.1 + r * rh
        if r < rows - 1:
            nodes.append(drawer(f"INT_Drawer_{r + 1}", -w / 2 + 0.03, y0, w / 2 - 0.03, y0 + rh - 0.02, d / 2 - 0.02, 0.4, WOOD_L))
        else:
            for k in range(2):
                nodes.append(drawer(f"INT_Drawer_{r + 1}{'LR'[k]}", -w / 2 + 0.03 + k * w / 2, y0, -0.01 + k * w / 2, y0 + rh - 0.02,
                                    d / 2 - 0.02, 0.4, WOOD_L, face_left=-0.02 if k == 1 else 0.0))
    face_left, face_right = -w / 2 + 0.027, w / 2 - 0.027
    top_face = 0.1 + rows * rh - 0.02
    rails = [(face_left, 0.1 + r * rh - 0.017, face_right, 0.1 + r * rh - 0.003)
             for r in range(1, rows)]
    rails.append((face_left, top_face + 0.003, face_right, h - 0.018))
    face_frame(mb, WOOD_L, d / 2 - 0.02, rails,
               [(-w / 2 + 0.018, 0.098, face_left, h - 0.018),
                (face_right, 0.098, w / 2 - 0.018, h - 0.018),
                (-0.007, 0.1 + (rows - 1) * rh - 0.003, 0.007, top_face + 0.003)])
    if mirror:
        mb.box(WOOD_L, (-0.42, h + 0.03, -d / 2 + 0.01), (0.42, h + 0.95, -d / 2 + 0.05))
        face_quad(mb, mr("Mirror"), (0, 0, 1, 1), -0.36, h + 0.1, 0.36, h + 0.88, -d / 2 + 0.052)
    return fmodel(name, "bedroom", mb, (w + 0.04, d, h + (0.95 if mirror else 0.03)), cols=[((-w / 2, 0, -d / 2), (w / 2, h + 0.03, d / 2))],
                  nodes=nodes, wall=True, clear_front=0.8, surface_y=h + 0.03)


def wardrobe():
    name = "RES_Wardrobe"
    mb = MB()
    w, d, h = 1.0, 0.58, 1.95
    hollow(mb, WOOD_D, (-w / 2, 0.06, -d / 2), (w / 2, h, d / 2 - 0.02), skip=("+z",))
    mb.box(WOOD_D, (-w / 2 - 0.03, h, -d / 2 - 0.02), (w / 2 + 0.03, h + 0.06, d / 2 + 0.01))
    mb.box(WOOD_D, (-w / 2, 0, -d / 2), (w / 2, 0.06, d / 2 - 0.04))
    hollow(mb, WOOD_L, (-w / 2 + 0.03, 0.08, -d / 2 + 0.03), (w / 2 - 0.03, h - 0.03, d / 2 - 0.03), skip=("+z",))
    mb.tube(METAL, [(-w / 2 + 0.05, h - 0.2, 0.0), (w / 2 - 0.05, h - 0.2, 0.0)], 0.012, 4)
    for k in range(4):   # hanging shirts
        rbox(mb, [DENIM, TWEED, mr("Gingham"), mr("FabricPlaid")][k], (-0.35 + k * 0.18, h - 1.05, -0.2), (-0.25 + k * 0.18, h - 0.22, 0.2),
             r=0.03, axis="z")
    nodes = [cab_door("INT_CabinetDoor_L", -w / 2 + 0.01, 0.08, w / 2 - 0.015, h - 0.1, d / 2 - 0.02, WOOD_D, "l"),
             cab_door("INT_CabinetDoor_R", w / 2 - 0.01, 0.08, w / 2 - 0.015, h - 0.1, d / 2 - 0.02, WOOD_D, "r")]
    return fmodel(name, "bedroom", mb, (w + 0.06, d, h + 0.06), cols=[((-w / 2, 0, -d / 2), (w / 2, h + 0.06, d / 2))], nodes=nodes,
                  wall=True, clear_front=0.9)


def desk(name="RES_Desk", pc=False):
    mb = MB()
    w, d, h = 1.2, 0.6, 0.75
    mb.box(WOOD_L, (-w / 2, h - 0.04, -d / 2), (w / 2, h, d / 2))
    hollow(mb, WOOD_L, (w / 2 - 0.42, 0.0, -d / 2 + 0.02), (w / 2 - 0.02, h - 0.04, d / 2 - 0.02), skip=("+z",))
    mb.box(WOOD_L, (-w / 2 + 0.02, 0, -d / 2 + 0.02), (-w / 2 + 0.05, h - 0.04, d / 2 - 0.02))
    nodes = [drawer("INT_Drawer_1", w / 2 - 0.41, h - 0.22, w / 2 - 0.03, h - 0.06, d / 2 - 0.02, 0.45, WOOD_L),
             drawer("INT_Drawer_2", w / 2 - 0.41, 0.05, w / 2 - 0.03, h - 0.26, d / 2 - 0.02, 0.45, WOOD_L)]
    if pc:   # beige CRT monitor + keyboard + tower
        mb.box(m01("Furn_PlasticDirty"), (-0.4, h, -0.25), (0.0, h + 0.34, 0.1))
        face_quad(mb, DETG, drect("pc_screen"), -0.37, h + 0.04, -0.03, h + 0.3, 0.101)
        mb.box(m01("Furn_PlasticDirty"), (-0.42, h, 0.12), (0.02, h + 0.03, 0.27))
        mb.box(m01("Furn_PlasticDirty"), (-w / 2 + 0.08, 0, -0.2), (-w / 2 + 0.28, 0.42, 0.25))
    return fmodel(name, "bedroom", mb, (w, d, h + (0.34 if pc else 0)), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], nodes=nodes,
                  wall=True, clear_front=0.9, surface_y=h, glow=pc)


def desk_chair():
    name = "RES_DeskChair_Office"
    mb = MB()
    for k in range(5):
        a = k * 2 * math.pi / 5
        mb.tube(m01("Furn_Rubber"), [(0, 0.08, 0), (0.28 * math.cos(a), 0.05, 0.28 * math.sin(a))], 0.02, 4)
        mb.cyl(m01("Furn_Rubber"), (0.28 * math.cos(a), 0.0, 0.28 * math.sin(a)), 0.03, 0.05, seg=6, caps=("top",))
    mb.cyl(METAL, (0, 0.08, 0), 0.025, 0.35, seg=6, caps=())
    rbox(mb, TWEED, (-0.24, 0.43, -0.22), (0.24, 0.52, 0.24), r=0.04)
    rbox(mb, TWEED, (-0.22, 0.6, -0.26), (0.22, 0.98, -0.18), r=0.05)
    mb.box(METAL, (-0.02, 0.48, -0.24), (0.02, 0.62, -0.2))
    return fmodel(name, "bedroom", mb, (0.6, 0.6, 1.0), cols=[((-0.25, 0, -0.26), (0.25, 0.55, 0.25))])


def alarm_clock():
    name = "RES_AlarmClock"
    mb = MB()
    mb.box(m01("Furn_WoodDark"), (-0.1, 0, -0.05), (0.1, 0.09, 0.05))
    face_quad(mb, DETG, drect("alarm_digits"), -0.085, 0.015, 0.085, 0.075, 0.051)
    return fmodel(name, "bedroom", mb, (0.2, 0.1, 0.09), cols=[], on_surface=True, prop=True, glow=True)


# ============================================================================
# BATHROOM
# ============================================================================
def toilet():
    name = "RES_Toilet"
    mb = MB()
    mb.cyl(PORC, (0, 0, 0.05), 0.13, 0.38, seg=10, r_top=0.19, caps=())
    seat = MB()
    pts = [(0.2 * math.cos(2 * math.pi * k / 12), 0.0, 0.25 * math.sin(2 * math.pi * k / 12)) for k in range(12)]
    seat.prism(PORC, [(p[0], p[2]) for p in pts], 0, 0.04)
    mb.merge(seat, T(0, 0.38, 0.06) @ Rx(-math.pi / 2))
    mb.box(PORC, (-0.21, 0.36, -0.26), (0.21, 0.78, -0.08))          # tank
    mb.box(PORC, (-0.23, 0.78, -0.27), (0.23, 0.81, -0.07))
    mb.box(METAL, (-0.2, 0.7, -0.08), (-0.12, 0.72, -0.05))
    lid = MB()
    lid.box(PORC, (-0.2, 0.0, -0.02), (0.2, 0.42, 0.0), skip=())
    return fmodel(name, "bathroom", mb, (0.46, 0.66, 0.81), cols=[((-0.22, 0, -0.27), (0.22, 0.45, 0.32)), ((-0.22, 0, -0.27), (0.22, 0.81, -0.07))],
                  wall=True, clear_front=0.6,
                  nodes=[{"name": "INT_Lid_Toilet", "t": (0, 0.42, -0.07), "mb": lid, "extras": {"veil_interact": "hinge", "axis": "x", "open_deg": -95}}])


def bath_sink(name="RES_BathSink_Pedestal", vanity=False):
    mb = MB()
    h = 0.85
    nodes = []
    if vanity:
        w, d = 0.8, 0.5
        hollow(mb, WOOD_P, (-w / 2, 0.08, -d / 2), (w / 2, h - 0.03, d / 2 - 0.02), skip=("+z",))
        mb.box(mr("Formica"), (-w / 2 - 0.02, h - 0.03, -d / 2), (w / 2 + 0.02, h, d / 2 + 0.01))
        nodes = [cab_door("INT_CabinetDoor_L", -w / 2 + 0.01, 0.1, w / 2 - 0.015, h - 0.17, d / 2 - 0.02, WOOD_P, "l"),
                 cab_door("INT_CabinetDoor_R", w / 2 - 0.01, 0.1, w / 2 - 0.015, h - 0.17, d / 2 - 0.02, WOOD_P, "r")]
        cols = [((-w / 2, 0, -d / 2), (w / 2, h, d / 2))]
    else:
        w, d = 0.56, 0.46
        mb.cyl(PORC, (0, 0, 0), 0.12, h - 0.15, seg=8, r_top=0.08, caps=())
        rbox(mb, PORC, (-w / 2, h - 0.18, -d / 2), (w / 2, h, d / 2), r=0.06)
        cols = [((-w / 2, 0, -d / 2), (w / 2, h, d / 2))]
    mb.box(METAL, (-0.18, h + 0.001, -0.1), (0.18, h + 0.002, 0.14), skip=("-y",))   # basin shadow
    mb.tube(METAL, [(0, h, -d / 2 + 0.05), (0, h + 0.16, -d / 2 + 0.05), (0, h + 0.17, -d / 2 + 0.15)], 0.013, 5, caps=True)
    return fmodel(name, "bathroom", mb, (w, d, h), cols=cols, nodes=nodes, wall=True, clear_front=0.6, surface_y=h)


def bathtub():
    name = "RES_Bathtub"
    mb = MB()
    w, d, h = 1.6, 0.75, 0.55
    mb.box(PORC, (-w / 2, 0, -d / 2), (w / 2, h, -d / 2 + 0.08))
    mb.box(PORC, (-w / 2, 0, d / 2 - 0.08), (w / 2, h, d / 2))
    mb.box(PORC, (-w / 2, 0, -d / 2 + 0.08), (-w / 2 + 0.1, h, d / 2 - 0.08))
    mb.box(PORC, (w / 2 - 0.1, 0, -d / 2 + 0.08), (w / 2, h, d / 2 - 0.08))
    mb.box(PORC, (-w / 2 + 0.1, 0, -d / 2 + 0.08), (w / 2 - 0.1, 0.12, d / 2 - 0.08), skip=("-y",))
    mb.tube(METAL, [(w / 2 - 0.06, 1.0, 0), (w / 2 - 0.06, 0.62, 0), (w / 2 - 0.22, 0.6, 0)], 0.015, 5, caps=True)
    # shower curtain rail + curtain on the open side
    mb.tube(METAL, [(-w / 2, 2.0, d / 2 - 0.03), (w / 2, 2.0, d / 2 - 0.03)], 0.01, 4)
    cur = MB()
    for k in range(6):
        xa, xb = -w / 2 + k * 0.12, -w / 2 + (k + 1) * 0.12
        za, zb = d / 2 - 0.03 + (0.03 if k % 2 else 0), d / 2 - 0.03 + (0 if k % 2 else 0.03)
        q = [[xa, 0.6, za], [xb, 0.6, zb], [xb, 1.98, zb], [xa, 1.98, za]]
        cur.quad(mr("Gingham"), *q, n=(0, 0, 1), uv=[(p[0], -p[1]) for p in q])
    mb.merge(cur)
    return fmodel(name, "bathroom", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], wall=True, along_wall=True, clear_front=0.6)


def shower():
    name = "RES_ShowerStall"
    mb = MB()
    s, h = 0.9, 2.0
    mb.box(PORC, (-s / 2, 0, -s / 2), (s / 2, 0.12, s / 2))
    for (a, b, c, e) in ((-s / 2, -s / 2 + 0.05, -s / 2, s / 2), (s / 2 - 0.05, s / 2, -s / 2, s / 2), (-s / 2, s / 2, -s / 2, -s / 2 + 0.05)):
        mb.box(m01("Int_TilesBathroom"), (a, 0.12, c), (b, h, e), skip=("-y",))
    mb.tube(METAL, [(0, 1.9, -s / 2 + 0.05), (0, 1.9, -s / 2 + 0.25)], 0.015, 4, caps=True)
    mb.cyl(METAL, (0, 1.84, -s / 2 + 0.25), 0.06, 0.06, seg=8, r_top=0.03, caps=("bottom",))
    mb.tube(METAL, [(-s / 2, h, s / 2), (s / 2, h, s / 2)], 0.01, 4)
    cur = MB()
    q = [[-s / 2 + 0.05, 0.2, s / 2], [-s / 2 + 0.35, 0.2, s / 2], [-s / 2 + 0.35, h - 0.02, s / 2], [-s / 2 + 0.05, h - 0.02, s / 2]]
    cur.quad(mr("Gingham"), *q, n=(0, 0, 1), uv=[(p[0], -p[1]) for p in q])
    mb.merge(cur)
    return fmodel(name, "bathroom", mb, (s, s, h), cols=[((-s / 2, 0, -s / 2), (-s / 2 + 0.05, h, s / 2)), ((s / 2 - 0.05, 0, -s / 2), (s / 2, h, s / 2)),
                                                           ((-s / 2, 0, -s / 2), (s / 2, 0.12, s / 2))], corner=True)


def bath_mirror():
    name = "RES_Mirror_Bathroom"
    mb = MB()
    mb.box(WOOD_P, (-0.32, -0.42, -0.025), (0.32, 0.42, 0.0), skip=("-z",))
    face_quad(mb, mr("Mirror"), (0, 0, 1, 1), -0.29, -0.39, 0.29, 0.39, 0.002)
    return fmodel(name, "bathroom", mb, (0.64, 0.03, 0.84), cols=[], wall_mount=True, mount_y=1.55)


def towel_rack():
    name = "RES_TowelRack"
    mb = MB()
    for sx in (-1, 1):
        mb.box(METAL, (sx * 0.3 - 0.02, -0.03, -0.0), (sx * 0.3 + 0.02, 0.03, 0.08))
    mb.tube(METAL, [(-0.3, 0.0, 0.07), (0.3, 0.0, 0.07)], 0.012, 4)
    tw = MB()
    rbox(tw, mt("PaintNavy"), (-0.22, -0.45, 0.05), (0.22, 0.02, 0.1), r=0.02)
    mb.merge(tw)
    return fmodel(name, "bathroom", mb, (0.64, 0.1, 0.5), cols=[], wall_mount=True, mount_y=1.2)


def medicine_cabinet():
    name = "RES_MedicineCabinet"
    mb = MB()
    w, h, d = 0.5, 0.65, 0.14
    mb.box(WHITE, (-w / 2, -h / 2, 0), (w / 2, h / 2, d), skip=("-z", "+z"))
    mb.box(WHITE, (-w / 2 + 0.02, -h / 2 + 0.02, 0.0), (w / 2 - 0.02, h / 2 - 0.02, 0.005), skip=("-z",))
    for y in (-0.1, 0.12):
        mb.box(WHITE, (-w / 2 + 0.02, y, 0.01), (w / 2 - 0.02, y + 0.015, d - 0.01))
    door = MB()
    door.box(WHITE, (0, -h / 2, 0), (w, h / 2, 0.02), skip=())
    face_quad(door, mr("Mirror"), (0, 0, 1, 1), 0.03, -h / 2 + 0.03, w - 0.03, h / 2 - 0.03, 0.022)
    return fmodel(name, "bathroom", mb, (w, d, h), cols=[], wall_mount=True, mount_y=1.55,
                  nodes=[{"name": "INT_CabinetDoor_Mirror", "t": (-w / 2, 0, d), "mb": door,
                          "extras": {"veil_interact": "hinge", "axis": "y", "open_deg": -100}}])


# ============================================================================
# GARAGE / BASEMENT / LAUNDRY
# ============================================================================
def shelving_metal(name="RES_Shelving_Metal"):
    mb = MB()
    w, d, h = 1.2, 0.45, 1.8
    for sx in (-1, 1):
        for sz in (-1, 1):
            mb.box(m01("Com_MetalShelving"), (sx * w / 2 - 0.02 * (sx > 0) - 0.0, 0, sz * d / 2 - 0.02 * (sz > 0)),
                   (sx * w / 2 + 0.02 * (sx < 0), h, sz * d / 2 + 0.02 * (sz < 0)))
    for k in range(5):
        y = 0.1 + k * 0.42
        mb.box(m01("Com_MetalShelving"), (-w / 2, y, -d / 2), (w / 2, y + 0.02, d / 2))
    rng = rng_of(name)
    for k in range(4):   # stuff on the shelves: paint cans, boxes
        y = 0.12 + k * 0.42
        for j in range(3):
            x = -0.4 + j * 0.4 + rng.uniform(-0.05, 0.05)
            if rng.random() < 0.5:
                mb.cyl(METAL, (x, y, 0.02), 0.09, 0.2, seg=8, caps=("top",))
            else:
                mb.box(CARD, (x - 0.15, y, -0.15), (x + 0.15, y + 0.22 + 0.08 * rng.random(), 0.15), skip=("-y",))
    return fmodel(name, "garage", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], wall=True, clear_front=0.8)


def toolbox():
    name = "RES_Toolbox"
    mb = MB()
    w, d, h = 0.5, 0.24, 0.2
    hollow(mb, mt("PaintRed"), (-w / 2, 0, -d / 2), (w / 2, h, d / 2), skip=("+y",))
    lid = MB()
    lid.box(mt("PaintRed"), (0, 0, -0.0), (w, 0.04, d), skip=())
    lid.tube(METAL, [(0.15, 0.04, d / 2), (0.15, 0.09, d / 2), (w - 0.15, 0.09, d / 2), (w - 0.15, 0.04, d / 2)], 0.01, 4)
    return fmodel(name, "garage", mb, (w, d, h + 0.13), cols=[((-w / 2, 0, -d / 2), (w / 2, h + 0.04, d / 2))], on_surface=True,
                  nodes=[{"name": "INT_Lid_Toolbox", "t": (-w / 2, h, -d / 2), "mb": lid,
                          "extras": {"veil_interact": "hinge", "axis": "x", "open_deg": -100}}])


def workbench():
    name = "RES_Workbench"
    mb = MB()
    w, d, h = 1.8, 0.7, 0.9
    mb.box(WOOD_L, (-w / 2, h - 0.06, -d / 2), (w / 2, h, d / 2))
    for sx in (-1, 1):
        for sz in (-1, 1):
            mb.box(WOOD_D, (sx * (w / 2 - 0.06) - 0.04, 0, sz * (d / 2 - 0.06) - 0.04), (sx * (w / 2 - 0.06) + 0.04, h - 0.06, sz * (d / 2 - 0.06) + 0.04))
    mb.box(WOOD_L, (-w / 2 + 0.05, 0.15, -d / 2 + 0.05), (w / 2 - 0.05, 0.18, d / 2 - 0.05))
    peg = MB()
    pts = [[-w / 2, h + 0.05, -d / 2 + 0.01], [w / 2, h + 0.05, -d / 2 + 0.01], [w / 2, h + 1.05, -d / 2 + 0.01], [-w / 2, h + 1.05, -d / 2 + 0.01]]
    peg.quad(mr("Pegboard"), *pts, n=(0, 0, 1), uv=[(p[0], -p[1]) for p in pts])
    mb.merge(peg)
    for k, (x, y) in enumerate(((-0.6, h + 0.6), (-0.3, h + 0.7), (0.1, h + 0.55), (0.5, h + 0.75))):   # hanging tools
        mb.box(METAL if k % 2 else WOOD_D, (x - 0.02, y - 0.25, -d / 2 + 0.02), (x + 0.02, y, -d / 2 + 0.05))
        mb.box(METAL, (x - 0.06, y - 0.06, -d / 2 + 0.02), (x + 0.06, y, -d / 2 + 0.06))
    mb.box(METAL, (w / 2 - 0.25, h, d / 2 - 0.15), (w / 2 - 0.05, h + 0.1, d / 2 + 0.05))   # vise
    return fmodel(name, "garage", mb, (w, d, h + 1.05), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], wall=True, clear_front=0.9, surface_y=h)


def storage_bin(name="RES_StorageBin"):
    mb = MB()
    w, d, h = 0.6, 0.4, 0.35
    hollow(mb, PLASTIC, (-w / 2, 0, -d / 2), (w / 2, h, d / 2), skip=("+y",))
    lid = MB()
    lid.box(mt("PaintNavy"), (-w / 2 - 0.01, 0, -d / 2 - 0.01), (w / 2 + 0.01, 0.04, d / 2 + 0.01), skip=())
    return fmodel(name, "garage", mb, (w, d, h + 0.04), cols=[((-w / 2, 0, -d / 2), (w / 2, h + 0.04, d / 2))],
                  nodes=[{"name": "INT_Lid_Bin", "t": (0, h, 0), "mb": lid, "extras": {"veil_interact": "lift", "axis": "y", "distance": 0.3}}],
                  stackable=True)


def cardboard_box(name="RES_CardboardBox_Closed", w=0.5, d=0.4, h=0.4, open_=False):
    mb = MB()
    hollow(mb, CARD, (-w / 2, 0, -d / 2), (w / 2, h, d / 2), skip=("+y",) if open_ else ())
    if open_:
        for (a, ang) in ((-1, 0.6), (1, -0.6)):
            f = MB()
            f.box(CARD, (0, -0.005, -d / 2), (w / 2, 0.0, d / 2), skip=())
            mb.merge(f, T(a * w / 2, h, 0) @ Rz(ang if a < 0 else math.pi + ang))
        mb.box(CARD, (-w / 2 + 0.01, h - 0.08, -d / 2 + 0.01), (w / 2 - 0.01, h - 0.079, d / 2 - 0.01), skip=("-y",))
    else:
        mb.box(m01("Furn_PlasticDirty"), (-0.04, h, -d / 2), (0.04, h + 0.002, d / 2), skip=("-y",))   # tape strip
    return fmodel(name, "garage", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], stackable=True)


def box_stack():
    name = "RES_CardboardBox_Stack"
    mb = MB()
    rng = rng_of(name)
    y = 0.0
    for k in range(3):
        w, d, h = 0.55 - k * 0.06, 0.45 - k * 0.04, 0.38 - k * 0.04
        b = MB()
        b.box(CARD, (-w / 2, 0, -d / 2), (w / 2, h, d / 2), skip=("-y",) if k else ())
        mb.merge(b, T(rng.uniform(-0.04, 0.04), y, rng.uniform(-0.04, 0.04)) @ Ry(rng.uniform(-0.2, 0.2)))
        y += h
    return fmodel(name, "garage", mb, (0.6, 0.5, y), cols=[((-0.3, 0, -0.25), (0.3, y, 0.25))], corner=True)


def water_heater():
    name = "RES_WaterHeater"
    mb = MB()
    mb.cyl(WHITE, (0, 0.05, 0), 0.28, 1.45, seg=12, caps=("top",))
    mb.cyl(METAL, (0, 0, 0), 0.24, 0.05, seg=8, caps=())
    for x in (-0.1, 0.1):
        mb.cyl(METAL, (x, 1.5, 0), 0.025, 0.4, seg=6, caps=())
    mb.cyl(METAL, (0, 1.5, 0.0), 0.06, 0.2, seg=8, r_top=0.08, caps=())
    mb.box(mt("PaintYellow"), (-0.12, 0.6, 0.27), (0.12, 0.8, 0.285), skip=("-z",))
    mb.box(m01("Com_SignageBacking"), (-0.08, 0.15, 0.26), (0.08, 0.3, 0.32))
    return fmodel(name, "garage", mb, (0.58, 0.6, 1.9), cols=[((-0.28, 0, -0.28), (0.28, 1.5, 0.28))], corner=True)


def electrical_panel():
    name = "RES_ElectricalPanel"
    mb = MB()
    w, h, d = 0.4, 0.6, 0.1
    mb.box(m01("Com_SignageBacking"), (-w / 2, -h / 2, 0), (w / 2, h / 2, d), skip=("-z", "+z"))
    face_quad(mb, DET, drect("breaker_panel"), -w / 2 + 0.02, -h / 2 + 0.02, w / 2 - 0.02, h / 2 - 0.02, 0.005)
    mb.cyl(METAL, (0, h / 2, d / 2), 0.025, 0.8, seg=6, caps=())
    door = MB()
    door.box(m01("Com_SignageBacking"), (0, -h / 2, 0), (w, h / 2, 0.015), skip=())
    door.box(METAL, (w - 0.06, -0.03, 0.015), (w - 0.03, 0.03, 0.03))
    return fmodel(name, "garage", mb, (w, d, h), cols=[], wall_mount=True, mount_y=1.5,
                  nodes=[{"name": "INT_CabinetDoor_Panel", "t": (-w / 2, 0, d), "mb": door,
                          "extras": {"veil_interact": "hinge", "axis": "y", "open_deg": -110}}])


def washer(name="RES_WashingMachine", dryer=False):
    mb = MB()
    w, d, h = 0.68, 0.68, 0.92
    hollow(mb, WHITE, (-w / 2, 0.02, -d / 2), (w / 2, h, d / 2), skip=("+y",) if not dryer else ())
    mb.box(WHITE, (-w / 2, h, -d / 2), (w / 2, h + 0.2, -d / 2 + 0.12))
    face_quad(mb, DET, drect("washer_panel"), -w / 2 + 0.03, h + 0.04, w / 2 - 0.03, h + 0.16, -d / 2 + 0.121)
    nodes = []
    if dryer:
        door = MB()
        door.cyl(WHITE, (0, 0, 0), 0.22, 0.04, seg=12, caps=("top",))
        door.cyl(m01("Arch_WindowGlassDirty"), (0, 0.04, 0), 0.15, 0.005, seg=12, caps=("top",))
        nd = MB()
        nd.merge(door, T(0.24, 0, 0) @ Rx(math.pi / 2))
        nodes.append({"name": "INT_ApplianceDoor_Dryer", "t": (-0.24, 0.5, d / 2), "mb": nd,
                      "extras": {"veil_interact": "hinge", "axis": "y", "open_deg": 100}})
        cols = [((-w / 2, 0, -d / 2), (w / 2, h + 0.2, d / 2))]
    else:
        mb.box(METAL, (-0.22, h - 0.3, -0.18), (0.22, h - 0.29, 0.26), skip=("-y",))
        lid = MB()
        lid.box(WHITE, (-w / 2, 0, 0), (w / 2, 0.03, d - 0.13), skip=())
        nodes.append({"name": "INT_Lid_Washer", "t": (0, h, -d / 2 + 0.12), "mb": lid,
                      "extras": {"veil_interact": "hinge", "axis": "x", "open_deg": -95}})
        cols = [((-w / 2, 0, -d / 2), (w / 2, h + 0.2, d / 2))]
    return fmodel(name, "laundry", mb, (w, d, h + 0.2), cols=cols, nodes=nodes, wall=True, clear_front=0.8)


def laundry_basket():
    name = "RES_LaundryBasket"
    mb = MB()
    mb.cyl(PLASTIC, (0, 0, 0), 0.24, 0.38, seg=10, r_top=0.28, caps=())
    mb.lump(DENIM, (0, 0.36, 0), (0.24, 0.1, 0.24), rng_of(name), subdiv=1, jitter=0.2)
    return fmodel(name, "laundry", mb, (0.56, 0.56, 0.46), cols=[((-0.25, 0, -0.25), (0.25, 0.4, 0.25))], corner=True)


def shoe_rack():
    name = "RES_ShoeRack"
    mb = MB()
    w, d, h = 0.8, 0.3, 0.45
    for y in (0.05, 0.25):
        mb.box(WOOD_L, (-w / 2, y, -d / 2), (w / 2, y + 0.02, d / 2))
    for sx in (-1, 1):
        mb.box(WOOD_L, (sx * w / 2 - (0.02 if sx > 0 else 0), 0, -d / 2), (sx * w / 2 + (0 if sx > 0 else 0.02), h, d / 2))
    for k, x in enumerate((-0.25, -0.05, 0.18)):   # sneakers / boots
        mb.box(RUBBER, (x - 0.06, 0.27, -0.12), (x + 0.06, 0.31, 0.14))
        mb.box(DENIM if k == 1 else LEATHER, (x - 0.055, 0.31, -0.1), (x + 0.055, 0.38, 0.06))
    return fmodel(name, "living", mb, (w, d, h), cols=[((-w / 2, 0, -d / 2), (w / 2, h, d / 2))], wall=True)


def newspaper():
    name = "RES_Newspaper"
    mb = MB()
    mb.box(DET, (-0.2, 0, -0.15), (0.2, 0.012, 0.15), skip=("-y",), uvrect={"+y": drect("newspaper")})
    return fmodel(name, "living", mb, (0.4, 0.3, 0.012), cols=[], on_surface=True, prop=True)


def radio():
    name = "RES_Radio"
    mb = MB()
    mb.box(WOOD_D, (-0.2, 0, -0.08), (0.2, 0.22, 0.08), uvrect={"+z": drect("keypad_radio")})
    mb.tube(METAL, [(0.15, 0.22, 0), (0.25, 0.55, 0)], 0.005, 3)
    return fmodel(name, "kitchen", mb, (0.4, 0.16, 0.22), cols=[], on_surface=True, prop=True)


def game_console():
    name = "RES_GameConsole"
    mb = MB()
    mb.box(m01("Com_SignageBacking"), (-0.15, 0, -0.1), (0.15, 0.07, 0.1))
    mb.box(m01("Furn_PlasticDirty"), (-0.06, 0.07, -0.04), (0.06, 0.1, 0.04))
    mb.box(m01("Furn_PlasticDirty"), (0.18, 0, 0.0), (0.3, 0.025, 0.06))
    mb.tube(m01("Furn_Rubber"), [(0.18, 0.012, 0.03), (0.1, 0.01, 0.12), (0.0, 0.01, 0.1)], 0.004, 3)
    return fmodel(name, "living", mb, (0.45, 0.2, 0.1), cols=[], on_surface=True, prop=True)


def storage_chest():
    name = "RES_StorageChest"
    mb = MB()
    w, d, h = 0.9, 0.45, 0.45
    hollow(mb, WOOD_D, (-w / 2, 0.04, -d / 2), (w / 2, h, d / 2), skip=("+y",))
    mb.box(METAL, (-w / 2 - 0.005, 0.15, -d / 2 - 0.005), (w / 2 + 0.005, 0.18, d / 2 + 0.005))
    legs(mb, WOOD_D, w, d, 0.04, inset=0.04, r=0.03)
    lid = MB()
    lid.box(WOOD_D, (-w / 2 - 0.01, 0, 0), (w / 2 + 0.01, 0.05, d + 0.01), skip=())
    lid.box(METAL, (-0.05, -0.04, d + 0.005), (0.05, 0.02, d + 0.02))
    return fmodel(name, "bedroom", mb, (w, d, h + 0.05), cols=[((-w / 2, 0, -d / 2), (w / 2, h + 0.05, d / 2))], wall=True,
                  nodes=[{"name": "INT_Lid_Chest", "t": (0, h, -d / 2), "mb": lid,
                          "extras": {"veil_interact": "hinge", "axis": "x", "open_deg": -100}}])


FURNITURE = [
    # living
    lambda: sofa(), lambda: sofa("RES_Sofa_Loveseat_Leather", LEATHER, 1.5, 2), lambda: armchair(), wingback,
    lambda: coffee_table(), side_table, lambda: crt_tv(), lambda: crt_tv("RES_TV_CRT_Off", on=False, wood=True), tv_console, tv_stand,
    floor_lamp, table_lamp, lambda: bookshelf(), lambda: bookshelf("RES_Bookshelf_Low", 1.2, 0.85, 2),
    lambda: rug(), lambda: rug("RES_Rug_Rect", 2.4, 1.7, m01("Int_CarpetWorn"), oval=False),
    lambda: frame("RES_Picture_Family", "photo_family", 0.36, 0.44), lambda: frame("RES_Picture_Landscape", "photo_landscape", 0.62, 0.42, WOOD_D),
    lambda: frame("RES_Painting_Barn", "painting_barn", 0.66, 0.46), lambda: curtains(),
    lambda: curtains("RES_Curtains_Plaid", mr("FabricPlaid")), wall_clock, calendar, poster, coat_rack, shoe_rack, newspaper, game_console,
    # kitchen
    lambda: fridge(), lambda: fridge("RES_Fridge_TopFreezer", WHITE, 0.8, 0.72, 1.75, True), lambda: stove(),
    lambda: stove("RES_Stove_Harvest", mr("EnamelHarvest")), lambda: counter(), lambda: counter("RES_Counter_Base_0.6", 0.6),
    lambda: counter("RES_Counter_Sink", 1.2, sink=True), counter_corner, lambda: wall_cabinet(),
    lambda: wall_cabinet("RES_WallCabinet_0.4", 0.4), island, lambda: dining_table(),
    lambda: dining_table("RES_DiningTable_Round", 1.1, round_=True, cloth=mr("Gingham")), lambda: dining_chair(),
    lambda: dining_chair("RES_DiningChair_Vinyl", True), microwave, kettle, dish_rack, dishes, trash_can, cereal_box, radio,
    # bedroom
    lambda: bed(), lambda: bed("RES_Bed_Single", 1.0, 2.0, mr("FabricPlaid"), WOOD_L), lambda: bed("RES_Bed_Double_Unmade", messy=True),
    mattress_bare, pillow, blanket_folded, nightstand, lambda: dresser(), lambda: dresser("RES_Dresser_Mirror", 1.2, 3, True),
    wardrobe, lambda: desk(), lambda: desk("RES_Desk_Computer", pc=True), desk_chair, alarm_clock, storage_chest,
    # bathroom
    toilet, lambda: bath_sink(), lambda: bath_sink("RES_BathSink_Vanity", True), bathtub, shower, bath_mirror, towel_rack, medicine_cabinet,
    # garage / basement / laundry
    lambda: shelving_metal(), toolbox, workbench, lambda: storage_bin(), lambda: cardboard_box(),
    lambda: cardboard_box("RES_CardboardBox_Open", 0.55, 0.45, 0.38, True), box_stack, water_heater, electrical_panel,
    lambda: washer(), lambda: washer("RES_Dryer", True), laundry_basket,
]
