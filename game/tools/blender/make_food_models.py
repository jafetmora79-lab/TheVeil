"""THE VEIL - the supermarket's products as proper little models (cans with rims, PET bottles with caps, crimped bags, boxes, wrapped bars), one GLB per product variant, each exactly the
size of the pack's own product of that name and with its origin at the base centre, so they replace the shelf products and also serve as the models of what the player picks up.
   python game/tools/blender/make_food_textures.py
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python game/tools/blender/make_food_models.py
Output: game/prototypes/food/FOOD_<variant>.glb   (front = +Z in Godot; flat bars lie on their back with the label up)."""
import sys, os, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
import make_story_props as P

ROOT = P.ROOT
FOOD = os.path.join(ROOT, "game", "prototypes", "food")
P.OUT = FOOD                                   # (the shared exporter writes here)
DIMS = json.load(open(os.path.join(FOOD, "dims.json")))
TEX = os.path.join(FOOD, "tex")

COL = {"metal": (0.72, 0.74, 0.78, 1), "dark": (0.06, 0.06, 0.07, 1)}


def label_mat(v):
    return P.mat("L_" + v, os.path.join(TEX, v + ".png"), (1, 1, 1, 1), 0.75)


def solid(name, col, rough=0.7, metal=0.0):
    return P.mat("S_" + name, None, col, rough, metal)


def new_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def ring_surface(bm, rings, seg, mat_of_band, uv_of, closed_bottom=True, closed_top=True):
    """rings: [(z, radius)] from bottom to top; faces between rings get material index mat_of_band(i); uv_of(ring_i, u) -> (u, v)."""
    uvl = bm.loops.layers.uv.verify()
    vs = []
    for (z, r) in rings:
        vs.append([bm.verts.new((math.cos(a * math.tau / seg) * r, math.sin(a * math.tau / seg) * r, z)) for a in range(seg)])
    for i in range(len(rings) - 1):
        for a in range(seg):
            b = (a + 1) % seg
            f = bm.faces.new((vs[i][a], vs[i][b], vs[i + 1][b], vs[i + 1][a]))
            f.material_index = mat_of_band(i)
            for l, (vi, ai) in zip(f.loops, ((i, a), (i, a + 1), (i + 1, a + 1), (i + 1, a))):
                l[uvl].uv = uv_of(vi, ai / seg)
    if closed_bottom:
        c = bm.verts.new((0, 0, rings[0][0]))
        for a in range(seg):
            f = bm.faces.new((c, vs[0][(a + 1) % seg], vs[0][a]))
            f.material_index = mat_of_band(0) if False else 0
            for l in f.loops:
                l[uvl].uv = (0.5, 0.5)
    if closed_top:
        c = bm.verts.new((0, 0, rings[-1][0]))
        for a in range(seg):
            f = bm.faces.new((c, vs[-1][a], vs[-1][(a + 1) % seg]))
            f.material_index = 0
            for l in f.loops:
                l[uvl].uv = (0.5, 0.5)


def rotate_to_godot(ob):
    """The parts are built with Z up and the front at -Y (the exporter's convention): nothing to do; kept for clarity."""
    return ob


def finish(variant, objs):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    P.export("FOOD_%s.glb" % variant)


# ------------------------------------------------------------------ can: a cylinder with a wrapped label, rolled rims
def can(variant, w, h, d):
    P.reset()
    r = w / 2
    bm = bmesh.new()
    rings = [(0.0, r * 0.93), (0.008, r), (0.012, r), (h - 0.012, r), (h - 0.008, r), (h, r * 0.93)]
    metal, lab = solid("can_metal", COL["metal"], 0.4, 0.7), label_mat(variant)
    # material 0 = metal (rims and ends), 1 = label (the wrapped band between the rims)
    ring_surface(bm, rings, 14, lambda i: 1 if i == 2 else 0, lambda i, u: ((u - 0.75) * 2.4 + 0.5, (rings[i][0] - 0.012) / (h - 0.024)))    # (the label's middle faces the front: -Y)
    # a pull tab on top
    tab = bmesh.ops.create_cube(bm, size=1.0)
    for v in tab["verts"]:
        v.co = Vector((v.co.x * r * 0.7, v.co.y * r * 0.28, v.co.z * 0.004 + h + 0.002)) + Vector((0.0, 0.0, 0))
    for f in bm.faces:
        pass
    ob = new_obj("can", bm, [metal, lab])
    finish(variant, [ob])


