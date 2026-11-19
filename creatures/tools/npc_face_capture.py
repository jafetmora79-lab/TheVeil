"""Flat, unlit, front orthographic capture of an NPC's face from its own texture (the base image for the expression kit).
   blender -b -P npc_face_capture.py -- <repo_root> <slug> <height_m>"""
import bpy, os, sys, math, json
root, slug, height = sys.argv[sys.argv.index("--") + 1:][:3]
height = float(height)
base = os.path.join(root, "creatures/humans/npcs", slug)
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "game_ready/npc_meshy.blend"))
body = bpy.data.objects["NPC_Meshy_Body"]
rig = bpy.data.objects["NPC_Meshy_Rig"]
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
img = None
for nd in body.data.materials[0].node_tree.nodes:
    if nd.type == 'TEX_IMAGE':
        img = nd.image
m = bpy.data.materials.new("flat")
m.use_nodes = True
nt = m.node_tree
nt.nodes.clear()
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
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
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
sc.world = w
# per-character vertical offset so the eyes sit at the centre of the frame (measured from a first capture), frame a little wider for big hair
SHIFT = {"eddie": 0.0256, "plaid_shirt": 0.0056, "police_officer": 0.016, "teen_blue_jacket": -0.0336, "bearded_man": 0.0056, "police_cap": -0.028,
         "elderly_woman": -0.0096, "police_redhair": -0.0096, "store_clerk": -0.0096}
RES, CX, CZ, SIZE = 1000, 0.0, height * 0.899 + SHIFT.get(slug, 0.0), 0.27
cam = bpy.data.cameras.new("c")
cam.type = 'ORTHO'
cam.ortho_scale = SIZE
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
sc.render.resolution_x = sc.render.resolution_y = RES
co.location = (CX, 5.0, CZ)
co.rotation_euler = (math.pi / 2, 0, math.pi)
os.makedirs(os.path.join(base, "work/face"), exist_ok=True)
sc.render.filepath = os.path.join(base, "work/face/face_flat.png")
bpy.ops.render.render(write_still=True)
json.dump({"res": RES, "cx": CX, "cz": CZ, "size": SIZE}, open(os.path.join(base, "work/face/face_capture.json"), "w"), indent=1)
print("CAPTURED", slug)
