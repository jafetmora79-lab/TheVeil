"""Read-only 'before' lineup of THE VEIL cast and creatures (imports GLBs from THE_VEIL_ASSETS_V2, never writes there).
blender -b -P refine/tools/preview_lineup.py -- <group: cast|creatures> <out.png>"""
import bpy, sys, os, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
group, out = argv[0], argv[1]
A = "THE_VEIL_ASSETS_V2/"
SETS = {
 "cast": ["06_Characters/Protagonist/CHR_Protagonist", "06_Characters/Commercial_NPCs/CHR_Eddie", "06_Characters/Marcus/CHR_Marcus",
          "06_Characters/Civilians/CHR_Ruth", "06_Characters/Civilians/CHR_Sarah", "06_Characters/Commercial_NPCs/CHR_Frank",
          "06_Characters/Civilians/CHR_Lena", "06_Characters/Police/CHR_Police_Officer", "06_Characters/Commercial_NPCs/CHR_Cashier"],
 "creatures": ["07_Creatures/Hounds/CRT_Hound", "07_Creatures/Skitter/CRT_Skitter", "07_Creatures/Shellcrawler/CRT_Shellcrawler", "07_Creatures/Colossus/CRT_Colossus"],
}
bpy.ops.wm.read_factory_settings(use_empty=True)
x = 0.0; maxh = 0.0; boxes = []
for p in SETS[group]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(A + p + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == 'MESH']
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(v.x for v in pts), min(v.y for v in pts), min(v.z for v in pts)))
    hi = Vector((max(v.x for v in pts), max(v.y for v in pts), max(v.z for v in pts)))
    w = max(hi.x - lo.x, hi.y - lo.y)
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.location.x += x - (lo.x + hi.x) / 2; r.location.y += -(lo.y + hi.y) / 2; r.location.z += -lo.z
    x += w + 0.6; maxh = max(maxh, hi.z - lo.z)
    print(p, "tris", sum(len(o.data.polygons) for o in meshes), "h", round(hi.z - lo.z, 2))
total = x
bpy.ops.object.light_add(type='SUN', location=(0, -5, 8)); bpy.context.object.data.energy = 3; bpy.context.object.rotation_euler = (0.9, 0.2, 0.5)
w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.38, 0.45, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bpy.context.scene.world = w
bpy.ops.mesh.primitive_plane_add(size=200, location=(total / 2, 0, 0)); g = bpy.context.object
m = bpy.data.materials.new("g"); m.diffuse_color = (0.18, 0.19, 0.2, 1); g.data.materials.append(m)
cam = bpy.data.cameras.new("c"); cam.type = 'ORTHO'; cam.ortho_scale = max(total, maxh * 1.8)
co = bpy.data.objects.new("c", cam); bpy.context.scene.collection.objects.link(co)
co.location = (total / 2 - 0.3, -30, maxh / 2); co.rotation_euler = (math.pi / 2, 0, 0); bpy.context.scene.camera = co
sc = bpy.context.scene; sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in sc.render.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
sc.render.resolution_x = 1800; sc.render.resolution_y = int(1800 * (maxh * 1.3) / max(total, 1)) + 100
sc.render.filepath = os.path.abspath(out); bpy.ops.render.render(write_still=True)