# ------------------------------------------------------------------ PET bottle: a body with a label band, a shoulder, a neck and a cap
def bottle(variant, w, h, d):
    P.reset()
    r = w / 2
    body_col = {"bottle_water": (0.75, 0.88, 0.97, 1), "bottle_sport": (0.35, 0.85, 0.5, 1), "bottle_cola": (0.12, 0.06, 0.04, 1), "bottle_orange": (0.95, 0.55, 0.12, 1),
                "bottle_lime": (0.55, 0.85, 0.2, 1), "bottle_tea": (0.55, 0.32, 0.1, 1), "bottle_volt": (0.9, 0.8, 0.15, 1), "bottle_berry": (0.45, 0.15, 0.55, 1)}[variant]
    cap_col = {"bottle_water": (0.2, 0.45, 0.85, 1), "bottle_cola": (0.75, 0.1, 0.12, 1)}.get(variant, (0.15, 0.15, 0.17, 1))
    liquid, lab, cap = solid("pet_" + variant, body_col, 0.25), label_mat(variant), solid("cap_" + variant, cap_col, 0.5)
    prof = [(0.0, r * 0.82), (0.012 * h, r * 0.96), (0.04 * h, r), (0.18 * h, r), (0.56 * h, r), (0.58 * h, r * 0.99), (0.64 * h, r * 0.9), (0.74 * h, r * 0.5), (0.80 * h, r * 0.3),
            (0.90 * h, r * 0.3), (0.905 * h, r * 0.42), (0.995 * h, r * 0.42), (h, r * 0.34)]
    bm = bmesh.new()
    # materials: 0 liquid body, 1 label band (rings 3-4 = z 0.18h..0.56h), 2 cap (top rings)
    def band(i):
        if i in (3, 4):
            return 1
        if i >= 9:
            return 2
        return 0
    ring_surface(bm, prof, 12, band, lambda i, u: ((u - 0.75) * 2.0 + 0.5, min(1.0, max(0.0, (prof[i][0] - 0.18 * h) / (0.38 * h)))), True, True)
    ob = new_obj("bottle", bm, [liquid, lab, cap])
    # the label band is a real band: push its two rings out a hair so it stands off the plastic
    for v in ob.data.vertices:
        z = v.co.z
        if 0.18 * h - 1e-6 <= z <= 0.56 * h + 1e-6 and math.hypot(v.co.x, v.co.y) > r * 0.99:
            v.co.x *= 1.02
            v.co.y *= 1.02
    finish(variant, [ob])


# ------------------------------------------------------------------ bag: a pillow with crimped fins top and bottom, the label on the front
def bag(variant, w, h, d):
    P.reset()
    nx, ny = 8, 12
    lab, body = label_mat(variant), solid("bag_back_" + variant, tuple(min(1, c * 0.8) for c in (0.8, 0.8, 0.8)) + (1,), 0.5, 0.2)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()

    def thick(ix, iy):
        x = ix / nx * 2 - 1
        y = iy / ny
        fin = 1.0
        if y < 0.07 or y > 0.93:
            fin = 0.12 + (0.04 if (ix % 2 == 0) else 0.0)                 # the crimped, almost flat ends
        else:
            fin = 0.35 + 0.65 * math.sin(math.pi * min(1.0, (y - 0.07) / 0.86)) ** 0.7
        edge = max(0.0, 1.0 - x * x) ** 0.5
        return max(0.004, d / 2 * fin * edge)
    front = [[bm.verts.new(((ix / nx - 0.5) * w, thick(ix, iy), iy / ny * h)) for ix in range(nx + 1)] for iy in range(ny + 1)]
    back = [[bm.verts.new(((ix / nx - 0.5) * w, -thick(ix, iy), iy / ny * h)) for ix in range(nx + 1)] for iy in range(ny + 1)]
    # the bag's front is toward -Y in Blender (Godot +Z): mirror the grids so the label faces -Y
    for iy in range(ny):
        for ix in range(nx):
            f = bm.faces.new((front[iy][ix + 1], front[iy][ix], front[iy + 1][ix], front[iy + 1][ix + 1]))
            f.material_index = 1
            for l, (a, b) in zip(f.loops, ((ix + 1, iy), (ix, iy), (ix, iy + 1), (ix + 1, iy + 1))):
                l[uvl].uv = (a / nx, b / ny)
            g = bm.faces.new((back[iy][ix], back[iy][ix + 1], back[iy + 1][ix + 1], back[iy + 1][ix]))
            g.material_index = 0
            for l in g.loops:
                l[uvl].uv = (0.5, 0.5)
    # seams: the border of the front joins the border of the back
    for iy in range(ny):
        for (a, b) in ((front[iy][0], back[iy][0]), (front[iy][nx], back[iy][nx])):
            pass
    for ix in range(nx):
        for (row) in (0, ny):
            f = bm.faces.new((front[row][ix], front[row][ix + 1], back[row][ix + 1], back[row][ix])) if row == ny else bm.faces.new((front[row][ix + 1], front[row][ix], back[row][ix], back[row][ix + 1]))
            f.material_index = 0
    for iy in range(ny):
        f = bm.faces.new((front[iy][0], front[iy + 1][0], back[iy + 1][0], back[iy][0]))
        f.material_index = 0
        f = bm.faces.new((front[iy + 1][nx], front[iy][nx], back[iy][nx], back[iy + 1][nx]))
        f.material_index = 0
    ob = new_obj("bag", bm, [body, lab])
    # front is -Y: flip so the label faces the +Z of Godot (-Y of Blender) -> the front grid is at +Y here: swap
    for v in ob.data.vertices:
        v.co.y = -v.co.y
    ob.data.flip_normals()
    finish(variant, [ob])


