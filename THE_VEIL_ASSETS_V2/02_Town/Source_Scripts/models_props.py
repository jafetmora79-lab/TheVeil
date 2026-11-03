"""Street_Props/ and Utilities/ models.

Prop conventions: origin at ground contact (base centre), Y up, the
"front" (sign face, lamp arm, opening) faces +Z. Collision is a small number
of convex hulls ("-convcolonly"). Attachment / light positions are empty
marker nodes (e.g. "LightPoint", "Attach_Power_C").
"""
import math

import numpy as np

from veil_mesh.mesh import MB, T, Ry, Rx, Rz, S, uv_rect_fn
from veil_mesh.materials import m01, mt
from veil_mesh.gltf import COL_KEY
from veil_mesh.kit import model, col_box, col_cyl, marker
from town_textures import SIGN_RECTS

AT = 256.0
BLACK, GALV, WOODP = mt("PaintBlack"), m01("Furn_MetalBrushed"), mt("PoleWood")


def rect_uv(key):
    x, y, w, h = SIGN_RECTS[key]
    return (x / AT, y / AT, (x + w) / AT, (y + h) / AT)


def sign_plate(mb, pts2, key, t=0.02, back=None):
    xs = [p[0] for p in pts2]
    ys = [p[1] for p in pts2]
    f = uv_rect_fn((min(xs), min(ys), max(xs), max(ys)), rect_uv(key))
    mb.prism(back or m01("Com_SignageBacking"), pts2, -t / 2, t / 2, cap_mat=mt("SignAtlas"),
             front_uvf=lambda p: f((p[0], p[1])), side_mat=back or m01("Com_SignageBacking"))
    # the back face must not show the sign atlas: re-route it
    g = mb.parts[mt("SignAtlas")]
    keep_p, keep_n, keep_uv, keep_i = [], [], [], []
    for k in range(0, len(g["i"]), 3):
        tri = g["i"][k:k + 3]
        if g["n"][tri[0]][2] < 0:  # back face -> backing material
            pts = [g["p"][q] for q in tri]
            mb.tri(back or m01("Com_SignageBacking"), *pts, n=(0, 0, -1))
            continue
        base = len(keep_p)
        for q in tri:
            keep_p.append(g["p"][q])
            keep_n.append(g["n"][q])
            keep_uv.append(g["uv"][q])
        keep_i += [base, base + 1, base + 2]
    g["p"], g["n"], g["uv"], g["i"] = keep_p, keep_n, keep_uv, keep_i


def regular(n, r, rot=0.0):
    return [(r * math.cos(rot + 2 * math.pi * k / n), r * math.sin(rot + 2 * math.pi * k / n)) for k in range(n)]


def post(mb, h, r=0.035, mat=None, sides=6):
    mb.cyl(mat or GALV, (0, 0, 0), r, h, seg=sides, caps=("top",))


def sign_on_post(name, shape, key, h_center, post_h, w=None, desc=""):
    mb = MB()
    post(mb, post_h)
    p = MB()
    sign_plate(p, shape, key)
    mb.merge(p, T(0, h_center, 0.045))
    mb.box(GALV, (-0.03, h_center - 0.2, 0.0), (0.03, h_center + 0.2, 0.035))  # bracket
    return model(name, mb, col_cyl((0, 0, 0), 0.05, post_h, 6), "convcolonly", meta=dict(kind="prop", desc=desc))


# ============================================================================
# LIGHTING
# ============================================================================
def lamp_residential():
    name = "SP_Lamp_Residential"
    mb = MB()
    mb.cyl(BLACK, (0, 0, 0), 0.16, 0.35, seg=8, r_top=0.09, caps=("top",))  # flared base
    mb.cyl(BLACK, (0, 0.35, 0), 0.07, 3.6, seg=8, r_top=0.05, caps=())
    mb.cyl(BLACK, (0, 3.95, 0), 0.09, 0.12, seg=8, caps=())                  # collar
    mb.cyl(BLACK, (0, 4.07, 0), 0.12, 0.08, seg=8, r_top=0.2, caps=())       # fitter
    mb.cyl(mt("LampGlow"), (0, 4.15, 0), 0.2, 0.45, seg=8, r_top=0.24, caps=())  # lantern glass
    mb.cyl(BLACK, (0, 4.6, 0), 0.28, 0.1, seg=8, r_top=0.26, caps=())
    mb.cyl(BLACK, (0, 4.7, 0), 0.26, 0.22, seg=8, r_top=0.03, caps=("top",))  # pointed cap
    mb.cyl(BLACK, (0, 4.92, 0), 0.03, 0.12, seg=6, caps=("top",))
    return model(name, mb, col_cyl((0, 0, 0), 0.14, 4.5, 8), "convcolonly",
                 extra=[marker("LightPoint", (0, 4.35, 0))], meta=dict(kind="prop", light=(0, 4.35, 0)))


def cobra_head(mb, at, arm_len, h):
    """Arm + cobra-head luminaire extending toward +Z from a pole top."""
    x, y, z = at
    mb.tube(BLACK, [(x, y, z), (x, y + 0.35, z + arm_len * 0.4), (x, y + 0.45, z + arm_len)], 0.04, 6)
    hz = z + arm_len
    mb.box(m01("Com_SignageBacking"), (x - 0.18, y + 0.3, hz - 0.05), (x + 0.18, y + 0.5, hz + 0.6),
           skip=("-y",))
    mb.box(mt("LampGlow"), (x - 0.15, y + 0.29, hz), (x + 0.15, y + 0.3, hz + 0.5), skip=("+y",))
    return (x, y + 0.25, hz + 0.25)


