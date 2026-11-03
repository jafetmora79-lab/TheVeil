"""Vegetation/ and Fences/ models.

Foliage is built from chunky, flat-shaded, jittered low-poly volumes using
the Pack 01 pixel textures (hedge foliage, bark, leaves) - no photographic
alpha cards. Cutout cards are used only for grass/weeds/dead foliage, with
pixel-art cutouts.

Fences: every section is 2.5 m long along +X with its *start* post at x=0;
chain sections end-to-end, rotate 90 deg at the shared post for corners, and
cap the run with the matching FN_Post_* model.
"""
import math
import zlib

import numpy as np

from veil_mesh.mesh import MB, T, Ry, Rx, Rz, S, nrm
from veil_mesh.materials import m01, mt
from veil_mesh.gltf import COL_KEY
from veil_mesh.kit import model, col_box, col_cyl

FOL, BARK = m01("Grnd_HedgeFoliage"), m01("Grnd_TreeBark")


def rng_of(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def trunk(mb, rng, h, r0, r1, lean=0.0, seg=7, mat=BARK):
    mb.cyl(mat, (0, 0, 0), r0, h, seg=seg, r_top=r1, caps=("top",), smooth=False, a0=rng.random())
    for k in range(3):  # root flare
        a = rng.random() * 2 * math.pi
        root = MB()
        root.cyl(mat, (0, 0, 0), r0 * 0.5, r0 * 1.6, seg=5, r_top=0.02, caps=(), smooth=False)
        mb.merge(root, T(math.cos(a) * r0 * 0.7, 0.0, math.sin(a) * r0 * 0.7) @ Rz(math.cos(a) * 1.1) @ Rx(-math.sin(a) * 1.1))


def branch(mb, p0, p1, r, mat=BARK):
    mb.tube(mat, [p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 + 0.2, (p0[2] + p1[2]) / 2), p1], r, 5)


def canopy(mb, rng, clusters, mat=FOL):
    for (c, rad) in clusters:
        mb.lump(mat, c, rad, rng, subdiv=1, jitter=0.16)


def tree_small():
    name = "VG_Tree_DeciduousSmall"
    rng, mb = rng_of(name), MB()
    trunk(mb, rng, 2.4, 0.13, 0.08)
    branch(mb, (0, 1.9, 0), (0.6, 2.7, 0.2), 0.05)
    canopy(mb, rng, [((0, 3.4, 0), (1.5, 1.25, 1.5)), ((0.7, 3.0, 0.3), (0.9, 0.8, 0.9)),
                     ((-0.6, 3.1, -0.4), (1.0, 0.85, 1.0)), ((0.1, 4.2, 0.1), (0.9, 0.8, 0.9))])
    return model(name, mb, col_cyl((0, 0, 0), 0.15, 2.4, 6), "convcolonly", meta=dict(kind="tree", height=5.0))


def tree_large():
    name = "VG_Tree_DeciduousLarge"
    rng, mb = rng_of(name), MB()
    trunk(mb, rng, 3.8, 0.34, 0.22, seg=8)
    for (x, y, z) in ((1.8, 5.6, 0.6), (-1.6, 5.2, -0.8), (0.4, 6.0, -1.6), (-0.4, 5.8, 1.5)):
        branch(mb, (0, 3.4, 0), (x, y, z), 0.11)
    canopy(mb, rng, [((0, 7.0, 0), (3.0, 2.3, 3.0)), ((2.0, 6.0, 0.8), (2.0, 1.6, 2.0)),
                     ((-1.9, 5.9, -0.9), (2.1, 1.7, 2.1)), ((0.5, 6.2, -2.0), (1.9, 1.5, 1.9)),
                     ((-0.4, 6.1, 1.9), (1.9, 1.5, 1.9)), ((0.2, 8.6, 0.2), (1.8, 1.4, 1.8))])
    return model(name, mb, col_cyl((0, 0, 0), 0.36, 3.8, 8), "convcolonly", meta=dict(kind="tree", height=10.0))


