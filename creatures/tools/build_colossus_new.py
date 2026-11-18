"""THE VEIL - a NEW Colossus, modelled from scratch in Blender (Blender 5.x).
   blender -b -P creatures/tools/build_colossus_new.py -- <out_rigged.glb> <out.blend>
Keeps the original skeleton (62 bones, same joint positions, bone names, sockets) so every clip, cinematic and collider still fits, but throws the old mesh away.
Design: a gaunt, wrong, ancient thing. Hunched ribcage with exposed rib arches and a ridge of vertebral spikes, a sagging pale belly sac, a long neck
and a narrow skull with a split mandible-maw, horns and two eye stalks. Long stilted legs with big elbow knuckles and spurs, claw toes; the front-left leg is
thicker and the rear-right leg ends in a broken claw. Tentacle chains are tapered tubes with barbed tips, rooted in the spine and flanks.
Pipeline: primitives -> voxel remesh union (organic mass) -> decimate; details (bone, tentacles, lower legs) stay separate; box-projected UVs on three
128 px pixel textures (hide / bone plate / tentacle) + an emission map of faint cracks; weights by nearest bone segment."""
import bpy, bmesh, sys, os, math, random
import numpy as np
from mathutils import Matrix, Vector

OUT_GLB, OUT_BLEND = sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2]
SRC = "THE_VEIL_ASSETS_V2/07_Creatures/Colossus/CRT_Colossus.glb"
random.seed(21)
rng = np.random.default_rng(21)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SRC))
arm = bpy.data.objects["CRT_Colossus"]
old_mesh = bpy.data.objects["CRT_Colossus_Mesh"]
bpy.data.objects.remove(old_mesh)
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
if arm.animation_data:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    arm.animation_data.action = None
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
for m in list(bpy.data.materials):
    bpy.data.materials.remove(m)
H = {b.name: b.head_local.copy() for b in arm.data.bones}


def V(*a):
    return Vector(a)


# ---------------------------------------------------------------------------------------------------------------- geometry helpers
def ellipsoid(bm, c, r, seg=20, rings=14, lump=0.0, rot=None, seed=0):
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    vs = res["verts"]
    rr = random.Random(seed)
    ph = [rr.random() * 6.28 for _ in range(4)]
    for v in vs:
        p = v.co.copy()
        n = 1.0 + lump * (math.sin(p.x * 3.1 + ph[0]) * math.sin(p.y * 2.7 + ph[1]) + .6 * math.sin(p.z * 4.3 + ph[2]) * math.sin(p.x * 1.9 + ph[3]))
        v.co = Vector((p.x * r[0] * n, p.y * r[1] * n, p.z * r[2] * n))
    if rot is not None:
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=rot, verts=vs)
    bmesh.ops.translate(bm, vec=c, verts=vs)
    return vs


def frames(pts):
    tans = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        tans.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(tans[0].z) < .9 else Vector((1, 0, 0))
    n0 = tans[0].cross(ref).normalized()
    out = []
    n = n0
    for t in tans:
        n = (n - t * n.dot(t)).normalized()
        out.append((t, n, t.cross(n).normalized()))
    return out


def tube(bm, pts, radii, sides=8, cap_start=True, cap_end=True, flat=1.0):
    pts = [Vector(p) for p in pts]
    fr = frames(pts)
    rings = []
    for p, r, (t, n, b) in zip(pts, radii, fr):
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a) * flat) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    if cap_start:
        c = bm.verts.new(pts[0] - fr[0][0] * radii[0] * .4)
        for k in range(sides):
            bm.faces.new((rings[0][(k + 1) % sides], rings[0][k], c))
    if cap_end:
        c = bm.verts.new(pts[-1] + fr[-1][0] * radii[-1] * .6)
        for k in range(sides):
            bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], c))
    return rings


def cone(bm, base, tip, rad, sides=6):
    return tube(bm, [base, tip], [rad, rad * .08], sides, cap_start=True, cap_end=False)


def lerp_pts(a, b, n):
    return [a.lerp(b, i / (n - 1)) for i in range(n)]


def bez(p0, p1, p2, n=8):
    out = []
    for i in range(n):
        t = i / (n - 1)
        out.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2)
    return out


def taper(n, r0, r1, power=1.0):
    return [r0 + (r1 - r0) * (i / (n - 1)) ** power for i in range(n)]