def lamp_commercial():
    name = "SP_Lamp_Commercial"
    mb = MB()
    mb.box(m01("Road_CurbConcrete"), (-0.25, 0, -0.25), (0.25, 0.3, 0.25))
    mb.cyl(mt("PaintGreen"), (0, 0.3, 0), 0.11, 6.0, seg=8, r_top=0.07, caps=("top",))
    for y in (1.2, 1.4):
        mb.cyl(mt("PaintGreen"), (0, y, 0), 0.13, 0.06, seg=8, caps=())
    lp = cobra_head_green(mb, (0, 6.1, 0), 1.6)
    # banner bracket
    mb.tube(mt("PaintGreen"), [(0, 4.2, 0), (0, 4.2, 0.6)], 0.02, 4)
    mb.tube(mt("PaintGreen"), [(0, 5.3, 0), (0, 5.3, 0.6)], 0.02, 4)
    return model(name, mb, [col_box((-0.25, 0, -0.25), (0.25, 0.3, 0.25)), col_cyl((0, 0, 0), 0.12, 6.2, 8)],
                 "convcolonly", extra=[marker("LightPoint", lp)], meta=dict(kind="prop", light=lp))


def cobra_head_green(mb, at, arm):
    x, y, z = at
    mb.tube(mt("PaintGreen"), [(x, y - 0.2, z), (x, y + 0.1, z + 0.3), (x, y + 0.25, z + arm)], 0.045, 6)
    hz = z + arm
    mb.box(mt("PaintGreen"), (-0.2, y + 0.1, hz - 0.1), (0.2, y + 0.33, hz + 0.65), skip=("-y",))
    mb.box(mt("LampGlow"), (-0.17, y + 0.09, hz - 0.05), (0.17, y + 0.1, hz + 0.6), skip=("+y",))
    return (0, y - 0.05, hz + 0.25)


def wooden_pole(mb, h=10.0, r0=0.15, r1=0.11):
    mb.cyl(WOODP, (0, 0, 0), r0, h, seg=8, r_top=r1, caps=("top",))
    for y in np.arange(2.4, 6.5, 0.45):  # step bolts
        a = 0.0 if int(y * 10) % 2 else math.pi
        mb.box(GALV, (r0 * math.cos(a) - 0.02, y, -0.02), (r0 * math.cos(a) + 0.18 * math.cos(a), y + 0.03, 0.02))


def crossarm(mb, y, w=2.4):
    mb.box(m01("Furn_WoodDark"), (-w / 2, y, -0.06), (w / 2, y + 0.1, 0.06))
    pts = []
    for x in (-w / 2 + 0.15, 0.0, w / 2 - 0.15):
        mb.cyl(m01("Furn_PlasticDirty"), (x, y + 0.1, 0), 0.05, 0.1, seg=6, r_top=0.035, caps=())
        mb.cyl(m01("Furn_PlasticDirty"), (x, y + 0.2, 0), 0.06, 0.04, seg=6, r_top=0.03, caps=("top",))
        pts.append((x, y + 0.24, 0))
    mb.tube(GALV, [(-0.5, y, 0), (0, y - 0.6, 0), (0.5, y, 0)], 0.015, 4)  # braces
    return pts


def utility_pole_light():
    """Wooden pole + crossarm + cobra-head arm. The lamp arm reaches along +X,
    parallel to the crossarm (i.e. over the road when the wires run along the
    street)."""
    name = "SP_UtilityPole_Streetlight"
    mb = MB()
    wooden_pole(mb)
    attach = crossarm(mb, 9.3)
    arm = MB()
    lpz = cobra_head(arm, (0, 6.6, 0.12), 1.8, 6.6)
    mb.merge(arm, Ry(math.pi / 2))
    lp = (lpz[2], lpz[1], -lpz[0])
    extra = [marker("LightPoint", lp)] + [marker(f"Attach_Power_{k}", p) for k, p in zip("LCR", attach)]
    extra.append(marker("Attach_Tel", (0, 7.2, 0)))
    return model(name, mb, col_cyl((0, 0, 0), 0.16, 10, 8), "convcolonly", extra=extra,
                 meta=dict(kind="prop", light=lp))


def lamp_wall():
    name = "SP_Lamp_Wall"
    mb = MB()
    mb.box(BLACK, (-0.09, -0.15, 0), (0.09, 0.15, 0.03))
    mb.tube(BLACK, [(0, 0.05, 0.03), (0, 0.12, 0.18), (0, 0.06, 0.28)], 0.015, 4)
    mb.box(BLACK, (-0.1, 0.06, 0.18), (0.1, 0.09, 0.38))
    mb.box(mt("LampGlow"), (-0.08, -0.16, 0.2), (0.08, 0.06, 0.36), skip=())
    mb.box(BLACK, (-0.1, -0.19, 0.18), (0.1, -0.16, 0.38))
    return model(name, mb, None, extra=[marker("LightPoint", (0, -0.05, 0.28))],
                 meta=dict(kind="prop", light=(0, -0.05, 0.28), note="Wall-mounted: origin at the wall surface, 2.1 m mount height recommended"))


# ============================================================================
# TRAFFIC
# ============================================================================
def stop_sign():
    return sign_on_post("SP_Sign_Stop", regular(8, 0.4, math.pi / 8), "stop", 2.2, 2.65, desc="R1-1 style 0.75 m octagon")


def yield_sign():
    tri = [(-0.45, 0.26), (0.45, 0.26), (0.0, -0.52)]
    return sign_on_post("SP_Sign_Yield", tri, "yield", 2.25, 2.6)


def speed_sign():
    return sign_on_post("SP_Sign_SpeedLimit25", [(-0.3, -0.37), (0.3, -0.37), (0.3, 0.37), (-0.3, 0.37)],
                        "speed25", 2.1, 2.55)


def parking_sign():
    return sign_on_post("SP_Sign_Parking2HR", [(-0.22, -0.3), (0.22, -0.3), (0.22, 0.3), (-0.22, 0.3)],
                        "parking", 2.0, 2.4)


def noparking_sign():
    return sign_on_post("SP_Sign_NoParking", [(-0.22, -0.3), (0.22, -0.3), (0.22, 0.3), (-0.22, 0.3)],
                        "noparking", 2.0, 2.4)


def deadend_sign():
    return sign_on_post("SP_Sign_DeadEnd", regular(4, 0.42, 0), "deadend", 2.15, 2.6)


def oneway_sign():
    return sign_on_post("SP_Sign_OneWay", [(-0.45, -0.15), (0.45, -0.15), (0.45, 0.15), (-0.45, 0.15)],
                        "oneway", 2.4, 2.6)