def tree_pine():
    name = "VG_Tree_Pine"
    rng, mb = rng_of(name), MB()
    trunk(mb, rng, 2.0, 0.2, 0.12)
    mb.cyl(BARK, (0, 2.0, 0), 0.12, 6.0, seg=6, r_top=0.04, caps=(), smooth=False)
    P = mt("PineNeedles")
    tiers = [(1.2, 2.3, 2.2), (2.6, 1.9, 2.0), (3.9, 1.5, 1.9), (5.1, 1.1, 1.8), (6.2, 0.7, 1.7)]
    for (y, r, h) in tiers:
        tier = MB()
        tier.cyl(P, (0, 0, 0), r, h, seg=7, r_top=0.08, caps=("top", "bottom"), smooth=False, a0=rng.random() * 3)
        # droop: jitter the skirt so tiers are not perfect cones
        g = tier.parts[P]
        g["p"] = [(p[0], p[1] - (0.18 * rng.random() if p[1] < 0.01 else 0), p[2]) for p in g["p"]]
        mb.merge(tier, T(0, y, 0))
    return model(name, mb, col_cyl((0, 0, 0), 0.22, 3.0, 6), "convcolonly", meta=dict(kind="tree", height=8.0))


def tree_dead():
    name = "VG_Tree_Dead"
    rng, mb = rng_of(name), MB()
    wood = m01("Hor_WoodDarkened")
    trunk(mb, rng, 3.2, 0.24, 0.12, mat=BARK)

    def grow(p, d, length, r, depth):
        q = (p[0] + d[0] * length, p[1] + d[1] * length, p[2] + d[2] * length)
        mb.tube(BARK if depth < 2 else wood, [p, q], r, 5 if depth < 2 else 3)
        if depth >= 3:
            return
        for _ in range(2 if depth else 3):
            nd = nrm(np.array(d) + rng.normal(0, 0.6, 3) + np.array([0, 0.25, 0]))
            grow(q, nd, length * rng.uniform(0.55, 0.75), r * 0.6, depth + 1)
    grow((0, 3.0, 0), (0.1, 1, 0.05), 1.6, 0.12, 0)
    for _ in range(2):  # snapped stubs
        a = rng.random() * 6.28
        mb.tube(BARK, [(0, 2.0, 0), (math.cos(a) * 0.7, 2.3, math.sin(a) * 0.7)], 0.06, 4)
    return model(name, mb, col_cyl((0, 0, 0), 0.26, 3.2, 6), "convcolonly", meta=dict(kind="tree", height=7.0))


def tree_overgrown():
    name = "VG_Tree_Overgrown"
    rng, mb = rng_of(name), MB()
    trunk(mb, rng, 3.0, 0.3, 0.2, seg=8)
    for (x, y, z) in ((1.7, 4.6, 0.5), (-1.5, 4.3, -0.6), (0.2, 5.0, 1.6)):
        branch(mb, (0, 2.8, 0), (x, y, z), 0.1)
    canopy(mb, rng, [((0, 5.6, 0), (2.6, 2.0, 2.6)), ((1.9, 4.7, 0.6), (1.7, 1.5, 1.7)),
                     ((-1.7, 4.5, -0.7), (1.8, 1.6, 1.8)), ((0.3, 4.9, 1.8), (1.6, 1.4, 1.6))])
    canopy(mb, rng, [((-0.8, 6.6, -0.6), (1.3, 1.0, 1.3))], mat=m01("Grnd_DeadVegetation"))
    iv = mt("Ivy")
    for k in range(6):  # ivy curtains hanging from the canopy edge + climbing the trunk
        a = k * math.pi / 3 + rng.random() * 0.4
        r = 2.2
        x, z = math.cos(a) * r, math.sin(a) * r
        top, bot = 4.4, 1.6 + rng.random()
        t = (-math.sin(a) * 0.7, math.cos(a) * 0.7)
        mb.quad(iv, [x - t[0], bot, z - t[1]], [x + t[0], bot, z + t[1]], [x + t[0], top, z + t[1]], [x - t[0], top, z - t[1]],
                n=(math.cos(a), 0, math.sin(a)))
    for k in range(4):
        a = k * math.pi / 2
        x, z = math.cos(a) * 0.31, math.sin(a) * 0.31
        t = (-math.sin(a) * 0.25, math.cos(a) * 0.25)
        mb.quad(iv, [x - t[0], 0.1, z - t[1]], [x + t[0], 0.1, z + t[1]], [x + t[0], 2.6, z + t[1]], [x - t[0], 2.6, z - t[1]],
                n=(math.cos(a), 0, math.sin(a)))
    return model(name, mb, col_cyl((0, 0, 0), 0.32, 3.0, 8), "convcolonly", meta=dict(kind="tree", height=8.0))


