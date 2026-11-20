"""Builds docs/story/data/flags_current.json from the source: every literal flag passed to set_flag / has_flag / clear_flag, with the files that set and read it.
   python docs/story/tools/build_flag_dictionary.py   (from the repo root)"""
import re, os, json, collections
setters, readers = collections.defaultdict(set), collections.defaultdict(set)
dyn = collections.defaultdict(set)
for dp, dn, fn in os.walk("game"):
    for f in fn:
        if not f.endswith(".gd") or "/tests/" in dp.replace("\\", "/") or "\tests" in dp:
            continue
        p = os.path.join(dp, f).replace("\\", "/")
        s = open(p, encoding="utf-8", errors="ignore").read()
        for m in re.finditer(r'(set_flag|clear_flag)\(\s*"([A-Za-z0-9_]+)"', s):
            setters[m.group(2)].add(p)
        for m in re.finditer(r'has_flag\(\s*"([A-Za-z0-9_]+)"', s):
            readers[m.group(1)].add(p)
        for m in re.finditer(r'(set_flag|has_flag)\(\s*"([A-Za-z0-9_]+)"\s*%', s):
            dyn[m.group(2)].add(p)
        for m in re.finditer(r'(set_flag|has_flag)\(\s*"([A-Za-z0-9_]+_)"\s*\+', s):
            dyn[m.group(2)].add(p)
out = {}
for k in sorted(set(setters) | set(readers)):
    out[k] = {"set_in": sorted(setters.get(k, [])), "read_in": sorted(readers.get(k, []))}
json.dump({"flags": out, "dynamic_prefixes": {k: sorted(v) for k, v in dyn.items()}}, open("docs/story/data/flags_current.json", "w"), indent=1)
print(len(out), "flags;", len(dyn), "dynamic prefixes")
by = collections.Counter()
for k in out:
    by[re.match(r"[a-z]+\d*", k).group(0)] += 1
print(by.most_common(25))