def street_name_sign(a="MAIN ST", b="OAK ST"):
    ka, kb = "blade_" + a.replace(" ", "_"), "blade_" + b.replace(" ", "_")
    name = "SP_Sign_StreetName" if (a, b) == ("MAIN ST", "OAK ST") else \
        f"SP_Sign_StreetName_{a.split()[0].title()}_{b.split()[0].title()}"
    mb = MB()
    post(mb, 3.1)
    blade = [(-0.45, -0.075), (0.45, -0.075), (0.45, 0.075), (-0.45, 0.075)]
    p1, p2 = MB(), MB()
    sign_plate(p1, blade, ka, t=0.015)
    sign_plate(p2, blade, kb, t=0.015)
    mb.merge(p1, T(0, 3.15, 0) @ Ry(math.pi / 2) @ T(0, 0, 0))
    mb.merge(p2, T(0, 3.33, 0))
    mb.cyl(GALV, (0, 3.08, 0), 0.05, 0.38, seg=6, caps=("top",))
    return model(name, mb, col_cyl((0, 0, 0), 0.05, 3.1, 6), "convcolonly",
                 meta=dict(kind="prop", desc=f"Blades: {b} (along X), {a} (along Z)"))


def signal_head(mb, at):
    """3-aspect vehicle signal facing +Z; red lit, amber/green dim."""
    x, y, z = at
    mb.box(mt("PaintYellow"), (x - 0.17, y - 0.5, z - 0.12), (x + 0.17, y + 0.5, z + 0.12), skip=())
    mb.box(BLACK, (x - 0.28, y - 0.6, z - 0.14), (x + 0.28, y + 0.6, z - 0.12), skip=())  # backplate
    for k, (lens, dy) in enumerate(((mt("LensRed"), 0.32), (mt("LensAmber"), 0.0), (mt("LensGreen"), -0.32))):
        lm = MB()
        lm.cyl(lens, (0, 0, 0), 0.1, 0.02, seg=10, caps=("top",))
        mb.merge(lm, T(x, y + dy, z + 0.12) @ Rx(math.pi / 2))
        vis = MB()
        vis.box(mt("PaintYellow"), (-0.13, 0.08, 0), (0.13, 0.1, 0.2), skip=())
        mb.merge(vis, T(x, y + dy, z + 0.12))


def traffic_light():
    name = "SP_TrafficLight_MastArm"
    mb = MB()
    mb.box(m01("Road_CurbConcrete"), (-0.35, 0, -0.35), (0.35, 0.25, 0.35))
    mb.cyl(BLACK, (0, 0.25, 0), 0.14, 6.0, seg=8, r_top=0.1, caps=("top",))
    # mast arm reaching over the road toward +X
    mb.tube(BLACK, [(0, 5.6, 0), (2.5, 5.75, 0), (5.2, 5.85, 0)], 0.07, 6, caps=True)
    mb.tube(BLACK, [(0, 6.1, 0), (2.0, 5.8, 0)], 0.03, 4)
    signal_head(mb, (3.0, 5.1, 0.05))
    signal_head(mb, (5.0, 5.2, 0.05))
    signal_head(mb, (0.0, 3.4, 0.2))  # near-side pole-mounted head
    mb.box(m01("Com_SignageBacking"), (-0.12, 1.1, 0.14), (0.12, 1.4, 0.26))  # ped push button box
    return model(name, mb, [col_box((-0.35, 0, -0.35), (0.35, 0.25, 0.35)), col_cyl((0, 0, 0), 0.15, 6.2, 8)],
                 "convcolonly", extra=[marker("Signal_Arm_1", (3.0, 5.1, 0.2)), marker("Signal_Arm_2", (5.0, 5.2, 0.2))],
                 meta=dict(kind="prop", desc="Arm points to +X over the lanes; heads face +Z (oncoming traffic)."))


def road_barrier():
    name = "SP_RoadBarrier"
    mb = MB()
    for x in (-0.85, 0.85):
        for zs in (-1, 1):
            mb.tube(mt("PaintWhite"), [(x, 0.0, zs * 0.35), (x, 1.15, 0)], 0.03, 4)
        mb.box(mt("PaintOrange"), (x - 0.05, 1.1, -0.05), (x + 0.05, 1.2, 0.05))
    for y in (0.45, 0.85):
        mb.box(mt("HazardStripe"), (-1.0, y, -0.02), (1.0, y + 0.22, 0.02), skip=())
    mb.box(mt("LensAmber"), (-0.08, 1.2, -0.03), (0.08, 1.33, 0.03), skip=())  # warning lamp
    return model(name, mb, col_box((-1.0, 0, -0.35), (1.0, 1.2, 0.35)), "convcolonly",
                 meta=dict(kind="prop", interactive=True))


def traffic_cone():
    name = "SP_TrafficCone"
    mb = MB()
    mb.box(mt("PaintBlack"), (-0.18, 0, -0.18), (0.18, 0.03, 0.18))
    mb.cyl(mt("PaintOrange"), (0, 0.03, 0), 0.15, 0.25, seg=10, r_top=0.11, caps=())
    mb.cyl(mt("PaintWhite"), (0, 0.28, 0), 0.11, 0.14, seg=10, r_top=0.085, caps=())
    mb.cyl(mt("PaintOrange"), (0, 0.42, 0), 0.085, 0.28, seg=10, r_top=0.025, caps=("top",))
    return model(name, mb, col_cyl((0, 0, 0), 0.16, 0.7, 8), "convcolonly", meta=dict(kind="prop", interactive=True))