def bush():
    name = "VG_Bush"
    rng, mb = rng_of(name), MB()
    canopy(mb, rng, [((0, 0.55, 0), (0.85, 0.6, 0.8)), ((0.5, 0.45, 0.3), (0.55, 0.45, 0.55)),
                     ((-0.45, 0.42, -0.25), (0.55, 0.42, 0.55))])
    return model(name, mb, col_box((-0.8, 0, -0.7), (0.8, 1.0, 0.7)), "convcolonly", meta=dict(kind="plant"))


def hedge_block(name, L=2.5, h=1.2, d=0.8, lumps=4):
    rng, mb = rng_of(name), MB()
    # boxy trimmed core + jittered lumps on top for a hand-clipped silhouette
    mb.box(FOL, (0, 0, -d / 2), (L, h * 0.8, d / 2), skip=("-y",))
    for k in range(lumps):
        x = (k + 0.5) * L / lumps
        mb.lump(FOL, (x, h * 0.8, 0), (L / lumps * 0.75, h * 0.25, d * 0.55), rng, subdiv=1, jitter=0.12)
    return mb


def hedge():
    name = "VG_Hedge"
    mb = hedge_block(name, 1.5, 1.1, 0.8, 2)
    return model(name, mb, col_box((0, 0, -0.4), (1.5, 1.1, 0.4)), "convcolonly", meta=dict(kind="plant"))


def cards(mb, mat, w, h, n, uv, rng, spread=0.15):
    """Crossed cutout cards (double-sided material) for grass/weeds."""
    u0, u1 = uv
    for k in range(n):
        a = k * math.pi / n + rng.random() * 0.3
        ox, oz = rng.uniform(-spread, spread), rng.uniform(-spread, spread)
        dx, dz = math.cos(a) * w / 2, math.sin(a) * w / 2
        pts = [[ox - dx, 0, oz - dz], [ox + dx, 0, oz + dz], [ox + dx, h, oz + dz], [ox - dx, h, oz - dz]]
        mb.quad(mat, *pts, n=(-math.sin(a), 0, math.cos(a)), uv=[(u0, 1), (u1, 1), (u1, 0), (u0, 0)])


def tall_grass():
    name = "VG_TallGrassClump"
    rng, mb = rng_of(name), MB()
    cards(mb, mt("GrassCards"), 1.0, 0.95, 3, (0.0, 0.5), rng)
    return model(name, mb, None, meta=dict(kind="plant", desc="No collision: walk-through"))


def weeds():
    name = "VG_Weeds"
    rng, mb = rng_of(name), MB()
    cards(mb, mt("GrassCards"), 0.9, 0.85, 3, (0.5, 1.0), rng)
    return model(name, mb, None, meta=dict(kind="plant"))


def flower_patch():
    name = "VG_FlowerPatch"
    rng, mb = rng_of(name), MB()
    mb.lump(mt("FlowerBed"), (0, 0.0, 0), (1.0, 0.22, 0.7), rng, subdiv=1, jitter=0.1)
    mb.lump(mt("FlowerBed"), (0.8, 0.0, 0.3), (0.6, 0.16, 0.5), rng, subdiv=1, jitter=0.1)
    return model(name, mb, None, meta=dict(kind="plant"))


def dead_vegetation():
    name = "VG_DeadVegetation"
    rng, mb = rng_of(name), MB()
    mb.lump(m01("Grnd_DeadVegetation"), (0, 0.0, 0), (0.7, 0.15, 0.6), rng, subdiv=1, jitter=0.15)
    cards(mb, m01("Hor_FoliageDead"), 0.9, 0.9, 2, (0.0, 1.0), rng)
    return model(name, mb, None, meta=dict(kind="plant"))


