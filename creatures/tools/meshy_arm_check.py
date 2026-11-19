"""Sagittal elbow / wrist bend over every key frame of every action (positive = forward, toward the front, +Y in Blender).
   blender -b -P meshy_arm_check.py -- <repo_root>"""
import bpy, os, sys, math
root = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.open_mainfile(filepath=os.path.join(root, "creatures/humans/sarah_meshy/game_ready/sarah_meshy_proto.blend"))
rig = bpy.data.objects["Sarah_Meshy_Rig"]
sc = bpy.context.scene


def ang(v):
    return math.degrees(math.atan2(v.y, -v.z))            # from straight down, forward (+Y) positive


for act in sorted(bpy.data.actions, key=lambda a: a.name):
    if act.name.startswith("hand_"):
        continue
    rig.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    res = {}
    for f in range(f0, f1 + 1, max(1, (f1 - f0) // 12)):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        for side in ("Left", "Right"):
            ua = rig.pose.bones[side + "UpperArm"]
            la = rig.pose.bones[side + "LowerArm"]
            ha = rig.pose.bones[side + "Hand"]
            u = (rig.matrix_world @ ua.tail) - (rig.matrix_world @ ua.head)
            fo = (rig.matrix_world @ la.tail) - (rig.matrix_world @ la.head)
            h = (rig.matrix_world @ ha.tail) - (rig.matrix_world @ ha.head)
            elbow = ang(fo) - ang(u)
            wrist = ang(h) - ang(fo)
            r = res.setdefault(side, {"e": [], "w": []})
            r["e"].append(elbow)
            r["w"].append(wrist)
    for side, r in res.items():
        print("ARM %-22s %-5s elbow flex %6.1f..%6.1f   wrist flex %6.1f..%6.1f" % (act.name, side, min(r["e"]), max(r["e"]), min(r["w"]), max(r["w"])))
