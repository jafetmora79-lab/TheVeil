"""Sarah head v6: paint the head/cap/ponytail textures straight onto the REAL Blender UVs.
For each UV triangle the pixel is shaded from its 3D position: the painted face (ChatGPT atlas, used only as a flat face reference)
is projected onto the front of the head using the real 3D landmarks (brow, eyes, nose, mouth, chin); everything else (skin, ears, neck, hair) is painted procedurally.
   blender -b head_v6_geo.blend -P paint_sarah_head_v6.py -- <out.blend> <tex_dir>"""
import bpy, sys, os, math, bmesh
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OUT, TEXDIR = os.path.abspath(a[0]), os.path.abspath(a[1])
os.makedirs(TEXDIR, exist_ok=True)
T = 256
src = bpy.data.images.load(os.path.abspath("creatures/humans/sarah/head_v5_tex/chatgpt_face_atlas_source.png"))
W, H = src.size
A = np.array(src.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1, :, :3]          # top-down
k = 3
A = A[:H // k * k, :W // k * k].reshape(H // k, k, W // k, k, 3).mean((1, 3))           # pre-filter to avoid aliasing
AH, AW = A.shape[:2]
cheek = A[int(650 / k):int(700 / k), int(240 / k):int(300 / k)].reshape(-1, 3).mean(0)
SKIN = np.array([.80, .62, .52]) * .55 + cheek * .45
HAIR_A, HAIR_B = np.array([.19, .115, .085]), np.array([.30, .185, .13])
LZ = np.array([1.40, 1.443, 1.492, 1.522, 1.553, 1.568, 1.60, 1.65])
LY = np.array([1010, 905, 790, 710, 552, 497, 330, 215], dtype=np.float32)


def sm(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def hash2(x, y):
    return (math.sin(x * 127.1 + y * 311.7) * 43758.5453) % 1.0


def noise(p, s):
    return (math.sin(p.x * s * 1.3 + p.z * s * .7) + math.sin(p.y * s * 1.9 - p.z * s * 1.1) + math.sin((p.x + p.y) * s * .8)) / 3


def hair_col(p, n):
    ang = math.atan2(p.x, p.y + .01) * 16 + p.z * 40
    s = .5 + .5 * math.sin(ang + math.sin(p.z * 70) * 1.3)
    c = HAIR_A * (1 - s) + HAIR_B * s
    return c * (.88 + .2 * hash2(math.floor(p.x * 300), math.floor(p.z * 300)))


def skin_col(p, n, region):
    m = noise(p, 70)
    c = SKIN * (1 + .07 * m)
    if hash2(math.floor(p.x * 260), math.floor(p.z * 260) + math.floor(p.y * 260)) > .985 and region == "face":
        c = c * .82
    if region == "neck":
        c = c * (.95 + .05 * sm((p.z - 1.40) / .05))
    if p.z < 1.47:
        c = c * (1 - .05 * sm((1.47 - p.z) / .05))
    return c


def face_sample(p):
    xs = 395 + p.x * 3300
    ys = float(np.interp(p.z, LZ, LY))
    xs = min(max(xs, 0), W - 1) / k
    ys = min(max(ys, 0), H - 1) / k
    return A[int(min(ys, AH - 1)), int(min(xs, AW - 1))]


def is_ear(p):
    return abs(p.x) > .060 and -.010 < p.y < .038 and 1.532 < p.z < 1.586


def shade(p, n, kind):
    if kind == "cap":
        return hair_col(p, n)
    if kind == "head":
        if p.z < 1.452:
            return skin_col(p, n, "neck")
        de = math.hypot((p.y - .014) / .022, (p.z - 1.558) / .028)
        if is_ear(p) and de < 1.25:
            c = skin_col(p, n, "ear")
            w = 1 - sm((de - .75) / .5)
            rim = .88 + .1 * sm(abs(de - .55) / .35)
            inner = .90 if de < .45 else 1.0
            tint = np.array([1.05, .95, .93])
            return c * (1 - w) + c * rim * inner * tint * w
        hair = p.z > 1.600 or (p.y > .005 and p.z > 1.525) or (abs(p.x) > .055 and p.z > 1.588 and p.y > -.03)
        wf = sm((-n.y - .10) / .35) * (1 - sm((abs(p.x) - .048) / .014)) * (1 if p.y < -.03 else 0)
        base = hair_col(p, n) if hair else skin_col(p, n, "face")
        if wf > 0:
            fs = face_sample(p)
            if fs.min() > .80:
                return base
            return base * (1 - wf) + fs * wf
        return base
    return hair_col(p, n)


def paint(obj, tex, kind):
    me = obj.data
    uv = me.uv_layers.active.data
    cover = np.zeros((T, T), bool)
    for poly in me.polygons:
        li = list(poly.loop_indices)
        n = Vector(poly.normal)
        for i in range(1, len(li) - 1):
            ls = (li[0], li[i], li[i + 1])
            P = [me.vertices[me.loops[l].vertex_index].co for l in ls]
            Q = [np.array(uv[l].uv) * T for l in ls]
            x0, x1 = int(math.floor(min(q[0] for q in Q))), int(math.ceil(max(q[0] for q in Q)))
            y0, y1 = int(math.floor(min(q[1] for q in Q))), int(math.ceil(max(q[1] for q in Q)))
            d = (Q[1][1] - Q[2][1]) * (Q[0][0] - Q[2][0]) + (Q[2][0] - Q[1][0]) * (Q[0][1] - Q[2][1])
            if abs(d) < 1e-9:
                continue
            for y in range(max(y0, 0), min(y1 + 1, T)):
                for x in range(max(x0, 0), min(x1 + 1, T)):
                    px, py = x + .5, y + .5
                    l1 = ((Q[1][1] - Q[2][1]) * (px - Q[2][0]) + (Q[2][0] - Q[1][0]) * (py - Q[2][1])) / d
                    l2 = ((Q[2][1] - Q[0][1]) * (px - Q[2][0]) + (Q[0][0] - Q[2][0]) * (py - Q[2][1])) / d
                    l3 = 1 - l1 - l2
                    if min(l1, l2, l3) < -.03:
                        continue
                    p = P[0] * l1 + P[1] * l2 + P[2] * l3
                    tex[y, x] = shade(p, n, kind)
                    cover[y, x] = True
    for _ in range(3):
        new = np.zeros_like(cover)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(cover, dy, 0), dx, 1)
            cand = sh & ~cover & ~new
            tex[cand] = np.roll(np.roll(tex, dy, 0), dx, 1)[cand]
            new |= cand
        cover |= new
    return tex


def save_png(name, arr):
    q = np.clip(arr, 0, 1)
    q = np.round(q * 23) / 23
    img = bpy.data.images.new(name, arr.shape[1], arr.shape[0], alpha=False)
    rgba = np.concatenate([q, np.ones(q.shape[:2] + (1,))], -1)
    img.pixels[:] = rgba.reshape(-1).tolist()
    img.filepath_raw = os.path.join(TEXDIR, name + ".png")
    img.file_format = 'PNG'
    img.save()
    return img


head = bpy.data.objects["Sarah_Head"]
cap = bpy.data.objects["Sarah_HairCap"]
pony = bpy.data.objects["Sarah_Hair_Ponytail"]
# image rows in Blender run bottom-up, UV v=0 is the bottom row: tex[y] with y = v*T already matches
tex = np.tile(SKIN, (T, T, 1)).astype(np.float32)
paint(head, tex, "head")
paint(cap, tex, "cap")
img256 = save_png("Sarah_Head_256", tex)
t128 = tex.reshape(128, 2, 128, 2, 3).mean((1, 3))
save_png("Sarah_Head_128", t128)

PT = 64
pt = np.zeros((PT, PT, 3), np.float32)
rs = np.random.RandomState(11)
colw = rs.uniform(.55, 1.2, PT)
colo = rs.uniform(0, 6.28, PT)
for y in range(PT):
    for x in range(PT):
        wob = math.sin(y * .18 + colo[x]) * .5 + math.sin(y * .47 + colo[x] * 2.1) * .25
        s_ = np.clip(.25 + .35 * colw[x] * (.5 + .5 * wob) + (rs.rand() - .5) * .22, 0, 1)
        if rs.rand() < .015:
            s_ = min(1.0, s_ + .35)
        pt[y, x] = (HAIR_A * (1 - s_) + HAIR_B * s_) * (.95 + .1 * rs.rand())
pimg = save_png("Sarah_Ponytail_64", pt)


def make_mat(name, image):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    bs.inputs["Roughness"].default_value = 1.0
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = image
    tn.interpolation = 'Closest'
    nt.links.new(tn.outputs[0], bs.inputs["Base Color"])
    return m


mh = make_mat("Sarah_Face_v6", img256)
mp = make_mat("Sarah_Ponytail_v6", pimg)
for o, m in ((head, mh), (cap, mh), (pony, mp)):
    o.data.materials.clear()
    o.data.materials.append(m)
print("TRIS head", sum(len(p.vertices) - 2 for p in head.data.polygons), "cap", sum(len(p.vertices) - 2 for p in cap.data.polygons), "pony", sum(len(p.vertices) - 2 for p in pony.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