mass = bmesh.new()      # remeshed into one organic body
bone = bmesh.new()      # plates, spikes, ribs, horns, claws
tent = bmesh.new()      # tentacles
hide_d = bmesh.new()    # separate hide parts (lower legs, eye stalks, tail)

# ------------------------------------------------------------------------------------------------------------ body mass
ellipsoid(mass, V(0, -0.6, 10.3), (2.8, 4.8, 2.5), lump=.07, seed=1)               # ribcage
ellipsoid(mass, V(0, -3.3, 10.6), (2.5, 2.2, 2.4), lump=.08, seed=2)               # shoulder hump
ellipsoid(mass, V(0, 3.4, 9.7), (2.4, 2.8, 2.1), lump=.07, seed=3)                  # pelvis
ellipsoid(mass, V(0, 0.5, 8.1), (1.9, 3.6, 1.7), lump=.12, seed=4)                  # belly sac
ellipsoid(mass, V(0, -7.1, 8.4), (1.15, 2.3, 1.25), lump=.05, seed=5)               # skull
ellipsoid(mass, V(0, -5.6, 8.9), (1.3, 1.3, 1.1), lump=.04, seed=6)                 # jaw root
tube(mass, [V(0, -4.0, 10.5), V(0, -4.9, 10.1), V(0, -5.8, 9.4), V(0, -6.3, 8.8)], [1.8, 1.5, 1.25, 1.1], 14)    # neck
# legs: hip bar, elbow knuckle, shin (tapering), ankle
LEG = {"FL": ("Chest", (-1, 1.0)), "FR": ("Chest", (1, 1.0)), "HL": ("Rear", (-1, 1.0)), "HR": ("Rear", (1, 1.0))}
TIPS = {"FL": V(-6.7, -7.1, 0), "FR": V(6.4, -6.7, 0), "HL": V(-5.0, 3.1, 0), "HR": V(3.6, 3.4, 0)}
for leg, (par, (sx, k)) in LEG.items():
    A, B, C, T = H[f"Leg_{leg}_Upper"], H[f"Leg_{leg}_Lower"], H[f"Leg_{leg}_Foot"], TIPS[leg]
    thick = 1.12 if leg == "FL" else 1.0
    inner = A + V(-sx * 1.4, 0, -.2)
    tube(mass, [inner, A, A.lerp(B, .5) + V(0, 0, .15), B], [1.35, 1.25 * thick, 1.1 * thick, 1.15 * thick], 12, cap_start=False, cap_end=False)
    ellipsoid(mass, B, (1.25 * thick, 1.25 * thick, 1.2 * thick), seg=14, rings=10, lump=.06, seed=hash(leg) % 97)
    mid = B.lerp(C, .45) + V(sx * .25, -.35, 0)
    tube(mass, [B, mid, C], [1.05 * thick, .78 * thick, .55 * thick], 10, cap_start=False, cap_end=False)
    ellipsoid(mass, C, (.62, .62, .62), seg=12, rings=8, seed=7)
# eye stalks' roots and tail root
tube(mass, [V(0, 5.0, 9.6), V(0, 6.6, 9.2)], [1.5, 1.0], 12)

# ---------------------------------------------------------------------------------------------------------- bone / plates
def surf_z(y):
    zs = []
    for c, r in (((0, -0.6, 10.3), (2.8, 4.8, 2.5)), ((0, -3.3, 10.6), (2.5, 2.2, 2.4)), ((0, 3.4, 9.7), (2.4, 2.8, 2.1))):
        t = 1 - ((y - c[1]) / r[1]) ** 2
        if t > 0:
            zs.append(c[2] + r[2] * math.sqrt(t))
    return max(zs) if zs else 9.0


for i in range(11):                                                              # vertebral ridge: spikes lean back, biggest over the shoulders
    y = -5.0 + i * 1.05
    z = surf_z(y)
    ln = [1.5, 2.0, 2.6, 2.9, 2.4, 2.0, 1.8, 1.6, 1.4, 1.1, .8][i]
    cone(bone, V(0, y, z - .45), V(0, y + .8 + .06 * ln, z + ln), .42 + .03 * ln, 6)
