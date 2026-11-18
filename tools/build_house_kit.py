"""THE VEIL - residential dressing kit (porch, yard, weathering). Blender 5.x:
   blender -b -P tools/build_house_kit.py -- game/world/dressing/VEIL_HouseKit.glb
Low-poly pieces + two small pixel atlases (nearest filtered at runtime). Hue-shifted ramps, clusters not noise."""
import bpy, bmesh, sys, math, random
from mathutils import Matrix

out = sys.argv[sys.argv.index("--") + 1]
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)


def c(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)) + (1.0,)


RAMP = {
    "conc": ["#3b3e47", "#555963", "#6f747c", "#8a8d8f"], "wood": ["#2a1f22", "#3f2c2a", "#5b4033", "#7b5b44"],
    "rust": ["#3a2124", "#5c2f2a", "#8a4a32", "#b0703f"], "clay": ["#4a2a2d", "#6e3a35", "#93513f", "#b8744d"],
    "moss": ["#1b2a22", "#2c4230", "#456b3d", "#6d8f4f"], "soil": ["#1d1a1f", "#2e2523", "#443229", "#5d4533"],
    "paper": ["#7d7a78", "#a29d97", "#c4bdb0", "#dcd5c4"], "plastic": ["#101216", "#1a1d24", "#2a2e38", "#3d4350"],
    "cloth": ["#2a3550", "#3a4a6e", "#52668f", "#7b8fb0"], "steel": ["#2c3039", "#444b57", "#626b78", "#8892a0"],
    "glow": ["#c98a3a", "#e8b25a", "#f6d58a", "#fff0c0"],
}
W, H, RS = 256, 128, 32
REG = {"conc": (0, 0), "wood": (64, 0), "rust": (128, 0), "clay": (192, 0), "moss": (0, 32), "soil": (64, 32), "paper": (128, 32),
       "plastic": (192, 32), "cloth": (0, 64), "steel": (64, 64), "glow": (128, 64), "crack": (192, 64)}
px = [0.0, 0.0, 0.0, 1.0] * (W * H)


def put(x, y, col):
    i = ((H - 1 - y) * W + x) * 4
    px[i:i + 4] = col


def cluster_fill(name, key):
    ox, oy = REG[name]
    r = RAMP[key]
    seeds = [(random.randrange(RS), random.randrange(RS), random.randrange(4)) for _ in range(10)]
    for y in range(RS):
        for x in range(RS):
            best = min(seeds, key=lambda s: (s[0] - x) ** 2 + (s[1] - y) ** 2 + random.random() * 6)
            put(ox + x, oy + y, c(r[best[2]]))


for n in ("conc", "wood", "rust", "clay", "moss", "soil", "paper", "plastic", "cloth", "steel", "glow"):
    cluster_fill(n, n)
