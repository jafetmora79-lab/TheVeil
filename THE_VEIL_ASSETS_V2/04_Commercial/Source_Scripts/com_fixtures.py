"""Pack 04 modular commercial fixtures and props (Pack 03 furniture format: origin = floor centre, front = +Z,
size = (w, d, h), convex collision boxes, optional interaction points in meta["interact"]).

Stock is built as product *runs*: one block per four facings, its face mapped to a 4-facing product strip of the
Pack 04 atlas -> fully stocked shelves at roughly 10 triangles per half metre of shelf.
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

import res_materials  # noqa: E402,F401  (Pack 01/02/03 material registry)
from res_materials import m01  # noqa: E402
from furniture import fmodel, rng_of  # noqa: E402
from veil_mesh.mesh import MB, T, Ry, Rx, Rz  # noqa: E402
from veil_mesh.materials import _reg  # noqa: E402

import com_atlas as CA  # noqa: E402

ATLAS, GLASS, GLOW = "M_Com4_Atlas", "M_Com4_Glass", "M_Com4_Glow"
PNG = os.path.join(V2, "04_Commercial", "Textures", "T_Com4_Atlas.png")


def register_materials():
    base = dict(png=PNG, uv=(1.0, 1.0), repeat=False, metal=0.0, pack="04")
    _reg(ATLAS, tres="04_Commercial/Materials/M_Com4_Atlas.tres", alpha="OPAQUE", double=False, rough=0.7, **base)
    _reg(GLASS, tres="04_Commercial/Materials/M_Com4_Glass.tres", alpha="BLEND", double=True, rough=0.1, color=(1.0, 1.0, 1.0, 0.35), **base)
    _reg(GLOW, tres="04_Commercial/Materials/M_Com4_Glow.tres", alpha="OPAQUE", double=False, rough=0.5, emission=(1.0, 1.0, 1.0), energy=1.2, **base)
    return [ATLAS, GLASS, GLOW]


register_materials()
R = CA.R
STEEL = m01("Com_MetalShelving")
WOODD = m01("Furn_WoodDark")
CARD = m01("Furn_Cardboard")


def abox(mb, sw, mn, mx, faces=None, skip=("-y",), mat=ATLAS, fmats=None):
    """axis-aligned box whose every face maps to atlas rect `sw` (faces={face: rect} overrides)"""
    ur = {f: R((faces or {}).get(f, sw)) for f in ("+x", "-x", "+y", "-y", "+z", "-z")}
    mb.box(mat, mn, mx, skip=skip, uvrect=ur, mats=fmats)


def decal(mb, rect, c, w, h, face="+z", mat=ATLAS, lift=0.003):
    """flat sign / label quad facing `face`"""
    x, y, z = c
    u0, v0, u1, v1 = R(rect)
    uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
    if face == "+z":
        pts, n = [(x - w / 2, y - h / 2, z + lift), (x + w / 2, y - h / 2, z + lift), (x + w / 2, y + h / 2, z + lift), (x - w / 2, y + h / 2, z + lift)], (0, 0, 1)
    elif face == "-z":
        pts, n = [(x + w / 2, y - h / 2, z - lift), (x - w / 2, y - h / 2, z - lift), (x - w / 2, y + h / 2, z - lift), (x + w / 2, y + h / 2, z - lift)], (0, 0, -1)
    elif face == "+x":
        pts, n = [(x + lift, y - h / 2, z + w / 2), (x + lift, y - h / 2, z - w / 2), (x + lift, y + h / 2, z - w / 2), (x + lift, y + h / 2, z + w / 2)], (1, 0, 0)
    elif face == "-x":
        pts, n = [(x - lift, y - h / 2, z - w / 2), (x - lift, y - h / 2, z + w / 2), (x - lift, y + h / 2, z + w / 2), (x - lift, y + h / 2, z - w / 2)], (-1, 0, 0)
    else:  # +y
        pts, n = [(x - w / 2, y + lift, z + h / 2), (x + w / 2, y + lift, z + h / 2), (x + w / 2, y + lift, z - h / 2), (x - w / 2, y + lift, z - h / 2)], (0, 1, 0)
    mb.quad(mat, *pts, n=n, uv=uv)


def stock_run(mb, x0, x1, y, zf, depth, h, strip, face=+1, facing=0.12, gap=0.004):
    """row of product blocks from x0..x1 standing on y, front face at z = zf facing +z (face=+1) or -z (face=-1)"""
    blk = 4 * facing
    u0, v0, u1, v1 = R(strip)
    x = x0
    while x < x1 - 0.05:
        xe = min(x + blk, x1)
        f = (xe - x) / blk
        if face > 0:
            z0, z1 = zf - depth, zf
        else:
            z0, z1 = zf, zf + depth
        ur = (u0, v0, u0 + (u1 - u0) * f, v1)
        side = (u0, v0, u0 + (u1 - u0) * 0.25, v1)
        top = (u0, v0, u0 + (u1 - u0) * f, v0 + (v1 - v0) * 0.2)
        rects = {"+z" if face > 0 else "-z": ur, "+x": side, "-x": side, "+y": top, "-z" if face > 0 else "+z": side}
        mb.box(ATLAS, (x + gap, y, z0), (xe - gap, y + h, z1), skip=("-y", "-z" if face > 0 else "+z"), uvrect=rects)
        x = xe


def solid(mb, sw, fn, *args, **kw):
    """cylinder / tube with every UV pinned to the centre of atlas swatch `sw`"""
    tmp = MB()
    getattr(tmp, fn)(ATLAS, *args, **kw)
    u0, v0, u1, v1 = R(sw)
    g = tmp.parts[ATLAS]
    g["uv"] = [[(u0 + u1) / 2, (v0 + v1) / 2] for _ in g["uv"]]
    mb.merge(tmp)


def interact(meta, name, p, kind):
    meta.setdefault("interact", []).append(dict(name=name, pos=[round(float(v), 3) for v in p], kind=kind))


def fx(name, cat, mb, size, cols, **meta):
    for mat in (ATLAS, GLASS, GLOW):
        g = mb.parts.get(mat)
        if g and g["uv"]:
            uv = np.asarray(g["uv"])
            assert uv.min() >= -1e-6 and uv.max() <= 1 + 1e-6, (name, mat, uv.min(), uv.max())
    m = fmodel(name, cat, mb, size, cols=cols, **meta)
    m["meta"]["pack"] = "04"
    return m


# =================================================================== shelving
def gondola(name, L, H, strips_front, strips_back, levels=None, endcap=True, sign=None):
    """double-sided gondola: length L along x, 1.0 m deep, stock faces +z (front) and -z (back)"""
    mb = MB()
    d = 0.5
    levels = levels or [0.12, 0.52, 0.92, 1.32][: max(2, int((H - 0.2) / 0.4))]
    abox(mb, "steel_dark", (-L / 2, 0, -d + 0.04), (L / 2, 0.12, d - 0.04), skip=("-y",))           # base / kick plate
    abox(mb, "pegboard", (-L / 2, 0.12, -0.04), (L / 2, H, 0.04), skip=("-y",))                    # spine
    abox(mb, "enamel_gray", (-L / 2, H - 0.06, -0.06), (L / 2, H, 0.06))
    for sx in (-1, 1):                                                                           # end uprights
        abox(mb, "enamel_gray", (sx * L / 2 - 0.03, 0, -d), (sx * L / 2 + 0.03, H, d), skip=("-y",))
    for k, y in enumerate(levels):
        for side, strips in ((1, strips_front), (-1, strips_back)):
            if not strips:
                continue
            z_edge = side * (d - 0.02)
            if k > 0:
                abox(mb, "enamel_white", (-L / 2 + 0.03, y - 0.03, min(0.04 * side, z_edge)), (L / 2 - 0.03, y, max(0.04 * side, z_edge)))
            # price-tag strip on the shelf edge
            decal(mb, "pricetags", (0, y - 0.015, z_edge), L - 0.08, 0.03, face="+z" if side > 0 else "-z", lift=0.001)
            hh = min(0.32, (levels[k + 1] - y - 0.06) if k + 1 < len(levels) else H - y - 0.12)
            stock_run(mb, -L / 2 + 0.04, L / 2 - 0.04, y, z_edge - side * 0.03, 0.34, hh, strips[k % len(strips)], face=side)
    if endcap:
        for sx in (-1, 1):
            for k, y in enumerate(levels[:3]):
                x_out = sx * (L / 2 + 0.32)
                abox(mb, "enamel_white", (min(sx * L / 2, x_out), y - 0.03, -0.45), (max(sx * L / 2, x_out), y, 0.45))
                st = (strips_front or strips_back)[(k + (sx > 0)) % len(strips_front or strips_back)]
                u0, v0, u1, v1 = R(st)
                xa, xb = sorted((sx * (L / 2 + 0.03), x_out - sx * 0.02))
                mb.box(ATLAS, (xa, y, -0.42), (xb, y + 0.30, 0.42), skip=("-y",),
                       uvrect={("+x" if sx > 0 else "-x"): (u0, v0, u1, v1), "+y": (u0, v0, u1, v0 + (v1 - v0) * 0.2),
                               "+z": (u0, v0, u0 + (u1 - u0) * 0.5, v1), "-z": (u0, v0, u0 + (u1 - u0) * 0.5, v1),
                               ("-x" if sx > 0 else "+x"): (u0, v0, u1, v1)})
    if sign:
        mb.box(ATLAS, (-0.01, H, -0.01), (0.01, H + 0.22, 0.01), uvrect={f: R("steel") for f in ("+x", "-x", "+z", "-z", "+y")})
    W = L + (0.68 if endcap else 0.0)
    return fx(name, "shelving", mb, (W, 1.0, H), cols=[((-W / 2, 0, -d), (W / 2, H, d))])


def wall_shelf(name, L, H, strips, header=None, depth=0.45, slat=False):
    """single-sided wall unit, back against -z, stock facing +z"""
    mb = MB()
    abox(mb, "steel_dark", (-L / 2, 0, -depth / 2), (L / 2, 0.12, depth / 2))
    abox(mb, "slat" if False else ("pegboard" if not slat else "laminate_gray"), (-L / 2, 0.12, -depth / 2), (L / 2, H, -depth / 2 + 0.04))
    for sx in (-1, 1):
        abox(mb, "enamel_gray", (sx * L / 2 - 0.03, 0, -depth / 2), (sx * L / 2 + 0.03, H, depth / 2))
    levels = [0.12 + k * 0.38 for k in range(int((H - 0.3) / 0.38) + 1)]
    for k, y in enumerate(levels):
        if k > 0:
            abox(mb, "enamel_white", (-L / 2 + 0.03, y - 0.03, -depth / 2 + 0.04), (L / 2 - 0.03, y, depth / 2))
        decal(mb, "pricetags", (0, y - 0.015, depth / 2), L - 0.08, 0.03, lift=0.001)
        hh = min(0.30, (levels[k + 1] - y - 0.05) if k + 1 < len(levels) else H - y - 0.1)
        stock_run(mb, -L / 2 + 0.04, L / 2 - 0.04, y, depth / 2 - 0.03, min(0.3, depth - 0.1), hh, strips[k % len(strips)],
                  facing=0.14 if strips[k % len(strips)].startswith("games") else 0.12)
    if header:
        abox(mb, "navy_paint", (-L / 2, H, -depth / 2), (L / 2, H + 0.25, -depth / 2 + 0.06))
        decal(mb, header, (0, H + 0.125, -depth / 2 + 0.06), min(L - 0.2, 1.2), 0.22)
    return fx(name, "shelving", mb, (L, depth, H + (0.25 if header else 0)), cols=[((-L / 2, 0, -depth / 2), (L / 2, H, depth / 2))], wall=True)


def cooler(name, doors, strips, header, frost=False):
    """glass-door reach-in cooler / freezer, back against -z"""
    mb = MB()
    dw, d, H = 0.78, 0.8, 2.1
    L = doors * dw
    abox(mb, "enamel_white", (-L / 2, 0, -d / 2), (L / 2, H, -d / 2 + 0.05))          # back
    abox(mb, "cooler_in", (-L / 2 + 0.04, 0.15, -d / 2 + 0.05), (L / 2 - 0.04, 1.85, -d / 2 + 0.06), skip=("-y", "-z"))
    abox(mb, "enamel_white", (-L / 2, 0, -d / 2), (L / 2, 0.15, d / 2))               # plinth
    abox(mb, "enamel_white", (-L / 2, 1.85, -d / 2), (L / 2, H, d / 2))               # header
    for sx in (-1, 1):
        abox(mb, "enamel_white", (sx * L / 2 - 0.04 * (sx > 0), 0, -d / 2), (sx * L / 2 + 0.04 * (sx < 0), H, d / 2))
    decal(mb, header, (0, 1.975, d / 2), min(L - 0.3, 1.2), 0.2, mat=GLOW)
    levels = [0.15, 0.55, 0.95, 1.35]
    for k, y in enumerate(levels):
        if k > 0:
            abox(mb, "chrome", (-L / 2 + 0.04, y - 0.02, -d / 2 + 0.06), (L / 2 - 0.04, y, d / 2 - 0.12))
        stock_run(mb, -L / 2 + 0.05, L / 2 - 0.05, y, d / 2 - 0.14, 0.4, 0.3 if k < 3 else 0.32, strips[k % len(strips)])
    mb.box(GLOW, (-L / 2 + 0.05, 1.82, -d / 2 + 0.06), (L / 2 - 0.05, 1.85, -d / 2 + 0.12), uvrect={f: R("light_panel") for f in ("+x", "-x", "-y", "+z", "-z", "+y")})
    for i in range(doors):
        x0 = -L / 2 + i * dw
        abox(mb, "chrome", (x0 + 0.02, 0.15, d / 2 - 0.04), (x0 + 0.05, 1.85, d / 2), skip=())
        abox(mb, "chrome", (x0 + dw - 0.05, 0.15, d / 2 - 0.04), (x0 + dw - 0.02, 1.85, d / 2), skip=())
        mb.box(GLASS, (x0 + 0.05, 0.17, d / 2 - 0.025), (x0 + dw - 0.05, 1.83, d / 2 - 0.015), skip=(),
               uvrect={f: R("frost" if frost else "glass_tint") for f in ("+x", "-x", "+y", "-y", "+z", "-z")})
        abox(mb, "chrome", (x0 + dw - 0.12, 0.7, d / 2), (x0 + dw - 0.09, 1.4, d / 2 + 0.05), skip=())
    meta = {}
    for i in range(doors):
        interact(meta, f"CoolerDoor_{i + 1}", (-L / 2 + (i + 0.5) * dw, 1.0, d / 2 + 0.1), "cooler_door")
    return fx(name, "refrigeration", mb, (L, d, H), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))], wall=True, **meta)


def chest_freezer(name="COM_Freezer_Chest"):
    mb = MB()
    L, d, H = 2.4, 0.95, 0.88
    abox(mb, "enamel_white", (-L / 2, 0, -d / 2), (L / 2, H, d / 2), skip=("-y", "+y"))
    abox(mb, "steel_dark", (-L / 2, 0, -d / 2 - 0.01), (L / 2, 0.12, d / 2 + 0.01))
    abox(mb, "cooler_in", (-L / 2 + 0.06, 0.3, -d / 2 + 0.06), (L / 2 - 0.06, 0.32, d / 2 - 0.06))
    for i, st in enumerate(("pizza", "frozen_veg", "icecream")):
        x0 = -L / 2 + 0.08 + i * (L - 0.16) / 3
        u0, v0, u1, v1 = R(st)
        mb.box(ATLAS, (x0 + 0.02, 0.32, -d / 2 + 0.1), (x0 + (L - 0.16) / 3 - 0.02, 0.72, d / 2 - 0.1), skip=("-y",),
               uvrect={"+y": (u0, v0, u1, v1), "+z": (u0, v0, u1, v1), "-z": (u0, v0, u1, v1), "+x": (u0, v0, u1, v1), "-x": (u0, v0, u1, v1)})
    for k in range(2):
        z0 = -d / 2 + 0.05 + k * (d - 0.1) / 2
        mb.box(GLASS, (-L / 2 + 0.05, H - 0.02, z0), (L / 2 - 0.05, H - 0.01, z0 + (d - 0.1) / 2), skip=(),
               uvrect={f: R("frost") for f in ("+x", "-x", "+y", "-y", "+z", "-z")})
    abox(mb, "chrome", (-L / 2, H - 0.03, -d / 2), (L / 2, H, -d / 2 + 0.05))
    abox(mb, "chrome", (-L / 2, H - 0.03, d / 2 - 0.05), (L / 2, H, d / 2))
    decal(mb, "aisle_frozen", (0, 0.55, d / 2), 0.6, 0.15)
    decal(mb, "aisle_frozen", (0, 0.55, -d / 2), 0.6, 0.15, face="-z")
    meta = {}
    interact(meta, "FreezerLid", (0, H + 0.1, 0), "freezer_lid")
    return fx(name, "refrigeration", mb, (L, d, H), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))], **meta)


def produce_table(name="COM_Produce_Table"):
    mb = MB()
    L, d, H = 2.2, 1.3, 0.85
    abox(mb, "crate_wood", (-L / 2, 0, -d / 2), (L / 2, 0.55, d / 2), skip=("-y",))
    kinds = ["apples", "oranges", "bananas", "lettuce", "potatoes", "tomatoes"]
    for i in range(3):
        for j in range(2):
            x0 = -L / 2 + 0.04 + i * (L - 0.08) / 3
            z0 = -d / 2 + 0.04 + j * (d - 0.08) / 2
            x1, z1 = x0 + (L - 0.08) / 3 - 0.04, z0 + (d - 0.08) / 2 - 0.04
            sw = kinds[(i * 2 + j) % len(kinds)]
            h_back = 0.85 if j == 0 else 0.72
            mb.box(ATLAS, (x0, 0.55, z0), (x1, h_back - 0.04, z1), skip=("-y", "+y"), uvrect={f: R("crate_wood") for f in ("+x", "-x", "+z", "-z")})
            u0, v0, u1, v1 = R(sw)
            mb.quad(ATLAS, (x0, h_back - 0.03, z1), (x1, h_back - 0.03, z1), (x1, h_back + 0.02, z0), (x0, h_back + 0.02, z0), n=(0, 0.97, 0.24),
                    uv=[(u0, v1), (u1, v1), (u1, v0), (u0, v0)])
    decal(mb, "produce_banner", (0, 0.35, d / 2), 0.7, 0.18)
    return fx(name, "produce", mb, (L, d, H), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))])


def produce_case(name="COM_Produce_WallCase"):
    mb = MB()
    L, d, H = 2.4, 0.9, 2.0
    abox(mb, "enamel_white", (-L / 2, 0, -d / 2), (L / 2, H, -d / 2 + 0.06))
    abox(mb, "enamel_white", (-L / 2, 1.8, -d / 2), (L / 2, H, 0.0))
    for sx in (-1, 1):
        abox(mb, "enamel_white", (sx * L / 2 - 0.04 * (sx > 0), 0, -d / 2), (sx * L / 2 + 0.04 * (sx < 0), H, d / 2 - 0.3))
    kinds = ["lettuce", "tomatoes", "apples", "oranges", "bananas", "potatoes"]
    for k, (y, z0, z1) in enumerate(((0.0, -d / 2 + 0.06, d / 2), (0.75, -d / 2 + 0.06, 0.15), (1.2, -d / 2 + 0.06, -0.05))):
        abox(mb, "enamel_white", (-L / 2 + 0.04, y, z0), (L / 2 - 0.04, y + 0.55, z1), skip=("-y",) if y == 0 else ())
        for i in range(3):
            x0 = -L / 2 + 0.06 + i * (L - 0.12) / 3
            x1 = x0 + (L - 0.12) / 3 - 0.03
            u0, v0, u1, v1 = R(kinds[(k * 3 + i) % len(kinds)])
            yy = y + 0.56
            mb.quad(ATLAS, (x0, yy, z1 - 0.02), (x1, yy, z1 - 0.02), (x1, yy + 0.08, z0 + 0.05), (x0, yy + 0.08, z0 + 0.05), n=(0, 0.98, 0.2),
                    uv=[(u0, v1), (u1, v1), (u1, v0), (u0, v0)])
    mb.box(GLOW, (-L / 2 + 0.05, 1.77, -d / 2 + 0.06), (L / 2 - 0.05, 1.8, -0.1), uvrect={f: R("light_panel") for f in ("+x", "-x", "-y", "+z", "-z", "+y")})
    decal(mb, "aisle_produce", (0, 1.9, 0.0), 0.8, 0.18)
    return fx(name, "produce", mb, (L, d, H), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))], wall=True)


# =================================================================== counters / checkouts
def register(mb, x, y, z, face=1):
    abox(mb, "gray_plastic", (x - 0.2, y, z - 0.18), (x + 0.2, y + 0.12, z + 0.18), faces={"+z" if face > 0 else "-z": "register"})
    abox(mb, "black_plastic", (x - 0.05, y + 0.12, z - 0.03), (x + 0.05, y + 0.3, z + 0.03))
    abox(mb, "black_plastic", (x - 0.16, y + 0.3, z - 0.06), (x + 0.16, y + 0.5, z + 0.06), faces={"+z" if face > 0 else "-z": "monitor"})
    abox(mb, "gray_plastic", (x - 0.22, y - 0.1, z - 0.2), (x + 0.22, y, z + 0.2))   # cash drawer


def checkout_lane(name="COM_Checkout_Lane"):
    """customer walks along +z side; cashier stands on the -z side at the +x end; conveyor along x"""
    mb = MB()
    L, d, H = 2.8, 0.8, 0.9
    abox(mb, "laminate_cream", (-L / 2, 0, -d / 2), (L / 2, H - 0.05, d / 2), skip=("-y",), faces={"+z": "laminate_gray"})
    abox(mb, "chrome", (-L / 2, H - 0.05, -d / 2), (L / 2, H, d / 2))
    mb.box(ATLAS, (-L / 2 + 0.05, H, -0.3), (0.6, H + 0.02, 0.3), uvrect={f: R("conveyor") for f in ("+x", "-x", "+y", "+z", "-z")})
    abox(mb, "black_plastic", (-0.6, H + 0.02, -0.02), (-0.2, H + 0.06, 0.02))          # divider bar
    abox(mb, "black_plastic", (-1.0, H + 0.02, -0.25), (-0.95, H + 0.08, 0.25))
    register(mb, 1.0, H, -0.15, face=-1)
    abox(mb, "black_plastic", (0.75, H, 0.22), (0.9, H + 0.25, 0.32), faces={"+z": "monitor"})                # card reader
    abox(mb, "steel", (L / 2 - 0.02, 0.6, -0.3), (L / 2 + 0.45, 0.62, 0.3))               # bagging shelf
    for k in range(2):
        abox(mb, "cardboard", (L / 2 + 0.03 + k * 0.2, 0.62, -0.1), (L / 2 + 0.2 + k * 0.2, 0.98, 0.1), skip=("-y",))
    abox(mb, "black_plastic", (-L / 2 + 0.1, 0, d / 2), (-L / 2 + 0.6, 1.3, d / 2 + 0.25), faces={"+z": "candy_rack", "-x": "candy_rack"})
    abox(mb, "steel", (L / 2 - 0.05, 0, -d / 2), (L / 2, 2.2, -d / 2 + 0.05))               # lane light pole
    mb.box(GLOW, (L / 2 - 0.15, 2.2, -d / 2 - 0.05), (L / 2 + 0.1, 2.4, -d / 2 + 0.15), uvrect={f: R("light_panel") for f in ("+x", "-x", "-y", "+z", "-z", "+y")})
    meta = {}
    interact(meta, "Register", (1.0, H + 0.2, -0.6), "register")
    interact(meta, "Conveyor", (-0.4, H + 0.05, 0.6), "checkout")
    return fx(name, "checkout", mb, (L + 0.5, d + 0.25, H), cols=[((-L / 2, 0, -d / 2), (L / 2, 1.0, d / 2 + 0.25))], **meta)


def counter(name, L=2.4, d=0.7, H=1.0, top="counter_wood", front="laminate_cream", glass_front=False, reg=True, header=None, extra=None):
    """retail / service counter; customer side +z, staff side -z"""
    mb = MB()
    abox(mb, front, (-L / 2, 0, -d / 2), (L / 2, H - 0.04, d / 2), skip=("-y",), faces={"-z": "wood_dark"})
    abox(mb, top, (-L / 2 - 0.03, H - 0.04, -d / 2), (L / 2 + 0.03, H, d / 2 + 0.03))
    if glass_front:
        mb.box(GLASS, (-L / 2 + 0.1, 0.25, d / 2 + 0.002), (L / 2 - 0.1, H - 0.1, d / 2 + 0.01), skip=(),
               uvrect={f: R("glass_tint") for f in ("+x", "-x", "+y", "-y", "+z", "-z")})
        stock_run(mb, -L / 2 + 0.15, L / 2 - 0.15, 0.3, d / 2 - 0.05, 0.25, 0.25, "games_b")
    abox(mb, "wood_dark", (-L / 2 + 0.05, 0.35, -d / 2 - 0.01), (L / 2 - 0.05, 0.37, -0.05))     # staff-side shelf
    stock_run(mb, -L / 2 + 0.1, 0, 0.37, -d / 2 + 0.3, 0.28, 0.24, "bankers", face=1)
    if reg:
        register(mb, L / 2 - 0.45, H, -0.1, face=-1)
    if header:
        abox(mb, "steel", (-0.02, H, -d / 2 + 0.02), (0.02, 2.0, -d / 2 + 0.06))
        abox(mb, "navy_paint", (-0.6, 2.0, -d / 2 + 0.02), (0.6, 2.3, -d / 2 + 0.06), faces={"+z": header, "-z": header})
    if extra:
        extra(mb, L, d, H)
    meta = {}
    if reg:
        interact(meta, "Register", (L / 2 - 0.45, H + 0.2, -d / 2 - 0.4), "register")
    interact(meta, "Counter", (0, H, d / 2 + 0.4), "counter")
    return fx(name, "counter", mb, (L + 0.06, d + 0.03, H), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))], **meta)


def pharmacy_extra(mb, L, d, H):
    abox(mb, "enamel_white", (-L / 2, H, -0.02), (L / 2, 1.35, 0.02), faces={})
    mb.box(GLASS, (-L / 2, 1.35, -0.01), (L / 2, 2.1, 0.01), skip=(), uvrect={f: R("glass_tint") for f in ("+x", "-x", "+y", "-y", "+z", "-z")})
    abox(mb, "red_plastic", (-L / 2, 2.1, -0.05), (L / 2, 2.45, 0.05), faces={"+z": "pharmacy", "-z": "pharmacy"})
    for k in range(3):
        abox(mb, "paper", (-0.9 + k * 0.25, H, 0.05), (-0.75 + k * 0.25, H + 0.22, 0.15))     # pick-up bags


def coffee_extra(mb, L, d, H):
    abox(mb, "black_plastic", (-0.6, H, -d / 2 + 0.02), (0.2, H + 0.6, -0.05), faces={"+z": "coffee_machine"})
    for k in range(4):
        solid(mb, "paper", "cyl", (0.4 + k * 0.1, H, 0.05), 0.04, 0.12, seg=6)
    abox(mb, "wood_dark", (-L / 2, 1.9, -d / 2), (L / 2, 2.15, -d / 2 + 0.04), faces={"+z": "coffee_sign"})


def service_extra(mb, L, d, H):
    for k in range(3):
        abox(mb, "bell_papers", (-0.8 + k * 0.3, H, -0.1), (-0.6 + k * 0.3, H + 0.01, 0.15), faces={"+y": "bell_papers"})


# =================================================================== supermarket props
def basket_stack(name="COM_BasketStack"):
    mb = MB()
    abox(mb, "steel_dark", (-0.25, 0, -0.2), (0.25, 0.08, 0.2))
    for k in range(6):
        y = 0.08 + k * 0.08
        abox(mb, "red_plastic", (-0.22, y, -0.17), (0.22, y + 0.12, 0.17), skip=("-y",))
    abox(mb, "black_plastic", (-0.02, 0.6, -0.17), (0.02, 0.72, 0.17))
    return fx(name, "supermarket", mb, (0.5, 0.4, 0.72), cols=[((-0.25, 0, -0.2), (0.25, 0.72, 0.2))])


def cart_corral(name="COM_CartCorral"):
    mb = MB()
    L, d, H = 3.2, 1.3, 1.05
    for sz in (-1, 1):
        for x in np.linspace(-L / 2, L / 2, 5):
            solid(mb, "chrome", "tube", [(x, 0, sz * d / 2), (x, H, sz * d / 2)], 0.025, 6)
        solid(mb, "chrome", "tube", [(-L / 2, H, sz * d / 2), (L / 2, H, sz * d / 2)], 0.025, 6)
        solid(mb, "chrome", "tube", [(-L / 2, 0.45, sz * d / 2), (L / 2, 0.45, sz * d / 2)], 0.02, 6)
    solid(mb, "chrome", "tube", [(L / 2, H, -d / 2), (L / 2, H, d / 2)], 0.025, 6)
    abox(mb, "steel", (L / 2 - 0.04, 0, -0.04), (L / 2 + 0.04, 2.0, 0.04))
    abox(mb, "green_paint", (L / 2 - 0.02, 1.55, -0.45), (L / 2 + 0.02, 2.0, 0.45), faces={"+x": "cart_return", "-x": "cart_return"})
    return fx(name, "supermarket", mb, (L, d, 2.0), cols=[((-L / 2, 0, -d / 2 - 0.03), (L / 2, H, -d / 2 + 0.03)), ((-L / 2, 0, d / 2 - 0.03), (L / 2, H, d / 2 + 0.03)),
                                                          ((L / 2 - 0.05, 0, -d / 2), (L / 2 + 0.05, 2.0, d / 2))])


def _uv_tubes(mb, sw):
    """MB.tube writes metric UVs; squeeze every atlas vertex into one swatch (keeps UVs inside the atlas)"""
    g = mb.parts.get(ATLAS)
    if not g:
        return
    u0, v0, u1, v1 = R(sw)
    for uv in g["uv"]:
        if not (0 <= uv[0] <= 1 and 0 <= uv[1] <= 1):
            uv[0], uv[1] = (u0 + u1) / 2, (v0 + v1) / 2


def grocery_bag(name="COM_GroceryBag"):
    mb = MB()
    abox(mb, "cardboard", (-0.16, 0, -0.09), (0.16, 0.42, 0.09), skip=("-y",), faces={"+y": "cardboard"})
    abox(mb, "lettuce", (-0.12, 0.42, -0.06), (0.0, 0.5, 0.06), skip=("-y",))
    abox(mb, "bread", (0.0, 0.42, -0.05), (0.12, 0.55, 0.05), skip=("-y",), faces={"+z": "bread"})
    decal(mb, "sign_market_sub", (0, 0.25, 0.09), 0.28, 0.05, lift=0.002)
    return fx(name, "supermarket", mb, (0.32, 0.18, 0.55), cols=[((-0.16, 0, -0.09), (0.16, 0.5, 0.09))], on_surface=True)


def pallet_stack(name="COM_PalletStack"):
    mb = MB()
    abox(mb, "crate_wood", (-0.6, 0, -0.5), (0.6, 0.14, 0.5), skip=("-y",))
    for k in range(3):
        for i in range(2):
            for j in range(2):
                abox(mb, "cardboard", (-0.58 + i * 0.6, 0.14 + k * 0.4, -0.48 + j * 0.5), (-0.02 + i * 0.6, 0.53 + k * 0.4, 0.0 + j * 0.48), skip=("-y",),
                     faces={"+z": "bankers" if (i + k) % 2 else "cardboard"})
    return fx(name, "storage", mb, (1.2, 1.0, 1.35), cols=[((-0.6, 0, -0.5), (0.6, 1.35, 0.5))])


def pallet_rack(name="COM_PalletRack"):
    mb = MB()
    L, d, H = 2.7, 1.0, 3.0
    for sx in (-1, 1):
        for sz in (-1, 1):
            abox(mb, "blue_paint", (sx * L / 2 - 0.04 * (sx > 0), 0, sz * d / 2 - 0.04 * (sz > 0)), (sx * L / 2 + 0.04 * (sx < 0), H, sz * d / 2 + 0.04 * (sz < 0)), skip=())
    for y in (0.15, 1.5, 2.85):
        for sz in (-1, 1):
            abox(mb, "orange_paint", (-L / 2, y - 0.1, sz * d / 2 - 0.05 * (sz > 0)), (L / 2, y, sz * d / 2 + 0.05 * (sz < 0)))
        abox(mb, "crate_wood", (-L / 2 + 0.06, y, -d / 2 + 0.02), (-0.04, y + 0.13, d / 2 - 0.02))
        abox(mb, "crate_wood", (0.04, y, -d / 2 + 0.02), (L / 2 - 0.06, y + 0.13, d / 2 - 0.02))
        if y < 2.8:
            for i in range(2):
                abox(mb, "cardboard", (-L / 2 + 0.1 + i * 1.32, y + 0.13, -0.45), (-L / 2 + 1.25 + i * 1.32, y + 1.0 - 0.1 * i, 0.45), skip=("-y",),
                     faces={"+z": "bankers", "-z": "bankers"})
    return fx(name, "storage", mb, (L, d, H), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))], wall=True)


# =================================================================== game shop
def game_rack(name, header, strips):
    """double-sided tiered island rack, 1.8 m long"""
    mb = MB()
    L, d, H = 1.8, 0.9, 1.35
    abox(mb, "black_plastic", (-L / 2, 0, -d / 2), (L / 2, 0.15, d / 2))
    abox(mb, "laminate_gray", (-L / 2, 0.15, -0.05), (L / 2, H, 0.05))
    for sx in (-1, 1):
        abox(mb, "black_plastic", (sx * L / 2 - 0.03, 0, -d / 2), (sx * L / 2 + 0.03, H, d / 2))
    for side in (1, -1):
        for k in range(4):
            y = 0.15 + k * 0.29
            z_out = side * (d / 2 - 0.05 - k * 0.07)
            abox(mb, "black_plastic", (-L / 2 + 0.03, y - 0.02, min(0.05 * side, z_out)), (L / 2 - 0.03, y, max(0.05 * side, z_out)))
            stock_run(mb, -L / 2 + 0.05, L / 2 - 0.05, y, z_out - side * 0.02, 0.12, 0.2, strips[(k + (side < 0)) % len(strips)], face=side, facing=0.135)
    abox(mb, "steel", (-0.02, H, -0.02), (0.02, H + 0.2, 0.02))
    abox(mb, "red_plastic" if header == "new_rel" else "yellow_paint", (-0.5, H + 0.2, -0.03), (0.5, H + 0.45, 0.03), faces={"+z": header, "-z": header})
    meta = {}
    interact(meta, "Browse", (0, 1.0, d / 2 + 0.4), "browse")
    return fx(name, "games", mb, (L, d, H + 0.45), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))], **meta)


def console_case(name="COM_ConsoleCase"):
    mb = MB()
    L, d, H = 1.6, 0.6, 1.0
    abox(mb, "black_plastic", (-L / 2, 0, -d / 2), (L / 2, 0.4, d / 2), skip=("-y",))
    mb.box(GLASS, (-L / 2, 0.4, -d / 2), (L / 2, H, d / 2), skip=("-y",), uvrect={f: R("glass_tint") for f in ("+x", "-x", "+y", "+z", "-z")})
    abox(mb, "black_plastic", (-L / 2 + 0.02, 0.4, -d / 2 + 0.02), (L / 2 - 0.02, 0.42, d / 2 - 0.02))
    stock_run(mb, -L / 2 + 0.1, L / 2 - 0.1, 0.42, 0.15, 0.3, 0.32, "consoles_boxes", facing=0.18)
    for k in range(3):
        abox(mb, "gray_plastic", (-0.6 + k * 0.45, 0.42, 0.18), (-0.45 + k * 0.45, 0.46, 0.26))       # controllers
    meta = {}
    interact(meta, "Display", (0, 0.9, d / 2 + 0.4), "browse")
    return fx(name, "games", mb, (L, d, H), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))], **meta)


def demo_station(name="COM_DemoStation"):
    mb = MB()
    abox(mb, "navy_paint", (-0.45, 0, -0.3), (0.45, 1.0, 0.3), skip=("-y",), faces={"+z": "playnow"})
    abox(mb, "black_plastic", (-0.36, 1.0, -0.28), (0.36, 1.55, 0.18))                  # CRT body
    abox(mb, "black_plastic", (-0.2, 1.05, -0.42), (0.2, 1.45, -0.28))
    mb.box(GLOW, (-0.3, 1.06, 0.18), (0.3, 1.5, 0.19), uvrect={f: R("crt_screen") for f in ("+z", "-z", "+x", "-x", "+y", "-y")})
    abox(mb, "gray_plastic", (-0.12, 1.0, 0.24), (0.12, 1.03, 0.32))                     # controller
    solid(mb, "black_plastic", "tube", [(0.0, 1.02, 0.24), (0.1, 1.0, 0.2), (0.2, 1.1, 0.0)], 0.006, 4)
    abox(mb, "green_paint", (-0.45, 1.55, -0.3), (0.45, 1.8, -0.26), faces={"+z": "playnow"})
    meta = {}
    interact(meta, "DemoController", (0, 1.05, 0.7), "demo_station")
    return fx(name, "games", mb, (0.9, 0.6, 1.8), cols=[((-0.45, 0, -0.3), (0.45, 1.55, 0.3))], **meta)


def poster_board(name="COM_PosterBoard", posters=(0, 1, 2)):
    mb = MB()
    L = 0.7 * len(posters)
    abox(mb, "black_plastic", (-L / 2, 0, -0.02), (L / 2, 0.95, 0.0))
    for i, p in enumerate(posters):
        decal(mb, f"poster_{p}", (-L / 2 + 0.35 + i * 0.7, 0.475, 0.0), 0.62, 0.85, lift=0.002)
    return fx(name, "decor", mb, (L, 0.03, 0.95), cols=[], wall_mounted=True)


# =================================================================== gas station
def fuel_pump(name="COM_FuelPump"):
    mb = MB()
    abox(mb, "concrete", (-0.55, 0, -0.32), (0.55, 0.1, 0.32))
    abox(mb, "enamel_white", (-0.5, 0.1, -0.28), (0.5, 1.25, 0.28), faces={"+z": "pump_face", "-z": "pump_face"})
    abox(mb, "red_plastic", (-0.5, 1.25, -0.28), (0.5, 1.9, 0.28), faces={"+z": "sign_fuel", "-z": "sign_fuel", "+x": "red_plastic"})
    for sx in (-1, 1):
        abox(mb, "black_plastic", (sx * 0.5 - 0.06 * (sx > 0), 0.75, -0.1), (sx * 0.5 + 0.06 * (sx < 0), 1.05, 0.1))   # nozzle holster
        solid(mb, "rubber", "tube", [(sx * 0.53, 0.95, 0.0), (sx * 0.62, 0.6, 0.05), (sx * 0.58, 0.3, 0.15), (sx * 0.5, 0.2, 0.25)], 0.018, 5)
    meta = {}
    interact(meta, "Nozzle_A", (-0.75, 1.0, 0.0), "fuel_nozzle")
    interact(meta, "Nozzle_B", (0.75, 1.0, 0.0), "fuel_nozzle")
    return fx(name, "gas", mb, (1.1, 0.64, 1.9), cols=[((-0.55, 0, -0.32), (0.55, 1.9, 0.32))], **meta)


def pump_island(name="COM_PumpIsland"):
    mb = MB()
    L, d = 5.0, 1.3
    abox(mb, "concrete", (-L / 2, 0, -d / 2), (L / 2, 0.16, d / 2), skip=("-y",), faces={"+z": "yellow_paint", "-z": "yellow_paint", "+x": "yellow_paint", "-x": "yellow_paint"})
    for sx in (-1, 1):
        solid(mb, "yellow_paint", "cyl", (sx * (L / 2 - 0.15), 0.16, 0), 0.08, 0.9, seg=8, caps=("top",))
    abox(mb, "black_plastic", (1.0, 0.16, -0.2), (1.4, 0.75, 0.2), skip=("-y",))       # squeegee / trash post
    return fx(name, "gas", mb, (L, d, 1.06), cols=[((-L / 2, 0, -d / 2), (L / 2, 0.16, d / 2)), ((L / 2 - 0.25, 0, -0.1), (L / 2 - 0.05, 1.06, 0.1)),
                                                     ((-L / 2 + 0.05, 0, -0.1), (-L / 2 + 0.25, 1.06, 0.1))])


def gas_canopy(name="COM_GasCanopy", L=14.0, D=9.0, H=5.0):
    mb = MB()
    for sx in (-1, 1):
        for sz in (-1, 1):
            abox(mb, "enamel_white", (sx * (L / 2 - 1.5) - 0.25, 0, sz * (D / 2 - 2.0) - 0.25), (sx * (L / 2 - 1.5) + 0.25, H, sz * (D / 2 - 2.0) + 0.25), skip=("-y",),
                 faces={})
    abox(mb, "enamel_white", (-L / 2, H, -D / 2), (L / 2, H + 0.9, D / 2), skip=(), faces={"+z": "tile_band", "-z": "tile_band", "+x": "tile_band", "-x": "tile_band",
                                                                                          "-y": "enamel_gray"})
    decal(mb, "sign_fuel", (0, H + 0.45, D / 2), 4.0, 0.6, mat=GLOW, lift=0.01)
    decal(mb, "sign_fuel", (0, H + 0.45, -D / 2), 4.0, 0.6, face="-z", mat=GLOW, lift=0.01)
    for i in range(4):
        for j in range(2):
            x, z = -L / 2 + 2.0 + i * (L - 4.0) / 3, -D / 4 + j * D / 2
            mb.box(GLOW, (x - 0.6, H - 0.03, z - 0.3), (x + 0.6, H, z + 0.3), skip=("+y",), uvrect={f: R("light_panel") for f in ("-y", "+x", "-x", "+z", "-z")})
    meta = {"lights": [[-L / 2 + 2.0 + i * (L - 4.0) / 3, H - 0.3, 0.0] for i in range(4)]}
    cols = [((sx * (L / 2 - 1.5) - 0.25, 0, sz * (D / 2 - 2.0) - 0.25), (sx * (L / 2 - 1.5) + 0.25, H, sz * (D / 2 - 2.0) + 0.25)) for sx in (-1, 1) for sz in (-1, 1)]
    cols.append(((-L / 2, H, -D / 2), (L / 2, H + 0.9, D / 2)))
    m = fx(name, "gas", mb, (L, D, H + 0.9), cols=cols, canopy_lights=meta["lights"], footprint_cols=True)
    return m


def price_sign(name="COM_PriceSign"):
    mb = MB()
    abox(mb, "concrete", (-0.5, 0, -0.35), (0.5, 0.5, 0.35), skip=("-y",))
    abox(mb, "steel", (-0.12, 0.5, -0.12), (0.12, 3.6, 0.12))
    abox(mb, "enamel_white", (-1.0, 3.6, -0.15), (1.0, 5.6, 0.15), faces={"+z": "prices", "-z": "prices"})
    mb.box(GLOW, (-0.98, 3.62, 0.15), (0.98, 5.58, 0.152), uvrect={"+z": R("prices")}, skip=("-z", "+x", "-x", "+y", "-y"))
    mb.box(GLOW, (-0.98, 3.62, -0.152), (0.98, 5.58, -0.15), uvrect={"-z": R("prices")}, skip=("+z", "+x", "-x", "+y", "-y"))
    return fx(name, "gas", mb, (2.0, 0.7, 5.6), cols=[((-0.5, 0, -0.35), (0.5, 0.5, 0.35)), ((-0.12, 0.5, -0.12), (0.12, 3.6, 0.12)), ((-1.0, 3.6, -0.15), (1.0, 5.6, 0.15))])


def air_pump(name="COM_AirPump"):
    mb = MB()
    abox(mb, "concrete", (-0.3, 0, -0.3), (0.3, 0.1, 0.3))
    abox(mb, "red_plastic", (-0.22, 0.1, -0.18), (0.22, 1.35, 0.18), faces={"+z": "airpump_face"})
    solid(mb, "rubber", "tube", [(0.22, 0.9, 0.0), (0.35, 0.5, 0.1), (0.3, 0.2, 0.25), (0.15, 0.15, 0.35)], 0.012, 4)
    meta = {}
    interact(meta, "AirHose", (0.3, 0.9, 0.5), "air_pump")
    return fx(name, "gas", mb, (0.6, 0.6, 1.35), cols=[((-0.3, 0, -0.3), (0.3, 1.35, 0.3))], **meta)


def ice_chest(name="COM_IceChest"):
    mb = MB()
    abox(mb, "enamel_white", (-0.7, 0, -0.4), (0.7, 1.25, 0.4), skip=("-y",), faces={"+z": "ice_door"})
    abox(mb, "blue_paint", (-0.7, 1.25, -0.4), (0.7, 1.4, 0.4), faces={"+z": "ice"})
    meta = {}
    interact(meta, "IceDoor", (0, 0.8, 0.8), "cooler_door")
    return fx(name, "gas", mb, (1.4, 0.8, 1.4), cols=[((-0.7, 0, -0.4), (0.7, 1.4, 0.4))], wall=True, **meta)


# =================================================================== pharmacy / archive
def dispensary_shelf(name="COM_DispensaryShelf"):
    return wall_shelf(name, 2.0, 2.0, ["pillbottles", "meds", "vitamins", "pain", "bandage"], depth=0.4)


def waiting_chairs(name="COM_WaitingChairs"):
    mb = MB()
    abox(mb, "steel", (-0.95, 0.38, -0.05), (0.95, 0.42, 0.05))
    for sx in (-0.85, 0.85):
        abox(mb, "steel", (sx - 0.03, 0, -0.25), (sx + 0.03, 0.42, 0.25))
    for k in range(3):
        x = -0.62 + k * 0.62
        abox(mb, "fabric_blue", (x - 0.26, 0.42, -0.22), (x + 0.26, 0.48, 0.24))
        abox(mb, "fabric_blue", (x - 0.26, 0.48, -0.26), (x + 0.26, 0.88, -0.2))
    return fx(name, "seating", mb, (1.9, 0.55, 0.88), cols=[((-0.95, 0, -0.27), (0.95, 0.88, 0.25))])


def filing_cabinet(name="COM_FilingCabinet"):
    mb = MB()
    abox(mb, "enamel_gray", (-0.23, 0, -0.33), (0.23, 1.32, 0.33), skip=("-y",), faces={"+z": "drawer4"})
    meta = {}
    interact(meta, "Drawers", (0, 0.9, 0.7), "drawer")
    return fx(name, "archive", mb, (0.46, 0.66, 1.32), cols=[((-0.23, 0, -0.33), (0.23, 1.32, 0.33))], wall=True, **meta)


def records_shelf(name="COM_RecordsShelf"):
    return gondola(name, 2.4, 2.2, ["bankers", "binders", "bankers", "binders", "bankers"], ["binders", "bankers", "binders", "bankers", "binders"],
                   levels=[0.12, 0.55, 0.98, 1.41, 1.84], endcap=False)


def document_boxes(name="COM_DocumentBoxes"):
    mb = MB()
    rng = rng_of(name)
    for k in range(3):
        for i in range(2):
            if k == 2 and i == 1:
                continue
            x = -0.2 + i * 0.41 + rng.uniform(-0.02, 0.02)
            abox(mb, "cardboard", (x - 0.2, k * 0.27, -0.24), (x + 0.2, k * 0.27 + 0.26, 0.24), skip=("-y",) if k == 0 else (), faces={"+z": "bankers", "-z": "bankers"})
    return fx(name, "archive", mb, (0.82, 0.48, 0.8), cols=[((-0.41, 0, -0.24), (0.41, 0.8, 0.24))])


def reading_table(name="COM_ReadingTable"):
    mb = MB()
    L, d, H = 2.4, 1.0, 0.76
    abox(mb, "felt_green", (-L / 2 + 0.06, H - 0.005, -d / 2 + 0.06), (L / 2 - 0.06, H + 0.001, d / 2 - 0.06), faces={"+y": "felt_green"})
    abox(mb, "wood_dark", (-L / 2, H - 0.05, -d / 2), (L / 2, H, d / 2), faces={"+y": "wood_dark"})
    for sx in (-1, 1):
        for sz in (-1, 1):
            abox(mb, "wood_dark", (sx * (L / 2 - 0.1) - 0.04, 0, sz * (d / 2 - 0.1) - 0.04), (sx * (L / 2 - 0.1) + 0.04, H - 0.05, sz * (d / 2 - 0.1) + 0.04))
    for sx in (-0.6, 0.6):
        abox(mb, "brass", (sx - 0.06, H, -0.06), (sx + 0.06, H + 0.02, 0.06))
        abox(mb, "brass", (sx - 0.01, H + 0.02, -0.01), (sx + 0.01, H + 0.3, 0.01))
        mb.box(GLOW, (sx - 0.18, H + 0.3, -0.08), (sx + 0.18, H + 0.38, 0.08), uvrect={f: R("fabric_green") for f in ("+x", "-x", "+y", "-y", "+z", "-z")}, skip=())
    abox(mb, "paper", (-0.3, H + 0.001, 0.0), (0.0, H + 0.01, 0.22))
    return fx(name, "archive", mb, (L, d, H + 0.38), cols=[((-L / 2, 0, -d / 2), (L / 2, H, d / 2))])


def reception_desk(name="COM_ReceptionDesk"):
    return counter(name, L=2.4, d=0.8, H=1.05, top="wood_dark", front="counter_wood", reg=False, extra=service_extra)


def notice_board(name="COM_NoticeBoard"):
    mb = MB()
    abox(mb, "wood_dark", (-0.6, 0, -0.03), (0.6, 0.8, 0.0), faces={"+z": "noticeboard"})
    return fx(name, "decor", mb, (1.2, 0.03, 0.8), cols=[], wall_mounted=True)


# =================================================================== registry
def stock_sets():
    return {
        "COM_Gondola_Grocery_A": (3.6, 1.8, ["cereal_a", "cereal_b", "crackers", "cookies"], ["soup", "beans", "tomato", "coffee"]),
        "COM_Gondola_Grocery_B": (3.6, 1.8, ["pasta", "rice", "baking", "tomato"], ["chips", "chips_b", "candy", "cookies"]),
        "COM_Gondola_Grocery_C": (3.6, 1.8, ["soda", "cola", "water", "juice"], ["baking", "rice", "bread", "crackers"]),
        "COM_Gondola_Grocery_D": (3.6, 1.8, ["detergent", "towels", "petfood", "towels"], ["shampoo", "toothpaste", "pain", "bandage"]),
        "COM_Gondola_Bread": (3.6, 1.8, ["bread", "crackers", "bread", "cookies"], ["cereal_b", "cereal_a", "crackers", "pasta"]),
        "COM_Gondola_Snacks": (2.4, 1.5, ["chips", "candy", "gum", "jerky"], ["chips_b", "cookies", "motoroil", "soda"]),
        "COM_Gondola_Health": (3.6, 1.6, ["meds", "pain", "vitamins", "bandage"], ["shampoo", "toothpaste", "towels", "gum"]),
    }


def all_fixtures():
    """(name, builder, export_to_gallery)"""
    out = []
    for nm, (L, H, a, b) in stock_sets().items():
        out.append((nm, (lambda nm=nm, L=L, H=H, a=a, b=b: gondola(nm, L, H, a, b)), True))
    out += [
        ("COM_WallShelf_Grocery", lambda: wall_shelf("COM_WallShelf_Grocery", 2.4, 2.0, ["soup", "beans", "coffee", "baking", "pasta"]), True),
        ("COM_WallShelf_Health", lambda: wall_shelf("COM_WallShelf_Health", 2.4, 1.9, ["shampoo", "toothpaste", "vitamins", "pain", "bandage"]), True),
        ("COM_WallShelf_Mart", lambda: wall_shelf("COM_WallShelf_Mart", 2.4, 1.8, ["motoroil", "towels", "petfood", "chips", "candy"]), True),
        ("COM_GameWallShelf", lambda: wall_shelf("COM_GameWallShelf", 2.0, 2.1, ["games_a", "games_b", "games_c", "games_d", "games_a"], header="new_rel", depth=0.35, slat=True), True),
        ("COM_GameWallShelf_Used", lambda: wall_shelf("COM_GameWallShelf_Used", 2.0, 2.1, ["games_used"], header="used", depth=0.35, slat=True), True),
        ("COM_ConsoleWallShelf", lambda: wall_shelf("COM_ConsoleWallShelf", 2.0, 2.1, ["consoles_boxes", "consoles_boxes", "games_c"], header="consoles", depth=0.45, slat=True), True),
        ("COM_Cooler_Dairy", lambda: cooler("COM_Cooler_Dairy", 3, ["milk", "yogurt", "juice", "eggs"], "aisle_dairy"), True),
        ("COM_Cooler_Frozen", lambda: cooler("COM_Cooler_Frozen", 3, ["icecream", "pizza", "frozen_veg", "icecream"], "aisle_frozen", frost=True), True),
        ("COM_Cooler_Drinks", lambda: cooler("COM_Cooler_Drinks", 3, ["soda", "cola", "water", "juice"], "aisle_dairy"), True),
        ("COM_Freezer_Chest", chest_freezer, True),
        ("COM_Produce_Table", produce_table, True),
        ("COM_Produce_WallCase", produce_case, True),
        ("COM_Checkout_Lane", checkout_lane, True),
        ("COM_ServiceCounter", lambda: counter("COM_ServiceCounter", L=3.0, d=0.8, H=1.05, header="service", extra=service_extra), True),
        ("COM_RetailCounter", lambda: counter("COM_RetailCounter", L=2.4, d=0.7, H=1.0, glass_front=True), True),
        ("COM_MartCounter", lambda: counter("COM_MartCounter", L=2.8, d=0.8, H=1.0, extra=lambda mb, L, d, H: abox(mb, "black_plastic", (-L / 2, H, -d / 2 + 0.02), (-L / 2 + 0.6, H + 0.6, -d / 2 + 0.35), faces={"+z": "candy_rack"})), True),
        ("COM_PharmacyCounter", lambda: counter("COM_PharmacyCounter", L=3.2, d=0.8, H=1.05, top="laminate_cream", extra=pharmacy_extra), True),
        ("COM_CoffeeStation", lambda: counter("COM_CoffeeStation", L=1.8, d=0.6, H=0.95, top="laminate_gray", front="wood_dark", reg=False, extra=coffee_extra), True),
        ("COM_BasketStack", basket_stack, True),
        ("COM_CartCorral", cart_corral, True),
        ("COM_GroceryBag", grocery_bag, True),
        ("COM_PalletStack", pallet_stack, True),
        ("COM_PalletRack", pallet_rack, True),
        ("COM_GameRack_New", lambda: game_rack("COM_GameRack_New", "new_rel", ["games_a", "games_b", "games_c", "games_d"]), True),
        ("COM_GameRack_Used", lambda: game_rack("COM_GameRack_Used", "used", ["games_used"]), True),
        ("COM_ConsoleCase", console_case, True),
        ("COM_DemoStation", demo_station, True),
        ("COM_PosterBoard", poster_board, True),
        ("COM_PosterBoard_B", lambda: poster_board("COM_PosterBoard_B", (3, 4, 5)), False),
        ("COM_FuelPump", fuel_pump, True),
        ("COM_PumpIsland", pump_island, True),
        ("COM_GasCanopy", gas_canopy, True),
        ("COM_PriceSign", price_sign, True),
        ("COM_AirPump", air_pump, True),
        ("COM_IceChest", ice_chest, True),
        ("COM_DispensaryShelf", dispensary_shelf, True),
        ("COM_WaitingChairs", waiting_chairs, True),
        ("COM_FilingCabinet", filing_cabinet, True),
        ("COM_RecordsShelf", records_shelf, True),
        ("COM_DocumentBoxes", document_boxes, True),
        ("COM_ReadingTable", reading_table, True),
        ("COM_ReceptionDesk", reception_desk, True),
        ("COM_NoticeBoard", notice_board, True),
    ]
    return out
