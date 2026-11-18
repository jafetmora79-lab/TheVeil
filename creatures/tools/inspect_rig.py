import bpy, sys, os
glb = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(glb))
for o in bpy.data.objects:
    print("OBJ", o.type, o.name, "parent=", o.parent.name if o.parent else None, "loc", tuple(round(v,2) for v in o.location), "scale", tuple(round(v,2) for v in o.scale),
          "tris", len(o.data.polygons) if o.type=='MESH' else "", "verts", len(o.data.vertices) if o.type=='MESH' else "", "vgroups", len(o.vertex_groups) if o.type=='MESH' else "")
for a in bpy.data.objects:
    if a.type == 'ARMATURE':
        for b in a.data.bones:
            print("BONE", b.name, "parent", b.parent.name if b.parent else None, "head", tuple(round(v,2) for v in b.head_local), "tail", tuple(round(v,2) for v in b.tail_local))
for act in bpy.data.actions:
    print("ACT", act.name, tuple(round(v,2) for v in act.frame_range), "fcurves", len(act.fcurves) if hasattr(act, "fcurves") else "?")
print("MATS", [m.name for m in bpy.data.materials], "IMGS", [(i.name, i.size[:]) for i in bpy.data.images])
