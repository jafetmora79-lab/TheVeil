"""THE VEIL cinematics - one Blender scene per ledger sequence (Blender 5.x, headless). NO RENDERS.
   blender -b -P docs/cinematics/blender/build_sequences.py -- <repo_root>
Reads docs/cinematics/data/shots.json (built by tools/build_ledger.py). For every row: a Scene named after the sequence id with the modular collections (Site, Cast, Creature, FX, Cameras), a camera
whose lens (vertical FOV) is keyed per shot, and a timeline marker per shot at its start frame (24 fps). Shots the code fixes in seconds use those; player-paced shots get a 4 s placeholder and
are marked "(paced)". The camera PATHS are not authored here (they are first-person and player-driven); only timing, lens and the marker structure, so a Godot reference-scene comparison has a
frame ledger to compare against. Pilot C03.02b has its full replay in C03_02b_pilot.blend. Writes docs/cinematics/blender/sequences_all.blend and data/sequence_timelines.json."""
import bpy, sys, os, json, math

root = sys.argv[sys.argv.index("--") + 1]
rows = json.load(open(os.path.join(root, "docs/cinematics/data/shots.json"), encoding="utf-8"))
FPS = 24
PACED = 4.0
bpy.ops.wm.read_factory_settings(use_empty=True)
base = bpy.context.scene
out = {}
first = True
for r in rows:
    sc = base if first else bpy.data.scenes.new(r["id"])
    sc.name = r["id"]
    first = False
    sc.render.fps = FPS
    for cname in ("Site", "Cast", "Creature", "FX", "Cameras"):
        c = bpy.data.collections.new("%s.%s" % (r["id"], cname))
        sc.collection.children.link(c)
    cams = bpy.data.collections["%s.Cameras" % r["id"]]
    cd = bpy.data.cameras.new("Cam." + r["id"])
    cd.sensor_fit = 'VERTICAL'
    cd.sensor_height = 24.0
    cam = bpy.data.objects.new("Cam." + r["id"], cd)
    cams.objects.link(cam)
    sc.camera = cam
    frame = 0
    shots = []
    for s in r["shots"]:
        paced = s["seconds"] is None
        secs = PACED if paced else float(s["seconds"])
        fov = s["fov_deg"]
        if isinstance(fov, str) and "->" in fov:
            a, b = [float(x) for x in fov.split("->")]
        elif fov is None:
            a = b = 72.0
        else:
            a = b = float(fov)
        n = max(1, int(round(secs * FPS)))
        name = s["shot"] + (" (paced)" if paced else "")
        sc.timeline_markers.new(name[:60], frame=frame)
        cd.angle_y = math.radians(a)
        cd.keyframe_insert("lens", frame=frame)
        cd.angle_y = math.radians(b)
        cd.keyframe_insert("lens", frame=frame + n)
        shots.append({"shot": s["shot"], "start_frame": frame, "frames": n, "paced": paced, "fov0": a, "fov1": b, "blocking": s["blocking"]})
        frame += n
    sc.frame_start = 0
    sc.frame_end = max(frame, 1)
    out[r["id"]] = {"title": r["title"], "status": r["status"], "frames": frame, "seconds": round(frame / FPS, 2), "shots": shots}
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "docs/cinematics/blender/sequences_all.blend"))
json.dump(out, open(os.path.join(root, "docs/cinematics/data/sequence_timelines.json"), "w"), indent=1)
print("SCENES", len(out), "TOTAL_S", round(sum(v["seconds"] for v in out.values()), 1))