def ivy_patch():
    name = "VG_IvyPatch"
    rng, mb = rng_of(name), MB()
    n = 4
    for i in range(n):
        for j in range(n):
            x0, x1 = i * 0.5, (i + 1) * 0.5
            y0, y1 = j * 0.5, (j + 1) * 0.5
            z = [0.02 + 0.04 * rng.random() for _ in range(4)]
            if rng.random() < 0.2 and j == n - 1:
                continue  # ragged top edge
            mb.quad(mt("Ivy"), [x0, y0, z[0]], [x1, y0, z[1]], [x1, y1, z[2]], [x0, y1, z[3]], n=(0, 0, 1),
                    uv=[(x0, -y0), (x1, -y0), (x1, -y1), (x0, -y1)])
    return model(name, mb, None, meta=dict(kind="plant", desc="2 x 2 m wall ivy; origin at wall base-left, faces +Z"))


def dirt_mound():
    name = "VG_DirtMound"
    rng, mb = rng_of(name), MB()
    mb.lump(m01("Grnd_Soil"), (0, 0, 0), (1.3, 0.55, 1.0), rng, subdiv=1, jitter=0.15)
    return model(name, mb, col_box((-1.1, 0, -0.85), (1.1, 0.45, 0.85)), "convcolonly", meta=dict(kind="ground"))


def rocks():
    name = "VG_RocksSmall"
    rng, mb = rng_of(name), MB()
    for (c, r) in (((0, 0.15, 0), (0.45, 0.35, 0.35)), ((0.55, 0.08, 0.25), (0.25, 0.2, 0.22)),
                   ((-0.4, 0.06, 0.3), (0.2, 0.15, 0.18)), ((0.2, 0.05, -0.4), (0.18, 0.12, 0.15))):
        mb.lump(mt("Rock"), c, r, rng, subdiv=0, jitter=0.25, squash_bottom=True)
    return model(name, mb, col_box((-0.5, 0, -0.45), (0.8, 0.45, 0.5)), "convcolonly", meta=dict(kind="ground"))


def gravel_pile():
    name = "VG_GravelPile"
    rng, mb = rng_of(name), MB()
    mb.cyl(m01("Road_Gravel"), (0, -0.02, 0), 1.2, 0.75, seg=9, r_top=0.15, caps=("top",), smooth=False)
    return model(name, mb, col_cyl((0, 0, 0), 1.1, 0.7, 8), "convcolonly", meta=dict(kind="ground"))


def flat_patch(name, mat, r, n=10, y=0.012):
    rng, mb = rng_of(name), MB()
    pts = [(r * (0.7 + 0.4 * rng.random()) * math.cos(2 * math.pi * k / n),
            r * (0.6 + 0.35 * rng.random()) * math.sin(2 * math.pi * k / n)) for k in range(n)]
    mb.ground_poly(mat, pts, y=y)
    return mb


def fallen_leaves():
    name = "VG_FallenLeaves"
    return model(name, flat_patch(name, m01("Grnd_LeavesFallen"), 1.6), None, meta=dict(kind="ground", desc="Ground decal, 12 mm proud"))


def mud_patch():
    name = "VG_MudPatch"
    return model(name, flat_patch(name, m01("Grnd_Mud"), 1.4, y=0.01), None, meta=dict(kind="ground"))


def stump():
    name = "VG_TreeStump"
    rng, mb = rng_of(name), MB()
    mb.cyl(BARK, (0, 0, 0), 0.38, 0.42, seg=9, r_top=0.33, caps=(), smooth=False)
    top = [(0.33 * math.cos(2 * math.pi * k / 9), 0.42, 0.33 * math.sin(2 * math.pi * k / 9)) for k in range(9)]
    mb.poly(mt("StumpTop"), top, (0, 1, 0), uvf=lambda p: (p[0] / 0.7 + 0.5, p[2] / 0.7 + 0.5))
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        root = MB()
        root.cyl(BARK, (0, 0, 0), 0.12, 0.5, seg=5, r_top=0.02, caps=(), smooth=False)
        mb.merge(root, T(math.cos(a) * 0.3, 0.05, math.sin(a) * 0.3) @ Rz(math.cos(a) * 1.3) @ Rx(-math.sin(a) * 1.3))
    return model(name, mb, col_cyl((0, 0, 0), 0.38, 0.42, 8), "convcolonly", meta=dict(kind="ground"))


