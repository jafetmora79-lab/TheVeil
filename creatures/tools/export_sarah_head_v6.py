"""Export the painted head v6 (head + hair cap + ponytail) as a GLB with its textures (head only; the playable Sarah is untouched).
   blender -b head_v6.blend -P export_sarah_head_v6.py -- <out.glb>"""
import bpy, sys, os
out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(o.type == 'MESH')
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_image_format='AUTO', export_yup=True)
print("EXPORTED", out)
