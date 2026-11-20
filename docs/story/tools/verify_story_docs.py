"""Checks the story docs against the repo: every `file.gd:function` reference exists, and every backticked dialogue/flag-looking id is either in
dialogue.json / flags_current.json / items.json (CURRENT) or listed as NEW. Prints the unknowns so a human can confirm each is a [P] proposal.
   python docs/story/tools/verify_story_docs.py   (from the repo root)"""
import re, os, json, glob, sys
docs = sorted(glob.glob("docs/story/[A-F]*.md"))
d = json.load(open("game/data/dialogue.json", encoding="utf-8"))
ids = {k for k, v in d.items() if isinstance(v, dict)}
flags = set(json.load(open("docs/story/data/flags_current.json"))["flags"])
items = set(json.load(open("game/data/items.json", encoding="utf-8"))["items"])
gd = {}
for dp, dn, fn in os.walk("game"):
    for f in fn:
        if f.endswith(".gd"):
            gd.setdefault(f, []).append(os.path.join(dp, f))
src_cache = {}
def has_func(fname, fn):
    for p in gd.get(fname, []):
        s = src_cache.setdefault(p, open(p, encoding="utf-8", errors="ignore").read())
        if re.search(r"func\s+" + re.escape(fn) + r"\b", s) or re.search(r"\b" + re.escape(fn) + r"\b", s):
            return True
    return False
bad_func, unknown = [], {}
nref = 0
for p in docs:
    s = open(p, encoding="utf-8").read()
    for m in re.finditer(r"`?(\w+\.gd)(?::|`: `)(_[A-Za-z]\w*|[A-Za-z]\w*)`?", s):
        nref += 1
        if m.group(1) not in gd or not has_func(m.group(1), m.group(2)):
            bad_func.append((os.path.basename(p), m.group(1), m.group(2)))
    for m in re.finditer(r"`((?:c\d+|p3|p4|lt|ch\d+|noah|wake|fridge)[A-Za-z0-9_]*)`", s):
        t = m.group(1)
        base = re.sub(r"_(Sarah|Ruth|Marcus|Eddie|alt)$", "", t)
        if t in ids or base in ids or t in flags or t in items:
            continue
        unknown.setdefault(t, set()).add(os.path.basename(p))
print("file:function references checked:", nref, " missing:", len(bad_func))
for b in bad_func:
    print("  MISSING", b)
print("ids/flags not in the repo (must all be NEW [P] items):", len(unknown))
for k, v in sorted(unknown.items()):
    print("  ", k, sorted(v))
sys.exit(1 if bad_func else 0)