def fallen_branch():
    name = "VG_FallenBranch"
    rng, mb = rng_of(name), MB()
    mb.tube(BARK, [(-1.4, 0.09, 0), (-0.3, 0.1, 0.15), (0.8, 0.07, 0.05), (1.5, 0.05, -0.15)], 0.09, 5, caps=True)
    mb.tube(BARK, [(0.0, 0.1, 0.12), (0.6, 0.08, 0.7), (0.9, 0.05, 1.0)], 0.045, 4, caps=True)
    mb.tube(BARK, [(-0.6, 0.1, 0.05), (-1.0, 0.25, -0.5)], 0.03, 3, caps=True)
    return model(name, mb, col_box((-1.5, 0, -0.2), (1.5, 0.2, 0.25)), "convcolonly", meta=dict(kind="ground"))


# ============================================================================
# FENCES (2.5 m sections along +X, start post at x=0)
# ============================================================================
L = 2.5
PAINT = m01("Arch_TrimPainted")


def picket_fence():
    name = "FN_Picket_2.5m"
    mb = MB()
    mb.box(PAINT, (-0.05, 0, -0.05), (0.05, 1.05, 0.05))
    mb.cyl(PAINT, (0, 1.05, 0), 0.06, 0.06, seg=4, r_top=0.0, caps=(), smooth=False, a0=math.pi / 4)
    for y in (0.25, 0.7):
        mb.box(PAINT, (0.05, y, -0.04), (L - 0.05, y + 0.08, -0.01))
    x = 0.12
    while x < L - 0.1:
        prof = [(-0.045, 0.05), (0.045, 0.05), (0.045, 0.82), (0.0, 0.92), (-0.045, 0.82)]
        p = MB()
        p.prism(PAINT, prof, -0.0, 0.025)
        mb.merge(p, T(x, 0, 0))
        x += 0.15
    return model(name, mb, col_box((0, 0, -0.06), (L, 1.0, 0.06)), "convcolonly", meta=dict(kind="fence", length=L))


def privacy_fence():
    name = "FN_Privacy_2.5m"
    mb = MB()
    planks = m01("Arch_WoodPlanksAged")
    mb.box(planks, (-0.06, 0, -0.06), (0.06, 1.9, 0.06))
    for y in (0.3, 1.45):
        mb.box(planks, (0.06, y, -0.1), (L - 0.06, y + 0.09, -0.05))
    # vertical boards: rotate the plank texture so its grain runs vertically
    x = 0.06
    while x < L - 0.05:
        w = min(0.14, L - 0.06 - x)
        x0, x1 = x + 0.005, x + w - 0.005
        for zf, nz in ((0.0, 1), (-0.02, -1)):
            pts = [[x0, 0.05, zf], [x1, 0.05, zf], [x1, 1.8, zf], [x0, 1.8, zf]]
            uv = [(-p[1], p[0]) for p in pts]
            mb.quad(planks, *pts, n=(0, 0, nz), uv=uv)
        mb.quad(planks, [x0, 1.8, -0.02], [x1, 1.8, -0.02], [x1, 1.8, 0.0], [x0, 1.8, 0.0], n=(0, 1, 0))
        x += 0.14
    return model(name, mb, col_box((0, 0, -0.1), (L, 1.85, 0.02)), "convcolonly", meta=dict(kind="fence", length=L))


def chainlink_fence():
    name = "FN_ChainLink_2.5m"
    mb = MB()
    mb.cyl(m01("Furn_MetalBrushed"), (0, 0, 0), 0.03, 1.55, seg=6, caps=("top",))
    mb.cyl(m01("Furn_MetalBrushed"), (0, 1.55, 0), 0.04, 0.05, seg=6, r_top=0.02, caps=("top",))
    mb.tube(m01("Furn_MetalBrushed"), [(0.0, 1.5, 0.0), (L, 1.5, 0.0)], 0.02, 4)
    pts = [[0.03, 0.03, 0], [L - 0.03, 0.03, 0], [L - 0.03, 1.5, 0], [0.03, 1.5, 0]]
    mb.quad(mt("ChainLink"), *pts, n=(0, 0, 1), uv=[(p[0], -p[1]) for p in pts])
    mb.tube(m01("Furn_MetalBrushed"), [(0.0, 0.05, 0.0), (L, 0.05, 0.0)], 0.006, 3)  # tension wire
    return model(name, mb, col_box((0, 0, -0.03), (L, 1.55, 0.03)), "convcolonly", meta=dict(kind="fence", length=L))


