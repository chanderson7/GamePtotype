#!/usr/bin/env python3
"""Flags `var x := f(...)` where f has no declared return type, which Godot 4 refuses
("Cannot infer the type of variable"), so the whole script fails to load. Covers local
functions, functions on preloaded scripts and on the autoloads. Run from the project:

    python3 tools/check_infer.py [paths...]

Best effort, for when no Godot binary is at hand. Exits 1 on any finding.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_calls import ROOT, PRELOAD, EXTENDS, strip_strings_and_comments  # noqa: E402

AUTOLOADS = {"GameState": "scripts/game_state.gd", "Sound": "scripts/audio/sound.gd", "Scenes": "scripts/ui/scenes.gd"}
FUNC_RET = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)\s*\((.*?)\)\s*(->\s*([\w\[\].]+))?\s*:', re.M | re.S)
INFER = re.compile(r'^\s*var\s+(\w+)\s*:=\s*(.+)$', re.M)
_cache = {}


def returns(rel):
    if rel in _cache:
        return _cache[rel]
    out = {}
    _cache[rel] = out
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        return out
    text = strip_strings_and_comments(open(path, encoding="utf-8").read())
    for m in FUNC_RET.finditer(text):
        out[m.group(1)] = m.group(4)  # None when untyped
    ext = EXTENDS.search(text)
    if ext:
        for k, v in returns(ext.group(1)).items():
            out.setdefault(k, v)
    return out


def check(path):
    rel = os.path.relpath(path, ROOT)
    raw = open(path, encoding="utf-8").read()
    text = strip_strings_and_comments(raw)
    aliases = {m.group(1): m.group(2) for m in PRELOAD.finditer(raw)}
    aliases.update({k: v for k, v in AUTOLOADS.items() if k not in aliases})
    local = returns(rel)
    found = []
    for m in INFER.finditer(text):
        expr = m.group(2).strip()
        line = text.count("\n", 0, m.start()) + 1
        if re.search(r'\bas\s+[\w\[\]]+\s*$', expr):
            continue  # a cast types it
        target = None
        mm = re.match(r'^(\w+)\.(\w+)\(', expr)
        if mm and mm.group(1) in aliases:
            target = (aliases[mm.group(1)], mm.group(2), returns(aliases[mm.group(1)]))
        else:
            mm = re.match(r'^(\w+)\(', expr)
            if mm and mm.group(1) in local:
                target = (rel, mm.group(1), local)
        if target is None:
            continue
        # Only a bare call: `f(x) + 1` or `f(x).y` is judged by Godot differently.
        res = re.match(r'^[\w.]+\(', expr)
        depth = 0
        end = None
        for i, ch in enumerate(expr):
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        if end is None or expr[end + 1:].strip() not in ("", ",") and not expr[end + 1:].strip().startswith("#"):
            continue
        name = target[1]
        ret = target[2].get(name, "missing")
        if ret is None or ret == "Variant":
            found.append("%s:%d: var %s := %s() but %s has no return type" % (rel, line, m.group(1), name, name))
    return found


def main(argv):
    targets = argv or ["scripts", "tests"]
    files = []
    for t in targets:
        t = t if os.path.isabs(t) else os.path.join(ROOT, t)
        if os.path.isdir(t):
            for d, _, names in os.walk(t):
                files += [os.path.join(d, n) for n in names if n.endswith(".gd")]
        else:
            files.append(t)
    found = []
    for f in sorted(files):
        found += check(f)
    for x in found:
        print(x)
    print("%d files, %d findings" % (len(files), len(found)))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