# ------------------------------------------------------------------ box: cardboard, the label on the front, a printed top and sides
def box(variant, w, h, d):
    P.reset()
    lab = label_mat(variant)
    side = P.mat("S_box_" + variant, os.path.join(TEX, variant + ".png"), (0.62, 0.62, 0.62, 1), 0.85)
    flap = solid("box_flap", (0.12, 0.11, 0.1, 1), 0.9)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    uvl = bm.loops.layers.uv.verify()
    for v in bm.verts:
        v.co = Vector((v.co.x * w, v.co.y * d, v.co.z * h + h / 2))
    for f in bm.faces:
        n = f.normal
        f.material_index = 1 if n.y < -0.5 else 0
        for l in f.loops:
            p = l.vert.co
            if n.y < -0.5:
                l[uvl].uv = (p.x / w + 0.5, p.z / h)
            elif abs(n.y) > 0.5:
                l[uvl].uv = (1.0 - (p.x / w + 0.5), p.z / h)
            elif abs(n.x) > 0.5:
                l[uvl].uv = (p.y / d + 0.5, p.z / h)
            else:
                l[uvl].uv = (p.x / w + 0.5, p.y / d + 0.5)
    ob = new_obj("box", bm, [side, lab])
    # the opening flap line and a tear strip across the top front
    bm2 = bmesh.new()
    bmesh.ops.create_cube(bm2, size=1.0)
    for v in bm2.verts:
        v.co = Vector((v.co.x * w * 1.002, v.co.y * d * 1.002, v.co.z * 0.003 + h * 0.94))
    ob2 = new_obj("flap", bm2, [flap])
    finish(variant, [ob, ob2])


# ------------------------------------------------------------------ flat bars: a wrapped bar lying on its back (label up, crimped fins at both ends) / a foil-wrapped chocolate slab
def flat(variant, w, h, d):
    P.reset()
    lab = label_mat(variant)
    foil = solid("foil_" + variant, (0.78, 0.78, 0.8, 1), 0.3, 0.8)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    is_choc = variant.startswith("choc")
    body_w = w * (0.86 if not is_choc else 1.0)
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * body_w, v.co.y * d, v.co.z * h + h / 2))
        if not is_choc:                                      # a rounded, pillowy wrapper: the top is crowned
            v.co.z += (0.012 if v.co.z > h / 2 else 0.0) * (1 - (2 * v.co.y / d) ** 2) * 0.6
    for f in bm.faces:
        n = f.normal
        f.material_index = 1 if n.z > 0.5 else 0
        for l in f.loops:
            p = l.vert.co
            l[uvl].uv = (p.x / body_w + 0.5, p.y / d + 0.5)
    parts = [new_obj("body", bm, [foil, lab])]
    if not is_choc:
        for sx in (-1, 1):                                   # the crimped fins at the ends
            b2 = bmesh.new()
            bmesh.ops.create_cube(b2, size=1.0)
            for v in b2.verts:
                v.co = Vector((v.co.x * (w - body_w) * 0.5 + sx * (body_w / 2 + (w - body_w) / 4), v.co.y * d * 0.9, v.co.z * h * 0.35 + h * 0.5))
            parts.append(new_obj("fin", b2, [foil]))
    finish(variant, parts)


def main():
    for v, dims in DIMS.items():
        w, h, d = dims
        if v.startswith("can_"):
            can(v, w, h, d)
        elif v.startswith("bottle_"):
            bottle(v, w, h, d)
        elif v.startswith("bag_"):
            bag(v, w, h, d)
        elif v.startswith("box_"):
            box(v, w, h, d)
        elif v.startswith("candy_bar") or v.startswith("choc_"):
            flat(v, w, h, d)


main()