ox, oy = REG["wood"]
for x in range(0, RS, 4):
    for y in range(RS):
        put(ox + x, oy + y, c(RAMP["wood"][0 if (y // 5) % 2 else 1]))
ox, oy = REG["paper"]
for y in range(0, RS, 6):
    for x in range(RS):
        put(ox + x, oy + y, c(RAMP["paper"][0]))
ox, oy = REG["crack"]
for y in range(RS):
    for x in range(RS):
        put(ox + x, oy + y, c(RAMP["conc"][1 + ((x * 3 + y) // 9) % 2]))
cx = 6
for y in range(RS):
    cx = max(3, min(RS - 4, cx + random.choice((-1, 0, 0, 1))))
    put(ox + cx, oy + y, c(RAMP["conc"][0]))
    put(ox + cx + 1, oy + y, c(RAMP["conc"][0]))


def uvr(name, inset=1):
    ox, oy = REG[name]
    return ((ox + inset) / W, 1 - (oy + RS - inset) / H, (ox + RS - inset) / W, 1 - (oy + inset) / H)


img = bpy.data.images.new("T_VeilHouseKit", W, H, alpha=True)
img.pixels[:] = px
img.pack()

AW, AH = 192, 64
apx = [0.0] * (AW * AH * 4)


def blobs(cell, ramp, n, rmin, rmax, vertical=False, dens=1.0):
    ox = cell * 64
    for _ in range(n):
        bx, by = random.randrange(4, 60), random.randrange(4, 60)
        rx = random.randint(rmin, rmax)
        ry = rx * (3 if vertical else 1)
        for y in range(max(0, by - ry), min(64, by + ry)):
            for x in range(max(0, bx - rx), min(64, bx + rx)):
                d = ((x - bx) / rx) ** 2 + ((y - by) / ry) ** 2
                if d < 1 and random.random() < dens:
                    col = c(ramp[random.choice((1, 2, 2, 3)) if d < .6 else random.choice((0, 1))])
                    i = (y * AW + ox + x) * 4
                    apx[i:i + 4] = col


blobs(0, RAMP["moss"], 26, 3, 7, dens=.9)
blobs(1, ["#14161b", "#1d1a1c", "#2a2420", "#3a3128"], 14, 2, 4, vertical=True, dens=.8)
blobs(2, ["#101114", "#17171a", "#201e1f", "#2b2826"], 5, 8, 13, dens=.95)
aimg = bpy.data.images.new("T_VeilHouseKit_A", AW, AH, alpha=True)
aimg.pixels[:] = apx
aimg.pack()


def mat(name, image, alpha=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    bsdf = n["Principled BSDF"]
    t = n.new("ShaderNodeTexImage")
    t.image = image
    t.interpolation = 'Closest'
    l.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        l.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return m


M = mat("M_VeilKit", img)
MA = mat("M_VeilKit_A", aimg, alpha=True)


def uv_proj(bm, name):
    u0, v0, u1, v1 = uvr(name)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for lp in f.loops:
            co = lp.vert.co
            lp[uv].uv = (u0 + (u1 - u0) * ((co.x * .9 + co.y * .6) % 1.0), v0 + (v1 - v0) * ((co.z * 1.1 + co.y * .4 + co.x * .3) % 1.0))
    return bm


def obj_from(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def box(sx, sy, sz, at=(0, 0, 0), rot=0.0, name="conc"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(rot, 3, 'Z'), verts=bm.verts)
    bmesh.ops.translate(bm, vec=at, verts=bm.verts)
    return uv_proj(bm, name)


def cyl(r1, r2, h, seg=8, at=(0, 0, 0), name="conc"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, vec=(at[0], at[1], at[2] + h / 2), verts=bm.verts)
    return uv_proj(bm, name)


def merge(bms):
    bm = bms[0]
    for o in bms[1:]:
        me = bpy.data.meshes.new("t")
        o.to_mesh(me)
        o.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    return bm


def rot(bm, deg, axis):
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(deg), 3, axis), verts=bm.verts)
    return bm


def lift(bm, z):
    bmesh.ops.translate(bm, vec=(0, 0, z), verts=bm.verts)
    return bm


def decal(name, w, h, cell, vertical):
    bm = bmesh.new()
    if vertical:
        pts = ((-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (-w / 2, 0, h))
    else:
        pts = ((-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0))
    f = bm.faces.new([bm.verts.new(p) for p in pts])
    uv = bm.loops.layers.uv.verify()
    u0, u1 = cell * 64 / AW, (cell + 1) * 64 / AW
    for lp, (u, v) in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))):
        lp[uv].uv = (u, v)
    return obj_from(name, bm, MA)


# ---- pieces (Blender Z up, base at 0) ----
obj_from("Slab_A", box(.9, .9, .07, (0, 0, .035)), M)
obj_from("Slab_B", box(.9, .9, .07, (0, 0, .035), .05, "crack"), M)
obj_from("Slab_C", box(.9, .8, .08, (0, 0, .025), .12, "crack"), M)
obj_from("DoorMat", box(.85, .52, .03, (0, 0, .015), 0, "cloth"), M)
stalks = [box(.015, .015, .3, (random.uniform(-.1, .1), random.uniform(-.1, .1), .5), random.uniform(-.4, .4), "wood") for _ in range(4)]
obj_from("Pot_Dead", merge([cyl(.17, .24, .38, 8, name="clay"), cyl(.2, .2, .02, 8, (0, 0, .36), "soil")] + stalks), M)
obj_from("Pot_Tipped", merge([lift(rot(cyl(.17, .24, .38, 8, name="clay"), 86, 'X'), .22), box(.5, .3, .02, (0, -.4, .01), .3, "soil")]), M)
obj_from("Newspapers", merge([box(.34, .22, .05, (0, 0, .025 + .05 * i), random.uniform(-.25, .25), "paper") for i in range(3)]), M)
bags = [cyl(.28, .1, .5, 7, (x, y, 0), "plastic") for x, y in ((0, 0), (.45, .1), (.2, .5))]
for b in bags:
    for v in b.verts:
        v.co.x *= 1.0 + .15 * math.sin(v.co.z * 9)
obj_from("TrashBags", merge(bags), M)
can = lift(rot(cyl(.26, .3, .8, 8, name="steel"), 90, 'X'), .3)
obj_from("TrashCan_Tipped", merge([can, cyl(.28, .28, .04, 8, (.8, .25, 0), "steel"), box(.4, .3, .12, (0, -.5, .06), .5, "paper")]), M)
bike = []
for cy_ in (-.5, .5):
    for i in range(12):
        a = 2 * math.pi * i / 12
        seg = box(.03, 2 * math.pi * .32 / 12 * 1.1, .03, (0, 0, 0), 0, "steel")
        rot(seg, math.degrees(a) + 90, 'X')
        bmesh.ops.translate(seg, vec=(0, cy_ + math.cos(a) * .32, .32 + math.sin(a) * .32), verts=seg.verts)
        bike.append(seg)
bike += [box(.035, 1.0, .035, (0, 0, .5), 0, "rust"), box(.035, .5, .035, (0, .2, .62), 0, "rust"),
         box(.3, .035, .035, (0, .55, .78), 0, "steel"), box(.07, .22, .035, (0, -.25, .72), 0, "plastic")]
obj_from("Bike_Fallen", lift(rot(merge(bike), 80, 'Y'), .35), M)
obj_from("PorchLamp", merge([box(.14, .12, .06, (0, 0, 0), 0, "steel"), box(.1, .09, .16, (0, .07, -.02), 0, "glow")]), M)
decal("Grime_Streaks", 1.3, 1.5, 1, True)
decal("Moss_Wall", 1.1, .9, 0, True)
decal("Moss_Flat", 1.2, 1.2, 0, False)
decal("Stain_Flat", 2.2, 2.2, 2, False)

bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_apply=True, export_yup=True)
print("KIT tris", sum(len(o.data.polygons) for o in bpy.data.objects), [o.name for o in bpy.data.objects])
bpy.ops.wm.save_as_mainfile(filepath="tools/source/VEIL_HouseKit.blend")