for i in range(7):                                                               # exposed rib arches on both flanks (the belly sac hangs between them)
    y = -3.3 + i * 1.15
    for sx in (-1, 1):
        pts = []
        for j in range(9):
            th = math.radians(16 + j * 10.5)
            rx, rz = 2.95 - .12 * abs(i - 3), 2.7
            pts.append(V(sx * rx * math.sin(th), y + .25 * math.sin(th * 2), 10.3 + rz * math.cos(th) - .05 * (i - 3) ** 2 * .1))
        tube(bone, pts, taper(9, .34, .17), 6, cap_start=False)
for sx in (-1, 1):                                                               # mandible blades of the split maw
    pts = bez(V(sx * .55, -8.0, 8.2), V(sx * 1.5, -9.6, 7.4), V(sx * .4, -11.0, 5.9), 9)
    tube(bone, pts, taper(9, .6, .08, .8), 7)
    for t in range(4):                                                           # teeth along the inside edge
        p = pts[2 + t]
        cone(bone, p + V(-sx * .15, 0, .1), p + V(-sx * .75, -.25, .55 - .12 * t), .16, 5)
    pts = bez(V(sx * .6, -6.5, 9.6), V(sx * 1.9, -7.2, 11.6), V(sx * 1.0, -8.8, 12.7), 8)   # brow horns
    tube(bone, pts, taper(8, .42, .05, .9), 6)
for leg, (par, (sx, k)) in LEG.items():
    B = H[f"Leg_{leg}_Lower"]
    big = 1.45 if leg == "FL" else 1.0
    cone(bone, B + V(sx * .5, .3, .6), B + V(sx * 1.4, .9, 2.4 * big), .6 * big, 6)         # elbow spur
    cone(bone, B + V(sx * .6, -.9, .2), B + V(sx * 1.5, -1.7, .9), .35 * big, 5)
    A = H[f"Leg_{leg}_Upper"]
    for t in range(3):                                                                       # armour ridge down the shin
        p = H[f"Leg_{leg}_Lower"].lerp(H[f"Leg_{leg}_Foot"], .2 + t * .22)
        cone(bone, p + V(0, .5, .2), p + V(sx * .5, 1.2, .5), .3, 5)
# claws (toes)
for leg, T in TIPS.items():
    sx = -1 if T.x < 0 else 1
    C = H[f"Leg_{leg}_Foot"]
    toe_n = 2 if leg == "HR" else 3                                                  # the rear-right foot lost a toe
    for t in range(toe_n):
        sp = (t - (toe_n - 1) / 2) * .85
        base = T + V(sx * .25 + sp * .4, .15, .55)
        tube(bone, bez(base, base + V(sp * .9, -1.0, .35), base + V(sp * 1.3, -2.1, -.45), 6), taper(6, .38, .06), 6)
    tube(bone, bez(T + V(0, .6, .6), T + V(sx * .5, 1.4, .8), T + V(sx * 1.0, 1.9, .2), 5), taper(5, .3, .06), 5)

# -------------------------------------------------------------------------------------------------------------- lower legs (hide, separate)
for leg, T in TIPS.items():
    sx = -1 if T.x < 0 else 1
    C = H[f"Leg_{leg}_Foot"]
    thick = 1.12 if leg == "FL" else 1.0
    tube(hide_d, [C, C.lerp(T + V(0, 0, .7), .5) + V(sx * .12, -.2, 0), T + V(0, 0, .55)], [.56 * thick, .42, .5], 9)
for sx in (-1, 1):                                                               # eye stalks and bulbs
    s1, s2 = H["Stalk_%s_01" % ("L" if sx < 0 else "R")], H["Stalk_%s_02" % ("L" if sx < 0 else "R")]
    pts = bez(s1 + V(0, .3, .3), s1.lerp(s2, .6) + V(sx * .4, -.4, .5), s2 + V(sx * .6, -1.0, -.4), 8)
    tube(hide_d, pts, taper(8, .34, .14), 7)
    ellipsoid(bone, pts[-1] + V(0, -.25, 0), (.55, .65, .55), seg=10, rings=8, seed=9)

# ------------------------------------------------------------------------------------------------------------------- tentacles
GROUPS = {"DorsalL": [f"T_DorsalL_0{i}" for i in range(1, 9)], "DorsalR": [f"T_DorsalR_0{i}" for i in range(1, 8)],
          "FlankL": [f"T_FlankL_0{i}" for i in range(1, 7)], "FlankR": [f"T_FlankR_0{i}" for i in range(1, 7)],
          "VentA": [f"T_VentA_0{i}" for i in range(1, 7)], "VentB": [f"T_VentB_0{i}" for i in range(1, 6)]}