# ============================================================================
# TOWN DETAILS
# ============================================================================
def fire_hydrant():
    name = "SP_FireHydrant"
    mb = MB()
    R = mt("PaintRed")
    mb.cyl(R, (0, 0, 0), 0.17, 0.06, seg=10, caps=("top",))                # flange
    mb.cyl(R, (0, 0.06, 0), 0.12, 0.5, seg=10, caps=())                    # barrel
    mb.cyl(R, (0, 0.5, 0), 0.15, 0.05, seg=10, caps=())                    # upper flange
    mb.cyl(R, (0, 0.55, 0), 0.13, 0.12, seg=10, r_top=0.05, caps=("top",))  # bonnet dome
    mb.cyl(mt("PaintWhite"), (0, 0.67, 0), 0.03, 0.06, seg=5, caps=("top",))  # operating nut
    for a in (0, math.pi):  # hose nozzles
        n = MB()
        n.cyl(R, (0, 0, 0), 0.045, 0.12, seg=8, caps=("top",), cap_mat=mt("PaintWhite"))
        mb.merge(n, T(0, 0.38, 0) @ Ry(a) @ Rz(-math.pi / 2) @ T(0, 0.08, 0))
    n = MB()
    n.cyl(R, (0, 0, 0), 0.07, 0.12, seg=8, caps=("top",), cap_mat=mt("PaintWhite"))  # pumper nozzle
    mb.merge(n, T(0, 0.33, 0) @ Rx(math.pi / 2) @ T(0, 0.08, 0))
    for k in range(6):  # flange bolts
        a = k * math.pi / 3
        mb.box(m01("Furn_MetalBrushed"), (0.15 * math.cos(a) - 0.015, 0.06, 0.15 * math.sin(a) - 0.015),
               (0.15 * math.cos(a) + 0.015, 0.085, 0.15 * math.sin(a) + 0.015))
    return model(name, mb, col_cyl((0, 0, 0), 0.17, 0.7, 8), "convcolonly", meta=dict(kind="prop"))


def mailbox():
    name = "SP_Mailbox_Residential"
    mb = MB()
    mb.box(m01("Arch_WoodPlanksAged"), (-0.05, 0, -0.05), (0.05, 1.0, 0.05))
    mb.box(m01("Arch_WoodPlanksAged"), (-0.12, 1.0, -0.3), (0.12, 1.04, 0.3))
    arch = [(-0.11, 0.0)] + [(0.11 * math.cos(math.pi - math.pi * k / 6), 0.12 + 0.11 * math.sin(math.pi - math.pi * k / 6))
                              for k in range(7)] + [(0.11, 0.0)]
    arch = [arch[0]] + arch[1:-1] + [arch[-1]]
    body = MB()
    body.prism(BLACK, arch, -0.24, 0.24)
    mb.merge(body, T(0, 1.04, 0))
    mb.box(mt("PaintRed"), (0.115, 1.12, -0.12), (0.13, 1.17, 0.12))  # flag arm
    mb.box(mt("PaintRed"), (0.115, 1.12, -0.12), (0.13, 1.3, -0.04))
    mb.box(m01("Furn_MetalBrushed"), (-0.02, 1.13, 0.24), (0.02, 1.17, 0.27))  # latch
    return model(name, mb, col_box((-0.13, 0, -0.3), (0.13, 1.3, 0.3)), "convcolonly",
                 meta=dict(kind="prop", desc="Door faces +Z (street side)"))


def trash_bin():
    name = "SP_TrashBin_Public"
    mb = MB()
    G = mt("PaintGreen")
    mb.cyl(G, (0, 0, 0), 0.3, 0.85, seg=12, caps=())
    for y in (0.08, 0.42, 0.78):
        mb.cyl(G, (0, y, 0), 0.32, 0.05, seg=12, caps=())
    mb.cyl(BLACK, (0, 0.85, 0), 0.33, 0.08, seg=12, caps=())
    mb.cyl(BLACK, (0, 0.93, 0), 0.33, 0.12, seg=12, r_top=0.12, caps=("top",))
    mb.box(mt("PaintBlack"), (-0.15, 0.88, 0.27), (0.15, 0.98, 0.34), skip=())  # opening hood
    mb.box(m01("Road_RoadPatch"), (-0.12, 0.9, 0.335), (0.12, 0.96, 0.336), skip=("-z",))
    return model(name, mb, col_cyl((0, 0, 0), 0.33, 1.05, 8), "convcolonly", meta=dict(kind="prop", interactive=True))


def dumpster():
    name = "SP_Dumpster"
    mb = MB()
    G = mt("PaintGreen")
    w, d, h = 0.95, 0.6, 1.15
    # tapered body (wider at the top)
    bot = [(-w + 0.08, -d + 0.05), (w - 0.08, -d + 0.05), (w - 0.08, d - 0.05), (-w + 0.08, d - 0.05)]
    top = [(-w, -d), (w, -d), (w, d), (-w, d)]
    yb, yt = 0.18, h
    for i in range(4):
        a, b = bot[i], bot[(i + 1) % 4]
        c, e = top[(i + 1) % 4], top[i]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        mb.quad(G, [a[0], yb, a[1]], [b[0], yb, b[1]], [c[0], yt, c[1]], [e[0], yt, e[1]], n=(mid[0], 0.1, mid[1]))
    mb.box(G, (-w - 0.04, yt - 0.06, -d - 0.04), (w + 0.04, yt, d + 0.04), skip=("+y",))
    mb.box(G, (-w, yt - 0.3, -d - 0.12), (-w + 0.15, yt - 0.15, d + 0.12))  # fork pockets
    mb.box(G, (w - 0.15, yt - 0.3, -d - 0.12), (w, yt - 0.15, d + 0.12))
    mb.box(m01("Road_RoadPatch"), (-w + 0.08, yt - 0.01, -d + 0.05), (w - 0.08, yt - 0.005, d - 0.05), skip=("-y",))
    for (x, z) in ((-0.75, -0.45), (0.75, -0.45), (-0.75, 0.45), (0.75, 0.45)):
        wheel = MB()
        wheel.cyl(m01("Furn_Rubber"), (0, -0.04, 0), 0.08, 0.08, seg=8, caps=("top", "bottom"))
        mb.merge(wheel, T(x, 0.09, z) @ Rx(math.pi / 2))
        mb.box(m01("Furn_MetalBrushed"), (x - 0.05, 0.12, z - 0.05), (x + 0.05, yb, z + 0.05))
    # lids are separate hinged nodes (pivot on the back edge, -Z)
    lids = []
    for k, x0 in enumerate((-w, 0.0)):
        lid = MB()
        lid.box(BLACK, (0.0, 0.0, 0.0), (w, 0.05, 2 * d + 0.08), skip=())
        lids.append({"name": f"Lid_{'LR'[k]}", "mb": lid, "t": (x0, yt, -d - 0.04),
                     "children": []})
    return model(name, mb, col_box((-w, 0, -d), (w, yt, d)), "convcolonly", extra=lids,
                 meta=dict(kind="prop", desc="Lids hinge on their -Z edge (node origin) for animation"))


