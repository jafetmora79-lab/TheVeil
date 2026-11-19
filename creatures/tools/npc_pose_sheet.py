import sys, os
from PIL import Image
root, slug = sys.argv[1], sys.argv[2]
d = os.path.join(root, "creatures/humans/npcs", slug, "work/rig_debug")
names = ["rig_front", "pose_elbows_three", "pose_shoulders_three", "pose_arms_forward_side", "pose_knees_side", "pose_hips_sit_side", "pose_head_close_front", "pose_head_three"]
ims = [Image.open(os.path.join(d, n + ".png")).convert("RGB") for n in names if os.path.exists(os.path.join(d, n + ".png"))]
ims = [im.resize((int(im.width * 420 / im.height), 420)) for im in ims]
W = sum(i.width for i in ims[:4])
s = Image.new("RGB", (max(sum(i.width for i in ims[:4]), sum(i.width for i in ims[4:])), 840), (40, 42, 48))
x = 0
for i in ims[:4]:
    s.paste(i, (x, 0)); x += i.width
x = 0
for i in ims[4:]:
    s.paste(i, (x, 420)); x += i.width
s.save(os.path.join(root, "creatures/humans/npcs", slug, "work/%s_rig_sheet.png" % slug))