def metal_railing():
    name = "FN_MetalRailing_2.5m"
    mb = MB()
    mb.box(BLACK_, (-0.03, 0, -0.03), (0.03, 1.05, 0.03))
    mb.box(BLACK_, (-0.04, 1.05, -0.04), (0.04, 1.1, 0.04))
    mb.box(BLACK_, (0.03, 0.98, -0.025), (L - 0.03, 1.02, 0.025))
    mb.box(BLACK_, (0.03, 0.1, -0.02), (L - 0.03, 0.13, 0.02))
    x = 0.15
    while x < L - 0.05:
        mb.box(BLACK_, (x - 0.008, 0.13, -0.008), (x + 0.008, 0.98, 0.008), skip=("-y", "+y"))
        x += 0.12
    return model(name, mb, col_box((0, 0, -0.04), (L, 1.1, 0.04)), "convcolonly", meta=dict(kind="fence", length=L))


BLACK_ = mt("PaintBlack")


def brick_wall():
    name = "FN_BrickWall_2.5m"
    mb = MB()
    mb.box(m01("Arch_BrickRed"), (0.2, 0, -0.15), (L, 0.85, 0.15))
    mb.box(m01("Arch_BrickRed"), (-0.2, 0, -0.2), (0.2, 1.0, 0.2))  # pier
    mb.box(m01("Arch_ConcreteFoundation"), (-0.24, 1.0, -0.24), (0.24, 1.08, 0.24))
    mb.box(m01("Arch_ConcreteFoundation"), (0.2, 0.85, -0.18), (L, 0.92, 0.18))
    return model(name, mb, col_box((-0.2, 0, -0.2), (L, 1.08, 0.2)), "convcolonly", meta=dict(kind="fence", length=L))


def retaining_wall():
    name = "FN_RetainingWall_2.5m"
    mb = MB()
    prof = [(-0.25, 0.0), (0.25, 0.0), (0.18, 1.2), (-0.18, 1.2)]
    p = MB()
    p.prism(m01("Arch_ConcreteFoundation"), prof, 0.0, L)  # battered profile extruded along local Z
    mb.merge(p, Ry(math.pi / 2))                             # ... which becomes +X
    return model(name, mb, col_box((0, 0, -0.25), (L, 1.2, 0.25)), "convcolonly", meta=dict(kind="fence", length=L))


def gate_leaf_privacy():
    leaf = MB()
    planks = m01("Arch_WoodPlanksAged")
    w = 1.15
    x = 0.0
    while x < w - 0.01:
        x0, x1 = x + 0.005, min(x + 0.135, w)
        for zf, nz in ((0.0, 1), (-0.02, -1)):
            pts = [[x0, 0.08, zf], [x1, 0.08, zf], [x1, 1.78, zf], [x0, 1.78, zf]]
            leaf.quad(planks, *pts, n=(0, 0, nz), uv=[(-p[1], p[0]) for p in pts])
        x += 0.14
    for y in (0.3, 1.45):
        leaf.box(planks, (0.02, y, -0.07), (w - 0.02, y + 0.09, -0.02))
    leaf.tube(planks, [(0.05, 0.35, -0.045), (w - 0.05, 1.45, -0.045)], 0.03, 4)  # Z brace
    leaf.box(m01("Furn_MetalBrushed"), (w - 0.12, 1.0, 0.0), (w - 0.06, 1.12, 0.04))  # latch
    return leaf


def fence_gate():
    name = "FN_FenceGate_Privacy_1.25m"
    mb = MB()
    mb.box(m01("Arch_WoodPlanksAged"), (-0.06, 0, -0.06), (0.06, 1.95, 0.06))
    return model(name, mb, col_box((-0.06, 0, -0.06), (0.06, 1.95, 0.06)), "convcolonly",
                 extra=[{"name": "GateLeaf", "mb": gate_leaf_privacy(), "t": (0.07, 0, 0)},
                        {"name": "GateLeaf_Col-convcolonly", "mb": col_box((0.07, 0, -0.08), (1.22, 1.8, 0.02))}],
                 meta=dict(kind="fence", length=1.25, interactive=True,
                           desc="Hinge post at x=0; GateLeaf node pivots on its hinge (rotate Y to open)"))


