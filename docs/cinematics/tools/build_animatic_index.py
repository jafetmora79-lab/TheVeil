"""Builds docs/cinematics/animatic/index.html: every sequence as a row of shot bars (fixed seconds solid, player-paced shaded), a playhead you can scrub, lens per shot.
A schematic timeline, not a render. Run from the repo root after build_ledger.py and blender build_sequences.py."""
import json, html
d = json.load(open("docs/cinematics/data/sequence_timelines.json", encoding="utf-8"))
rows = []
for sid, v in d.items():
    bars = "".join('<div class="b%s" style="flex:%d" title="%s | %s | fov %s-%s">%s</div>' % (
        " p" if s["paced"] else "", max(s["frames"], 6), html.escape(s["shot"]), html.escape(s["blocking"]), round(s["fov0"]), round(s["fov1"]), html.escape(s["shot"][:28])) for s in v["shots"])
    rows.append('<div class="r"><div class="h"><b>%s</b> %s <i>%s - %.1f s</i></div><div class="t">%s</div></div>' % (sid, html.escape(v["title"]), html.escape(v["status"]), v["seconds"], bars))
page = """<!doctype html><meta charset=utf-8><title>The Veil - sequence animatic index</title>
<style>body{background:#111;color:#ddd;font:13px monospace;margin:12px}.r{margin:6px 0}.h i{color:#889}.t{display:flex;gap:2px}.b{background:#3a5a7a;padding:3px;overflow:hidden;white-space:nowrap;border-left:2px solid #8cf}.b.p{background:#4a4a4a;border-left-color:#777}</style>
<h3>Sequence animatic index (schematic: seconds where the code fixes them, shaded = player-paced, 4 s placeholder). Hover a bar for blocking and lens.</h3>
""" + "\n".join(rows)
open("docs/cinematics/animatic/index.html", "w", encoding="utf-8").write(page)
print(len(rows), "sequences")
