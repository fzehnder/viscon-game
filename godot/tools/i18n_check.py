#!/usr/bin/env python3
"""Lists German text in the scripts that has no English yet (see scripts/i18n.gd).

    python3 godot/tools/i18n_check.py            # everything that is missing, per file
    python3 godot/tools/i18n_check.py level3     # only files whose path contains "level3"
    python3 godot/tools/i18n_check.py --all      # also text that looks like an id

The English lives in scripts/i18n_en.gd (everything outside the level folders) and in
scripts/level<N>/en.gd (one per level folder), as  "German": "English",  lines.
A text counts as covered if it is a key there. Text that only exists as a piece of a longer
key, or that the game puts together at run time, may still be listed; that is fine if the
longer key (with %s) covers it.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "..", "scripts")
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
KEY = re.compile(r'^\s*"((?:[^"\\\n]|\\.)*)"\s*:\s*"')
IDENT = re.compile(r'^[a-z0-9_./:\-]*$')
GERMAN_HINT = re.compile(r'[äöüßÄÖÜ]|\b(der|die|das|den|dem|und|ist|nicht|ein|eine|einen|ihr|du|dich|dir|mit|zum|zur|für|auf|noch|schon|jetzt|wird|sind|habt|hast|kein|keine|wer|was|wie|wo|ich|wir|euch|bitte|gut|weiter|zurück|nochmals|starten|Aufgabe|Fehler|Zeit|Level)\b', re.I)


def literals(path):
    for ln, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.lstrip().startswith("#"):
            continue
        for m in LIT.finditer(line):
            t = m.group(1)
            after = line[m.end():m.end() + 2]
            if after.startswith(":") and not after.startswith(":="):
                continue   # a dictionary key
            if t.startswith(("res://", "user://")) or re.fullmatch(r"[0-9a-fA-F]{6,8}", t):
                continue
            if IDENT.match(t) or not re.search(r"[A-Za-zÄÖÜäöüß]{2,}", t):
                continue
            yield ln, t


def english_keys():
    keys = set()
    for dp, _, files in os.walk(SCRIPTS):
        for f in files:
            if f == "i18n_en.gd" or f == "en.gd":
                here = set()
                for ln, line in enumerate(open(os.path.join(dp, f), encoding="utf-8"), 1):
                    m = KEY.match(line)
                    if m:
                        if m.group(1) in here:
                            # GDScript refuses the whole file then, and all of its English is gone
                            print("DUPLICATE KEY %s:%d  %s" % (os.path.relpath(os.path.join(dp, f), SCRIPTS), ln, m.group(1)))
                        here.add(m.group(1))
                        keys.add(m.group(1))
    return keys


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    show_all = "--all" in sys.argv
    keys = english_keys()
    lines_of_keys = set()
    for k in keys:
        for part in k.split("\\n"):
            lines_of_keys.add(part.strip())
    total = 0
    for dp, _, files in sorted(os.walk(SCRIPTS)):
        for f in sorted(files):
            if not f.endswith(".gd") or f in ("i18n_en.gd", "en.gd", "i18n.gd"):
                continue
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, SCRIPTS)
            if args and not any(a in rel for a in args):
                continue
            missing = []
            seen = set()
            for ln, t in literals(path):
                if t in keys or t.strip() in lines_of_keys or t in seen:
                    continue
                if not show_all and not GERMAN_HINT.search(t) and not re.search(r"[A-ZÄÖÜ][a-zäöüß]+ [a-zäöüß]", t):
                    continue
                seen.add(t)
                missing.append((ln, t))
            if missing:
                print("== %s (%d)" % (rel, len(missing)))
                for ln, t in missing:
                    print("  %4d  %s" % (ln, t))
                total += len(missing)
    print("missing: %d" % total)


if __name__ == "__main__":
    main()
