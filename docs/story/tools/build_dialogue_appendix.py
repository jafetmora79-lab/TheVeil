"""Exports the CURRENT line-by-line dialogue (game/data/dialogue.json, the runtime source of truth) per displayed chapter into docs/story/appendix/.
   python docs/story/tools/build_dialogue_appendix.py   (from the repo root)"""
import json, re, os, collections
d = json.load(open("game/data/dialogue.json", encoding="utf-8"))
MAP = [  # (regex on id, displayed chapter / bucket)
    (r"^(wake|fridge|keys|wash|need|left|in_|no_|shop|game|errands|groceries|pay|town|parked|market|merch|eddie|gh|map_intro|cq|edge)", "01-02_Act_I_opening_and_errands"),
    (r"^p3_", "03-04_Act_I_Veil_arrives_and_last_open_door"),
    (r"^p4_", "05_Act_I_Lock_In"),
    (r"^c5_", "06_Act_II_The_First_Search"),
    (r"^c6_", "07_Act_II_Voices_in_the_Mist"),
    (r"^c7_", "08_Act_II_A_Trace_of_Noah"),
    (r"^c8_", "09_Act_III_Something_at_the_Doors"),
    (r"^c9_", "10_Act_III_The_Fall_of_the_Supermarket"),
    (r"^c10_", "11_Act_III_No_Safe_Road"),
    (r"^c11_", "12_Act_IV_The_Farm_Road"),
    (r"^c12_", "13_Act_IV_The_Truth_Beneath_Greyhaven"),
    (r"^c13_", "14_Act_IV_Into_the_Veil"),
    (r"^c14_", "15_Act_V_The_Last_Shelter"),
    (r"^c15_", "16_Act_V_What_Remains"),
    (r"^(lt_|sv_|exp_|obs_|gun_)", "OPT_living_town_survivors_expedition_optional"),
]
buckets = collections.OrderedDict()
for k, v in d.items():
    if not isinstance(v, dict) or "lines" not in v:
        continue
    for rx, b in MAP:
        if re.match(rx, k):
            buckets.setdefault(b, []).append(k)
            break
    else:
        buckets.setdefault("OTHER", []).append(k)
os.makedirs("docs/story/appendix", exist_ok=True)
idx = ["# Current dialogue, by displayed chapter", "", "Exported verbatim from `game/data/dialogue.json` (runtime source of truth). Every PROPOSED or REVISED line in the story docs carries a new subtitle ID; these are CURRENT.", ""]
for b, ids in sorted(buckets.items()):
    out = ["# %s" % b, ""]
    n = 0
    for k in ids:
        v = d[k]
        out.append("## `%s`%s" % (k, " (draft)" if v.get("draft") else ""))
        if v.get("source"):
            out.append("_%s_" % v["source"])
        if v.get("choices"):
            out.append("choices: " + " / ".join(str(c.get("text", c)) if isinstance(c, dict) else str(c) for c in v["choices"]))
        for l in v["lines"]:
            out.append("- **%s** %s" % (l.get("speaker") or "(protagonist)", l.get("text", "")))
            n += 1
        out.append("")
    open("docs/story/appendix/current_dialogue_%s.md" % b, "w", encoding="utf-8").write("\n".join(out))
    idx.append("- [%s](current_dialogue_%s.md) - %d scenes, %d lines" % (b, b, len(ids), n))
open("docs/story/appendix/INDEX.md", "w", encoding="utf-8").write("\n".join(idx))
print({b: len(i) for b, i in buckets.items()})
