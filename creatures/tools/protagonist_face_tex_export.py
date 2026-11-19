"""Export the protagonist with the face-texture material (second material slot) as a GLB for the Godot check.
   blender -b -P protagonist_face_tex_export.py -- <repo_root>"""
import bpy, sys, os
root = sys.argv[sys.argv.index("--") + 1]
base = os.path.join(root, "creatures/humans/protagonist/face_geo")
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "protagonist_face_texture_swap.blend"))
body = bpy.data.objects["Protagonist_Meshy_Body"]
rig = bpy.data.objects["Protagonist_Meshy_Rig"]
mat = body.data.materials[1]
for nd in mat.node_tree.nodes:
    if nd.type == 'TEX_IMAGE':
        nd.image = bpy.data.images.load(os.path.join(base, "tex/face_neutral.png"))
        nd.interpolation = "Closest"
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(base, "CHR_Protagonist_FaceTex.glb"), export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_yup=True, export_apply=False)
print("EXPORTED", os.path.getsize(os.path.join(base, "CHR_Protagonist_FaceTex.glb")))