for g, names in GROUPS.items():
    pts = [H[n] for n in names]
    ext = pts[-1] + (pts[-1] - pts[-2]) * 1.3
    pts = pts + [ext]
    # root a little inside the body so it grows out of the flesh
    root = pts[0] + (pts[0] - pts[1]).normalized() * 1.0
    pts = [root] + pts
    n = len(pts)
    base_r = {"DorsalL": .85, "DorsalR": .8, "FlankL": .7, "FlankR": .7, "VentA": .6, "VentB": .5}[g]
    tube(tent, pts, taper(n, base_r, .09, .9), 8)
    for k in range(3):                                                           # barbs at the tip
        a = 2 * math.pi * k / 3
        d = (pts[-1] - pts[-2]).normalized()
        side = d.cross(Vector((0, 0, 1))).normalized()
        cone(tent, pts[-2] + side * .12 * math.cos(a), pts[-1] + side * .5 * math.cos(a) + d * .6 + Vector((0, 0, .5 * math.sin(a))), .1, 4)
# thin extra whips sprouting from the shoulders (asymmetry: more on the left)
for i, (c, d) in enumerate((((-1.4, -3.5, 12.4), (-.6, -.6, 1)), ((-2.0, -2.0, 12.0), (-1, .2, .9)), ((1.2, -3.0, 12.6), (.5, -.8, 1)))):
    p0 = V(*c)
    pts = bez(p0, p0 + V(*d) * 2.5 + V(0, 0, 1.5), p0 + V(*d) * 5.2 + V(0, -1.0, 2.2 - i), 9)
    tube(tent, pts, taper(9, .32, .05), 6)

# ---------------------------------------------------------------------------------------------------------------- objects, remesh
def to_obj(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


omass, obone, otent, ohide = to_obj(mass, "mass"), to_obj(bone, "bone"), to_obj(tent, "tent"), to_obj(hide_d, "hided")
bpy.context.view_layer.objects.active = omass
omass.select_set(True)
mod = omass.modifiers.new("remesh", 'REMESH')
mod.mode = 'VOXEL'
mod.voxel_size = 0.34
mod.use_smooth_shade = False
bpy.ops.object.modifier_apply(modifier="remesh")
print("MASS after remesh tris", sum(len(p.vertices) - 2 for p in omass.data.polygons))
dm = omass.modifiers.new("dec", 'DECIMATE')
dm.ratio = min(1.0, 5200.0 / max(1, sum(len(p.vertices) - 2 for p in omass.data.polygons)))
bpy.ops.object.modifier_apply(modifier="dec")
print("MASS after decimate tris", sum(len(p.vertices) - 2 for p in omass.data.polygons))

# ---------------------------------------------------------------------------------------------------------------- textures
def px_to_image(name, arr, packed=True):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    flat = np.ones((h, w, 4), dtype=np.float32)
    flat[..., :3] = arr
    img.pixels[:] = flat[::-1].reshape(-1)         # image rows run bottom-up
    img.pack()
    return img


def hexs(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)], dtype=np.float32)


def voronoi_tex(n, ramp, cells, seed, border_dark=.55, speck=.12):
    r = np.random.default_rng(seed)
    pts = r.random((cells, 2)) * n
    ys, xs = np.mgrid[0:n, 0:n]
    best = np.full((n, n), 1e9)
    second = np.full((n, n), 1e9)
    idx = np.zeros((n, n), dtype=int)
    for k, p in enumerate(pts):
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d = (xs - (p[0] + ox)) ** 2 + (ys - (p[1] + oy)) ** 2
                m = d < best
                second = np.where(m, best, np.where(d < second, d, second))
                idx = np.where(m, k, idx)
                best = np.where(m, d, best)
    tone = r.random(cells)[idx]
    img = np.zeros((n, n, 3), dtype=np.float32)
    edge = (np.sqrt(second) - np.sqrt(best))
    for y in range(n):
        for x in range(n):
            t = tone[y, x] * .7 + .15 + (r.random() - .5) * speck
            if edge[y, x] < 1.6:
                t *= border_dark
            img[y, x] = ramp[min(len(ramp) - 1, max(0, int(t * len(ramp))))]
    return img, edge


