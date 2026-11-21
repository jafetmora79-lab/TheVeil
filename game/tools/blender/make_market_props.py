"""THE VEIL - the supermarket's fixtures rebuilt in Blender (review notes #14, #15, #18): the wall fridges (doors, shelves, stocked with real bottles / cans / cartons), the chest
freezers (rim, sliding glass lids, frozen goods inside), the produce wall (stepped wooden trays of fruit and vegetables) and the produce islands.
   python game/tools/blender/make_market_signs.py
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python game/tools/blender/make_market_props.py
Output: game/prototypes/market_props/MKT_*.glb.  Blender frame as make_story_props: X along the fixture, the FRONT faces -Y (Godot +Z), Z up; origin = floor level,
centred along X, at the BACK (y = 0) for wall fixtures / the centre for the island and the freezer."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix
import make_story_props as P

OUTDIR = os.path.join(P.ROOT, "game", "prototypes", "market_props")
TEXD = os.path.join(OUTDIR, "tex")
P.OUT = OUTDIR
os.makedirs(OUTDIR, exist_ok=True)

SOLID = {}


def solid(name, col, rough=0.7, metal=0.0, emit=None):
    if name not in SOLID:
        SOLID[name] = P.mat("S_" + name, None, tuple(col) + (1,), rough, metal, emit)
    return SOLID[name]


def tex(name, tint=(1, 1, 1, 1), rough=0.8, metal=0.0):
    return P.mat("T_" + name, name, tint, rough, metal)


def glass():
    m = solid("Glass", (0.6, 0.8, 0.85), 0.1)
    return m


class Acc:
    """Collects geometry per material and builds one object."""
    def __init__(self):
        self.bm = {}

    def _b(self, m):
        if m.name not in self.bm:
            self.bm[m.name] = (m, bmesh.new())
        return self.bm[m.name][1]

    def _uv(self, bm, scale=1.0, front=None):
        uv = bm.loops.layers.uv.verify()
        for f in bm.faces:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                p = l.vert.co
                if front is not None and ax == 1 and n.y < 0:
                    cx, cz, w, h = front
                    l[uv].uv = ((p.x - (cx - w / 2)) / w, (p.z - (cz - h / 2)) / h)
                elif ax == 0:
                    l[uv].uv = (p.y / scale, p.z / scale)
                elif ax == 1:
                    l[uv].uv = (p.x / scale, p.z / scale)
                else:
                    l[uv].uv = (p.x / scale, p.y / scale)

    def box(self, c, s, m, scale=1.0, front=None, rz=0.0, rx=0.0, cover=None):
        bm = self._b(m)
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
        cov_uv = None
        if cover is not None:                       # a game cover: the +Z face carries the picture (u along x, v along y; cover="flip" turns v), the rest is plain
            uvl = tmp.loops.layers.uv.verify()
            for f in tmp.faces:
                for l in f.loops:
                    p_ = l.vert.co
                    if f.normal.z > 0.5:
                        l[uvl].uv = ((p_.x / s[0] + 0.5, p_.y / s[1] + 0.5) if cover != "flip" else (0.5 - p_.x / s[0], 0.5 - p_.y / s[1]))
                    else:
                        l[uvl].uv = (0.0, 0.0)
            cov_uv = True
        if rz:
            bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(rz, 3, "Z"))
        if rx:
            bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(rx, 3, "X"))
        for v in tmp.verts:
            v.co += Vector(c)
        tmp.normal_update()
        if cov_uv is None:
            self._uv(tmp, scale, front)
        me = bpy.data.meshes.new("t")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def cyl(self, c, r, h, m, seg=6, r2=None, axis="Z"):
        bm = self._b(m)
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
        if axis == "X":
            bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
        elif axis == "Y":
            bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
        for v in tmp.verts:
            v.co += Vector(c)
        tmp.normal_update()
        self._uv(tmp, 0.5)
        me = bpy.data.meshes.new("t")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def ball(self, c, r, m, seg=6, rings=4, sc=(1, 1, 1)):
        bm = self._b(m)
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg, v_segments=rings, radius=r)
        for v in tmp.verts:
            v.co = Vector((v.co.x * sc[0], v.co.y * sc[1], v.co.z * sc[2])) + Vector(c)
        tmp.normal_update()
        self._uv(tmp, 0.5)
        me = bpy.data.meshes.new("t")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def build(self, name):
        me = bpy.data.meshes.new(name)
        full = bmesh.new()
        mats = []
        for key, (m, b) in self.bm.items():
            idx = len(mats)
            mats.append(m)
            tmp = bpy.data.meshes.new("x")
            b.to_mesh(tmp)
            b.free()
            full_start = len(full.faces)
            full.from_mesh(tmp)
            for f in list(full.faces)[full_start:]:
                f.material_index = idx
            bpy.data.meshes.remove(tmp)
        uvl = full.loops.layers.uv.verify()
        full.normal_update()
        full.to_mesh(me)
        full.free()
        for m in mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# ------------------------------------------------------------------ palettes
def pal():
    return {"red": solid("red", (0.75, 0.12, 0.1), 0.5), "blue": solid("blue", (0.15, 0.32, 0.72), 0.5), "green": solid("green", (0.2, 0.6, 0.25), 0.5),
            "yellow": solid("yellow", (0.95, 0.8, 0.15), 0.5), "orange": solid("orange", (0.95, 0.5, 0.1), 0.5), "brown": solid("brown", (0.28, 0.15, 0.08), 0.6),
            "white": solid("white", (0.93, 0.93, 0.9), 0.6), "purple": solid("purple", (0.45, 0.15, 0.5), 0.5), "pink": solid("pink", (0.9, 0.45, 0.6), 0.5),
            "pet": solid("pet", (0.72, 0.86, 0.95), 0.25), "black": solid("black", (0.05, 0.05, 0.06), 0.6), "silver": solid("silver", (0.75, 0.76, 0.8), 0.35, 0.8),
            "lgreen": solid("lgreen", (0.55, 0.8, 0.3), 0.6), "tan": solid("tan", (0.75, 0.6, 0.4), 0.8), "cream": solid("cream", (0.9, 0.86, 0.75), 0.7)}


COLS = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "white", "brown"]


def bottle(a, c, h, r, body, label, cap, seg=6):
    x, y, z = c
    a.cyl((x, y, z + h * 0.31), r, h * 0.62, body, seg)
    a.cyl((x, y, z + h * 0.71), r, h * 0.18, body, seg, r2=r * 0.36)                 # shoulder
    a.cyl((x, y, z + h * 0.86), r * 0.36, h * 0.12, body, seg)                       # neck
    a.cyl((x, y, z + h * 0.96), r * 0.42, h * 0.08, cap, seg)
    a.cyl((x, y, z + h * 0.34), r * 1.05, h * 0.34, label, seg)


def can(a, c, h, r, label, seg=6):
    x, y, z = c
    pal_ = pal()
    a.cyl((x, y, z + h / 2), r, h, label, seg)
    a.cyl((x, y, z + h + 0.002), r * 0.92, 0.006, pal_["silver"], seg)


def carton(a, c, w, d, h, col, topcol):
    x, y, z = c
    a.box((x, y, z + h / 2), (w, d, h), col)
    a.box((x, y, z + h + 0.025), (w * 0.9, d * 0.5, 0.05), topcol)


def metal():
    return tex("Furniture/T_Furn_MetalBrushed.png", (0.86, 0.88, 0.9, 1), 0.5, 0.5)


def wood(col=(0.8, 0.7, 0.55, 1)):
    return tex("Furniture/T_Furn_WoodLight.png", col, 0.9)


# ------------------------------------------------------------------ wall fridge: a three-door glass-fronted drinks / dairy unit, stocked
def wall_fridge(fname, W=2.4, D=0.85, H=2.14, sign="drinks", seed=1):
    P.reset()
    random.seed(seed)
    A = Acc()
    p = pal()
    shell = metal()
    dark = solid("dark", (0.07, 0.08, 0.09), 0.6)
    white = solid("shelfwhite", (0.93, 0.94, 0.92), 0.5)
    frame = solid("frame", (0.72, 0.74, 0.78), 0.35, 0.8)
    light = solid("lamp", (1, 1, 0.92), 0.5, 0.0, (1.0, 0.98, 0.9, 1))
    sg = tex("../../market_props/tex/sign_%s.png" % sign, (1, 1, 1, 1), 0.6) if False else P.mat("Sign_" + sign, os.path.join(TEXD, "sign_%s.png" % sign), (1, 1, 1, 1), 0.6)
    A.box((0, -D / 2, 0.07), (W, D, 0.14), dark)                                            # kick plate
    for sx in (-1, 1):
        A.box((sx * (W / 2 - 0.015), -D / 2, (0.14 + H - 0.28) / 2), (0.03, D, H - 0.42), shell)        # side panels
    A.box((0, -0.015, (0.14 + H - 0.28) / 2), (W - 0.06, 0.03, H - 0.42), white)            # back panel
    A.box((0, -D / 2, 0.145), (W - 0.06, D - 0.04, 0.01), white)                             # floor of the cabinet
    A.box((0, -D / 2, H - 0.14), (W, D, 0.28), shell)                                       # header
    A.box((0, -D - 0.006, H - 0.14), (W - 0.12, 0.012, 0.2), sg, front=(0, H - 0.14, W - 0.12, 0.2))
    A.box((0, -D / 2 - 0.05, H - 0.285), (W - 0.2, D - 0.3, 0.012), light)                  # the lamp under the header
    shelf_z = [0.30, 0.70, 1.10, 1.48]
    for z in shelf_z:
        A.box((0, -(D - 0.1) / 2 - 0.03, z), (W - 0.06, D - 0.1, 0.018), white)
        A.box((0, -(D - 0.08), z + 0.025), (W - 0.06, 0.016, 0.05), frame)                # price rail
    # stock: each shelf carries one kind of drink, in a front row and a row behind it
    kinds = ["pet_big", "cola", "can", "carton"] if sign == "drinks" else ["carton", "carton", "can", "pet_big"]
    random.shuffle(COLS)
    for si, z in enumerate(shelf_z):
        kind = kinds[si % 4]
        for row, yy in enumerate((-(D - 0.2), -(D - 0.38))):
            step = {"pet_big": 0.115, "cola": 0.095, "can": 0.075, "carton": 0.105}[kind]
            x = -W / 2 + 0.1
            ci = random.randrange(len(COLS))
            while x < W / 2 - 0.08:
                col = p[COLS[ci % len(COLS)]]
                if random.random() < 0.18:
                    ci += 1
                if kind == "pet_big":
                    bottle(A, (x, yy, z + 0.01), 0.30, 0.036, p["pet"], col, p[random.choice(["blue", "red", "black"])])
                elif kind == "cola":
                    bottle(A, (x, yy, z + 0.01), 0.24, 0.032, p["brown"] if random.random() < 0.5 else p["pet"], col, p["red"])
                elif kind == "can":
                    can(A, (x, yy, z + 0.01), 0.115, 0.032, col)
                else:
                    carton(A, (x, yy, z + 0.01), 0.08, 0.08, 0.22, col, p["white"])
                x += step
    # the three glass doors, closed: frame, glass, a long handle
    dw = W / 3
    zt, zb = H - 0.28, 0.14
    for i in range(4):
        A.box((-W / 2 + i * dw, -D - 0.01, (zt + zb) / 2), (0.04, 0.03, zt - zb), frame)
    for zz in (zb + 0.01, zt - 0.01):
        A.box((0, -D - 0.01, zz), (W, 0.03, 0.04), frame)
    for i in range(3):
        cx = -W / 2 + (i + 0.5) * dw
        A.box((cx, -D - 0.012, (zt + zb) / 2), (dw - 0.05, 0.008, zt - zb - 0.04), glass())
        A.box((cx + dw / 2 - 0.07, -D - 0.045, 1.0), (0.022, 0.03, 0.55), frame)
    return A.build("WallFridge")


# ------------------------------------------------------------------ produce
FRUIT = None


def produce_item(a, p, c, kind):
    x, y, z = c
    if kind == "apple":
        a.ball((x, y, z + 0.04), 0.042, p["red"], 5, 4)
    elif kind == "orange":
        a.ball((x, y, z + 0.045), 0.046, p["orange"], 5, 4)
    elif kind == "lemon":
        a.ball((x, y, z + 0.035), 0.036, p["yellow"], 5, 4, (1.3, 0.9, 0.9))
    elif kind == "lime":
        a.ball((x, y, z + 0.035), 0.036, p["lgreen"], 5, 4)
    elif kind == "tomato":
        a.ball((x, y, z + 0.04), 0.046, p["red"], 5, 4, (1, 1, 0.85))
    elif kind == "potato":
        a.ball((x, y, z + 0.04), 0.045, p["tan"], 5, 4, (1.3, 0.9, 0.85))
    elif kind == "cabbage":
        a.ball((x, y, z + 0.09), 0.1, p["lgreen"], 6, 4)
    elif kind == "lettuce":
        a.ball((x, y, z + 0.07), 0.085, p["green"], 6, 3, (1, 1, 0.85))
    elif kind == "pepper":
        a.box((x, y, z + 0.045), (0.07, 0.07, 0.09), p[random.choice(["red", "yellow", "green"])])
    elif kind == "carrot":
        for k in range(3):
            a.cyl((x + (k - 1) * 0.03, y, z + 0.025), 0.016, 0.2, p["orange"], 4, r2=0.006, axis="Y")
    elif kind == "banana":
        for k in range(3):
            a.cyl((x + (k - 1) * 0.034, y, z + 0.03 + 0.01 * (k % 2)), 0.017, 0.2, p["yellow"], 4, axis="Y")
    elif kind == "corn":
        a.cyl((x, y, z + 0.04), 0.036, 0.21, p["yellow"], 5, axis="Y")
        a.cyl((x, y + 0.06, z + 0.04), 0.04, 0.1, p["green"], 5, axis="Y")
    elif kind == "grape":
        for k in range(6):
            a.ball((x + random.uniform(-0.04, 0.04), y + random.uniform(-0.04, 0.04), z + 0.03 + 0.02 * (k % 3)), 0.022, p["purple"], 4, 3)


def tray(a, p, x0, x1, y0, y1, z, kinds, step=0.11, slope=0.0):
    """A single layer of produce in the tray whose floor is at z, over x0..x1, y0..y1 (y runs front = more negative)."""
    nx = max(1, int((x1 - x0) / step))
    ny = max(1, int((y1 - y0) / step))
    k = random.choice(kinds)
    for i in range(nx):
        if random.random() < 0.3:
            k = random.choice(kinds)
        for j in range(ny):
            yy = y0 + (j + 0.5) * (y1 - y0) / ny + random.uniform(-0.01, 0.01)
            produce_item(a, p, (x0 + (i + 0.5) * (x1 - x0) / nx + random.uniform(-0.01, 0.01), yy, z + slope * (yy - y0)), k)


FRUITS = ["apple", "orange", "lemon", "tomato", "potato", "pepper", "lime"]
VEG = ["cabbage", "lettuce", "carrot", "corn", "potato", "tomato", "pepper"]


def crate(a, c, s, m, rim=0.05):
    """An open wooden tray: floor, four rim boards; c = centre of its floor-plan at z = top of the sides."""
    x, y, z = c
    sx, sy, sz = s
    a.box((x, y, z - sz / 2), (sx, sy, sz), m)


def produce_wall(fname, W=2.4, D=0.9, H=2.3, seed=2):
    P.reset()
    random.seed(seed)
    A = Acc()
    p = pal()
    wd = wood()
    dark = wood((0.55, 0.45, 0.35, 1))
    frame = solid("frame", (0.72, 0.74, 0.78), 0.35, 0.8)
    sg = P.mat("Sign_produce", os.path.join(TEXD, "sign_produce.png"), (1, 1, 1, 1), 0.6)
    A.box((0, -0.02, H / 2 - 0.2), (W, 0.04, H - 0.4), dark)                                   # backboard
    # three stepped, tilted trays (front low .. back high): each a wooden riser with a sloped bed so the produce faces the shopper
    tiers = [(D, 0.62, 0.40), (0.62, 0.34, 0.74), (0.34, 0.06, 1.08)]
    ang = math.radians(16)
    for ti, (y1, y0, top) in enumerate(tiers):
        A.box((0, -(y1 + y0) / 2, top / 2 - 0.05), (W - 0.04, y1 - y0, top - 0.10), wd)           # riser block
        A.box((0, -(y1 + y0) / 2, top - 0.005), ((W - 0.1), (y1 - y0) / math.cos(ang), 0.02), dark, rx=ang)   # the tilted bed
        A.box((0, -y1 + 0.015, top + 0.03), (W - 0.04, 0.03, 0.09), wd)                           # lip along the front
        for sx in (-1, 1):
            A.box((sx * (W / 2 - 0.025), -(y1 + y0) / 2, top + 0.035), (0.04, y1 - y0, 0.1), wd)
        tray(A, p, -W / 2 + 0.07, W / 2 - 0.07, -y1 + 0.05, -y0 - 0.01, top, FRUITS if ti != 2 else VEG, step=0.1, slope=math.tan(ang))
    A.box((0, -0.3, 1.95), (W, 0.05, 0.12), frame)                                              # the misting bar over the top tray
    A.box((0, -0.04, H - 0.18), (W, 0.1, 0.36), dark)
    A.box((0, -0.092, H - 0.18), (W - 0.1, 0.012, 0.28), sg, front=(0, H - 0.18, W - 0.1, 0.28))
    A.box((0, -D / 2, 0.01), (W, D, 0.02), dark)
    return A.build("ProduceWall")


def produce_island(fname, L=2.2, Wd=1.3, seed=3):
    P.reset()
    random.seed(seed)
    A = Acc()
    p = pal()
    wd = wood()
    dark = wood((0.55, 0.45, 0.35, 1))
    A.box((0, 0, 0.22), (L, Wd, 0.44), wd)                                                     # the base crate
    for sy in (-1, 1):
        A.box((0, sy * (Wd / 2 - 0.02), 0.5), (L, 0.04, 0.12), wd)
    for sx in (-1, 1):
        A.box((sx * (L / 2 - 0.02), 0, 0.5), (0.04, Wd, 0.12), wd)
    A.box((0, 0, 0.5), (L - 0.5, Wd - 0.5, 0.2), dark)                                         # the raised middle
    tray(A, p, -L / 2 + 0.06, -L / 2 + 0.25, -Wd / 2 + 0.06, Wd / 2 - 0.06, 0.44, VEG)
    tray(A, p, L / 2 - 0.25, L / 2 - 0.06, -Wd / 2 + 0.06, Wd / 2 - 0.06, 0.44, VEG)
    tray(A, p, -L / 2 + 0.25, L / 2 - 0.25, -Wd / 2 + 0.06, -Wd / 2 + 0.25, 0.44, FRUITS)
    tray(A, p, -L / 2 + 0.25, L / 2 - 0.25, Wd / 2 - 0.25, Wd / 2 - 0.06, 0.44, FRUITS)
    tray(A, p, -L / 2 + 0.3, L / 2 - 0.3, -Wd / 2 + 0.28, Wd / 2 - 0.28, 0.6, FRUITS)
    return A.build("ProduceIsland")


# ------------------------------------------------------------------ chest freezer with sliding glass lids, stocked
def chest_freezer(fname, L=2.4, Wd=1.0, H=0.92, seed=4):
    P.reset()
    random.seed(seed)
    A = Acc()
    p = pal()
    cream = solid("freezer", (0.9, 0.9, 0.86), 0.5)
    dark = solid("dark", (0.07, 0.08, 0.09), 0.6)
    frame = solid("frame", (0.72, 0.74, 0.78), 0.35, 0.8)
    inner = solid("inner", (0.85, 0.92, 0.95), 0.4)
    sg = P.mat("Sign_frozen", os.path.join(TEXD, "sign_frozen.png"), (1, 1, 1, 1), 0.6)
    A.box((0, 0, 0.06), (L - 0.1, Wd - 0.1, 0.12), dark)                                        # plinth
    A.box((0, 0, 0.12 + 0.19), (L - 0.04, Wd - 0.04, 0.38), cream)                            # the solid base under the well
    for sy in (-1, 1):
        A.box((0, sy * (Wd / 2 - 0.03), 0.12 + 0.36), (L, 0.06, 0.72), cream)                  # the long walls
    for sx in (-1, 1):
        A.box((sx * (L / 2 - 0.03), 0, 0.12 + 0.36), (0.06, Wd - 0.12, 0.72), cream)           # the end walls
    A.box((0, -Wd / 2 - 0.004, 0.45), (0.8, 0.012, 0.2), sg, front=(0, 0.45, 0.8, 0.2))      # the FROZEN plate on the long front
    for i in range(7):
        A.box((-0.9 + i * 0.3, -Wd / 2 - 0.004, 0.2), (0.16, 0.01, 0.02), dark)                  # the vent slots
    # the rim round the opening (the well stays open), the well lined and floored
    ow, od = L - 0.2, Wd - 0.2
    for sy in (-1, 1):
        A.box((0, sy * (od / 2 + 0.05), 0.865), (L, 0.1, 0.04), cream)
        A.box((0, sy * (od / 2 + 0.05), 0.89), (L, 0.1, 0.012), frame)
    for sx in (-1, 1):
        A.box((sx * (ow / 2 + 0.05), 0, 0.865), (0.1, Wd - 0.2, 0.04), cream)
        A.box((sx * (ow / 2 + 0.05), 0, 0.89), (0.1, Wd - 0.2, 0.012), frame)
    for sy in (-1, 1):
        A.box((0, sy * (od / 2 + 0.005), 0.66), (ow, 0.012, 0.36), inner)                        # inside lining of the well
    for sx in (-1, 1):
        A.box((sx * (ow / 2 + 0.005), 0, 0.66), (0.012, od, 0.36), inner)
    A.box((0, 0, 0.5), (ow, od, 0.01), inner)                                                    # the well's floor
    # frozen goods: pizza boxes, tubs, bags, laid in rows (and stacked)
    zi = 0.505
    x = -ow / 2 + 0.12
    while x < ow / 2 - 0.1:
        kind = random.choice(["pizza", "tub", "bag", "box"])
        w = {"pizza": 0.28, "tub": 0.16, "bag": 0.2, "box": 0.18}[kind]
        y = -od / 2 + 0.12
        while y < od / 2 - 0.08:
            col = p[random.choice(COLS)]
            stack = random.choice([1, 2, 3, 4]) if kind in ("pizza", "box", "bag") else 1
            for s in range(stack):
                zz = zi + s * (0.035 if kind == "pizza" else 0.05 if kind == "bag" else 0.07)
                if kind == "pizza":
                    A.box((x, y, zz + 0.0175), (0.26, 0.26, 0.033), p["cream"] if s % 2 == 0 else col)
                elif kind == "tub":
                    A.cyl((x, y, zz + 0.05), 0.065, 0.10, col, 6)
                    A.cyl((x, y, zz + 0.103), 0.068, 0.012, p["white"], 6)
                elif kind == "bag":
                    A.box((x, y, zz + 0.025), (0.19, 0.14, 0.05), col)
                else:
                    A.box((x, y, zz + 0.035), (0.17, 0.12, 0.07), col)
            y += w * 0.9 if kind != "tub" else 0.16
        x += w * 0.9
    # the lids: two sliding panes in aluminium frames, one sitting a little above the other, a finger slot in each
    for i, sx in enumerate((-1, 1)):
        cx = sx * (ow / 4 + 0.02)
        zz = 0.915 + 0.012 * i
        A.box((cx, 0, zz), (ow / 2 + 0.02, od + 0.04, 0.008), glass())
        for sy in (-1, 1):
            A.box((cx, sy * (od / 2 + 0.02), zz + 0.008), (ow / 2 + 0.02, 0.03, 0.03), frame)
        for sxx in (-1, 1):
            A.box((cx + sxx * (ow / 4 + 0.01), 0, zz + 0.008), (0.03, od + 0.04, 0.03), frame)
        A.box((cx - sx * 0.2, 0, zz + 0.02), (0.1, 0.03, 0.012), dark)
    return A.build("ChestFreezer")


# ------------------------------------------------------------------ the game shop's display case: black plinth, glass box, game boxes on two sloped boards (pictures facing BOTH ways, a plain back to each)
def game_case(fname, L=1.6, D=0.6):
    P.reset()
    random.seed(9)
    A = Acc()
    black = solid("casebase", (0.05, 0.05, 0.06), 0.4)
    velvet = solid("velvet", (0.08, 0.04, 0.1), 0.95)
    chrome = solid("frame", (0.72, 0.74, 0.78), 0.35, 0.8)
    A.box((0, 0, 0.03), (L - 0.1, D - 0.1, 0.06), black)                                         # the recessed kick
    A.box((0, 0, 0.22), (L, D, 0.32), black)                                                     # the cabinet
    A.box((0, -D / 2 - 0.004, 0.22), (L - 0.1, 0.008, 0.2), solid("casepanel", (0.12, 0.12, 0.15), 0.4))   # an inset door panel on each long side
    A.box((0, D / 2 + 0.004, 0.22), (L - 0.1, 0.008, 0.2), solid("casepanel", (0.12, 0.12, 0.15), 0.4))
    A.box((0, 0, 0.395), (L + 0.02, D + 0.02, 0.03), chrome)                                      # the top rim
    A.box((0, 0, 0.415), (L - 0.06, D - 0.06, 0.012), velvet)                                    # the display bed
    top = 1.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            A.box((sx * (L / 2 - 0.012), sy * (D / 2 - 0.012), (0.41 + top) / 2), (0.024, 0.024, top - 0.41), chrome)   # corner posts
    A.box((0, 0, top - 0.006), (L, D, 0.02), chrome)                                              # the lid frame
    g = glass()
    A.box((0, -D / 2 + 0.006, (0.41 + top) / 2), (L - 0.05, 0.006, top - 0.43), g)
    A.box((0, D / 2 - 0.006, (0.41 + top) / 2), (L - 0.05, 0.006, top - 0.43), g)
    for sx in (-1, 1):
        A.box((sx * (L / 2 - 0.006), 0, (0.41 + top) / 2), (0.006, D - 0.05, top - 0.43), g)
    A.box((0, 0, top + 0.001), (L - 0.05, D - 0.05, 0.006), g)
    # two sloped boards back to back (a ridge down the middle), the game boxes leaning on them
    ang = math.radians(34)
    sl = 0.24
    cy = 0.15                                                  # the centre of each slope, off the ridge
    zc = 0.5
    A.box((0, 0, 0.46), (L - 0.1, 0.1, 0.09), black)
    for sy in (-1, 1):
        A.box((0, sy * cy, zc), (L - 0.1, sl, 0.014), black, rx=ang if sy < 0 else -ang)
    n_per = 7
    step = (L - 0.2) / n_per
    back = P.mat("CoverBack", os.path.join(TEXD, "cover_back.png"), (1, 1, 1, 1), 0.7)
    for sy in (-1, 1):
        for i in range(n_per):
            k = random.randrange(8)
            cm = P.mat("Cover%d" % k, os.path.join(TEXD, "cover_%d.png" % k), (1, 1, 1, 1), 0.6)
            x = -L / 2 + 0.1 + (i + 0.5) * step
            nrm = (0, -sy * math.sin(ang) * -1, 0)
            # position: a point on the slope, lifted off it by half the box thickness along the slope's normal
            nz = math.cos(ang)
            ny = (-math.sin(ang) if sy < 0 else math.sin(ang))
            A.box((x, sy * cy + ny * 0.012, zc + nz * 0.012), (step - 0.02, sl - 0.02, 0.016), cm, rx=ang if sy < 0 else -ang, cover="norm" if sy < 0 else "flip")
    # price cards standing on the bed at the front of each slope
    for sy in (-1, 1):
        for i in range(3):
            A.box((-0.4 + i * 0.4, sy * (D / 2 - 0.07), 0.45), (0.1, 0.004, 0.06), solid("card", (0.95, 0.93, 0.8), 0.8))
    return A.build("GameCase")


def main():
    for fn, build in (("MKT_WallFridge_drinks.glb", lambda: wall_fridge("", sign="drinks", seed=1)), ("MKT_WallFridge_dairy.glb", lambda: wall_fridge("", sign="dairy", seed=7)),
                      ("MKT_ProduceWall.glb", lambda: produce_wall("")), ("MKT_ProduceIsland.glb", lambda: produce_island("")), ("MKT_ChestFreezer.glb", lambda: chest_freezer("")), ("MKT_GameCase.glb", lambda: game_case(""))):
        build()
        P.export(fn)


main()