def garden_gate():
    name = "FN_GardenGate_1.25m"
    mb = MB()
    mb.box(PAINT, (-0.06, 0, -0.06), (0.06, 1.15, 0.06))
    mb.cyl(PAINT, (0, 1.15, 0), 0.07, 0.07, seg=4, r_top=0.0, caps=(), smooth=False, a0=math.pi / 4)
    leaf = MB()
    for y in (0.25, 0.7):
        leaf.box(PAINT, (0.0, y, -0.04), (1.12, y + 0.08, -0.01))
    x = 0.07
    while x < 1.1:
        h = 0.85 + 0.12 * math.sin(math.pi * x / 1.12)  # gentle arched top
        prof = [(-0.04, 0.08), (0.04, 0.08), (0.04, h), (0.0, h + 0.08), (-0.04, h)]
        pk = MB()
        pk.prism(PAINT, prof, 0.0, 0.022)
        leaf.merge(pk, T(x, 0, 0))
        x += 0.14
    leaf.tube(PAINT, [(0.05, 0.3, -0.03), (1.07, 0.72, -0.03)], 0.02, 4)
    return model(name, mb, col_box((-0.06, 0, -0.06), (0.06, 1.15, 0.06)), "convcolonly",
                 extra=[{"name": "GateLeaf", "mb": leaf, "t": (0.08, 0, 0)},
                        {"name": "GateLeaf_Col-convcolonly", "mb": col_box((0.08, 0, -0.05), (1.2, 1.0, 0.03))}],
                 meta=dict(kind="fence", length=1.25, interactive=True))


def hedge_boundary():
    name = "FN_HedgeBoundary_2.5m"
    mb = hedge_block(name, L, 1.3, 0.9, 3)
    return model(name, mb, col_box((0, 0, -0.45), (L, 1.3, 0.45)), "convcolonly", meta=dict(kind="fence", length=L))


def post_model(name, kind):
    mb = MB()
    if kind == "picket":
        mb.box(PAINT, (-0.05, 0, -0.05), (0.05, 1.05, 0.05))
        mb.cyl(PAINT, (0, 1.05, 0), 0.06, 0.06, seg=4, r_top=0.0, caps=(), smooth=False, a0=math.pi / 4)
        col = col_box((-0.05, 0, -0.05), (0.05, 1.1, 0.05))
    elif kind == "privacy":
        mb.box(m01("Arch_WoodPlanksAged"), (-0.06, 0, -0.06), (0.06, 1.9, 0.06))
        col = col_box((-0.06, 0, -0.06), (0.06, 1.9, 0.06))
    else:
        mb.cyl(m01("Furn_MetalBrushed"), (0, 0, 0), 0.035, 1.6, seg=6, caps=("top",))
        col = col_cyl((0, 0, 0), 0.04, 1.6, 6)
    return model(name, mb, col, "convcolonly", meta=dict(kind="fence", length=0))


NATURE_MODELS = [
    ("Vegetation", tree_small), ("Vegetation", tree_large), ("Vegetation", tree_pine), ("Vegetation", tree_dead),
    ("Vegetation", tree_overgrown), ("Vegetation", bush), ("Vegetation", hedge), ("Vegetation", tall_grass),
    ("Vegetation", weeds), ("Vegetation", flower_patch), ("Vegetation", dead_vegetation), ("Vegetation", ivy_patch),
    ("Vegetation", dirt_mound), ("Vegetation", rocks), ("Vegetation", gravel_pile), ("Vegetation", fallen_leaves),
    ("Vegetation", stump), ("Vegetation", fallen_branch), ("Vegetation", mud_patch),
    ("Fences", picket_fence), ("Fences", privacy_fence), ("Fences", chainlink_fence), ("Fences", metal_railing),
    ("Fences", brick_wall), ("Fences", retaining_wall), ("Fences", fence_gate), ("Fences", garden_gate),
    ("Fences", hedge_boundary),
    ("Fences", lambda: post_model("FN_Post_Picket", "picket")),
    ("Fences", lambda: post_model("FN_Post_Privacy", "privacy")),
    ("Fences", lambda: post_model("FN_Post_ChainLink", "chain")),
]