hide_ramp = [hexs(c) for c in ("#15181d", "#1d2128", "#2a2d36", "#383945", "#4a4658")]
hide_img, hide_edge = voronoi_tex(128, hide_ramp, 46, 3, .45)
# purple bruising bands
for y in range(128):
    for x in range(128):
        if (math.sin(x * .11 + y * .05) + math.sin(y * .17 - x * .04)) > 1.45:
            hide_img[y, x] = hide_img[y, x] * .7 + hexs("#4b2f5c") * .3
emis = np.zeros((128, 128, 3), dtype=np.float32)
for y in range(128):
    for x in range(128):
        if hide_edge[y, x] < 1.1 and ((x * 7 + y * 13) % 11) < 1:
            emis[y, x] = hexs("#2aa9a4") * .7
bone_ramp = [hexs(c) for c in ("#3b342b", "#5a5043", "#7e7260", "#a29780", "#c4b89c")]
bone_img, _ = voronoi_tex(128, bone_ramp, 14, 5, .6, .06)
for y in range(128):                              # growth rings and chips
    for x in range(128):
        v = math.sin((y * .9 + math.sin(x * .08) * 5)) * .5 + .5
        if v > .86:
            bone_img[y, x] *= .72
tent_img = np.zeros((128, 128, 3), dtype=np.float32)
tent_ramp = [hexs(c) for c in ("#0d0c13", "#161423", "#241d37", "#35294d", "#4a3a66")]
rr = np.random.default_rng(8)
for y in range(128):
    band = (y // 16) % 2
    for x in range(128):
        t = .35 + .25 * band + (rr.random() - .5) * .25
        if y % 16 in (0, 1):
            t = .08
        tent_img[y, x] = tent_ramp[min(4, int(t * 5))]
for _ in range(60):                               # pale sucker dots
    cx, cy = rr.integers(0, 128), rr.integers(0, 128)
    tent_img[cy % 128, cx % 128] = hexs("#8d7f9e")
    tent_img[(cy + 1) % 128, cx % 128] = hexs("#5e5272")

img_h, img_b, img_t = px_to_image("T_Colossus_Hide", hide_img), px_to_image("T_Colossus_Plate", bone_img), px_to_image("T_Colossus_Tentacle", tent_img)
img_e = px_to_image("T_Colossus_Hide_E", emis)


def make_mat(name, img, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    t.interpolation = 'Closest'
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 1.0
    if emit is not None:
        te = nt.nodes.new("ShaderNodeTexImage")
        te.image = emit
        te.interpolation = 'Closest'
        nt.links.new(te.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = .5
    return m


mat_plate = make_mat("M_Crt_Colossus", img_b)
mat_hide = make_mat("M_Crt_Colossus_Hide", img_h, img_e)
mat_tent = make_mat("M_Crt_Tentacle", img_t)

# ---------------------------------------------------------------------------------------------------------------- join, UV, materials
bpy.ops.object.select_all(action='DESELECT')
for o in (omass, obone, otent, ohide):
    o.select_set(True)
    o.data.materials.clear()
omass.data.materials.append(mat_plate)
omass.data.materials.append(mat_hide)
omass.data.materials.append(mat_tent)
for o, mi in ((omass, 1), (obone, 0), (otent, 2), (ohide, 1)):
    for p in o.data.polygons:
        p.material_index = mi
for o in (obone, otent, ohide):
    o.data.materials.append(mat_plate)
    o.data.materials.append(mat_hide)
    o.data.materials.append(mat_tent)
bpy.context.view_layer.objects.active = omass
bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
mesh.name = "CRT_Colossus_Mesh"
mesh.data.name = "CRT_Colossus_Mesh"
me = mesh.data
for p in me.polygons:
    p.use_smooth = False
# box-projected UVs, ~3 m per tile (tentacles 2 m): faces keep their own island
uv = me.uv_layers.new(name="UVMap")
scale = {0: 1 / 3.2, 1: 1 / 3.4, 2: 1 / 2.2}
for p in me.polygons:
    n = p.normal
    ax = max(range(3), key=lambda i: abs(n[i]))
    s = scale[p.material_index]
    for li in p.loop_indices:
        co = me.vertices[me.loops[li].vertex_index].co
        if ax == 0:
            u, v = co.y, co.z
        elif ax == 1:
            u, v = co.x, co.z
        else:
            u, v = co.x, co.y
        uv.data[li].uv = (u * s, v * s)

# ---------------------------------------------------------------------------------------------------------------- weights (nearest bone segments)
SEGS = {}
def seg(name, a, b):
    SEGS.setdefault(name, []).append((np.array(a, dtype=float), np.array(b, dtype=float)))


seg("Body", (0, .2, 9.4), (0, 3.0, 9.8)); seg("Body", (0, -.8, 10.0), (0, .6, 9.6))
seg("Rear", (0, 3.4, 9.8), (0, 6.8, 9.2))
seg("Chest", (0, -2.8, 10.1), (0, -1.0, 10.1)); seg("Chest", (0, -2.8, 10.1), (0, -4.6, 10.2))
seg("Belly", (0, -1.0, 8.2), (0, 2.2, 8.0))
seg("Head", tuple(H["Head"]), (0, -8.4, 8.3)); seg("Head", (0, -6.0, 9.0), (0, -7.4, 8.4))
seg("Maw_L", tuple(H["Maw_L"]), (-.6, -11.0, 5.9)); seg("Maw_R", tuple(H["Maw_R"]), (.6, -11.0, 5.9))
for s in ("L", "R"):
    seg(f"Stalk_{s}_01", tuple(H[f"Stalk_{s}_01"]), tuple(H[f"Stalk_{s}_02"]))
    seg(f"Stalk_{s}_02", tuple(H[f"Stalk_{s}_02"]), tuple(H[f"Stalk_{s}_02"] + (H[f"Stalk_{s}_02"] - H[f"Stalk_{s}_01"]) * .9))
for leg in LEG:
    seg(f"Leg_{leg}_Upper", tuple(H[f"Leg_{leg}_Upper"] + V(-LEG[leg][1][0] * 1.4, 0, 0)), tuple(H[f"Leg_{leg}_Lower"]))
    seg(f"Leg_{leg}_Lower", tuple(H[f"Leg_{leg}_Lower"]), tuple(H[f"Leg_{leg}_Foot"]))
    seg(f"Leg_{leg}_Foot", tuple(H[f"Leg_{leg}_Foot"]), tuple(TIPS[leg]))
for g, names in GROUPS.items():
    for i, n in enumerate(names):
        a = H[n]
        b = H[names[i + 1]] if i + 1 < len(names) else a + (a - H[names[i - 1]]) * 2.0
        seg(n, tuple(a), tuple(b))
        if i == 0:
            seg(n, tuple(a + (a - b).normalized() * 1.0), tuple(a))


def d2seg(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    c = a + t[:, None] * ab
    return np.linalg.norm(P - c, axis=1)


P = np.array([v.co[:] for v in me.vertices])
names = list(SEGS)
D = np.stack([np.min([d2seg(P, a, b) for a, b in SEGS[n]], axis=0) for n in names], axis=1)      # verts x bones
W = np.zeros_like(D)
order = np.argsort(D, axis=1)[:, :3]
for i in range(len(P)):
    ds = D[i, order[i]]
    w = 1.0 / (ds ** 3 + 1e-3)
    # tentacle / claw / bone parts belong to their own chain: sharpen hard
    W[i, order[i]] = w / w.sum()
W[W < .04] = 0
W /= W.sum(axis=1, keepdims=True)
for n in names:
    mesh.vertex_groups.new(name=n)
for j, n in enumerate(names):
    vg = mesh.vertex_groups[n]
    for i in np.nonzero(W[:, j] > 0)[0]:
        vg.add([int(i)], float(W[i, j]), 'REPLACE')
mesh.parent = arm
mod = mesh.modifiers.new("Armature", 'ARMATURE')
mod.object = arm
print("FINAL tris", sum(len(p.vertices) - 2 for p in me.polygons), "verts", len(me.vertices), "bbox z", P[:, 2].min(), P[:, 2].max(), "y", P[:, 1].min(), P[:, 1].max(), "x", P[:, 0].min(), P[:, 0].max())
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT_GLB), export_format='GLB', export_animations=False, export_skins=True, export_yup=True, export_apply=False)
print("DONE new colossus")
