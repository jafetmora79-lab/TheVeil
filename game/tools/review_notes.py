"""Reads / updates the playtest sticky notes made with F2 (review mode) in THE VEIL.
   python game/tools/review_notes.py list            open notes, one line each
   python game/tools/review_notes.py list --all      every note
   python game/tools/review_notes.py show 7          one note in full (+ where its screenshot is)
   python game/tools/review_notes.py done 7 "what was changed" [commit]
   python game/tools/review_notes.py wontfix 7 "why"
   python game/tools/review_notes.py reopen 7
   python game/tools/review_notes.py path            where the notes file and screenshots are
The notes live in  %APPDATA%/Godot/app_userdata/THE VEIL/veil_notes.json  (override with env VEIL_NOTES)."""
import json, os, sys, datetime

DEFAULT = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "THE VEIL", "veil_notes.json")
PATH = os.environ.get("VEIL_NOTES", DEFAULT)


def load():
    if not os.path.exists(PATH):
        sys.exit("no notes file at " + PATH)
    return json.load(open(PATH, encoding="utf-8"))


def save(d):
    json.dump(d, open(PATH, "w", encoding="utf-8"), indent=2)


def find(d, i):
    for n in d["notes"]:
        if int(n["id"]) == i:
            return n
    sys.exit("no note #%d" % i)


def line(n):
    t = n.get("target", {})
    cands = t.get("candidates", [])
    scene = (cands[0].get("scene") if cands and cands[0].get("scene") else t.get("scene", "")) or ""
    return "#%-3d [%-6s] %-5s ch%-2s %s   -> %s %s" % (n["id"], n.get("status", "open"), n.get("type", ""), n.get("chapter", {}).get("number", "?"),
                                                    n.get("text", "")[:90].replace("\n", " / "), t.get("name", "?"), os.path.basename(scene))


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else "list"
    if cmd == "path":
        print(PATH)
        print(os.path.join(os.path.dirname(PATH), "review"))
        return
    d = load()
    if cmd == "list":
        show_all = "--all" in a
        rows = [n for n in d["notes"] if show_all or n.get("status", "open") == "open"]
        for n in rows:
            print(line(n))
        print("%d shown, %d open of %d" % (len(rows), sum(1 for n in d["notes"] if n.get("status", "open") == "open"), len(d["notes"])))
    elif cmd == "show":
        n = find(d, int(a[1]))
        print(json.dumps({k: v for k, v in n.items() if k != "flags"}, indent=2))
        print("flags set:", len(n.get("flags", [])))
        if n.get("screenshot"):
            print("screenshot:", os.path.join(os.path.dirname(PATH), "review", n["screenshot"]))
    elif cmd in ("done", "wontfix"):
        n = find(d, int(a[1]))
        n["status"] = "fixed" if cmd == "done" else "wontfix"
        n["resolution"] = {"note": a[2] if len(a) > 2 else "", "commit": a[3] if len(a) > 3 else "", "when": datetime.datetime.now().isoformat(timespec="seconds")}
        save(d)
        print(line(n))
    elif cmd == "reopen":
        n = find(d, int(a[1]))
        n["status"] = "open"
        n.pop("resolution", None)
        save(d)
        print(line(n))
    else:
        sys.exit(__doc__)


main()
