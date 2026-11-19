"""Visual validation render for head v8b: unchanged geometry, flat skin material, soft directional lighting, optional TEMPORARY untextured hairstyle
(side-swept bangs, crown volume, ponytail) in dark grey.  The hair is built here at render time only; head_v8b.blend is not modified.
   blender -b head_v8b.blend -P render_v8b_validation.py -- <out.png> <hair 0/1>"""
import bpy, bmesh, sys, os, math, random
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out, with_hair = a[0], a[1] == "1"
head = bpy.data.objects["Sarah_Head_v8"]


def mat(name, col, rough=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = rough
    return m


skin = mat("skin", (.80, .60, .50, 1))
hairm = mat("hair", (.17, .17, .19, 1))
body_m = mat("body", (.42, .43, .47, 1))
head.data.materials.clear()
head.data.materials.append(skin)

# ---------------------------------------------------------------- neck / shoulders context (appended read-only from the v3 body)
path = os.path.abspath("creatures/humans/sarah/CHR_Sarah_v3.blend")
with bpy.data.libraries.load(path, link=False) as (src, dst):
    dst.objects = ["Sarah_Body"]
for ob in dst.objects:
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = None
    for md in list(ob.modifiers):
        ob.modifiers.remove(md)
    ob.data.materials.clear()
    ob.data.materials.append(body_m)
    b = bmesh.new()
    b.from_mesh(ob.data)
    bmesh.ops.delete(b, geom=[f for f in b.faces if max(v.co.z for v in f.verts) < 1.12], context='FACES')
    b.to_mesh(ob.data)
    b.free()

# ---------------------------------------------------------------- temporary hair
if with_hair:
    hm = bmesh.new()
    hm.from_mesh(head.data)
    keep = []
    for f in hm.faces:
        c = f.calc_center_median()
        if abs(c.x) > .062 and -.012 < c.y < .045 and 1.52 < c.z < 1.60:
            continue                                                       # leave the ears free
        if c.y > .062 or c.z < 1.50:
            if not (c.y > .0 and c.z > 1.50):
                continue
        # hairline: high on the parting side (+x), dropping into side-swept bangs towards -x, sideburns at the temples
        line = 1.602 - .040 * max(-1.0, min(1.0, -c.x / .06))
        if c.y < -.02 and c.z < line:
            continue
        if abs(c.x) > .064 and c.z < 1.548:
            continue
        if c.y > .0 and c.z < 1.515:
            continue
        keep.append(f)
    hg = bmesh.new()
    vm = {}
    for f in keep:
        vs = []
        for v in f.verts:
            if v.index not in vm:
                n = v.normal.copy()
                d = .019 + .012 * max(0.0, min(1.0, (v.co.z - 1.57) / .08))     # volume that grows towards the crown
                if v.co.y < -.04 and v.co.z < 1.62:
                    d = .012                                                       # thinner fringe
                p = v.co + n * d
                if v.co.y < -.04 and v.co.z < 1.61:
                    p.x += -.004                                                    # fringe swept sideways
                vm[v.index] = hg.verts.new(p)
            vs.append(vm[v.index])
        hg.faces.new(vs)
    bmesh.ops.recalc_face_normals(hg, faces=list(hg.faces))
    hmesh = bpy.data.meshes.new("TempHair")
    hg.to_mesh(hmesh)
    hg.free()
    hm.free()
    hair = bpy.data.objects.new("TempHair", hmesh)
    bpy.context.scene.collection.objects.link(hair)
    # crown tuft
    tb = bmesh.new()
    tip = tb.verts.new((.006, -.020, 1.712))
    base = [tb.verts.new((.020 * math.cos(t) + .004, .020 * math.sin(t) - .012, 1.655)) for t in np.linspace(0, 2 * math.pi, 7)[:-1]]
    for i in range(6):
        tb.faces.new((base[i], base[(i + 1) % 6], tip))
    bmesh.ops.recalc_face_normals(tb, faces=list(tb.faces))
    tm = bpy.data.meshes.new("TempHairTuft")
    tb.to_mesh(tm)
    tb.free()
    tuft = bpy.data.objects.new("TempHairTuft", tm)
    bpy.context.scene.collection.objects.link(tuft)
    # ponytail
    random.seed(3)
    pts = [(0, .086, 1.590), (0, .126, 1.545), (0, .154, 1.470), (0, .160, 1.390), (0, .152, 1.300), (0, .142, 1.215), (0, .132, 1.150)]
    rx = [.030, .040, .042, .037, .030, .020, .005]
    ry = [.024, .030, .032, .028, .023, .016, .005]
    pb = bmesh.new()
    rings = []
    for i, ((px, py, pz), x_, y_) in enumerate(zip(pts, rx, ry)):
        row = []
        for k in range(6):
            t = 2 * math.pi * k / 6 + (.25 if i % 2 else 0)
            j = 1 + random.uniform(-.07, .07)
            row.append(pb.verts.new((px + math.cos(t) * x_ * j, py + math.sin(t) * y_ * j, pz)))
        rings.append(row)
    for i in range(len(rings) - 1):
        for k in range(6):
            pb.faces.new((rings[i][k], rings[i][(k + 1) % 6], rings[i + 1][(k + 1) % 6], rings[i + 1][k]))
    pb.faces.new(rings[0][::-1])
    bmesh.ops.recalc_face_normals(pb, faces=list(pb.faces))
    pm = bpy.data.meshes.new("TempPony")
    pb.to_mesh(pm)
    pb.free()
    pony = bpy.data.objects.new("TempPony", pm)
    bpy.context.scene.collection.objects.link(pony)
    for o in (hair, tuft, pony):
        o.data.materials.append(hairm)
        for p in o.data.polygons:
            p.use_smooth = False
    tris = sum(len(p.vertices) - 2 for o in (hair, tuft, pony) for p in o.data.polygons)
    print("TEMP HAIR tris", tris)

# ---------------------------------------------------------------- soft directional lighting
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.36, .37, .41, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = .55
bpy.context.scene.world = w
for rot, en, ang in (((48, 0, -38), 3.4, .35), ((70, 0, 140), 1.0, .5), ((105, 0, 205), 1.6, .3)):
    bpy.ops.object.light_add(type='SUN')
    L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot]
    L.data.energy = en
    L.data.angle = ang
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
sc.eevee.use_shadows = True
sc.render.resolution_x = sc.render.resolution_y = 520
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = .42
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
ctr = Vector((0, -.02, 1.52))
tiles = []
for name, az in (("front", 0), ("three", 38), ("side", 90)):
    t = math.radians(az)
    co.location = (ctr.x + 6 * math.sin(t), ctr.y - 6 * math.cos(t), ctr.z)
    co.rotation_euler = (math.pi / 2, 0, t)
    p = os.path.abspath(out.replace(".png", "_" + name + ".png"))
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    tiles.append(p)
ims = [bpy.data.images.load(p) for p in tiles]
arr = np.concatenate([np.array(i.pixels[:], dtype=np.float32).reshape(520, 520, 4) for i in ims], axis=1)
sh = bpy.data.images.new("s", 520 * len(ims), 520)
sh.pixels[:] = arr.reshape(-1)
sh.filepath_raw = os.path.abspath(out)
sh.file_format = 'PNG'
sh.save()
for p in tiles:
    os.remove(p)
