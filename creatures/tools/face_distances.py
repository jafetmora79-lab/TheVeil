"""Face acceptance test: close-up portrait / conversation distance / typical in-game NPC distance, restrained flat lighting so the texture is judged, not the shading.
blender -b file.blend -P face_distances.py -- out.png"""
import bpy, math, os, sys
import numpy as np
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
for o in list(bpy.data.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o)
head = bpy.data.objects["Sarah_Head"]
hc = Vector((0, -.03, 1.53))
w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (.55, .56, .6, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0; bpy.context.scene.world = w
bpy.ops.object.light_add(type='SUN'); L = bpy.context.object; L.rotation_euler = (math.radians(55), 0, math.radians(-25)); L.data.energy = 1.2
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.view_settings.view_transform = 'Standard'
cam = bpy.data.cameras.new("c"); co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co


def shot(name, dist, fov, res, crop=None, ortho=None):
    if ortho:
        cam.type = 'ORTHO'; cam.ortho_scale = ortho
    else:
        cam.type = 'PERSP'; cam.angle = math.radians(fov)
    co.location = (hc.x, hc.y - dist, hc.z); co.rotation_euler = (math.pi / 2, 0, 0)
    sc.render.resolution_x, sc.render.resolution_y = res
    p = os.path.abspath(out.replace(".png", "_" + name + ".png")); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); a = np.array(im.pixels[:], dtype=np.float32).reshape(res[1], res[0], 4); os.remove(p)
    if crop:
        cx, cy, cw, ch = crop; a = a[cy:cy + ch, cx:cx + cw]
    return a


A = shot("close", 6, 0, (480, 480), ortho=.27)
B = shot("conv", 1.6, 40, (480, 480))
C0 = shot("game", 5.0, 60, (960, 540), crop=(380, 170, 200, 200))        # native pixels at 960x540, a head about 40 px tall
C = np.kron(C0, np.ones((2, 2, 1), dtype=np.float32))[:480, :480] if C0.shape[0] <= 240 else C0
C = np.kron(C0, np.ones((2, 2, 1), dtype=np.float32))
C = np.pad(C, ((0, 480 - C.shape[0]), (0, 480 - C.shape[1]), (0, 0)))
sheet = np.concatenate([A, B, C], axis=1)
im = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0]); im.pixels[:] = sheet.reshape(-1); im.filepath_raw = os.path.abspath(out); im.file_format = 'PNG'; im.save()