def newspaper_box():
    name = "SP_NewspaperBox"
    mb = MB()
    N = mt("PaintNavy")
    for (x, z) in ((-0.18, -0.15), (0.18, -0.15), (-0.18, 0.15), (0.18, 0.15)):
        mb.box(N, (x - 0.02, 0, z - 0.02), (x + 0.02, 0.35, z + 0.02))
    mb.box(N, (-0.23, 0.35, -0.2), (0.23, 1.05, 0.2))
    mb.box(m01("Arch_WindowGlassDirty"), (-0.17, 0.62, 0.2), (0.17, 0.95, 0.205), skip=("-z",))
    mb.box(N, (-0.23, 0.6, 0.2), (0.23, 0.62, 0.23))
    mb.box(m01("Com_SignageBacking"), (0.1, 0.45, 0.2), (0.18, 0.56, 0.22))  # coin slot
    # GAZETTE label
    lab = MB()
    sign_plate(lab, [(-0.2, -0.05), (0.2, -0.05), (0.2, 0.05), (-0.2, 0.05)], "gazette", t=0.01, back=N)
    mb.merge(lab, T(0, 1.0, 0.2))
    mb.box(N, (-0.24, 1.05, -0.21), (0.24, 1.08, 0.21))
    return model(name, mb, col_box((-0.23, 0, -0.2), (0.23, 1.08, 0.2)), "convcolonly",
                 meta=dict(kind="prop", interactive=True))


def bench():
    name = "SP_Bench_Wood"
    mb = MB()
    for x in (-0.75, 0.75):
        leg = [(-0.28, 0.0), (0.22, 0.0), (0.2, 0.42), (0.32, 0.88), (0.26, 0.9), (0.12, 0.45), (-0.28, 0.42)]
        part = MB()
        part.prism(BLACK, [(z, y) for z, y in leg], -0.03, 0.03)
        mb.merge(part, T(x, 0, 0) @ Ry(math.pi / 2))
    wood = m01("Furn_WoodLight")
    for k in range(4):  # seat slats
        z = -0.24 + k * 0.12
        mb.box(wood, (-0.95, 0.42, z), (0.95, 0.46, z + 0.09), skip=())
    for k in range(2):  # back slats
        y = 0.58 + k * 0.15
        s = MB()
        s.box(wood, (-0.95, 0, -0.02), (0.95, 0.1, 0.02), skip=())
        mb.merge(s, T(0, y, 0.2 + k * 0.05) @ Rx(-0.3))
    return model(name, mb, col_box((-0.95, 0, -0.28), (0.95, 0.9, 0.32)), "convcolonly",
                 meta=dict(kind="prop", desc="Seat faces -Z; back is on the +Z side"))


def bus_stop_sign():
    name = "SP_Sign_BusStop"
    mb = MB()
    post(mb, 2.8)
    p = MB()
    sign_plate(p, [(-0.22, -0.3), (0.22, -0.3), (0.22, 0.3), (-0.22, 0.3)], "bus")
    mb.merge(p, T(0, 2.45, 0.045))
    mb.box(m01("Com_SignageBacking"), (-0.12, 1.35, 0.04), (0.12, 1.75, 0.1))  # timetable case
    mb.box(m01("Arch_WindowGlassDirty"), (-0.1, 1.38, 0.1), (0.1, 1.72, 0.101), skip=("-z",))
    return model(name, mb, col_cyl((0, 0, 0), 0.05, 2.8, 6), "convcolonly", meta=dict(kind="prop"))


def bus_shelter():
    name = "SP_BusShelter"
    mb = MB()
    W, D, H = 1.6, 0.75, 2.4
    for (x, z) in ((-W, -D), (W, -D), (-W, D), (W, D)):
        mb.box(BLACK, (x - 0.04, 0, z - 0.04), (x + 0.04, H, z + 0.04))
    roof = MB()
    roof.box(m01("Com_SignageBacking"), (-W - 0.15, 0, -D - 0.2), (W + 0.15, 0.12, D + 0.3), skip=())
    mb.merge(roof, T(0, H, 0) @ Rx(-0.05))
    glass = m01("Arch_WindowGlassDirty")
    for x0, x1 in ((-W + 0.04, -0.02), (0.02, W - 0.04)):  # back wall panes
        mb.box(glass, (x0, 0.15, -D - 0.01), (x1, H - 0.15, -D + 0.01), skip=())
    mb.box(glass, (W - 0.01, 0.15, -D + 0.04), (W + 0.01, H - 0.15, D * 0.2), skip=())  # side pane
    mb.box(BLACK, (-W, 0.12, -D - 0.03), (W, 0.15, -D + 0.03))
    mb.box(BLACK, (-W, H - 0.15, -D - 0.03), (W, H - 0.12, -D + 0.03))
    # bench
    mb.box(m01("Furn_WoodLight"), (-1.2, 0.45, -D + 0.05), (1.2, 0.5, -D + 0.45), skip=())
    for x in (-1.0, 1.0):
        mb.box(BLACK, (x - 0.03, 0, -D + 0.2), (x + 0.03, 0.45, -D + 0.26))
    hdr = MB()
    sign_plate(hdr, [(-0.3, -0.08), (0.3, -0.08), (0.3, 0.08), (-0.3, 0.08)], "bus", t=0.02)
    mb.merge(hdr, T(-W + 0.4, H + 0.25, D + 0.31))
    cols = [col_box((-W - 0.05, 0, -D - 0.05), (W + 0.05, H, -D + 0.05)),
            col_box((W - 0.05, 0, -D), (W + 0.05, H, D * 0.2)),
            col_box((-1.2, 0, -D + 0.05), (1.2, 0.5, -D + 0.45)),
            col_box((-W - 0.15, H, -D - 0.2), (W + 0.15, H + 0.15, D + 0.3))]
    return model(name, mb, cols, "convcolonly", meta=dict(kind="prop", desc="Open side faces +Z (kerb)"))


