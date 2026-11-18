"""Sarah v3 MESH (independent rebuild; structure and budget learned from studying how a low-poly PS2-era game builds its people - nothing copied):
   ONE clothed body mesh (clothing is the surface itself: boots, sleeves, trousers are shaped by the silhouette and PAINTED), a separate ~200-tri head with an
   unfolded head map, a small ponytail, and the VEIL humanoid rig. Starting geometry: the CC0 DaemonBase female body + head (DaemonOutcast).
   blender -b creatures/humans/pack_daemonbase/extracted/fem.blend -P creatures/tools/build_sarah_v3_mesh.py -- <out.blend>"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

OUT_BLEND = sys.argv[sys.argv.index("--") + 1]
HEIGHT = 1.66
S = HEIGHT / 2.006
Z = lambda z: z * S

body = bpy.data.objects["FemmeBody"]
head = bpy.data.objects["femmehead"]
eyes = bpy.data.objects["eyes"]
lash = bpy.data.objects["lash"]
for o in (head, eyes, lash):
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
bpy.data.objects.remove(eyes)
bpy.data.objects.remove(lash)
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        bpy.data.objects.remove(o)
for o in (body, head):
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    o.data.materials.clear()
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    o.data.transform(Matrix.Scale(S, 4))
    o.data.update()
EL, ER = Vector((-0.029, -0.089, 1.534)), Vector((0.030, -0.089, 1.534))
ez = 1.534


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ======================================================================================================= HEAD (~200 tris, painted face)
bmh = bmesh.new()
bmh.from_mesh(head.data)
bmesh.ops.dissolve_limit(bmh, angle_limit=math.radians(14), verts=list(bmh.verts), edges=list(bmh.edges), delimit={'MATERIAL'})
bmesh.ops.holes_fill(bmh, edges=[e for e in bmh.edges if e.is_boundary], sides=12)
bmh.to_mesh(head.data)
bmh.free()
head.data.update()
bpy.context.view_layer.objects.active = head
dm = head.modifiers.new("simplify", 'DECIMATE')
dm.decimate_type = 'COLLAPSE'
dm.ratio = .5
dm.use_symmetry = True
dm.symmetry_axis = 'X'
bpy.ops.object.modifier_apply(modifier="simplify")
hv0 = head.data.vertices
ymin0 = min(v.co.y for v in hv0)
best = min(hv0, key=lambda v: (v.co.x - 0) ** 2 + (v.co.y - ymin0) ** 2 * .25 + (v.co.z - (ez - .040)) ** 2)
best.co.y -= .014                                                   # the one allowed bit of relief: a low-poly nose wedge
for v in hv0:
    if v != best and (v.co - best.co).length < .022:
        v.co.y -= .005
for v in hv0:
    v.co.x *= 1.0 - .03 * max(0.0, (min(w.co.z for w in hv0) + (max(w.co.z for w in hv0) - min(w.co.z for w in hv0)) * .4 - v.co.z) / ((max(w.co.z for w in hv0) - min(w.co.z for w in hv0)) * .4))
bmh2 = bmesh.new()
bmh2.from_mesh(head.data)
bmesh.ops.remove_doubles(bmh2, verts=list(bmh2.verts), dist=1e-5)
bmesh.ops.dissolve_degenerate(bmh2, dist=1e-5, edges=list(bmh2.edges))
bmesh.ops.recalc_face_normals(bmh2, faces=list(bmh2.faces))
bmh2.to_mesh(head.data)
bmh2.free()
head.data.update()
hb = np.array([v.co[:] for v in head.data.vertices])
hxmin_all, hxmax_all = hb[:, 0].min(), hb[:, 0].max()
hzmin, hzmax = hb[:, 2].min(), hb[:, 2].max()
hymin, hymax = hb[:, 1].min(), hb[:, 1].max()


def classify_uv(poly):
    n = poly.normal
    if n.y < -.45:
        return "front"
    if abs(n.x) > .5:
        return "left" if poly.center.x < 0 else "right"
    if n.y > .30:
        return "back"
    if abs(n.z) > .5:
        return "top" if n.z > 0 else "under"
    return "front" if n.y < -.15 else ("left" if poly.center.x < 0 else "right")


face_polys = [pl for pl in head.data.polygons if classify_uv(pl) == "front"]
fx = np.array([head.data.vertices[i].co.x for pl in face_polys for i in pl.vertices])
hxmin, hxmax = float(fx.min()), float(fx.max())
FZ_BROW = ez + .047
huv = head.data.uv_layers.active if head.data.uv_layers else head.data.uv_layers.new(name="UVMap")
head["uv_front"] = [hxmin, hxmax, float(hzmin), float(FZ_BROW), float(hzmax)]
head["uv_layout"] = "front u0-.62 | left u.64-.82 v.5-1 | right u.82-1 v.5-1 (mirrored) | back u.64-.88 v0-.5 | top u.88-1 v.27-.49 | under u.88-1 v.02-.24"
for poly in head.data.polygons:
    kind = classify_uv(poly)
    for li in poly.loop_indices:
        co = head.data.vertices[head.data.loops[li].vertex_index].co
        t = (co.y - hymin) / (hymax - hymin)
        zz = (co.z - hzmin) / (hzmax - hzmin)
        xx = (co.x - hxmin_all) / (hxmax_all - hxmin_all)
        if kind == "front":
            v = .80 * (co.z - hzmin) / (FZ_BROW - hzmin) if co.z <= FZ_BROW else .80 + .20 * (co.z - FZ_BROW) / (hzmax - FZ_BROW)
            uvv = (min(.62, max(0.0, (co.x - hxmin) / (hxmax - hxmin) * .62)), min(1.0, max(0.0, v)))
        elif kind == "left":
            uvv = (.64 + (1 - t) * .18, .50 + zz * .50)
        elif kind == "right":
            uvv = (1.0 - (1 - t) * .18, .50 + zz * .50)
        elif kind == "back":
            uvv = (.64 + xx * .24, zz * .50)
        elif kind == "top":
            uvv = (.88 + xx * .11, .27 + (1 - t) * .22)
        else:
            uvv = (.88 + xx * .11, .02 + t * .22)
        huv.data[li].uv = uvv
for p in head.data.polygons:
    p.use_smooth = False
print("HEAD tris", tris(head))

# ======================================================================================================= BODY: one clothed surface
bb = body.data
for v in bb.vertices:
    z = v.co.z
    # boots: thicker ankles and feet below the shin
    if z < Z(.30):
        f = 1.0 + .17 * (1 - z / Z(.30)) ** .6
        cx = .10 if v.co.x > 0 else -.10
        v.co.x = cx + (v.co.x - cx) * f
        v.co.y = -.01 + (v.co.y + .01) * f
    # trousers a little fuller between ankle and hip
    elif z < Z(.85):
        f = 1.0 + .05 * math.sin(math.pi * (z - Z(.30)) / (Z(.85) - Z(.30)))
        cx = .095 if v.co.x > 0 else -.095
        v.co.x = cx + (v.co.x - cx) * f
        v.co.y = -.005 + (v.co.y + .005) * f
bb.update()
bpy.context.view_layer.objects.active = body
body.name = "Sarah_Body"
if not bb.uv_layers:
    bb.uv_layers.new(name="UVMap")
body.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
bpy.ops.uv.pack_islands(margin=0.012)
bpy.ops.object.mode_set(mode='OBJECT')
for p in bb.polygons:
    p.use_smooth = False
print("BODY tris", tris(body))

# ======================================================================================================= ponytail (small, own UVs)
bs = bmesh.new()
uvs = bs.loops.layers.uv.verify()


def tube(b2, pts, radii, sides=7, flat=1.0, cap_end=True):
    pts = [Vector(p) for p in pts]
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = t.cross(Vector((1, 0, 0))) if abs(t.x) < .9 else t.cross(Vector((0, 1, 0)))
        n.normalize()
        bn = t.cross(n).normalized()
        rings.append([b2.verts.new(p + (n * math.cos(2 * math.pi * k / sides) + bn * math.sin(2 * math.pi * k / sides) * flat) * r) for k in range(sides)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            f = b2.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
            for lp, (u, v) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                lp[uvs].uv = (u / sides * .9, v / (len(rings) - 1))
    if cap_end:
        c = b2.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * .7)
        for k in range(sides):
            f = b2.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], c))
            for lp in f.loops:
                lp[uvs].uv = (.95, 1.0)


cxh = (hxmin_all + hxmax_all) / 2
root = Vector((cxh, hymax - .03, hzmax - (hzmax - hzmin) * .34))
tube(bs, [root, root + Vector((0, .05, -.03)), root + Vector((0, .085, -.12)), root + Vector((.005, .09, -.24)), root + Vector((0, .075, -.36)), root + Vector((-.012, .06, -.46))],
     [.03, .045, .048, .04, .028, .012], 7, .85)
tube(bs, [root + Vector((0, .035, -.01)), root + Vector((0, .04, -.025))], [.036, .036], 8, 1.0)
hm = bpy.data.meshes.new("Hair")
bs.to_mesh(hm)
bs.free()
hair = bpy.data.objects.new("Sarah_Hair", hm)
bpy.context.scene.collection.objects.link(hair)
head.name = "Sarah_Head"

# ======================================================================================================= rig (VEIL humanoid names, A-pose) + weights
hip_x = .085
J = {"Hips": Vector((0, -.01, Z(.86))), "Spine": Vector((0, -.01, Z(1.02))), "Chest": Vector((0, -.02, Z(1.20))), "UpperChest": Vector((0, -.02, Z(1.32))),
     "Neck": Vector((0, -.02, Z(1.52))), "Head": Vector((0, -.01, Z(1.70)))}
for side, sx in (("Left", -1), ("Right", 1)):
    J[side + "Shoulder"] = Vector((sx * .035, -.02, Z(1.455)))
    J[side + "UpperArm"] = Vector((sx * Z(.275), -.01, Z(1.42)))
    J[side + "LowerArm"] = Vector((sx * Z(.335), .0, Z(1.24)))
    J[side + "Hand"] = Vector((sx * Z(.40), .005, Z(1.10)))
    J[side + "UpperLeg"] = Vector((sx * hip_x, 0, Z(.84)))
    J[side + "LowerLeg"] = Vector((sx * (hip_x + .01), -.005, Z(.50)))
    J[side + "Foot"] = Vector((sx * (hip_x + .02), 0, Z(.075)))
    J[side + "Toes"] = Vector((sx * (hip_x + .025), -.115, Z(.03)))
TIP_HAND = {s: J[s + "Hand"] + Vector((sx * Z(.035), 0, -Z(.12))) for s, sx in (("Left", -1), ("Right", 1))}
CH = {"Hips": "Spine", "Spine": "Chest", "Chest": "UpperChest", "UpperChest": "Neck", "Neck": "Head"}
PARENT = {"Spine": "Hips", "Chest": "Spine", "UpperChest": "Chest", "Neck": "UpperChest", "Head": "Neck"}
for side in ("Left", "Right"):
    PARENT.update({side + "Shoulder": "UpperChest", side + "UpperArm": side + "Shoulder", side + "LowerArm": side + "UpperArm", side + "Hand": side + "LowerArm",
                   side + "UpperLeg": "Hips", side + "LowerLeg": side + "UpperLeg", side + "Foot": side + "LowerLeg", side + "Toes": side + "Foot"})
    CH.update({side + "Shoulder": side + "UpperArm", side + "UpperArm": side + "LowerArm", side + "LowerArm": side + "Hand", side + "UpperLeg": side + "LowerLeg",
               side + "LowerLeg": side + "Foot", side + "Foot": side + "Toes"})
arm_d = bpy.data.armatures.new("Sarah_Rig")
rig = bpy.data.objects.new("Sarah_Rig", arm_d)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h in J.items():
    eb = arm_d.edit_bones.new(name)
    eb.head = h
    if name in CH:
        eb.tail = J[CH[name]]
    elif name.endswith("Hand"):
        eb.tail = TIP_HAND[name[:-4]]
    elif name == "Head":
        eb.tail = h + Vector((0, 0, Z(.2)))
    else:
        eb.tail = h + Vector((0, -.08, 0))
    if (eb.tail - eb.head).length < .02:
        eb.tail = eb.head + Vector((0, 0, .03))
for name, par in PARENT.items():
    arm_d.edit_bones[name].parent = arm_d.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
SEG = {}
for name in J:
    a = J[name]
    b = J[CH[name]] if name in CH else (TIP_HAND[name[:-4]] if name.endswith("Hand") else (a + Vector((0, 0, Z(.2))) if name == "Head" else a + Vector((0, -.1, 0))))
    SEG[name] = (np.array(a[:]), np.array(b[:]))


def d2seg(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def weight_mesh(ob, exponent=3.0):
    P = np.array([v.co[:] for v in ob.data.vertices])
    names = list(SEG)
    D = np.stack([d2seg(P, *SEG[n]) for n in names], axis=1)
    order = np.argsort(D, axis=1)[:, :3]
    W = np.zeros_like(D)
    for i in range(len(P)):
        ds = D[i, order[i]]
        w = 1.0 / (ds ** exponent + 1e-4)
        W[i, order[i]] = w / w.sum()
    W[W < .05] = 0
    W /= W.sum(axis=1, keepdims=True)
    for n in names:
        ob.vertex_groups.new(name=n)
    for j, n in enumerate(names):
        vg = ob.vertex_groups[n]
        for i in np.nonzero(W[:, j] > 0)[0]:
            vg.add([int(i)], float(W[i, j]), 'REPLACE')


weight_mesh(body, 3.0)
for ob in (head, hair):
    for n in J:
        ob.vertex_groups.new(name=n)
    ob.vertex_groups["Head"].add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
for ob in (body, head, hair):
    ob.parent = rig
    md = ob.modifiers.new("Armature", 'ARMATURE')
    md.object = rig
print("SKELETON bones", len(arm_d.bones), "total tris", sum(tris(o) for o in (body, head, hair)))
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT_BLEND))
print("MESH v3 saved")
