#!/usr/bin/env python3
"""Übersetzungen pflegen: sammelt alle übersetzbaren Texte und aktualisiert locale/<sprache>.po.

Quellsprache ist Deutsch – die deutschen Texte sind gleichzeitig die msgids.
Gesammelt werden:
  * tr("…") und TranslationServer.translate("…") in scripts/**/*.gd
  * Texte in Konstanten direkt unter einem Kommentar "# i18n"
  * text, tooltip_text, title, placeholder_text in scenes/*.tscn
  * Anzeigefelder in data/*.json (name, description, text, intro, trophy, trophies)

Aufruf (im Projektordner):
  python3 tools/i18n.py            # locale/en.po aktualisieren (neue Texte mit leerer Übersetzung)
  python3 tools/i18n.py --check    # Fehler (Exit 1), wenn eine Übersetzung fehlt – vor jedem Commit!
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["en"]
DATA_FIELDS = {"name", "description", "text", "intro", "trophy"}
STR = r'"((?:[^"\\]|\\.)*)"'


def gd_unescape(s):
    return bytes(s, "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def worth(s):
    """Gleiche Regel wie beim Markieren: nur echte Anzeigetexte, keine IDs."""
    if len(s) < 2 or re.fullmatch(r"[a-z0-9_./ \-]+", s) or not re.search(r"[A-Za-zÄÖÜäöüß]{2,}", s):
        return False
    return bool(re.search(r"[ÄÖÜäöüß ]", s) or re.match(r"[A-ZÄÖÜ][a-zäöüß]+", s) or re.fullmatch(r"[A-ZÄÖÜ\-!]+", s))


def collect():
    found = {}  # msgid -> Fundstelle

    def add(text, where):
        if text and text not in found:
            found[text] = where

    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding="utf-8").read()
        for m in re.finditer(r'(?:\btr|TranslationServer\.translate)\(\s*' + STR, src):
            add(gd_unescape(m.group(1)), rel)
        lines = src.split("\n")
        for i, line in enumerate(lines):
            if line.strip().startswith("# i18n"):
                depth, j = 0, i + 1
                while j < len(lines):
                    code = lines[j].split("#")[0]
                    for m in re.finditer(STR, code):
                        text = gd_unescape(m.group(1))
                        if worth(text):
                            add(text, rel)
                    depth += code.count("[") + code.count("{") - code.count("]") - code.count("}")
                    if depth <= 0:
                        break
                    j += 1

    for path in sorted(glob.glob(os.path.join(ROOT, "scenes", "*.tscn"))):
        src = open(path, encoding="utf-8").read()
        for m in re.finditer(r'^(?:text|tooltip_text|title|placeholder_text) = ' + STR, src, re.M | re.S):
            add(gd_unescape(m.group(1)), os.path.relpath(path, ROOT))

    def walk(node, rel):
        if isinstance(node, dict):
            for k, v in node.items():
                if k in DATA_FIELDS and isinstance(v, str):
                    add(v, rel)
                elif k == "trophies" and isinstance(v, list):
                    for t in v:
                        add(t, rel)
                else:
                    walk(v, rel)
        elif isinstance(node, list):
            for v in node:
                walk(v, rel)

    for path in sorted(glob.glob(os.path.join(ROOT, "data", "*.json"))):
        walk(json.load(open(path, encoding="utf-8")), os.path.relpath(path, ROOT))
    found.pop("Punch your Enemy", None)
    return found


def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def read_po(path):
    entries = {}
    if not os.path.exists(path):
        return entries
    msgid = msgstr = None
    mode = None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith("msgid "):
            if msgid is not None:
                entries[msgid] = msgstr
            msgid, msgstr, mode = po_unescape(line[7:-1]), "", "id"
        elif line.startswith("msgstr "):
            msgstr, mode = po_unescape(line[8:-1]), "str"
        elif line.startswith('"') and mode:
            if mode == "id":
                msgid += po_unescape(line[1:-1])
            else:
                msgstr += po_unescape(line[1:-1])
    if msgid is not None:
        entries[msgid] = msgstr
    entries.pop("", None)
    return entries


def write_po(path, lang, found, old):
    out = [
        "# Punch your Enemy – Übersetzung (%s). Quellsprache: Deutsch." % lang,
        "# Mit tools/i18n.py aktualisieren, nicht die msgids von Hand ändern.",
        'msgid ""', 'msgstr ""',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Language: %s\\n"' % lang, "",
    ]
    for msgid, where in found.items():
        out.append("#: " + where)
        out.append('msgid "%s"' % po_escape(msgid))
        out.append('msgstr "%s"' % po_escape(old.get(msgid, "")))
        out.append("")
    open(path, "w", encoding="utf-8").write("\n".join(out))


def main():
    check = "--check" in sys.argv
    found = collect()
    missing_total = 0
    for lang in LANGS:
        path = os.path.join(ROOT, "locale", lang + ".po")
        old = read_po(path)
        missing = [m for m in found if not old.get(m)]
        missing_total += len(missing)
        if check:
            for m in missing:
                print("FEHLT (%s): %s   [%s]" % (lang, m.replace("\n", "\\n"), found[m]))
        else:
            write_po(path, lang, found, old)
        print("%s: %d Texte, %d ohne Übersetzung" % (lang, len(found), len(missing)))
    if check and missing_total:
        sys.exit(1)


if __name__ == "__main__":
    main()
