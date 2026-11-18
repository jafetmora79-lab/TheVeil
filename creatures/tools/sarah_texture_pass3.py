"""Sarah v3 texture pass (same painter as pass 2 for the head; new body atlas painter for the single clothed body mesh). Original docstring: Sarah PS2 texture + face pass 2 (all painted independently, procedurally; nothing is taken from any other game's files).
   blender -b creatures/humans/sarah/CHR_Sarah_PS2_phase2.blend -P creatures/tools/sarah_texture_pass2.py -- <out_dir> <out.blend> <out.glb>
Keeps the head, the head UV layout (v2) and the rig. Changes only textures/materials:
 - head: one 128x128 map, small low-contrast features, mottled red-brown skin, darker sockets, flat painted hair with strand direction, closed neutral mouth;
   two extra mouth variants (open / round) as whole-map texture swaps - no mouth geometry
 - body: ONE 256x256 atlas (shirt, trousers, hands/neck, boots, belt gear, collar/pocket patch, ponytail) with folds, creases, wear and stains painted in
 - one shared cloudy fog/grunge field laid over skin and cloth (same noise in both maps), no gloss; filtered (linear) rather than hard-pixel"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector

OUT_DIR, OUT_BLEND, OUT_GLB = os.path.abspath(sys.argv[sys.argv.index("--") + 1]), sys.argv[sys.argv.index("--") + 2], sys.argv[sys.argv.index("--") + 3]
os.makedirs(OUT_DIR, exist_ok=True)
rng = np.random.default_rng(11)
head = bpy.data.objects["Sarah_Head"]
body = bpy.data.objects["Sarah_Body"]
hair = bpy.data.objects["Sarah_Hair"]
S = 1.66 / 2.006

if 'Sarah_Head_ORIGINAL' in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects['Sarah_Head_ORIGINAL'])


# ------------------------------------------------------------------------------------------------------------- helpers
def hexs(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)], dtype=np.float32)


def sm(e0, e1, x):
    if abs(e1 - e0) < 1e-9:
        return 1.0 if x >= e1 else 0.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def mix(c, c2, a):
    return c + (np.asarray(c2, dtype=np.float32) - c) * max(0.0, min(1.0, a))


def ell(x, z, cx, cz, rx, rz):
    return ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2


def vnoise(g, seed):
    r = np.random.default_rng(seed).random((g, g))
    return r


def fbm(n, seed=5, base=4, octaves=5):
    """cloudy value noise 0..1, n x n"""
    out = np.zeros((n, n), dtype=np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        g = base * 2 ** o
        r = vnoise(g + 1, seed + o)
        xs = np.linspace(0, g, n, endpoint=False)
        x0 = xs.astype(int)
        fx = xs - x0
        a = r[:, x0] * (1 - fx) + r[:, x0 + 1] * fx
        b = a[x0, :] * (1 - fx)[:, None] + a[x0 + 1, :] * fx[:, None]
        out += b * amp
        tot += amp
        amp *= .55
    out /= tot
    return (out - out.min()) / (out.max() - out.min())


FOG = fbm(256, 21)                                       # ONE shared fog field for every map (the 128 head map reads the same field at half size)
FOG_B = fbm(256, 77, 3, 4)


def fog_at(u, v, n):
    return FOG[min(255, int(v * 255)), min(255, int(u * 255))]


def apply_fog(tex, strength=1.0):
    n = tex.shape[0]
    f = FOG if n == 256 else FOG.reshape(n, 256 // n, n, 256 // n).mean(axis=(1, 3))
    f = (f - .35) / .5
    f = np.clip(f, 0, 1)[..., None]
    grey = np.array([.44, .45, .47], dtype=np.float32)
    dark = np.clip((FOG_B if n == 256 else FOG_B.reshape(n, 256 // n, n, 256 // n).mean(axis=(1, 3))), 0, 1)[..., None]
    out = tex * (1 - .22 * strength * dark) * (1 - .10 * strength * f)
    out = out + (grey - out) * .20 * strength * f                       # cloudy grey haze, also desaturates
    return np.clip(out, 0, 1)


def raster(ob, tex, fn, tags=None):
    me = ob.data
    uv = me.uv_layers.active.data
    Hh, Ww = tex.shape[:2]
    done = np.zeros((Hh, Ww), dtype=bool)
    for pi, poly in enumerate(me.polygons):
        tag = tags[pi] if tags else None
        li = poly.loop_indices
        for k in range(1, len(li) - 1):
            ls = (li[0], li[k], li[k + 1])
            uvs_ = np.array([[uv[l].uv[0] * Ww, uv[l].uv[1] * Hh] for l in ls])
            pos = np.array([me.vertices[me.loops[l].vertex_index].co[:] for l in ls])
            x0, x1 = int(max(0, math.floor(uvs_[:, 0].min() - 1))), int(min(Ww - 1, math.ceil(uvs_[:, 0].max() + 1)))
            y0, y1 = int(max(0, math.floor(uvs_[:, 1].min() - 1))), int(min(Hh - 1, math.ceil(uvs_[:, 1].max() + 1)))
            if x1 < x0 or y1 < y0:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
            a, b, c = uvs_
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-9:
                continue
            w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
            w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
            w2 = 1 - w0 - w1
            e = -.7 / max(1.0, abs(d) ** .5)
            yy, xx = np.nonzero((w0 >= e) & (w1 >= e) & (w2 >= e))
            for iy, ix in zip(yy, xx):
                p = w0[iy, ix] * pos[0] + w1[iy, ix] * pos[1] + w2[iy, ix] * pos[2]
                tex[y0 + iy, x0 + ix] = fn(Vector(p), poly.normal, tag, (x0 + ix + .5) / Ww, (y0 + iy + .5) / Hh)
                done[y0 + iy, x0 + ix] = True
    for _ in range(4):
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh, shd = np.roll(np.roll(tex, dy, 0), dx, 1), np.roll(np.roll(done, dy, 0), dx, 1)
            m = (~done) & shd
            tex[m] = sh[m]
            done |= m
    return tex


def blur(tex, n=1):
    for _ in range(n):
        tex = (tex * 4 + np.roll(tex, 1, 0) + np.roll(tex, -1, 0) + np.roll(tex, 1, 1) + np.roll(tex, -1, 1)) / 8
    return tex


def to_image(name, tex):
    h, w = tex.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    flat = np.ones((h, w, 4), dtype=np.float32)
    flat[..., :3] = np.clip(tex, 0, 1)
    img.pixels[:] = flat.reshape(-1)
    img.pack()
    return img


# ------------------------------------------------------------------------------------------------------------- palette (desaturated, low contrast)
SKIN_A, SKIN_B, SKIN_C = hexs("#b58d7b"), hexs("#a47468"), hexs("#c5a28d")       # base, red-brown blotch, pale blotch
SOCKET, HAIR_A, HAIR_B, BROW_C = hexs("#7d5a52"), hexs("#58392a"), hexs("#3b261c"), hexs("#5a4034")
NAVY, NAVY_D, TROU, CREAM = hexs("#2c3552"), hexs("#1c2338"), hexs("#262b39"), hexs("#a9a58f")
LEATHER, BOOT = hexs("#3a2d25"), hexs("#33261e")

# ------------------------------------------------------------------------------------------------------------- HEAD (128 x 128)
xmin, xmax, zmin, zbrow, zmax = head["uv_front"]
face_cx = (xmin + xmax) / 2
ez = 1.534
EXL, EXR = -0.029, 0.030
hv = np.array([v.co[:] for v in head.data.vertices])
hymin, hymax = hv[:, 1].min(), hv[:, 1].max()
hzmin, hzmax = hv[:, 2].min(), hv[:, 2].max()


def blotch(p, seed_off=0.0):
    return (math.sin(p.x * 61 + p.z * 17 + 1.7 + seed_off) + math.sin(p.z * 53 - p.x * 23 + .6) + math.sin((p.x + p.z) * 37 + 2.2)) / 3


# the crown ("top") and the underside of the jaw shared one UV rectangle: give each its own half so the underside is not painted with hair
hxall = (hv[:, 0].min(), hv[:, 0].max())
for poly in head.data.polygons:
    nz = poly.normal.z
    if nz > .45 or nz < -.45:
        for l in poly.loop_indices:
            co = head.data.vertices[head.data.loops[l].vertex_index].co
            t = (co.y - hymin) / (hymax - hymin)
            xx = (co.x - hxall[0]) / (hxall[1] - hxall[0])
            head.data.uv_layers.active.data[l].uv = (.88 + xx * .11, (.27 + (1 - t) * .22) if nz > 0 else (.02 + t * .22))


def head_fn_factory(mouth):
    def head_fn(p, n, tag, u, v):
        up = (p.z - hzmin) / (hzmax - hzmin)
        back = (p.y - hymin) / (hymax - hymin)
        x, z = p.x - face_cx, p.z
        is_hair = up > .80 or (up > .45 and back > .50) or (up > .52 and abs(x) > .052) or n.z > .45
        if is_hair:
            # flat painted hair block: strands run down the sides/front and back-to-front over the crown
            s = math.sin(p.x * 210 + math.sin(p.z * 14) * 1.6) * .5 + .5 if n.z <= .45 else math.sin(p.y * 210 + math.sin(p.x * 18) * 1.4) * .5 + .5
            col = mix(HAIR_A, HAIR_B, .25 + .55 * s)
            col = col * (.86 + .22 * (.5 + .5 * math.sin(p.z * 9 + p.x * 21)))
            col = mix(col, hexs("#7a5a42"), .18 * max(0.0, math.sin(p.x * 140 + p.z * 25)) * (1 if n.z <= .45 else 1))        # a few lighter strands
            col = mix(col, HAIR_B, .55 * sm(.74, .62, up) * (n.y < -.2))                                                          # dark roots at the hairline
            return col
        col = SKIN_A.copy()
        b = blotch(p)
        col = mix(col, SKIN_B, .55 * sm(.08, .55, b))                                      # red-brown mottling
        col = mix(col, SKIN_C, .45 * sm(.08, .55, -b))
        col = mix(col, SKIN_B, .25 * math.exp(-ell(abs(x), z, .05, ez - .034, .026, .022)))   # flushed cheeks
        col = mix(col, SKIN_B, .22 * sm(.40, 0.0, up))                                      # jaw / neck end
        col = mix(col, SOCKET, .22 * sm(.065, .09, abs(x)))                                 # temples
        for ex in (EXL - face_cx, EXR - face_cx):
            dx, dz = x - ex, z - ez
            col = mix(col, SOCKET, .62 * (1 - sm(.15, 1.0, ell(dx, dz, 0, .002, .033, .019))))        # dark, shadowed eye socket
            col = mix(col, SOCKET, .35 * (1 - sm(.15, 1.0, ell(dx, dz, 0, -.0125, .024, .006))))      # tired under-eye
            W = .0150
            top = .0050 * max(0.0, 1 - (dx / W) ** 2) + .0004
            bot = -.0040 * max(0.0, 1 - (dx / W) ** 2)
            if abs(dx) < W and bot < dz < top:
                c = hexs("#9a948a") * (.8 + .2 * (1 - abs(dx) / W))                         # grey sclera
                ir = ell(dx, dz, 0, .0004, .0058, .0058)                                    # iris a touch larger and darker than life
                if ir < 1:
                    c = mix(c, hexs("#2d2521"), .92 * (1 - sm(.7, 1.0, ir)))
                col = c
            col = mix(col, hexs("#3a2a26"), .75 * (1 - sm(.0, .0016, abs(dz - (top + .0006)))) * (1 if abs(dx) < W * 1.1 else 0))    # soft lid line
            u2 = (abs(dx) + 0.0)
            by = ez + .0205 + .004 * math.sin(math.pi * min(1.0, max(0.0, (dx * (1 if ex > 0 else -1) + .008) / .05))) - .002
            if abs(x) > .010 and abs(dx) < .040 and abs(z - by) < .0045:
                col = mix(col, BROW_C, .55)                                                 # soft brow
        # nose: a little shading, no outline
        col = mix(col, SKIN_B, .20 * math.exp(-((abs(x) - .0100) / .004) ** 2) * sm(ez - .003, ez - .02, z) * sm(ez - .05, ez - .035, z))
        col = mix(col, hexs("#5c3f38"), .70 * (1 - sm(.6, 1.0, ell(abs(x), z, .0068, ez - .0495, .0034, .0020))))
        # closed neutral mouth: a single soft line with a faintly tinted lower lip; the open variants only change this block
        lz = ez - .0715
        hw = .0215
        if mouth == "neutral":
            ln = 1 - sm(.0004, .0017, abs(z - lz + .0003 * (1 - (x / hw) ** 2)))
            col = mix(col, hexs("#6a4640"), .75 * ln * (1 - sm(.85, 1.05, abs(x) / hw)))
            col = mix(col, hexs("#a06b60"), .22 * (1 - sm(.6, 1.1, ell(x, z, 0, lz - .0042, .015, .0036))))
        elif mouth == "open":
            op = 1 - sm(.85, 1.05, ell(x, z, 0, lz - .0015, .0150, .0066))
            col = mix(col, hexs("#2b1816"), .95 * op)
            col = mix(col, hexs("#8c8174"), .55 * op * (1 - sm(.0, .0020, abs(z - (lz + .0035))) * 0) * (1 if z > lz + .0020 else 0))     # upper teeth
        else:   # "round" (oo)
            op = 1 - sm(.7, 1.05, ell(x, z, 0, lz - .0010, .0085, .0080))
            col = mix(col, hexs("#2b1816"), .95 * op)
        return col
    return head_fn


def make_head(mouth):
    t = raster(head, np.tile(SKIN_A, (128, 128, 1)).astype(np.float32), head_fn_factory(mouth))
    t = blur(t, 1)
    return apply_fog(t, 1.0)


tex_head = {m: make_head(m) for m in ("neutral", "open", "round")}

# ------------------------------------------------------------------------------------------------------------- BODY ATLAS (256 x 256)
# one clothed body surface: the smart-projected islands are squeezed into u 0-.78 and the ponytail takes the strip u .80-1
bme = body.data
buv = bme.uv_layers.active.data
for l in range(len(buv)):
    u, v = buv[l].uv
    buv[l].uv = (u * .77 + .005, v * .985 + .005)
hz = np.array([v.co.z for v in hair.data.vertices])
if not hair.data.uv_layers:
    hair.data.uv_layers.new(name="UVMap")
huvh = hair.data.uv_layers.active.data
for poly in hair.data.polygons:
    for l in poly.loop_indices:
        co = hair.data.vertices[hair.data.loops[l].vertex_index].co
        huvh[l].uv = (.81 + ((co.x * 9.0 + co.y * 7.0) % 1.0) * .17, .03 + (co.z - hz.min()) / max(1e-6, hz.max() - hz.min()) * .94)
HEM, WAIST, SHO, NECK = .97 * S, 1.12 * S, 1.46 * S, 1.57 * S
LEATHER_D = hexs("#2f241d")


def body_region(p):
    ax = abs(p.x)
    if p.z > NECK and ax < .09 * S:
        return "neck"
    if ax > .37 * S and p.z < 1.12 * S:
        return "hand"
    if ax > .205 * S and 1.12 * S <= p.z < SHO + .04 * S:
        return "sleeve"
    if p.z >= HEM:
        return "shirt"
    if p.z < .26 * S:
        return "boot"
    return "trouser"


def body_fn(p, n, tag, u, v):
    if tag == "hair":
        s = math.sin(p.z * 170 + math.sin(p.x * 25) * 2.0) * .5 + .5
        return mix(HAIR_A, HAIR_B, .3 + .5 * s) * (.88 + .2 * math.sin(p.z * 60))
    reg = body_region(p)
    wv = 1.0 + .035 * (1 if (int(p.x * 230) + int(p.z * 230)) % 2 else -1)
    skin = mix(mix(SKIN_A, SKIN_B, .55 * sm(.08, .55, blotch(p, 1.3))), SKIN_C, .4 * sm(.08, .55, -blotch(p, 1.3)))
    if reg == "hand":
        return mix(skin, SKIN_B, .2 * sm(1.0 * S, .90 * S, p.z))
    if reg == "neck":
        return mix(skin, SKIN_B, .30 * sm(1.40 * S, 1.58 * S, p.z))
    if reg == "boot":
        col = BOOT * (.8 + .4 * abs(math.sin(p.x * 130) * math.sin(p.y * 90 + 1.0)))
        col = mix(col, hexs("#4e3d31"), .45 * math.exp(-((p.z - .20 * S) / .01) ** 2))
        col = mix(col, hexs("#171210"), .9 * sm(.03 * S, .015 * S, p.z))
        return mix(col, hexs("#6a5c4c"), .25 * max(0.0, math.sin(p.x * 70 + p.y * 40)) * sm(.10, .03, p.z))
    if reg in ("shirt", "sleeve"):
        col = NAVY * wv
        if reg == "sleeve":
            col = col * (1 - .28 * math.exp(-((p.z - 1.27 * S) / .035) ** 2) * (.5 + .5 * math.sin(abs(p.x) * 170)))
            col = col * (1 - .20 * math.exp(-((p.z - 1.38 * S) / .03) ** 2))
            col = mix(col, hexs("#4a5068"), .22 * math.exp(-((p.z - 1.27 * S) / .05) ** 2))
            if p.z < 1.12 * S + .058 * S:
                col = mix(col, CREAM * (.85 + .15 * wv), .92)
        else:
            col = col * (1 - .22 * math.exp(-(((abs(p.x) - .13 * S) / .03) ** 2 + ((p.z - 1.28 * S) / .04) ** 2)))
            col = col * (1 - .16 * math.exp(-((p.z - (WAIST + .06)) / .03) ** 2) * (.5 + .5 * math.sin(p.x * 110 + p.z * 40)))
            if p.z > 1.44 * S and abs(abs(p.x) - .17 * S) < .006:
                col = NAVY_D
            if n.y < -.3 and abs(p.x) < .022 * S:
                col = col * .8
            if n.y < -.3 and .07 * S < p.x < .135 * S and abs(p.z - (1.225 * S)) < .011:
                col = mix(col, hexs("#9c8a58"), .8)
            # painted breast pockets with flap + stitch lines
            for sx in (-1, 1):
                if n.y < -.3 and .055 * S < sx * p.x < .115 * S and 1.215 * S < p.z < 1.275 * S and sx > 0 or (n.y < -.3 and .055 * S < sx * p.x < .115 * S and 1.215 * S < p.z < 1.275 * S):
                    edge = min(abs(p.z - 1.215 * S), abs(p.z - 1.275 * S), abs(abs(p.x) - .055 * S), abs(abs(p.x) - .115 * S))
                    col = mix(col, NAVY_D, .7 * (1 - sm(0, .004, edge)))
                    col = mix(col, hexs("#3d476a"), .25 * sm(1.250 * S, 1.275 * S, p.z))
            # painted duty belt: dark leather band, buckle, pouch (left hip) and radio holster (right hip)
            if abs(p.z - WAIST) < .022:
                col = LEATHER_D * (.85 + .3 * abs(math.sin(p.x * 120)))
                if n.y < -.3 and abs(p.x) < .016:
                    col = hexs("#7d7664")
            if n.y > -.5 and WAIST - .09 < p.z < WAIST - .004 and -.205 * S < p.x < -.12 * S:
                col = LEATHER_D * 1.2
            if WAIST - .08 < p.z < WAIST - .004 and .12 * S < p.x < .20 * S:
                col = hexs("#1d1a1a")
            if p.z < HEM + .03:
                col = col * .86
        col = mix(col, hexs("#171b2a"), .55 * sm(.22, .55, blotch(p, 3.1)) * sm(HEM + .12, HEM, p.z))
        col = mix(col, hexs("#3a3a30"), .18 * sm(.55, .8, blotch(p, 5.5)))
        # collar: a lighter folded edge around the neck opening
        if p.z > 1.50 * S and abs(p.x) < .13 * S:
            col = mix(col, hexs("#3b4568"), .55 * sm(1.50 * S, 1.56 * S, p.z))
        return col
    col = TROU * wv
    if n.y < -.4 and abs(abs(p.x) - .095) < .005:
        col = col * 1.35
    col = col * (1 - .24 * math.exp(-((p.z - .52 * S) / .05) ** 2) * (.5 + .5 * math.sin(p.x * 130 + p.z * 90)))
    col = col * (1 - .20 * math.exp(-((p.z - .80 * S) / .04) ** 2))
    col = mix(col, hexs("#43485a"), .25 * math.exp(-((p.z - .50 * S) / .045) ** 2) * (n.y < -.2))
    if n.y < -.2 and abs(p.z - .54 * S) < .035 and .02 < abs(p.x) < .14:                       # painted knee pads
        edge = min(abs(p.z - .505 * S), abs(p.z - .575 * S))
        col = mix(col, hexs("#1a1e29"), .55 * (1 - sm(0, .004, edge)))
    if abs(p.z - .72 * S) < .04 and abs(p.x) > .115 * S and n.x * (1 if p.x > 0 else -1) > .3:  # thigh pocket
        col = mix(col, hexs("#1d212c"), .5)
    col = mix(col, hexs("#161921"), .6 * sm(.25, .55, blotch(p, 2.2)) * sm(.35, .10, p.z))
    return col


atlas = np.tile(TROU, (256, 256, 1)).astype(np.float32)
raster(body, atlas, body_fn, None)
raster(hair, atlas, body_fn, ["hair"] * len(hair.data.polygons))
atlas = apply_fog(blur(atlas, 1), 1.0)

# ------------------------------------------------------------------------------------------------------------- materials
def mat(name, tex, interp='Linear'):
    img = to_image("T_" + name, tex)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    t.interpolation = interp
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 1.0
    try:
        b.inputs["Specular IOR Level"].default_value = 0.0                           # no gloss
    except KeyError:
        pass
    return m


M_head = mat("Sarah_Face_P2", tex_head["neutral"])
M_body = mat("Sarah_Body_P2", atlas)
for ob, m in ((head, M_head), (body, M_body), (hair, M_body)):
    ob.data.materials.clear()
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.material_index = 0
for ob in (body, head, hair):
    for p in ob.data.polygons:
        p.use_smooth = False


def save_png(name, tex):
    img = to_image(name, tex)
    img.filepath_raw = os.path.join(OUT_DIR, name + ".png")
    img.file_format = 'PNG'
    img.save()


save_png("Sarah_Head_128_neutral", tex_head["neutral"])
save_png("Sarah_Head_128_mouth_open", tex_head["open"])
save_png("Sarah_Head_128_mouth_round", tex_head["round"])
save_png("Sarah_Body_256_atlas", atlas)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT_GLB), export_format="GLB", export_animations=False, export_skins=True, export_yup=True, export_apply=False)
print("PASS2 DONE head tris", sum(len(p.vertices) - 2 for p in head.data.polygons))
