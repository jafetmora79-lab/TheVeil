"""Rough, untextured chin-length bob for the V8c head (render-time only; head_v8c.blend is not modified).
Side-swept bangs (low on the viewer's right), rounded volume, ears covered, ends at the chin.
   blender -b head_v8c.blend -P render_v8c_bob.py -- <out.png>"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
head = bpy.data.objects["Sarah_Head_v8"]


def mat(name, col):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = 1.0
    return m


skin, hairm, bodym = mat("skin", (.80, .60, .50, 1)), mat("hair", (.20, .16, .14, 1)), mat("body", (.30, .31, .35, 1))
head.data.materials.clear()
head.data.materials.append(skin)

path = os.path.abspath("creatures/humans/sarah/CHR_Sarah_v3.blend")
with bpy.data.libraries.load(path, link=False) as (src, dst):
    dst.objects = ["Sarah_Body"]
for ob in dst.objects:
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = None
    for md in list(ob.modifiers):
        ob.modifiers.remove(md)
    ob.data.materials.clear()
    ob.data.materials.append(bodym)
    b = bmesh.new()
    b.from_mesh(ob.data)
    bmesh.ops.delete(b, geom=[f for f in b.faces if max(v.co.z for v in f.verts) < 1.12], context='FACES')
    b.to_mesh(ob.data)
    b.free()

# ------------------------------------------------------------------ bob: lofted shell, z / half width / front / back
B = np.array([
    [1.694, .000, .000, .000],
    [1.686, .036, .038, .046],
    [1.672, .064, .068, .078],
    [1.654, .086, .090, .100],
    [1.632, .097, .100, .108],
    [1.610, .106, .107, .115],
    [1.580, .109, .107, .119],
    [1.550, .108, .102, .121],
    [1.520, .103, .094, .120],
    [1.490, .096, .084, .113],
    [1.462, .087, .072, .102],
    [1.446, .078, .062, .092],
])
NS = 30
zr = B[:, 0]
bm = bmesh.new()
rows = []
for r in B:
    z, hw, f, bk = r
    row = []
    for k in range(NS):
        t = 2 * math.pi * k / NS
        s, c = math.sin(t), math.cos(t)
        if hw < 1e-6:
            row.append(bm.verts.new((0, 0, z)))
            continue
        d = f if c >= 0 else bk
        n = 2.5
        rr = 1.0 / ((abs(s) / hw) ** n + (abs(c) / d) ** n) ** (1.0 / n)
        row.append(bm.verts.new((rr * s, -rr * c, z)))
    rows.append(row)
for i in range(len(rows) - 1):
    for k in range(NS):
        k2 = (k + 1) % NS
        if i == 0:
            bm.faces.new((rows[0][0], rows[1][k2], rows[1][k]))
        else:
            bm.faces.new((rows[i][k], rows[i][k2], rows[i + 1][k2], rows[i + 1][k]))
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
# open the face: bangs fall diagonally (lower on the viewer's right), hair frames the face at the sides
keep = []
for f in bm.faces:
    c = f.calc_center_median()
    if c.y < -.045:
        line = 1.592 - .024 * max(-1.0, min(1.0, c.x / .055))
        if abs(c.x) < .092 and c.z < line:
            continue                                                             # the face window
    keep.append(f)
drop = [f for f in bm.faces if f not in keep]
bmesh.ops.delete(bm, geom=drop, context='FACES_ONLY')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
me = bpy.data.meshes.new("TempBob")
bm.to_mesh(me)
bm.free()
bob = bpy.data.objects.new("TempBob", me)
bpy.context.scene.collection.objects.link(bob)
bob.data.materials.append(hairm)
for p in me.polygons:
    p.use_smooth = False
print("BOB tris", sum(len(p.vertices) - 2 for p in me.polygons))

# ------------------------------------------------------------------ lighting + cameras (same soft directional setup as the validation renders)
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.10, .10, .11, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = .6
bpy.context.scene.world = w
for rot, en, ang in (((48, 0, -38), 3.2, .35), ((70, 0, 140), 1.0, .5), ((105, 0, 205), 1.4, .3)):
    bpy.ops.object.light_add(type='SUN')
    L = bpy.context.object
    L.rotation_euler = [math.radians(x) for x in rot]
    L.data.energy = en
    L.data.angle = ang
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = 700
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = .40
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
ctr = Vector((0, -.02, 1.52))
for name, az in (("front", 0), ("three", 38), ("side", 90)):
    t = math.radians(az)
    co.location = (ctr.x + 6 * math.sin(t), ctr.y - 6 * math.cos(t), ctr.z)
    co.rotation_euler = (math.pi / 2, 0, t)
    sc.render.filepath = os.path.abspath(out.replace(".png", "_" + name + ".png"))
    bpy.ops.render.render(write_still=True)