def bike_rack():
    name = "SP_BikeRack"
    mb = MB()
    pts = [(-0.9, 0.0, 0)]
    for k in range(5):  # serpentine "wave" rack: up, over, down for each bay
        x = -0.9 + k * 0.45
        pts += [(x + 0.03, 0.72, 0), (x + 0.2, 0.75, 0), (x + 0.22, 0.05, 0), (x + 0.45, 0.0, 0)]
    mb.tube(GALV, pts, 0.03, 6)
    return model(name, mb, col_box((-0.95, 0, -0.05), (1.4, 0.78, 0.05)), "convcolonly", meta=dict(kind="prop"))


def parking_meter():
    name = "SP_ParkingMeter"
    mb = MB()
    mb.cyl(GALV, (0, 0, 0), 0.04, 1.1, seg=6, caps=("top",))
    mb.box(m01("Com_SignageBacking"), (-0.11, 1.1, -0.08), (0.11, 1.42, 0.09))
    dome = MB()
    dome.cyl(m01("Arch_WindowGlassDirty"), (0, 0, 0), 0.08, 0.02, seg=10, caps=("top",))
    mb.merge(dome, T(0, 1.32, 0.09) @ Rx(math.pi / 2))
    mb.cyl(m01("Com_SignageBacking"), (0, 1.42, 0), 0.11, 0.08, seg=10, r_top=0.05, caps=("top",))
    mb.box(GALV, (-0.03, 1.16, 0.09), (0.03, 1.2, 0.1))
    return model(name, mb, col_box((-0.11, 0, -0.08), (0.11, 1.5, 0.09)), "convcolonly", meta=dict(kind="prop"))


def phone_booth():
    name = "SP_PhoneBooth"
    mb = MB()
    W, H = 0.45, 2.25
    for (x, z) in ((-W, -W), (W, -W), (-W, W), (W, W)):
        mb.box(GALV, (x - 0.04, 0, z - 0.04), (x + 0.04, H, z + 0.04))
    mb.box(m01("Road_CurbConcrete"), (-W - 0.05, 0, -W - 0.05), (W + 0.05, 0.05, W + 0.05))
    mb.box(mt("PaintNavy"), (-W - 0.06, H, -W - 0.06), (W + 0.06, H + 0.25, W + 0.06))
    for (z, a) in ((W + 0.061, 0), (-W - 0.061, math.pi)):
        h = MB()
        sign_plate(h, [(-0.3, -0.07), (0.3, -0.07), (0.3, 0.07), (-0.3, 0.07)], "phone", t=0.01, back=mt("PaintNavy"))
        mb.merge(h, T(0, H + 0.125, z) @ Ry(a))
    glass = m01("Arch_WindowGlassDirty")
    mb.box(glass, (-W + 0.04, 0.25, -W - 0.01), (W - 0.04, H - 0.05, -W + 0.01), skip=())  # back
    mb.box(glass, (-W - 0.01, 0.25, -W + 0.04), (-W + 0.01, H - 0.05, W - 0.04), skip=())  # left
    mb.box(glass, (W - 0.01, 0.25, -W + 0.04), (W + 0.01, H - 0.05, W - 0.04), skip=())    # right
    mb.box(BLACK, (-0.15, 1.1, -W + 0.02), (0.15, 1.55, -W + 0.12))  # phone unit
    mb.box(m01("Furn_Rubber"), (-0.2, 1.3, -W + 0.12), (-0.15, 1.5, -W + 0.17))  # handset
    door = MB()
    door.box(glass, (0.0, 0.05, -0.01), (2 * W - 0.08, H - 0.05, 0.01), skip=())
    door.box(GALV, (0.0, 0.05, -0.02), (0.04, H - 0.05, 0.02))
    cols = [col_box((-W - 0.05, 0, -W - 0.05), (W + 0.05, H + 0.25, -W + 0.05)),
            col_box((-W - 0.05, 0, -W), (-W + 0.05, H + 0.25, W)),
            col_box((W - 0.05, 0, -W), (W + 0.05, H + 0.25, W))]
    return model(name, mb, cols, "convcolonly",
                 extra=[{"name": "Door", "mb": door, "t": (-W + 0.04, 0, W)}],
                 meta=dict(kind="prop", interactive=True, desc="Door node pivots at its left edge (front, +Z)"))


def manhole():
    name = "SP_ManholeCover"
    mb = MB()
    r = 0.45
    ring = [(r * math.cos(2 * math.pi * k / 16), r * math.sin(2 * math.pi * k / 16)) for k in range(16)]
    pts = [(x, 0.012, z) for x, z in ring]
    mb.poly(mt("ManholeCover"), pts, (0, 1, 0), uvf=lambda p: ((p[0] / (2 * r)) + 0.5, (p[2] / (2 * r)) + 0.5))
    for k in range(16):
        a, b = ring[k], ring[(k + 1) % 16]
        mb.quad(m01("Furn_MetalBrushed"), [a[0], 0, a[1]], [b[0], 0, b[1]], [b[0], 0.012, b[1]], [a[0], 0.012, a[1]],
                n=(a[0] + b[0], 0, a[1] + b[1]))
    return model(name, mb, None, meta=dict(kind="prop", desc="Sits 12 mm proud of the road surface"))


def drain_grate():
    name = "SP_DrainGrate"
    mb = MB()
    pts = [(-0.3, 0.008, -0.2), (0.3, 0.008, -0.2), (0.3, 0.008, 0.2), (-0.3, 0.008, 0.2)]
    mb.poly(mt("DrainGrate"), pts, (0, 1, 0), uvf=lambda p: (p[0] / 0.6 + 0.5, p[2] / 0.4 + 0.5))
    mb.box(m01("Furn_MetalBrushed"), (-0.31, 0, -0.21), (0.31, 0.008, 0.21), skip=("-y", "+y"))
    return model(name, mb, None, meta=dict(kind="prop"))


