#!/usr/bin/env python3
"""Static check for calls into preloaded scripts, for when no Godot binary is at hand.

For every `const Name = preload("res://....gd")` in a script, each `Name.member(...)` call
must name a function the target script defines, with an argument count it accepts, and
each `Name.MEMBER` must name a const, var, enum, inner class or function there. It also
follows `extends "res://....gd"` one level for members. Run from the project folder:

    python3 tools/check_calls.py [paths...]

Exits 1 on any problem. It is not a type checker: it only catches the slips a refactor
makes most (a renamed helper, a dropped or added argument, a moved constant).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PRELOAD = re.compile(r'^\s*const\s+(\w+)\s*(?::=|=)\s*preload\("res://([^"]+\.gd)"\)', re.M)
FUNC = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)\s*\(', re.M)
MEMBER = re.compile(r'^\s*(?:static\s+)?(?:const|var|enum|class|signal)\s+(\w+)', re.M)
EXTENDS = re.compile(r'^extends\s+"res://([^"]+\.gd)"', re.M)
BUILTIN = {"new", "get", "set", "call", "has_method", "callv", "get_script", "resource_path",
           "get_class", "is_class", "connect", "emit", "bind"}

_cache = {}


def split_args(text, start):
    """Arguments of the call whose '(' is at text[start]; returns (args, end) or None."""
    depth = 0
    i = start
    args = []
    cur = ""
    quote = None
    while i < len(text):
        ch = text[i]
        if quote:
            cur += ch
            if ch == "\\":
                cur += text[i + 1] if i + 1 < len(text) else ""
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            cur += ch
        elif ch == "#":
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        elif ch in "([{":
            depth += 1
            if depth > 1:
                cur += ch
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                if cur.strip():
                    args.append(cur.strip())
                return args, i
            cur += ch
        elif ch == "," and depth == 1:
            args.append(cur.strip())
            cur = ""
        else:
            cur += ch
        i += 1
    return None


def signature(text, m):
    """(required, total) parameter counts of the func matched at m."""
    res = split_args(text, m.end() - 1)
    if res is None:
        return (0, 99)
    params = [p for p in res[0] if p]
    req = sum(1 for p in params if "=" not in p)
    return (req, len(params))


def load(rel):
    if rel in _cache:
        return _cache[rel]
    path = os.path.join(ROOT, rel)
    info = {"funcs": {}, "members": set(), "ok": os.path.exists(path)}
    _cache[rel] = info
    if not info["ok"]:
        return info
    text = open(path, encoding="utf-8").read()
    for m in FUNC.finditer(text):
        info["funcs"][m.group(1)] = signature(text, m)
    info["members"].update(MEMBER.findall(text))
    ext = EXTENDS.search(text)
    if ext:
        parent = load(ext.group(1))
        for k, v in parent["funcs"].items():
            info["funcs"].setdefault(k, v)
        info["members"] |= parent["members"]
    return info


def strip_strings_and_comments(text):
    out = []
    i = 0
    quote = None
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == "\\":
                out.append("  ")
                i += 2
                continue
            if ch == quote:
                quote = None
                out.append(ch)
            else:
                out.append("\n" if ch == "\n" else " ")
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#":
            while i < len(text) and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def check_file(path):
    problems = []
    raw = open(path, encoding="utf-8").read()
    text = strip_strings_and_comments(raw)
    aliases = {m.group(1): m.group(2) for m in PRELOAD.finditer(raw)}
    for alias, rel in aliases.items():
        info = load(rel)
        if not info["ok"]:
            problems.append("%s: %s preloads missing %s" % (path, alias, rel))
            continue
        for m in re.finditer(r'(?<![\w.])%s\.(\w+)(\s*\()?' % re.escape(alias), text):
            name = m.group(1)
            line = text.count("\n", 0, m.start()) + 1
            if name in BUILTIN:
                continue
            if m.group(2):
                if name not in info["funcs"]:
                    if name in info["members"]:
                        continue  # an inner class constructor or a callable var
                    problems.append("%s:%d: %s.%s() is not defined in %s" % (path, line, alias, name, rel))
                    continue
                res = split_args(text, m.end() - 1)
                if res is None:
                    continue
                n = len(res[0])
                req, total = info["funcs"][name]
                if n < req or n > total:
                    problems.append("%s:%d: %s.%s() takes %d to %d arguments, given %d" % (path, line, alias, name, req, total, n))
            elif name not in info["members"] and name not in info["funcs"]:
                problems.append("%s:%d: %s.%s is not defined in %s" % (path, line, alias, name, rel))
    return problems


def main(argv):
    targets = argv or ["scripts", "tests"]
    files = []
    for t in targets:
        t = os.path.join(ROOT, t) if not os.path.isabs(t) else t
        if os.path.isdir(t):
            for d, _, names in os.walk(t):
                files += [os.path.join(d, n) for n in names if n.endswith(".gd")]
        else:
            files.append(t)
    problems = []
    for f in sorted(files):
        problems += check_file(f)
    for p in problems:
        print(p)
    print("%d files, %d problems" % (len(files), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
