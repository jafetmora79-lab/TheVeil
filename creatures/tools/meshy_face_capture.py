"""Stage A of the face expressions: a flat, unlit, front orthographic capture of Sarah's face from the 512 PSX texture (the exact
texels the game shows), plus ray-cast helpers. The decal expressions are painted from this image so they match her face exactly.
   blender -b -P meshy_face_capture.py -- <repo_root>"""
import bpy, os, sys, math, json
import numpy as np
from mathutils import Vector

root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/sarah_meshy")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/sarah_meshy_proto.blend"))
body = bpy.data.objects["Sarah_Meshy_Body"]
rig = bpy.data.objects["Sarah_Meshy_Rig"]
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
bpy.context.view_layer.update()
# emission material from the same image (unlit, nearest)
m = bpy.data.materials.new("flat")
m.use_nodes = True
nt = m.node_tree
nt.nodes.clear()
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(os.path.join(base, "work/textures/material_0_diffuse_512_nearest.png"))
tex.interpolation = "Closest"
em = nt.nodes.new("ShaderNodeEmission")
out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(tex.outputs["Color"], em.inputs["Color"])
nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
body.data.materials.clear()
body.data.materials.append(m)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
sc.render.film_transparent = False
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
sc.world = w
RES = 1000
CX, CZ, SIZE = 0.0, 1.53, 0.20
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = SIZE
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
sc.render.resolution_x = sc.render.resolution_y = RES
co.location = (CX, 5.0, CZ)
co.rotation_euler = (math.pi / 2, 0, math.pi)             # at +Y looking toward -Y (the face is on +Y); screen right = -X
sc.render.filepath = os.path.join(base, "work/face/face_flat.png")
bpy.ops.render.render(write_still=True)
json.dump({"res": RES, "cx": CX, "cz": CZ, "size": SIZE, "note": "pixel u = (CX - X)/SIZE*RES + RES/2 ; pixel v(from top) = RES/2 - (Z - CZ)/SIZE*RES"},
          open(os.path.join(base, "work/face/face_capture.json"), "w"), indent=1)
print("CAPTURED")