# ============================================================================
# UTILITIES
# ============================================================================
def utility_pole():
    name = "UT_UtilityPole"
    mb = MB()
    wooden_pole(mb)
    attach = crossarm(mb, 9.3)
    mb.box(GALV, (-0.2, 7.15, 0.11), (0.2, 7.2, 0.16))  # telephone cable clamp
    mb.box(mt("PaintYellow"), (-0.08, 1.8, 0.145), (0.08, 2.0, 0.15), skip=("-z",))  # pole tag
    extra = [marker(f"Attach_Power_{k}", p) for k, p in zip("LCR", attach)] + [marker("Attach_Tel", (0, 7.2, 0))]
    return model(name, mb, col_cyl((0, 0, 0), 0.16, 10, 8), "convcolonly", extra=extra,
                 meta=dict(kind="prop", desc="Power attach y=9.54 at local x=-1.05/0/1.05 (crossarm along X); telephone y=7.2 on the pole axis. Lines run along local Z: give pole and line the same yaw +-90 deg"))


def transformer_pole():
    name = "UT_Transformer_PoleMount"
    mb = MB()
    mb.box(GALV, (-0.05, -0.4, -0.05), (0.05, 0.4, 0.2))  # bracket (origin = pole surface)
    mb.cyl(m01("Com_SignageBacking"), (0, -0.45, 0.45), 0.3, 0.95, seg=10, caps=("top", "bottom"))
    mb.cyl(m01("Com_SignageBacking"), (0, 0.5, 0.45), 0.32, 0.05, seg=10, caps=("top",))
    for x in (-0.12, 0.12):
        mb.cyl(m01("Furn_PlasticDirty"), (x, 0.55, 0.45), 0.04, 0.18, seg=6, r_top=0.025, caps=("top",))
    for y in (-0.3, -0.1, 0.1, 0.3):  # cooling fins
        mb.box(m01("Com_SignageBacking"), (-0.34, y, 0.4), (0.34, y + 0.04, 0.5))
    return model(name, mb, None, meta=dict(kind="prop", desc="Mount on a utility pole at ~7.6 m; origin on pole face, can toward +Z"))


def transformer_pad():
    name = "UT_Transformer_PadMount"
    mb = MB()
    mb.box(m01("Road_CurbConcrete"), (-0.75, 0, -0.65), (0.75, 0.12, 0.65))
    mb.box(mt("PaintGreen"), (-0.6, 0.12, -0.5), (0.6, 1.25, 0.5))
    mb.box(mt("PaintGreen"), (-0.63, 1.25, -0.53), (0.63, 1.3, 0.53))
    mb.box(mt("VentGrille"), (-0.45, 0.85, 0.5), (0.45, 1.1, 0.505), skip=("-z",))
    mb.box(m01("Furn_MetalBrushed"), (-0.02, 0.5, 0.5), (0.02, 0.75, 0.52))  # door seam handle
    mb.box(mt("PaintYellow"), (0.2, 0.55, 0.5), (0.4, 0.7, 0.505), skip=("-z",))  # warning decal
    return model(name, mb, col_box((-0.75, 0, -0.65), (0.75, 1.3, 0.65)), "convcolonly", meta=dict(kind="prop"))


def _catenary(p0, p1, sag, n=10):
    out = []
    for k in range(n + 1):
        t = k / n
        p = [p0[i] + (p1[i] - p0[i]) * t for i in range(3)]
        p[1] -= sag * 4 * t * (1 - t)
        out.append(tuple(p))
    return out


def power_line(span):
    name = f"UT_PowerLine_Span{span}m"
    mb = MB()
    for x in (-1.05, 0.0, 1.05):
        mb.tube(BLACK, _catenary((x, 9.54, 0), (x, 9.54, span), 0.02 * span + 0.2), 0.012, 3)
    return model(name, mb, None, meta=dict(kind="span", span=span,
                                           desc=f"3 conductors from UT_UtilityPole attach points at z=0 to the next pole at z={span}"))


def telephone_line(span):
    name = f"UT_TelephoneLine_Span{span}m"
    mb = MB()
    mb.tube(BLACK, _catenary((0, 7.2, 0), (0, 7.2, span), 0.03 * span + 0.3), 0.02, 4)
    return model(name, mb, None, meta=dict(kind="span", span=span))


def junction_box():
    name = "UT_JunctionBox"
    mb = MB()
    mb.box(m01("Com_SignageBacking"), (-0.2, 0, 0), (0.2, 0.5, 0.18))
    mb.box(m01("Com_SignageBacking"), (-0.21, 0.5, 0), (0.21, 0.52, 0.2))
    mb.box(m01("Furn_MetalBrushed"), (0.12, 0.2, 0.18), (0.15, 0.3, 0.2))
    mb.cyl(GALV, (0, -0.6, 0.09), 0.025, 0.6, seg=6, caps=())  # conduit down
    return model(name, mb, None, meta=dict(kind="prop", desc="Wall/pole mount: origin at mounting surface, ~1.2 m high"))


def electrical_cabinet():
    name = "UT_ElectricalCabinet"
    mb = MB()
    mb.box(m01("Road_CurbConcrete"), (-0.6, 0, -0.35), (0.6, 0.1, 0.35))
    mb.box(m01("Com_SignageBacking"), (-0.5, 0.1, -0.25), (0.5, 1.45, 0.25))
    mb.box(m01("Com_SignageBacking"), (-0.53, 1.45, -0.28), (0.53, 1.5, 0.28))
    mb.box(m01("Road_RoadPatch"), (-0.005, 0.15, 0.25), (0.005, 1.4, 0.252), skip=("-z",))  # door split
    for x in (-0.25, 0.25):
        mb.box(mt("VentGrille"), (x - 0.15, 1.0, 0.25), (x + 0.15, 1.3, 0.255), skip=("-z",))
        mb.box(m01("Furn_MetalBrushed"), (x * 0.2 - 0.015, 0.7, 0.25), (x * 0.2 + 0.015, 0.82, 0.27))
    mb.box(mt("PaintYellow"), (-0.1, 0.4, 0.25), (0.1, 0.55, 0.255), skip=("-z",))
    return model(name, mb, col_box((-0.6, 0, -0.35), (0.6, 1.5, 0.35)), "convcolonly", meta=dict(kind="prop"))


def water_meter():
    name = "UT_WaterMeter"
    mb = MB()
    mb.box(m01("Road_CurbConcrete"), (-0.25, 0, -0.18), (0.25, 0.02, 0.18), skip=("-y", "+y"))
    mb.ground_poly(m01("Road_CurbConcrete"), [(-0.25, -0.18), (0.25, -0.18), (0.25, 0.18), (-0.25, 0.18)], y=0.02)
    pts = [(-0.18, 0.022, -0.12), (0.18, 0.022, -0.12), (0.18, 0.022, 0.12), (-0.18, 0.022, 0.12)]
    mb.poly(mt("UtilityCover"), pts, (0, 1, 0), uvf=lambda p: (p[0] / 0.36 + 0.5, p[2] / 0.24 + 0.5))
    return model(name, mb, None, meta=dict(kind="prop", desc="In-ground meter box, 2 cm proud"))


def ac_unit():
    name = "UT_ACUnit_Exterior"
    mb = MB()
    mb.box(m01("Road_CurbConcrete"), (-0.5, 0, -0.45), (0.5, 0.08, 0.45))
    mb.box(m01("Com_SignageBacking"), (-0.4, 0.08, -0.38), (0.4, 0.88, 0.38), mats={
        "+x": mt("VentGrille"), "-x": mt("VentGrille"), "+z": mt("VentGrille"), "-z": mt("VentGrille")})
    mb.cyl(m01("Furn_Rubber"), (0, 0.88, 0), 0.3, 0.02, seg=12, caps=("top",))
    mb.box(GALV, (-0.02, 0.9, -0.28), (0.02, 0.92, 0.28))  # fan guard bar
    blade = MB()
    blade.box(GALV, (-0.28, 0, -0.02), (0.28, 0.02, 0.02), skip=())
    mb.merge(blade, T(0, 0.9, 0) @ Ry(0.6))
    mb.tube(m01("Furn_MetalBrushed"), [(0.3, 0.3, -0.38), (0.3, 0.3, -0.6), (0.3, 1.2, -0.6)], 0.02, 4)
    mb.tube(m01("Furn_Rubber"), [(0.18, 0.3, -0.38), (0.18, 0.3, -0.6), (0.18, 1.2, -0.6)], 0.025, 4)
    return model(name, mb, col_box((-0.5, 0, -0.45), (0.5, 0.92, 0.45)), "convcolonly",
                 meta=dict(kind="prop", desc="Line set runs to the wall on the -Z side"))


def rooftop_vent():
    name = "UT_RooftopVent"
    mb = MB()
    mb.box(m01("Com_SignageBacking"), (-0.4, 0, -0.4), (0.4, 0.3, 0.4))
    mb.cyl(m01("Furn_MetalBrushed"), (0, 0.3, 0), 0.22, 0.35, seg=10, caps=())
    mb.cyl(mt("VentGrille"), (0, 0.65, 0), 0.24, 0.25, seg=10, r_top=0.3, caps=())
    mb.cyl(m01("Furn_MetalBrushed"), (0, 0.9, 0), 0.34, 0.12, seg=10, r_top=0.05, caps=("top",))
    return model(name, mb, col_box((-0.4, 0, -0.4), (0.4, 1.02, 0.4)), "convcolonly", meta=dict(kind="prop"))


def access_cover():
    name = "UT_UtilityAccessCover"
    mb = MB()
    pts = [(-0.4, 0.01, -0.4), (0.4, 0.01, -0.4), (0.4, 0.01, 0.4), (-0.4, 0.01, 0.4)]
    mb.poly(mt("UtilityCover"), pts, (0, 1, 0), uvf=lambda p: (p[0] / 0.8 + 0.5, p[2] / 0.8 + 0.5))
    mb.box(m01("Furn_MetalBrushed"), (-0.41, 0, -0.41), (0.41, 0.01, 0.41), skip=("-y", "+y"))
    return model(name, mb, None, meta=dict(kind="prop"))


PROP_MODELS = [
    ("Street_Props", lamp_residential), ("Street_Props", lamp_commercial), ("Street_Props", utility_pole_light),
    ("Street_Props", lamp_wall), ("Street_Props", stop_sign), ("Street_Props", speed_sign),
    ("Street_Props", street_name_sign), ("Street_Props", yield_sign), ("Street_Props", traffic_light),
    ("Street_Props", parking_sign), ("Street_Props", noparking_sign), ("Street_Props", deadend_sign),
    ("Street_Props", oneway_sign), ("Street_Props", road_barrier), ("Street_Props", traffic_cone),
    ("Street_Props", fire_hydrant), ("Street_Props", mailbox), ("Street_Props", trash_bin),
    ("Street_Props", dumpster), ("Street_Props", newspaper_box), ("Street_Props", bench),
    ("Street_Props", bus_stop_sign), ("Street_Props", bus_shelter), ("Street_Props", bike_rack),
    ("Street_Props", parking_meter), ("Street_Props", phone_booth), ("Street_Props", manhole),
    ("Street_Props", drain_grate),
    ("Utilities", utility_pole), ("Utilities", transformer_pole), ("Utilities", transformer_pad),
    ("Utilities", lambda: power_line(20)), ("Utilities", lambda: power_line(25)), ("Utilities", lambda: power_line(30)),
    ("Utilities", lambda: telephone_line(25)), ("Utilities", lambda: telephone_line(30)),
    ("Utilities", junction_box), ("Utilities", electrical_cabinet), ("Utilities", water_meter),
    ("Utilities", ac_unit), ("Utilities", rooftop_vent), ("Utilities", access_cover),
]
